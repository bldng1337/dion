import 'dart:convert';

import 'package:dionysos/data/search_profile.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:rdion_runtime/rdion_runtime.dart' as rust;

rust.Setting _setting(rust.SettingValue value, {String label = 'Sort'}) =>
    rust.Setting(
      label: label,
      value: value,
      default_: value,
      visible: true,
      ui: const rust.SettingsUI.dropdown(
        options: [rust.DropdownOption(label: 'New', value: 'new')],
      ),
    );

void main() {
  test('profile settings survive a json round trip', () {
    final profile = SearchProfile(
      id: '1',
      name: 'Manga',
      enabled: const {'ext'},
      settings: {
        'ext': {'sort': _setting(const rust.SettingValue.string(data: 'top'))},
      },
    );

    final decoded = SearchProfile.fromJson(
      json.decode(json.encode(profile.toJson())) as Map<String, dynamic>,
    );

    expect(decoded, profile);
    expect(decoded.settings['ext']!['sort']!.ui, isNotNull);
  });

  test('profiles stored before settings existed load without them', () {
    final decoded = SearchProfile.fromJson({
      'id': '1',
      'name': 'Old',
      'enabled': ['ext'],
    });

    expect(decoded.settings, isEmpty);
  });

  test('stored values carry over onto returned definitions', () {
    final returned = {
      'sort': _setting(
        const rust.SettingValue.string(data: 'new'),
        label: 'Sort by',
      ),
      'nsfw': _setting(const rust.SettingValue.boolean(data: false)),
    };
    final stored = {
      'sort': _setting(const rust.SettingValue.string(data: 'top')),
      'nsfw': _setting(const rust.SettingValue.string(data: 'stale type')),
      'gone': _setting(const rust.SettingValue.string(data: 'x')),
    };

    final merged = mergeSearchSettingValues(returned, stored);

    expect(merged.keys, unorderedEquals(['sort', 'nsfw']));
    expect(merged['sort']!.label, 'Sort by');
    expect(merged['sort']!.value, const rust.SettingValue.string(data: 'top'));
    expect(
      merged['nsfw']!.value,
      const rust.SettingValue.boolean(data: false),
    );
  });
}
