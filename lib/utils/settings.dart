import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';

class SettingCollection<T,M extends MetaData<T>> {
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
}

class Setting<T, M extends MetaData<T>> with ChangeNotifier {
  final M metadata;
  late T _value;
  final T _initialvalue;

  Setting(T initial, this.metadata) : _initialvalue = initial {
    _value = initial;
  }

  T get intialValue => _initialvalue;
  T get value => _value;
  set value(T v) {
    if (v == _value) return;
    notifyListeners();
    _value = v;
  }

  void addCollection<_T,_M extends MetaData<_T>>(SettingCollection<_T,_M> collection) {
    collection.add(this as Setting<_T,_M>);
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
    return ListenableBuilder(listenable: setting, builder: (context, child) => Visibility(visible: setting.value, child: this));
  }
}
