import 'package:flutter/material.dart';

import '../controller.dart';

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

/// Where the update screens look for your app icon when none is given.
/// Put a square PNG here and list it under `flutter: assets:` in pubspec.yaml.
const defaultAppIconAsset = 'assets/app_icon.png';

/// Replaces a default screen while the controller keeps all the behavior.
typedef UpdateWidgetBuilder =
    Widget Function(BuildContext context, RemoteConfigController controller);

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

/// The card both update screens are made of: an icon, a title, a message and
/// the actions. Everything is laid out with start/end, never left/right, so it
/// reads correctly in both text directions. Pass [centered] for the wall.
class UpdateCard extends StatelessWidget {
  const UpdateCard({
    super.key,
    required this.title,
    required this.message,
    required this.actions,
    this.error,
    this.icon = Icons.system_update,
    this.image,
    this.centered = false,
    this.elevated = true,
  });

  final String title;
  final String message;
  final List<Widget> actions;
  final Widget? error;
  final IconData icon;

  /// Your app icon. Shown instead of [icon]; if it cannot be loaded (for
  /// example the file is missing) [icon] is shown.
  final ImageProvider? image;

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
          _Emblem(
            image: image,
            icon: icon,
            size: elevated ? 64 : 96,
          ),
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

/// The blocking screen. Use it through [UpdateGate] so back stays blocked.
class RequiredUpdatePage extends StatelessWidget {
  const RequiredUpdatePage({
    super.key,
    required this.controller,
    this.texts,
    this.appIcon = const AssetImage(defaultAppIconAsset),
    this.showAppIcon = true,
  });

  final RemoteConfigController controller;
  final UpdateTexts? texts;

  /// Your app icon. Missing file: the update icon is shown instead.
  final ImageProvider? appIcon;

  /// False hides the app icon and always shows the update icon.
  final bool showAppIcon;

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
              child: UpdateCard(
                centered: true,
                elevated: false,
                image: showAppIcon ? appIcon : null,
                title: strings.requiredTitle,
                message: strings.requiredMessage,
                error: _LaunchError(controller: controller, texts: strings),
                actions: [UpdateButton(controller: controller, texts: strings)],
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
    this.appIcon = const AssetImage(defaultAppIconAsset),
    this.showAppIcon = true,
  });

  final RemoteConfigController controller;
  final UpdateTexts? texts;
  final bool allowSkip;

  /// Your app icon. Missing file: the update icon is shown instead.
  final ImageProvider? appIcon;

  /// False hides the app icon and always shows the update icon.
  final bool showAppIcon;

  @override
  Widget build(BuildContext context) {
    final strings = texts ?? UpdateTexts.of(context);
    return Directionality(
      textDirection: strings.directionOf(context),
      child: Padding(
        padding: const EdgeInsetsDirectional.all(24),
        child: UpdateCard(
          image: showAppIcon ? appIcon : null,
          title: strings.optionalTitle,
          message: strings.optionalMessage,
          error: _LaunchError(controller: controller, texts: strings),
          actions: [
            UpdateButton(controller: controller, texts: strings),
            const SizedBox(height: 8),
            Row(
              children: [
                Expanded(
                  child: TextButton(
                    onPressed: () => controller.dismissOptional(),
                    child: Text(strings.later, textAlign: TextAlign.center),
                  ),
                ),
                if (allowSkip)
                  Expanded(
                    child: TextButton(
                      onPressed: () =>
                          controller.dismissOptional(skipVersion: true),
                      child: Text(strings.skip, textAlign: TextAlign.center),
                    ),
                  ),
              ],
            ),
          ],
        ),
      ),
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

/// The icon at the top of the card: your app icon, or a round update icon.
class _Emblem extends StatelessWidget {
  const _Emblem({required this.image, required this.icon, required this.size});

  final ImageProvider? image;
  final IconData icon;
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
        child: Icon(icon, size: size / 2, color: scheme.onPrimaryContainer),
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
      // The white frame appears only once the image has really loaded, so a
      // missing file shows the plain round icon and nothing else.
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
