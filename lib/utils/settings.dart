import 'package:dionysos/utils/log.dart';
import 'package:flutter/material.dart';

class SettingCollection<T, M extends MetaData<T>> {
  final List<Setting<T, M>> settings;
  SettingCollection() : settings = [];
  void add(Setting<T, M> s) {
    settings.add(s);
  }
}

abstract class EnumMetaData<T extends Enum> extends MetaData<T> {
  List<T> get enumvalues;
}

class MetaData<T> {
  const MetaData();
  void onChange(T t) {}
}

/*
* Typesafty gone too far :(
* needed because dart cant cast generics
*/
class SettingView<T, M extends MetaData<T>, WT, WM extends MetaData<WT>>
    implements Setting<T, M> {
  final Setting<WT, WM> setting;

  SettingView(this.setting);

  @override
  T get value => setting.value as T;

  @override
  set value(T v) {
    logger.i('Setting ${setting} to $v');
    setting.value = v as WT;
  }

  @override
  T get _value => setting._value as T;

  @override
  // TODO: implement _initialvalue
  T get _initialvalue => throw UnimplementedError();

  @override
  void addCollection<_T, _M extends MetaData<_T>>(
    SettingCollection<_T, _M> collection,
  ) {
    collection.add(this as Setting<_T, _M>);
  }

  @override
  void addListener(VoidCallback listener) {
    setting.addListener(listener);
  }

  @override
  Setting<T2, M2> cast<T2 extends T, M2 extends MetaData<T2>>() {
    return SettingView<T2, M2, T, M>(this);
  }

  @override
  void dispose() {
    setting.dispose();
  }

  @override
  bool get hasListeners => setting.hasListeners;

  @override
  T get intialValue => setting.intialValue as T;

  @override
  M get metadata => setting.metadata as M;

  @override
  void notifyListeners() {
    setting.notifyListeners();
  }

  @override
  void removeListener(VoidCallback listener) {
    setting.removeListener(listener);
  }

  @override
  set _value(T __value) {
    setting._value = __value as WT;
  }
}

class Setting<T, M extends MetaData<T>> with ChangeNotifier {
  final M metadata;
  late T _value;
  final T _initialvalue;

  Setting(T initial, this.metadata)
      : _initialvalue = initial,
        _value = initial;
  Setting.fromValue(T initial, T value, this.metadata)
      : _initialvalue = initial,
        _value = value;

  T get intialValue => _initialvalue;
  T get value => _value;
  set value(T v) {
    if (v == _value) return;
    metadata.onChange(v);
    _value = v;
    notifyListeners();
  }

  void addCollection<_T, _M extends MetaData<_T>>(
    SettingCollection<_T, _M> collection,
  ) {
    collection.add(this as Setting<_T, _M>);
  }

  Setting<T2, M2> cast<T2 extends T, M2 extends MetaData<T2>>() {
    return SettingView<T2, M2, T, M>(this);
  }

  @override
  String toString() {
    return value.toString();
  }

  @override
  bool operator ==(Object other) {
    return other is Setting<T, M> &&
        other.value == value &&
        other.metadata == metadata;
  }

  @override
  int get hashCode => Object.hash(value, metadata);
}

extension Settings on Widget {
  Widget conditional(Setting<bool, dynamic> setting) {
    return ListenableBuilder(
      listenable: setting,
      builder: (context, child) =>
          Visibility(visible: setting.value, child: this),
    );
  }
}
