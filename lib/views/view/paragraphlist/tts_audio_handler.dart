import 'dart:async';

import 'package:audio_service/audio_service.dart';

class TtsMediaInfo {
  final String title;
  final String? album;
  final String? artist;
  final Uri? artUri;
  final Map<String, String>? artHeaders;

  const TtsMediaInfo({
    required this.title,
    this.album,
    this.artist,
    this.artUri,
    this.artHeaders,
  });
}

List<MediaControl> _ttsControls({
  required bool playing,
  required bool hasNext,
}) {
  return [
    if (playing) MediaControl.pause else MediaControl.play,
    if (hasNext) MediaControl.skipToNext,
  ];
}

class TtsAudioHandler extends BaseAudioHandler {
  /// Called when the system requests play/resume.
  Future<void> Function()? onPlay;

  /// Called when the system requests pause.
  Future<void> Function()? onPause;

  /// Called when the system requests stop.
  Future<void> Function()? onStop;

  /// Called when the system requests the next paragraph/chapter.
  Future<void> Function()? onSkipNext;

  /// Called when the system requests the previous paragraph/chapter.
  Future<void> Function()? onSkipPrevious;

  /// Whether a next chapter exists for the currently-read content. Controls
  /// whether the skip-to-next media button is shown.
  bool _hasNext = false;
  bool get hasNext => _hasNext;
  set hasNext(bool value) {
    _hasNext = value;
    _publishState();
  }

  /// Publish a new playback state derived from [playing] / [processing].
  void publishState({
    required bool playing,
    AudioProcessingState processing = AudioProcessingState.ready,
  }) {
    playbackState.add(
      PlaybackState(
        controls: _ttsControls(playing: playing, hasNext: _hasNext),
        systemActions: const {
          MediaAction.seek,
          MediaAction.seekForward,
          MediaAction.seekBackward,
        },
        androidCompactActionIndices: const [0, 1],
        processingState: processing,
        playing: playing,
      ),
    );
  }

  /// Publish (or clear) the media item shown in the notification.
  void publishMediaItem(TtsMediaInfo? info) {
    if (info == null) {
      mediaItem.add(null);
      return;
    }
    mediaItem.add(
      MediaItem(
        id: info.title,
        title: info.title,
        album: info.album,
        artist: info.artist,
        artUri: info.artUri,
        artHeaders: info.artHeaders,
      ),
    );
  }

  @override
  Future<void> play() async {
    await onPlay?.call();
    // State is published by the controller once it actually starts speaking.
  }

  @override
  Future<void> pause() async {
    await onPause?.call();
  }

  @override
  Future<void> stop() async {
    await onStop?.call();
    await super.stop();
  }

  @override
  Future<void> skipToNext() async {
    await onSkipNext?.call();
  }

  @override
  Future<void> skipToPrevious() async {
    await onSkipPrevious?.call();
  }

  void _publishState() {
    final current = playbackState.value;
    publishState(playing: current.playing, processing: current.processingState);
  }
}
