import 'package:flutter/material.dart';

import '../playground_state.dart';
import 'widgets.dart';

/// Every "Change the look" level from the README, switchable live.
class LookTab extends StatelessWidget {
  const LookTab({super.key, required this.state});

  final PlaygroundState state;

  @override
  Widget build(BuildContext context) => ListenableBuilder(
    listenable: state,
    builder: (context, _) => ListView(
      padding: const EdgeInsets.all(20),
      children: [
        Section(
          title: 'Level 1: the words',
          hint: 'UpdateTexts. Arabic is also right-to-left by itself.',
          children: [
            ChoiceRow<bool>(
              value: state.arabic,
              options: const {false: 'English', true: 'العربية'},
              onChanged: (v) {
                state.arabic = v;
                state.changed();
              },
            ),
          ],
        ),
        Section(
          title: 'App direction',
          hint: 'The card uses start/end, so it follows the app.',
          children: [
            ChoiceRow<DirectionMode>(
              value: state.direction,
              options: const {
                DirectionMode.auto: 'Normal',
                DirectionMode.ltr: 'Left to right',
                DirectionMode.rtl: 'Right to left',
              },
              onChanged: (v) {
                state.direction = v;
                state.changed();
              },
            ),
          ],
        ),
        Section(
          title: 'Level 2: the icon',
          hint: 'appIcon takes an image. iconBuilder takes any widget.',
          children: [
            ChoiceRow<IconStyle>(
              value: state.icon,
              options: const {
                IconStyle.round: 'Round (default)',
                IconStyle.image: 'appIcon: image',
                IconStyle.builder: 'iconBuilder',
              },
              onChanged: (v) {
                state.icon = v;
                state.changed();
              },
            ),
          ],
        ),
        Section(
          title: 'Levels 3 and 4: the card and the screens',
          hint: 'cardBuilder re-arranges the card. requiredBuilder / '
              'optionalBuilder replace the whole screen.',
          children: [
            ChoiceRow<CardStyle>(
              value: state.card,
              options: const {
                CardStyle.standard: 'Default',
                CardStyle.custom: 'cardBuilder',
                CardStyle.banner: 'Wrapped default',
                CardStyle.ownScreens: 'Own screens',
              },
              onChanged: (v) {
                state.card = v;
                state.changed();
              },
            ),
          ],
        ),
        Section(
          title: 'Behavior',
          children: [
            SwitchRow(
              label: 'Show the optional dialog',
              subtitle: 'showOptional',
              value: state.showOptional,
              onChanged: (v) {
                state.showOptional = v;
                state.changed();
              },
            ),
            SwitchRow(
              label: 'Allow "Skip this version"',
              subtitle: 'allowSkip',
              value: state.allowSkip,
              onChanged: (v) {
                state.allowSkip = v;
                state.changed();
              },
            ),
            const SizedBox(height: 8),
            ChoiceRow<ThemeMode>(
              value: state.themeMode,
              options: const {
                ThemeMode.light: 'Light',
                ThemeMode.dark: 'Dark',
                ThemeMode.system: 'System',
              },
              onChanged: (v) {
                state.themeMode = v;
                state.changed();
              },
            ),
          ],
        ),
        Section(
          title: 'The code for this look',
          hint: 'What your UpdateGate would be.',
          children: [Code(_code(state))],
        ),
      ],
    ),
  );

  static String _code(PlaygroundState s) {
    final lines = <String>[
      'UpdateGate(',
      '  controller: controller,',
      if (s.arabic) '  texts: const UpdateTexts.arabic(),',
      if (s.icon == IconStyle.image)
        "  appIcon: const AssetImage('assets/logo.png'),",
      if (s.icon == IconStyle.builder) '  iconBuilder: demoIconBuilder,',
      if (s.card == CardStyle.custom) '  cardBuilder: customCard,',
      if (s.card == CardStyle.banner) '  cardBuilder: bannerCard,',
      if (s.card == CardStyle.ownScreens) ...[
        '  requiredBuilder: ownWall,',
        '  optionalBuilder: ownDialog,',
      ],
      if (!s.showOptional) '  showOptional: false,',
      if (!s.allowSkip) '  allowSkip: false,',
      '  child: child!,',
      ')',
    ];
    return lines.join('\n');
  }
}
