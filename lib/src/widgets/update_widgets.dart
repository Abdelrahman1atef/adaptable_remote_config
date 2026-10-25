import 'package:flutter/material.dart';

import '../controller.dart';

/// Button and message labels. English by default, Arabic for Arabic locales.
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
      launchError = 'تعذر فتح التحديث. يرجى المحاولة مرة أخرى.';

  final String requiredTitle;
  final String optionalTitle;
  final String requiredMessage;
  final String optionalMessage;
  final String update;
  final String later;
  final String skip;
  final String retry;
  final String launchError;

  static UpdateTexts of(BuildContext context) =>
      Localizations.localeOf(context).languageCode == 'ar'
      ? const UpdateTexts.arabic()
      : const UpdateTexts();
}

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

/// The blocking screen. Use it through [UpdateGate] so back stays blocked.
class RequiredUpdatePage extends StatelessWidget {
  const RequiredUpdatePage({super.key, required this.controller, this.texts});

  final RemoteConfigController controller;
  final UpdateTexts? texts;

  @override
  Widget build(BuildContext context) {
    final strings = texts ?? UpdateTexts.of(context);
    return Scaffold(
      body: SafeArea(
        child: Center(
          child: SingleChildScrollView(
            padding: const EdgeInsetsDirectional.all(24),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                Text(
                  strings.requiredTitle,
                  style: Theme.of(context).textTheme.headlineSmall,
                ),
                const SizedBox(height: 16),
                Text(strings.requiredMessage, textAlign: TextAlign.center),
                const SizedBox(height: 24),
                UpdateButton(controller: controller, texts: strings),
                _LaunchError(controller: controller, texts: strings),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

/// The dismissible "update available" dialog (Later / Skip this version).
class OptionalUpdateDialog extends StatelessWidget {
  const OptionalUpdateDialog({
    super.key,
    required this.controller,
    this.texts,
    this.allowSkip = true,
  });

  final RemoteConfigController controller;
  final UpdateTexts? texts;
  final bool allowSkip;

  @override
  Widget build(BuildContext context) {
    final strings = texts ?? UpdateTexts.of(context);
    return AlertDialog(
      scrollable: true,
      title: Text(strings.optionalTitle),
      content: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(strings.optionalMessage),
          _LaunchError(controller: controller, texts: strings),
        ],
      ),
      actions: [
        if (allowSkip)
          TextButton(
            onPressed: () => controller.dismissOptional(skipVersion: true),
            child: Text(strings.skip),
          ),
        TextButton(
          onPressed: () => controller.dismissOptional(),
          child: Text(strings.later),
        ),
        UpdateButton(controller: controller, texts: strings),
      ],
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
                style: TextStyle(color: Theme.of(context).colorScheme.error),
              ),
            ),
          ),
  );
}
