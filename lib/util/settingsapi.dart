import 'dart:io';
import 'dart:math';

import 'package:dionysos/data/Entry.dart';
import 'package:dionysos/extension/jsextension.dart';
import 'package:dionysos/main.dart';
import 'package:dionysos/util/utils.dart';
import 'package:file_picker/file_picker.dart';
import 'package:flutter/material.dart';
import 'package:isar/isar.dart';
import 'package:language_code/language_code.dart';
//=============================================================================
//===================================SETTINGS==================================
//=============================================================================

abstract class Settingsetter {
  const Settingsetter();
  Future<bool> setvalue<T>(T value, String key);
  Future<bool> clear(String key);
  Future<T> getvalue<T>(String key);
}

enum SettingType {
  extension,
  entry,
  search;

  String name() {
    switch (this) {
      case extension:
        return 'extension';
      case entry:
        return 'entry';
      case search:
        return 'search';
    }
  }
}

class ExtensionSettingsetter extends Settingsetter {
  final Extension extension;
  final SettingType type;
  ExtensionSettingsetter(this.extension, this.type);

  @override
  Future<bool> clear(String key) async {
    extension.settings[key]['value'] = extension.settings[key]['def'];
    return true;
  }

  @override
  Future<bool> setvalue<T>(T value, String key) async {
    extension.setsettings(key, value);
    return true;
  }

  @override
  Future<T> getvalue<T>(String key) async {
    return extension.settings[key]['value'] as T;
  }
}

class SettingsCategory {
  final String id;

  const SettingsCategory(this.id);
}

abstract class OptionalSetting<T> {
  final String id;
  final SettingsCategory? category;

  const OptionalSetting(this.id, {this.category});

  String get key {
    return "${category?.id ?? ""}$id";
  }

  T? get _value;
  T? get value {
    return _value;
  }

  Future<bool> clear() {
    return prefs.remove(key);
  }

  Future<bool> setvalue(T value);
}

class ExtensionSetting<T> extends Setting<T> {
  final Extension extension;
  ExtensionSetting(
    String id,
    this.extension,
  ) : super(id, extension.settings[id]['value'] as T, category: null);

  @override
  T? get _value => extension.settings[key]['value'] as T;

  @override
  Future<bool> setvalue(T value) async {
    extension.setsettings(key, value);
    return true;
  }
}

class EntryExtensionSetting<T> extends ExtensionSetting<T> {
  final EntryDetail entry;
  EntryExtensionSetting(
    super.id,
    super.extension,
    this.entry,
  );

  @override
  T? get _value => entry.getSetting(key);

  @override
  Future<bool> setvalue(T value) async {
    entry.setSetting(key, value);
    return true;
  }
}

abstract class Setting<T> {
  final String id;
  final SettingsCategory? category;
  final T defaultvalue;
  const Setting(
    this.id,
    this.defaultvalue, {
    this.category,
  });

  String get key {
    return "${category?.id ?? ""}$id";
  }

  T? get _value;
  T get value {
    return _value ?? defaultvalue;
  }

  Future<bool> clear() {
    return prefs.remove(key);
  }

  Future<bool> setvalue(T value);
}

class SettingString extends Setting<String> {
  const SettingString(
    super.id,
    super.defaultvalue, {
    super.category,
  });

  @override
  String? get _value {
    return prefs.getString(key);
  }

  @override
  Future<bool> setvalue(String value) {
    return prefs.setString(key, value);
  }
}

class SettingBoolean extends Setting<bool> {
  const SettingBoolean(super.id, super.defaultvalue, {super.category});

  @override
  bool? get _value {
    return prefs.getBool(key);
  }

  @override
  Future<bool> setvalue(bool value) {
    return prefs.setBool(key, value);
  }
}

class SettingInt extends Setting<int> {
  const SettingInt(super.id, super.defaultvalue, {super.category});

  @override
  int? get _value {
    return prefs.getInt(key);
  }

  @override
  Future<bool> setvalue(int value) {
    return prefs.setInt(key, value);
  }
}

class SettingDouble extends Setting<double> {
  const SettingDouble(super.id, super.defaultvalue, {super.category});

  @override
  double? get _value {
    return prefs.getDouble(key);
  }

  @override
  Future<bool> setvalue(double value) {
    return prefs.setDouble(key, value);
  }
}

class SettingStringList extends Setting<List<String>> {
  const SettingStringList(super.id, super.defaultvalue, {super.category});

  @override
  List<String>? get _value {
    return prefs.getStringList(key);
  }

  @override
  Future<bool> setvalue(List<String> value) {
    return prefs.setStringList(key, value);
  }

  Future<bool> add(String value) {
    final list = List.of(this.value);
    list.add(value);
    return setvalue(list);
  }

  Future<bool> remove(String value) {
    final list = List.of(this.value);
    list.remove(value);
    return setvalue(list);
  }
}

class SettingDirectory extends OptionalSetting<Directory> {
  const SettingDirectory(super.id, {super.category});

  @override
  Directory? get _value {
    final String? str = prefs.getString(key);
    if (str == null) {
      return null;
    }
    return Directory(str);
  }

  @override
  Future<bool> setvalue(Directory value) {
    return prefs.setString(key, value.absolute.path);
  }
}

class SettingLanguage extends Setting<LanguageCodes> {
  const SettingLanguage(super.id, super.defaultvalue, {super.category});

  @override
  LanguageCodes? get _value => stringtoLang(prefs.getString(key));

  @override
  Future<bool> setvalue(LanguageCodes value) {
    return prefs.setString(key, value.nativeName);
  }
}

//=============================================================================
//================================SETTINGS TILE================================
//=============================================================================
abstract class Tile {
  final String name;
  final String description;
  final IconData? icon;

  const Tile(this.name, this.description, {this.icon});

  Widget render(BuildContext context, Function update);
}

abstract class SettingTile<T> extends Tile {
  final Setting<T> setting;

  const SettingTile(super.name, super.description, this.setting, {super.icon});
}

abstract class OptionalSettingTile<T> extends Tile {
  final OptionalSetting<T> setting;
  const OptionalSettingTile(
    super.name,
    super.description,
    this.setting, {
    super.icon,
  });
}

class WidgetTile extends Tile {
  final Widget Function(BuildContext context) w;

  const WidgetTile(this.w) : super('', '');

  @override
  Widget render(BuildContext context, Function update) {
    return w(context);
  }
}

class SettingsNavTile extends Tile {
  final SettingPageBuilder builder;

  const SettingsNavTile(
    super.name,
    super.description,
    this.builder, {
    super.icon,
  });

  @override
  Widget render(BuildContext context, Function update) {
    return Tooltip(
      message: description,
      child: ListTile(
        leading: icon != null ? Icon(icon) : null,
        title: Text(name),
        onTap: () => enav(context, builder.build(null)),
      ),
    );
  }
}

class ChoiceTile<T> extends SettingTile<T> {
  final List<Choice<T>> choices;
  const ChoiceTile(
    super.name,
    super.description,
    super.setting, {
    required this.choices,
    super.icon,
  });

  @override
  Widget render(BuildContext context, Function update) {
    T value = setting.value;
    if (!choices.contains(value)) {
      value = choices.first.value;
      setting.setvalue(value);
    }
    return Tooltip(
      message: description,
      child: ListTile(
        leading: icon != null ? Icon(icon) : null,
        title: Text(name),
        trailing: DropdownButton(
          items: choices
              .map(
                (e) => DropdownMenuItem(
                  value: e.value,
                  child: Text(e.name),
                ),
              )
              .toList(),
          value: value,
          onChanged: (val) => setting
              .setvalue(val ?? setting.defaultvalue)
              .then((value) => update()),
        ),
      ),
    );
  }
}

class SimpleChoiceTile extends SettingTile<String> {
  final List<String> choices;
  const SimpleChoiceTile(
    super.name,
    super.description,
    super.setting, {
    required this.choices,
    super.icon,
  });

  @override
  Widget render(BuildContext context, Function update) {
    String value = setting.value;
    if (!choices.contains(value)) {
      value = choices.first;
      setting.setvalue(value);
    }
    return Tooltip(
      message: description,
      child: ListTile(
        leading: icon != null ? Icon(icon) : null,
        title: Text(name),
        trailing: DropdownButton(
          items: choices
              .map(
                (e) => DropdownMenuItem(
                  value: e,
                  child: Text(e),
                ),
              )
              .toList(),
          value: value,
          onChanged: (val) => setting
              .setvalue(val ?? setting.defaultvalue)
              .then((value) => update()),
        ),
      ),
    );
  }
}

class BooleanTile extends SettingTile<bool> {
  const BooleanTile(super.name, super.description, super.setting, {super.icon});

  @override
  Widget render(BuildContext context, Function update) {
    return Tooltip(
      message: description,
      child: ListTile(
        leading: icon != null ? Icon(icon) : null,
        title: Text(name),
        trailing: Switch(
          value: setting.value,
          onChanged: (bool value) =>
              setting.setvalue(value).then((value) => update()),
        ),
      ),
    );
  }
}

class ButtonTile extends Tile {
  final void Function() onpress;

  const ButtonTile(
    super.name,
    super.description, {
    required super.icon,
    required this.onpress,
  });

  @override
  Widget render(BuildContext context, Function update) {
    return Tooltip(
      message: description,
      child: ListTile(
        leading: icon != null ? Icon(icon) : null,
        title: Text(name),
        onTap: onpress,
      ),
    );
  }
}

class DoubleTile extends SettingTile<double> {
  final double min;
  final double max;
  const DoubleTile(
    super.name,
    super.description,
    super.setting, {
    this.min = 0,
    this.max = 1,
    super.icon,
  });

  double round(double value) {
    return ((value * 100).round().toDouble()) / 100.0;
  }

  @override
  Widget render(BuildContext context, Function update) {
    double curr = round(setting.value);
    return Tooltip(
      message: description,
      child: ListTile(
        leading: icon != null ? Icon(icon) : null,
        title: Text(name),
        subtitle: StatefulBuilder(
          builder: (context, setState) => Slider(
            value: curr,
            onChangeEnd: (a) => setting.setvalue(a),
            min: min,
            max: max,
            onChanged: (double valv) {
              setState(() {
                curr = ((valv * 100).round().toDouble()) / 100;
              });
            },
          ),
        ),
      ),
    );
  }
}

class ConditionalTile extends Tile {
  final Setting<bool> setting;
  final Tile child;
  const ConditionalTile(this.setting, this.child, {super.icon}) : super('', '');

  @override
  Widget render(BuildContext context, Function update) {
    if (setting.value) {
      return child.render(context, update);
    } else {
      return Container();
    }
  }
}

class DirectoryTile extends OptionalSettingTile<Directory> {
  const DirectoryTile(
    super.name,
    super.description,
    super.setting, {
    super.icon,
  });

  @override
  Widget render(BuildContext context, Function update) {
    return Tooltip(
      message: description,
      child: ListTile(
        leading: icon != null ? Icon(icon) : null,
        title: Text(name),
        subtitle: Text(setting.value?.path ?? 'Unset'),
        onTap: () async {
          final String? path = await FilePicker.platform.getDirectoryPath();
          if (path == null) {
            setting.clear();
            return;
          }
          setting.setvalue(Directory(path));
          update();
        },
      ),
    );
  }
}

class LanguageTile extends SettingTile<LanguageCodes> {
  const LanguageTile(
    super.name,
    super.description,
    super.setting, {
    super.icon,
  });

  @override
  Widget render(BuildContext context, Function update) {
    return Tooltip(
      message: description,
      child: ListTile(
        leading: icon != null ? Icon(icon) : null,
        title: Text(name),
        trailing: DropdownButton(
          items: LanguageCodes.values
              .map(
                (e) => DropdownMenuItem(
                  value: e,
                  child: Text(e.nativeName),
                ),
              )
              .toList(),
          value: setting.value,
          onChanged: (val) {
            if (val == null) {
              setting.clear();
              return;
            }
            setting.setvalue(val).then((value) => update());
          },
        ),
      ),
    );
  }
}

class TitleTile extends Tile {
  const TitleTile(super.name, super.description, {super.icon});

  @override
  Widget render(BuildContext context, Function update) {
    return Padding(
      padding: const EdgeInsets.all(10),
      child: Tooltip(
        message: description,
        child: Text(
          name,
          style: TextStyle(
              color: Theme.of(context).colorScheme.primary, fontSize: 20,),
        ),
      ),
    );
  }
}

class Choice<T> {
  final IconData? icon;
  final String name;
  final T value;
  const Choice(this.name, this.value, {this.icon});
}

class SortingTile extends Tile {
  final List<Choice<String>> choices;
  final Setting<String> choice;
  final Setting<bool> descending;
  const SortingTile(
    super.name,
    super.description,
    this.choice,
    this.descending,
    this.choices,
  );

  @override
  Widget render(BuildContext context, Function update) {
    return Tooltip(
      message: description,
      child: ListTile(
        leading: const Icon(Icons.sort),
        title: const Text('Sort'),
        isThreeLine: true,
        subtitle: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: choices.map((e) => sorttile(e, update)).toList(),
        ),
      ),
    );
  }

  Widget sorttile(Choice<String> c, Function update) {
    const double siz = 30;
    return GestureDetector(
      onTap: () {
        if (c.value == choice.value) {
          descending.setvalue(!descending.value).then((value) => update());
          return;
        }
        choice.setvalue(c.value).then((value) => update());
      },
      child: SizedBox(
        height: siz,
        child: Row(
          children: [
            if (c.value == choice.value)
              Icon(
                descending.value ? Icons.arrow_downward : Icons.arrow_upward,
                size: siz - 3,
              )
            else
              const SizedBox(
                width: siz - 3,
              ),
            Expanded(
              child: Text(
                c.name,
                style: const TextStyle(fontSize: siz / 2),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class CategoryTile extends Tile {
  const CategoryTile(super.name, super.description, {super.icon});

  @override
  Widget render(BuildContext context, Function update) {
    return Tooltip(
      message: description,
      child: FutureBuilder(
        future: isar.categorys.where().anyId().findAll(),
        builder: (context, snapshot) {
          if (snapshot.data == null) {
            return const ListTile(
              title: CircularProgressIndicator(),
            );
          }
          return ListTile(
            title: const Text('Categories'),
            // isThreeLine: true,
            leading: IconButton(
              icon: const Icon(Icons.add),
              onPressed: () => isar
                  .writeTxn(
                () => isar.categorys.put(
                  Category()..name = 'Category ${Random().nextInt(999)}',
                ),
              )
                  .then((value) {
                update();
              }),
            ),
            subtitle: ListView.builder(
              shrinkWrap: true,
              itemCount: snapshot.data!.length,
              itemBuilder: (context, index) {
                final Category c = snapshot.data![index];
                return ListTile(
                  title: Row(
                    children: [
                      Expanded(child: Text(c.name)),
                      IconButton(
                        onPressed: () => isar
                            .writeTxn(() => isar.categorys.delete(c.id))
                            .then((value) => update()),
                        icon: const Icon(Icons.delete),
                      ),
                      IconButton(
                        onPressed: () {
                          showDialog(
                            context: context,
                            builder: (context) {
                              return AlertDialog(
                                title: const Text('Edit:'),
                                content: TextField(
                                  controller:
                                      TextEditingController(text: c.name),
                                  onSubmitted: (value) => isar
                                      .writeTxn(
                                        () =>
                                            isar.categorys.put(c..name = value),
                                      )
                                      .then((value) => update()),
                                ),
                              );
                            },
                          );
                        },
                        icon: const Icon(Icons.edit),
                      ),
                    ],
                  ),
                );
              },
            ),
          );
        },
      ),
    );
  }
}

//=============================================================================
//=====================================PAGE====================================
//=============================================================================

class _SettingsPage extends StatefulWidget {
  final List<Tile> settings;
  final Function? onupdate;
  final String title;
  final bool bare;

  final bool nested;
  const _SettingsPage(
    this.title,
    this.settings,
    this.onupdate, {
    this.bare = false,
    this.nested = false,
  });

  @override
  State<_SettingsPage> createState() => _SettingsPageState();
}

class _SettingsPageState extends State<_SettingsPage> {
  void update() {
    if (widget.onupdate != null) {
      widget.onupdate?.call();
    }
    setState(() {});
  }

  @override
  Widget build(BuildContext context) {
    if (widget.settings.isEmpty) {
      return Container();
    }
    if (widget.bare) {
      // print(context.size?.height);
      return ListView.builder(
        shrinkWrap: widget.nested,
        itemCount: widget.settings.length,
        itemBuilder: (context, index) {
          return widget.settings[index].render(context, update);
        },
      );
    }
    return Scaffold(
      appBar: AppBar(
        title: Text(widget.title),
      ),
      body: ListView.builder(
        itemCount: widget.settings.length,
        itemBuilder: (context, index) =>
            widget.settings[index].render(context, update),
      ),
    );
  }
}

class SettingPageBuilder {
  final String title;
  final List<Tile> settings;

  const SettingPageBuilder(this.title, this.settings);

  Widget build(Function? update) {
    return _SettingsPage(title, settings, update);
  }

  Widget barebuild(Function? update, {bool nested = false}) {
    return _SettingsPage(title, settings, update, bare: true, nested: nested);
  }
}

class ExtensionSettingPageBuilder extends SettingPageBuilder {
  final Extension extension;
  final SettingType type;
  final EntryDetail? entry;

  ExtensionSettingPageBuilder(this.extension, this.type, {this.entry})
      : super(
          extension.data!.name,
          extension.settings.entries
              .where((e) {
                return e.value['type'] == type.name();
              })
              .map((e) => buildsetting(e.key, e.value, extension, entry))
              .toList(),
        );

  static Tile buildsetting(
      String name, dynamic value, Extension extension, EntryDetail? entry,) {
    if (value['ui'] != null) {
      return displayui(value['ui'], value, name, extension, entry);
    }
    if (value['def'] is bool) {
      return displayui({'type': 'checkbox'}, value, name, extension, entry);
    }
    if (value['def'] is String) {
      return displayui({'type': 'textbox'}, value, name, extension, entry);
    }
    if (value['def'] is int || value['def'] is double) {
      return displayui({'type': 'numberbox'}, value, name, extension, entry);
    }
    return TitleTile('Unknown $name', 'Unknown Setting');
  }

  static ExtensionSetting<T> getSetting<T>(
    String name,
    Extension extension,
    EntryDetail? entry,
  ) =>
      switch (entry) {
        final EntryDetail e => EntryExtensionSetting<T>(name, extension, e),
        _ => ExtensionSetting<T>(name, extension),
      };

  static Tile displayui(
    dynamic ui,
    dynamic value,
    String name,
    Extension extension,
    EntryDetail? entry,
  ) {
    return switch ((ui['type'] as String).toLowerCase()) {
      'slider' => DoubleTile(
          (value['name'] as String?) ?? name,
          (ui['description'] as String?) ?? '',
          getSetting(name, extension, entry),
        ),
      'checkbox' => BooleanTile(
          (value['name'] as String?) ?? name,
          (ui['description'] as String?) ?? '',
          getSetting(name, extension, entry),
        ),
      'dropdown' => ChoiceTile(
          (value['name'] as String?) ?? name,
          (ui['description'] as String?) ?? '',
          getSetting(name, extension, entry),
          choices: (ui['choices'] as List<dynamic>)
              .map((e) => Choice(e['name'] as String, e['value'] as String))
              .toList(),
        ),
      'textbox' => TextTile(
          (value['name'] as String?) ?? name,
          (ui['description'] as String?) ?? '',
          getSetting(name, extension, entry),
          hint: (ui['hint'] as String?) ?? '',
        ),
      _ => TitleTile('Unknown $name', 'Unknown Setting'),
    };
  }
}

class TextTile extends SettingTile<String> {
  final String? hint;
  const TextTile(super.name, super.description, super.setting,
      {super.icon, this.hint,});

  @override
  Widget render(BuildContext context, Function update) {
    final controller = TextEditingController(text: setting.value);
    return Tooltip(
      message: description,
      child: ListTile(
        // isThreeLine: true,
        // subtitle: Text(setting.value),
        leading: icon != null ? Icon(icon) : null,
        title: Row(
          children: [
            Padding(padding: const EdgeInsets.all(10),child: Text(name),),
            SizedBox(
              // height: 50,
              width: MediaQuery.of(context).size.width * 0.9 -
                  getTextSize(name, null).width-20,
              child: TextField(
                controller: controller,
                onEditingComplete: () =>
                    setting.setvalue(controller.text).then((value) => update()),
                onSubmitted: (value) =>
                    setting.setvalue(controller.text).then((value) => update()),
                onTapOutside: (event) =>
                    setting.setvalue(controller.text).then((value) => update()),
                decoration: InputDecoration(
                  hintText: hint,
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}
