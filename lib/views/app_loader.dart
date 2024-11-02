import 'package:awesome_extensions/awesome_extensions.dart';
import 'package:flutter/material.dart';
import 'package:flutter_extended_platform_widgets/flutter_extended_platform_widgets.dart';

class LoadTask {
  final Future<void> Function(BuildContext context) task;
  final String name;
  LoadTask(this.task, this.name);
}

class AppLoader extends StatefulWidget {
  final List<LoadTask> tasks;
  final Function(BuildContext context) onComplete;
  const AppLoader({required this.tasks, required this.onComplete, super.key});

  @override
  _AppLoaderState createState() => _AppLoaderState();
}

class _AppLoaderState extends State<AppLoader> {
  @override
  Widget build(BuildContext context) {
    return PlatformTabScaffold(
      bodyBuilder: (context, index) => StreamBuilder(
        stream: Stream.fromFutures(
          widget.tasks.indexed.map(
            (e) async {
              await e.$2.task(context);
              return e.$1;
            },
          ),
        ),
        builder: (context, snapshot) {
          return snapshot.when(
            data: (data, isComplete) {
              if (isComplete) {
                widget.onComplete(context);
                return nil;
              }
              return CircularProgressIndicator(
                value: (data / widget.tasks.length).clamp(0, 1),
              );
            },
            error: (error, stackTrace) {
              return Text('We have an error');
            },
            loading: () {
              return const CircularProgressIndicator();
            },
          );
        },
      ),
    );
  }
}
