import 'package:audio_service/audio_service.dart';
import 'package:audio_session/audio_session.dart';
import 'package:dionysos/data/settings/appsettings.dart';
import 'package:dionysos/service/extension.dart';
import 'package:dionysos/service/player.dart';
import 'package:dionysos/utils/log.dart';
import 'package:dionysos/utils/observer.dart';
import 'package:dionysos/utils/service.dart';
import 'package:dionysos/views/view/paragraphlist/tts_audio_handler.dart';
import 'package:dionysos/views/view/paragraphlist/tts_regularise.dart';
import 'package:flutter/widgets.dart';
import 'package:flutter_dispose_scope/flutter_dispose_scope.dart';
import 'package:flutter_tts/flutter_tts.dart';

export 'package:dionysos/views/view/paragraphlist/tts_audio_handler.dart'
    show TtsMediaInfo;

enum TtsState { stopped, playing, paused }

typedef TtsNextChapter = ({
  List<Paragraph> paragraphs,
  bool hasNext,
  TtsMediaInfo? media,
});

class TtsStateData extends InheritedWidget {
  final TtsController controller;
  const TtsStateData({
    super.key,
    required this.controller,
    required super.child,
  });

  static TtsController? of(BuildContext context) {
    return context
        .dependOnInheritedWidgetOfExactType<TtsStateData>()
        ?.controller;
  }

  @override
  bool updateShouldNotify(TtsStateData oldWidget) => true;
}

List<(int index, String text)> extractTextFromParagraphs(
  List<Paragraph> paragraphs,
) {
  final tts = settings.readerSettings.paragraphreader.tts;
  final doRegularise = tts.regularise.enabled.value;
  final stripSeparators = tts.regularise.stripSeparators.value;
  final collapseBlankLines = tts.regularise.collapseBlankLines.value;
  final result = <(int, String)>[];
  for (int i = 0; i < paragraphs.length; i++) {
    final raw = _paragraphToText(paragraphs[i]);
    if (raw == null) continue;
    final text = doRegularise
        ? regulariseText(
            raw,
            stripSeparators: stripSeparators,
            collapseBlankLines: collapseBlankLines,
          )
        : raw.trim();
    if (text.isNotEmpty) {
      result.add((i, text));
    }
  }
  return result;
}

String? _paragraphToText(Paragraph p) {
  switch (p) {
    case final Paragraph_Text t:
      return t.content;
    case final Paragraph_Mixed m:
      final buf = StringBuffer();
      for (final c in m.content) {
        switch (c) {
          case final MixedContent_Text t:
            buf.write(t.content);
          case MixedContent_CustomUI():
            break;
          case final MixedContent_Table table:
            for (final row in table.columns) {
              for (final cell in row.cells) {
                final cellText = _paragraphToText(cell);
                if (cellText != null) {
                  buf.write(cellText);
                  buf.write(' ');
                }
              }
            }
        }
      }
      return buf.toString();
    case Paragraph_CustomUI():
      return null;
    case final Paragraph_Table table:
      final buf = StringBuffer();
      for (final row in table.columns) {
        for (final cell in row.cells) {
          final cellText = _paragraphToText(cell);
          if (cellText != null) {
            buf.write(cellText);
            buf.write(' ');
          }
        }
      }
      return buf.isEmpty ? null : buf.toString();
  }
}

class TtsController with ChangeNotifier, DisposeScope implements Disposable {
  final FlutterTts _tts = FlutterTts();
  final TtsAudioHandler _audioHandler = TtsAudioHandler();

  TtsState _state = TtsState.stopped;
  TtsState get state => _state;

  int _currentParagraphIndex = -1;
  int get currentParagraphIndex => _currentParagraphIndex;

  /// The start and end character offsets of the word currently being spoken
  /// within the current paragraph's text.
  int _wordStart = 0;
  int _wordEnd = 0;
  int get wordStart => _wordStart;
  int get wordEnd => _wordEnd;

  /// The extracted text segments: (original paragraph index, text).
  List<(int index, String text)> _segments = [];

  /// Index into [_segments] for the segment currently being spoken.
  int _segmentIndex = 0;
  int get segmentIndex => _segmentIndex;
  int get segmentCount => _segments.length;

  bool _isLoadingNextChapter = false;
  bool get isLoadingNextChapter => _isLoadingNextChapter;

  Future<TtsNextChapter?> Function()? onLoadNextChapter;

  TtsMediaInfo? _mediaInfo;

  bool _sessionActive = false;
  bool _disposed = false;

  int _generation = 0;

  TtsController() {
    _initTts();
    _bindSettings();
    _wireAudioHandler();
  }

  Future<void> _initTts() async {
    final tts = settings.readerSettings.paragraphreader.tts;
    await _tts.setLanguage(tts.language.value);
    await _tts.setSpeechRate(tts.rate.value);
    await _tts.setVolume(tts.volume.value);
    await _tts.setPitch(tts.pitch.value);

    addDispose(() => _tts.stop());

    _tts.setStartHandler(() {
      _state = TtsState.playing;
      _notifyState();
    });

    _tts.setCompletionHandler(() {
      _onSegmentComplete();
    });

    _tts.setProgressHandler((
      String text,
      int startOffset,
      int endOffset,
      String word,
    ) {
      _wordStart = startOffset;
      _wordEnd = endOffset;
      notifyListeners();
    });

    _tts.setErrorHandler((msg) {
      logger.e('TTS error: $msg');
      _engineBusy = false;
      _stopForRestart = false;
      _state = TtsState.stopped;
      _notifyState();
    });

    _tts.setCancelHandler(() {
      _onCancel();
    });

    _tts.setPauseHandler(() {
      _state = TtsState.paused;
      _notifyState();
    });

    _tts.setContinueHandler(() {
      _state = TtsState.playing;
      _notifyState();
    });
  }

  void _bindSettings() {
    final tts = settings.readerSettings.paragraphreader.tts;
    Observer(
      () => _tts.setLanguage(tts.language.value),
      tts.language,
    ).disposedBy(this);
    Observer(
      () => _tts.setSpeechRate(tts.rate.value),
      tts.rate,
    ).disposedBy(this);
    Observer(() => _tts.setPitch(tts.pitch.value), tts.pitch).disposedBy(this);
    Observer(
      () => _tts.setVolume(tts.volume.value),
      tts.volume,
    ).disposedBy(this);
  }

  void _wireAudioHandler() {
    _audioHandler.onPlay = resume;
    _audioHandler.onPause = pause;
    _audioHandler.onStop = stop;
    _audioHandler.onSkipNext = skipToNextParagraph;
    _audioHandler.onSkipPrevious = skipToPreviousParagraph;
  }

  void loadParagraphs(
    List<Paragraph> paragraphs, {
    bool hasNextChapter = false,
    TtsMediaInfo? mediaInfo,
  }) {
    _segments = extractTextFromParagraphs(paragraphs);
    _segmentIndex = 0;
    _currentParagraphIndex = _segments.isNotEmpty ? _segments[0].$1 : -1;
    _wordStart = 0;
    _wordEnd = 0;
    _isLoadingNextChapter = false;
    _mediaInfo = mediaInfo;
    _audioHandler.hasNext = hasNextChapter;
    if (_sessionActive) {
      _audioHandler.publishMediaItem(mediaInfo);
    }
    notifyListeners();
  }

  void setMediaInfo(TtsMediaInfo? mediaInfo) {
    _mediaInfo = mediaInfo;
    if (_sessionActive) {
      _audioHandler.publishMediaItem(mediaInfo);
    }
  }

  Future<void> speak({int? paragraphIndex}) async {
    if (_segments.isEmpty) return;

    if (paragraphIndex != null) {
      // Find the segment that matches or is closest after this paragraph index
      final idx = _segments.indexWhere((s) => s.$1 >= paragraphIndex);
      if (idx != -1) {
        _segmentIndex = idx;
      }
    }

    if (_segmentIndex >= _segments.length) {
      _segmentIndex = 0;
    }

    _state = TtsState.playing;
    await _activateSession();
    await _speakCurrentSegment();
  }

  /// Whether the engine is believed to be mid-utterance. Used to serialise
  /// speak requests: flutter_tts with QUEUE_FLUSH drops a second `speak` call
  /// while one is in flight, so before dispatching a new utterance we stop the
  /// current one and dispatch on the resulting cancel callback.
  bool _engineBusy = false;

  /// True when we have already asked the engine to stop in order to start a new
  /// utterance (skip). Prevents the cancel handler from treating a user-initiated
  /// stop as a "go ahead and speak the next" signal.
  bool _stopForRestart = false;

  Future<void> _speakCurrentSegment() async {
    if (_segmentIndex >= _segments.length) {
      await _handleChapterEnd();
      return;
    }
    if (_engineBusy) {
      // Queue this segment to be spoken once the current utterance cancels.
      _stopForRestart = true;
      await _tts.stop();
      return;
    }
    final segment = _segments[_segmentIndex];
    _currentParagraphIndex = segment.$1;
    _wordStart = 0;
    _wordEnd = 0;
    _engineBusy = true;
    _notifyState();
    await _tts.speak(segment.$2);
  }

  void _onSegmentComplete() {
    _engineBusy = false;
    if (_stopForRestart) {
      // We stopped only to restart with a new segment; don't advance.
      _stopForRestart = false;
      _speakCurrentSegment();
      return;
    }
    if (_state != TtsState.playing) return;
    _segmentIndex++;
    _speakCurrentSegment();
  }

  void _onCancel() {
    _engineBusy = false;
    if (_stopForRestart) {
      _stopForRestart = false;
      _speakCurrentSegment();
    }
  }

  Future<void> _handleChapterEnd() async {
    final loader = onLoadNextChapter;
    if (loader == null) {
      await stop();
      return;
    }
    // Stop any utterance still playing (e.g. a skip at the last segment) before
    // loading the next chapter, and clear the restart flags so a late cancel
    // callback doesn't spuriously dispatch a segment.
    _stopForRestart = false;
    if (_engineBusy) {
      _engineBusy = false;
      await _tts.stop();
    }
    _isLoadingNextChapter = true;
    _generation++;
    _audioHandler.publishState(
      playing: false,
      processing: AudioProcessingState.buffering,
    );
    notifyListeners();
    final genBefore = _generation;
    try {
      final next = await loader();
      // If a stop/skip happened while loading, abandon the advance.
      if (genBefore != _generation || _state == TtsState.stopped) {
        return;
      }
      if (next == null || next.paragraphs.isEmpty) {
        await stop();
        return;
      }
      loadParagraphs(
        next.paragraphs,
        hasNextChapter: next.hasNext,
        mediaInfo: next.media,
      );
      // Continue reading the new chapter from the top.
      await _speakCurrentSegment();
    } catch (e, stack) {
      logger.e('TTS chapter advance failed', error: e, stackTrace: stack);
      await stop();
    }
  }

  Future<void> pause() async {
    if (_state == TtsState.playing) {
      _generation++;
      _engineBusy = false;
      await _tts.pause();
      _state = TtsState.paused;
      _notifyState();
    }
  }

  Future<void> resume() async {
    if (_state == TtsState.paused) {
      // flutter_tts on some platforms doesn't support true resume,
      // so we re-speak the current segment
      _state = TtsState.playing;
      await _activateSession();
      await _speakCurrentSegment();
    }
  }

  Future<void> stop() async {
    _generation++;
    _engineBusy = false;
    _stopForRestart = false;
    await _tts.stop();
    _state = TtsState.stopped;
    _currentParagraphIndex = -1;
    _wordStart = 0;
    _wordEnd = 0;
    _isLoadingNextChapter = false;
    _segmentIndex = 0;
    await _deactivateSession();
    notifyListeners();
  }

  Future<void> skipToNextParagraph() async {
    if (_segments.isEmpty) return;
    _segmentIndex++;
    if (_segmentIndex >= _segments.length) {
      await _handleChapterEnd();
      return;
    }
    await _speakCurrentSegment();
  }

  Future<void> skipToPreviousParagraph() async {
    if (_segments.isEmpty) return;
    if (_segmentIndex > 0) {
      _segmentIndex--;
    }
    await _speakCurrentSegment();
  }

  Future<void> togglePlayPause({int? fromParagraph}) async {
    switch (_state) {
      case TtsState.stopped:
        await speak(paragraphIndex: fromParagraph);
      case TtsState.playing:
        await pause();
      case TtsState.paused:
        await resume();
    }
  }

  Future<void> _activateSession() async {
    if (_sessionActive) return;
    _sessionActive = true;
    try {
      final session = await AudioSession.instance;
      await session.configure(const AudioSessionConfiguration.speech());
      await session.setActive(true);
    } catch (e, stack) {
      logger.e(
        'Failed to configure audio session',
        error: e,
        stackTrace: stack,
      );
    }
    if (has<PlayerService>()) {
      locate<PlayerService>().setSession(_audioHandler);
    }
    _audioHandler.publishMediaItem(_mediaInfo);
    _audioHandler.publishState(playing: _state == TtsState.playing);
  }

  /// Release the audio session and hand the media session back to video.
  Future<void> _deactivateSession() async {
    if (!_sessionActive) return;
    _sessionActive = false;
    try {
      final session = await AudioSession.instance;
      await session.setActive(false);
    } catch (e, stack) {
      logger.e(
        'Failed to deactivate audio session',
        error: e,
        stackTrace: stack,
      );
    }
    if (has<PlayerService>()) {
      locate<PlayerService>().clearSession();
    }
  }

  /// Update internal state, notify listeners, and mirror to the media session.
  void _notifyState() {
    if (_sessionActive) {
      _audioHandler.publishState(
        playing: _state == TtsState.playing,
        processing: _isLoadingNextChapter
            ? AudioProcessingState.buffering
            : AudioProcessingState.ready,
      );
    }
    notifyListeners();
  }

  @override
  void disposedBy(DisposeScope disposeScope) {
    disposeScope.addDispose(dispose);
  }

  @override
  Future<void> dispose() async {
    if (_disposed) return;
    _disposed = true;
    _generation++;
    _engineBusy = false;
    _stopForRestart = false;
    await _tts.stop();
    await _deactivateSession();
    super.dispose();
  }
}
