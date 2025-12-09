import 'package:dionysos/data/source.dart';
import 'package:dionysos/utils/async.dart';
import 'package:dionysos/widgets/errordisplay.dart';
import 'package:dionysos/widgets/progress.dart';
import 'package:dionysos/widgets/scaffold.dart';
import 'package:flutter/widgets.dart';
import 'package:inline_result/inline_result.dart';

class SourceWrapper extends StatelessWidget {
  final SourceSupplier source;
  final Widget Function(BuildContext context, SourcePath source) builder;
  final Widget Function(BuildContext context, Object error)? errorBuilder;
  final Widget Function(BuildContext context)? loadingBuilder;

  const SourceWrapper({
    super.key,
    required this.source,
    required this.builder,
    this.errorBuilder,
    this.loadingBuilder,
  });

  @override
  Widget build(BuildContext context) {
    return ListenableBuilder(
      listenable: source,
      builder: (context, child) => LoadingBuilder(
        future: source.sourceFuture,
        builder: (context, item) {
          if (item.isFailure) {
            return errorBuilder?.call(context, item.getOrThrow) ??
                NavScaff(
                  title: const Text('Error'),
                  child: ErrorDisplay(
                    e: item.exceptionOrNull,
                    message: 'Error loading source',
                  ),
                );
          }
          return builder(context, item.getOrThrow);
        },
        error: (context, error, stackTrace) =>
            errorBuilder?.call(context, error) ??
            NavScaff(
              title: const Text('Error'),
              child: ErrorDisplay(
                e: error,
                s: stackTrace,
                message: 'Error loading source',
              ),
            ),
        loading: (context) =>
            loadingBuilder?.call(context) ??
            const NavScaff(title: Text('Loading...'), child: DionProgressBar()),
      ),
    );
  }
}
