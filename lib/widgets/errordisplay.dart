import 'package:awesome_extensions/awesome_extensions.dart';
import 'package:dionysos/utils/log.dart';
import 'package:dionysos/utils/result.dart';
import 'package:dionysos/widgets/buttons/textbutton.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

class UnwrapResultBuilder<T> extends StatelessWidget {
  final Result<T> res;
  final Widget Function(T) onSuccess;
  const UnwrapResultBuilder(
      {super.key, required this.res, required this.onSuccess});

  @override
  Widget build(BuildContext context) {
    if (res.isError) {
      return ErrorDisplay(e: res.error!, s: res.trace);
    }

    // ignore: null_check_on_nullable_type_parameter
    return onSuccess(res.value!);
  }
}

class ErrorBoundary extends StatelessWidget {
  final Object? e;
  final StackTrace? s;
  final String? message;
  final Widget child;
  final List<ErrorAction>? actions;

  const ErrorBoundary({
    super.key,
    required this.e,
    this.s,
    this.message = '',
    required this.child,
    this.actions,
  });

  @override
  Widget build(BuildContext context) {
    if (e != null) {
      return ErrorDisplay(
        e: e!,
        s: s,
        message: message,
        actions: actions,
      );
    }
    return child;
  }
}

class ErrorAction {
  final String label;
  final Function()? onTap;
  const ErrorAction({required this.label, this.onTap});
}

class ErrorDisplay extends StatelessWidget {
  final Object e;
  final StackTrace? s;
  final String? message;
  final List<ErrorAction>? actions;
  const ErrorDisplay({
    super.key,
    required this.e,
    this.s,
    this.message = '',
    this.actions,
  });

  @override
  Widget build(BuildContext context) {
    logger.e(message, error: e, stackTrace: s);
    final trace = s ?? StackTrace.current;
    return ColoredBox(
      color: Colors.black.withOpacity(0.4),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              const Icon(
                Icons.report_problem,
                color: Colors.red,
              ).paddingAll(5),
              Text(
                e.toString(),
                style: context.bodyMedium,
                softWrap: true,
              ).expanded(),
            ],
          ).paddingAll(5).expanded(),
          Text(
            trace.toString(),
            style: context.bodySmall,
            overflow: TextOverflow.clip,
            softWrap: false,
          ).paddingOnly(left: 30).expanded(),
          if (actions != null)
            Row(
              children: [
                for (final action in actions!)
                  DionTextbutton(
                    onPressed: action.onTap,
                    child: Text(action.label),
                  ),
              ],
            ),
        ],
      ).paddingAll(10),
    ).onLongPress(() {
      showDialog(
        context: context,
        builder: (context) => AlertDialog(
          title: Text(e.toString()),
          content: Text(trace.toString()),
          actions: [
            TextButton(
              onPressed: () => context.pop(),
              child: const Text('Ok'),
            ),
            TextButton(
              child: const Text('Copy Error'),
              onPressed: () {
                Clipboard.setData(ClipboardData(text: '$e\n\n$trace'))
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
