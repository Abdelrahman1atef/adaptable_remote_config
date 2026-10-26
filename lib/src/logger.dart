import 'dart:convert';

import 'package:flutter/foundation.dart';

/// Prints what the controller fetched and decided, in boxes, the way Dio's
/// `LogInterceptor` prints requests. Off by default: pass one to
/// `RemoteConfigController(log: ...)` to turn it on.
///
/// ```dart
/// RemoteConfigController(
///   ...,
///   log: kDebugMode ? const RemoteConfigLogger() : null, // debug builds only
/// )
/// ```
///
/// Values whose key looks like a secret (`token`, `secret`, `password`,
/// `api_key`) are printed as `***`. Add more with [hideKeys].
class RemoteConfigLogger {
  const RemoteConfigLogger({
    this.values = true,
    this.decision = true,
    this.errors = true,
    this.actions = true,
    this.hideKeys = const {},
    this.maxValueLength = 120,
    this.print,
  });

  /// Print every key and value that was fetched or restored.
  final bool values;

  /// Print what the app will show (wall, dialog or nothing) and why.
  final bool decision;

  /// Print errors and rejected (ignored) values.
  final bool errors;

  /// Print the user's taps: Update, Later, Skip.
  final bool actions;

  /// Keys whose value is printed as `***`.
  final Set<String> hideKeys;

  /// Longer values are cut with `…`.
  final int maxValueLength;

  /// Where lines go. Default: `debugPrint`. Use it to send logs to your own
  /// logger, for example `print: Log.info`.
  final void Function(String line)? print;

  static final _secret = RegExp(
    r'(secret|token|password|passwd|api[_-]?key)',
    caseSensitive: false,
  );

  /// One box with a [title] and [lines].
  void box(String title, List<String> lines) {
    final out = print ?? debugPrint;
    out('╔═ adaptable_remote_config · $title');
    for (final line in lines) {
      out('║ $line');
    }
    out('╚${'═' * 40}');
  }

  /// `key = value` lines, sorted and aligned, with secrets hidden.
  List<String> describeValues(Map<String, dynamic> map) {
    final keys = map.keys.toList()..sort();
    final width = keys.fold<int>(0, (m, k) => k.length > m ? k.length : m);
    return [
      for (final key in keys)
        '${key.padRight(width)} = ${_show(key, map[key])}',
    ];
  }

  String _show(String key, Object? value) {
    if (hideKeys.contains(key) || _secret.hasMatch(key)) return '"***"';
    final text = value is String ? '"$value"' : jsonEncode(value);
    if (text.length <= maxValueLength) return text;
    return '${text.substring(0, maxValueLength)}… (${text.length} chars)';
  }
}
