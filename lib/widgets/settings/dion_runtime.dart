import 'package:awesome_extensions/awesome_extensions.dart';
import 'package:dionysos/data/settings/extension_setting.dart';
import 'package:dionysos/data/settings/settings.dart';
import 'package:dionysos/service/extension.dart'
    hide Alignment, ButtonType, EdgeInsets, StackFit, WrapAlignment;
import 'package:dionysos/utils/design_tokens.dart';
import 'package:dionysos/utils/observer.dart';
import 'package:dionysos/utils/safe_set_state.dart';
import 'package:dionysos/views/customui.dart';
import 'package:dionysos/widgets/buttons/textbutton.dart';
import 'package:dionysos/widgets/errordisplay.dart';
import 'package:dionysos/widgets/settings/setting_dropdown.dart';
import 'package:dionysos/widgets/settings/setting_numberbox.dart';
import 'package:dionysos/widgets/settings/setting_slider.dart';
import 'package:dionysos/widgets/settings/setting_stringlist.dart';
import 'package:dionysos/widgets/settings/setting_textbox.dart';
import 'package:dionysos/widgets/settings/setting_toggle.dart';
import 'package:dionysos/widgets/settings/settings_multidropdown.dart';
import 'package:flutter/material.dart' show Icons;
import 'package:flutter/widgets.dart';
import 'package:flutter_dispose_scope/flutter_dispose_scope.dart';

class DionRuntimeSettingView extends StatelessWidget {
  final Setting<dynamic, DionRuntimeSettingMetaData<dynamic>> setting;

  const DionRuntimeSettingView({super.key, required this.setting});

  @override
  Widget build(BuildContext context) {
    if (setting.metadata.ui != null) {
      switch (setting.metadata.ui!) {
        case final SettingsUI_CustomUI ui:
          return _ExtensionBoundCustomUi(ui: ui.ui, metadata: setting.metadata);
        case final SettingsUI_MultiDropdown _:
          return SettingsMultiDropdown<Object>(
            setting: setting.cast(),
            title: setting.metadata.label,
          );
        case final SettingsUI_CheckBox _:
          return SettingToggle(
            setting: setting.cast(),
            title: setting.metadata.label,
          );
        case final SettingsUI_Slider slider:
          return SettingSlider<double>(
            setting: setting.cast(),
            title: setting.metadata.label,
            min: slider.min,
            max: slider.max,
          );
        case final SettingsUI_Dropdown _:
          return SettingDropdown<dynamic>(
            setting: setting.cast(),
            title: setting.metadata.label,
          );
        // The host directory picker is not wired up yet; the path is still
        // editable as plain text.
        case final SettingsUI_Directory _:
          return SettingTextbox(
            setting: setting.cast(),
            title: setting.metadata.label,
          );
      }
    }
    switch (setting.value) {
      case String _:
        return SettingTextbox(
          setting: setting.cast(),
          title: setting.metadata.label,
        );
      case double _:
        return SettingNumberbox<double>(
          setting: setting.cast(),
          title: setting.metadata.label,
        );
      case bool _:
        return SettingToggle(
          setting: setting.cast(),
          title: setting.metadata.label,
        );
      case List<String> _:
        return SettingStringList(setting: setting.cast());
      case _:
        return ErrorDisplay(
          e: Exception('Unknown Setting type ${setting.value.runtimeType}'),
          message: 'Setting key ${setting.metadata.id} unexpected Runtime type',
        );
    }
  }
}

/// A CustomUI setting is powered by its extension's runtime (slot/event
/// handlers), so it cannot render while the extension is disabled and crashes
/// on lookup when it is uninstalled. Show a banner for both, offering to
/// enable the extension in the disabled case.
class _ExtensionBoundCustomUi extends StatefulWidget {
  final CustomUI ui;
  final DionRuntimeSettingMetaData<dynamic> metadata;

  const _ExtensionBoundCustomUi({required this.ui, required this.metadata});

  @override
  State<_ExtensionBoundCustomUi> createState() =>
      _ExtensionBoundCustomUiState();
}

class _ExtensionBoundCustomUiState extends State<_ExtensionBoundCustomUi>
    with StateDisposeScopeMixin {
  Observer? _observer;

  @override
  void initState() {
    super.initState();
    _observeExtension();
  }

  @override
  void didUpdateWidget(covariant _ExtensionBoundCustomUi oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.metadata.extId != widget.metadata.extId) {
      _observeExtension();
    }
  }

  void _observeExtension() {
    _observer?.dispose();
    final extension = widget.metadata.extensionOrNull;
    if (extension == null) {
      _observer = null;
      return;
    }
    // Follow enable/disable so the banner swaps to the CustomUI (or back)
    // as soon as the state flips.
    _observer = Observer(() => safeSetState(), extension)
      ..disposedBy(scope);
  }

  @override
  Widget build(BuildContext context) {
    final extension = widget.metadata.extensionOrNull;
    if (extension == null) {
      return const _ExtensionStateBanner(message: 'Extension not installed');
    }
    if (!extension.isenabled) {
      return _ExtensionStateBanner(
        message: 'Extension disabled',
        action: 'Enable',
        onAction: extension.enable,
      );
    }
    return CustomUIWidget.fromUI(ui: widget.ui, extension: extension);
  }
}

class _ExtensionStateBanner extends StatelessWidget {
  final String message;
  final String? action;
  final Future<void> Function()? onAction;

  const _ExtensionStateBanner({
    required this.message,
    this.action,
    this.onAction,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(
        horizontal: DionSpacing.md,
        vertical: DionSpacing.sm,
      ),
      decoration: BoxDecoration(
        color: context.theme.colorScheme.errorContainer.withValues(alpha: 0.5),
        borderRadius: DionRadius.small,
        border: Border.all(
          color: context.theme.colorScheme.error.withValues(alpha: 0.2),
          width: 0.5,
        ),
      ),
      child: Row(
        children: [
          Icon(
            Icons.warning_amber_rounded,
            size: 18,
            color: context.theme.colorScheme.error,
          ),
          const SizedBox(width: DionSpacing.sm),
          Expanded(
            child: Text(
              message,
              style: context.bodySmall?.copyWith(
                color: context.theme.colorScheme.onErrorContainer,
                fontWeight: FontWeight.w500,
              ),
            ),
          ),
          if (action != null)
            DionTextbutton(
              type: ButtonType.elevated,
              onPressed: onAction,
              child: Text(action!),
            ),
        ],
      ),
    );
  }
}
