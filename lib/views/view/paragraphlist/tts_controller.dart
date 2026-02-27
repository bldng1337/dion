import 'package:dionysos/data/settings/appsettings.dart';
import 'package:dionysos/service/extension.dart';
import 'package:dionysos/utils/log.dart';
import 'package:dionysos/utils/observer.dart';
import 'package:flutter/widgets.dart';
import 'package:flutter_dispose_scope/flutter_dispose_scope.dart';
import 'package:flutter_tts/flutter_tts.dart';

enum TtsState { stopped, playing, paused }

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
  final result = <(int, String)>[];
  for (int i = 0; i < paragraphs.length; i++) {
    final text = _paragraphToText(paragraphs[i]);
    if (text != null && text.trim().isNotEmpty) {
      result.add((i, text.trim()));
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

  /// Callback to go to the next chapter.
  VoidCallback? onChapterEnd;

  TtsController() {
    _initTts();
    _bindSettings();
  }

  Future<void> _initTts() async {
    await _tts.setLanguage(
      settings.readerSettings.paragraphreader.tts.language.value,
    );
    await _tts.setSpeechRate(
      settings.readerSettings.paragraphreader.tts.rate.value,
    );
    await _tts.setVolume(
      settings.readerSettings.paragraphreader.tts.volume.value,
    );
    await _tts.setPitch(
      settings.readerSettings.paragraphreader.tts.pitch.value,
    );

    addDispose(() => _tts.stop());

    _tts.setStartHandler(() {
      _state = TtsState.playing;
      notifyListeners();
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
      _state = TtsState.stopped;
      notifyListeners();
    });

    _tts.setCancelHandler(() {
      _state = TtsState.stopped;
      notifyListeners();
    });

    _tts.setPauseHandler(() {
      _state = TtsState.paused;
      notifyListeners();
    });

    _tts.setContinueHandler(() {
      _state = TtsState.playing;
      notifyListeners();
    });
  }

  void _bindSettings() {
    Observer(
      () => _tts.setLanguage(
        settings.readerSettings.paragraphreader.tts.language.value,
      ),
      settings.readerSettings.paragraphreader.tts.language,
    ).disposedBy(this);
    Observer(
      () => _tts.setSpeechRate(
        settings.readerSettings.paragraphreader.tts.rate.value,
      ),
      settings.readerSettings.paragraphreader.tts.rate,
    ).disposedBy(this);
    Observer(
      () => _tts.setPitch(
        settings.readerSettings.paragraphreader.tts.pitch.value,
      ),
      settings.readerSettings.paragraphreader.tts.pitch,
    ).disposedBy(this);
    Observer(
      () => _tts.setVolume(
        settings.readerSettings.paragraphreader.tts.volume.value,
      ),
      settings.readerSettings.paragraphreader.tts.volume,
    ).disposedBy(this);
  }

  void loadParagraphs(List<Paragraph> paragraphs) {
    _segments = extractTextFromParagraphs(paragraphs);
    _segmentIndex = 0;
    _currentParagraphIndex = _segments.isNotEmpty ? _segments[0].$1 : -1;
    _wordStart = 0;
    _wordEnd = 0;
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

    await _speakCurrentSegment();
  }

  Future<void> _speakCurrentSegment() async {
    if (_segmentIndex >= _segments.length) {
      _state = TtsState.stopped;
      _currentParagraphIndex = -1;
      notifyListeners();
      onChapterEnd?.call();
      return;
    }

    final segment = _segments[_segmentIndex];
    _currentParagraphIndex = segment.$1;
    _wordStart = 0;
    _wordEnd = 0;
    notifyListeners();

    await _tts.speak(segment.$2);
  }

  void _onSegmentComplete() {
    _segmentIndex++;
    _speakCurrentSegment();
  }

  Future<void> pause() async {
    if (_state == TtsState.playing) {
      await _tts.pause();
      _state = TtsState.paused;
      notifyListeners();
    }
  }

  Future<void> resume() async {
    if (_state == TtsState.paused) {
      // flutter_tts on some platforms doesn't support true resume,
      // so we re-speak the current segment
      _state = TtsState.playing;
      notifyListeners();
      await _speakCurrentSegment();
    }
  }

  Future<void> stop() async {
    await _tts.stop();
    _state = TtsState.stopped;
    _currentParagraphIndex = -1;
    _wordStart = 0;
    _wordEnd = 0;
    notifyListeners();
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

  @override
  void disposedBy(DisposeScope disposeScope) {
    disposeScope.addDispose(dispose);
  }
}
