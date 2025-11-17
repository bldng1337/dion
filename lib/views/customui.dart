import 'package:awesome_extensions/awesome_extensions.dart' hide NavigatorExt;
import 'package:dionysos/data/entry/entry.dart';
import 'package:dionysos/service/source_extension.dart' hide DropdownItem;
import 'package:dionysos/utils/time.dart';
import 'package:dionysos/widgets/card.dart';
import 'package:dionysos/widgets/image.dart';
import 'package:flutter/material.dart' show Colors;
import 'package:flutter/widgets.dart';
import 'package:url_launcher/url_launcher.dart';

class CustomUIWidget extends StatelessWidget {
  final Extension extension;
  final CustomUI? ui;
  const CustomUIWidget({super.key, this.ui, required this.extension});

  @override
  Widget build(BuildContext context) {
    return switch (ui) {
      null => nil,
      final CustomUI_Text text => Text(text.text),
      final CustomUI_Image img => DionImage(
        imageUrl: img.image.url,
        httpHeaders: img.image.header,
      ),
      final CustomUI_Link link => Text(
        link.label ?? link.link,
        style: context.bodyMedium?.copyWith(
          color: Colors.blue,
          decoration: TextDecoration.underline,
        ),
      ).onTap(() => launchUrl(Uri.parse(link.link))),
      final CustomUI_TimeStamp timestamp => switch (timestamp.display) {
        TimestampType.relative => Text(
          DateTime.tryParse(timestamp.timestamp)?.formatrelative() ?? '',
        ),
        TimestampType.absolute => Text(
          DateTime.tryParse(timestamp.timestamp)?.toString() ?? '',
        ),
      },
      final CustomUI_EntryCard entryCard => EntryCard(
        entry: EntryImpl(entryCard.entry, extension.id),
      ),
      final CustomUI_Column column => SingleChildScrollView(
        child: Column(
          children: column.children
              .map((e) => CustomUIWidget(ui: e, extension: extension))
              .toList(),
        ),
      ),
      final CustomUI_Row row => SingleChildScrollView(
        scrollDirection: Axis.horizontal,
        child: Row(
          children: row.children
              .map((e) => CustomUIWidget(ui: e, extension: extension))
              .toList(),
        ),
      ),
      _ => throw UnimplementedError(
        'Unknown CustomUI Widget',
      ), //TODO: Rework CustomUI with actions etc.
    };
  }
}
