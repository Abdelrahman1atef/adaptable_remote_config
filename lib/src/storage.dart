import 'dart:convert';

import 'package:shared_preferences/shared_preferences.dart';

/// Persists JSON snapshots under controller-generated per-app keys.
abstract class ConfigStorage {
  Future<Map<String, dynamic>?> read(String key);
  Future<void> write(String key, Map<String, dynamic> value);
}

/// Useful for tests or explicitly session-only configuration.
class MemoryConfigStorage implements ConfigStorage {
  final Map<String, String> _values = {};
  @override
  Future<Map<String, dynamic>?> read(String key) async {
    final value = _values[key];
    return value == null ? null : jsonDecode(value) as Map<String, dynamic>;
  }

  @override
  Future<void> write(String key, Map<String, dynamic> value) async {
    _values[key] = jsonEncode(value);
  }
}

/// Default persistent cache and reminder storage backed by SharedPreferences.
class PreferencesConfigStorage implements ConfigStorage {
  @override
  Future<Map<String, dynamic>?> read(String key) async {
    final preferences = await SharedPreferences.getInstance();
    final value = preferences.getString(key);
    return value == null ? null : jsonDecode(value) as Map<String, dynamic>;
  }

  @override
  Future<void> write(String key, Map<String, dynamic> value) async {
    final preferences = await SharedPreferences.getInstance();
    if (!await preferences.setString(key, jsonEncode(value))) {
      throw StateError('Could not persist remote configuration');
    }
  }
}
