import 'package:flutter/material.dart';
import '../../../../core/theme/app_colors.dart';
import '../../../../core/theme/app_text_styles.dart';
import '../../../../core/theme/app_spacing.dart';
import '../../../../core/widgets/glass_card.dart';

class BatteryDisplay extends StatelessWidget {
  final int? percentage;

  const BatteryDisplay({super.key, this.percentage});

  Color get _color {
    if (percentage == null) return AppColors.textMuted;
    if (percentage! >= 50) return AppColors.active;
    if (percentage! >= 20) return AppColors.warning;
    return AppColors.error;
  }

  @override
  Widget build(BuildContext context) {
    return GlassCard(
      padding: const EdgeInsets.symmetric(
        horizontal: AppSpacing.md,
        vertical: AppSpacing.md - 2,
      ),
      child: Row(
        children: [
          Icon(Icons.bolt_rounded, size: 18, color: _color),
          const SizedBox(width: AppSpacing.sm),
          Text(
            'Battery',
            style: AppTextStyles.h3.copyWith(color: AppColors.textSecondary),
          ),
          const Spacer(),
          Text(
            percentage != null ? '$percentage%' : '--',
            style: AppTextStyles.h2.copyWith(color: _color),
          ),
        ],
      ),
    );
  }
}
