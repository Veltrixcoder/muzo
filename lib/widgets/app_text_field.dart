import 'package:flutter/cupertino.dart';
import 'package:flutter/material.dart';

class AppTextField extends StatelessWidget {
  final TextEditingController? controller;
  final String placeholder;
  final TextInputType keyboardType;
  final int? maxLines;
  final int? minLines;
  final Widget? prefix;
  final ValueChanged<String>? onChanged;
  final bool enabled;
  final FocusNode? focusNode;
  final TextInputAction? textInputAction;
  final ValueChanged<String>? onSubmitted;
  final BorderRadius? borderRadius;

  const AppTextField({
    super.key,
    this.controller,
    required this.placeholder,
    this.keyboardType = TextInputType.text,
    this.maxLines = 1,
    this.minLines,
    this.prefix,
    this.onChanged,
    this.enabled = true,
    this.focusNode,
    this.textInputAction,
    this.onSubmitted,
    this.borderRadius,
  });

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final cs = theme.colorScheme;

    // Use a smaller radius if it's a multi-line text area, otherwise fully rounded capsule/pill
    final isMultiLine = maxLines != null && maxLines! > 1;
    final effectiveBorderRadius = borderRadius ?? BorderRadius.circular(isMultiLine ? 16 : 22);

    return CupertinoTextField(
      controller: controller,
      keyboardType: keyboardType,
      maxLines: maxLines,
      minLines: minLines,
      enabled: enabled,
      focusNode: focusNode,
      textInputAction: textInputAction,
      onSubmitted: onSubmitted,
      placeholder: placeholder,
      placeholderStyle: TextStyle(
        color: cs.onSurface.withValues(alpha: 0.35),
        fontSize: 13.5,
        fontWeight: FontWeight.w400,
        fontFamily: theme.textTheme.bodyMedium?.fontFamily,
      ),
      style: TextStyle(
        color: cs.onSurface,
        fontSize: 13.5,
        fontWeight: FontWeight.w500,
        fontFamily: theme.textTheme.bodyMedium?.fontFamily,
      ),
      decoration: BoxDecoration(
        color: cs.onSurface.withValues(alpha: 0.04),
        borderRadius: effectiveBorderRadius,
        border: Border.all(
          color: cs.onSurface.withValues(alpha: 0.08),
          width: 0.8,
        ),
      ),
      padding: EdgeInsets.symmetric(
        horizontal: 16,
        vertical: isMultiLine ? 10 : 8,
      ),
      prefix: prefix != null
          ? Padding(
              padding: const EdgeInsets.only(left: 12.0),
              child: prefix,
            )
          : null,
      onChanged: onChanged,
    );
  }
}
