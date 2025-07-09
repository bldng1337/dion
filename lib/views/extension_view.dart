import 'package:awesome_extensions/awesome_extensions.dart';
import 'package:dionysos/service/source_extension.dart' hide Setting;
import 'package:dionysos/utils/log.dart';
import 'package:dionysos/utils/service.dart';
import 'package:dionysos/utils/settings.dart';
import 'package:dionysos/widgets/badge.dart';
import 'package:dionysos/widgets/errordisplay.dart';
import 'package:dionysos/widgets/foldabletext.dart';
import 'package:dionysos/widgets/image.dart';
import 'package:dionysos/widgets/scaffold.dart';
import 'package:dionysos/widgets/settings/setting_numberbox.dart';
import 'package:dionysos/widgets/settings/setting_slider.dart';
import 'package:dionysos/widgets/settings/setting_textbox.dart';
import 'package:dionysos/widgets/settings/setting_toggle.dart';
import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';

class ExtensionView extends StatefulWidget {
  const ExtensionView({super.key});

  @override
  _ExtensionViewState createState() => _ExtensionViewState();
}

class _ExtensionViewState extends State<ExtensionView> {
  Extension? extension;
  Object? error;

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    try {
      final ext = locate<SourceExtension>().getExtension(
        GoRouterState.of(context).pathParameters['id']!,
      );
      ext.internalProxy.getSettingsIds().then((e) {
        logger.i(e);
      });
      setState(() {
        extension = ext;
      });
    } catch (e) {
      error = e;
    }
  }

  @override
  Widget build(BuildContext context) {
    if (error != null) {
      return NavScaff(
        title: Text('Error Loading ${extension?.name ?? ''}'),
        child: Center(
          child: ErrorDisplay(e: error),
        ),
      );
    }
    if (extension == null) {
      return const NavScaff(
        title: Text('Loading ...'),
        child: Center(child: CircularProgressIndicator()),
      );
    }
    return NavScaff(
      child: Column(
        children: [
          Row(
            children: [
              DionImage(
                imageUrl: extension!.data.icon,
                width: 100,
                height: 100,
              ),
              Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    crossAxisAlignment: CrossAxisAlignment.end,
                    children: [
                      Text(
                        extension!.name,
                        style: context.titleLarge,
                      ),
                      DionBadge(
                        color: Colors.grey,
                        child: Text(
                          extension!.data.version ?? '',
                          style: context.bodyMedium,
                        ),
                      ).paddingAll(5),
                    ],
                  ),
                  if (extension!.data.author != null &&
                      extension!.data.author!.isNotEmpty)
                    Text(
                      'by ${extension!.data.author}',
                      style: context.bodyMedium,
                    ),
                ],
              ).paddingAll(10),
            ],
          ).paddingAll(30),
          Expanded(
            child: SingleChildScrollView(
              child: Column(
                children: [
                  if (extension!.data.desc != null &&
                      extension!.data.desc!.isNotEmpty)
                    Foldabletext(
                      extension!.data.desc ?? '',
                      style: context.bodyMedium,
                    ),
                  Text('Settings: ${extension!.settings.length}'),
                  for (final e in extension!.settings.where(
                    (set) =>
                        set.metadata.setting.settingtype ==
                        Settingtype.extension_,
                  ))
                    SettingView(setting: e),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class SettingView extends StatelessWidget {
  final Setting<dynamic, ExtensionSettingMetaData<dynamic>> setting;
  const SettingView({super.key, required this.setting});

  @override
  Widget build(BuildContext context) {
    if (setting.metadata.setting.setting.ui != null) {
      return switch (setting.metadata.setting.setting.ui) {
        final SettingUI_Slider slider => SettingSlider(
            title: slider.label,
            setting: setting.cast<double, ExtensionSettingMetaData<double>>(),
            max: slider.max,
            min: slider.min, //TODO: step
          ),
        final SettingUI_Checkbox checkbox => SettingToggle(
            title: checkbox.label,
            setting: setting.cast<bool, ExtensionSettingMetaData<bool>>(),
          ),
        final SettingUI_Textbox textbox => SettingTextbox(
            title: textbox.label,
            setting: setting.cast<String, ExtensionSettingMetaData<String>>(),
          ),
        final SettingUI_Dropdown setting =>
          Text('Dropdown: ${setting.label}'), //TODO: implement dropdown
        _ => Text(
            'Setting: ${setting.metadata.id} has no known type ${setting.runtimeType}',),
      };
    }
    return switch (setting.intialValue) {
      final int val => SettingNumberbox(
          title: setting.metadata.id,
          setting: setting.cast<int, ExtensionSettingMetaData<int>>(),
        ),
      final double val => SettingNumberbox(
          title: setting.metadata.id,
          setting: setting.cast<double, ExtensionSettingMetaData<double>>(),
        ),
      final bool val => SettingToggle(
          title: setting.metadata.id,
          setting: setting.cast<bool, ExtensionSettingMetaData<bool>>(),
        ),
      final String val => SettingTextbox(
          title: setting.metadata.id,
          setting: setting.cast<String, ExtensionSettingMetaData<String>>(),),
      _ => Text(
          'Setting: ${setting.metadata.id} has no known type ${setting.runtimeType}',),
    };
  }
}
