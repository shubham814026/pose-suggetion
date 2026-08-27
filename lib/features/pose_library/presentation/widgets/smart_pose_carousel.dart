import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../../../../core/theme/app_theme.dart';
import '../../data/models/target_pose.dart';
import '../../services/pose_library_service.dart';
import '../../../pose_recommendation/services/context_frame_scheduler.dart';
import '../../../pose_recommendation/services/pose_recommendation_service.dart';
import 'mini_silhouette_painter.dart';
import 'pose_thumbnail_card.dart';

/// Interactive horizontal recommendation carousel tray (Huawei AI Camera style).
/// Displays top 3–5 dynamically recommended poses based on live background & people count,
/// plus the on-demand AI Neural Pose Generator.
class SmartPoseCarousel extends StatefulWidget {
  final List<double>? currentSceneVector;

  const SmartPoseCarousel({
    super.key,
    this.currentSceneVector,
  });

  @override
  State<SmartPoseCarousel> createState() => _SmartPoseCarouselState();
}

class _SmartPoseCarouselState extends State<SmartPoseCarousel> {
  final ScrollController _scrollController = ScrollController();

  @override
  void dispose() {
    _scrollController.dispose();
    super.dispose();
  }

  void _scrollToIndex(int index, int totalCount) {
    if (!_scrollController.hasClients || totalCount == 0) return;
    const double itemWidth = 90.0;
    final double targetOffset = (index * itemWidth) - (MediaQuery.of(context).size.width / 2) + (itemWidth / 2);
    final double clampedOffset = targetOffset.clamp(
      0.0,
      _scrollController.position.maxScrollExtent,
    );

    _scrollController.animateTo(
      clampedOffset,
      duration: const Duration(milliseconds: 250),
      curve: Curves.easeOutCubic,
    );
  }

  /// Triggers real-time on-device dynamic pose generation via ContextPoseNet
  void _generateAndApplyAIPose(
    BuildContext context,
    PoseLibraryService poseLibrary,
    PoseRecommendationService recommender,
    ContextFrameScheduler? scheduler,
  ) {
    final contextVector = scheduler?.currentContextVector ??
        recommender.buildContextVector(
          sceneVector: widget.currentSceneVector ?? List.filled(64, 0.15),
          propIndex: scheduler?.detectedPropIndex ?? 0,
          peopleCount: scheduler?.detectedPeopleCount ?? 1,
          isFrontCamera: scheduler?.isFrontCamera ?? true,
        );

    final generatedPose = recommender.generatePoseFromContext(contextVector);
    if (generatedPose != null) {
      poseLibrary.setCustomActivePose(generatedPose);
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: const Text(
            '✨ Synthesized new AI Context Pose from live camera!',
            style: TextStyle(fontWeight: FontWeight.bold),
          ),
          duration: const Duration(milliseconds: 1000),
          backgroundColor: AppTheme.primaryCyan.withAlpha(220),
          behavior: SnackBarBehavior.floating,
        ),
      );
    }
  }

  /// Opens full-screen bottom sheet gallery to browse all library poses
  void _openFullPoseGallery(BuildContext context, PoseLibraryService poseLibrary) {
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: AppTheme.surfaceColor,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
      ),
      builder: (context) {
        return DraggableScrollableSheet(
          initialChildSize: 0.75,
          minChildSize: 0.4,
          maxChildSize: 0.95,
          expand: false,
          builder: (context, scrollController) {
            final poses = poseLibrary.filteredPoses;
            return Column(
              children: [
                const SizedBox(height: 12),
                Container(
                  width: 40,
                  height: 4,
                  decoration: BoxDecoration(
                    color: AppTheme.textSecondary.withAlpha(100),
                    borderRadius: BorderRadius.circular(2),
                  ),
                ),
                Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 12),
                  child: Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      Text(
                        'Pose Library (${poses.length} Poses)',
                        style: const TextStyle(
                          color: AppTheme.textPrimary,
                          fontSize: 18,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                      IconButton(
                        icon: const Icon(Icons.close, color: AppTheme.textSecondary),
                        onPressed: () => Navigator.of(context).pop(),
                      ),
                    ],
                  ),
                ),
                const Divider(height: 1, color: Colors.white12),
                Expanded(
                  child: GridView.builder(
                    controller: scrollController,
                    padding: const EdgeInsets.all(16),
                    gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
                      crossAxisCount: 3,
                      mainAxisSpacing: 12,
                      crossAxisSpacing: 12,
                      childAspectRatio: 0.85,
                    ),
                    itemCount: poses.length,
                    itemBuilder: (context, index) {
                      final pose = poses[index];
                      final isSelected = poseLibrary.activeTargetPose?.id == pose.id;

                      return GestureDetector(
                        onTap: () {
                          poseLibrary.selectPoseById(pose.id);
                          Navigator.of(context).pop();
                        },
                        child: Container(
                          decoration: BoxDecoration(
                            color: isSelected ? const Color(0xEE1E293B) : const Color(0x990F172A),
                            borderRadius: BorderRadius.circular(12),
                            border: Border.all(
                              color: isSelected ? AppTheme.primaryCyan : Colors.white24,
                              width: isSelected ? 2.0 : 1.0,
                            ),
                          ),
                          padding: const EdgeInsets.all(8),
                          child: Column(
                            mainAxisAlignment: MainAxisAlignment.center,
                            children: [
                              Expanded(
                                child: CustomPaint(
                                  size: const Size(double.infinity, double.infinity),
                                  painter: MiniSilhouettePainter(
                                    pose: pose,
                                    isSelected: isSelected,
                                    accentColor: AppTheme.primaryCyan,
                                  ),
                                ),
                              ),
                              const SizedBox(height: 4),
                              Text(
                                pose.name,
                                style: TextStyle(
                                  color: isSelected ? AppTheme.primaryCyan : Colors.white,
                                  fontSize: 10,
                                  fontWeight: isSelected ? FontWeight.bold : FontWeight.normal,
                                ),
                                maxLines: 1,
                                overflow: TextOverflow.ellipsis,
                                textAlign: TextAlign.center,
                              ),
                            ],
                          ),
                        ),
                      );
                    },
                  ),
                ),
              ],
            );
          },
        );
      },
    );
  }

  @override
  Widget build(BuildContext context) {
    final poseLibrary = Provider.of<PoseLibraryService>(context);
    final recommender = Provider.of<PoseRecommendationService>(context, listen: false);

    // Read live ContextFrameScheduler state
    ContextFrameScheduler? scheduler;
    try {
      scheduler = Provider.of<ContextFrameScheduler>(context);
    } catch (_) {
      scheduler = null;
    }

    final sceneVector = widget.currentSceneVector ??
        scheduler?.sceneVector ??
        List.generate(64, (i) => (i % 2 == 0) ? 0.15 : -0.10);

    final int peopleCount = scheduler?.detectedPeopleCount ?? 1;
    final bool isSitting = scheduler?.currentStance == StanceType.sitting;

    // Dynamically retrieve top 5 matching recommendations based on live background & people count
    final List<TargetPose> topRecommendations = recommender.getTopRecommendations(
      allPoses: poseLibrary.allPoses.isNotEmpty ? poseLibrary.allPoses : poseLibrary.filteredPoses,
      sceneVector: sceneVector,
      peopleCount: peopleCount,
      isSitting: isSitting,
      topK: 5,
    );

    return SizedBox(
      height: 84,
      child: Row(
        children: [
          Expanded(
            child: ListView.builder(
              controller: _scrollController,
              scrollDirection: Axis.horizontal,
              padding: const EdgeInsets.symmetric(horizontal: 8),
              // Card 0: AI Neural Generator, Cards 1..5: Top 5 Dynamic Recommendations
              itemCount: topRecommendations.length + 1,
              itemBuilder: (context, index) {
                if (index == 0) {
                  // Special Card: Real-Time AI Neural Generator
                  final isAIPoseActive = poseLibrary.activeTargetPose?.id.startsWith('pose_ai_generated') ?? false;
                  return GestureDetector(
                    onTap: () => _generateAndApplyAIPose(context, poseLibrary, recommender, scheduler),
                    child: Container(
                      width: 82,
                      margin: const EdgeInsets.only(right: 8),
                      padding: const EdgeInsets.symmetric(horizontal: 4, vertical: 4),
                      decoration: BoxDecoration(
                        gradient: LinearGradient(
                          begin: Alignment.topLeft,
                          end: Alignment.bottomRight,
                          colors: isAIPoseActive
                              ? [const Color(0xFF0284C7), const Color(0xFF0EA5E9)]
                              : [const Color(0xCC0F172A), const Color(0xCC1E293B)],
                        ),
                        borderRadius: BorderRadius.circular(14),
                        border: Border.all(
                          color: isAIPoseActive ? Colors.white : AppTheme.primaryCyan.withAlpha(180),
                          width: 2.0,
                        ),
                        boxShadow: [
                          BoxShadow(
                            color: AppTheme.primaryCyan.withAlpha(isAIPoseActive ? 120 : 40),
                            blurRadius: 8,
                            spreadRadius: 1,
                          ),
                        ],
                      ),
                      child: const Column(
                        mainAxisAlignment: MainAxisAlignment.center,
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          Icon(Icons.auto_awesome, color: Colors.white, size: 16),
                          SizedBox(height: 2),
                          Text(
                            'AI Neural',
                            style: TextStyle(
                              color: Colors.white,
                              fontSize: 9.0,
                              fontWeight: FontWeight.bold,
                            ),
                          ),
                          Text(
                            '✨ Generate',
                            style: TextStyle(
                              color: AppTheme.primaryCyan,
                              fontSize: 7.5,
                              fontWeight: FontWeight.bold,
                            ),
                          ),
                        ],
                      ),
                    ),
                  );
                }

                final TargetPose pose = topRecommendations[index - 1];
                final bool isSelected = poseLibrary.activeTargetPose?.id == pose.id;
                final int matchScore = recommender.getMatchPercentage(sceneVector, pose).toInt();

                return PoseThumbnailCard(
                  pose: pose,
                  isSelected: isSelected,
                  matchScore: matchScore,
                  onTap: () {
                    poseLibrary.setCustomActivePose(pose);
                    _scrollToIndex(index, topRecommendations.length + 1);
                  },
                );
              },
            ),
          ),

          // Gallery Grid View Trigger Button
          GestureDetector(
            onTap: () => _openFullPoseGallery(context, poseLibrary),
            child: Container(
              height: 72,
              width: 36,
              margin: const EdgeInsets.only(right: 8),
              decoration: BoxDecoration(
                color: Colors.black.withAlpha(180),
                borderRadius: BorderRadius.circular(12),
                border: Border.all(color: Colors.white24),
              ),
              child: const Column(
                mainAxisAlignment: MainAxisAlignment.center,
                mainAxisSize: MainAxisSize.min,
                children: [
                  Icon(Icons.grid_view_rounded, color: Colors.white, size: 16),
                  SizedBox(height: 2),
                  Text(
                    'All',
                    style: TextStyle(color: AppTheme.textSecondary, fontSize: 8.0),
                  ),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }
}
