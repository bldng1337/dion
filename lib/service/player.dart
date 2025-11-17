import 'package:audio_service/audio_service.dart';
import 'package:dionysos/data/source.dart';
import 'package:dionysos/utils/service.dart';
import 'package:flutter_dispose_scope/flutter_dispose_scope.dart';
import 'package:media_kit/media_kit.dart';

class PlayerService {
  late AudioHandler _audioHandler;

  static Future<void> ensureInitialized() async {
    final self = PlayerService();
    self._audioHandler = await AudioService.init(
      builder: () => AudioPlayerHandler(),
      config: const AudioServiceConfig(
        androidNotificationChannelId: 'me.bldng.dionysos.audio.channel',
        androidNotificationChannelName: 'Audio playback',
        androidNotificationOngoing: true,
      ),
    );

    register<PlayerService>(self);
  }

  Future<void> setSession(PlaySession session) async {
    await _audioHandler.customAction('setSession', {'session': session});
  }

  Future<void> disposeSession(PlaySession session) async {
    await _audioHandler.customAction('invalidateSession', {'session': session});
  }
}

//Windows.Media.SystemMediaTransportControls
//C++/WinRT
class AudioPlayerHandler extends BaseAudioHandler {
  PlaySession? _session;

  @override
  AudioPlayerHandler();
  @override
  Future<void> play() {
    if (_session != null) {
      _session!.player.play();
    }
    return super.play();
  }

  @override
  Future<void> pause() {
    if (_session != null) {
      _session!.player.pause();
    }
    return super.pause();
  }

  @override
  Future<void> skipToNext() {
    if (_session != null) {
      _session!.gonext?.call();
    }
    return super.skipToNext();
  }

  @override
  Future<void> skipToPrevious() {
    if (_session != null) {
      _session!.goprev?.call();
    }
    return super.skipToPrevious();
  }

  Future<void> setSession(PlaySession session) async {
    // Update position
    var lastduration = Duration.zero;
    session.player.stream.position.listen((event) {
      if ((lastduration - event).inMilliseconds < 1000) {
        return;
      }
      lastduration = event;
      playbackState.add(playbackState.value.copyWith(updatePosition: event));
    });

    // Update buffering
    session.player.stream.buffering.listen((event) {
      if (event) {
        playbackState.add(
          playbackState.value.copyWith(
            controls: [
              if (session.eppath.hasprev && session.goprev != null)
                MediaControl.skipToPrevious,
              MediaControl.pause,
              if (session.eppath.hasnext && session.gonext != null)
                MediaControl.skipToNext,
            ],
            processingState: AudioProcessingState.buffering,
          ),
        );
      } else {
        playbackState.add(
          playbackState.value.copyWith(
            controls: [
              if (session.eppath.hasprev && session.goprev != null)
                MediaControl.skipToPrevious,
              MediaControl.play,
              if (session.eppath.hasnext && session.gonext != null)
                MediaControl.skipToNext,
            ],
            processingState: AudioProcessingState.ready,
          ),
        );
      }
    });

    // Update buffer
    session.player.stream.buffer.listen((event) {
      playbackState.add(playbackState.value.copyWith(bufferedPosition: event));
    });

    // Update playing
    session.player.stream.playing.listen((event) {
      if (event) {
        playbackState.add(
          playbackState.value.copyWith(
            controls: [
              if (session.eppath.hasprev && session.goprev != null)
                MediaControl.skipToPrevious,
              MediaControl.pause,
              if (session.eppath.hasnext && session.gonext != null)
                MediaControl.skipToNext,
            ],
            playing: true,
          ),
        );
      } else {
        playbackState.add(
          playbackState.value.copyWith(
            controls: [
              if (session.eppath.hasprev && session.goprev != null)
                MediaControl.skipToPrevious,
              MediaControl.play,
              if (session.eppath.hasnext && session.gonext != null)
                MediaControl.skipToNext,
            ],
            playing: false,
          ),
        );
      }
    });

    playbackState.add(
      playbackState.value.copyWith(
        controls: [
          if (session.eppath.hasprev && session.goprev != null)
            MediaControl.skipToPrevious,
          if (session.player.state.playing)
            MediaControl.pause
          else
            MediaControl.play,
          if (session.eppath.hasnext && session.gonext != null)
            MediaControl.skipToNext,
        ],
        processingState: session.player.state.buffering
            ? AudioProcessingState.buffering
            : AudioProcessingState.ready,
        playing: session.player.state.playing,
        bufferedPosition: session.player.state.buffer,
        updatePosition: session.player.state.position,
      ),
    );
    session.player.stream.duration.listen((event) {
      mediaItem.add(mediaItem.value!.copyWith(duration: event));
    });
    session.source.addListener(() {
      mediaItem.add(
        MediaItem(
          id: session.eppath.name,
          title: session.eppath.name,
          album: session.eppath.entry.title,
          artist: session.eppath.entry.author?[0],
          duration: session.player.state.duration,
          artUri: session.eppath.cover != null
              ? Uri.tryParse(session.eppath.cover!.url)
              : null,
          artHeaders: session.eppath.cover != null
              ? session.eppath.entry.cover!.header
              : null,
          // rating: session.eppath.entry.rating != null
          //     ? Rating.newStarRating(
          //         RatingStyle.percentage,
          //         (session.eppath.entry.rating ?? 0 * 100) as int,
          //       )
          //     : null,
        ),
      );
    });
    mediaItem.add(
      MediaItem(
        id: session.eppath.name,
        title: session.eppath.name,
        album: session.eppath.entry.title,
        artist: session.eppath.entry.author?[0],
        duration: session.player.state.duration,
        artUri: session.eppath.cover != null
            ? Uri.tryParse(session.eppath.cover!.url)
            : null,
        artHeaders: session.eppath.cover != null
            ? session.eppath.entry.cover!.header
            : null,
        // rating: session.eppath.entry.rating != null
        //     ? Rating.newStarRating(
        //         RatingStyle.percentage,
        //         (session.eppath.entry.rating ?? 0 * 100) as int,
        //       )
        //     : null,
      ),
    );
    _session = session;
  }

  @override
  Future customAction(String name, [Map<String, dynamic>? extras]) async {
    switch (name) {
      case 'invalidateSession':
        final session = extras?['session'] as PlaySession?;
        if (session == null) {
          return;
        }
        if (_session?.eppath == session.eppath) {
          _session = null;
          playbackState.add(
            playbackState.value.copyWith(
              controls: [],
              processingState: AudioProcessingState.idle,
              playing: false,
            ),
          );
        }
      case 'setSession':
        final session = extras?['session'] as PlaySession?;
        if (session == null) {
          return;
        }
        setSession(session);
    }
    return super.customAction(name, extras);
  }
}

class PlaySession implements Disposable {
  final SourceSupplier source;
  final Function()? gonext;
  final Function()? goprev;
  final Player player;

  EpisodePath get eppath => source.episode;

  PlaySession(this.source, this.player, {this.gonext, this.goprev});

  @override
  void disposedBy(DisposeScope disposeScope) {
    disposeScope.addDispose(dispose);
  }

  @override
  Future<void> dispose() async {
    locate<PlayerService>().disposeSession(this);
  }
}
