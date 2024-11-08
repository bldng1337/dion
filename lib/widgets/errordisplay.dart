import 'package:awesome_extensions/awesome_extensions.dart';
import 'package:dionysos/utils/log.dart';
import 'package:flutter/material.dart';

class ErrorDisplay extends StatelessWidget {
  final Object e;
  final StackTrace? s;
  final String? message;
  const ErrorDisplay({super.key, required this.e, this.s, this.message=''});

  @override
  Widget build(BuildContext context) {
    logger.e(message,error: e,stackTrace: s);
    if(e is! Error){
      return nil;
    }
    final error=e as Error;
    final trace=s??error.stackTrace??StackTrace.current;
    return LayoutBuilder(
      builder: (context, constraints) => Container(
        constraints: constraints,
        color: Colors.black.withOpacity(0.4),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Row(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                const Icon(Icons.report_problem,color: Colors.red,).paddingAll(5),
                Text(error.toString()),
              ],
            ),
            if(constraints.maxWidth>700&&constraints.maxHeight>500)
              Text(trace.toString()),
          ],
        ).paddingAll(5),
      ),
    );
  }
}
