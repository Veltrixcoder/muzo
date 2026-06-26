import 'package:flutter/material.dart';
import 'package:muzo/widgets/glass_container.dart';

class AppAlertDialog extends StatelessWidget {
  final String title;
  final Widget content;
  final List<Widget> actions;

  const AppAlertDialog({
    super.key,
    required this.title,
    required this.content,
    required this.actions,
  });

  bool _isActionPrimary(Widget action, int index) {
    Widget? child;
    if (action is TextButton) {
      child = action.child;
    } else if (action is ElevatedButton) {
      child = action.child;
    }
    if (child == null) return index == 0;

    String text = '';
    if (child is Text) {
      text = (child.data ?? '').toLowerCase();
    }

    final negativeWords = ['cancel', 'not now', 'ignore', 'close', 'no', 'dismiss', 'later'];
    final positiveWords = ['ok', 'yes', 'enable', 'join', 'confirm', 'agree', 'allow', 'done', 'save', 'delete', 'create'];

    bool isPrimary = index == 0; // Default fallback for sorted actions: left is primary
    if (negativeWords.any((w) => text.contains(w))) {
      isPrimary = false;
    } else if (positiveWords.any((w) => text.contains(w))) {
      isPrimary = true;
    }
    return isPrimary;
  }

  Widget _overrideTextColor(Widget widget, Color color) {
    if (widget is Text) {
      return Text(
        widget.data ?? '',
        style: (widget.style ?? const TextStyle()).copyWith(color: color),
        strutStyle: widget.strutStyle,
        textAlign: widget.textAlign,
        textDirection: widget.textDirection,
        locale: widget.locale,
        softWrap: widget.softWrap,
        overflow: widget.overflow,
        textScaler: widget.textScaler,
        maxLines: widget.maxLines,
        semanticsLabel: widget.semanticsLabel,
        textWidthBasis: widget.textWidthBasis,
        textHeightBehavior: widget.textHeightBehavior,
        selectionColor: widget.selectionColor,
      );
    }
    if (widget is Row) {
      return Row(
        mainAxisAlignment: widget.mainAxisAlignment,
        mainAxisSize: widget.mainAxisSize,
        crossAxisAlignment: widget.crossAxisAlignment,
        textDirection: widget.textDirection,
        verticalDirection: widget.verticalDirection,
        textBaseline: widget.textBaseline,
        children: widget.children.map((c) => _overrideTextColor(c, color)).toList(),
      );
    }
    return widget;
  }

  Widget _buildCapsuleAction(BuildContext context, Widget action, int index, int totalCount) {
    final theme = Theme.of(context);
    final isDark = theme.brightness == Brightness.dark;

    VoidCallback? onPressed;
    Widget? child;

    if (action is TextButton) {
      onPressed = action.onPressed;
      child = action.child;
    } else if (action is ElevatedButton) {
      onPressed = action.onPressed;
      child = action.child;
    }

    if (child == null) return action;

    String text = '';
    if (child is Text) {
      text = (child.data ?? '').toLowerCase();
    }

    final negativeWords = ['cancel', 'not now', 'ignore', 'close', 'no', 'dismiss', 'later'];
    final positiveWords = ['ok', 'yes', 'enable', 'join', 'confirm', 'agree', 'allow', 'done', 'save', 'delete', 'create'];

    bool isPrimary = index == 0; // The left/first button is primary by default
    if (negativeWords.any((w) => text.contains(w))) {
      isPrimary = false;
    } else if (positiveWords.any((w) => text.contains(w))) {
      isPrimary = true;
    }

    final isDestructive = text.contains('delete') || text.contains('remove') || text.contains('logout') || text.contains('sign out') || text.contains('clear');

    final Color bg = isPrimary
        ? (isDestructive ? Colors.red : theme.primaryColor)
        : (isDark ? Colors.white.withValues(alpha: 0.12) : Colors.black.withValues(alpha: 0.06));

    final Color fg = isPrimary
        ? (isDestructive ? Colors.white : theme.colorScheme.onPrimary)
        : (isDestructive ? Colors.red : theme.colorScheme.onSurface);

    final Widget finalChild = _overrideTextColor(child, fg);

    return SizedBox(
      height: 38,
      child: Material(
        color: bg,
        shape: const StadiumBorder(),
        clipBehavior: Clip.antiAlias,
        child: InkWell(
          onTap: onPressed,
          child: Center(
            child: Padding(
              padding: const EdgeInsets.symmetric(horizontal: 16),
              child: DefaultTextStyle(
                style: TextStyle(
                  color: fg,
                  fontWeight: FontWeight.bold,
                  fontSize: 13,
                ),
                child: finalChild,
              ),
            ),
          ),
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Dialog(
      backgroundColor: Colors.transparent, // Important for glass effect
      insetPadding: const EdgeInsets.symmetric(horizontal: 44, vertical: 24),
      child: GlassContainer(
        borderRadius: BorderRadius.circular(25),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Padding(
              padding: const EdgeInsets.fromLTRB(20, 24, 20, 4),
              child: Text(
                title,
                textAlign: TextAlign.center,
                style: TextStyle(
                  color: Theme.of(context).colorScheme.onSurface,
                  fontSize: 17,
                  fontWeight: FontWeight.w600,
                  letterSpacing: -0.4,
                ),
              ),
            ),
            Padding(
              padding: const EdgeInsets.fromLTRB(20, 4, 20, 20),
              child: DefaultTextStyle(
                style: TextStyle(
                  color: Theme.of(context).colorScheme.onSurface.withValues(alpha: 0.8),
                  fontSize: 13,
                  height: 1.35,
                  letterSpacing: -0.1,
                ),
                textAlign: TextAlign.center,
                child: content,
              ),
            ),
            if (actions.isNotEmpty) ...[
              Padding(
                padding: const EdgeInsets.fromLTRB(16, 0, 16, 16),
                child: Builder(
                  builder: (context) {
                    if (actions.length == 2) {
                      final is0Primary = _isActionPrimary(actions[0], 0);
                      final is1Primary = _isActionPrimary(actions[1], 1);

                      final List<Widget> sortedActions = List.from(actions);
                      if (!is0Primary && is1Primary) {
                        sortedActions[0] = actions[1];
                        sortedActions[1] = actions[0];
                      }

                      return Row(
                        children: [
                          Expanded(
                            child: _buildCapsuleAction(context, sortedActions[0], 0, 2),
                          ),
                          const SizedBox(width: 10),
                          Expanded(
                            child: _buildCapsuleAction(context, sortedActions[1], 1, 2),
                          ),
                        ],
                      );
                    } else {
                      return Column(
                        crossAxisAlignment: CrossAxisAlignment.stretch,
                        children: List.generate(actions.length, (index) {
                          return Padding(
                            padding: EdgeInsets.only(
                              bottom: index < actions.length - 1 ? 8 : 0,
                            ),
                            child: _buildCapsuleAction(context, actions[index], index, actions.length),
                          );
                        }),
                      );
                    }
                  },
                ),
              ),
            ],
          ],
        ),
      ),
    );
  }
}

Future<T?> showAppAlertDialog<T>({
  required BuildContext context,
  required String title,
  required Widget content,
  List<Widget>? actions,
  List<Widget> Function(BuildContext dialogContext)? actionsBuilder,
}) {
  return showDialog<T>(
    context: context,
    builder: (dialogContext) => AppAlertDialog(
      title: title,
      content: content,
      actions: actionsBuilder != null ? actionsBuilder(dialogContext) : (actions ?? []),
    ),
  );
}
