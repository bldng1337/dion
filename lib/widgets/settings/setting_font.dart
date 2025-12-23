import 'package:awesome_extensions/awesome_extensions.dart';
import 'package:dionysos/data/font.dart';
import 'package:dionysos/data/settings/settings.dart';
import 'package:dionysos/widgets/dropdown/single_dropdown.dart';
import 'package:dionysos/widgets/listtile.dart';
import 'package:dionysos/widgets/settings/setting_tile_wrapper.dart';
import 'package:dionysos/widgets/text.dart';
import 'package:flutter/widgets.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:system_fonts/system_fonts.dart';

class SettingFont extends StatefulWidget {
  final String title;
  final String? description;
  final IconData? icon;
  final Setting<Font, dynamic> setting;
  const SettingFont({
    super.key,
    required this.setting,
    required this.title,
    this.description,
    this.icon,
  });

  @override
  State<SettingFont> createState() => _SettingFontState();
}

class _SettingFontState extends State<SettingFont> {
  final List<Font> fonts = [];

  @override
  void initState() {
    super.initState();
    fonts.addAll(
      GoogleFonts.asMap().keys.map(
        (font) => Font(name: font, type: FontType.google),
      ),
    );
    SystemFonts().loadAllFonts().then((fonts) {
      this.fonts.addAll(
        fonts.map((font) => Font(name: font, type: FontType.system)),
      );
      setState(() {});
    });
  }

  @override
  Widget build(BuildContext context) {
    if (fonts.isEmpty) return SizedBox.shrink();
    // return Text('SettingFont is deprecated, use SettingDropdown with Font items instead.');
    if (!fonts.contains(widget.setting.value)) {
      widget.setting.value = fonts[0];
    }
    final tile = ListenableBuilder(
      listenable: widget.setting,
      builder: (context, child) => SettingTileWrapper(
        child: DionListTile(
          leading: widget.icon != null ? Icon(widget.icon) : null,
          trailing: DionDropdown<Font>(
            items: fonts
                .map(
                  (font) => DionDropdownItemWidget<Font>(
                    value: font,
                    label: font.name,
                    labelWidget: DionFontText(
                      text: font.name,
                      only: FontType.system,
                      font: font,
                      style: context.bodyMedium,
                    ),
                  ),
                )
                .toList(),
            value: widget.setting.value,
            onChanged: (value) {
              if (value == null) {
                try {
                  widget.setting.value = widget.setting.intialValue;
                } catch (_) {}
              } else {
                widget.setting.value = value;
              }
            },
          ),
          title: Text(widget.title, style: context.titleMedium),
        ),
      ),
    );
    if (widget.description != null) {
      return tile.withTooltip(widget.description!);
    }
    return tile;
  }
}
