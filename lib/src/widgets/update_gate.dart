import 'dart:async';

import 'package:flutter/material.dart';

import '../controller.dart';
import 'update_widgets.dart';

/// Install in `MaterialApp.builder` (or `MaterialApp.router.builder`) around
/// the navigation child, so it sits above every route, dialog and deep link.
/// The caller owns and disposes the controller; use one gate per controller.
///
/// - While the first check settles: [loadingBuilder] (a spinner by default).
/// - Required update: the app stays mounted but hidden and unreachable, and an
///   isolated navigator shows [requiredBuilder].
/// - Optional update: [optionalBuilder] over a dismissible barrier.
class UpdateGate extends StatefulWidget {
  const UpdateGate({
    super.key,
    required this.controller,
    required this.child,
    this.requiredBuilder,
    this.optionalBuilder,
    this.loadingBuilder,
    this.texts,
    this.showOptional = true,
    this.checkOnResume = true,
    this.allowSkip = true,
    this.appIcon = const AssetImage(defaultAppIconAsset),
    this.showAppIcon = true,
  });

  final RemoteConfigController controller;
  final Widget child;
  final UpdateWidgetBuilder? requiredBuilder;
  final UpdateWidgetBuilder? optionalBuilder;
  final WidgetBuilder? loadingBuilder;
  final UpdateTexts? texts;

  /// False turns the optional dialog off (build your own from the controller).
  final bool showOptional;

  /// Refreshes when the app resumes, at most once per `refreshInterval`.
  final bool checkOnResume;
  final bool allowSkip;

  /// Your app icon, shown at the top of the wall and the dialog. By default it
  /// is read from `assets/app_icon.png`; if that file is missing the update
  /// icon is shown instead.
  final ImageProvider? appIcon;

  /// False always shows the update icon, never your app icon.
  final bool showAppIcon;

  @override
  State<UpdateGate> createState() => _UpdateGateState();
}

class _UpdateGateState extends State<UpdateGate> with WidgetsBindingObserver {
  bool _started = false;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
    unawaited(_start(widget.controller));
  }

  Future<void> _start(RemoteConfigController controller) async {
    await controller.initialize();
    if (mounted && identical(controller, widget.controller)) {
      setState(() => _started = true);
    }
  }

  @override
  void didUpdateWidget(UpdateGate oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (!identical(oldWidget.controller, widget.controller)) {
      _started = false;
      unawaited(_start(widget.controller));
    }
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    if (state == AppLifecycleState.resumed && widget.checkOnResume) {
      unawaited(widget.controller.refresh(force: false));
    }
  }

  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
    super.dispose();
  }

  @override
  Widget build(BuildContext context) => ListenableBuilder(
    listenable: widget.controller,
    builder: _buildGate,
  );

  Widget _buildGate(BuildContext context, Widget? _) {
    final controller = widget.controller;
    final waiting = !_started && !controller.isReady;
    final required = controller.update.isRequired;
    final optional =
        !waiting && !required && widget.showOptional && controller.shouldPrompt;
    final hidden = waiting || required;
    final content = Stack(
      fit: StackFit.expand,
      children: [
        // Stay mounted so deep links can update the router, but leave paint,
        // hit testing, focus and accessibility while blocked.
        Offstage(
          offstage: hidden,
          child: ExcludeFocus(
            excluding: hidden || optional,
            child: ExcludeSemantics(
              excluding: hidden || optional,
              child: TickerMode(enabled: !hidden, child: widget.child),
            ),
          ),
        ),
        if (waiting)
          widget.loadingBuilder?.call(context) ??
              const Material(child: Center(child: CircularProgressIndicator())),
        if (required)
          // Its own navigator keeps any route a custom blocker opens away from
          // the protected app's route tree.
          HeroControllerScope.none(
            child: Navigator(
              key: ObjectKey(controller),
              onGenerateRoute: (_) => MaterialPageRoute<void>(
                builder: (context) => PopScope(
                  canPop: false,
                  child:
                      widget.requiredBuilder?.call(context, controller) ??
                      RequiredUpdatePage(
                        controller: controller,
                        texts: widget.texts,
                        appIcon: widget.appIcon,
                        showAppIcon: widget.showAppIcon,
                      ),
                ),
              ),
            ),
          ),
        if (optional) ...[
          ModalBarrier(
            dismissible: true,
            onDismiss: controller.dismissOptional,
            semanticsLabel: MaterialLocalizations.of(
              context,
            ).modalBarrierDismissLabel,
            color: Theme.of(context).colorScheme.scrim.withValues(alpha: 0.54),
          ),
          Center(
            child:
                widget.optionalBuilder?.call(context, controller) ??
                OptionalUpdateDialog(
                  controller: controller,
                  texts: widget.texts,
                  allowSkip: widget.allowSkip,
                  appIcon: widget.appIcon,
                  showAppIcon: widget.showAppIcon,
                ),
          ),
        ],
      ],
    );
    // Below a Router (not the usual MaterialApp.builder spot) also swallow the
    // back button, so it cannot reach the hidden routes.
    if (Router.maybeOf(context)?.backButtonDispatcher == null) return content;
    return BackButtonListener(
      onBackButtonPressed: () async {
        if (waiting || required) return true;
        if (!optional) return false;
        await controller.dismissOptional();
        return true;
      },
      child: content,
    );
  }
}
