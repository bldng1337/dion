import 'package:dionysos/data/settings/settings.dart';
import 'package:dionysos/utils/immutable.dart';
import 'package:dionysos/widgets/buttons/iconbutton.dart';
import 'package:dionysos/widgets/dion_textbox.dart';
import 'package:dionysos/widgets/listtile.dart';
import 'package:flutter/material.dart';

class SettingStringList extends StatelessWidget {
  final Setting<List<String>, dynamic> setting;
  const SettingStringList({super.key, required this.setting});

  @override
  Widget build(BuildContext context) {
    return ListenableBuilder(
      listenable: setting,
      builder: (context, child) => Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          if (setting.value.isEmpty) const Text('No Entries'),
          ...setting.value.indexed.map(
            (e) => DionListTile(
              title: Text(e.$2),
              onTap: () {
                setting.value = setting.value.withoutIndex([e.$1]);
              },
            ),
          ),
          Builder(
            builder: (context) {
              String content = '';
              return Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Expanded(
                    child: DionTextbox(
                      controller: TextEditingController(text: content),
                      onChanged: (value) => content = value,
                      onSubmitted: (value) =>
                          setting.value = setting.value.withNewEntries([value]),
                      maxLines: 1,
                    ),
                  ),
                  DionIconbutton(
                    icon: const Icon(Icons.add),
                    onPressed: () {
                      setting.value = setting.value.withNewEntries([content]);
                    },
                  ),
                ],
              );
            },
          ),
        ],
      ),
    );
  }
}
