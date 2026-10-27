import 'dart:io';

import 'windows_console.dart';

/// One selectable option.
class Choice<T> {
  const Choice(this.label, this.value, {this.hint = '', this.provides = const []});

  final String label;
  final T value;
  final String hint;

  /// What this option gives you, one short line each. The menu lists them under
  /// the option the cursor is on.
  final List<String> provides;
}

/// Asks the questions. The terminal version is below; tests use a scripted one.
abstract class Prompter {
  T select<T>(String question, List<Choice<T>> options, {int initial = 0});

  List<T> multiSelect<T>(
    String question,
    List<Choice<T>> options, {
    Set<T> initial = const {},
  });

  String input(
    String question, {
    String defaultValue = '',
    String? Function(String value)? validate,
  });

  bool confirm(String question, {bool defaultValue = true});
}

enum _Key { up, down, enter, space, abort, other }

/// Arrow keys + Enter in a real terminal, numbered lines otherwise.
class TerminalPrompter implements Prompter {
  /// The parameters exist so tests can drive the prompter with fake keys.
  TerminalPrompter({
    int Function()? readByte,
    StringSink? sink,
    bool? interactive,
    void Function()? onAbort,
  }) : _readByte = readByte ?? stdin.readByteSync,
       _out = sink ?? stdout,
       _forced = interactive,
       _real = readByte == null,
       _onAbort = onAbort;

  final int Function() _readByte;
  final StringSink _out;
  final bool? _forced;
  final bool _real;
  final void Function()? _onAbort;

  bool get _interactive =>
      _forced ??
      (stdin.hasTerminal && stdout.hasTerminal && stdout.supportsAnsiEscapes);

  String get _reset => _interactive ? '\x1B[0m' : '';
  String get _cyan => _interactive ? '\x1B[36m' : '';
  String get _green => _interactive ? '\x1B[32m' : '';
  String get _dim => _interactive ? '\x1B[2m' : '';
  String get _bold => _interactive ? '\x1B[1m' : '';

  @override
  T select<T>(String question, List<Choice<T>> options, {int initial = 0}) {
    final picked = _choose(question, options, {initial}, multi: false);
    return options[picked.first].value;
  }

  @override
  List<T> multiSelect<T>(
    String question,
    List<Choice<T>> options, {
    Set<T> initial = const {},
  }) {
    final start = {
      for (var i = 0; i < options.length; i++)
        if (initial.contains(options[i].value)) i,
    };
    final picked = _choose(question, options, start, multi: true);
    return [for (final i in picked) options[i].value];
  }

  @override
  String input(
    String question, {
    String defaultValue = '',
    String? Function(String value)? validate,
  }) {
    final suffix = defaultValue.isEmpty ? '' : ' $_dim($defaultValue)$_reset';
    while (true) {
      _out.write('$_cyan?$_reset $_bold$question$_reset$suffix ');
      final line = stdin.readLineSync()?.trim();
      if (line == null) _abort();
      final value = line.isEmpty ? defaultValue : line;
      final error = validate?.call(value);
      if (error == null) return value;
      _out.writeln('  $error');
    }
  }

  @override
  bool confirm(String question, {bool defaultValue = true}) {
    final hint = defaultValue ? 'Y/n' : 'y/N';
    while (true) {
      _out.write('$_cyan?$_reset $_bold$question$_reset $_dim($hint)$_reset ');
      final line = stdin.readLineSync()?.trim().toLowerCase();
      if (line == null) _abort();
      if (line.isEmpty) return defaultValue;
      if (line == 'y' || line == 'yes') return true;
      if (line == 'n' || line == 'no') return false;
    }
  }

  /// Draws the list and moves a cursor. Returns the chosen indexes.
  List<int> _pick<T>(
    String question,
    List<Choice<T>> options,
    Set<int> start,
    void Function() restore, {
    required bool multi,
  }) {
    var cursor = start.isEmpty ? 0 : start.first;
    final chosen = {...start};
    final keys = multi ? 'space select, enter confirm' : 'enter select';
    var drawn = 0;

    void draw() {
      if (drawn > 0) _out.write('\x1B[${drawn}A\r\x1B[J');
      _out.writeln('$_cyan?$_reset $_bold$question$_reset $_dim($keys)$_reset');
      for (var i = 0; i < options.length; i++) {
        final on = i == cursor;
        final mark = multi ? (chosen.contains(i) ? '[x] ' : '[ ] ') : '';
        final hint = options[i].hint.isEmpty ? '' : ' $_dim${options[i].hint}$_reset';
        final line = '${on ? '>' : ' '} $mark${options[i].label}';
        _out.writeln(on ? '$_cyan$line$_reset$hint' : '$line$hint');
        if (on) {
          for (final item in options[i].provides) {
            _out.writeln('      $_dim+ $item$_reset');
          }
        }
      }
      drawn = options.length + 1 + options[cursor].provides.length;
    }

    try {
      draw();
      while (true) {
        switch (_readKey()) {
          case _Key.up:
            cursor = (cursor - 1 + options.length) % options.length;
          case _Key.down:
            cursor = (cursor + 1) % options.length;
          case _Key.space:
            if (multi && !chosen.remove(cursor)) chosen.add(cursor);
          case _Key.enter:
            if (!multi) chosen..clear()..add(cursor);
            if (chosen.isEmpty && multi) break;
            _out.write('\x1B[${drawn}A\r\x1B[J');
            final names = [for (final i in chosen.toList()..sort()) options[i].label];
            _out.writeln(
              '$_green+$_reset $_bold$question$_reset ${names.join(', ')}',
            );
            return chosen.toList()..sort();
          case _Key.abort:
            restore();
            _abort();
          case _Key.other:
            break;
        }
        draw();
      }
    } finally {
      restore();
    }
  }

  /// Arrow-key menu when raw keyboard input is available, numbered otherwise.
  List<int> _choose<T>(
    String question,
    List<Choice<T>> options,
    Set<int> start, {
    required bool multi,
  }) {
    if (_interactive) {
      final restore = _enterRaw();
      if (restore != null) {
        return _pick(question, options, start, restore, multi: multi);
      }
    }
    return _numbered(question, options, start, multi: multi);
  }

  /// Turns off line buffering and echo so single key presses can be read.
  /// Returns the function that undoes it, or null when that is not possible.
  void Function()? _enterRaw() {
    if (!_real) return () {};
    if (Platform.isWindows) return WindowsConsoleMode.enterRaw()?.restore;
    final echo = stdin.echoMode;
    final line = stdin.lineMode;
    void restore() {
      stdin.echoMode = echo;
      stdin.lineMode = line;
    }

    try {
      stdin.echoMode = false;
      stdin.lineMode = false;
      return restore;
    } on StdinException {
      try {
        restore();
      } on StdinException {
        // Nothing more can be done.
      }
      return null;
    }
  }

  _Key _readKey() {
    final byte = _readByte();
    if (byte == -1 || byte == 3) return _Key.abort;
    if (byte == 13 || byte == 10) return _Key.enter;
    if (byte == 32) return _Key.space;
    if (byte == 107) return _Key.up; // k
    if (byte == 106) return _Key.down; // j
    if (byte == 27) {
      final next = _readByte();
      if (next != 91 && next != 79) return _Key.other;
      return switch (_readByte()) {
        65 => _Key.up,
        66 => _Key.down,
        _ => _Key.other,
      };
    }
    if (byte == 224 || byte == 0) {
      return switch (_readByte()) {
        72 => _Key.up,
        80 => _Key.down,
        _ => _Key.other,
      };
    }
    return _Key.other;
  }

  /// Plain numbered list for pipes, CI and consoles without ANSI support.
  List<int> _numbered<T>(
    String question,
    List<Choice<T>> options,
    Set<int> start, {
    required bool multi,
  }) {
    _out.writeln('? $question');
    for (var i = 0; i < options.length; i++) {
      final hint = options[i].hint.isEmpty ? '' : '  (${options[i].hint})';
      _out.writeln('  ${i + 1}) ${options[i].label}$hint');
      for (final item in options[i].provides) {
        _out.writeln('       + $item');
      }
    }
    final fallback = (start.toList()..sort()).map((i) => i + 1).join(',');
    final prompt = multi ? 'numbers, comma separated' : 'number';
    while (true) {
      _out.write('  $prompt [${fallback.isEmpty ? '1' : fallback}]: ');
      final line = stdin.readLineSync()?.trim();
      if (line == null) _abort();
      final text = line.isEmpty ? (fallback.isEmpty ? '1' : fallback) : line;
      final picked = <int>{};
      for (final part in text.split(',')) {
        final n = int.tryParse(part.trim());
        if (n != null && n >= 1 && n <= options.length) picked.add(n - 1);
      }
      if (picked.isNotEmpty && (multi || picked.length == 1)) {
        return picked.toList()..sort();
      }
    }
  }

  Never _abort() {
    _out.writeln('\nCancelled.');
    _onAbort?.call();
    exit(130);
  }
}
