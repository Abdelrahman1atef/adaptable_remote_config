import 'package:flutter/material.dart';

/// A titled group of controls.
class Section extends StatelessWidget {
  const Section({super.key, required this.title, this.hint, required this.children});

  final String title;
  final String? hint;
  final List<Widget> children;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Padding(
      padding: const EdgeInsets.only(bottom: 20),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(title, style: theme.textTheme.titleSmall),
          if (hint != null)
            Padding(
              padding: const EdgeInsets.only(top: 2),
              child: Text(
                hint!,
                style: theme.textTheme.bodySmall?.copyWith(
                  color: theme.colorScheme.onSurfaceVariant,
                ),
              ),
            ),
          const SizedBox(height: 8),
          ...children,
        ],
      ),
    );
  }
}

/// One choice out of several, shown as chips that wrap onto more lines.
class ChoiceRow<T> extends StatelessWidget {
  const ChoiceRow({
    super.key,
    required this.value,
    required this.options,
    required this.onChanged,
  });

  final T value;
  final Map<T, String> options;
  final ValueChanged<T> onChanged;

  @override
  Widget build(BuildContext context) => Wrap(
    spacing: 8,
    runSpacing: 4,
    children: [
      for (final entry in options.entries)
        ChoiceChip(
          label: Text(entry.value),
          selected: entry.key == value,
          onSelected: (_) => onChanged(entry.key),
        ),
    ],
  );
}

/// A text field that follows its [value] (so presets can fill it) and reports
/// edits through [onChanged].
class LabeledField extends StatefulWidget {
  const LabeledField({
    super.key,
    required this.label,
    required this.value,
    required this.onChanged,
    this.helper,
    this.onSubmitted,
  });

  final String label;
  final String value;
  final String? helper;
  final ValueChanged<String> onChanged;
  final ValueChanged<String>? onSubmitted;

  @override
  State<LabeledField> createState() => _LabeledFieldState();
}

class _LabeledFieldState extends State<LabeledField> {
  late final TextEditingController _controller = TextEditingController(
    text: widget.value,
  );
  final FocusNode _focus = FocusNode();

  @override
  void didUpdateWidget(LabeledField oldWidget) {
    super.didUpdateWidget(oldWidget);
    // A preset changed the value from outside: show it, unless being typed in.
    if (!_focus.hasFocus && _controller.text != widget.value) {
      _controller.text = widget.value;
    }
  }

  @override
  void dispose() {
    _controller.dispose();
    _focus.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) => Padding(
    padding: const EdgeInsets.only(bottom: 12),
    child: TextField(
      controller: _controller,
      focusNode: _focus,
      onChanged: widget.onChanged,
      onSubmitted: widget.onSubmitted,
      decoration: InputDecoration(
        labelText: widget.label,
        helperText: widget.helper,
        helperMaxLines: 3,
        border: const OutlineInputBorder(),
        isDense: true,
      ),
    ),
  );
}

class SwitchRow extends StatelessWidget {
  const SwitchRow({
    super.key,
    required this.label,
    required this.value,
    required this.onChanged,
    this.subtitle,
  });

  final String label;
  final String? subtitle;
  final bool value;
  final ValueChanged<bool>? onChanged;

  @override
  Widget build(BuildContext context) => SwitchListTile(
    contentPadding: EdgeInsets.zero,
    dense: true,
    title: Text(label),
    subtitle: subtitle == null ? null : Text(subtitle!),
    value: value,
    onChanged: onChanged,
  );
}

/// Small monospace text, for code and logs.
class Code extends StatelessWidget {
  const Code(this.text, {super.key});

  final String text;

  @override
  Widget build(BuildContext context) => Container(
    width: double.infinity,
    padding: const EdgeInsets.all(12),
    decoration: BoxDecoration(
      color: Theme.of(context).colorScheme.surfaceContainerHighest,
      borderRadius: BorderRadius.circular(8),
    ),
    child: SelectableText(
      text,
      style: const TextStyle(fontFamily: 'monospace', fontSize: 12, height: 1.4),
    ),
  );
}
