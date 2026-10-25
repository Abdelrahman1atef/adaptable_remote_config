import 'dart:ffi';
import 'dart:io';

import 'package:ffi/ffi.dart';

/// Raw keyboard input for the Windows console.
///
/// `stdin.echoMode` / `stdin.lineMode` are not enough there: they can fail with
/// "The parameter is incorrect" depending on the console's current state, and
/// arrow keys are never delivered unless virtual-terminal input is switched on,
/// which `dart:io` cannot do. So this talks to the console API directly.
class WindowsConsoleMode {
  WindowsConsoleMode._(this._handle, this._original, this._setMode);

  final int _handle;
  final int _original;
  final int Function(int handle, int mode) _setMode;

  static const _stdInputHandle = 0xFFFFFFF6; // (DWORD)-10
  static const _processedInput = 0x0001;
  static const _lineInput = 0x0002;
  static const _echoInput = 0x0004;
  static const _virtualTerminalInput = 0x0200;

  /// Switches stdin to raw, escape-sequence input. Null when this is not a
  /// Windows console that supports it (the caller then uses numbered input).
  static WindowsConsoleMode? enterRaw() {
    if (!Platform.isWindows) return null;
    try {
      final kernel = DynamicLibrary.open('kernel32.dll');
      final getStdHandle = kernel
          .lookupFunction<IntPtr Function(Uint32), int Function(int)>(
            'GetStdHandle',
          );
      final getMode = kernel.lookupFunction<
        Int32 Function(IntPtr, Pointer<Uint32>),
        int Function(int, Pointer<Uint32>)
      >('GetConsoleMode');
      final setMode = kernel
          .lookupFunction<Int32 Function(IntPtr, Uint32), int Function(int, int)>(
            'SetConsoleMode',
          );

      final handle = getStdHandle(_stdInputHandle);
      if (handle == 0 || handle == -1) return null;
      final slot = calloc<Uint32>();
      try {
        if (getMode(handle, slot) == 0) return null;
        final original = slot.value;
        // Ctrl-C then arrives as byte 3, so the mode can always be restored.
        final raw =
            (original & ~(_lineInput | _echoInput | _processedInput)) |
            _virtualTerminalInput;
        if (setMode(handle, raw) == 0) return null;
        return WindowsConsoleMode._(handle, original, setMode);
      } finally {
        calloc.free(slot);
      }
    } on Object {
      return null;
    }
  }

  /// Puts the console back the way it was.
  void restore() => _setMode(_handle, _original);
}
