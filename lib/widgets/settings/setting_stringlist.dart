import 'package:awesome_extensions/awesome_extensions.dart';
import 'package:dionysos/data/settings/settings.dart';
import 'package:dionysos/utils/immutable.dart';
import 'package:dionysos/widgets/buttons/iconbutton.dart';
import 'package:dionysos/widgets/dion_textbox.dart';
import 'package:dionysos/widgets/container/listtile.dart';
import 'package:dionysos/widgets/settings/setting_tile_wrapper.dart';
import 'package:flutter/material.dart';

class SettingStringList extends StatefulWidget {
  final Setting<List<String>, dynamic> setting;
  const SettingStringList({super.key, required this.setting});

  @override
  State<SettingStringList> createState() => _SettingStringListState();
}

class _SettingStringListState extends State<SettingStringList> {
  late final TextEditingController _controller;

  @override
  void initState() {
    super.initState();
    _controller = TextEditingController();
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  void _addEntryFromController() {
    final raw = _controller.text;
    final entry = raw.trim();
    if (entry.isEmpty) return;
    widget.setting.value = widget.setting.value.withNewEntries([entry]);
    _controller.clear();
  }

  void _removeIndex(int index) {
    widget.setting.value = widget.setting.value.withoutIndex([index]);
  }

  @override
  Widget build(BuildContext context) {
    return ListenableBuilder(
      listenable: widget.setting,
      builder: (context, child) => SettingTileWrapper(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            if (widget.setting.value.isEmpty)
              Padding(
                padding: const EdgeInsets.symmetric(vertical: 8.0),
                child: Text('No Entries', style: context.bodyMedium),
              ),
            ...widget.setting.value.indexed.map(
              (e) => SettingTileWrapper(
                child: DionListTile(
                  title: Text(e.$2, style: context.bodyMedium),
                  trailing: DionIconbutton(
                    icon: const Icon(Icons.delete),
                    onPressed: () => _removeIndex(e.$1),
                  ),
                  onTap: () => _removeIndex(e.$1),
                ),
              ),
            ),
            Padding(
              padding: const EdgeInsets.symmetric(vertical: 5.0),
              child: Row(
                children: [
                  Expanded(
                    child: DionTextbox(
                      controller: _controller,
                      onSubmitted: (_) => _addEntryFromController(),
                      maxLines: 1,
                    ),
                  ),
                  const SizedBox(width: 8),
                  DionIconbutton(
                    icon: const Icon(Icons.add),
                    onPressed: _addEntryFromController,
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}
