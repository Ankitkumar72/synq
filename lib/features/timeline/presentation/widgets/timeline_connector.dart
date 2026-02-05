import 'package:flutter/material.dart';
import '../../../../core/theme/app_theme.dart';

class TimelineConnector extends StatelessWidget {
  final bool isLast;
  final bool isActive;

  const TimelineConnector({
    super.key,
    this.isLast = false,
    this.isActive = false,
  });

  @override
  Widget build(BuildContext context) {
    return Column(
      children: [
        if (isActive) ...[
          Container(
            width: 12,
            height: 12,
            decoration: const BoxDecoration(
              color: AppColors.primary,
              shape: BoxShape.circle,
            ),
          ),
          const SizedBox(height: 4),
        ],
        Expanded(
          child: Container(
            width: 2,
            color: isActive ? AppColors.primary : Colors.grey.withOpacity(0.2),
          ),
        ),
      ],
    );
  }
}
