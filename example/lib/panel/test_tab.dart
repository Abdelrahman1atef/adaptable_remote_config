import 'package:flutter/material.dart';

import '../playground_state.dart';
import 'widgets.dart';

/// The things around the update: where the values live, the network, the store.
class TestTab extends StatelessWidget {
  const TestTab({super.key, required this.state});

  final PlaygroundState state;

  @override
  Widget build(BuildContext context) => ListenableBuilder(
    listenable: state,
    builder: (context, _) => ListView(
      padding: const EdgeInsets.all(20),
      children: [
        Section(
          title: 'Where the values live',
          hint: 'Both are simulated here. Firebase works the same way but '
              'needs your own project (see the README).',
          children: [
            ChoiceRow<SourceKind>(
              value: state.source,
              options: const {
                SourceKind.custom: 'Your own function',
                SourceKind.http: 'A JSON file (HTTP)',
              },
              onChanged: state.setSource,
            ),
          ],
        ),
        Section(
          title: 'The network',
          hint: 'Offline: the fetch fails and the app uses its saved copy. '
              'Try it after fetching once.',
          children: [
            ChoiceRow<bool>(
              value: state.offline,
              options: const {false: 'Online', true: 'Offline'},
              onChanged: (v) {
                state.offline = v;
                state.changed();
              },
            ),
          ],
        ),
        Section(
          title: 'The Update button',
          hint: 'Nothing is really opened. Tap Update on the wall or the '
              'dialog, then read the message above the pill.',
          children: [
            ChoiceRow<bool>(
              value: state.storeOpens,
              options: const {true: 'Store opens', false: 'Store fails'},
              onChanged: (v) {
                state.storeOpens = v;
                state.changed();
              },
            ),
            const SizedBox(height: 8),
            Text(
              'Google Play in-app update (inAppUpdate:)',
              style: Theme.of(context).textTheme.bodyMedium,
            ),
            const SizedBox(height: 4),
            ChoiceRow<PlayHook>(
              value: state.playHook,
              options: const {
                PlayHook.off: 'Not used',
                PlayHook.handled: 'Play handles it',
                PlayHook.notHandled: 'Play cannot',
              },
              onChanged: state.setPlayHook,
            ),
          ],
        ),
        Section(
          title: 'Memory',
          hint: 'Later and Skip are remembered, and so is the last good '
              'copy of the values.',
          children: [
            Wrap(
              spacing: 8,
              runSpacing: 4,
              children: [
                OutlinedButton(
                  onPressed: state.forgetEverything,
                  child: const Text('Forget saved copy, Later and Skip'),
                ),
                OutlinedButton(
                  onPressed: state.controller.check,
                  child: const Text('Check again (no network)'),
                ),
              ],
            ),
          ],
        ),
        Section(
          title: 'Logs',
          children: [
            SwitchRow(
              label: 'Also print logs to the console',
              subtitle: 'The Logs tab always shows them. In your app: '
                  'log: RemoteConfigLogger().',
              value: state.echoLogs,
              onChanged: (v) {
                state.echoLogs = v;
                state.changed();
              },
            ),
          ],
        ),
      ],
    ),
  );
}
