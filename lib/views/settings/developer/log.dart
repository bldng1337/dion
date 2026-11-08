import 'dart:io';

import 'package:awesome_extensions/awesome_extensions.dart';
import 'package:dionysos/utils/design_tokens.dart';
import 'package:dionysos/utils/log.dart';
import 'package:dionysos/utils/platform.dart';
import 'package:dionysos/utils/share.dart';
import 'package:dionysos/utils/time.dart';
import 'package:dionysos/widgets/buttons/iconbutton.dart';
import 'package:dionysos/widgets/progress.dart';
import 'package:dionysos/widgets/scaffold.dart';
import 'package:dionysos/widgets/settings/setting_title.dart';
import 'package:file_selector/file_selector.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:logger/logger.dart' show Level;
import 'package:path_provider/path_provider.dart';

class LogView extends StatefulWidget {
  const LogView({super.key});

  @override
  State<LogView> createState() => _LogViewState();
}

class _LogViewState extends State<LogView> {
  final Set<Level> _selectedLevels = {
    Level.trace,
    Level.debug,
    Level.info,
    Level.warning,
    Level.error,
    Level.fatal,
  };

  bool _backgroundOnly = false;

  @override
  void initState() {
    super.initState();
    if (!LogStore.instance.isReady) {
      LogStore.instance.ready.whenComplete(() {
        if (mounted) setState(() {});
      });
    }
  }

  void _toggleLevel(Level level) {
    setState(() {
      if (_selectedLevels.contains(level)) {
        _selectedLevels.remove(level);
      } else {
        _selectedLevels.add(level);
      }
    });
  }

  bool _isLevelSelected(Level level) {
    return _selectedLevels.contains(level);
  }

  List<LogRecord> get _filteredLogs {
    return LogStore.instance.records
        .where(
          (record) =>
              _selectedLevels.contains(record.level) &&
              (!_backgroundOnly || record.source != kLogSourceMain),
        )
        .toList();
  }

  Future<void> _exportLogs(List<LogRecord> logs) async {
    final content = formatLogRecords(logs);
    final fileName =
        'dion-logs-${DateTime.now().toIso8601String().replaceAll(':', '-')}.txt';
    if (getPlatform() == CPlatform.ios || getPlatform() == CPlatform.android) {
      final dir = await getTemporaryDirectory();
      final file = File('${dir.path}/$fileName');
      await file.writeAsString(content);
      await shareFiles([file]);
    } else {
      final String? dir = await getDirectoryPath();
      if (dir == null) return;
      final file = File('$dir/$fileName');
      await file.create(recursive: true);
      await file.writeAsString(content);
    }
  }

  @override
  Widget build(BuildContext context) {
    final store = LogStore.instance;
    return NavScaff(
      child: Column(
        children: [
          const SettingTitle(title: 'Logs'),
          SingleChildScrollView(
            scrollDirection: Axis.horizontal,
            padding: const EdgeInsets.symmetric(
              horizontal: DionSpacing.lg,
              vertical: DionSpacing.sm,
            ),
            child: Row(
              children: [
                FilterChip(
                  label: const Text('Debug'),
                  selected: _isLevelSelected(Level.debug),
                  onSelected: (selected) {
                    setState(() {
                      if (selected) {
                        _selectedLevels.addAll([Level.trace, Level.debug]);
                      } else {
                        _selectedLevels.removeAll([Level.trace, Level.debug]);
                      }
                    });
                  },
                ),
                const SizedBox(width: DionSpacing.sm),
                FilterChip(
                  label: const Text('Info'),
                  selected: _isLevelSelected(Level.info),
                  onSelected: (selected) {
                    setState(() {
                      if (selected) {
                        _selectedLevels.addAll([Level.info, Level.all]);
                      } else {
                        _selectedLevels.removeAll([Level.info, Level.all]);
                      }
                    });
                  },
                ),
                const SizedBox(width: DionSpacing.sm),
                FilterChip(
                  label: const Text('Warning'),
                  selected: _isLevelSelected(Level.warning),
                  onSelected: (selected) {
                    _toggleLevel(Level.warning);
                  },
                ),
                const SizedBox(width: DionSpacing.sm),
                FilterChip(
                  label: const Text('Error'),
                  selected: _isLevelSelected(Level.error),
                  onSelected: (selected) {
                    setState(() {
                      if (selected) {
                        _selectedLevels.addAll([Level.error, Level.fatal]);
                      } else {
                        _selectedLevels.removeAll([Level.error, Level.fatal]);
                      }
                    });
                  },
                ),
                const SizedBox(width: DionSpacing.sm),
                FilterChip(
                  label: const Text('Background'),
                  selected: _backgroundOnly,
                  onSelected: (selected) {
                    setState(() {
                      _backgroundOnly = selected;
                    });
                  },
                ),
                const SizedBox(width: DionSpacing.lg),
                TextButton.icon(
                  onPressed: () {
                    store.clear();
                  },
                  icon: const Icon(Icons.delete_outline, size: 18),
                  label: const Text('Clear'),
                ),
                TextButton.icon(
                  onPressed: _filteredLogs.isEmpty
                      ? null
                      : () => _exportLogs(_filteredLogs),
                  icon: const Icon(Icons.filter_alt_outlined, size: 18),
                  label: const Text('Export'),
                ),
                TextButton.icon(
                  onPressed: store.records.isEmpty
                      ? null
                      : () => _exportLogs(store.records),
                  icon: const Icon(Icons.file_download_outlined, size: 18),
                  label: const Text('Export All'),
                ),
              ],
            ),
          ),
          Expanded(
            child: !store.isReady
                ? const Center(child: DionProgressBar(size: 24))
                : ListenableBuilder(
                    listenable: store,
                    builder: (context, child) {
                      final filteredLogs = _filteredLogs;

                      if (filteredLogs.isEmpty) {
                        return Center(
                          child: Text(
                            'No logs found',
                            style: TextStyle(color: context.textTertiary),
                          ),
                        );
                      }

                      return ListView.separated(
                        padding: const EdgeInsets.all(DionSpacing.sm),
                        itemCount: filteredLogs.length,
                        separatorBuilder: (context, index) =>
                            const Divider(height: 1),
                        itemBuilder: (context, index) {
                          // Show newest first
                          final record =
                              filteredLogs[filteredLogs.length - 1 - index];
                          return _LogItem(record: record);
                        },
                      );
                    },
                  ),
          ),
        ],
      ),
    );
  }
}

class _LogItem extends StatefulWidget {
  final LogRecord record;

  const _LogItem({required this.record});

  @override
  State<_LogItem> createState() => _LogItemState();
}

class _LogItemState extends State<_LogItem> {
  bool _stackExpanded = false;

  LogRecord get record => widget.record;

  Color _getColor(Level level) {
    return switch (level) {
      Level.all || Level.info => Colors.blue,
      Level.trace || Level.debug => DionColors.success,
      Level.warning => DionColors.warning,
      Level.error || Level.fatal => DionColors.error,
      _ => Colors.grey, // off and deprecated levels (verbose/wtf/nothing)
    };
  }

  IconData _getIcon(Level level) {
    return switch (level) {
      Level.all || Level.info => Icons.info_outline,
      Level.trace || Level.debug => Icons.bug_report_outlined,
      Level.warning => Icons.warning_amber_rounded,
      Level.error || Level.fatal => Icons.error_outline,
      _ =>
        Icons.help_outline, // off and deprecated levels (verbose/wtf/nothing)
    };
  }

  @override
  Widget build(BuildContext context) {
    final color = _getColor(record.level);
    final time = record.time.formatrelative();
    final isBackground = record.source != kLogSourceMain;

    return Container(
      padding: const EdgeInsets.symmetric(
        vertical: DionSpacing.sm,
        horizontal: DionSpacing.xs,
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Icon(
            _getIcon(record.level),
            color: color,
            size: 20,
          ).paddingOnly(top: 2, right: DionSpacing.sm),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    Container(
                      padding: const EdgeInsets.symmetric(
                        horizontal: 6,
                        vertical: 2,
                      ),
                      decoration: BoxDecoration(
                        color: color.withValues(alpha: 0.1),
                        borderRadius: BorderRadius.circular(DionRadius.sm),
                      ),
                      child: Text(
                        record.level.name.toUpperCase(),
                        style: TextStyle(
                          color: color,
                          fontSize: 10,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                    ),
                    if (isBackground) ...[
                      const SizedBox(width: DionSpacing.xs),
                      Container(
                        padding: const EdgeInsets.symmetric(
                          horizontal: 6,
                          vertical: 2,
                        ),
                        decoration: BoxDecoration(
                          color: Colors.deepPurple.withValues(alpha: 0.1),
                          borderRadius: BorderRadius.circular(DionRadius.sm),
                        ),
                        child: const Text(
                          'BG',
                          style: TextStyle(
                            color: Colors.deepPurple,
                            fontSize: 10,
                            fontWeight: FontWeight.bold,
                          ),
                        ),
                      ),
                    ],
                    const SizedBox(width: DionSpacing.sm),
                    Text(
                      time,
                      style: TextStyle(
                        color: context.theme.hintColor,
                        fontSize: 11,
                      ),
                    ),
                    const Spacer(),
                    DionIconbutton(
                      tooltip: 'Copy Log Entry',
                      icon: const Icon(Icons.copy, size: 14),
                      onPressed: () async {
                        await Clipboard.setData(
                          ClipboardData(text: formatLogRecord(record)),
                        );
                      },
                    ),
                  ],
                ),
                const SizedBox(height: DionSpacing.xs),
                if (record.message != 'FlutterError')
                  Text(record.message, style: context.bodyMedium),
                if (record.error != null)
                  Text(
                    record.error!,
                    style: const TextStyle(color: Colors.redAccent),
                  ).paddingOnly(top: DionSpacing.xs),
                if (record.stackTrace != null)
                  GestureDetector(
                    onTap: () {
                      setState(() {
                        _stackExpanded = !_stackExpanded;
                      });
                    },
                    child: Container(
                      margin: const EdgeInsets.only(top: DionSpacing.xs),
                      padding: const EdgeInsets.all(DionSpacing.sm),
                      decoration: BoxDecoration(
                        color: context.theme.colorScheme.surfaceContainerHighest
                            .withValues(alpha: 0.3),
                        borderRadius: BorderRadius.circular(DionRadius.sm),
                      ),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Row(
                            mainAxisSize: MainAxisSize.min,
                            children: [
                              Icon(
                                _stackExpanded
                                    ? Icons.expand_less
                                    : Icons.expand_more,
                                size: 14,
                                color: context.theme.hintColor,
                              ),
                              const SizedBox(width: DionSpacing.xs),
                              Text(
                                _stackExpanded
                                    ? 'Stack trace'
                                    : 'Stack trace (tap to expand)',
                                style: TextStyle(
                                  color: context.theme.hintColor,
                                  fontSize: 10,
                                ),
                              ),
                            ],
                          ),
                          Text(
                            record.stackTrace!,
                            maxLines: _stackExpanded ? null : 5,
                            overflow: TextOverflow.ellipsis,
                            style: const TextStyle(
                              fontFamily: 'monospace',
                              fontSize: 10,
                            ),
                          ),
                        ],
                      ),
                    ),
                  ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}
