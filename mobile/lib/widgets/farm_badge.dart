import 'package:flutter/material.dart';
import '../constants/app_colors.dart';

enum FarmBadgeType { success, warning, error, info, neutral, primary }

class FarmBadge extends StatelessWidget {
  final String label;
  final IconData? icon;
  final FarmBadgeType type;
  final double fontSize;
  final EdgeInsetsGeometry padding;

  const FarmBadge({
    super.key,
    required this.label,
    this.icon,
    this.type = FarmBadgeType.neutral,
    this.fontSize = 11.0,
    this.padding = const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
  });

  @override
  Widget build(BuildContext context) {
    Color bg;
    Color fg;
    Color borderColor;

    switch (type) {
      case FarmBadgeType.success:
        bg = AppColors.successLight;
        fg = AppColors.successDark;
        borderColor = const Color(0xFFBBF7D0);
        break;
      case FarmBadgeType.warning:
        bg = AppColors.warningLight;
        fg = AppColors.warningDark;
        borderColor = const Color(0xFFFDE68A);
        break;
      case FarmBadgeType.error:
        bg = AppColors.errorLight;
        fg = AppColors.errorDark;
        borderColor = const Color(0xFFFECACA);
        break;
      case FarmBadgeType.info:
        bg = AppColors.infoLight;
        fg = AppColors.infoDark;
        borderColor = const Color(0xFFBAE6FD);
        break;
      case FarmBadgeType.primary:
        bg = const Color(0xFFE2EFE0);
        fg = AppColors.primary;
        borderColor = const Color(0xFFC7E2C3);
        break;
      case FarmBadgeType.neutral:
        bg = const Color(0xFFF1F5F9);
        fg = const Color(0xFF475569);
        borderColor = const Color(0xFFE2E8F0);
        break;
    }

    return Container(
      padding: padding,
      decoration: BoxDecoration(
        color: bg,
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: borderColor, width: 0.8),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          if (icon != null) ...[
            Icon(icon, size: fontSize + 2, color: fg),
            const SizedBox(width: 4),
          ],
          Text(
            label,
            style: TextStyle(
              fontSize: fontSize,
              fontWeight: FontWeight.bold,
              color: fg,
              letterSpacing: 0.2,
            ),
          ),
        ],
      ),
    );
  }
}
