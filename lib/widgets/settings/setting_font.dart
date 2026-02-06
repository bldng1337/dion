import 'package:dionysos/data/font.dart';
import 'package:dionysos/data/settings/settings.dart';
import 'package:dionysos/utils/design_tokens.dart';
import 'package:dionysos/widgets/dropdown/single_dropdown.dart';
import 'package:dionysos/widgets/progress.dart';
import 'package:dionysos/widgets/text.dart';
import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:system_fonts/system_fonts.dart';

/// A font picker setting with the new clean design.
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
    if (fonts.isEmpty) return const SizedBox.shrink();

    // Loading state
    if (!fonts.contains(widget.setting.value)) {
      return Padding(
        padding: const EdgeInsets.symmetric(
          horizontal: DionSpacing.lg,
          vertical: DionSpacing.md,
        ),
        child: Row(
          children: [
            if (widget.icon != null) ...[
              Icon(widget.icon, size: 20, color: context.textSecondary),
              const SizedBox(width: DionSpacing.md),
            ],
            Expanded(
              child: Text(
                widget.title,
                style: DionTypography.titleSmall(context.textPrimary),
              ),
            ),
            const SizedBox(width: DionSpacing.md),
            const DionProgressBar(size: 16),
            const SizedBox(width: DionSpacing.sm),
            Text(
              'Loading fonts...',
              style: DionTypography.bodySmall(context.textTertiary),
            ),
          ],
        ),
      );
    }

    return ListenableBuilder(
      listenable: widget.setting,
      builder: (context, child) {
        final tile = _SettingFontTile(
          title: widget.title,
          description: widget.description,
          icon: widget.icon,
          fonts: fonts,
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
        );

        if (widget.description != null) {
          return Tooltip(message: widget.description!, child: tile);
        }
        return tile;
      },
    );
  }
}

class _SettingFontTile extends StatelessWidget {
  final String title;
  final String? description;
  final IconData? icon;
  final List<Font> fonts;
  final Font value;
  final ValueChanged<Font?> onChanged;

  const _SettingFontTile({
    required this.title,
    this.description,
    this.icon,
    required this.fonts,
    required this.value,
    required this.onChanged,
  });

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(
        horizontal: DionSpacing.lg,
        vertical: DionSpacing.md,
      ),
      child: Row(
        children: [
          if (icon != null) ...[
            Icon(icon, size: 20, color: context.textSecondary),
            const SizedBox(width: DionSpacing.md),
          ],
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              mainAxisSize: MainAxisSize.min,
              children: [
                Text(
                  title,
                  style: DionTypography.titleSmall(context.textPrimary),
                ),
                if (description != null) ...[
                  const SizedBox(height: 2),
                  Text(
                    description!,
                    style: DionTypography.bodySmall(context.textTertiary),
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                  ),
                ],
              ],
            ),
          ),
          const SizedBox(width: DionSpacing.md),
          DionDropdown<Font>(
            items: fonts
                .map(
                  (font) => DionDropdownItemWidget<Font>(
                    value: font,
                    label: font.name,
                    labelWidget: DionFontText(
                      text: font.name,
                      only: FontType.system,
                      font: font,
                      style: DionTypography.bodyMedium(context.textPrimary),
                    ),
                  ),
                )
                .toList(),
            value: value,
            onChanged: onChanged,
          ),
        ],
      ),
    );
  }
}
