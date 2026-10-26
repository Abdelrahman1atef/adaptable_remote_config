import 'dart:math' as math;

import 'package:adaptable_remote_config/adaptable_remote_config.dart';
import 'package:flutter/material.dart';

import '../playground_state.dart';
import 'logs_tab.dart';
import 'look_tab.dart';
import 'test_tab.dart';
import 'values_tab.dart';

/// Puts the playground in its own `Overlay`, so text fields work even though
/// this sits above the app's Navigator (it must stay usable over the wall).
class PlaygroundPanelHost extends StatefulWidget {
  const PlaygroundPanelHost({super.key, required this.state});

  final PlaygroundState state;

  @override
  State<PlaygroundPanelHost> createState() => _PlaygroundPanelHostState();
}

class _PlaygroundPanelHostState extends State<PlaygroundPanelHost> {
  late final OverlayEntry _entry = OverlayEntry(
    builder: (_) => PlaygroundPanel(state: widget.state),
  );

  @override
  void dispose() {
    _entry
      ..remove()
      ..dispose();
    super.dispose();
  }

  @override
  // The panel keeps the same layout whatever direction the app is forced to.
  Widget build(BuildContext context) => Directionality(
    textDirection: TextDirection.ltr,
    child: Overlay(initialEntries: [_entry]),
  );
}

class PlaygroundPanel extends StatelessWidget {
  const PlaygroundPanel({super.key, required this.state});

  final PlaygroundState state;

  @override
  Widget build(BuildContext context) {
    final media = MediaQuery.of(context);
    final bottom = math.max(media.viewInsets.bottom, media.viewPadding.bottom);
    return ValueListenableBuilder<bool>(
      valueListenable: state.panelOpen,
      builder: (context, open, _) => Align(
        alignment: Alignment.bottomCenter,
        child: ConstrainedBox(
          constraints: const BoxConstraints(maxWidth: 640),
          child: Padding(
            padding: EdgeInsets.only(
              bottom: open ? media.viewInsets.bottom : bottom + 12,
            ),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                _Toast(state: state),
                if (open)
                  _Sheet(
                    state: state,
                    maxHeight: math.min(
                      media.size.height * 0.72,
                      media.size.height -
                          media.viewInsets.bottom -
                          media.padding.top -
                          16,
                    ),
                    onClose: () => state.panelOpen.value = false,
                  )
                else
                  _Pill(
                    state: state,
                    onTap: () => state.panelOpen.value = true,
                  ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

Color _colorOf(BuildContext context, UpdateKind kind) => switch (kind) {
  UpdateKind.none => Colors.grey,
  UpdateKind.optional => Colors.orange,
  UpdateKind.required => Colors.red,
};

String _labelOf(UpdateKind kind) => switch (kind) {
  UpdateKind.none => 'NOTHING',
  UpdateKind.optional => 'DIALOG',
  UpdateKind.required => 'WALL',
};

class _Toast extends StatelessWidget {
  const _Toast({required this.state});

  final PlaygroundState state;

  @override
  Widget build(BuildContext context) => ValueListenableBuilder<String?>(
    valueListenable: state.toast,
    builder: (context, message, _) => message == null
        ? const SizedBox.shrink()
        : Padding(
            padding: const EdgeInsets.only(bottom: 8, left: 16, right: 16),
            child: Material(
              elevation: 4,
              borderRadius: BorderRadius.circular(12),
              color: Theme.of(context).colorScheme.inverseSurface,
              child: Padding(
                padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
                child: Text(
                  message,
                  style: TextStyle(
                    color: Theme.of(context).colorScheme.onInverseSurface,
                  ),
                ),
              ),
            ),
          ),
  );
}

/// The collapsed bar: the live decision, tap to open the playground.
class _Pill extends StatelessWidget {
  const _Pill({required this.state, required this.onTap});

  final PlaygroundState state;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    return ListenableBuilder(
      listenable: Listenable.merge([state, state.controller]),
      builder: (context, _) {
        final kind = state.controller.update.kind;
        return Material(
          elevation: 8,
          shape: const StadiumBorder(),
          color: scheme.inverseSurface,
          child: InkWell(
            customBorder: const StadiumBorder(),
            onTap: onTap,
            child: Padding(
              padding: const EdgeInsets.symmetric(horizontal: 18, vertical: 12),
              child: Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Icon(Icons.circle, size: 12, color: _colorOf(context, kind)),
                  const SizedBox(width: 10),
                  Text(
                    'Playground · ${_labelOf(kind)}',
                    style: TextStyle(
                      color: scheme.onInverseSurface,
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                  const SizedBox(width: 10),
                  Icon(Icons.keyboard_arrow_up, color: scheme.onInverseSurface),
                ],
              ),
            ),
          ),
        );
      },
    );
  }
}

class _Sheet extends StatelessWidget {
  const _Sheet({
    required this.state,
    required this.maxHeight,
    required this.onClose,
  });

  final PlaygroundState state;
  final double maxHeight;
  final VoidCallback onClose;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Material(
      elevation: 16,
      color: theme.colorScheme.surface,
      borderRadius: const BorderRadius.vertical(top: Radius.circular(24)),
      clipBehavior: Clip.antiAlias,
      child: SizedBox(
        height: maxHeight,
        child: DefaultTabController(
          length: 4,
          child: Column(
            children: [
              Padding(
                padding: const EdgeInsets.fromLTRB(20, 12, 8, 0),
                child: Row(
                  children: [
                    Expanded(
                      child: ListenableBuilder(
                        listenable: Listenable.merge([state, state.controller]),
                        builder: (context, _) => Row(
                          children: [
                            Icon(
                              Icons.circle,
                              size: 12,
                              color: _colorOf(context, state.controller.update.kind),
                            ),
                            const SizedBox(width: 8),
                            Expanded(
                              child: Text(
                                state.verdict,
                                maxLines: 2,
                                overflow: TextOverflow.ellipsis,
                                style: theme.textTheme.titleSmall,
                              ),
                            ),
                          ],
                        ),
                      ),
                    ),
                    IconButton(
                      tooltip: 'Close',
                      onPressed: onClose,
                      icon: const Icon(Icons.keyboard_arrow_down),
                    ),
                  ],
                ),
              ),
              const TabBar(
                tabs: [
                  Tab(text: 'Values'),
                  Tab(text: 'Look'),
                  Tab(text: 'Test'),
                  Tab(text: 'Logs'),
                ],
              ),
              Expanded(
                child: TabBarView(
                  children: [
                    ValuesTab(state: state),
                    LookTab(state: state),
                    TestTab(state: state),
                    LogsTab(state: state),
                  ],
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
