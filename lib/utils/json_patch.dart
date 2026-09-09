/// Minimal JSON Patch (RFC 6902 subset) used to record entry-extension
/// changes.
///
/// [diffJson] descends into maps (so keys like `meta/<key>` compose across
/// extensions) but replaces lists and leaf values wholesale. Coarse
/// whole-field ops are deliberate: they survive being re-applied to a
/// slightly different document far better than index-level array edits.
library;

/// Returns the ops that transform [before] into [after]. [applyJsonPatch] on
/// [before] with the result yields a document equal to [after].
List<Map<String, dynamic>> diffJson(
  Map<String, dynamic> before,
  Map<String, dynamic> after,
) {
  final ops = <Map<String, dynamic>>[];
  _diffObject(before, after, '', ops);
  return ops;
}

/// Applies [ops] to [doc] in place. Throws [StateError] when an op addresses
/// a path that does not exist in [doc]; callers treat that as "stale patch".
Map<String, dynamic> applyJsonPatch(
  Map<String, dynamic> doc,
  List<Map<String, dynamic>> ops,
) {
  for (final op in ops) {
    final path = op['path'];
    if (path is! String) {
      throw StateError('Patch op without a path: $op');
    }
    final tokens = jsonPointerTokens(path);
    if (tokens.isEmpty) {
      throw StateError('Unsupported root patch path: $path');
    }
    final parent = resolvePointer(doc, tokens.sublist(0, tokens.length - 1));
    final key = tokens.last;
    final value = op['value'];
    switch (op['op']) {
      case 'add' || 'replace':
        if (parent is List) {
          final index = key == '-' ? parent.length : int.parse(key);
          if (index > parent.length) {
            throw StateError('Patch index $index out of bounds: $path');
          }
          if (op['op'] == 'add' && index == parent.length) {
            parent.add(value);
          } else {
            parent[index] = value;
          }
        } else if (parent is Map) {
          parent[key] = value;
        } else {
          throw StateError('Cannot patch into ${parent.runtimeType}: $path');
        }
      case 'remove':
        if (parent is List) {
          parent.removeAt(int.parse(key));
        } else if (parent is Map) {
          parent.remove(key);
        } else {
          throw StateError('Cannot patch into ${parent.runtimeType}: $path');
        }
      default:
        throw StateError('Unsupported patch op: ${op['op']}');
    }
  }
  return doc;
}

/// Deep equality for decoded JSON values; `Map`/`List` only compare with `==`
/// shallowly, which is not enough to detect unchanged fields while diffing.
bool jsonEquals(dynamic a, dynamic b) {
  if (identical(a, b)) return true;
  if (a is num && b is num) return a == b;
  if (a is Map && b is Map) {
    if (a.length != b.length) return false;
    return a.entries.every(
      (e) => b.containsKey(e.key) && jsonEquals(e.value, b[e.key]),
    );
  }
  if (a is List && b is List) {
    if (a.length != b.length) return false;
    for (var i = 0; i < a.length; i++) {
      if (!jsonEquals(a[i], b[i])) return false;
    }
    return true;
  }
  return a == b;
}

void _diffObject(
  Map<dynamic, dynamic> before,
  Map<dynamic, dynamic> after,
  String path,
  List<Map<String, dynamic>> ops,
) {
  for (final key in before.keys) {
    if (!after.containsKey(key)) {
      ops.add({'op': 'remove', 'path': '$path/${_escapeKey(key)}'});
    }
  }
  for (final entry in after.entries) {
    final keyPath = '$path/${_escapeKey(entry.key)}';
    if (!before.containsKey(entry.key)) {
      ops.add({'op': 'add', 'path': keyPath, 'value': entry.value});
      continue;
    }
    _diffValue(before[entry.key], entry.value, keyPath, ops);
  }
}

void _diffValue(
  dynamic before,
  dynamic after,
  String path,
  List<Map<String, dynamic>> ops,
) {
  if (jsonEquals(before, after)) return;
  if (before is Map && after is Map) {
    _diffObject(before, after, path, ops);
    return;
  }
  ops.add({'op': 'replace', 'path': path, 'value': after});
}

String _escapeKey(dynamic key) =>
    key.toString().replaceAll('~', '~0').replaceAll('/', '~1');

List<String> jsonPointerTokens(String pointer) => pointer
    .split('/')
    .skip(1)
    .map((t) => t.replaceAll('~1', '/').replaceAll('~0', '~'))
    .toList();

dynamic resolvePointer(dynamic doc, List<String> tokens) {
  var current = doc;
  for (final token in tokens) {
    if (current is List) {
      current = current[int.parse(token)];
    } else if (current is Map) {
      final next = current[token];
      if (next == null) {
        throw StateError('Patch path leads through missing key "$token"');
      }
      current = next;
    } else {
      throw StateError('Cannot descend into ${current.runtimeType}');
    }
  }
  return current;
}
