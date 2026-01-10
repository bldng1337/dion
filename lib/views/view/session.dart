import 'dart:math';

import 'package:dionysos/data/activity/episode.dart';
import 'package:dionysos/data/source.dart';
import 'package:dionysos/service/database.dart';
import 'package:dionysos/utils/observer.dart';
import 'package:dionysos/utils/service.dart';
import 'package:flutter/widgets.dart';
import 'package:uuid/uuid.dart';

class SessionData extends InheritedWidget {
  final EpisodeActivity session;

  const SessionData({super.key, required this.session, required super.child});

  static SessionData? of(BuildContext context) {
    return context.dependOnInheritedWidgetOfExactType<SessionData>();
  }

  @override
  bool updateShouldNotify(covariant SessionData oldWidget) {
    return session != oldWidget.session;
  }
}

class Session extends StatefulWidget {
  final SourceSupplier source;
  final Widget child;
  const Session({super.key, required this.source, required this.child});

  @override
  _SessionState createState() => _SessionState();
}

class _SessionState extends State<Session> {
  late EpisodeActivity session;
  late Observer sourceObserver;

  @override
  void initState() {
    super.initState();
    session = EpisodeActivity(
      entry: widget.source.episode.entry,
      extensionid: widget.source.episode.entry.boundExtensionId,
      fromepisode: widget.source.episode.episodenumber,
      toepisode: widget.source.episode.episodenumber,
      time: DateTime.now(),
      id: const Uuid().v4(),
    );
    sourceObserver = Observer(() {
      setState(() {
        final db = locate<Database>();
        final ep = widget.source.episode;
        session = session.copyWith(
          toepisode: max(ep.episodenumber, session.toepisode),
          fromepisode: min(ep.episodenumber, session.fromepisode),
          duration: DateTime.now().difference(session.time),
        );
        db.addActivity(session);
      });
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
    final db = locate<Database>();
    final ep = widget.source.episode;
    session = session.copyWith(
      toepisode: max(ep.episodenumber, session.toepisode),
      fromepisode: min(ep.episodenumber, session.fromepisode),
      duration: DateTime.now().difference(session.time),
    );
    db.addActivity(session);
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return SessionData(session: session, child: widget.child);
  }
}
