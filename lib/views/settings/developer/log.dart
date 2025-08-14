import 'dart:convert';

import 'package:awesome_extensions/awesome_extensions.dart';
import 'package:dionysos/utils/log.dart';
import 'package:dionysos/utils/time.dart';
import 'package:dionysos/widgets/badge.dart';
import 'package:dionysos/widgets/buttons/iconbutton.dart';
import 'package:dionysos/widgets/buttons/textbutton.dart';
import 'package:dionysos/widgets/scaffold.dart';
import 'package:dionysos/widgets/settings/setting_title.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:logger/src/log_level.dart';

class LogView extends StatelessWidget {
  const LogView({super.key});

  @override
  Widget build(BuildContext context) {
    return NavScaff(
      child: Column(
        children: [
          const SettingTitle(title: 'Logs'),
          Row(
            children: [
              DionTextbutton(
                child: const Text('Clear'),
                onPressed: () {
                  logBuffer.clear();
                },
              ),
            ],
          ),
          if (logBuffer.buffer.isEmpty)
            const Center(child: Text('No logs'))
          else
            Expanded(
              child: SizedBox(
                height: context.height,
                child: ListenableBuilder(
                  listenable: logBuffer,
                  builder: (context, child) => ListView.builder(
                    shrinkWrap: true,
                    itemBuilder: (context, index) {
                      final element = logBuffer.buffer.elementAt(
                        logBuffer.buffer.length - 1 - index,
                      );
                      final color = switch (element.origin.level) {
                        Level.all || Level.info => Colors.blueAccent,
                        Level.trace ||
                        Level.debug ||
                        Level.verbose => Colors.greenAccent,
                        Level.warning => Colors.yellowAccent,
                        Level.error ||
                        Level.wtf ||
                        Level.fatal => Colors.redAccent,
                        Level.off || Level.nothing => Colors.transparent,
                      }.withAlpha(75);
                      if (color == Colors.transparent) return nil;
                      return DionBadge(
                        color: color,
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Row(
                              children: [
                                Icon(switch (element.origin.level) {
                                  Level.all || Level.info => Icons.info,
                                  Level.trace ||
                                  Level.debug ||
                                  Level.verbose => Icons.bug_report,
                                  Level.warning => Icons.warning,
                                  Level.error ||
                                  Level.wtf ||
                                  Level.fatal => Icons.error,
                                  Level.off || Level.nothing => Icons.close,
                                }, color: color.withAlpha(255)),
                                Text(
                                  '${element.origin.level.name.capitalize} • ${element.origin.time.formatrelative()}',
                                  style: context.labelMedium,
                                ).paddingAll(5),
                              ],
                            ).paddingAll(5),
                            if (element.origin.error != null)
                              Text(
                                element.origin.error.toString(),
                                style: context.bodyMedium!.copyWith(
                                  color: Colors.red,
                                ),
                              ).paddingAll(5),
                            if (element.origin.stackTrace != null)
                              Text(
                                maxLines: 10,
                                element.origin.stackTrace.toString(),
                                style: context.bodyMedium!.copyWith(
                                  color: Colors.grey,
                                ),
                              ),
                            if (element.origin.message != 'FlutterError')
                              switch (element.origin.message) {
                                final String message => Text(
                                  message,
                                  style: context.bodyMedium,
                                ),
                                _ => () {
                                  try {
                                    return Text(
                                      jsonEncode(element.origin.message),
                                      style: context.bodyMedium,
                                    );
                                  } catch (_) {
                                    // expected error
                                  }
                                  return Text(
                                    element.origin.message.toString(),
                                    style: context.bodyMedium,
                                  );
                                }(),
                              },
                            Row(
                              mainAxisAlignment: MainAxisAlignment.end,
                              children: [
                                DionIconbutton(
                                  icon: const Icon(Icons.copy, size: 15),
                                  onPressed: () async {
                                    await Clipboard.setData(
                                      ClipboardData(
                                        text: element.lines.join('\n'),
                                      ),
                                    );
                                  },
                                ),
                              ],
                            ).paddingOnly(top: 5),
                          ],
                        ).paddingAll(5),
                      );
                    },
                    itemCount: logBuffer.buffer.length,
                  ),
                ).paddingAll(5),
              ),
            ),
        ],
      ),
    );
  }
}
