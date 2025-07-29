import 'dart:io';

import 'package:dionysos/utils/settings.dart';
import 'package:pub_semver/pub_semver.dart';

final preferenceCollection = SettingCollection<dynamic, PreferenceMetaData>();

abstract class PreferenceMetaData<T> extends SettingMetaData<T> {
  final String id;
  @override
  const PreferenceMetaData(this.id);

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

class PreferenceEnumMetaData<T extends Enum> extends PreferenceMetaData<T>
    implements EnumMetaData<T> {
  @override
  final List<T> enumvalues;
  const PreferenceEnumMetaData(super.id, this.enumvalues);

  @override
  T? parse(String value) =>
      enumvalues.where((e) => e.name == value).firstOrNull;

  @override
  String stringify(T value) => value.name;
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

enum ReaderMode { paginated }

enum UpdateChannel { stable, beta }

final settings = (
  audioBookSettings: (
    volume: Setting(50.0, const PreferenceDoubleMetaData('audiobook.volume')),
    speed: Setting(1.0, const PreferenceDoubleMetaData('audiobook.speed')),
    // subtitle: Setting( TODO
    //   true,
    //   const PreferenceBoolMetaData('audiobook.subtitle'),
    // ),
  ),
  update: (
    enabled: Setting(true, const PreferenceBoolMetaData('update.enabled')),
    channel: Setting(
      UpdateChannel.beta,
      const PreferenceEnumMetaData('update.channel', UpdateChannel.values),
    ),
    minor: Setting(true, const PreferenceBoolMetaData('update.minor')),
    patch: Setting(true, const PreferenceBoolMetaData('update.patch')),
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
      title: Setting(
        false,
        const PreferenceBoolMetaData('paragraphreader.title'),
      )..addCollection(preferenceCollection),
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
