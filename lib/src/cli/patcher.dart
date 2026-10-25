/// The outcome of editing one source file: new text, or a reason it was left
/// alone (the caller then shows the manual step instead).
class PatchResult {
  const PatchResult.changed(String this.source, this.note)
    : alreadyDone = false;
  const PatchResult.skipped(this.note, {this.alreadyDone = false})
    : source = null;

  final String? source;
  final String note;

  /// Skipped because the file already has this edit.
  final bool alreadyDone;

  bool get changed => source != null;
}

final _appWidget = RegExp(r'\b(?:MaterialApp|CupertinoApp)(?:\.router)?\s*\(');

/// True when [source] builds an app widget this patcher can wrap.
bool hasAppWidget(String source) => _appWidget.hasMatch(source);

/// Runs [patch] on LF text and restores CRLF line endings when the file had
/// them, so Windows projects do not end up with mixed endings.
PatchResult _keepLineEndings(
  String source,
  PatchResult Function(String lf) patch,
) {
  final crlf = source.contains('\r\n');
  final result = patch(crlf ? source.replaceAll('\r\n', '\n') : source);
  if (!crlf || !result.changed) return result;
  return PatchResult.changed(
    result.source!.replaceAll('\n', '\r\n'),
    result.note,
  );
}

/// Adds `builder: ... UpdateGate(...)` to the single `MaterialApp` /
/// `CupertinoApp` in [source].
PatchResult wrapAppWithGate(
  String source, {
  required List<String> imports,
  required bool showOptional,
}) => _keepLineEndings(
  source,
  (lf) => _wrapApp(lf, imports: imports, showOptional: showOptional),
);

PatchResult _wrapApp(
  String source, {
  required List<String> imports,
  required bool showOptional,
}) {
  if (source.contains('UpdateGate(')) {
    return const PatchResult.skipped('UpdateGate is already in place', alreadyDone: true);
  }
  final matches = _appWidget.allMatches(source).toList();
  if (matches.length != 1) {
    return PatchResult.skipped(
      matches.isEmpty ? 'no MaterialApp found' : 'several app widgets found',
    );
  }
  final match = matches.single;
  final open = match.end - 1;
  final close = _closingParen(source, open);
  if (close < 0) return const PatchResult.skipped('could not parse the app');
  if (_topLevel(source, open, close).contains(RegExp(r'(^|[^\w.])builder\s*:'))) {
    return const PatchResult.skipped('the app already has a builder');
  }

  final lineStart = source.lastIndexOf('\n', match.start) + 1;
  final indent = RegExp(r'^[ \t]*').stringMatch(source.substring(lineStart))!;
  final optional = showOptional ? '' : '\n$indent    showOptional: false,';
  final insert =
      '\n$indent  builder: (context, child) => UpdateGate('
      '\n$indent    controller: AppUpdate.controller,$optional'
      '\n$indent    child: child!,'
      '\n$indent  ),';
  final tail = source[open + 1] == '\n' ? '' : '\n$indent  ';
  // A `const MaterialApp(` cannot hold a closure.
  final before = source
      .substring(0, match.start)
      .replaceFirst(RegExp(r'\bconst\s+$'), '');
  final patched =
      '$before${source.substring(match.start, open + 1)}$insert$tail'
      '${source.substring(open + 1)}';
  return PatchResult.changed(
    addImports(patched, imports),
    'wrapped the app in UpdateGate',
  );
}

/// Makes `main()` call `Firebase.initializeApp` before `runApp`.
PatchResult initFirebaseInMain(
  String source, {
  required List<String> imports,
  required bool withOptions,
}) => _keepLineEndings(
  source,
  (lf) => _initFirebase(lf, imports: imports, withOptions: withOptions),
);

PatchResult _initFirebase(
  String source, {
  required List<String> imports,
  required bool withOptions,
}) {
  if (source.contains('Firebase.initializeApp')) {
    return const PatchResult.skipped('Firebase is already initialized', alreadyDone: true);
  }
  final main = RegExp(
    r'^(?:void|Future<void>)\s+main\s*\(\s*(?:List<String>\s+\w+\s*)?\)\s*(?:async\s*)?\{',
    multiLine: true,
  ).firstMatch(source);
  if (main == null) {
    return const PatchResult.skipped('main() is not a block function');
  }
  final options = withOptions ? 'options: DefaultFirebaseOptions.currentPlatform' : '';
  final init = '  await Firebase.initializeApp($options);';
  const binding = '  WidgetsFlutterBinding.ensureInitialized();';

  var header = main.group(0)!.replaceFirst(RegExp(r'^(?:void|Future<void>)'), 'Future<void>');
  if (!header.contains('async')) {
    header = header.replaceFirst(RegExp(r'\s*\{$'), ' async {');
  }
  var rest = source.substring(main.end);
  final existing = RegExp(r'^[ \t]*WidgetsFlutterBinding\.ensureInitialized\(\);[ \t]*$', multiLine: true)
      .firstMatch(rest);
  if (existing != null) {
    rest = '${rest.substring(0, existing.end)}\n$init${rest.substring(existing.end)}';
  } else {
    header = '$header\n$binding\n$init';
  }
  final patched = '${source.substring(0, main.start)}$header$rest';
  final needsWidgets = !patched.contains("import 'package:flutter/");
  return PatchResult.changed(
    addImports(patched, [...imports, if (needsWidgets) "import 'package:flutter/widgets.dart';"]),
    'initialized Firebase in main()',
  );
}

/// Inserts each `import ...;` line that is not already there.
String addImports(String source, Iterable<String> imports) {
  final missing = [
    for (final line in imports)
      if (!source.contains(line)) line,
  ];
  if (missing.isEmpty) return source;
  final found = RegExp(r'^import\s+[^;]+;[ \t]*$', multiLine: true)
      .allMatches(source)
      .toList();
  if (found.isEmpty) return '${missing.join('\n')}\n\n$source';
  final end = found.last.end;
  return '${source.substring(0, end)}\n${missing.join('\n')}${source.substring(end)}';
}

/// Index of the `)` matching the `(` at [open], or -1.
int _closingParen(String s, int open) {
  var depth = 0;
  for (var i = open; i < s.length; i++) {
    final c = s[i];
    if (c == "'" || c == '"') {
      i = _skipString(s, i);
      if (i < 0) return -1;
    } else if (c == '(') {
      depth++;
    } else if (c == ')' && --depth == 0) {
      return i;
    }
  }
  return -1;
}

/// The text of the call between [open] and [close] with nested brackets and
/// strings removed, so only its own named arguments remain.
String _topLevel(String s, int open, int close) {
  final out = StringBuffer();
  var depth = 0;
  for (var i = open + 1; i < close; i++) {
    final c = s[i];
    if (c == "'" || c == '"') {
      i = _skipString(s, i);
      if (i < 0) break;
    } else if ('([{'.contains(c)) {
      depth++;
    } else if (')]}'.contains(c)) {
      depth--;
    } else if (depth == 0) {
      out.write(c);
    }
  }
  return out.toString();
}

/// Index of the closing quote of the string starting at [start].
int _skipString(String s, int start) {
  final quote = s[start];
  for (var i = start + 1; i < s.length; i++) {
    if (s[i] == r'\') {
      i++;
    } else if (s[i] == quote) {
      return i;
    }
  }
  return -1;
}
