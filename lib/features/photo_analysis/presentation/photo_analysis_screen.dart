import 'dart:io';
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../../../../core/theme/app_theme.dart';
import '../../pose_library/data/models/target_pose.dart';
import '../../pose_library/presentation/widgets/pose_image_view.dart';
import '../../pose_library/services/pose_library_service.dart';
import '../../pose_recommendation/services/pose_recommendation_service.dart';
import '../models/photo_analysis_result.dart';

/// Screen displaying clicked photo analysis and exactly 3 suggested photos from the 12,000 dataset
/// with actionable coaching explaining why they will look better.
class PhotoAnalysisScreen extends StatefulWidget {
  final PhotoAnalysisResult analysis;

  const PhotoAnalysisScreen({
    super.key,
    required this.analysis,
  });

  @override
  State<PhotoAnalysisScreen> createState() => _PhotoAnalysisScreenState();
}

class _PhotoAnalysisScreenState extends State<PhotoAnalysisScreen> {
  TargetPose? _selectedPose;

  @override
  void initState() {
    super.initState();
    if (widget.analysis.peopleCount > 0 && widget.analysis.recommendedPoses.isNotEmpty) {
      _selectedPose = widget.analysis.recommendedPoses.first;
    }
  }

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    if (_selectedPose == null && widget.analysis.peopleCount > 0) {
      if (widget.analysis.recommendedPoses.isNotEmpty) {
        _selectedPose = widget.analysis.recommendedPoses.first;
      }
    }
  }

  String _deriveWhyLooksBetter(TargetPose pose) {
    final name = pose.name.toLowerCase();
    final cat = pose.category.toLowerCase();

    if (cat.contains('sitting') || name.contains('seat') || name.contains('bench')) {
      return 'Comfortable seated geometry with relaxed hands and angled shoulders eliminates stiffness and adds casual lifestyle depth.';
    } else if (cat.contains('beach') || cat.contains('coastal')) {
      return 'Open chest and relaxed stride capture natural outdoor lighting and wind with effortless movement.';
    } else if (cat.contains('fashion') || cat.contains('streetwear') || cat.contains('aesthetic')) {
      return 'Subtle 45° torso turn with weight shifted to the back leg creates flattering silhouette elongation and high-fashion attitude.';
    } else if (cat.contains('couple') || cat.contains('duo')) {
      return 'Complementary head tilts and staggered shoulder heights create an intimate, natural connection without feeling rigid.';
    } else if (cat.contains('group') || cat.contains('family')) {
      return 'Tiered multi-level spacing avoids flat lineup and creates a lively, cohesive composition.';
    } else if (cat.contains('gym') || cat.contains('fitness')) {
      return 'Clean athletic posture with defined limb alignment highlights strength and balance.';
    } else {
      return 'Enhanced spine alignment, relaxed natural hands, and purposeful chin angle bring confident, flattering composition.';
    }
  }

  void _useAsReferenceAndReturn(BuildContext context, TargetPose pose) {
    final poseLibrary = Provider.of<PoseLibraryService>(context, listen: false);
    poseLibrary.setCustomActivePose(pose);

    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(
          '✨ Reference set: "${pose.name}". Use the corner preview to pose!',
          style: const TextStyle(fontWeight: FontWeight.bold),
        ),
        backgroundColor: AppTheme.primaryCyan.withAlpha(230),
        duration: const Duration(milliseconds: 1400),
        behavior: SnackBarBehavior.floating,
      ),
    );

    Navigator.of(context).pop(true);
  }

  void _openFullPhotoModal(BuildContext context, TargetPose pose) {
    showDialog(
      context: context,
      builder: (context) {
        return Dialog(
          backgroundColor: Colors.transparent,
          insetPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 24),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              ClipRRect(
                borderRadius: BorderRadius.circular(20),
                child: SizedBox(
                  width: double.infinity,
                  height: MediaQuery.of(context).size.height * 0.65,
                  child: PoseImageView(
                    pose: pose,
                    fit: BoxFit.cover,
                  ),
                ),
              ),
              const SizedBox(height: 12),
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
                decoration: BoxDecoration(
                  color: const Color(0xFF0F172A),
                  borderRadius: BorderRadius.circular(16),
                  border: Border.all(color: Colors.white24),
                ),
                child: Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    Expanded(
                      child: Text(
                        pose.name,
                        style: const TextStyle(color: Colors.white, fontSize: 14, fontWeight: FontWeight.bold),
                        overflow: TextOverflow.ellipsis,
                      ),
                    ),
                    IconButton(
                      icon: const Icon(Icons.close, color: Colors.white),
                      onPressed: () => Navigator.of(context).pop(),
                    ),
                  ],
                ),
              ),
            ],
          ),
        );
      },
    );
  }

  @override
  Widget build(BuildContext context) {
    final analysis = widget.analysis;
    final recommender = Provider.of<PoseRecommendationService>(context, listen: false);

    final List<TargetPose> top3Photos = analysis.peopleCount > 0
        ? analysis.recommendedPoses.take(3).toList()
        : const [];

    final activePose = _selectedPose ?? (top3Photos.isNotEmpty ? top3Photos.first : null);

    final String peopleBadgeText = analysis.peopleCount == 0
        ? '👤 0 People (Empty Scene)'
        : (analysis.peopleCount == 1 ? '👤 1 Person (Solo)' : '👥 ${analysis.peopleCount} People');

    return Scaffold(
      backgroundColor: const Color(0xFF090D16),
      appBar: AppBar(
        backgroundColor: const Color(0xFF0F172A),
        elevation: 0,
        leading: IconButton(
          icon: const Icon(Icons.arrow_back_ios_new, color: Colors.white),
          onPressed: () => Navigator.of(context).pop(false),
        ),
        title: const Column(
          children: [
            Text(
              'AI Photo Suggestions',
              style: TextStyle(color: Colors.white, fontSize: 16, fontWeight: FontWeight.bold),
            ),
            Text(
              '3 Photos Suggested from 12,000 Dataset',
              style: TextStyle(color: AppTheme.primaryCyan, fontSize: 11),
            ),
          ],
        ),
        centerTitle: true,
      ),
      body: SafeArea(
        child: Column(
          children: [
            // Upper Section: User Clicked Photo with Scene Context Badges
            Expanded(
              flex: 4,
              child: Stack(
                fit: StackFit.expand,
                children: [
                  Padding(
                    padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
                    child: ClipRRect(
                      borderRadius: BorderRadius.circular(20),
                      child: Image.file(
                        File(analysis.imagePath),
                        fit: BoxFit.cover,
                        errorBuilder: (_, __, ___) => Container(
                          color: const Color(0xFF1E293B),
                          child: const Center(
                            child: Icon(Icons.broken_image, color: Colors.white54, size: 48),
                          ),
                        ),
                      ),
                    ),
                  ),

                  // Gradient overlay
                  Padding(
                    padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
                    child: Container(
                      decoration: BoxDecoration(
                        borderRadius: BorderRadius.circular(20),
                        gradient: const LinearGradient(
                          begin: Alignment.topCenter,
                          end: Alignment.bottomCenter,
                          colors: [
                            Colors.black38,
                            Colors.transparent,
                            Colors.black87,
                          ],
                        ),
                      ),
                    ),
                  ),

                  // "Your Clicked Photo" Pill Label (Top Left)
                  Positioned(
                    top: 18,
                    left: 26,
                    child: Container(
                      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                      decoration: BoxDecoration(
                        color: Colors.black.withAlpha(200),
                        borderRadius: BorderRadius.circular(12),
                        border: Border.all(color: Colors.white30),
                      ),
                      child: const Row(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          Icon(Icons.camera_alt, color: Colors.white, size: 12),
                          SizedBox(width: 4),
                          Text(
                            'Your Captured Photo',
                            style: TextStyle(color: Colors.white, fontSize: 11, fontWeight: FontWeight.bold),
                          ),
                        ],
                      ),
                    ),
                  ),

                  // Floating Context Badges (Bottom)
                  Positioned(
                    bottom: 18,
                    left: 26,
                    right: 26,
                    child: Wrap(
                      spacing: 8,
                      runSpacing: 6,
                      children: [
                        _buildContextBadge('${analysis.lightingEmoji} ${analysis.lightingName}', const Color(0xFFF59E0B)),
                        _buildContextBadge('${analysis.sceneEmoji} ${analysis.sceneName}', const Color(0xFF0EA5E9)),
                        _buildContextBadge(peopleBadgeText, analysis.peopleCount > 0 ? const Color(0xFF10B981) : const Color(0xFF94A3B8)),
                        _buildContextBadge('✨ ${analysis.occasionVibe}', const Color(0xFFA855F7)),
                      ],
                    ),
                  ),
                ],
              ),
            ),

            // Lower Section: Top 3 Suggested Photos or Zero-Person Notice
            Expanded(
              flex: 5,
              child: Container(
                width: double.infinity,
                decoration: const BoxDecoration(
                  color: Color(0xFF0F172A),
                  borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
                  boxShadow: [
                    BoxShadow(color: Colors.black54, blurRadius: 16, offset: Offset(0, -4)),
                  ],
                ),
                padding: const EdgeInsets.fromLTRB(16, 14, 16, 12),
                child: analysis.peopleCount == 0
                    ? Center(
                        child: Column(
                          mainAxisAlignment: MainAxisAlignment.center,
                          children: [
                            Container(
                              padding: const EdgeInsets.all(16),
                              decoration: BoxDecoration(
                                color: Colors.white.withAlpha(15),
                                shape: BoxShape.circle,
                              ),
                              child: const Icon(Icons.person_off_outlined, color: AppTheme.textSecondary, size: 40),
                            ),
                            const SizedBox(height: 14),
                            const Text(
                              'No Person Detected in Photo',
                              style: TextStyle(color: Colors.white, fontSize: 16, fontWeight: FontWeight.bold),
                            ),
                            const SizedBox(height: 8),
                            const Padding(
                              padding: EdgeInsets.symmetric(horizontal: 24),
                              child: Text(
                                'The on-device ML model requires at least 1 person in the photo to suggest flattering poses.\nFrame yourself or your group and tap Retake.',
                                textAlign: TextAlign.center,
                                style: TextStyle(color: AppTheme.textSecondary, fontSize: 12.5, height: 1.4),
                              ),
                            ),
                            const SizedBox(height: 22),
                            SizedBox(
                              width: 170,
                              height: 44,
                              child: ElevatedButton.icon(
                                onPressed: () => Navigator.of(context).pop(false),
                                icon: const Icon(Icons.refresh_rounded, color: Colors.black, size: 18),
                                label: const Text(
                                  'Retake Photo',
                                  style: TextStyle(color: Colors.black, fontSize: 13, fontWeight: FontWeight.bold),
                                ),
                                style: ElevatedButton.styleFrom(
                                  backgroundColor: AppTheme.primaryCyan,
                                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
                                  elevation: 4,
                                ),
                              ),
                            ),
                          ],
                        ),
                      )
                    : Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          // Header
                          Row(
                            mainAxisAlignment: MainAxisAlignment.spaceBetween,
                            children: [
                              Text(
                                '${analysis.peopleCount == 1 ? "Solo" : (analysis.peopleCount == 2 ? "Duo" : (analysis.peopleCount == 3 ? "Trio" : "${analysis.peopleCount}-Person Group"))} Suggestions (${top3Photos.length} Photos)',
                                style: const TextStyle(color: Colors.white, fontSize: 13, fontWeight: FontWeight.bold),
                              ),
                              if (analysis.predictedCategory != null)
                                Container(
                                  padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                                  decoration: BoxDecoration(
                                    color: AppTheme.primaryCyan.withAlpha(40),
                                    borderRadius: BorderRadius.circular(6),
                                    border: Border.all(color: AppTheme.primaryCyan.withAlpha(120), width: 0.8),
                                  ),
                                  child: Row(
                                    mainAxisSize: MainAxisSize.min,
                                    children: [
                                      const Icon(Icons.memory, color: AppTheme.primaryCyan, size: 11),
                                      const SizedBox(width: 4),
                                      Text(
                                        'ML: ${analysis.predictedCategory} (${((analysis.categoryProbability ?? 0.85) * 100).toInt()}%)',
                                        style: const TextStyle(color: AppTheme.primaryCyan, fontSize: 10, fontWeight: FontWeight.bold),
                                      ),
                                    ],
                                  ),
                                )
                              else
                                const Text(
                                  '12,000 Dataset Matches',
                                  style: TextStyle(color: AppTheme.primaryCyan, fontSize: 11, fontWeight: FontWeight.bold),
                                ),
                            ],
                          ),

                    const SizedBox(height: 8),

                    // Top 3 Suggested Photos Cards
                    SizedBox(
                      height: 124,
                      child: Row(
                        children: top3Photos.map((pose) {
                          final isSelected = activePose?.id == pose.id;
                          final int matchScore = recommender.calculateDynamicMatchPercentage(
                            sceneVector: analysis.sceneVector,
                            pose: pose,
                            peopleCount: analysis.peopleCount,
                            detectedStance: analysis.stanceType,
                          ).round();

                          return Expanded(
                            child: GestureDetector(
                              onTap: () {
                                setState(() {
                                  _selectedPose = pose;
                                });
                              },
                              child: Container(
                                margin: const EdgeInsets.symmetric(horizontal: 4),
                                decoration: BoxDecoration(
                                  borderRadius: BorderRadius.circular(14),
                                  border: Border.all(
                                    color: isSelected ? AppTheme.primaryCyan : Colors.white24,
                                    width: isSelected ? 2.5 : 1.0,
                                  ),
                                  boxShadow: isSelected
                                      ? [
                                          BoxShadow(
                                            color: AppTheme.primaryCyan.withAlpha(90),
                                            blurRadius: 10,
                                            spreadRadius: 1,
                                          ),
                                        ]
                                      : null,
                                ),
                                child: ClipRRect(
                                  borderRadius: BorderRadius.circular(12),
                                  child: Stack(
                                    fit: StackFit.expand,
                                    children: [
                                      // Real Photo Image
                                      PoseImageView(
                                        pose: pose,
                                        fit: BoxFit.cover,
                                      ),

                                      // Subtle Bottom Gradient
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

                                      // Match Badge
                                      Positioned(
                                        top: 5,
                                        left: 5,
                                        child: Container(
                                          padding: const EdgeInsets.symmetric(horizontal: 5, vertical: 2),
                                          decoration: BoxDecoration(
                                            color: isSelected ? AppTheme.primaryCyan : Colors.black87,
                                            borderRadius: BorderRadius.circular(6),
                                          ),
                                          child: Text(
                                            '✨ $matchScore%',
                                            style: TextStyle(
                                              color: isSelected ? Colors.black : Colors.white,
                                              fontSize: 8.5,
                                              fontWeight: FontWeight.bold,
                                            ),
                                          ),
                                        ),
                                      ),

                                      // Pose Name & Category (Bottom)
                                      Positioned(
                                        bottom: 5,
                                        left: 5,
                                        right: 5,
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
                            ),
                          );
                        }).toList(),
                      ),
                    ),

                    const SizedBox(height: 8),

                    // "Why this photo will look better" coaching advice
                    if (activePose != null)
                      Expanded(
                        child: Container(
                          width: double.infinity,
                          padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                          decoration: BoxDecoration(
                            color: const Color(0xFF1E293B),
                            borderRadius: BorderRadius.circular(14),
                            border: Border.all(color: Colors.white12),
                          ),
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Row(
                                children: [
                                  const Icon(Icons.lightbulb_outline, color: AppTheme.primaryCyan, size: 15),
                                  const SizedBox(width: 6),
                                  Expanded(
                                    child: Text(
                                      'Why "${activePose.name}" will look better:',
                                      style: const TextStyle(
                                        color: AppTheme.primaryCyan,
                                        fontSize: 11,
                                        fontWeight: FontWeight.bold,
                                      ),
                                      maxLines: 1,
                                      overflow: TextOverflow.ellipsis,
                                    ),
                                  ),
                                  InkWell(
                                    onTap: () => _openFullPhotoModal(context, activePose),
                                    child: const Text(
                                      'View Photo ↗',
                                      style: TextStyle(color: Colors.white70, fontSize: 10, decoration: TextDecoration.underline),
                                    ),
                                  ),
                                ],
                              ),
                              const SizedBox(height: 4),
                              Expanded(
                                child: SingleChildScrollView(
                                  child: Text(
                                    _deriveWhyLooksBetter(activePose),
                                    style: const TextStyle(
                                      color: Colors.white70,
                                      fontSize: 11.5,
                                      height: 1.35,
                                    ),
                                  ),
                                ),
                              ),
                              if (activePose.actionTags.isNotEmpty) ...[
                                const SizedBox(height: 4),
                                Wrap(
                                  spacing: 6,
                                  runSpacing: 4,
                                  children: activePose.actionTags.take(3).map((tag) {
                                    return Container(
                                      padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                                      decoration: BoxDecoration(
                                        color: AppTheme.primaryCyan.withAlpha(30),
                                        borderRadius: BorderRadius.circular(6),
                                        border: Border.all(color: AppTheme.primaryCyan.withAlpha(100), width: 0.8),
                                      ),
                                      child: Text(
                                        '${tag.arrow} ${tag.label}',
                                        style: const TextStyle(color: AppTheme.primaryCyan, fontSize: 9.5, fontWeight: FontWeight.bold),
                                      ),
                                    );
                                  }).toList(),
                                ),
                              ],
                            ],
                          ),
                        ),
                      )
                    else
                      const Spacer(),

                    const SizedBox(height: 8),

                    // Action Buttons Row
                    Row(
                      children: [
                        // Retake / Back to Camera
                        Expanded(
                          flex: 1,
                          child: SizedBox(
                            height: 44,
                            child: OutlinedButton(
                              onPressed: () => Navigator.of(context).pop(false),
                              style: OutlinedButton.styleFrom(
                                side: const BorderSide(color: Colors.white24),
                                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
                              ),
                              child: const Text(
                                'Retake',
                                style: TextStyle(color: Colors.white, fontSize: 13, fontWeight: FontWeight.bold),
                              ),
                            ),
                          ),
                        ),
                        const SizedBox(width: 10),
                        // Use as Reference Guide
                        Expanded(
                          flex: 2,
                          child: SizedBox(
                            height: 44,
                            child: ElevatedButton.icon(
                              onPressed: activePose != null
                                  ? () => _useAsReferenceAndReturn(context, activePose)
                                  : null,
                              icon: const Icon(Icons.photo_library_outlined, color: Colors.black, size: 18),
                              label: const Text(
                                'Use as Reference Guide',
                                style: TextStyle(color: Colors.black, fontSize: 13, fontWeight: FontWeight.bold),
                              ),
                              style: ElevatedButton.styleFrom(
                                backgroundColor: AppTheme.primaryCyan,
                                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
                                elevation: 4,
                              ),
                            ),
                          ),
                        ),
                      ],
                    ),
                  ],
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildContextBadge(String text, Color color) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
      decoration: BoxDecoration(
        color: Colors.black.withAlpha(200),
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: color.withAlpha(180), width: 1.0),
        boxShadow: [
          BoxShadow(
            color: color.withAlpha(40),
            blurRadius: 6,
          ),
        ],
      ),
      child: Text(
        text,
        style: TextStyle(
          color: color,
          fontSize: 11,
          fontWeight: FontWeight.bold,
        ),
      ),
    );
  }
}
