import 'package:dionysos/extension/jsextension.dart';
import 'package:dionysos/util/utils.dart';
import 'package:fancy_shimmer_image/fancy_shimmer_image.dart';
import 'package:flutter/material.dart';
import 'package:url_launcher/link.dart';

class Extensionsetting extends StatefulWidget {
  final Extension ext;
  const Extensionsetting(this.ext, {super.key});

  @override
  _ExtensionsettingState createState() => _ExtensionsettingState();
}

class _ExtensionsettingState extends State<Extensionsetting> {
  Widget buildsetting(String name, dynamic value) {
    switch ((value['type'] as String).toLowerCase()) {
      case 'radio':
        return Column(
          children: [
            Text(name),
            ...(value['items'] as List<String>).map<Widget>(
              (a) => RadioListTile<String>(
                groupValue: a,
                value: value['current'] as String,
                onChanged: (String? val) {
                  widget.ext.settings[name]['current'] =
                      val ?? value['current'];
                },
              ),
            ),
          ],
        );
      case 'check':
        return Column(
          children: [
            Text(name),
            CheckboxListTile(
              value: value['current'] as bool?,
              onChanged: (bool? val) {
                widget.ext.settings[name]['current'] = val ?? value['current'];
              },
            ),
          ],
        );
    }
    return Container();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(),
      body: ListView(
        children: [
          Row(
            children: [
              Padding(
                padding: const EdgeInsets.all(10),
                child: FancyShimmerImage(
                  width: 200,
                  height: 200,
                  imageUrl: widget.ext.data?.icon ?? '',
                  errorWidget: const Icon(Icons.image, size: 200),
                ),
              ),
              Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    widget.ext.data?.name ?? '',
                    style: const TextStyle(fontSize: 30),
                  ),
                  Text(
                    widget.ext.data?.type.toString() ?? '',
                    style: const TextStyle(fontSize: 20),
                  ),
                  Text(
                    widget.ext.data?.desc ?? '',
                    style: const TextStyle(fontSize: 20),
                  ),
                  if (widget.ext.data?.giturl != null)
                    Link(
                      uri: Uri.parse('https://flutter.dev'),
                      builder: (BuildContext context, FollowLink? followLink) =>
                          TextButton(
                        onPressed: followLink,
                        child: Text(widget.ext.data?.giturl ?? ''),
                      ),
                    ),
                ],
              ),
            ],
          ),
          const ConstructionWarning(),
          ...widget.ext.settings.entries
              .map((e) => buildsetting(e.key, e.value)),
        ],
      ),
    );
  }
}
