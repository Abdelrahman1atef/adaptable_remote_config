import 'package:flutter/material.dart';

import '../controller.dart';
import '../update.dart';

/// Button and message labels. English by default, Arabic for Arabic locales.
///
/// [textDirection] is the reading direction of these texts. Leave it null to
/// follow the app. The Arabic preset is always right-to-left, so Arabic text is
/// laid out correctly even inside a left-to-right app.
class UpdateTexts {
  const UpdateTexts({
    this.requiredTitle = 'Update required',
    this.optionalTitle = 'Update available',
    this.requiredMessage = 'Please update the app to continue.',
    this.optionalMessage = 'A newer version of the app is available.',
    this.update = 'Update',
    this.later = 'Later',
    this.skip = 'Skip this version',
    this.retry = 'Retry',
    this.launchError = 'Could not open the update. Please try again.',
    this.textDirection,
  });

  const UpdateTexts.arabic()
    : requiredTitle = 'التحديث مطلوب',
      optionalTitle = 'يتوفر تحديث',
      requiredMessage = 'يرجى تحديث التطبيق للمتابعة.',
      optionalMessage = 'يتوفر إصدار أحدث من التطبيق.',
      update = 'تحديث',
      later = 'لاحقاً',
      skip = 'تخطي هذا الإصدار',
      retry = 'إعادة المحاولة',
      launchError = 'تعذر فتح التحديث. يرجى المحاولة مرة أخرى.',
      textDirection = TextDirection.rtl;

  final String requiredTitle;
  final String optionalTitle;
  final String requiredMessage;
  final String optionalMessage;
  final String update;
  final String later;
  final String skip;
  final String retry;
  final String launchError;

  /// Null means "same as the app".
  final TextDirection? textDirection;

  /// The direction the update screens are drawn in.
  TextDirection directionOf(BuildContext context) =>
      textDirection ?? Directionality.maybeOf(context) ?? TextDirection.ltr;

  static UpdateTexts of(BuildContext context) =>
      Localizations.localeOf(context).languageCode == 'ar'
      ? const UpdateTexts.arabic()
      : const UpdateTexts();
}

/// Replaces a default screen while the controller keeps all the behavior.
typedef UpdateWidgetBuilder =
    Widget Function(BuildContext context, RemoteConfigController controller);

/// Builds the icon at the top of the card. [size] is the space the default
/// layout gives it (64 on the dialog, 96 on the wall). Return any widget: an
/// SVG, an animation, a network image...
typedef UpdateIconBuilder = Widget Function(BuildContext context, double size);

/// Lays out the whole card yourself, from ready-made parts in [UpdateCardData].
typedef UpdateCardBuilder =
    Widget Function(BuildContext context, UpdateCardData data);

/// Everything a custom card needs, already built and wired to the controller.
/// Place the parts however you like; the buttons keep working.
class UpdateCardData {
  const UpdateCardData({
    required this.controller,
    required this.texts,
    required this.isRequired,
    required this.title,
    required this.message,
    required this.icon,
    required this.error,
    required this.updateButton,
    required this.laterButton,
    required this.skipButton,
  });

  final RemoteConfigController controller;
  final UpdateTexts texts;

  /// True on the wall (cannot be dismissed), false on the optional dialog.
  final bool isRequired;

  /// Ready-to-show texts for this kind of update.
  final String title;
  final String message;

  /// The icon: your app icon, your [UpdateIconBuilder], or the round default.
  final Widget icon;

  /// The "could not open the store" message; empty until a launch fails.
  final Widget error;

  /// Opens the store (becomes "Retry" after a failed launch).
  final Widget updateButton;

  /// Hides the dialog for a day. Null on the wall.
  final Widget? laterButton;

  /// Hides this version for good. Null on the wall, or when skipping is off.
  final Widget? skipButton;

  /// What is being offered: kind, version and store address.
  UpdateResult get update => controller.update;
}

/// "Update" button that turns into "Retry" after a failed launch.
class UpdateButton extends StatelessWidget {
  const UpdateButton({super.key, required this.controller, this.texts});

  final RemoteConfigController controller;
  final UpdateTexts? texts;

  @override
  Widget build(BuildContext context) => ListenableBuilder(
    listenable: controller,
    builder: (context, _) {
      final strings = texts ?? UpdateTexts.of(context);
      return FilledButton(
        onPressed: controller.isOpeningUpdate ? null : controller.openUpdate,
        child: Text(
          controller.actionError == null ? strings.update : strings.retry,
        ),
      );
    },
  );
}

/// The default card: an icon, a title, a message and the buttons. Everything
/// is laid out with start/end, never left/right, so it reads correctly in both
/// text directions. [centered] is for the wall.
class UpdateCard extends StatelessWidget {
  const UpdateCard({
    super.key,
    required this.title,
    required this.message,
    required this.icon,
    required this.actions,
    this.error,
    this.centered = false,
    this.elevated = true,
  });

  /// The default card made from [data]: this is what the gate draws unless you
  /// pass a `cardBuilder`. Call it from your own builder to wrap the default.
  factory UpdateCard.fromData(UpdateCardData data) => UpdateCard(
    title: data.title,
    message: data.message,
    icon: data.icon,
    error: data.error,
    centered: data.isRequired,
    elevated: !data.isRequired,
    actions: [
      data.updateButton,
      if (data.laterButton != null || data.skipButton != null) ...[
        const SizedBox(height: 8),
        Row(
          children: [
            if (data.laterButton != null) Expanded(child: data.laterButton!),
            if (data.skipButton != null) Expanded(child: data.skipButton!),
          ],
        ),
      ],
    ],
  );

  final String title;
  final String message;
  final Widget icon;
  final List<Widget> actions;
  final Widget? error;

  /// True: everything centered (the wall). False: aligned to the start edge.
  final bool centered;

  /// False draws no card background, for use on a full page.
  final bool elevated;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final scheme = theme.colorScheme;
    final align = centered ? TextAlign.center : TextAlign.start;
    final content = Padding(
      padding: const EdgeInsetsDirectional.all(24),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: centered
            ? CrossAxisAlignment.center
            : CrossAxisAlignment.start,
        children: [
          icon,
          const SizedBox(height: 16),
          Text(
            title,
            textAlign: align,
            style: theme.textTheme.titleLarge?.copyWith(
              color: scheme.onSurface,
            ),
          ),
          const SizedBox(height: 8),
          Text(
            message,
            textAlign: align,
            style: theme.textTheme.bodyMedium?.copyWith(
              color: scheme.onSurfaceVariant,
            ),
          ),
          ?error,
          const SizedBox(height: 24),
          SizedBox(
            width: double.infinity,
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: actions,
            ),
          ),
        ],
      ),
    );
    return ConstrainedBox(
      constraints: const BoxConstraints(maxWidth: 420),
      child: elevated
          ? Material(
              color: scheme.surfaceContainerHigh,
              elevation: 3,
              shadowColor: scheme.shadow,
              clipBehavior: Clip.antiAlias,
              borderRadius: BorderRadius.circular(28),
              // Scrolls when the screen is small or the text is very large.
              child: SingleChildScrollView(child: content),
            )
          : Material(type: MaterialType.transparency, child: content),
    );
  }
}

/// The ready-made parts for one kind of update.
UpdateCardData _dataFor(
  BuildContext context, {
  required RemoteConfigController controller,
  required UpdateTexts strings,
  required bool isRequired,
  required bool allowSkip,
  required ImageProvider? appIcon,
  required UpdateIconBuilder? iconBuilder,
}) {
  final size = isRequired ? 96.0 : 64.0;
  return UpdateCardData(
    controller: controller,
    texts: strings,
    isRequired: isRequired,
    title: isRequired ? strings.requiredTitle : strings.optionalTitle,
    message: isRequired ? strings.requiredMessage : strings.optionalMessage,
    icon:
        iconBuilder?.call(context, size) ??
        _Emblem(image: appIcon, size: size),
    error: _LaunchError(controller: controller, texts: strings),
    updateButton: UpdateButton(controller: controller, texts: strings),
    laterButton: isRequired
        ? null
        : TextButton(
            onPressed: () => controller.dismissOptional(),
            child: Text(strings.later, textAlign: TextAlign.center),
          ),
    skipButton: isRequired || !allowSkip
        ? null
        : TextButton(
            onPressed: () => controller.dismissOptional(skipVersion: true),
            child: Text(strings.skip, textAlign: TextAlign.center),
          ),
  );
}

Widget _defaultCard(BuildContext context, UpdateCardData data) =>
    UpdateCard.fromData(data);

/// The blocking screen. Use it through [UpdateGate] so back stays blocked.
class RequiredUpdatePage extends StatelessWidget {
  const RequiredUpdatePage({
    super.key,
    required this.controller,
    this.texts,
    this.appIcon,
    this.iconBuilder,
    this.cardBuilder,
  });

  final RemoteConfigController controller;
  final UpdateTexts? texts;

  /// Your app icon, shown on a white tile. Null: the round update icon.
  final ImageProvider? appIcon;

  /// Builds the icon yourself (wins over [appIcon]).
  final UpdateIconBuilder? iconBuilder;

  /// Lays out the whole card yourself.
  final UpdateCardBuilder? cardBuilder;

  @override
  Widget build(BuildContext context) {
    final strings = texts ?? UpdateTexts.of(context);
    return Directionality(
      textDirection: strings.directionOf(context),
      child: Scaffold(
        body: SafeArea(
          child: Center(
            child: SingleChildScrollView(
              padding: const EdgeInsetsDirectional.all(24),
              child: Builder(
                builder: (context) => (cardBuilder ?? _defaultCard)(
                  context,
                  _dataFor(
                    context,
                    controller: controller,
                    strings: strings,
                    isRequired: true,
                    allowSkip: false,
                    appIcon: appIcon,
                    iconBuilder: iconBuilder,
                  ),
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }
}

/// The dismissible "update available" card (Later / Skip this version).
class OptionalUpdateDialog extends StatelessWidget {
  const OptionalUpdateDialog({
    super.key,
    required this.controller,
    this.texts,
    this.allowSkip = true,
    this.appIcon,
    this.iconBuilder,
    this.cardBuilder,
  });

  final RemoteConfigController controller;
  final UpdateTexts? texts;
  final bool allowSkip;

  /// Your app icon, shown on a white tile. Null: the round update icon.
  final ImageProvider? appIcon;

  /// Builds the icon yourself (wins over [appIcon]).
  final UpdateIconBuilder? iconBuilder;

  /// Lays out the whole card yourself.
  final UpdateCardBuilder? cardBuilder;

  @override
  Widget build(BuildContext context) {
    final strings = texts ?? UpdateTexts.of(context);
    return Directionality(
      textDirection: strings.directionOf(context),
      child: Padding(
        padding: const EdgeInsetsDirectional.all(24),
        // Any card, including your own cardBuilder, scrolls instead of
        // overflowing on a short screen (a phone in landscape, big text).
        child: SingleChildScrollView(
          child: Builder(
            builder: (context) => (cardBuilder ?? _defaultCard)(
              context,
              _dataFor(
                context,
                controller: controller,
                strings: strings,
                isRequired: false,
                allowSkip: allowSkip,
                appIcon: appIcon,
                iconBuilder: iconBuilder,
              ),
            ),
          ),
        ),
      ),
    );
  }
}

/// The icon at the top: your image on a white tile, or a round update icon.
class _Emblem extends StatelessWidget {
  const _Emblem({required this.image, required this.size});

  final ImageProvider? image;
  final double size;

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    final fallback = DecoratedBox(
      decoration: BoxDecoration(
        color: scheme.primaryContainer,
        shape: BoxShape.circle,
      ),
      child: SizedBox.square(
        dimension: size,
        child: Icon(
          Icons.system_update,
          size: size / 2,
          color: scheme.onPrimaryContainer,
        ),
      ),
    );
    final provider = image;
    if (provider == null) return fallback;
    final radius = BorderRadius.circular(size / 4);
    return Image(
      image: provider,
      width: size,
      height: size,
      fit: BoxFit.contain,
      excludeFromSemantics: true,
      // The white tile appears only once the image has really loaded, so a
      // broken image shows the plain round icon and nothing else.
      frameBuilder: (context, child, frame, wasSynchronouslyLoaded) =>
          frame == null && !wasSynchronouslyLoaded
          ? SizedBox.square(dimension: size)
          : DecoratedBox(
              decoration: BoxDecoration(
                color: Colors.white,
                borderRadius: radius,
                border: Border.all(color: scheme.outlineVariant),
              ),
              child: ClipRRect(borderRadius: radius, child: child),
            ),
      errorBuilder: (_, _, _) => fallback,
    );
  }
}

class _LaunchError extends StatelessWidget {
  const _LaunchError({required this.controller, required this.texts});

  final RemoteConfigController controller;
  final UpdateTexts texts;

  @override
  Widget build(BuildContext context) => ListenableBuilder(
    listenable: controller,
    builder: (context, _) => controller.actionError == null
        ? const SizedBox.shrink()
        : Semantics(
            liveRegion: true,
            child: Padding(
              padding: const EdgeInsetsDirectional.only(top: 16),
              child: Text(
                texts.launchError,
                textAlign: TextAlign.center,
                style: TextStyle(color: Theme.of(context).colorScheme.error),
              ),
            ),
          ),
  );
}
