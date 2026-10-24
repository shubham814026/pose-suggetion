import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../../../../core/theme/app_theme.dart';
import '../../data/models/target_pose.dart';
import '../../services/pose_library_service.dart';
import '../../../pose_recommendation/services/context_frame_scheduler.dart';
import '../../../pose_recommendation/services/pose_recommendation_service.dart';
import 'pose_image_view.dart';
import 'pose_thumbnail_card.dart';

/// Interactive horizontal recommendation carousel tray (Huawei AI Camera style).
/// Displays top 3–5 dynamically recommended poses based on live background & people count,
/// plus the on-demand AI Neural Pose Generator.
class SmartPoseCarousel extends StatefulWidget {
  final List<double>? currentSceneVector;
  final int? peopleCount;

  const SmartPoseCarousel({
    super.key,
    this.currentSceneVector,
    this.peopleCount,
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
                        'Browse Reference Photos (${poses.length} Photos)',
                        style: const TextStyle(
                          color: AppTheme.textPrimary,
                          fontSize: 16,
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
                      childAspectRatio: 0.75,
                    ),
                    itemCount: poses.length,
                    itemBuilder: (context, index) {
                      final pose = poses[index];
                      final isSelected = poseLibrary.activeTargetPose?.id == pose.id;

                      return GestureDetector(
                        onTap: () {
                          poseLibrary.setCustomActivePose(pose);
                          Navigator.of(context).pop();
                          ScaffoldMessenger.of(context).showSnackBar(
                            SnackBar(
                              content: Text(
                                '✨ Reference photo set: "${pose.name}"',
                                style: const TextStyle(fontWeight: FontWeight.bold),
                              ),
                              backgroundColor: AppTheme.primaryCyan.withAlpha(220),
                              duration: const Duration(milliseconds: 1000),
                              behavior: SnackBarBehavior.floating,
                            ),
                          );
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
                          child: ClipRRect(
                            borderRadius: BorderRadius.circular(11),
                            child: Stack(
                              fit: StackFit.expand,
                              children: [
                                PoseImageView(
                                  pose: pose,
                                  fit: BoxFit.cover,
                                ),
                                Container(
                                  decoration: const BoxDecoration(
                                    gradient: LinearGradient(
                                      begin: Alignment.topCenter,
                                      end: Alignment.bottomCenter,
                                      colors: [
                                        Colors.transparent,
                                        Colors.black54,
                                        Colors.black87,
                                      ],
                                    ),
                                  ),
                                ),
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
                                          fontWeight: isSelected ? FontWeight.bold : FontWeight.w600,
                                        ),
                                        maxLines: 1,
                                        overflow: TextOverflow.ellipsis,
                                      ),
                                      Text(
                                        pose.category,
                                        style: const TextStyle(
                                          color: AppTheme.textSecondary,
                                          fontSize: 7.5,
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
        List.filled(64, 0.0);

    final int peopleCount = widget.peopleCount ?? (scheduler != null ? scheduler.detectedPeopleCount : 1);
    final int propIndex = scheduler?.detectedPropIndex ?? 4;
    final StanceType stance = scheduler?.currentStance ?? StanceType.standing;

    final candidatePoses = poseLibrary.allPoses.isNotEmpty
        ? poseLibrary.allPoses
        : poseLibrary.filteredPoses;

    final contextVector = scheduler?.currentContextVector ??
        recommender.buildContextVector(
          sceneVector: sceneVector,
          propIndex: propIndex,
          peopleCount: peopleCount,
          isFrontCamera: scheduler?.isFrontCamera ?? true,
        );

    final neuralResult = recommender.runNeuralRecommendationInference(
      contextVector: contextVector,
      candidatePoses: candidatePoses,
      peopleCount: peopleCount,
      detectedStance: stance,
      topK: 3,
    );

    List<TargetPose> topRecommendations = List.from(neuralResult.recommendedPoses);

    // If candidate library poses are still loading and at least 1 person is detected, dynamically synthesize 3 neural recommendations
    if (peopleCount > 0 && topRecommendations.isEmpty) {
      topRecommendations = recommender.generateDynamicPoseRecommendations(
        baseContextVector: contextVector,
        sceneName: 'Studio & Photography',
        lightingName: 'Natural Daylight',
        peopleCount: peopleCount,
        count: 3,
      );
    }

    // Ensure the currently active pose is present in the carousel so user can see it selected
    final activePose = poseLibrary.activeTargetPose;
    if (activePose != null && !topRecommendations.any((p) => p.id == activePose.id)) {
      topRecommendations.insert(0, activePose);
    }

    // Auto-select top recommendation ONLY when at least 1 person is detected in view!
    if (peopleCount > 0 &&
        poseLibrary.activeTargetPose == null &&
        !poseLibrary.userExplicitlyCleared &&
        topRecommendations.isNotEmpty) {
      WidgetsBinding.instance.addPostFrameCallback((_) {
        if (mounted &&
            poseLibrary.activeTargetPose == null &&
            !poseLibrary.userExplicitlyCleared &&
            peopleCount > 0) {
          poseLibrary.autoSelectRecommendedPose(topRecommendations.first);
        }
      });
    }

    final String badgeLabel = peopleCount == 0
        ? 'No Person in View • Point camera at people'
        : (peopleCount == 1
            ? '1 Person (Solo) • ML: ${neuralResult.predictedCategory} (${(neuralResult.categoryProbability * 100).toInt()}%)'
            : (peopleCount == 2
                ? '2 People (Duo) • ML: ${neuralResult.predictedCategory} (${(neuralResult.categoryProbability * 100).toInt()}%)'
                : (peopleCount == 3
                    ? '3 People (Trio) • ML: ${neuralResult.predictedCategory} (${(neuralResult.categoryProbability * 100).toInt()}%)'
                    : '$peopleCount People (Group) • ML: ${neuralResult.predictedCategory} (${(neuralResult.categoryProbability * 100).toInt()}%)')));

    return Column(
      mainAxisSize: MainAxisSize.min,
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        // Live Neural Recommender & Person Detection Status Badge
        Padding(
          padding: const EdgeInsets.only(left: 12, bottom: 6),
          child: Container(
            padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 3.5),
            decoration: BoxDecoration(
              color: const Color(0xFF0F172A).withAlpha(230),
              borderRadius: BorderRadius.circular(12),
              border: Border.all(
                color: peopleCount > 0
                    ? AppTheme.primaryCyan.withAlpha(200)
                    : Colors.white24,
                width: 1.0,
              ),
              boxShadow: [
                BoxShadow(
                  color: Colors.black.withAlpha(140),
                  blurRadius: 4,
                  offset: const Offset(0, 2),
                ),
              ],
            ),
            child: Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                Icon(
                  peopleCount == 0
                      ? Icons.person_off_outlined
                      : (peopleCount == 1 ? Icons.person : Icons.group),
                  color: peopleCount > 0 ? AppTheme.primaryCyan : Colors.white70,
                  size: 13,
                ),
                const SizedBox(width: 5),
                Text(
                  badgeLabel,
                  style: TextStyle(
                    color: peopleCount > 0 ? Colors.white : Colors.white70,
                    fontSize: 10.5,
                    fontWeight: FontWeight.bold,
                  ),
                ),
              ],
            ),
          ),
        ),

        if (peopleCount == 0)
          Container(
            height: 72,
            margin: const EdgeInsets.symmetric(horizontal: 12),
            padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
            decoration: BoxDecoration(
              color: const Color(0xFF0F172A).withAlpha(210),
              borderRadius: BorderRadius.circular(16),
              border: Border.all(color: Colors.white12),
            ),
            child: Row(
              children: [
                Container(
                  padding: const EdgeInsets.all(8),
                  decoration: BoxDecoration(
                    color: Colors.white.withAlpha(15),
                    shape: BoxShape.circle,
                  ),
                  child: const Icon(Icons.person_search_outlined, color: AppTheme.primaryCyan, size: 20),
                ),
                const SizedBox(width: 12),
                const Expanded(
                  child: Column(
                    mainAxisAlignment: MainAxisAlignment.center,
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        'No Person Detected',
                        style: TextStyle(color: Colors.white, fontSize: 12.5, fontWeight: FontWeight.bold),
                      ),
                      SizedBox(height: 2),
                      Text(
                        'Point camera at 1, 2, 3, or a group of people for ML poses',
                        style: TextStyle(color: AppTheme.textSecondary, fontSize: 10),
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                      ),
                    ],
                  ),
                ),
                GestureDetector(
                  onTap: () => _openFullPoseGallery(context, poseLibrary),
                  child: Container(
                    padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
                    decoration: BoxDecoration(
                      color: AppTheme.primaryCyan.withAlpha(35),
                      borderRadius: BorderRadius.circular(10),
                      border: Border.all(color: AppTheme.primaryCyan.withAlpha(140)),
                    ),
                    child: const Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Icon(Icons.photo_library_outlined, color: AppTheme.primaryCyan, size: 13),
                        SizedBox(width: 4),
                        Text(
                          '12k Poses',
                          style: TextStyle(color: AppTheme.primaryCyan, fontSize: 10.5, fontWeight: FontWeight.bold),
                        ),
                      ],
                    ),
                  ),
                ),
              ],
            ),
          )
        else
          SizedBox(
            height: 112,
            child: Row(
              children: [
                Expanded(
                  child: ListView.builder(
                    controller: _scrollController,
                    scrollDirection: Axis.horizontal,
                    padding: const EdgeInsets.symmetric(horizontal: 8),
                    itemCount: topRecommendations.length,
                    itemBuilder: (context, index) {
                      final TargetPose pose = topRecommendations[index];
                      final bool isSelected = poseLibrary.activeTargetPose?.id == pose.id;
                      final int matchScore = recommender.calculateDynamicMatchPercentage(
                        sceneVector: sceneVector,
                        pose: pose,
                        peopleCount: peopleCount,
                        detectedStance: stance,
                      ).round();

                      return PoseThumbnailCard(
                        pose: pose,
                        isSelected: isSelected,
                        matchScore: matchScore,
                        onTap: () {
                          poseLibrary.setCustomActivePose(pose);
                          _scrollToIndex(index, topRecommendations.length);
                        },
                      );
                    },
                  ),
                ),

                // Gallery Grid View Trigger Button
                GestureDetector(
                  onTap: () => _openFullPoseGallery(context, poseLibrary),
                  child: Container(
                    height: 104,
                    width: 40,
                    margin: const EdgeInsets.only(right: 8),
                    decoration: BoxDecoration(
                      color: Colors.black.withAlpha(200),
                      borderRadius: BorderRadius.circular(12),
                      border: Border.all(color: Colors.white24),
                    ),
                    child: const Column(
                      mainAxisAlignment: MainAxisAlignment.center,
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Icon(Icons.photo_library_outlined, color: AppTheme.primaryCyan, size: 18),
                        SizedBox(height: 4),
                        Text(
                          '12k',
                          style: TextStyle(color: Colors.white, fontSize: 9.0, fontWeight: FontWeight.bold),
                        ),
                        Text(
                          'Poses',
                          style: TextStyle(color: AppTheme.textSecondary, fontSize: 8.0),
                        ),
                      ],
                    ),
                  ),
                ),
              ],
            ),
          ),
      ],
    );
  }
}
