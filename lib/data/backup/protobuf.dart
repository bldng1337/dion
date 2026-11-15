import 'dart:convert';
import 'dart:typed_data';

/// Decodes the protobuf wire format without generated message classes.
///
/// Foreign backups are written by kotlinx-serialization from annotated Kotlin
/// classes rather than `.proto` files, so messages are read field by field
/// against the field numbers of those classes.
class ProtoMessage {
  final Map<int, List<ProtoValue>> _fields;

  ProtoMessage._(this._fields);

  factory ProtoMessage.decode(Uint8List bytes) {
    final fields = <int, List<ProtoValue>>{};
    final reader = _ProtoReader(bytes);
    while (!reader.isDone) {
      final key = reader.readVarint();
      final number = key >>> 3;
      final value = switch (key & 0x7) {
        0 => ProtoValue._varint(reader.readVarint()),
        1 => ProtoValue._fixed(reader.readFixed(8)),
        2 => ProtoValue._bytes(reader.readBytes(reader.readVarint())),
        5 => ProtoValue._fixed(reader.readFixed(4)),
        final wireType => throw FormatException(
          'Unsupported protobuf wire type $wireType for field $number',
        ),
      };
      (fields[number] ??= []).add(value);
    }
    return ProtoMessage._(fields);
  }

  bool has(int field) => _fields.containsKey(field);

  ProtoValue? _last(int field) => _fields[field]?.last;

  int? int64(int field) => _last(field)?.asInt;

  int int64Or(int field, int fallback) => int64(field) ?? fallback;

  bool? boolean(int field) {
    final value = int64(field);
    return value == null ? null : value != 0;
  }

  String? string(int field) => _last(field)?.asString;

  ProtoMessage? message(int field) => _last(field)?.asMessage;

  List<String> strings(int field) => [
    for (final value in _fields[field] ?? const <ProtoValue>[]) value.asString,
  ];

  List<ProtoMessage> messages(int field) => [
    for (final value in _fields[field] ?? const <ProtoValue>[]) value.asMessage,
  ];

  /// Repeated integers, accepting both packed and unpacked encodings.
  List<int> int64s(int field) => [
    for (final value in _fields[field] ?? const <ProtoValue>[])
      ...value.asPackedInts,
  ];
}

class ProtoValue {
  final int? _int;
  final Uint8List? _bytes;

  const ProtoValue._varint(int value) : _int = value, _bytes = null;
  const ProtoValue._fixed(int value) : _int = value, _bytes = null;
  const ProtoValue._bytes(Uint8List value) : _int = null, _bytes = value;

  int get asInt =>
      _int ?? (throw const FormatException('Expected a numeric field'));

  Uint8List get asBytes =>
      _bytes ??
      (throw const FormatException('Expected a length-delimited field'));

  String get asString => utf8.decode(asBytes, allowMalformed: true);

  ProtoMessage get asMessage => ProtoMessage.decode(asBytes);

  Iterable<int> get asPackedInts sync* {
    final bytes = _bytes;
    if (bytes == null) {
      yield asInt;
      return;
    }
    final reader = _ProtoReader(bytes);
    while (!reader.isDone) {
      yield reader.readVarint();
    }
  }
}

class _ProtoReader {
  final Uint8List _bytes;
  int _offset = 0;

  _ProtoReader(this._bytes);

  bool get isDone => _offset >= _bytes.length;

  int _next() {
    if (_offset >= _bytes.length) {
      throw const FormatException('Truncated protobuf message');
    }
    return _bytes[_offset++];
  }

  int readVarint() {
    var result = 0;
    for (var shift = 0; shift < 64; shift += 7) {
      final byte = _next();
      result |= (byte & 0x7f) << shift;
      if (byte & 0x80 == 0) return result;
    }
    throw const FormatException('Malformed protobuf varint');
  }

  int readFixed(int length) {
    var result = 0;
    for (var i = 0; i < length; i++) {
      result |= _next() << (8 * i);
    }
    return result;
  }

  Uint8List readBytes(int length) {
    if (length < 0 || _offset + length > _bytes.length) {
      throw const FormatException('Truncated protobuf message');
    }
    final view = Uint8List.sublistView(_bytes, _offset, _offset + length);
    _offset += length;
    return view;
  }
}
