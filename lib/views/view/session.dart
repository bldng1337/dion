import 'dart:math';

import 'package:dionysos/data/activity/episode.dart';
import 'package:dionysos/data/source.dart';
import 'package:dionysos/service/database.dart';
import 'package:dionysos/utils/debounce.dart';
import 'package:dionysos/utils/observer.dart';
import 'package:dionysos/utils/service.dart';
import 'package:flutter/widgets.dart';
import 'package:uuid/uuid.dart';

class SessionData extends InheritedWidget {
  final SessionManager manager;

  const SessionData({super.key, required this.manager, required super.child});

  static SessionData? of(BuildContext context) {
    return context.dependOnInheritedWidgetOfExactType<SessionData>();
  }

  @override
  bool updateShouldNotify(covariant SessionData oldWidget) {
    return manager != oldWidget.manager;
  }
}

class Session extends StatefulWidget {
  final SourceSupplier source;
  final Widget child;
  const Session({super.key, required this.source, required this.child});

  @override
  _SessionState createState() => _SessionState();
}

abstract class SessionManager {
  EpisodeActivity get session;
  ValueNotifier<EpisodeActivity> get sessionNotifier;

  void keepSessionAlive({bool saveToDb = false});
}

class _SessionState extends State<Session> implements SessionManager {
  @override
  EpisodeActivity get session => sessionNotifier.value;
  @override
  late ValueNotifier<EpisodeActivity> sessionNotifier;
  late Observer sourceObserver;
  DateTime lastKeepAlive = DateTime.now();
  late final Debouncer saveDebouncer = Debouncer(
    duration: const Duration(milliseconds: 750),
    action: saveSession,
  );

  @override
  void keepSessionAlive({bool saveToDb = false}) {
    if (saveToDb) {
      // Debounced so rapid actions (e.g. spamming play/pause or seeking) only hit the database once, after the last action.
      saveDebouncer.run();
    }
    if (DateTime.now().difference(lastKeepAlive) <
        const Duration(milliseconds: 1000)) {
      return;
    }
    updateSession();
    lastKeepAlive = DateTime.now();
  }

  Future<void> saveSession() async {
    final db = locate<Database>();
    await db.addActivity(session);
    await widget.source.episode.save();
  }

  Future<void> updateSession() async {
    final db = locate<Database>();
    if (DateTime.now().difference(lastKeepAlive) > const Duration(minutes: 1)) {
      await db.addActivity(session);
      sessionNotifier.value = EpisodeActivity(
        entry: widget.source.episode.entry,
        extensionid: widget.source.episode.entry.boundExtensionId,
        fromepisode: widget.source.episode.episodenumber,
        toepisode: widget.source.episode.episodenumber,
        time: DateTime.now(),
        id: const Uuid().v4(),
      );
      lastKeepAlive = DateTime.now();
      await db.addActivity(session);
      return;
    }
    final ep = widget.source.episode;
    sessionNotifier.value = session.copyWith(
      toepisode: max(ep.episodenumber, session.toepisode),
      fromepisode: min(ep.episodenumber, session.fromepisode),
      duration: DateTime.now().difference(session.time),
    );
  }

  @override
  void initState() {
    super.initState();
    sessionNotifier = ValueNotifier<EpisodeActivity>(
      EpisodeActivity(
        entry: widget.source.episode.entry,
        extensionid: widget.source.episode.entry.boundExtensionId,
        fromepisode: widget.source.episode.episodenumber,
        toepisode: widget.source.episode.episodenumber,
        time: DateTime.now(),
        id: const Uuid().v4(),
      ),
    );
    sourceObserver = Observer(
      () {
        keepSessionAlive(saveToDb: true);
      },
      widget.source,
      callIndirectly: false,
    );
  }

  @override
  void didUpdateWidget(covariant Session oldWidget) {
    super.didUpdateWidget(oldWidget);
    //TODO: If the source supplier changes we might want to start a new session?
    sourceObserver.swapListener(widget.source);
  }

  @override
  void dispose() {
    // Cancel any debounced save and persist immediately on teardown.
    saveDebouncer.dispose();
    updateSession();
    saveSession();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return SessionData(manager: this, child: widget.child);
  }
}
