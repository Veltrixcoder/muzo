import 'dart:ui';
import 'package:flutter/material.dart';
import 'package:flutter/cupertino.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

void showGlassSnackBar(BuildContext context, String message) {
  final double bottomPadding = MediaQuery.of(context).padding.bottom;
  ScaffoldMessenger.of(context).showSnackBar(
    SnackBar(
      backgroundColor: Colors.transparent,
      elevation: 0,
      behavior: SnackBarBehavior.floating,
      margin: EdgeInsets.only(left: 12, right: 12, bottom: 16 + bottomPadding),
      padding: EdgeInsets.zero,
      content: _GlassSnackBarContent(message: message),
      duration: const Duration(seconds: 2),
    ),
  );
}

class _GlassSnackBarContent extends ConsumerWidget {
  final String message;

  const _GlassSnackBarContent({required this.message});

  IconData _getIconForMessage(String msg) {
    final lower = msg.toLowerCase();
    if (lower.contains('download')) {
      if (lower.contains('complete') || lower.contains('success')) {
        return CupertinoIcons.checkmark_circle_fill;
      }
      if (lower.contains('fail') || lower.contains('error')) {
        return CupertinoIcons.exclamationmark_circle_fill;
      }
      return CupertinoIcons.arrow_down_circle_fill;
    }
    if (lower.contains('queue')) {
      return CupertinoIcons.list_bullet;
    }
    if (lower.contains('favorite')) {
      return CupertinoIcons.star_fill;
    }
    if (lower.contains('history')) {
      return CupertinoIcons.trash_fill;
    }
    return CupertinoIcons.info_circle_fill;
  }

  Color _getIconColor(String msg, Color accentColor) {
    final lower = msg.toLowerCase();
    if (lower.contains('favorite')) {
      return Colors.orange;
    }
    if (lower.contains('fail') || lower.contains('error')) {
      return Colors.red;
    }
    return accentColor;
  }

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final theme = Theme.of(context);
    final isDark = theme.brightness == Brightness.dark;
    final accentColor = theme.colorScheme.primary;

    return ClipRRect(
      borderRadius: BorderRadius.circular(25),
      child: BackdropFilter(
        filter: ImageFilter.blur(sigmaX: 25, sigmaY: 25),
        child: Container(
          padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 16),
          decoration: BoxDecoration(
            color: (isDark ? Colors.black : Colors.white).withValues(alpha: isDark ? 0.20 : 0.35),
            borderRadius: BorderRadius.circular(25),
            border: Border.all(
              color: Colors.white.withValues(alpha: isDark ? 0.12 : 0.20),
              width: 0.75,
            ),
            boxShadow: [
              BoxShadow(
                color: Colors.black.withValues(alpha: isDark ? 0.35 : 0.12),
                blurRadius: 20,
                spreadRadius: -4,
                offset: const Offset(0, 8),
              ),
            ],
          ),
          child: Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              Icon(
                _getIconForMessage(message),
                color: _getIconColor(message, accentColor),
                size: 22,
              ),
              const SizedBox(width: 14),
              Expanded(
                child: Text(
                  message,
                  style: TextStyle(
                    color: theme.colorScheme.onSurface,
                    fontSize: 14,
                    fontWeight: FontWeight.w600,
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
