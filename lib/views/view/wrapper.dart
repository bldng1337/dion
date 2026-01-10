import 'package:dionysos/data/source.dart';
import 'package:dionysos/utils/async.dart';
import 'package:dionysos/utils/observer.dart';
import 'package:dionysos/widgets/errordisplay.dart';
import 'package:dionysos/widgets/progress.dart';
import 'package:dionysos/widgets/scaffold.dart';
import 'package:flutter/widgets.dart';
import 'package:flutter_dispose_scope/flutter_dispose_scope.dart';
import 'package:inline_result/inline_result.dart';

class SourceWrapper extends StatefulWidget {
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
  State<SourceWrapper> createState() => _SourceWrapperState();
}

class _SourceWrapperState extends State<SourceWrapper>
    with StateDisposeScopeMixin {
  Future<Result<SourcePath>>? _cachedFuture;
  late final Observer _sourceObserver;

  @override
  void initState() {
    super.initState();
    _updateFuture();
    _sourceObserver = Observer(
      _onSourceChanged,
      widget.source,
      callOnInit: false,
    )..disposedBy(scope);
  }

  @override
  void didUpdateWidget(SourceWrapper oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.source != widget.source) {
      _sourceObserver.swapListener(widget.source);
      _updateFuture();
    }
  }

  void _onSourceChanged() {
    _updateFuture();
    if (mounted) {
      setState(() {});
    }
  }

  void _updateFuture() {
    // Check if we already have a cached result synchronously
    final cachedResult = widget.source.sourceResult;
    if (cachedResult != null) {
      // Use a completed future with the cached result
      _cachedFuture = Future.value(cachedResult);
    } else {
      // Only create a new future if we don't have cached data
      _cachedFuture = widget.source.sourceFuture;
    }
  }

  @override
  Widget build(BuildContext context) {
    // First check if we have a synchronous result available
    final syncResult = widget.source.sourceResult;
    if (syncResult != null) {
      if (syncResult.isFailure) {
        return widget.errorBuilder?.call(
              context,
              syncResult.exceptionOrNull!,
            ) ??
            NavScaff(
              title: const Text('Error'),
              child: ErrorDisplay(
                e: syncResult.exceptionOrNull,
                message: 'Error loading source',
              ),
            );
      }
      return widget.builder(context, syncResult.getOrThrow);
    }

    // Fall back to async loading
    return LoadingBuilder(
      future: _cachedFuture,
      builder: (context, item) {
        if (item.isFailure) {
          return widget.errorBuilder?.call(context, item.exceptionOrNull!) ??
              NavScaff(
                title: const Text('Error'),
                child: ErrorDisplay(
                  e: item.exceptionOrNull,
                  message: 'Error loading source',
                ),
              );
        }
        return widget.builder(context, item.getOrThrow);
      },
      error: (context, error, stackTrace) =>
          widget.errorBuilder?.call(context, error) ??
          NavScaff(
            title: const Text('Error'),
            child: ErrorDisplay(
              e: error,
              s: stackTrace,
              message: 'Error loading source',
            ),
          ),
      loading: (context) =>
          widget.loadingBuilder?.call(context) ??
          const NavScaff(title: Text('Loading...'), child: DionProgressBar()),
    );
  }
}
