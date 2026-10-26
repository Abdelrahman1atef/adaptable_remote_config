import 'package:flutter/material.dart';

import '../playground_state.dart';
import 'widgets.dart';

/// What `RemoteConfigLogger` prints: every fetch, the decision and why.
class LogsTab extends StatelessWidget {
  const LogsTab({super.key, required this.state});

  final PlaygroundState state;

  @override
  Widget build(BuildContext context) => ListenableBuilder(
    listenable: state,
    builder: (context, _) {
      final theme = Theme.of(context);
      return Column(
        children: [
          Padding(
            padding: const EdgeInsets.fromLTRB(20, 12, 12, 0),
            child: Row(
              children: [
                Expanded(
                  child: Text(
                    'Newest first. FETCHED shows the keys, DECISION says why.',
                    style: theme.textTheme.bodySmall,
                  ),
                ),
                TextButton(
                  onPressed: state.logs.isEmpty
                      ? null
                      : () {
                          state.logs.clear();
                          state.changed();
                        },
                  child: const Text('Clear'),
                ),
              ],
            ),
          ),
          Expanded(
            child: state.logs.isEmpty
                ? const Center(child: Text('Nothing yet. Try a case.'))
                : ListView.builder(
                    padding: const EdgeInsets.fromLTRB(20, 4, 20, 20),
                    itemCount: state.logs.length,
                    itemBuilder: (context, index) {
                      final box = state.logs[index];
                      return Padding(
                        padding: const EdgeInsets.only(bottom: 12),
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              box.title,
                              style: theme.textTheme.titleSmall,
                            ),
                            const SizedBox(height: 4),
                            Code(box.lines.join('\n')),
                          ],
                        ),
                      );
                    },
                  ),
          ),
        ],
      );
    },
  );
}
