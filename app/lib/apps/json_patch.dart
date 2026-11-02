/// JSON Pointer (RFC 6901) and the JSON Patch (RFC 6902) operations an
/// action returns, over plain decoded JSON (maps, lists and values).
library;

/// The segments of [pointer]: `/todos/0/title` → `todos`, `0`, `title`.
List<String> pointerSegments(String pointer) {
  if (pointer.isEmpty) return const [];
  return pointer
      .substring(1)
      .split('/')
      .map((it) => it.replaceAll('~1', '/').replaceAll('~0', '~'))
      .toList();
}

/// The value at [pointer] in [document], or null when there is none.
Object? valueAt(Object? document, String pointer) {
  var node = document;
  for (final segment in pointerSegments(pointer)) {
    if (node is Map) {
      node = node[segment];
    } else if (node is List) {
      final index = int.tryParse(segment);
      if (index == null || index < 0 || index >= node.length) return null;
      node = node[index];
    } else {
      return null;
    }
  }
  return node;
}

/// A deep copy of [value], so a patch never touches what a widget holds.
Object? deepCopy(Object? value) => switch (value) {
  final Map<dynamic, dynamic> map => {
    for (final entry in map.entries) '${entry.key}': deepCopy(entry.value),
  },
  final List<dynamic> list => [for (final item in list) deepCopy(item)],
  _ => value,
};

/// [document] with [operations] applied, as a new document.
///
/// Throws a [FormatException] on an operation it cannot apply; the caller
/// then reloads the app from the server.
Map<String, dynamic> applyPatch(
  Map<String, dynamic> document,
  List<dynamic> operations,
) {
  final root = deepCopy(document)! as Map<String, dynamic>;
  for (final raw in operations) {
    final op = raw as Map<String, dynamic>;
    final path = op['path'] as String;
    switch (op['op']) {
      case 'add':
        _set(root, path, deepCopy(op['value']), insert: true);
      case 'replace':
        _set(root, path, deepCopy(op['value']), insert: false);
      case 'remove':
        _remove(root, path);
      case 'move':
        final from = op['from'] as String;
        final value = valueAt(root, from);
        _remove(root, from);
        _set(root, path, value, insert: true);
      case 'copy':
        _set(
          root,
          path,
          deepCopy(valueAt(root, op['from'] as String)),
          insert: true,
        );
      case 'test':
        break;
      default:
        throw FormatException('unknown op ${op['op']}');
    }
  }
  return root;
}

(Object, String) _parent(Map<String, dynamic> root, String path) {
  final segments = pointerSegments(path);
  if (segments.isEmpty) throw const FormatException('cannot patch the root');
  final parentPointer = path.substring(0, path.lastIndexOf('/'));
  final parent = valueAt(root, parentPointer);
  if (parent == null) throw FormatException('no parent for $path');
  return (parent, segments.last);
}

void _set(
  Map<String, dynamic> root,
  String path,
  Object? value, {
  required bool insert,
}) {
  final (parent, key) = _parent(root, path);
  if (parent is Map) {
    parent[key] = value;
  } else if (parent is List) {
    if (key == '-') {
      parent.add(value);
      return;
    }
    final index = int.parse(key);
    if (insert) {
      parent.insert(index, value);
    } else {
      parent[index] = value;
    }
  } else {
    throw FormatException('cannot set $path');
  }
}

void _remove(Map<String, dynamic> root, String path) {
  final (parent, key) = _parent(root, path);
  if (parent is Map) {
    parent.remove(key);
  } else if (parent is List) {
    parent.removeAt(int.parse(key));
  } else {
    throw FormatException('cannot remove $path');
  }
}
