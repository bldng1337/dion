import 'dart:async';

import 'package:audio_service/audio_service.dart';
import 'package:dionysos/data/source.dart';
import 'package:dionysos/utils/service.dart';
import 'package:flutter_dispose_scope/flutter_dispose_scope.dart';
import 'package:media_kit/media_kit.dart';

class PlayerService {
  late SwitchAudioHandler _audioHandler;

  static Future<void> ensureInitialized() async {
    final self = PlayerService();
    self._audioHandler = await AudioService.init(
      builder: () => SwitchAudioHandler(),
      config: const AudioServiceConfig(
        androidNotificationChannelId: 'me.bldng.dionysos.audio.channel',
        androidNotificationChannelName: 'Audio playback',
        androidNotificationOngoing: true,
      ),
    );

    register<PlayerService>(self);
  }

  AudioHandler get currentSession => _audioHandler.inner;

  Future<void> setSession(FutureOr<AudioHandler> handler) async {
    _audioHandler.inner = await handler;
  }

  Future<void> clearSession() async {
    _audioHandler.inner = BaseAudioHandler();
  }
}

//Windows.Media.SystemMediaTransportControls
//C++/WinRT
class AudioPlayerHandler extends BaseAudioHandler implements Disposable {
  final SourceSupplier source;
  final Function()? gonext;
  final Function()? goprev;
  final Player player;

  /// Stream subscriptions created in [_init]; cancelled in [dispose].
  final List<StreamSubscription> _streamSubs = [];

  EpisodePath get eppath => source.episode;

  AudioPlayerHandler._(this.source, this.player, {this.gonext, this.goprev});

  static Future<AudioPlayerHandler> create(
    SourceSupplier source,
    Player player, {
    Function()? gonext,
    Function()? goprev,
  }) async {
    final handler = AudioPlayerHandler._(
      source,
      player,
      gonext: gonext,
      goprev: goprev,
    );
    await handler._init();
    return handler;
  }

  @override
  void disposedBy(DisposeScope disposeScope) {
    disposeScope.addDispose(dispose);
  }

  @override
  Future<void> dispose() async {
    for (final sub in _streamSubs) {
      await sub.cancel();
    }
    _streamSubs.clear();
    source.removeListener(_publishMediaFromSource);
    final player = locate<PlayerService>();
    if (this != player.currentSession) {
      return;
    }
    player.clearSession();
  }

  @override
  Future<void> play() {
    player.play();
    return super.play();
  }

  @override
  Future<void> pause() {
    player.pause();
    return super.pause();
  }

  @override
  Future<void> skipToNext() {
    gonext?.call();
    return super.skipToNext();
  }

  @override
  Future<void> skipToPrevious() {
    goprev?.call();
    return super.skipToPrevious();
  }

  /// Publish a [MediaItem] derived from the current [source]. Registered as a
  /// listener on [source] in [_init] and removed in [dispose].
  void _publishMediaFromSource() {
    mediaItem.add(
      MediaItem(
        id: eppath.name,
        title: eppath.name,
        album: eppath.entry.title,
        artist: eppath.entry.author?[0],
        duration: player.state.duration,
        artUri: eppath.cover != null ? Uri.tryParse(eppath.cover!.url) : null,
        artHeaders: eppath.cover != null ? eppath.entry.cover!.header : null,
        // rating: eppath.entry.rating != null
        //     ? Rating.newStarRating(
        //         RatingStyle.percentage,
        //         (eppath.entry.rating ?? 0 * 100) as int,
        //       )
        //     : null,
      ),
    );
  }

  Future<void> _init() async {
    // Update position
    var lastduration = Duration.zero;
    _streamSubs.add(player.stream.position.listen((event) {
      if ((lastduration - event).inMilliseconds < 1000) {
        return;
      }
      lastduration = event;
      playbackState.add(playbackState.value.copyWith(updatePosition: event));
    }));

    // Update buffering
    _streamSubs.add(player.stream.buffering.listen((event) {
      if (event) {
        playbackState.add(
          playbackState.value.copyWith(
            controls: [
              if (eppath.hasprev && goprev != null) MediaControl.skipToPrevious,
              MediaControl.pause,
              if (eppath.hasnext && gonext != null) MediaControl.skipToNext,
            ],
            processingState: AudioProcessingState.buffering,
          ),
        );
      } else {
        playbackState.add(
          playbackState.value.copyWith(
            controls: [
              if (eppath.hasprev && goprev != null) MediaControl.skipToPrevious,
              MediaControl.play,
              if (eppath.hasnext && gonext != null) MediaControl.skipToNext,
            ],
            processingState: AudioProcessingState.ready,
          ),
        );
      }
    }));

    // Update buffer
    _streamSubs.add(player.stream.buffer.listen((event) {
      playbackState.add(playbackState.value.copyWith(bufferedPosition: event));
    }));

    // Update playing
    _streamSubs.add(player.stream.playing.listen((event) {
      if (event) {
        playbackState.add(
          playbackState.value.copyWith(
            controls: [
              if (eppath.hasprev && goprev != null) MediaControl.skipToPrevious,
              MediaControl.pause,
              if (eppath.hasnext && gonext != null) MediaControl.skipToNext,
            ],
            playing: true,
          ),
        );
      } else {
        playbackState.add(
          playbackState.value.copyWith(
            controls: [
              if (eppath.hasprev && goprev != null) MediaControl.skipToPrevious,
              MediaControl.play,
              if (eppath.hasnext && gonext != null) MediaControl.skipToNext,
            ],
            playing: false,
          ),
        );
      }
    }));

    playbackState.add(
      playbackState.value.copyWith(
        controls: [
          if (eppath.hasprev && goprev != null) MediaControl.skipToPrevious,
          if (player.state.playing) MediaControl.pause else MediaControl.play,
          if (eppath.hasnext && gonext != null) MediaControl.skipToNext,
        ],
        processingState: player.state.buffering
            ? AudioProcessingState.buffering
            : AudioProcessingState.ready,
        playing: player.state.playing,
        bufferedPosition: player.state.buffer,
        updatePosition: player.state.position,
      ),
    );
    _streamSubs.add(player.stream.duration.listen((event) {
      mediaItem.add(mediaItem.value!.copyWith(duration: event));
    }));
    source.addListener(_publishMediaFromSource);
    mediaItem.add(
      MediaItem(
        id: eppath.name,
        title: eppath.name,
        album: eppath.entry.title,
        artist: eppath.entry.author?[0],
        duration: player.state.duration,
        artUri: eppath.cover != null ? Uri.tryParse(eppath.cover!.url) : null,
        artHeaders: eppath.cover != null ? eppath.entry.cover!.header : null,
        // rating: eppath.entry.rating != null
        //     ? Rating.newStarRating(
        //         RatingStyle.percentage,
        //         (eppath.entry.rating ?? 0 * 100) as int,
        //       )
        //     : null,
      ),
    );
  }
}
