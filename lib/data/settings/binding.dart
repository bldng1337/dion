import 'package:flutter/services.dart';

enum InputZone {
  left,
  center,
  right,
  full;

  String get label => switch (this) {
    InputZone.left => 'Left',
    InputZone.center => 'Center',
    InputZone.right => 'Right',
    InputZone.full => 'Anywhere',
  };

  bool matches(InputZone detected) {
    if (this == InputZone.full) return true;
    return this == detected;
  }

  static InputZone fromPosition(Offset position, Size size) {
    if (size.width <= 0) return InputZone.center;
    final third = size.width / 3;
    if (position.dx < third) return InputZone.left;
    if (position.dx > third * 2) return InputZone.right;
    return InputZone.center;
  }
}

enum SwipeDirection {
  left,
  right,
  up,
  down;

  String get symbol => switch (this) {
    SwipeDirection.left => '←',
    SwipeDirection.right => '→',
    SwipeDirection.up => '↑',
    SwipeDirection.down => '↓',
  };

  String get label => switch (this) {
    SwipeDirection.left => 'Left',
    SwipeDirection.right => 'Right',
    SwipeDirection.up => 'Up',
    SwipeDirection.down => 'Down',
  };
}

sealed class InputBinding {
  const InputBinding();

  String get label;

  String get identifier;

  Map<String, dynamic> toJson();

  factory InputBinding.fromJson(Map<String, dynamic> json) {
    final type = json['type'] as String;
    return switch (type) {
      'key' => KeyBind._fromJson(json),
      'swipe' => SwipeGesture._fromJson(json),
      'tap' => TapGesture._fromJson(json),
      'longpress' => LongPressGesture._fromJson(json),
      _ => throw FormatException('Unknown InputBinding type: $type'),
    };
  }
}

class KeyBind extends InputBinding {
  final LogicalKeyboardKey key;
  final bool ctrl;
  final bool alt;
  final bool shift;
  final bool meta;

  const KeyBind(
    this.key, {
    this.ctrl = false,
    this.alt = false,
    this.shift = false,
    this.meta = false,
  });

  bool matchesKey(LogicalKeyboardKey pressed) {
    if (pressed.keyId != key.keyId) return false;
    final hk = HardwareKeyboard.instance;
    return hk.isControlPressed == ctrl &&
        hk.isAltPressed == alt &&
        hk.isShiftPressed == shift &&
        hk.isMetaPressed == meta;
  }

  @override
  String get label {
    final parts = <String>[
      if (ctrl) 'Ctrl',
      if (alt) 'Alt',
      if (shift) 'Shift',
      if (meta) 'Meta',
      _keySymbol(key),
    ];
    return parts.join(' + ');
  }

  @override
  String get identifier {
    final mods = <String>[
      if (ctrl) 'ctrl',
      if (alt) 'alt',
      if (shift) 'shift',
      if (meta) 'meta',
    ].join(',');
    return 'key:$mods:${key.keyId}';
  }

  @override
  Map<String, dynamic> toJson() => {
    'type': 'key',
    'keyId': key.keyId,
    if (ctrl) 'ctrl': true,
    if (alt) 'alt': true,
    if (shift) 'shift': true,
    if (meta) 'meta': true,
  };

  KeyBind._fromJson(Map<String, dynamic> json)
    : this(
        LogicalKeyboardKey.findKeyByKeyId((json['keyId'] as num).toInt()) ??
            LogicalKeyboardKey((json['keyId'] as num).toInt()),
        ctrl: json['ctrl'] as bool? ?? false,
        alt: json['alt'] as bool? ?? false,
        shift: json['shift'] as bool? ?? false,
        meta: json['meta'] as bool? ?? false,
      );
}

class SwipeGesture extends InputBinding {
  final SwipeDirection direction;
  final InputZone zone;

  const SwipeGesture(this.direction, {this.zone = InputZone.full});

  @override
  String get label {
    final base = 'Swipe ${direction.symbol}';
    return zone == InputZone.full ? base : '$base (${zone.label})';
  }

  @override
  String get identifier => 'swipe:${direction.name}:${zone.name}';

  @override
  Map<String, dynamic> toJson() => {
    'type': 'swipe',
    'direction': direction.name,
    'zone': zone.name,
  };

  SwipeGesture._fromJson(Map<String, dynamic> json)
    : this(
        SwipeDirection.values.byName(json['direction'] as String),
        zone: InputZone.values.byName(json['zone'] as String? ?? 'full'),
      );
}

class TapGesture extends InputBinding {
  final int count;
  final InputZone zone;

  const TapGesture(this.count, {this.zone = InputZone.full});

  @override
  String get label {
    final noun = switch (count) {
      1 => 'Tap',
      2 => 'Double Tap',
      3 => 'Triple Tap',
      _ => '${count}x Tap',
    };
    return zone == InputZone.full ? noun : '$noun (${zone.label})';
  }

  @override
  String get identifier => 'tap:$count:${zone.name}';

  @override
  Map<String, dynamic> toJson() => {
    'type': 'tap',
    'count': count,
    'zone': zone.name,
  };

  TapGesture._fromJson(Map<String, dynamic> json)
    : this(
        (json['count'] as num).toInt(),
        zone: InputZone.values.byName(json['zone'] as String? ?? 'full'),
      );
}

class LongPressGesture extends InputBinding {
  final InputZone zone;

  const LongPressGesture({this.zone = InputZone.full});

  @override
  String get label =>
      zone == InputZone.full ? 'Long Press' : 'Long Press (${zone.label})';

  @override
  String get identifier => 'longpress:${zone.name}';

  @override
  Map<String, dynamic> toJson() => {'type': 'longpress', 'zone': zone.name};

  LongPressGesture._fromJson(Map<String, dynamic> json)
    : this(zone: InputZone.values.byName(json['zone'] as String? ?? 'full'));
}

final Map<LogicalKeyboardKey, String> _keySymbols = {
  LogicalKeyboardKey.arrowLeft: '←',
  LogicalKeyboardKey.arrowRight: '→',
  LogicalKeyboardKey.arrowUp: '↑',
  LogicalKeyboardKey.arrowDown: '↓',
  LogicalKeyboardKey.enter: '↵',
  LogicalKeyboardKey.numpadEnter: '↵',
  LogicalKeyboardKey.space: 'Space',
  LogicalKeyboardKey.escape: 'Esc',
  LogicalKeyboardKey.backspace: '⌫',
  LogicalKeyboardKey.tab: '⇥',
  LogicalKeyboardKey.delete: 'Del',
  LogicalKeyboardKey.home: 'Home',
  LogicalKeyboardKey.end: 'End',
  LogicalKeyboardKey.pageUp: 'PgUp',
  LogicalKeyboardKey.pageDown: 'PgDn',
};

String _keySymbol(LogicalKeyboardKey key) {
  final known = _keySymbols[key];
  if (known != null) return known;
  final label = key.keyLabel.trim();
  return label.isEmpty ? (key.debugName ?? 'Key') : label;
}

bool isModifierKey(LogicalKeyboardKey key) => switch (key) {
  LogicalKeyboardKey.control ||
  LogicalKeyboardKey.controlLeft ||
  LogicalKeyboardKey.controlRight ||
  LogicalKeyboardKey.alt ||
  LogicalKeyboardKey.altLeft ||
  LogicalKeyboardKey.altRight ||
  LogicalKeyboardKey.shift ||
  LogicalKeyboardKey.shiftLeft ||
  LogicalKeyboardKey.shiftRight ||
  LogicalKeyboardKey.meta ||
  LogicalKeyboardKey.metaLeft ||
  LogicalKeyboardKey.metaRight ||
  LogicalKeyboardKey.fn => true,
  _ => false,
};
