import 'dart:convert';

/// Reads [path] from [json]: an exact key first, then a dotted path
/// (`android.minimum_version`).
Object? readPath(Map<String, dynamic> json, String path) {
  if (json.containsKey(path)) return json[path];
  Object? value = json;
  for (final part in path.split('.')) {
    if (value is! Map) return null;
    value = value[part];
  }
  return value;
}

/// An immutable snapshot of the remote key/value pairs with typed getters.
///
/// Every getter takes a key or a dotted path and falls back to the given
/// default when the value is missing, blank or of the wrong type.
class RemoteValues {
  RemoteValues([Map<String, dynamic> values = const {}])
    : _values = _freeze(values) as Map<String, dynamic>;

  final Map<String, dynamic> _values;

  Map<String, dynamic> toJson() => _values;

  Object? raw(String path) => readPath(_values, path);

  bool has(String path) => raw(path) != null;

  String string(String path, [String fallback = '']) {
    final value = raw(path);
    return value is String && value.trim().isNotEmpty ? value.trim() : fallback;
  }

  bool boolean(String path, [bool fallback = false]) => switch (raw(path)) {
    bool value => value,
    'true' || '1' => true,
    'false' || '0' => false,
    _ => fallback,
  };

  num number(String path, [num fallback = 0]) {
    final value = raw(path);
    return value is num ? value : num.tryParse('$value') ?? fallback;
  }

  /// An object or list, given either as JSON or as an encoded JSON string.
  Object? json(String path, [Object? fallback]) {
    final value = raw(path);
    if (value is! String) return value ?? fallback;
    try {
      return jsonDecode(value);
    } on FormatException {
      return fallback;
    }
  }
}

Object? _freeze(Object? value) {
  if (value is Map) {
    return Map<String, dynamic>.unmodifiable(
      value.map((key, value) => MapEntry('$key', _freeze(value))),
    );
  }
  if (value is List) return List<Object?>.unmodifiable(value.map(_freeze));
  return value;
}
