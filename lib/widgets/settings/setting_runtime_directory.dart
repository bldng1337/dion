import 'package:dionysos/data/settings/extension_setting.dart';
import 'package:dionysos/data/settings/settings.dart';
import 'package:dionysos/service/extension.dart'
    hide Alignment, ButtonType, EdgeInsets, StackFit, WrapAlignment;
import 'package:dionysos/utils/design_tokens.dart';
import 'package:dionysos/utils/log.dart';
import 'package:dionysos/utils/toast.dart';
import 'package:dionysos/views/dialog/directory_picker.dart';
import 'package:dionysos/widgets/buttons/iconbutton.dart';
import 'package:dionysos/widgets/settings/setting_tile_wrapper.dart';
import 'package:flutter/material.dart' show Icons, Tooltip;
import 'package:flutter/widgets.dart';

class SettingRuntimeDirectory extends StatelessWidget {
  final String title;
  final String? description;
  final bool write;
  final Setting<String, DionRuntimeSettingMetaData<dynamic>> setting;

  const SettingRuntimeDirectory({
    super.key,
    required this.title,
    required this.setting,
    this.write = false,
    this.description,
  });

  @override
  Widget build(BuildContext context) {
    return ListenableBuilder(
      listenable: setting,
      builder: (context, _) {
        final tile = Padding(
          padding: const EdgeInsets.symmetric(
            horizontal: DionSpacing.lg,
            vertical: DionSpacing.md,
          ),
          child: SettingRow(
            title: title,
            subtitle: setting.value.isNotEmpty
                ? setting.value
                : 'No directory selected',
            control: DionIconbutton(
              tooltip: 'Choose Directory',
              onPressed: () => _pick(context),
              icon: const Icon(Icons.folder_outlined),
            ),
          ),
        );

        if (description != null) {
          return Tooltip(message: description, child: tile);
        }
        return tile;
      },
    );
  }

  Future<void> _pick(BuildContext context) async {
    final path = await pickDirectoryPath(
      context,
      write: write,
      initialDirectory: setting.value.isNotEmpty ? setting.value : null,
    );
    if (path == null) return;
    final extension = setting.metadata.extensionOrNull;
    if (extension != null) {
      try {
        await extension.grantPermission(
          Permission.storage(path: path, write: write),
        );
      } catch (e, s) {
        logger.e(
          'Failed to grant storage permission for $path',
          error: e,
          stackTrace: s,
        );
        showToast(
          'Could not grant the extension access to the picked directory',
          ToastKind.warning,
        );
      }
    }
    setting.value = path;
  }
}
