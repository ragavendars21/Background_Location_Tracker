import 'package:flutter/material.dart';
import '../../domain/entities/location_entity.dart';
import '../../../../core/theme/app_colors.dart';
import '../../../../core/theme/app_text_styles.dart';
import '../../../../core/theme/app_spacing.dart';
import '../../../../core/widgets/glass_card.dart';
import '../../../../core/utils/date_formatter.dart';

class LocationTile extends StatelessWidget {
  final LocationEntity location;
  final int index;

  const LocationTile({super.key, required this.location, required this.index});

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(bottom: AppSpacing.sm + 4),
      child: GlassCard(
        padding: const EdgeInsets.symmetric(
          horizontal: AppSpacing.md,
          vertical: AppSpacing.md - 2,
        ),
        child: Row(
          crossAxisAlignment: CrossAxisAlignment.center,
          children: [
            // Index badge
            Container(
              width: 38,
              height: 38,
              decoration: BoxDecoration(
                gradient: AppColors.brandGradient,
                borderRadius: BorderRadius.circular(AppSpacing.radiusMd),
              ),
              alignment: Alignment.center,
              child: Text(
                '$index',
                style: AppTextStyles.label.copyWith(
                  color: Colors.white,
                  fontSize: 11,
                ),
              ),
            ),
            const SizedBox(width: AppSpacing.md),
            // Coordinates + meta
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    '${location.latitude.toStringAsFixed(6)}°N',
                    style: AppTextStyles.mono.copyWith(
                      color: AppColors.textPrimary,
                      fontSize: 12,
                    ),
                  ),
                  Text(
                    '${location.longitude.toStringAsFixed(6)}°E',
                    style: AppTextStyles.mono.copyWith(
                      color: AppColors.textPrimary,
                      fontSize: 12,
                    ),
                  ),
                  const SizedBox(height: 4),
                  Row(
                    children: [
                      _Tag(
                        icon: Icons.my_location_rounded,
                        label: '±${location.accuracy.toStringAsFixed(1)}m',
                        color: AppColors.brand,
                      ),
                      const SizedBox(width: AppSpacing.sm),
                      Flexible(
                        child: _Tag(
                          icon: Icons.access_time_rounded,
                          label: DateFormatter.timestampToShort(
                              location.timestamp),
                          color: AppColors.textMuted,
                          overflow: true,
                        ),
                      ),
                    ],
                  ),
                ],
              ),
            ),
            const SizedBox(width: AppSpacing.sm),
            const Icon(
              Icons.chevron_right_rounded,
              size: 16,
              color: AppColors.textMuted,
            ),
          ],
        ),
      ),
    );
  }
}

class _Tag extends StatelessWidget {
  final IconData icon;
  final String label;
  final Color color;
  final bool overflow;

  const _Tag({
    required this.icon,
    required this.label,
    required this.color,
    this.overflow = false,
  });

  @override
  Widget build(BuildContext context) {
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        Icon(icon, size: 10, color: color),
        const SizedBox(width: 3),
        overflow
            ? Flexible(
                child: Text(
                  label,
                  style: AppTextStyles.bodySmall.copyWith(color: color),
                  overflow: TextOverflow.ellipsis,
                ),
              )
            : Text(
                label,
                style: AppTextStyles.bodySmall.copyWith(color: color),
              ),
      ],
    );
  }
}
