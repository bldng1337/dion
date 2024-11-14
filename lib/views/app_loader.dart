import 'package:awesome_extensions/awesome_extensions.dart';
import 'package:dionysos/utils/log.dart';
import 'package:dionysos/widgets/scaffold.dart';
import 'package:flutter/material.dart';

class AppLoader extends StatefulWidget {
  final List<Future<void> Function()> tasks;
  final Function(BuildContext context) onComplete;
  const AppLoader({required this.tasks, required this.onComplete, super.key});

  @override
  _AppLoaderState createState() => _AppLoaderState();
}

class _AppLoaderState extends State<AppLoader> {
  Error? e;
  int currentTask = 0;
  @override
  Widget build(BuildContext context) {
    return NavScaff(
      child: StreamBuilder(
        stream: Stream.fromFutures(
          widget.tasks.map(
            (task) async {
              await task();
            },
          ).toList(),
        ).asBroadcastStream(),
        builder: (context, snapshot) {
          if (e != null) {
            return Center(child: Text(e.toString()));
          }
          return snapshot.when(
            data: (data, isComplete) {
              currentTask++;
              if (isComplete) {
                widget.onComplete(context);
                return const Center(child: CircularProgressIndicator());
              }
              return Center(
                child: CircularProgressIndicator(
                  value: (currentTask / widget.tasks.length).clamp(0, 1),
                ),
              );
            },
            error: (error, stackTrace) {
              e = error as Error?;
              logger.e('Error Loading App',
                  error: error, stackTrace: stackTrace);
              return Center(child: Text(e.toString()));
            },
            loading: () {
              return const Center(child: CircularProgressIndicator());
            },
          );
        },
      ),
    );
  }
}
