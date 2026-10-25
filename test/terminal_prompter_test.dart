import 'package:adaptable_remote_config/src/cli/prompter.dart';
import 'package:flutter_test/flutter_test.dart';

const _esc = 27;
const _up = [_esc, 91, 65];
const _down = [_esc, 91, 66];
const _enter = [13];
const _space = [32];
const _ctrlC = [3];

class _Abort implements Exception {}

/// A prompter fed with raw key bytes, as a real terminal would send them.
({TerminalPrompter prompter, StringBuffer out}) _terminal(
  List<List<int>> keys,
) {
  final bytes = [for (final key in keys) ...key];
  final out = StringBuffer();
  final prompter = TerminalPrompter(
    readByte: () => bytes.isEmpty ? -1 : bytes.removeAt(0),
    sink: out,
    interactive: true,
    onAbort: () => throw _Abort(),
  );
  return (prompter: prompter, out: out);
}

const _options = [
  Choice('Firebase', 'firebase'),
  Choice('HTTP', 'http'),
  Choice('Custom', 'custom'),
];

void main() {
  test('Enter picks the highlighted default', () {
    final t = _terminal([_enter]);
    expect(t.prompter.select('Source?', _options), 'firebase');
  });

  test('down arrows move the cursor, up wraps around', () {
    expect(_terminal([_down, _down, _enter]).prompter.select('?', _options), 'custom');
    expect(_terminal([_up, _enter]).prompter.select('?', _options), 'custom');
    expect(_terminal([_down, _down, _down, _enter]).prompter.select('?', _options), 'firebase');
  });

  test('j / k and Windows console arrow codes also work', () {
    expect(_terminal([[106], _enter]).prompter.select('?', _options), 'http');
    expect(_terminal([[106], [107], _enter]).prompter.select('?', _options), 'firebase');
    expect(_terminal([[224, 80], _enter]).prompter.select('?', _options), 'http');
    expect(_terminal([[0, 72], _enter]).prompter.select('?', _options), 'custom');
    expect(_terminal([[_esc, 79, 66], _enter]).prompter.select('?', _options), 'http');
  });

  test('unknown keys are ignored', () {
    expect(_terminal([[120], [_esc, 91, 67], _down, _enter]).prompter.select('?', _options), 'http');
  });

  test('the highlighted line is redrawn and the answer is summarized', () {
    final t = _terminal([_down, _enter]);
    t.prompter.select('Source?', _options);
    final text = t.out.toString().replaceAll(RegExp(r'\x1B\[[0-9;]*[A-Za-z]'), '');
    expect(text, contains('> Firebase'));
    expect(text, contains('> HTTP'));
    expect(text, contains('+ Source? HTTP'));
  });

  test('space toggles in a multi select, Enter confirms', () {
    final t = _terminal([_space, _down, _space, _enter]);
    final picked = t.prompter.multiSelect(
      'Platforms?',
      const [Choice('Android', 'a'), Choice('iOS', 'i')],
      initial: const {'a'},
    );
    // Android starts selected; the first space un-ticks it, the second ticks iOS.
    expect(picked, ['i']);
  });

  test('a multi select cannot be confirmed empty', () {
    final t = _terminal([_space, _enter, _down, _space, _enter]);
    final picked = t.prompter.multiSelect(
      'Platforms?',
      const [Choice('Android', 'a'), Choice('iOS', 'i')],
      initial: const {'a'},
    );
    expect(picked, ['i']);
  });

  test('Ctrl-C and end of input cancel', () {
    expect(() => _terminal([_ctrlC]).prompter.select('?', _options), throwsA(isA<_Abort>()));
    expect(() => _terminal([]).prompter.select('?', _options), throwsA(isA<_Abort>()));
  });
}
