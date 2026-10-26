import 'package:flutter/material.dart';

import 'playground_state.dart';

/// The pretend app. The update screens appear on top of it.
class HomePage extends StatelessWidget {
  const HomePage({super.key, required this.state});

  final PlaygroundState state;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return ListenableBuilder(
      listenable: Listenable.merge([state, state.controller]),
      builder: (context, _) {
        // A setting that comes from the same remote values (README: "Read
        // other settings too"). Edit "Welcome message" in the playground.
        final welcome = state.controller.values.string(
          'welcome_message',
          'Welcome',
        );
        return Scaffold(
          appBar: AppBar(title: Text(welcome)),
          body: ListView(
            padding: const EdgeInsets.fromLTRB(16, 16, 16, 140),
            children: [
              const _Card(
                icon: Icons.touch_app,
                title: 'This is your app',
                body:
                    'The update wall and the update dialog appear on top of it, '
                    'above every screen. Tap the pill at the bottom to open the '
                    'playground and try each feature.',
              ),
              _Card(
                icon: Icons.bolt,
                title: 'Try this first',
                body:
                    '1. Open the playground.\n'
                    '2. Tap "Optional update" and read the dialog.\n'
                    '3. Tap "Force update" and see the wall. The playground '
                    'stays usable over it.\n'
                    '4. Open the Logs tab to see why.',
              ),
              _Card(
                icon: Icons.settings_suggest,
                title: 'Another remote value',
                body:
                    'The title above is the value "welcome_message":\n'
                    '"$welcome"\n\n'
                    'Change it in the playground, press Publish, and this '
                    'screen updates without a restart.',
                bodyStyle: theme.textTheme.bodyMedium,
              ),
            ],
          ),
        );
      },
    );
  }
}

class _Card extends StatelessWidget {
  const _Card({
    required this.icon,
    required this.title,
    required this.body,
    this.bodyStyle,
  });

  final IconData icon;
  final String title;
  final String body;
  final TextStyle? bodyStyle;

  @override
  Widget build(BuildContext context) => Card(
    margin: const EdgeInsets.only(bottom: 12),
    child: Padding(
      padding: const EdgeInsets.all(16),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Icon(icon, color: Theme.of(context).colorScheme.primary),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(title, style: Theme.of(context).textTheme.titleMedium),
                const SizedBox(height: 4),
                Text(body, style: bodyStyle),
              ],
            ),
          ),
        ],
      ),
    ),
  );
}
