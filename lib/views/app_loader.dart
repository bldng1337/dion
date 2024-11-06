import 'package:awesome_extensions/awesome_extensions.dart';
import 'package:dionysos/utils/log.dart';
import 'package:flutter/material.dart';
import 'package:flutter_platform_widgets/flutter_platform_widgets.dart';

class AppLoader extends StatefulWidget {
  final List<Future<void> Function(BuildContext context)> tasks;
  final Function(BuildContext context) onComplete;
  const AppLoader({required this.tasks, required this.onComplete, super.key});

  @override
  _AppLoaderState createState() => _AppLoaderState();
}

class _AppLoaderState extends State<AppLoader> {
  int currentTask = 0;
  @override
  Widget build(BuildContext context) {
    logger.i('AppLoader');
    return PlatformScaffold(
      body: StreamBuilder(
        stream: Stream.fromFutures(
          widget.tasks.map(
            (task) async {
              await Future.delayed(1000.milliseconds);
              await task(context);
            },
          ).toList(),
        ).asBroadcastStream(),
        builder: (context, snapshot) {
          return snapshot.when(
            data: (data, isComplete) {
              currentTask++;
              if (isComplete) {
                // if(currentTask != widget.tasks.length){
                //   throw Exception('Illegal State: Not all initial tasks are completed ($currentTask/${widget.tasks.length})');
                // }
                widget.onComplete(context);
                return const Center(child: CircularProgressIndicator());
              }
              return Center(
                  child: CircularProgressIndicator(
                value: (currentTask / widget.tasks.length).clamp(0, 1),
              ),);
            },
            error: (error, stackTrace) {
              logger.e('Error Loading App',error: error, stackTrace: stackTrace);
              return const Center(child: Text('We have an error'));
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
