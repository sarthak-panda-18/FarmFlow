import 'package:flutter/material.dart';
import '../constants/app_colors.dart';

enum FarmCardVariant { paleGreen, white, greenOutlined, darkGreen }

class FarmCard extends StatelessWidget {
  final Widget child;
  final EdgeInsetsGeometry padding;
  final EdgeInsetsGeometry margin;
  final VoidCallback? onTap;
  final FarmCardVariant variant;
  final double borderRadius;
  final Border? customBorder;

  const FarmCard({
    super.key,
    required this.child,
    this.padding = const EdgeInsets.all(16.0),
    this.margin = EdgeInsets.zero,
    this.onTap,
    this.variant = FarmCardVariant.paleGreen,
    this.borderRadius = 14.0,
    this.customBorder,
  });

  @override
  Widget build(BuildContext context) {
    Color bgColor;
    Border? border;

    switch (variant) {
      case FarmCardVariant.paleGreen:
        bgColor = AppColors.cardSurface;
        border = customBorder ?? Border.all(color: AppColors.border, width: 1);
        break;
      case FarmCardVariant.white:
        bgColor = Colors.white;
        border = customBorder ?? Border.all(color: AppColors.border, width: 1);
        break;
      case FarmCardVariant.greenOutlined:
        bgColor = Colors.white;
        border = customBorder ??
            Border.all(color: AppColors.primaryLight, width: 1.5);
        break;
      case FarmCardVariant.darkGreen:
        bgColor = AppColors.primary;
        border = customBorder;
        break;
    }

    final cardContent = Container(
      margin: margin,
      decoration: BoxDecoration(
        color: bgColor,
        borderRadius: BorderRadius.circular(borderRadius),
        border: border,
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.02),
            blurRadius: 6,
            offset: const Offset(0, 2),
          ),
        ],
      ),
      child: Material(
        color: Colors.transparent,
        borderRadius: BorderRadius.circular(borderRadius),
        child: InkWell(
          onTap: onTap,
          borderRadius: BorderRadius.circular(borderRadius),
          child: Padding(
            padding: padding,
            child: child,
          ),
        ),
      ),
    );

    return cardContent;
  }
}
