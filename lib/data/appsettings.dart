import 'package:dionysos/utils/settings.dart';

final preferenceCollection = SettingCollection<dynamic, PreferenceMetaData>();

abstract class PreferenceMetaData<T> extends MetaData<T> {
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

enum ReaderMode {
  paginated,
}

final testset = Setting(true, const PreferenceBoolMetaData('test'))
    .addCollection(preferenceCollection);

final settings = (
  readerSettings: (
    paragraphreader: (
      mode: Setting(
        ReaderMode.paginated,
        const PreferenceEnumMetaData('paragraphreader.mode', ReaderMode.values),
      )..addCollection(preferenceCollection),
      title: Setting(
        true,
        const PreferenceBoolMetaData('paragraphreader.title'),
        )..addCollection(preferenceCollection),
      text: (
        adaptivewidth: Setting(
          true,
          const PreferenceBoolMetaData('paragraphreader.text.adaptivewidth'),
        )..addCollection(preferenceCollection),
        linewidth: Setting(
          10.0,
          const PreferenceDoubleMetaData('paragraphreader.text.linewidth'),
        )..addCollection(preferenceCollection),
        size: Setting(
          25,
          const PreferenceIntMetaData('paragraphreader.text.size'),
        )..addCollection(preferenceCollection),
        weight: Setting(
          0.1,
          const PreferenceDoubleMetaData('paragraphreader.text.weight'),
        )..addCollection(preferenceCollection),
        linespacing: Setting(
          1.5,
          const PreferenceDoubleMetaData('paragraphreader.text.linespacing'),
        )..addCollection(preferenceCollection),
        paragraphspacing: Setting(
          1.5,
          const PreferenceDoubleMetaData('paragraphreader.text.paragraphspacing'),
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
  )
);
