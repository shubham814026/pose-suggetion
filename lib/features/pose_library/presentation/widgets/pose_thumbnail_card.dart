import 'package:flutter/material.dart';
import '../../../../core/theme/app_theme.dart';
import '../../data/models/target_pose.dart';
import 'pose_image_view.dart';

/// Interactive bottom carousel card for a single recommended target pose.
/// Displays the real reference photo from the 12,000 dataset, pose title, and dynamic match badge.
class PoseThumbnailCard extends StatelessWidget {
  final TargetPose pose;
  final bool isSelected;
  final int matchScore;
  final VoidCallback onTap;
  final VoidCallback? onInfoTap;

  const PoseThumbnailCard({
    super.key,
    required this.pose,
    required this.isSelected,
    required this.matchScore,
    required this.onTap,
    this.onInfoTap,
  });

  @override
  Widget build(BuildContext context) {
    final Color scoreBadgeColor = matchScore >= 80
        ? AppTheme.successGreen
        : (matchScore >= 50 ? AppTheme.primaryCyan : AppTheme.warningAmber);

    return GestureDetector(
      onTap: onTap,
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 200),
        curve: Curves.easeInOut,
        width: 104,
        margin: const EdgeInsets.only(right: 8),
        decoration: BoxDecoration(
          color: isSelected ? const Color(0xFF1E293B) : const Color(0xCC0F172A),
          borderRadius: BorderRadius.circular(14),
          border: Border.all(
            color: isSelected ? AppTheme.primaryCyan : Colors.white24,
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
        child: ClipRRect(
          borderRadius: BorderRadius.circular(13),
          child: Stack(
            fit: StackFit.expand,
            children: [
              // Real Reference Photo from 12,000 Dataset
              PoseImageView(
                pose: pose,
                fit: BoxFit.cover,
              ),

              // Gradient Overlay for Readability
              Container(
                decoration: const BoxDecoration(
                  gradient: LinearGradient(
                    begin: Alignment.topCenter,
                    end: Alignment.bottomCenter,
                    colors: [
                      Colors.transparent,
                      Colors.black45,
                      Colors.black87,
                    ],
                  ),
                ),
              ),

              // Match Score Badge (Top Left)
              Positioned(
                top: 5,
                left: 5,
                child: Container(
                  padding: const EdgeInsets.symmetric(horizontal: 5, vertical: 2),
                  decoration: BoxDecoration(
                    color: scoreBadgeColor.withAlpha(220),
                    borderRadius: BorderRadius.circular(6),
                    boxShadow: const [
                      BoxShadow(color: Colors.black45, blurRadius: 4),
                    ],
                  ),
                  child: Text(
                    '✨ $matchScore%',
                    style: const TextStyle(
                      color: Colors.white,
                      fontSize: 8.5,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                ),
              ),

              // Info Icon Button (Top Right)
              if (onInfoTap != null)
                Positioned(
                  top: 3,
                  right: 3,
                  child: GestureDetector(
                    onTap: onInfoTap,
                    child: Container(
                      padding: const EdgeInsets.all(3),
                      decoration: BoxDecoration(
                        color: Colors.black.withAlpha(160),
                        shape: BoxShape.circle,
                      ),
                      child: const Icon(Icons.info_outline, color: Colors.white, size: 14),
                    ),
                  ),
                ),

              // Pose Title & Category (Bottom)
              Positioned(
                bottom: 6,
                left: 6,
                right: 6,
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Text(
                      pose.name,
                      style: TextStyle(
                        color: isSelected ? AppTheme.primaryCyan : Colors.white,
                        fontSize: 9.5,
                        fontWeight: FontWeight.bold,
                      ),
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                    ),
                    Text(
                      pose.category,
                      style: const TextStyle(
                        color: AppTheme.textSecondary,
                        fontSize: 8.0,
                      ),
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                    ),
                  ],
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
