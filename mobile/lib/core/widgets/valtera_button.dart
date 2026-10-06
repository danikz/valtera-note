import 'package:flutter/material.dart';
import '../theme/app_colors.dart';
import '../theme/app_typography.dart';

enum ValteraButtonVariant { primary, secondary, danger, outline }

class ValteraButton extends StatelessWidget {
  final String text;
  final VoidCallback? onPressed;
  final bool isLoading;
  final IconData? icon;
  final ValteraButtonVariant variant;
  final double? width;

  const ValteraButton({
    super.key,
    required this.text,
    this.onPressed,
    this.isLoading = false,
    this.icon,
    this.variant = ValteraButtonVariant.primary,
    this.width,
  });

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;

    Color bg;
    Color fg;
    BorderSide border = BorderSide.none;

    switch (variant) {
      case ValteraButtonVariant.primary:
        bg = isDark ? AppColors.emeraldAccent : AppColors.primary;
        fg = isDark ? Colors.black : Colors.white;
        break;
      case ValteraButtonVariant.secondary:
        bg = isDark ? AppColors.darkSurfaceVariant : AppColors.lightMuted;
        fg = isDark ? AppColors.darkTextPrimary : AppColors.lightTextPrimary;
        break;
      case ValteraButtonVariant.danger:
        bg = isDark ? AppColors.errorRed.withAlpha(50) : AppColors.destructive.withAlpha(30);
        fg = isDark ? AppColors.errorRed : AppColors.destructive;
        border = BorderSide(color: isDark ? AppColors.errorRed : AppColors.destructive, width: 1);
        break;
      case ValteraButtonVariant.outline:
        bg = Colors.transparent;
        fg = isDark ? AppColors.darkTextPrimary : AppColors.lightTextPrimary;
        border = BorderSide(color: isDark ? AppColors.darkBorder : AppColors.lightBorder, width: 1);
        break;
    }

    return SizedBox(
      width: width,
      height: 48, // Minimum touch target 48dp (UI/UX Pro Max rule)
      child: ElevatedButton(
        style: ElevatedButton.styleFrom(
          backgroundColor: bg,
          foregroundColor: fg,
          elevation: 0,
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(10),
            side: border,
          ),
          padding: const EdgeInsets.symmetric(horizontal: 16),
        ),
        onPressed: isLoading ? null : onPressed,
        child: isLoading
            ? SizedBox(
                width: 20,
                height: 20,
                child: CircularProgressIndicator(
                  strokeWidth: 2,
                  color: fg,
                ),
              )
            : Row(
                mainAxisSize: MainAxisSize.min,
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  if (icon != null) ...[
                    Icon(icon, size: 18, color: fg),
                    const SizedBox(width: 8),
                  ],
                  Text(
                    text,
                    style: AppTypography.labelMedium(
                      color: fg,
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                ],
              ),
      ),
    );
  }
}
