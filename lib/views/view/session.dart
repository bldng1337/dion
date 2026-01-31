import 'dart:math';

import 'package:dionysos/data/activity/episode.dart';
import 'package:dionysos/data/source.dart';
import 'package:dionysos/service/database.dart';
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

  void keepSessionAlive();
}

class _SessionState extends State<Session> implements SessionManager {
  @override
  EpisodeActivity get session => sessionNotifier.value;
  @override
  late ValueNotifier<EpisodeActivity> sessionNotifier;
  late Observer sourceObserver;
  DateTime lastKeepAlive = DateTime.now();

  @override
  void keepSessionAlive({bool saveToDb = false}) {
    if (DateTime.now().difference(lastKeepAlive) <
        const Duration(milliseconds: 500)) {
      return;
    }
    updateSession(saveToDb: saveToDb);
    lastKeepAlive = DateTime.now();
  }

  Future<void> updateSession({bool saveToDb = false}) async {
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
    if (!saveToDb) return;
    await db.addActivity(session);
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
    sourceObserver = Observer(() {
      keepSessionAlive(saveToDb: true);
    }, widget.source);
  }

  @override
  void didUpdateWidget(covariant Session oldWidget) {
    super.didUpdateWidget(oldWidget);
    //TODO: If the source supplier changes we might want to start a new session?
    sourceObserver.swapListener(widget.source);
  }

  @override
  void dispose() {
    updateSession(saveToDb: true);
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return SessionData(manager: this, child: widget.child);
  }
}
