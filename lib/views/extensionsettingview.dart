import 'package:dionysos/extension/extensionmanager.dart';
import 'package:dionysos/extension/jsextension.dart';
import 'package:dionysos/util/settingsapi.dart';
import 'package:dionysos/util/utils.dart';
import 'package:dionysos/widgets/image.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter/widgets.dart';
import 'package:url_launcher/link.dart';

class Extensionsetting extends StatefulWidget {
  final Extension ext;
  const Extensionsetting(this.ext, {super.key});

  @override
  _ExtensionsettingState createState() => _ExtensionsettingState();
}

class _ExtensionsettingState extends State<Extensionsetting> {
  Widget displayui(dynamic ui, dynamic value, String name) {
    return StatefulBuilder(
      builder: (context, setState) => Row(
        children: [
          Text((ui['label'] as String?) ?? name),
          switch ((ui['type'] as String).toLowerCase()) {
            'slider' => Slider(
                value: value['value'] as double,
                min: ui['min'] as double,
                max: ui['max'] as double,
                divisions: (((ui['max'] as double) - (ui['min'] as double)) /
                        (ui['step'] as double))
                    .ceil(),
                onChanged: (double? val) {
                  widget.ext.setsettings(name, val);
                  setState(() {});
                },
              ),
            'checkbox' => Checkbox(
                value: value['value'] as bool,
                onChanged: (bool? val) {
                  widget.ext.setsettings(name, val);
                  setState(() {});
                },
              ),
            'textbox' => TextField(
                decoration: InputDecoration(
                  hintText: (ui['hint'] as String?) ?? '',
                ),
                controller: TextEditingController()
                  ..text = value['value'] as String,
                onChanged: (val) {
                  widget.ext.setsettings(name, val);
                },
              ),
            'numberbox' => TextField(
                decoration: InputDecoration(
                  hintText: (ui['hint'] as String?) ?? '',
                ),
                inputFormatters: [
                  FilteringTextInputFormatter.allow(RegExp(r'[0-9\.]')),
                  FilteringTextInputFormatter.singleLineFormatter,
                ],
                controller: TextEditingController()
                  ..text = (value['value'] as num).toString(),
                onChanged: (val) {
                  widget.ext.setsettings(name, num.parse(val));
                  setState(() {});
                },
              ),
            'dropdown' => DropdownButton<String>(
                value: value['value'] as String,
                onChanged: (String? val) {
                  widget.ext.setsettings(name, val);
                  setState(() {});
                },
                items: (ui['options'] as List<dynamic>)
                    .cast<Map<String, dynamic>>()
                    .map<DropdownMenuItem<String>>(
                      (e) => DropdownMenuItem<String>(
                        value: e['value'] as String,
                        child: Text(e['label'] as String),
                      ),
                    )
                    .toList(),
              ),
            _ => Container(),
          },
        ],
      ),
    );
  }

  Widget buildsetting(String name, dynamic value) {
    if (value['ui'] != null) {
      return displayui(value['ui'], value, name);
    }
    if (value['def'] is bool) {
      return displayui({'type': 'checkbox'}, value, name);
    }
    if (value['def'] is String) {
      return displayui({'type': 'textbox'}, value, name);
    }
    if (value['def'] is int || value['def'] is double) {
      return displayui({'type': 'numberbox'}, value, name);
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
                  imageUrl: widget.ext.data?.icon ?? 'https://0.0.0.0/',
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
                    widget.ext.data?.type
                            ?.map((v) => v.toString())
                            .reduce((a, b) => '$a, $b') ??
                        '',
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
          TextButton(
            onPressed: () {
              ExtensionManager().uninstall(widget.ext);
            },
            child: const Text('Uninstall'),
          ),
          // const ConstructionWarning(),
          const Padding(
            padding: EdgeInsets.all(10),
            child: Text(
              'Settings',
              style: TextStyle(fontSize: 20),
            ),
          ),
          ExtensionSettingPageBuilder(widget.ext, SettingType.extension)
              .barebuild(null, nested: true)
          // Column(
          //   children: widget.ext.settings.entries
          //       .where((e) => e.value['type'] == 'extension')
          //       .map((e) => buildsetting(e.key, e.value))
          //       .toList(),
          // )
          ,
          // )
        ],
      ),
    );
  }
}
