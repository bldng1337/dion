import 'dart:convert';
import 'dart:io';

import 'package:dionysos/data/settings/settings.dart';
import 'package:dionysos/service/preference.dart';
import 'package:dionysos/utils/log.dart';
import 'package:dionysos/utils/service.dart';
import 'package:pub_semver/pub_semver.dart';
import 'package:dionysos/data/font.dart';

final preferenceCollection = SettingCollection<dynamic, PreferenceMetaData>();

abstract class PreferenceMetaData<T> extends SettingMetaData<T> {
  final String id;
  @override
  const PreferenceMetaData(this.id);

  @override
  T initValue(T t) {
    final prefs = locate<PreferenceService>();
    try {
      final value = prefs.getString(id);
      if (value == null) return t;
      return parse(value) ?? t;
    } catch (e, stack) {
      logger.e('Error loading preference', error: e, stackTrace: stack);
      prefs.remove(id);
    }
    return t;
  }

  @override
  void onChange(T t) {
    final prefs = locate<PreferenceService>();
    try {
      prefs.setString(id, stringify(t));
    } catch (e, stack) {
      logger.e('Error saving preference $this', error: e, stackTrace: stack);
      prefs.remove(id);
    }
    super.onChange(t);
  }

  String stringify(T value);
  T? parse(String value);
}

class PreferenceBoolMetaData extends PreferenceMetaData<bool> {
  const PreferenceBoolMetaData(super.id);

  @override
  bool? parse(String value) => switch (value.toLowerCase()) {
    'true' => true,
    'false' => false,
    _ => null,
  };

  @override
  String stringify(bool value) => value ? 'true' : 'false';
}

class PreferenceIntMetaData extends PreferenceMetaData<int> {
  const PreferenceIntMetaData(super.id);

  @override
  int? parse(String value) => int.tryParse(value);

  @override
  String stringify(int value) => value.toString();
}

class PreferenceDoubleMetaData extends PreferenceMetaData<double> {
  const PreferenceDoubleMetaData(super.id);

  @override
  double? parse(String value) => double.tryParse(value);

  @override
  String stringify(double value) => value.toString();
}

class PreferenceFontMetaData extends PreferenceMetaData<Font> {
  const PreferenceFontMetaData(super.id);

  @override
  Font? parse(String value) {
    final map = json.decode(value) as Map<String, dynamic>;
    if (map.isEmpty) return null;
    return Font.fromJson(map);
  }

  @override
  String stringify(Font value) => json.encode(value.toJson());
}

class PreferenceEnumMetaData<T extends Enum> extends PreferenceMetaData<T>
    implements EnumMetaData<T> {
  final List<T> enumvalues;
  const PreferenceEnumMetaData(super.id, this.enumvalues);

  @override
  T? parse(String value) =>
      enumvalues.where((e) => e.name == value).firstOrNull;

  @override
  String stringify(T value) => value.name;

  @override
  List<EnumValue<T>> get values =>
      enumvalues.map((e) => EnumValue(e.name, e)).toList();

  @override
  String getLabel(T value) {
    return value.name;
  }
}

class PreferenceDirectoryMetaData extends PreferenceMetaData<Directory?> {
  const PreferenceDirectoryMetaData(super.id);

  @override
  Directory? parse(String value) => value == '' ? null : Directory(value);

  @override
  String stringify(Directory? value) => value?.absolute.path ?? '';
}

class VersionMetaData extends PreferenceMetaData<Version> {
  const VersionMetaData(super.id);

  @override
  Version parse(String value) => Version.parse(value);

  @override
  String stringify(Version value) => value.canonicalizedVersion;
}

class StringListMetaData extends PreferenceMetaData<List<String>> {
  const StringListMetaData(super.id);

  @override
  List<String> parse(String value) =>
      (json.decode(value) as List<dynamic>).cast<String>();

  @override
  String stringify(List<String> value) => json.encode(value);
}

enum ReaderMode { paginated, infinite }

enum UpdateChannel { stable, beta }

final settings = (
  extension: (
    repositories: Setting(
      <String>[],
      const StringListMetaData('extension.repositories'),
    )..addCollection(preferenceCollection),
  ),
  library: (
    showAllTab: Setting(false, const PreferenceBoolMetaData('library.showall'))
      ..addCollection(preferenceCollection),
    showNoneTab: Setting(true, const PreferenceBoolMetaData('library.shownone'))
      ..addCollection(preferenceCollection),
  ),
  audioBookSettings: (
    volume: Setting(50.0, const PreferenceDoubleMetaData('audiobook.volume'))
      ..addCollection(preferenceCollection),
    speed: Setting(1.0, const PreferenceDoubleMetaData('audiobook.speed'))
      ..addCollection(preferenceCollection),
    // subtitle: Setting( TODO
    //   true,
    //   const PreferenceBoolMetaData('audiobook.subtitle'),
    // ),
  ),
  update: (
    enabled: Setting(true, const PreferenceBoolMetaData('update.enabled'))
      ..addCollection(preferenceCollection),
    channel: Setting(
      UpdateChannel.beta,
      const PreferenceEnumMetaData('update.channel', UpdateChannel.values),
    )..addCollection(preferenceCollection),
    minor: Setting(true, const PreferenceBoolMetaData('update.minor'))
      ..addCollection(preferenceCollection),
    patch: Setting(true, const PreferenceBoolMetaData('update.patch'))
      ..addCollection(preferenceCollection),
    lastnotified: Setting(
      Version.none,
      const VersionMetaData('update.lastnotified'),
    ),
  ),
  sync: (
    enabled: Setting(true, const PreferenceBoolMetaData('sync.enabled'))
      ..addCollection(preferenceCollection),
    path: Setting(
      null as Directory?,
      const PreferenceDirectoryMetaData('sync.path'),
    )..addCollection(preferenceCollection),
  ),
  readerSettings: (
    imagelistreader: (
      mode: Setting(
        ReaderMode.paginated,
        const PreferenceEnumMetaData('imagelistreader.mode', ReaderMode.values),
      )..addCollection(preferenceCollection),
      adaptivewidth: Setting(
        true,
        const PreferenceBoolMetaData('paragraphreader.text.adaptivewidth'),
      )..addCollection(preferenceCollection),
      width: Setting(
        70.0,
        const PreferenceDoubleMetaData('paragraphreader.text.linewidth'),
      )..addCollection(preferenceCollection),
      music: Setting(
        true,
        const PreferenceBoolMetaData('paragraphreader.text.music'),
      )..addCollection(preferenceCollection),
      volume: Setting(
        50.0,
        const PreferenceDoubleMetaData('paragraphreader.text.volume'),
      )..addCollection(preferenceCollection),
    ),
    paragraphreader: (
      mode: Setting(
        ReaderMode.paginated,
        const PreferenceEnumMetaData('paragraphreader.mode', ReaderMode.values),
      )..addCollection(preferenceCollection),
      font: Setting(
        const Font(name: 'Roboto', type: FontType.google),
        const PreferenceFontMetaData('paragraphreader.font'),
      )..addCollection(preferenceCollection),
      title: Setting(
        false,
        const PreferenceBoolMetaData('paragraphreader.title'),
      )..addCollection(preferenceCollection),
      titleSettings: (
        size: Setting(
          24,
          const PreferenceIntMetaData('paragraphreader.title_settings.size'),
        )..addCollection(preferenceCollection),
        thumbBanner: Setting(
          true,
          const PreferenceBoolMetaData('paragraphreader.title_settings.banner'),
        )..addCollection(preferenceCollection),
      ),
      text: (
        adaptivewidth: Setting(
          true,
          const PreferenceBoolMetaData('paragraphreader.text.adaptivewidth'),
        )..addCollection(preferenceCollection),
        linewidth: Setting(
          70.0,
          const PreferenceDoubleMetaData('paragraphreader.text.linewidth'),
        )..addCollection(preferenceCollection),
        size: Setting(
          24,
          const PreferenceIntMetaData('paragraphreader.text.size'),
        )..addCollection(preferenceCollection),
        weight: Setting(
          0.4,
          const PreferenceDoubleMetaData('paragraphreader.text.weight'),
        )..addCollection(preferenceCollection),
        bionic: Setting(
          false,
          const PreferenceBoolMetaData('paragraphreader.text.bionic'),
        )..addCollection(preferenceCollection),
        bionicSettings: (
          bionicWheight: Setting(
            0.5,
            const PreferenceDoubleMetaData(
              'paragraphreader.text.bionic_settings.bionic_weight',
            ),
          )..addCollection(preferenceCollection),
          bionicSize: Setting(
            24,
            const PreferenceIntMetaData(
              'paragraphreader.text.bionic_settings.bionic_size',
            ),
          )..addCollection(preferenceCollection),
          letters: Setting(
            1,
            const PreferenceIntMetaData(
              'paragraphreader.text.bionic_settings.letters',
            ),
          )..addCollection(preferenceCollection),
        ),
        linespacing: Setting(
          1.5,
          const PreferenceDoubleMetaData('paragraphreader.text.linespacing'),
        )..addCollection(preferenceCollection),
        paragraphspacing: Setting(
          3.0,
          const PreferenceDoubleMetaData(
            'paragraphreader.text.paragraphspacing',
          ),
        )..addCollection(preferenceCollection),
        selectable: Setting(
          true,
          const PreferenceBoolMetaData('paragraphreader.text.selectable'),
        )..addCollection(preferenceCollection),
        bionicreading: Setting(
          true,
          const PreferenceBoolMetaData('paragraphreader.text.bionicreading'),
        )..addCollection(preferenceCollection),
        bionicweight: Setting(
          0.5,
          const PreferenceDoubleMetaData('paragraphreader.text.bionicweight'),
        )..addCollection(preferenceCollection),
      ),
    ),
  ),
);
