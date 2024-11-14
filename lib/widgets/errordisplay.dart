import 'package:awesome_extensions/awesome_extensions.dart';
import 'package:dionysos/utils/log.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

class ErrorDisplay extends StatelessWidget {
  final Object e;
  final StackTrace? s;
  final String? message;
  const ErrorDisplay({super.key, required this.e, this.s, this.message = ''});

  @override
  Widget build(BuildContext context) {
    logger.e(message, error: e, stackTrace: s);
    if (e is! Exception) {
      return nil;
    }
    final error = e as Exception;
    final trace = s ?? StackTrace.current;
    return ColoredBox(
      color: Colors.black.withOpacity(0.4),
      child: Column(
        children: [
          Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              const Icon(
                Icons.report_problem,
                color: Colors.red,
              ).paddingAll(5),
              Text(
                error.toString().split('\n').first,
                style: context.bodyMedium,
                softWrap: true,
              ).expanded(),
            ],
          ).paddingAll(5),
          Text(
            trace.toString(),
            style: context.bodySmall,
            overflow: TextOverflow.clip,
            softWrap: false,
          ).expanded(),
        ],
      ).paddingAll(10),
    ).onLongPress(() {
      showDialog(
        context: context,
        builder: (context) => AlertDialog(
          title: Text(error.toString().split('\n').first),
          content: Text(trace.toString()),
          actions: [
            TextButton(
              onPressed: () => context.pop(),
              child: const Text('Ok'),
            ),
            TextButton(
              child: const Text('Copy Error'),
              onPressed: () {
                Clipboard.setData(ClipboardData(text: '$error\n\n$trace'))
                    .then((a) {
                  if (context.mounted) {
                    context.pop();
                  }
                });
              },
            ),
          ],
        ),
      );
    });
  }
}
