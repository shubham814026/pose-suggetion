import 'dart:io';
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../../../../core/theme/app_theme.dart';
import '../../pose_library/data/models/target_pose.dart';
import '../../pose_library/presentation/widgets/mini_silhouette_painter.dart';
import '../../pose_library/services/pose_library_service.dart';
import '../../pose_recommendation/services/pose_recommendation_service.dart';
import '../models/photo_analysis_result.dart';

/// Screen displaying the multi-modal photo analysis breakdown and top 5 dynamic AI recommended poses.
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
    if (widget.analysis.recommendedPoses.isNotEmpty) {
      _selectedPose = widget.analysis.recommendedPoses.first;
    }
  }

  void _generateNovelAIPose(BuildContext context) {
    final recommender = Provider.of<PoseRecommendationService>(context, listen: false);
    final poseLibrary = Provider.of<PoseLibraryService>(context, listen: false);

    final novelPose = recommender.generatePoseFromContext(
      widget.analysis.contextVector,
      customName: '✨ AI Context Synthesis',
      customDesc: 'Novel neural-generated posture customized for this scene.',
    );

    if (novelPose != null) {
      setState(() {
        _selectedPose = novelPose;
      });
      poseLibrary.setCustomActivePose(novelPose);

      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: const Text(
            '✨ Synthesized new AI Context Pose for this photo!',
            style: TextStyle(fontWeight: FontWeight.bold),
          ),
          backgroundColor: AppTheme.primaryCyan.withAlpha(220),
          duration: const Duration(milliseconds: 1200),
          behavior: SnackBarBehavior.floating,
        ),
      );
    }
  }

  void _applyStencilAndReturnToCamera(BuildContext context) {
    final poseLibrary = Provider.of<PoseLibraryService>(context, listen: false);
    if (_selectedPose != null) {
      poseLibrary.setCustomActivePose(_selectedPose!);
    }
    Navigator.of(context).pop(true);
  }

  @override
  Widget build(BuildContext context) {
    final analysis = widget.analysis;
    final recommender = Provider.of<PoseRecommendationService>(context, listen: false);

    final String peopleBadgeText = analysis.peopleCount == 0
        ? '👤 0 People (Empty Scene)'
        : (analysis.peopleCount == 1 ? '👤 1 Person (Solo)' : '👥 ${analysis.peopleCount} People');

    return Scaffold(
      backgroundColor: const Color(0xFF090D16),
      appBar: AppBar(
        backgroundColor: Colors.transparent,
        elevation: 0,
        leading: IconButton(
          icon: const Icon(Icons.arrow_back_ios_new, color: Colors.white),
          onPressed: () => Navigator.of(context).pop(false),
        ),
        title: const Text(
          'Photo Scene Context',
          style: TextStyle(color: Colors.white, fontSize: 18, fontWeight: FontWeight.bold),
        ),
        centerTitle: true,
      ),
      body: SafeArea(
        child: Column(
          children: [
            // Upper Section: Snapshot Preview with Context Badges
            Expanded(
              flex: 4,
              child: Stack(
                fit: StackFit.expand,
                children: [
                  // Photo Image File
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

                  // Subtle gradient overlay for readability
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

                  // Floating Context Badges
                  Positioned(
                    bottom: 20,
                    left: 28,
                    right: 28,
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Wrap(
                          spacing: 8,
                          runSpacing: 6,
                          children: [
                            _buildContextBadge(
                              '${analysis.lightingEmoji} ${analysis.lightingName}',
                              const Color(0xFFF59E0B),
                            ),
                            _buildContextBadge(
                              '${analysis.sceneEmoji} ${analysis.sceneName}',
                              const Color(0xFF0EA5E9),
                            ),
                            _buildContextBadge(
                              peopleBadgeText,
                              analysis.peopleCount > 0 ? const Color(0xFF10B981) : const Color(0xFF94A3B8),
                            ),
                            _buildContextBadge(
                              '✨ ${analysis.occasionVibe}',
                              const Color(0xFFA855F7),
                            ),
                          ],
                        ),
                      ],
                    ),
                  ),
                ],
              ),
            ),

            // Lower Section: Top Recommendations & Action Deck
            Expanded(
              flex: 5,
              child: Container(
                width: double.infinity,
                decoration: const BoxDecoration(
                  color: Color(0xFF0F172A),
                  borderRadius: BorderRadius.vertical(top: Radius.circular(28)),
                  boxShadow: [
                    BoxShadow(
                      color: Colors.black45,
                      blurRadius: 16,
                      offset: Offset(0, -4),
                    ),
                  ],
                ),
                padding: const EdgeInsets.fromLTRB(16, 16, 16, 12),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    // Header Row with AI Neural Synthesizer trigger
                    Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        Text(
                          analysis.peopleCount == 0
                              ? 'Suggested Staging Poses (0 People)'
                              : 'AI Generated Poses (${analysis.peopleCount} Detected)',
                          style: const TextStyle(
                            color: Colors.white,
                            fontSize: 15,
                            fontWeight: FontWeight.bold,
                          ),
                        ),
                        InkWell(
                          onTap: () => _generateNovelAIPose(context),
                          borderRadius: BorderRadius.circular(16),
                          child: Container(
                            padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
                            decoration: BoxDecoration(
                              gradient: const LinearGradient(
                                colors: [Color(0xFF0284C7), Color(0xFF0EA5E9)],
                              ),
                              borderRadius: BorderRadius.circular(16),
                              boxShadow: [
                                BoxShadow(
                                  color: AppTheme.primaryCyan.withAlpha(80),
                                  blurRadius: 6,
                                ),
                              ],
                            ),
                            child: const Row(
                              mainAxisSize: MainAxisSize.min,
                              children: [
                                Icon(Icons.auto_awesome, color: Colors.white, size: 14),
                                SizedBox(width: 4),
                                Text(
                                  'AI Synthesize',
                                  style: TextStyle(
                                    color: Colors.white,
                                    fontSize: 11,
                                    fontWeight: FontWeight.bold,
                                  ),
                                ),
                              ],
                            ),
                          ),
                        ),
                      ],
                    ),

                    const SizedBox(height: 10),

                    // Top 5 Pose Selection Carousel
                    SizedBox(
                      height: 130,
                      child: ListView.builder(
                        scrollDirection: Axis.horizontal,
                        itemCount: analysis.recommendedPoses.length,
                        itemBuilder: (context, index) {
                          final pose = analysis.recommendedPoses[index];
                          final isSelected = _selectedPose?.id == pose.id;

                          final int matchScore = recommender.calculateDynamicMatchPercentage(
                            sceneVector: analysis.sceneVector,
                            pose: pose,
                            peopleCount: analysis.peopleCount,
                            detectedStance: analysis.stanceType,
                          ).round();

                          final String badgeLabel = analysis.peopleCount == 0
                              ? '$matchScore% Scene Fit'
                              : '$matchScore% Match';

                          return GestureDetector(
                            onTap: () {
                              setState(() {
                                _selectedPose = pose;
                              });
                            },
                            child: AnimatedContainer(
                              duration: const Duration(milliseconds: 200),
                              width: 105,
                              margin: const EdgeInsets.only(right: 10),
                              padding: const EdgeInsets.all(8),
                              decoration: BoxDecoration(
                                color: isSelected
                                    ? const Color(0xFF1E293B)
                                    : const Color(0xFF090D16).withAlpha(180),
                                borderRadius: BorderRadius.circular(16),
                                border: Border.all(
                                  color: isSelected
                                      ? AppTheme.primaryCyan
                                      : Colors.white12,
                                  width: isSelected ? 2.0 : 1.0,
                                ),
                                boxShadow: isSelected
                                    ? [
                                        BoxShadow(
                                          color: AppTheme.primaryCyan.withAlpha(90),
                                          blurRadius: 10,
                                        ),
                                      ]
                                    : [],
                              ),
                              child: Column(
                                mainAxisAlignment: MainAxisAlignment.center,
                                children: [
                                  // Silhouette Thumbnail Canvas
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

                                  // Match Badge
                                  Container(
                                    padding:
                                        const EdgeInsets.symmetric(horizontal: 5, vertical: 2),
                                    decoration: BoxDecoration(
                                      color: isSelected
                                          ? AppTheme.primaryCyan.withAlpha(220)
                                          : Colors.white12,
                                      borderRadius: BorderRadius.circular(6),
                                    ),
                                    child: Text(
                                      '✨ $badgeLabel',
                                      style: TextStyle(
                                        color: isSelected ? Colors.black : Colors.white70,
                                        fontSize: 8.5,
                                        fontWeight: FontWeight.bold,
                                      ),
                                    ),
                                  ),
                                  const SizedBox(height: 3),

                                  // Pose Name
                                  Text(
                                    pose.name,
                                    style: TextStyle(
                                      color: isSelected ? Colors.white : Colors.white70,
                                      fontSize: 10,
                                      fontWeight:
                                          isSelected ? FontWeight.bold : FontWeight.normal,
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

                    const SizedBox(height: 8),

                    // Selected Pose In-Situ Guidance Tags
                    if (_selectedPose != null && _selectedPose!.actionTags.isNotEmpty)
                      Expanded(
                        child: Container(
                          width: double.infinity,
                          padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                          decoration: BoxDecoration(
                            color: const Color(0xFF090D16).withAlpha(150),
                            borderRadius: BorderRadius.circular(12),
                            border: Border.all(color: Colors.white10),
                          ),
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            mainAxisAlignment: MainAxisAlignment.center,
                            children: [
                              const Text(
                                'Action Stencil Guidance:',
                                style: TextStyle(
                                  color: AppTheme.textSecondary,
                                  fontSize: 10,
                                  fontWeight: FontWeight.bold,
                                ),
                              ),
                              const SizedBox(height: 4),
                              Wrap(
                                spacing: 6,
                                runSpacing: 4,
                                children: _selectedPose!.actionTags.take(3).map((tag) {
                                  return Container(
                                    padding: const EdgeInsets.symmetric(
                                        horizontal: 8, vertical: 3),
                                    decoration: BoxDecoration(
                                      color: AppTheme.primaryCyan.withAlpha(35),
                                      borderRadius: BorderRadius.circular(8),
                                      border: Border.all(
                                        color: AppTheme.primaryCyan.withAlpha(120),
                                        width: 0.8,
                                      ),
                                    ),
                                    child: Text(
                                      '${tag.arrow} ${tag.label}',
                                      style: const TextStyle(
                                        color: AppTheme.primaryCyan,
                                        fontSize: 9.5,
                                        fontWeight: FontWeight.bold,
                                      ),
                                    ),
                                  );
                                }).toList(),
                              ),
                            ],
                          ),
                        ),
                      )
                    else
                      const Spacer(),

                    const SizedBox(height: 8),

                    // Floating Apply Stencil Button
                    SizedBox(
                      width: double.infinity,
                      height: 48,
                      child: ElevatedButton.icon(
                        onPressed: () => _applyStencilAndReturnToCamera(context),
                        icon: const Icon(Icons.camera_alt_rounded, color: Colors.black, size: 20),
                        label: Text(
                          _selectedPose != null
                              ? 'Apply Stencil: "${_selectedPose!.name}"'
                              : 'Apply Stencil & Shoot',
                          style: const TextStyle(
                            color: Colors.black,
                            fontSize: 14,
                            fontWeight: FontWeight.bold,
                          ),
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                        ),
                        style: ElevatedButton.styleFrom(
                          backgroundColor: AppTheme.primaryCyan,
                          shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(16),
                          ),
                          elevation: 6,
                        ),
                      ),
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
