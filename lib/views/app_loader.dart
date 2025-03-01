import 'package:awesome_extensions/awesome_extensions.dart';
import 'package:dionysos/utils/log.dart';
import 'package:dionysos/widgets/errordisplay.dart';
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
  late List<Future> tasks;
  late Stream<void> stream;
  Object? error;
  @override
  void initState() {
    tasks = widget.tasks.map(
      (task) async {
        try {
          await task();
        } catch (e) {
          if (error != null) {
            return;
          }
          error = e;
        }
      },
    ).toList();
    stream = Stream.fromFutures(tasks).asBroadcastStream();

    super.initState();
  }

  @override
  Widget build(BuildContext context) {
    int currentTask = 0;
    return NavScaff(
      child: StreamBuilder(
        stream: stream,
        builder: (context, snapshot) {
          currentTask++;
          if (error != null) {
            return Center(child: ErrorDisplay(e: error!));
          }
          return snapshot.when(
            data: (data, isComplete) {
              if (isComplete && error == null) {
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
              return Center(child: ErrorDisplay(e: error));
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
