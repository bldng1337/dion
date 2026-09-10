import 'package:dionysos/data/settings/settings.dart';
import 'package:dionysos/widgets/settings/setting_dropdown.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

class _FakeEnumMetaData extends EnumMetaData<String> {
  // Long enough that its intrinsic text width exceeds the tile width below;
  // this reproduces the gutenberg shelf dropdown overflowing the search
  // settings popup.
  static const String longLabel =
      'Out of copyright books in languages other than English and French';

  @override
  List<EnumValue<String>> get values => const [
    EnumValue('popular', 'popular'),
    EnumValue(longLabel, 'long'),
  ];

  @override
  String getLabel(String value) =>
      values.where((e) => e.value == value).first.name;
}

void main() {
  testWidgets('SettingDropdown does not overflow narrow containers', (
    tester,
  ) async {
    final setting = Setting<String, EnumMetaData<String>>(
      'popular',
      _FakeEnumMetaData(),
    );
    await tester.pumpWidget(
      MaterialApp(
        home: Scaffold(
          body: Center(
            // Width of the dropdown tile inside the search settings popup.
            child: SizedBox(
              width: 386,
              child: SettingDropdown<String>(
                setting: setting,
                title: 'Browse collection',
              ),
            ),
          ),
        ),
      ),
    );
    await tester.pumpAndSettle();
  });
}
