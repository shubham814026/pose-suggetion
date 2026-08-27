import 'package:flutter/material.dart';
import '../../../../core/theme/app_theme.dart';
import '../../data/models/target_pose.dart';
import 'mini_silhouette_painter.dart';

/// Interactive bottom carousel card for a single recommended target pose.
/// Displays a live vector silhouette preview, pose title, and dynamic match badge.
class PoseThumbnailCard extends StatelessWidget {
  final TargetPose pose;
  final bool isSelected;
  final int matchScore;
  final VoidCallback onTap;

  const PoseThumbnailCard({
    super.key,
    required this.pose,
    required this.isSelected,
    required this.matchScore,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    final Color accentColor = isSelected ? AppTheme.primaryCyan : Colors.white;
    final Color scoreBadgeColor = matchScore >= 80
        ? AppTheme.successGreen
        : (matchScore >= 50 ? AppTheme.primaryCyan : AppTheme.warningAmber);

    return GestureDetector(
      onTap: onTap,
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 200),
        curve: Curves.easeInOut,
        width: 82,
        margin: const EdgeInsets.only(right: 8),
        padding: const EdgeInsets.symmetric(horizontal: 4, vertical: 4),
        decoration: BoxDecoration(
          color: isSelected ? const Color(0xEE1E293B) : const Color(0x990F172A),
          borderRadius: BorderRadius.circular(14),
          border: Border.all(
            color: isSelected ? AppTheme.primaryCyan : Colors.white.withAlpha(35),
            width: isSelected ? 2.0 : 1.0,
          ),
          boxShadow: isSelected
              ? [
                  BoxShadow(
                    color: AppTheme.primaryCyan.withAlpha(80),
                    blurRadius: 8,
                    spreadRadius: 1,
                  )
                ]
              : null,
        ),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          mainAxisSize: MainAxisSize.min,
          children: [
            // Vector Silhouette Thumbnail Preview
            Container(
              width: 32,
              height: 32,
              padding: const EdgeInsets.all(2),
              decoration: BoxDecoration(
                color: Colors.black.withAlpha(120),
                borderRadius: BorderRadius.circular(6),
              ),
              child: CustomPaint(
                painter: MiniSilhouettePainter(
                  pose: pose,
                  isSelected: isSelected,
                  accentColor: accentColor,
                ),
              ),
            ),
            const SizedBox(height: 3),

            // Pose Title
            Text(
              pose.name,
              style: TextStyle(
                color: isSelected ? Colors.white : AppTheme.textPrimary,
                fontSize: 9.5,
                fontWeight: isSelected ? FontWeight.bold : FontWeight.w500,
              ),
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              textAlign: TextAlign.center,
            ),
            const SizedBox(height: 2),

            // Context Match Score Pill Badge
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 4, vertical: 1),
              decoration: BoxDecoration(
                color: scoreBadgeColor.withAlpha(isSelected ? 60 : 30),
                borderRadius: BorderRadius.circular(6),
              ),
              child: Text(
                '✨ $matchScore%',
                style: TextStyle(
                  color: scoreBadgeColor,
                  fontSize: 8.0,
                  fontWeight: FontWeight.bold,
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}
