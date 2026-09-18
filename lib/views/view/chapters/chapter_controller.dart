import 'dart:async';

import 'package:dionysos/data/settings/appsettings.dart';
import 'package:dionysos/service/extension.dart';
import 'package:dionysos/utils/log.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter_dispose_scope/flutter_dispose_scope.dart';
import 'package:media_kit/media_kit.dart';

class PlaybackChapter {
  final String title;
  final Duration start;
  final Duration? end;
  final ChapterKind? kind;
  const PlaybackChapter(this.title, this.start, {this.end, this.kind});

  @override
  String toString() => 'PlaybackChapter($title, $start, $end, $kind)';
}

ChapterKind? _kindFromTitle(String title) {
  final lower = title.toLowerCase();
  bool matches(RegExp pattern) => pattern.hasMatch(lower);
  if (matches(RegExp(r'\b(opening|intro|introduction|op)\b'))) {
    return ChapterKind.intro;
  }
  if (matches(RegExp(r'\b(outro|ending|ed|credits|closing)\b'))) {
    return ChapterKind.outro;
  }
  if (matches(RegExp(r'\b(recap|recaps|previously|last time|summary)\b'))) {
    return ChapterKind.recap;
  }
  if (matches(RegExp(r'\bfiller\b'))) {
    return ChapterKind.filler;
  }
  if (matches(RegExp(r'\b(preview|teaser|trailer|next (episode|time))\b'))) {
    return ChapterKind.preview;
  }
  return null;
}

class ChapterController with ChangeNotifier implements Disposable {
  final Player player;
  final ChapterAutoSkipSettings autoSkip;

  List<PlaybackChapter> _chapters = const [];
  int _currentIndex = -1;
  Duration _duration = Duration.zero;
  bool _canSkipCurrent = false;

  /// Set while the current chapter has not been auto-skipped yet; cleared on
  /// auto-skip and on user seeks so a seek into a chapter is never fought.
  bool _autoSkipArmed = true;
  Duration? _lastPosition;

  StreamSubscription? _positionSub;
  StreamSubscription? _durationSub;
  bool _disposed = false;
  int _generation = 0;

  ChapterController({required this.player, required this.autoSkip}) {
    _durationSub = player.stream.duration.listen(_onDuration);
    _positionSub = player.stream.position.listen(_onPosition);
  }

  List<PlaybackChapter> get chapters => _chapters;
  int get currentIndex => _currentIndex;
  bool get hasChapters => _chapters.isNotEmpty;

  /// Whether the currently playing chapter is one the user would want to skip
  /// manually (a typed chapter that has not been played through yet).
  bool get canSkipCurrent => _canSkipCurrent;

  PlaybackChapter? get currentChapter =>
      (_currentIndex >= 0 && _currentIndex < _chapters.length)
      ? _chapters[_currentIndex]
      : null;

  Duration endOf(PlaybackChapter chapter) {
    final explicit = chapter.end;
    if (explicit != null && explicit > chapter.start) {
      return explicit;
    }
    final index = _chapters.indexOf(chapter);
    if (index >= 0 && index + 1 < _chapters.length) {
      return _chapters[index + 1].start;
    }
    return chapter.start > _duration ? chapter.start : _duration;
  }

  /// Must be called by the view after [Player.open] for every media (episode
  /// or stream switch), passing the chapters the source provided, if any.
  Future<void> onMediaOpened({List<Chapter>? chapters}) async {
    _generation++;
    _currentIndex = -1;
    _lastPosition = null;
    _autoSkipArmed = true;
    _canSkipCurrent = false;
    if (chapters == null || chapters.isEmpty) {
      _chapters = const [];
    } else {
      _chapters = [
        for (final chapter in chapters)
          PlaybackChapter(
            chapter.title,
            Duration(milliseconds: (chapter.start * 1000).round()),
            end: chapter.end == null
                ? null
                : Duration(milliseconds: (chapter.end! * 1000).round()),
            kind: chapter.kind,
          ),
      ];
    }
    _notify();
    await _readPlayerChapters();
  }

  Future<void> goToChapter(int index) async {
    if (index < 0 || index >= _chapters.length) return;
    await player.seek(_chapters[index].start);
  }

  /// Advances to the next chapter. Returns false when the media has no more
  /// chapters, so the caller can fall back to episode navigation.
  Future<bool> nextChapter() async {
    if (!hasChapters || _currentIndex + 1 >= _chapters.length) return false;
    await goToChapter(_currentIndex + 1);
    return true;
  }

  /// Goes back to the previous chapter, or to the start of the current one
  /// when already more than a few seconds into it. Returns false when the
  /// media is in its first chapter, so the caller can fall back to episode
  /// navigation.
  Future<bool> prevChapter() async {
    if (!hasChapters) return false;
    if (_currentIndex >= 0) {
      final current = _chapters[_currentIndex];
      if (player.state.position - current.start > const Duration(seconds: 3)) {
        await goToChapter(_currentIndex);
        return true;
      }
    }
    if (_currentIndex <= 0) return false;
    await goToChapter(_currentIndex - 1);
    return true;
  }

  /// Seeks to the end of the current chapter (manual skip button).
  Future<void> skipCurrent() async {
    final chapter = currentChapter;
    if (chapter == null) return;
    await player.seek(endOf(chapter));
  }

  void _onDuration(Duration duration) {
    if (duration == _duration) return;
    _duration = duration;
    // The last chapter's implicit end depends on the duration.
    _notify();
  }

  void _onPosition(Duration position) {
    final last = _lastPosition;
    _lastPosition = position;
    if (_chapters.isEmpty || _duration <= Duration.zero) return;

    // A jump larger than natural playback granularity is a user (or resume)
    // seek; never auto-skip on its arrival position.
    final isSeek = last != null && (position - last).abs() > _seekThreshold;
    final index = _indexOf(position);
    final indexChanged = index != _currentIndex;
    if (indexChanged) {
      _currentIndex = index;
      _autoSkipArmed = true;
    }
    if (isSeek) {
      _autoSkipArmed = false;
    }

    final chapter = currentChapter;
    final canSkip =
        chapter != null &&
        chapter.kind != null &&
        position < endOf(chapter) - _manualSkipMargin;
    final skipStateChanged = canSkip != _canSkipCurrent;
    if (skipStateChanged) {
      _canSkipCurrent = canSkip;
    }
    if (indexChanged || skipStateChanged) {
      _notify();
    }

    if (chapter == null || chapter.kind == null) return;
    if (!_autoSkipArmed || isSeek || !player.state.playing) return;
    if (!_kindEnabled(chapter.kind!)) return;
    final end = endOf(chapter);
    if (position >= end - _autoSkipEpsilon) return;
    _autoSkipArmed = false;
    logger.d('Auto-skipping ${chapter.kind!.name} chapter "${chapter.title}"');
    player.seek(end);
  }

  int _indexOf(Duration position) {
    var low = 0;
    var high = _chapters.length - 1;
    var result = -1;
    while (low <= high) {
      final mid = (low + high) >> 1;
      if (_chapters[mid].start <= position) {
        result = mid;
        low = mid + 1;
      } else {
        high = mid - 1;
      }
    }
    return result;
  }

  bool _kindEnabled(ChapterKind kind) => switch (kind) {
    ChapterKind.intro => autoSkip.intro.value,
    ChapterKind.outro => autoSkip.outro.value,
    ChapterKind.recap => autoSkip.recap.value,
    ChapterKind.filler => autoSkip.filler.value,
    ChapterKind.preview => autoSkip.preview.value,
  };

  /// Reads chapters embedded in the container via mpv (M4B, MKV, MP4, ...).
  /// Only applied when the source did not provide its own chapters; chapters
  /// are available once demuxing finished, hence the duration wait.
  Future<void> _readPlayerChapters() async {
    if (kIsWeb || _chapters.isNotEmpty || _disposed) return;
    final platform = player.platform;
    if (platform is! NativePlayer) return;
    final generation = _generation;
    if (player.state.duration <= Duration.zero) {
      // Chapters only exist after demuxing; a manual subscription (instead of
      // firstWhere + timeout) avoids leaking a listener on timeout.
      final seen = Completer<void>();
      final sub = player.stream.duration
          .where((duration) => duration > Duration.zero)
          .listen((_) {
            if (!seen.isCompleted) seen.complete();
          });
      try {
        await seen.future.timeout(const Duration(seconds: 30));
      } on TimeoutException {
        return;
      } catch (e) {
        logger.d('Waiting for media duration failed: $e');
        return;
      } finally {
        await sub.cancel();
      }
    }
    if (_disposed || generation != _generation || _chapters.isNotEmpty) {
      return;
    }
    try {
      final count =
          int.tryParse(
            (await platform.getProperty('chapter-list/count')).trim(),
          ) ??
          0;
      if (count == 0 ||
          _disposed ||
          generation != _generation ||
          _chapters.isNotEmpty) {
        return;
      }
      final result = <PlaybackChapter>[];
      for (var i = 0; i < count; i++) {
        final rawTitle = (await platform.getProperty('chapter-list/$i/title'))
            .trim();
        final seconds = double.tryParse(
          (await platform.getProperty('chapter-list/$i/time')).trim(),
        );
        if (seconds == null) continue;
        result.add(
          PlaybackChapter(
            rawTitle.isEmpty ? 'Chapter ${result.length + 1}' : rawTitle,
            Duration(milliseconds: (seconds * 1000).round()),
            kind: _kindFromTitle(rawTitle),
          ),
        );
      }
      if (_disposed || generation != _generation || _chapters.isNotEmpty) {
        return;
      }
      if (result.isEmpty) return;
      _chapters = result;
      if (_lastPosition != null) {
        _currentIndex = _indexOf(_lastPosition!);
      }
      _notify();
    } catch (e, stack) {
      logger.d('Reading embedded chapters failed: $e', stackTrace: stack);
    }
  }

  void _notify() {
    if (_disposed) return;
    notifyListeners();
  }

  static const _seekThreshold = Duration(seconds: 2);
  static const _autoSkipEpsilon = Duration(milliseconds: 250);
  static const _manualSkipMargin = Duration(seconds: 1);

  @override
  void disposedBy(DisposeScope disposeScope) {
    disposeScope.addDispose(dispose);
  }

  @override
  Future<void> dispose() async {
    _disposed = true;
    await _positionSub?.cancel();
    await _durationSub?.cancel();
    super.dispose();
  }
}
