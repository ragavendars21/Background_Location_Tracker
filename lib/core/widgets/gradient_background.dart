import 'package:flutter/material.dart';
import '../theme/app_colors.dart';

/// Full-screen gradient background with decorative ambient glow blobs.
class GradientBackground extends StatelessWidget {
  final Widget child;

  const GradientBackground({super.key, required this.child});

  @override
  Widget build(BuildContext context) {
    return Container(
      decoration: const BoxDecoration(gradient: AppColors.bgGradient),
      child: Stack(
        children: [
          Positioned(
            top: -80,
            right: -80,
            child: _GlowBlob(
              color: AppColors.brand.withValues(alpha: 0.09),
              size: 280,
            ),
          ),
          Positioned(
            top: 260,
            left: -100,
            child: _GlowBlob(
              color: AppColors.purple.withValues(alpha: 0.07),
              size: 220,
            ),
          ),
          Positioned(
            bottom: 80,
            right: -50,
            child: _GlowBlob(
              color: AppColors.accent.withValues(alpha: 0.05),
              size: 190,
            ),
          ),
          child,
        ],
      ),
    );
  }
}

class _GlowBlob extends StatelessWidget {
  final Color color;
  final double size;

  const _GlowBlob({required this.color, required this.size});

  @override
  Widget build(BuildContext context) {
    return Container(
      width: size,
      height: size,
      decoration: BoxDecoration(shape: BoxShape.circle, color: color),
    );
  }
}
