import 'dart:ui';
import 'package:flutter/material.dart';

import 'package:flutter_riverpod/flutter_riverpod.dart';

class GlassContainer extends ConsumerWidget {
  final Widget child;
  final double blur;
  final double opacity;
  final Color color;
  final BorderRadius? borderRadius;
  final EdgeInsetsGeometry? padding;
  final EdgeInsetsGeometry? margin;
  final BoxBorder? border;

  const GlassContainer({
    super.key,
    required this.child,
    this.blur = 15.0,
    this.opacity = 0.2,
    this.color = Colors.white,
    this.borderRadius,
    this.padding,
    this.margin,
    this.border,
  });

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final isDarkTheme = Theme.of(context).brightness == Brightness.dark;
    
    // Override defaults with navbar styling if not explicitly set
    final effectiveColor = color == Colors.white 
        ? (isDarkTheme ? Colors.black : Colors.white) 
        : color;
    final effectiveOpacity = opacity == 0.2 
        ? (isDarkTheme ? 0.20 : 0.35) 
        : opacity;
    final effectiveBlur = blur == 15.0 ? 25.0 : blur;
    final effectiveRadius = borderRadius ?? BorderRadius.circular(28);
    final effectiveBorder = border ?? Border.all(
      color: Colors.white.withValues(alpha: isDarkTheme ? 0.12 : 0.20),
      width: 0.75,
    );

    return Container(
      margin: margin,
      child: ClipRRect(
        borderRadius: effectiveRadius,
        child: BackdropFilter(
          filter: ImageFilter.blur(sigmaX: effectiveBlur, sigmaY: effectiveBlur),
          child: Container(
            padding: padding,
            decoration: BoxDecoration(
              color: effectiveColor.withValues(alpha: effectiveOpacity),
              borderRadius: effectiveRadius,
              border: effectiveBorder,
            ),
            child: child,
          ),
        ),
      ),
    );
  }
}
