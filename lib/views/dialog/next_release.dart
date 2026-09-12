import 'package:awesome_extensions/awesome_extensions.dart' hide NavigatorExt;
import 'package:dionysos/data/entry/entry_saved.dart';
import 'package:dionysos/utils/media_type.dart';
import 'package:dionysos/utils/time.dart';
import 'package:dionysos/widgets/buttons/textbutton.dart';
import 'package:dionysos/widgets/dialog.dart';
import 'package:flutter/material.dart'
    show TimeOfDay, showDatePicker, showDialog, showTimePicker;
import 'package:flutter/widgets.dart';

enum _NextReleaseAction { setDate, clear }

Future<void> showNextReleaseEditor(BuildContext context, EntrySaved entry) async {
  final episodeName = entry.mediaType.episodeName.toLowerCase();
  final overrideDate = entry.nextReleaseOverride;
  final action = await showDialog<_NextReleaseAction>(
    context: context,
    builder: (dialogContext) => DionAlertDialog(
      title: Text('Next ${entry.mediaType.episodeName}'),
      content: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            switch (entry.nextRelease) {
              null => 'No next release date known.',
              final date when entry.nextReleaseOverride != null =>
                  'Set manually: ${date.toDateString()}',
              final date => 'Predicted: ${date.toDateString()}',
            },
            style: dialogContext.bodyMedium,
          ),
        ],
      ),
      actions: [
        DionTextbutton(
          type: ButtonType.ghost,
          onPressed:
              overrideDate == null
                  ? null
                  : () => Navigator.pop(
                    dialogContext,
                    _NextReleaseAction.clear,
                  ),
          child: const Text('Clear'),
        ),
        DionTextbutton(
          onPressed: () =>
              Navigator.pop(dialogContext, _NextReleaseAction.setDate),
          child: const Text('Set Date'),
        ),
      ],
    ),
  );
  switch (action) {
    case _NextReleaseAction.clear:
      entry.nextReleaseOverride = null;
      await entry.save();
    case _NextReleaseAction.setDate:
      if (!context.mounted) break;
      final date = await _pickDate(context, entry, episodeName);
      if (date != null) {
        entry.nextReleaseOverride = date;
        await entry.save();
      }
    case null:
      break;
  }
}

Future<DateTime?> _pickDate(
  BuildContext context,
  EntrySaved entry,
  String episodeName,
) async {
  final now = DateTime.now();
  final firstDate = now.subtract(const Duration(days: 365));
  final lastDate = now.add(const Duration(days: 365 * 5));
  var initial = entry.nextRelease ?? now;
  if (initial.isBefore(firstDate)) initial = now;
  if (initial.isAfter(lastDate)) initial = now;
  final date = await showDatePicker(
    context: context,
    initialDate: initial,
    firstDate: firstDate,
    lastDate: lastDate,
    helpText: 'Next $episodeName releases',
  );
  if (date == null || !context.mounted) return null;
  final time = await showTimePicker(
    context: context,
    initialTime:
        entry.nextRelease != null
            ? TimeOfDay.fromDateTime(entry.nextRelease!)
            : TimeOfDay.now(),
    helpText: 'Next $episodeName releases',
  );
  if (time == null) return null;
  return DateTime(date.year, date.month, date.day, time.hour, time.minute);
}
