import 'package:flutter/material.dart';
import '../../../../core/theme/app_colors.dart';
import '../../../../core/theme/app_text_styles.dart';
import '../../../../core/theme/app_spacing.dart';

class TrackingButton extends StatelessWidget {
  final bool isTracking;
  final VoidCallback onStart;
  final VoidCallback onStop;

  const TrackingButton({
    super.key,
    required this.isTracking,
    required this.onStart,
    required this.onStop,
  });

  @override
  Widget build(BuildContext context) {
    return Column(
      children: [
        _GradientBtn(
          label: 'START TRACKING',
          icon: Icons.play_arrow_rounded,
          gradient: AppColors.startGradient,
          glowColor: AppColors.active,
          enabled: !isTracking,
          onTap: onStart,
        ),
        const SizedBox(height: AppSpacing.md),
        _GradientBtn(
          label: 'STOP TRACKING',
          icon: Icons.stop_rounded,
          gradient: AppColors.stopGradient,
          glowColor: AppColors.error,
          enabled: isTracking,
          onTap: onStop,
        ),
      ],
    );
  }
}

class _GradientBtn extends StatelessWidget {
  final String label;
  final IconData icon;
  final LinearGradient gradient;
  final Color glowColor;
  final bool enabled;
  final VoidCallback onTap;

  const _GradientBtn({
    required this.label,
    required this.icon,
    required this.gradient,
    required this.glowColor,
    required this.enabled,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: enabled ? onTap : null,
      child: AnimatedOpacity(
        opacity: enabled ? 1.0 : 0.28,
        duration: const Duration(milliseconds: 250),
        child: Container(
          width: double.infinity,
          height: 56,
          decoration: BoxDecoration(
            gradient: gradient,
            borderRadius: BorderRadius.circular(AppSpacing.radiusXxl),
            boxShadow: enabled
                ? [
                    BoxShadow(
                      color: glowColor.withValues(alpha: 0.32),
                      blurRadius: 18,
                      offset: const Offset(0, 6),
                    ),
                  ]
                : null,
          ),
          child: Row(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Icon(icon, color: Colors.white, size: 22),
              const SizedBox(width: 8),
              Text(label, style: AppTextStyles.button),
            ],
          ),
        ),
      ),
    );
  }
}
