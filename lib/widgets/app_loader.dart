import 'package:awesome_extensions/awesome_extensions.dart';
import 'package:dionysos/widgets/errordisplay.dart';
import 'package:dionysos/widgets/scaffold.dart';
import 'package:flutter/material.dart';

class AppLoader extends StatefulWidget {
  final List<(String, Future<void> Function())> tasks;
  final Function(BuildContext context) onComplete;
  final List<ErrorAction>? actions;
  const AppLoader({
    required this.tasks,
    required this.onComplete,
    super.key,
    this.actions,
  });

  @override
  _AppLoaderState createState() => _AppLoaderState();
}

class _AppLoaderState extends State<AppLoader> {
  List<String> tasknames = [];
  Object? error;
  StackTrace? stack;
  Future<void> doTask(String name, Future<void> Function() task) async {
    try {
      tasknames.add(name);
      await task();
    } catch (e, cstack) {
      if (error != null) {
        return;
      }
      setState(() {
        error = e;
        stack = cstack;
      });
    }
    setState(() {
      tasknames.remove(name);
    });
    if (tasknames.isEmpty && mounted && error == null) {
      widget.onComplete(context);
    }
  }

  @override
  void initState() {
    for (final task in widget.tasks) {
      doTask(task.$1, task.$2);
    }
    super.initState();
  }

  @override
  Widget build(BuildContext context) {
    if (error != null) {
      return NavScaff(
        child: Center(
          child: ErrorDisplay(e: error, s: stack, actions: widget.actions),
        ),
      );
    }
    return NavScaff(
      child: Center(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            CircularProgressIndicator(
              value: 1 - (tasknames.length / widget.tasks.length),
            ),
            if (tasknames.isNotEmpty)
              Text(
                'Loading ${tasknames.firstOrNull}',
                style: context.bodyLarge,
              ).paddingAll(10),
          ],
        ),
      ),
    );
  }
}
