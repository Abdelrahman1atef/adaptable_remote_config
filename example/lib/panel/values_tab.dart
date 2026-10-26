import 'dart:convert';

import 'package:flutter/material.dart';

import '../playground_state.dart';
import 'widgets.dart';

/// The "server" and the "phone": what you publish and who reads it.
class ValuesTab extends StatelessWidget {
  const ValuesTab({super.key, required this.state});

  final PlaygroundState state;

  static const _presets = {
    Preset.upToDate: 'Up to date',
    Preset.optional: 'Optional update',
    Preset.force: 'Force update',
    Preset.wallWins: 'Wall beats dialog',
    Preset.mistake: 'A mistake (ignored)',
    Preset.iosNoLink: 'iPhone, no link',
  };

  @override
  Widget build(BuildContext context) => ListenableBuilder(
    listenable: Listenable.merge([state, state.controller]),
    builder: (context, _) {
      final ios = state.platform == 'ios';
      final values = ios ? state.draft.ios : state.draft.android;
      return ListView(
        padding: const EdgeInsets.all(20),
        children: [
          Section(
            title: 'Try a case',
            hint: 'Each one fills the values, publishes and fetches. '
                'They match rows of the README decision table.',
            children: [
              Wrap(
                spacing: 8,
                runSpacing: 4,
                children: [
                  for (final entry in _presets.entries)
                    ActionChip(
                      label: Text(entry.value),
                      onPressed: () => state.applyPreset(entry.key),
                    ),
                ],
              ),
            ],
          ),
          Section(
            title: 'The phone',
            hint: 'Pretend to be this phone. The installed version is what '
                'the app compares with.',
            children: [
              ChoiceRow<String>(
                value: state.platform,
                options: const {'android': 'Android', 'ios': 'iPhone'},
                onChanged: state.setPlatform,
              ),
              const SizedBox(height: 12),
              LabeledField(
                label: 'Installed version',
                value: state.installedVersion,
                helper: 'Like 1.2.0 or 1.2.0+4. Press Enter to apply (restarts the app).',
                onChanged: (_) {},
                onSubmitted: state.setInstalled,
              ),
            ],
          ),
          Section(
            title: 'The server values (${ios ? 'ios_*' : 'android_*'})',
            hint: 'Edit, then press Publish, like "Publish changes" in the '
                'Firebase console.',
            children: [
              LabeledField(
                label: 'Minimum version',
                value: values.minimum,
                helper: 'Only counts when "Force update" is on.',
                onChanged: (v) {
                  values.minimum = v;
                  state.changed();
                },
              ),
              LabeledField(
                label: 'Latest version',
                value: values.latest,
                helper: 'Older apps get the optional dialog.',
                onChanged: (v) {
                  values.latest = v;
                  state.changed();
                },
              ),
              LabeledField(
                label: 'Store link',
                value: values.store,
                helper: ios
                    ? 'Required on iPhone. Empty means nothing can be shown.'
                    : 'Empty is fine on Android: the Play Store link is built '
                          'from the package name.',
                onChanged: (v) {
                  values.store = v;
                  state.changed();
                },
              ),
              SwitchRow(
                label: 'Force update',
                subtitle: 'On: below the minimum means the wall.',
                value: state.draft.force,
                onChanged: (v) {
                  state.draft.force = v;
                  state.changed();
                },
              ),
              LabeledField(
                label: 'Welcome message (a normal remote setting)',
                value: state.draft.welcome,
                onChanged: (v) {
                  state.draft.welcome = v;
                  state.changed();
                },
              ),
              Row(
                children: [
                  FilledButton.icon(
                    onPressed: state.hasUnpublished ? state.publish : null,
                    icon: const Icon(Icons.cloud_upload),
                    label: const Text('Publish'),
                  ),
                  const SizedBox(width: 8),
                  OutlinedButton(
                    onPressed: state.fetchNow,
                    child: const Text('Fetch now'),
                  ),
                  const SizedBox(width: 8),
                  TextButton(
                    onPressed: state.restart,
                    child: const Text('Restart app'),
                  ),
                ],
              ),
              if (state.hasUnpublished)
                Padding(
                  padding: const EdgeInsets.only(top: 8),
                  child: Text(
                    'Unpublished changes: the app still sees the old values.',
                    style: TextStyle(color: Theme.of(context).colorScheme.error),
                  ),
                ),
              SwitchRow(
                label: 'Push to the open app when I publish',
                subtitle: state.source == SourceKind.custom
                    ? 'Like Firebase real-time updates (subscribeToChanges).'
                    : 'A JSON file cannot push. Use "Fetch now" or restart.',
                value: state.pushOnPublish && state.source == SourceKind.custom,
                onChanged: state.source == SourceKind.custom
                    ? (v) {
                        state.pushOnPublish = v;
                        state.changed();
                      }
                    : null,
              ),
            ],
          ),
          Section(
            title: 'What the server sends',
            hint: state.source == SourceKind.custom
                ? 'Your function returns this map (default key names).'
                : 'The JSON file at the URL (UpdateKeys.nested).',
            children: [
              Code(
                const JsonEncoder.withIndent('  ').convert(
                  state.source == SourceKind.custom
                      ? state.live.toFlat()
                      : state.live.toNested(),
                ),
              ),
            ],
          ),
        ],
      );
    },
  );
}
