import 'dart:async';

import 'package:awesome_extensions/awesome_extensions.dart';
import 'package:dionysos/utils/log.dart';
import 'package:dionysos/widgets/buttons/clickable.dart';
import 'package:dionysos/widgets/buttons/textbutton.dart';
import 'package:dionysos/widgets/container/container.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:inline_result/inline_result.dart';
import 'package:dionysos/widgets/dialog.dart';

class UnwrapResultBuilder<T> extends StatelessWidget {
  final Result<T> res;
  final Widget Function(T) onSuccess;
  const UnwrapResultBuilder({
    super.key,
    required this.res,
    required this.onSuccess,
  });

  @override
  Widget build(BuildContext context) {
    return res.fold(
      onSuccess: onSuccess,
      onFailure: (e, s) => ErrorDisplay(e: e, s: s),
    );
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
      return ErrorDisplay(e: e, s: s, message: message, actions: actions);
    }
    return child;
  }
}

class ErrorAction {
  final String label;
  final FutureOr<void> Function()? onTap;
  const ErrorAction({required this.label, this.onTap});
}

class ErrorDisplay extends StatelessWidget {
  final Object? e;
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

  String getErrorMessage() {
    final msg = e.toString().trim();
    if (msg.isEmpty) {
      return 'Unknown Error';
    }
    return msg;
  }

  void _showErrorPopup(BuildContext context) {
    showDialog(
      context: context,
      builder: (context) => DionDialog(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            SingleChildScrollView(
              child: Column(
                children: [
                  Row(
                    children: [
                      Icon(
                        Icons.report_problem,
                        color: context.theme.colorScheme.error,
                        size: 20,
                      ).paddingOnly(right: 8),
                      Expanded(
                        child: Text(
                          getErrorMessage(),
                          style: context.titleMedium,
                        ),
                      ),
                    ],
                  ).paddingOnly(bottom: 12),
                  if (s != null)
                    Text(
                      s!.toString(),
                      style: context.bodySmall?.copyWith(
                        color: context.theme.colorScheme.onSurface.withValues(
                          alpha: 0.7,
                        ),
                      ),
                    ).paddingOnly(bottom: 12),
                ],
              ),
            ).paddingOnly(bottom: 12).expanded(),
            Row(
              mainAxisAlignment: MainAxisAlignment.end,
              children: [
                DionTextbutton(
                  type: ButtonType.ghost,
                  onPressed: () => context.pop(),
                  child: const Text('Ok'),
                ).paddingOnly(right: 8),
                DionTextbutton(
                  child: const Text('Copy Error'),
                  onPressed: () {
                    Clipboard.setData(ClipboardData(text: '$e\n\n$s')).then((
                      a,
                    ) {
                      if (context.mounted) {
                        context.pop();
                      }
                    });
                  },
                ).paddingOnly(right: 8),
                ...?actions?.map(
                  (action) => DionTextbutton(
                    onPressed: action.onTap,
                    child: Text(action.label),
                  ),
                ),
              ],
            ),
          ],
        ).paddingAll(16),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    if (e == null) {
      return Container();
    }
    logger.e(message, error: e, stackTrace: s);

    return LayoutBuilder(
      builder: (context, constraints) {
        final maxWidth = constraints.maxWidth;
        final maxHeight = constraints.maxHeight;
        final minDimension = maxWidth < maxHeight ? maxWidth : maxHeight;

        if (minDimension <= 60) {
          return Clickable(
            onLongTap: () => _showErrorPopup(context),
            child: DionContainer(
              type: ContainerType.filled,
              color: context.theme.colorScheme.error.withValues(alpha: 0.1),
              borderColor: context.theme.colorScheme.error,
              child: Icon(
                Icons.report_problem,
                color: context.theme.colorScheme.error,
                size: minDimension * 0.5,
              ),
            ),
          );
        }

        if (minDimension <= 150 || maxHeight <= 80) {
          return Clickable(
            onLongTap: () => _showErrorPopup(context),
            child: DionContainer(
              type: ContainerType.filled,
              color: context.theme.colorScheme.error.withValues(alpha: 0.1),
              borderColor: context.theme.colorScheme.error,
              child: Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Icon(
                    Icons.report_problem,
                    color: context.theme.colorScheme.error,
                    size: 20,
                  ).paddingOnly(right: 6),
                  Flexible(
                    child: Text(
                      getErrorMessage(),
                      style: context.bodyMedium,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                    ),
                  ),
                ],
              ).paddingSymmetric(horizontal: 8, vertical: 6),
            ),
          );
        }

        return Clickable(
          onLongTap: () => _showErrorPopup(context),
          child: DionContainer(
            type: ContainerType.filled,
            color: context.theme.colorScheme.error.withValues(alpha: 0.1),
            borderColor: context.theme.colorScheme.error,
            child: ConstrainedBox(
              constraints: BoxConstraints(
                minWidth: 30,
                minHeight: 30,
                maxWidth: maxWidth,
                maxHeight: maxHeight,
              ),
              child: SingleChildScrollView(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Row(
                      mainAxisSize: MainAxisSize.min,
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Icon(
                          Icons.report_problem,
                          color: context.theme.colorScheme.error,
                          size: 20,
                        ).paddingOnly(right: 8),
                        Flexible(
                          child: Text(
                            getErrorMessage(),
                            style: context.bodyLarge,
                            softWrap: true,
                          ),
                        ),
                      ],
                    ).paddingSymmetric(horizontal: 8, vertical: 6),
                    if (s != null && maxHeight > 120)
                      Padding(
                        padding: const EdgeInsets.only(
                          left: 36,
                          right: 8,
                          bottom: 6,
                        ),
                        child: Text(
                          s!.toString(),
                          style: context.bodySmall?.copyWith(
                            color: context.theme.colorScheme.onSurface
                                .withValues(alpha: 0.7),
                          ),
                          maxLines: maxHeight > 200 ? null : 3,
                          overflow: maxHeight > 200
                              ? TextOverflow.clip
                              : TextOverflow.ellipsis,
                        ),
                      ),
                    if (actions != null)
                      Padding(
                        padding: const EdgeInsets.symmetric(horizontal: 8),
                        child: Wrap(
                          spacing: 8,
                          runSpacing: 4,
                          children: [
                            for (final action in actions!)
                              DionTextbutton(
                                onPressed: action.onTap,
                                child: Text(action.label),
                              ),
                          ],
                        ).paddingOnly(bottom: 6),
                      ),
                  ],
                ),
              ),
            ),
          ),
        );
      },
    );
  }
}
