import 'package:flutter/material.dart';
import '../theme/app_colors.dart';
import '../theme/app_typography.dart';

enum SyncDisplayStatus { local, syncing, synced, error }

class StatusIndicator extends StatelessWidget {
  final SyncDisplayStatus status;
  final String? customMessage;

  const StatusIndicator({
    super.key,
    required this.status,
    this.customMessage,
  });

  @override
  Widget build(BuildContext context) {
    Color dotColor;
    String label;

    switch (status) {
      case SyncDisplayStatus.synced:
        dotColor = AppColors.success;
        label = customMessage ?? 'Synced';
        break;
      case SyncDisplayStatus.local:
        dotColor = AppColors.warning;
        label = customMessage ?? 'Local';
        break;
      case SyncDisplayStatus.syncing:
        dotColor = AppColors.primary;
        label = customMessage ?? 'Syncing...';
        break;
      case SyncDisplayStatus.error:
        dotColor = AppColors.errorRed;
        label = customMessage ?? 'Error';
        break;
    }

    final isDark = Theme.of(context).brightness == Brightness.dark;

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
      decoration: BoxDecoration(
        color: dotColor.withAlpha(isDark ? 35 : 25),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(
          color: dotColor.withAlpha(isDark ? 80 : 60),
          width: 0.8,
        ),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Container(
            width: 6,
            height: 6,
            decoration: BoxDecoration(
              color: dotColor,
              shape: BoxShape.circle,
            ),
          ),
          const SizedBox(width: 5),
          Text(
            label,
            style: AppTypography.bodySmall(
              color: dotColor,
            ).copyWith(fontWeight: FontWeight.w600, fontSize: 11),
          ),
        ],
      ),
    );
  }
}
