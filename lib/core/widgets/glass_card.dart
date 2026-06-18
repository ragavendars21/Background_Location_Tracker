import 'dart:ui';
import 'package:flutter/material.dart';
import '../theme/app_colors.dart';
import '../theme/app_spacing.dart';

/// Frosted-glass card. Place over any coloured/gradient background.
class GlassCard extends StatelessWidget {
  final Widget child;
  final EdgeInsetsGeometry? padding;
  final double? width;
  final double? height;
  final double borderRadius;
  final Gradient? gradient;
  final Color? color;
  final Color? borderColor;
  final VoidCallback? onTap;

  const GlassCard({
    super.key,
    required this.child,
    this.padding,
    this.width,
    this.height,
    this.borderRadius = AppSpacing.radiusXl,
    this.gradient,
    this.color,
    this.borderColor,
    this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    // RepaintBoundary tells Flutter's compositor that this subtree should be
    // painted on its own layer. Without it, BackdropFilter forces everything
    // ABOVE this card in the widget tree to repaint whenever this card
    // needs a repaint (e.g., during the 60fps entry animation). With it,
    // each card paints independently — the stagger animation no longer
    // triggers a full-screen repaint cascade through the blur shader.
    //
    // WHY THIS MATTERS: the home screen has 6+ GlassCards. Without boundaries,
    // a 1-second setState (session timer) triggers 6 blur re-composites per
    // frame. With boundaries, only the card whose content changed repaints.
    Widget card = RepaintBoundary(
      child: ClipRRect(
        borderRadius: BorderRadius.circular(borderRadius),
        child: BackdropFilter(
          filter: ImageFilter.blur(sigmaX: 14, sigmaY: 14),
          child: Container(
            width: width,
            height: height,
            padding: padding ?? const EdgeInsets.all(AppSpacing.md),
            decoration: BoxDecoration(
              gradient: gradient,
              color: gradient == null ? (color ?? AppColors.glassWhite) : null,
              borderRadius: BorderRadius.circular(borderRadius),
              border: Border.all(
                color: borderColor ?? AppColors.glassBorder,
                width: 1,
              ),
            ),
            child: child,
          ),
        ),
      ),
    );

    if (onTap != null) {
      return GestureDetector(onTap: onTap, child: card);
    }
    return card;
  }
}
