import 'package:adaptable_remote_config/adaptable_remote_config.dart';
import 'package:flutter/material.dart';

import 'custom_looks.dart';
import 'home_page.dart';
import 'panel/playground_panel.dart';
import 'playground_state.dart';

/// A playground for `adaptable_remote_config`.
///
/// The "app" behind the update screens is [HomePage]. The pill at the bottom
/// opens the playground: change the fake server's values, pick a look, fake the
/// store, and read the logs. No Firebase and no server are needed.
void main() => runApp(const PlaygroundApp());

class PlaygroundApp extends StatefulWidget {
  const PlaygroundApp({super.key, this.state});

  /// Tests pass their own state.
  final PlaygroundState? state;

  @override
  State<PlaygroundApp> createState() => _PlaygroundAppState();
}

class _PlaygroundAppState extends State<PlaygroundApp> {
  late final PlaygroundState _state = widget.state ?? PlaygroundState();
  late final bool _ownsState = widget.state == null;

  @override
  void dispose() {
    if (_ownsState) _state.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    const seed = Color(0xFF6750A4);
    return ListenableBuilder(
      listenable: _state,
      builder: (context, _) => MaterialApp(
        title: 'adaptable_remote_config playground',
        debugShowCheckedModeBanner: false,
        theme: ThemeData(colorScheme: ColorScheme.fromSeed(seedColor: seed)),
        darkTheme: ThemeData(
          colorScheme: ColorScheme.fromSeed(
            seedColor: seed,
            brightness: Brightness.dark,
          ),
        ),
        themeMode: _state.themeMode,
        home: HomePage(state: _state),
        // The gate goes around the whole app, above every route. The
        // playground goes next to it, so it stays usable over the wall.
        builder: (context, child) => _Shell(state: _state, child: child!),
      ),
    );
  }
}

class _Shell extends StatelessWidget {
  const _Shell({required this.state, required this.child});

  final PlaygroundState state;
  final Widget child;

  @override
  Widget build(BuildContext context) {
    final gate = UpdateGate(
      controller: state.controller,
      // Level 1: the words.
      texts: state.arabic ? const UpdateTexts.arabic() : null,
      showOptional: state.showOptional,
      allowSkip: state.allowSkip,
      // Level 2: the icon.
      appIcon: state.icon == IconStyle.image
          ? const AssetImage('assets/logo.png')
          : null,
      iconBuilder: state.icon == IconStyle.builder ? demoIconBuilder : null,
      // Level 3: the card layout.
      cardBuilder: switch (state.card) {
        CardStyle.custom => customCard,
        CardStyle.banner => bannerCard,
        _ => null,
      },
      // Level 4: the whole screens.
      requiredBuilder: state.card == CardStyle.ownScreens ? ownWall : null,
      optionalBuilder: state.card == CardStyle.ownScreens ? ownDialog : null,
      child: child,
    );
    final forced = state.forcedDirection;
    return Stack(
      fit: StackFit.expand,
      children: [
        forced == null
            ? gate
            : Directionality(textDirection: forced, child: gate),
        PlaygroundPanelHost(state: state),
      ],
    );
  }
}
