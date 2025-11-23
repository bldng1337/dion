import 'dart:convert';

import 'package:awesome_extensions/awesome_extensions.dart';
import 'package:dionysos/utils/log.dart';
import 'package:dionysos/utils/time.dart';
import 'package:dionysos/widgets/buttons/iconbutton.dart';
import 'package:dionysos/widgets/scaffold.dart';
import 'package:dionysos/widgets/settings/setting_title.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:logger/logger.dart';

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
    Level.wtf,
    Level.fatal,
  };

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

  @override
  Widget build(BuildContext context) {
    return NavScaff(
      child: Column(
        children: [
          const SettingTitle(title: 'Logs'),
          SingleChildScrollView(
            scrollDirection: Axis.horizontal,
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
            child: Row(
              children: [
                FilterChip(
                  label: const Text('Debug'),
                  selected: _isLevelSelected(Level.debug),
                  onSelected: (selected) {
                    setState(() {
                      if (selected) {
                        _selectedLevels.addAll([
                          Level.trace,
                          Level.debug,
                          Level.verbose,
                        ]);
                      } else {
                        _selectedLevels.removeAll([
                          Level.trace,
                          Level.debug,
                          Level.verbose,
                        ]);
                      }
                    });
                  },
                ),
                const SizedBox(width: 8),
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
                const SizedBox(width: 8),
                FilterChip(
                  label: const Text('Warning'),
                  selected: _isLevelSelected(Level.warning),
                  onSelected: (selected) {
                    _toggleLevel(Level.warning);
                  },
                ),
                const SizedBox(width: 8),
                FilterChip(
                  label: const Text('Error'),
                  selected: _isLevelSelected(Level.error),
                  onSelected: (selected) {
                    setState(() {
                      if (selected) {
                        _selectedLevels.addAll([
                          Level.error,
                          Level.wtf,
                          Level.fatal,
                        ]);
                      } else {
                        _selectedLevels.removeAll([
                          Level.error,
                          Level.wtf,
                          Level.fatal,
                        ]);
                      }
                    });
                  },
                ),
                const SizedBox(width: 16),
                TextButton.icon(
                  onPressed: () {
                    logBuffer.clear();
                  },
                  icon: const Icon(Icons.delete_outline, size: 18),
                  label: const Text('Clear'),
                ),
              ],
            ),
          ),
          Expanded(
            child: ListenableBuilder(
              listenable: logBuffer,
              builder: (context, child) {
                final filteredLogs = logBuffer.buffer.where((element) {
                  return _selectedLevels.contains(element.origin.level);
                }).toList();

                if (filteredLogs.isEmpty) {
                  return const Center(
                    child: Text(
                      'No logs found',
                      style: TextStyle(color: Colors.grey),
                    ),
                  );
                }

                return ListView.separated(
                  padding: const EdgeInsets.all(8),
                  itemCount: filteredLogs.length,
                  separatorBuilder: (context, index) =>
                      const Divider(height: 1),
                  itemBuilder: (context, index) {
                    // Show newest first
                    final element =
                        filteredLogs[filteredLogs.length - 1 - index];
                    return _LogItem(element: element);
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

class _LogItem extends StatelessWidget {
  final OutputEvent element;

  const _LogItem({required this.element});

  Color _getColor(Level level) {
    return switch (level) {
      Level.all || Level.info => Colors.blue,
      Level.trace || Level.debug || Level.verbose => Colors.green,
      Level.warning => Colors.orange,
      Level.error || Level.wtf || Level.fatal => Colors.red,
      Level.off || Level.nothing => Colors.grey,
    };
  }

  IconData _getIcon(Level level) {
    return switch (level) {
      Level.all || Level.info => Icons.info_outline,
      Level.trace || Level.debug || Level.verbose => Icons.bug_report_outlined,
      Level.warning => Icons.warning_amber_rounded,
      Level.error || Level.wtf || Level.fatal => Icons.error_outline,
      Level.off || Level.nothing => Icons.help_outline,
    };
  }

  @override
  Widget build(BuildContext context) {
    final color = _getColor(element.origin.level);
    final time = element.origin.time.formatrelative();

    return Container(
      padding: const EdgeInsets.symmetric(vertical: 8, horizontal: 4),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Icon(
            _getIcon(element.origin.level),
            color: color,
            size: 20,
          ).paddingOnly(top: 2, right: 8),
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
                        borderRadius: BorderRadius.circular(4),
                      ),
                      child: Text(
                        element.origin.level.name.toUpperCase(),
                        style: TextStyle(
                          color: color,
                          fontSize: 10,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                    ),
                    const SizedBox(width: 8),
                    Text(
                      time,
                      style: TextStyle(
                        color: context.theme.hintColor,
                        fontSize: 11,
                      ),
                    ),
                    const Spacer(),
                    DionIconbutton(
                      icon: const Icon(Icons.copy, size: 14),
                      onPressed: () async {
                        await Clipboard.setData(
                          ClipboardData(text: element.lines.join('\n')),
                        );
                      },
                    ),
                  ],
                ),
                const SizedBox(height: 4),
                if (element.origin.message != 'FlutterError')
                  _buildMessage(context),
                if (element.origin.error != null)
                  Text(
                    element.origin.error.toString(),
                    style: const TextStyle(color: Colors.redAccent),
                  ).paddingOnly(top: 4),
                if (element.origin.stackTrace != null)
                  Container(
                    margin: const EdgeInsets.only(top: 4),
                    padding: const EdgeInsets.all(8),
                    decoration: BoxDecoration(
                      color: context.theme.colorScheme.surfaceContainerHighest
                          .withOpacity(0.3),
                      borderRadius: BorderRadius.circular(4),
                    ),
                    child: Text(
                      element.origin.stackTrace.toString(),
                      maxLines: 5,
                      overflow: TextOverflow.ellipsis,
                      style: const TextStyle(
                        fontFamily: 'monospace',
                        fontSize: 10,
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

  Widget _buildMessage(BuildContext context) {
    final message = element.origin.message;
    if (message is String) {
      return Text(message, style: context.bodyMedium);
    }
    try {
      return Text(jsonEncode(message), style: context.bodyMedium);
    } catch (_) {
      return Text(message.toString(), style: context.bodyMedium);
    }
  }
}
