import 'dart:async';
import 'dart:convert';
import 'dart:isolate';

import 'package:dionysos/service/database.dart';
import 'package:dionysos/utils/design_tokens.dart';
import 'package:dionysos/utils/log.dart';
import 'package:dionysos/utils/service.dart';
import 'package:dionysos/widgets/scaffold.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_dispose_scope/flutter_dispose_scope.dart';

/// Above this many characters the rendered preview is truncated; the full
/// text stays available through the copy button. Rendering multi-megabyte
/// strings in a SelectableText blocks the UI thread on its own.
const _maxRenderChars = 200000;

/// A developer tool for running arbitrary SurrealQL queries against the
/// active database and inspecting the raw return values. Useful for
/// diagnosing data issues on deployed apps.
class QueryDebugger extends StatefulWidget {
  const QueryDebugger({super.key});

  @override
  State<QueryDebugger> createState() => _QueryDebuggerState();
}

class _QueryDebuggerState extends State<QueryDebugger>
    with StateDisposeScopeMixin {
  late final TextEditingController _queryController = TextEditingController(
    text: 'SELECT * FROM type::table(\$table) LIMIT 10;',
  )..disposedBy(scope);
  late final TextEditingController _varsController = TextEditingController(
    text: '{\n  "table": "entry"\n}',
  )..disposedBy(scope);

  bool _varsExpanded = false;
  bool _running = false;
  _QueryResult? _result;

  /// Pretty-printed JSON of [_result], computed off the UI isolate (large
  /// results take seconds to encode on the main thread). Null while the
  /// encoding for the current run is in flight.
  String? _pretty;

  /// Guards against a finished encoding from an older run overwriting the
  /// current result.
  int _runSeq = 0;

  Future<void> _runQuery() async {
    final query = _queryController.text.trim();
    if (query.isEmpty) return;

    Map<String, dynamic>? vars;
    final rawVars = _varsController.text.trim();
    if (rawVars.isNotEmpty) {
      try {
        final decoded = jsonDecode(rawVars);
        if (decoded is Map<String, dynamic>) {
          vars = decoded;
        } else if (decoded is Map) {
          vars = decoded.map((k, v) => MapEntry(k.toString(), v));
        } else {
          setState(
            () => _result = _QueryResult.error(
              'Variables must be a JSON object, got ${decoded.runtimeType}.',
            ),
          );
          return;
        }
      } catch (e, stack) {
        logger.e(
          'Failed to parse query variables',
          error: e,
          stackTrace: stack,
        );
        setState(
          () => _result = _QueryResult.error('Invalid variables JSON:\n$e'),
        );
        return;
      }
    }

    final seq = ++_runSeq;
    setState(() {
      _running = true;
      _result = null;
      _pretty = null;
    });

    final stopwatch = Stopwatch()..start();
    try {
      final result = await locate<Database>().db.query(query, vars: vars);
      stopwatch.stop();
      if (!mounted) return;
      setState(() {
        _result = _QueryResult.success(result, elapsed: stopwatch.elapsed);
        _running = false;
      });
      unawaited(_encodePretty(result, seq));
    } catch (e, stack) {
      stopwatch.stop();
      logger.e('Query failed', error: e, stackTrace: stack);
      if (!mounted) return;
      setState(() {
        _result = _QueryResult.error(e.toString(), elapsed: stopwatch.elapsed);
        _running = false;
      });
    }
  }

  Future<void> _encodePretty(List<dynamic> result, int seq) async {
    String pretty;
    try {
      pretty = await _prettyJson(result);
    } catch (e) {
      logger.e('Failed to encode query result', error: e);
      pretty = result.toString();
    }
    if (!mounted || seq != _runSeq) return;
    setState(() => _pretty = pretty);
  }

  /// Static so the [Isolate.run] closure cannot capture the State: closures
  /// inside instance methods box `this` into their context, and the State's
  /// graph (controllers, listeners, binding) is unsendable across isolates.
  static Future<String> _prettyJson(List<dynamic> result) =>
      Isolate.run(() => prettyEncode(result));

  void _clear() {
    setState(() => _result = null);
  }

  /// Best-effort summary of a result, e.g. "2 statements · 5 records".
  String _summarize(List<dynamic> result) {
    final statements = result.length;
    final totalRecords = result.fold<int>(0, (acc, stmt) {
      if (stmt is List) return acc + stmt.length;
      return acc + 1;
    });
    final stmtLabel = statements == 1 ? 'statement' : 'statements';
    final recLabel = totalRecords == 1 ? 'record' : 'records';
    return '$statements $stmtLabel · $totalRecords $recLabel';
  }

  @override
  Widget build(BuildContext context) {
    return NavScaff(
      title: const Text('Query Console'),
      child: Column(
        children: [
          Expanded(
            child: ListView(
              padding: const EdgeInsets.only(
                left: DionSpacing.md,
                right: DionSpacing.md,
                top: DionSpacing.md,
                bottom: DionSpacing.xxxl,
              ),
              children: [
                _EditorCard(
                  label: 'QUERY',
                  child: TextField(
                    controller: _queryController,
                    minLines: 6,
                    maxLines: 12,
                    style: const TextStyle(
                      fontFamily: 'monospace',
                      fontSize: 13,
                    ),
                    decoration: const InputDecoration(
                      border: InputBorder.none,
                      isDense: true,
                    ),
                  ),
                ),
                const SizedBox(height: DionSpacing.md),
                _VarsSection(
                  controller: _varsController,
                  expanded: _varsExpanded,
                  onToggle: () =>
                      setState(() => _varsExpanded = !_varsExpanded),
                ),
                const SizedBox(height: DionSpacing.md),
                _ActionBar(
                  running: _running,
                  onRun: _runQuery,
                  onClear: _clear,
                ),
                if (_result != null) ...[
                  const SizedBox(height: DionSpacing.md),
                  _ResultPanel(
                    result: _result!,
                    pretty: _pretty,
                    summarize: _summarize,
                  ),
                ],
              ],
            ),
          ),
        ],
      ),
    );
  }
}

/// Encodes SurrealDB-specific values (record ids, datetimes, etc.) that the
/// default JSON encoder cannot serialize, degrading to a string form instead
/// of throwing.
Object? _fallbackEncoder(Object? object) {
  if (object is DateTime) return object.toIso8601String();
  return object.toString();
}

/// Pretty-prints a query result for display. Runs on a helper isolate (see
/// [_QueryDebuggerState._encodePretty]), so it must not touch widget state.
String prettyEncode(List<dynamic> result) {
  const encoder = JsonEncoder.withIndent('  ', _fallbackEncoder);
  try {
    return encoder.convert(result);
  } catch (_) {
    // Last resort: fall back to toString if anything still throws.
    return result.toString();
  }
}

/// A bordered container wrapping an editor field, styled like the grouped
/// setting cards used elsewhere in the app.
class _EditorCard extends StatelessWidget {
  final String label;
  final Widget child;

  const _EditorCard({required this.label, required this.child});

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(
        horizontal: DionSpacing.md,
        vertical: DionSpacing.sm,
      ),
      decoration: BoxDecoration(
        color: context.surfaceMuted.withValues(alpha: 0.4),
        borderRadius: DionRadius.medium,
        border: Border.all(
          color: context.borderColor.withValues(alpha: 0.4),
          width: 0.5,
        ),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            label,
            style: DionTypography.sectionHeader(context.textTertiary),
          ),
          const SizedBox(height: DionSpacing.xs),
          child,
        ],
      ),
    );
  }
}

class _VarsSection extends StatelessWidget {
  final TextEditingController controller;
  final bool expanded;
  final VoidCallback onToggle;

  const _VarsSection({
    required this.controller,
    required this.expanded,
    required this.onToggle,
  });

  @override
  Widget build(BuildContext context) {
    return _EditorCard(
      label: 'VARIABLES (JSON)',
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          GestureDetector(
            onTap: onToggle,
            child: Row(
              children: [
                Icon(
                  expanded ? Icons.expand_less : Icons.expand_more,
                  size: 18,
                  color: context.textTertiary,
                ),
                const SizedBox(width: DionSpacing.xs),
                Text(
                  expanded ? 'Hide variables' : 'Show variables',
                  style: DionTypography.labelMedium(context.textSecondary),
                ),
              ],
            ),
          ),
          if (expanded) ...[
            const SizedBox(height: DionSpacing.sm),
            TextField(
              controller: controller,
              minLines: 3,
              maxLines: 8,
              style: const TextStyle(fontFamily: 'monospace', fontSize: 13),
              decoration: const InputDecoration(
                border: InputBorder.none,
                isDense: true,
              ),
            ),
          ],
        ],
      ),
    );
  }
}

class _ActionBar extends StatelessWidget {
  final bool running;
  final VoidCallback onRun;
  final VoidCallback onClear;

  const _ActionBar({
    required this.running,
    required this.onRun,
    required this.onClear,
  });

  @override
  Widget build(BuildContext context) {
    return Row(
      children: [
        FilledButton.icon(
          onPressed: running ? null : onRun,
          icon: running
              ? const SizedBox(
                  width: 16,
                  height: 16,
                  child: CircularProgressIndicator(
                    strokeWidth: 2,
                    color: Colors.white,
                  ),
                )
              : const Icon(Icons.play_arrow, size: 18),
          label: const Text('Run'),
        ),
        const SizedBox(width: DionSpacing.sm),
        TextButton(
          onPressed: running ? null : onClear,
          child: const Text('Clear'),
        ),
      ],
    );
  }
}

class _ResultPanel extends StatelessWidget {
  final _QueryResult result;

  /// Pretty-printed JSON, null while the (possibly slow) off-isolate
  /// encoding is still running.
  final String? pretty;
  final String Function(List<dynamic>) summarize;

  const _ResultPanel({
    required this.result,
    required this.pretty,
    required this.summarize,
  });

  @override
  Widget build(BuildContext context) {
    if (result.error != null) {
      return _BorderedBlock(
        accent: DionColors.error,
        header: Text(
          result.elapsed != null
              ? 'ERROR · ${result.elapsed!.inMilliseconds} ms'
              : 'ERROR',
          style: DionTypography.labelMedium(DionColors.error),
        ),
        trailing: _CopyButton(text: result.error!),
        child: SelectableText(
          result.error!,
          style: const TextStyle(
            fontFamily: 'monospace',
            fontSize: 12,
            color: DionColors.error,
          ),
        ),
      );
    }

    final data = result.data!;
    if (pretty == null) {
      return _BorderedBlock(
        accent: DionColors.success,
        header: Row(
          children: [
            Text(
              'RESULT · ${result.elapsed!.inMilliseconds} ms',
              style: DionTypography.labelMedium(DionColors.success),
            ),
            const SizedBox(width: DionSpacing.sm),
            Flexible(
              child: Text(
                summarize(data),
                style: DionTypography.bodySmall(context.textTertiary),
                overflow: TextOverflow.ellipsis,
              ),
            ),
          ],
        ),
        child: Center(
          child: Padding(
            padding: const EdgeInsets.all(DionSpacing.md),
            child: SizedBox(
              width: 16,
              height: 16,
              child: CircularProgressIndicator(
                strokeWidth: 2,
                color: context.textTertiary,
              ),
            ),
          ),
        ),
      );
    }

    final full = pretty!;
    final truncated = full.length > _maxRenderChars;
    final preview = truncated
        ? '${full.substring(0, _maxRenderChars)}\n… '
            '[truncated, ${full.length - _maxRenderChars} more '
            'characters — use the copy button for the full output]'
        : full;
    return _BorderedBlock(
      accent: DionColors.success,
      header: Row(
        children: [
          Text(
            'RESULT · ${result.elapsed!.inMilliseconds} ms',
            style: DionTypography.labelMedium(DionColors.success),
          ),
          const SizedBox(width: DionSpacing.sm),
          Flexible(
            child: Text(
              summarize(data),
              style: DionTypography.bodySmall(context.textTertiary),
              overflow: TextOverflow.ellipsis,
            ),
          ),
        ],
      ),
      trailing: _CopyButton(text: full),
      child: SelectableText(
        preview,
        style: TextStyle(
          fontFamily: 'monospace',
          fontSize: 12,
          color: context.textPrimary,
        ),
      ),
    );
  }
}

class _BorderedBlock extends StatelessWidget {
  final Color accent;
  final Widget header;
  final Widget? trailing;
  final Widget child;

  const _BorderedBlock({
    required this.accent,
    required this.header,
    required this.child,
    this.trailing,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      decoration: BoxDecoration(
        color: accent.withValues(alpha: 0.05),
        borderRadius: DionRadius.medium,
        border: Border.all(color: accent.withValues(alpha: 0.3), width: 0.5),
      ),
      padding: const EdgeInsets.all(DionSpacing.md),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Expanded(child: header),
              if (trailing != null) ...[
                const SizedBox(width: DionSpacing.sm),
                trailing!,
              ],
            ],
          ),
          const SizedBox(height: DionSpacing.sm),
          child,
        ],
      ),
    );
  }
}

class _CopyButton extends StatelessWidget {
  final String text;

  const _CopyButton({required this.text});

  @override
  Widget build(BuildContext context) {
    return IconButton(
      tooltip: 'Copy',
      visualDensity: VisualDensity.compact,
      iconSize: 18,
      padding: EdgeInsets.zero,
      constraints: const BoxConstraints(),
      onPressed: () async {
        await Clipboard.setData(ClipboardData(text: text));
      },
      icon: Icon(Icons.copy, size: 16, color: context.textTertiary),
    );
  }
}

/// Outcome of a single query run.
class _QueryResult {
  final List<dynamic>? data;
  final String? error;
  final Duration? elapsed;

  const _QueryResult._({this.data, this.error, this.elapsed});

  factory _QueryResult.success(
    List<dynamic> data, {
    required Duration elapsed,
  }) => _QueryResult._(data: data, elapsed: elapsed);

  factory _QueryResult.error(String message, {Duration? elapsed}) =>
      _QueryResult._(error: message, elapsed: elapsed);
}
