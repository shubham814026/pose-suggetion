import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../../../../core/theme/app_theme.dart';
import '../../pose_recommendation/services/context_frame_scheduler.dart';
import '../../pose_recommendation/services/pose_recommendation_service.dart';
import '../data/models/target_pose.dart';
import '../services/pose_library_service.dart';
import 'widgets/pose_image_view.dart';

/// Full-screen Pose Library & Category Explorer.
/// Allows browsing, searching, and selecting reference guide photos from the 12,000 dataset.
class PoseLibraryScreen extends StatefulWidget {
  final ValueChanged<TargetPose>? onSelectPose;

  const PoseLibraryScreen({
    super.key,
    this.onSelectPose,
  });

  @override
  State<PoseLibraryScreen> createState() => _PoseLibraryScreenState();
}

class _PoseLibraryScreenState extends State<PoseLibraryScreen> {
  final TextEditingController _searchController = TextEditingController();
  String _searchQuery = '';

  @override
  void dispose() {
    _searchController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final poseLibrary = Provider.of<PoseLibraryService>(context);
    final recommender = Provider.of<PoseRecommendationService>(context, listen: false);

    ContextFrameScheduler? scheduler;
    try {
      scheduler = Provider.of<ContextFrameScheduler>(context);
    } catch (_) {
      scheduler = null;
    }

    final sceneVector = scheduler?.sceneVector ?? List.filled(64, 0.0);
    final int peopleCount = scheduler?.detectedPeopleCount ?? 1;
    final bool isSitting = scheduler?.currentStance == StanceType.sitting;

    // Filter poses by category and search query
    List<TargetPose> displayedPoses = poseLibrary.filteredPoses;
    if (_searchQuery.isNotEmpty) {
      displayedPoses = displayedPoses.where((pose) {
        return pose.name.toLowerCase().contains(_searchQuery.toLowerCase()) ||
            pose.category.toLowerCase().contains(_searchQuery.toLowerCase()) ||
            pose.description.toLowerCase().contains(_searchQuery.toLowerCase());
      }).toList();
    }

    // Top recommended poses
    final topRecs = recommender.getTopRecommendations(
      allPoses: poseLibrary.allPoses.isNotEmpty ? poseLibrary.allPoses : poseLibrary.filteredPoses,
      sceneVector: sceneVector,
      peopleCount: peopleCount,
      isSitting: isSitting,
      topK: 3,
    );

    final categories = poseLibrary.availableCategories;

    return Scaffold(
      backgroundColor: const Color(0xFF090D16),
      appBar: AppBar(
        backgroundColor: const Color(0xFF0F172A),
        elevation: 0,
        title: const Column(
          children: [
            Text(
              'Reference Photo Library',
              style: TextStyle(color: Colors.white, fontSize: 16, fontWeight: FontWeight.bold),
            ),
            Text(
              '12,000 Verified Photography Poses',
              style: TextStyle(color: AppTheme.primaryCyan, fontSize: 11),
            ),
          ],
        ),
        centerTitle: true,
      ),
      body: SafeArea(
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // Search Input Field
            Padding(
              padding: const EdgeInsets.fromLTRB(16, 12, 16, 8),
              child: Container(
                decoration: BoxDecoration(
                  color: const Color(0xFF1E293B),
                  borderRadius: BorderRadius.circular(16),
                  border: Border.all(color: Colors.white12),
                ),
                child: TextField(
                  controller: _searchController,
                  onChanged: (val) {
                    setState(() {
                      _searchQuery = val.trim();
                    });
                  },
                  style: const TextStyle(color: Colors.white, fontSize: 14),
                  decoration: InputDecoration(
                    hintText: 'Search 12,000+ reference photos, styles...',
                    hintStyle: const TextStyle(color: AppTheme.textSecondary, fontSize: 13),
                    prefixIcon: const Icon(Icons.search, color: AppTheme.primaryCyan, size: 20),
                    suffixIcon: _searchQuery.isNotEmpty
                        ? IconButton(
                            icon: const Icon(Icons.clear, color: Colors.white54, size: 18),
                            onPressed: () {
                              _searchController.clear();
                              setState(() {
                                _searchQuery = '';
                              });
                            },
                          )
                        : null,
                    border: InputBorder.none,
                    contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
                  ),
                ),
              ),
            ),

            // Horizontal Category Selector Chips
            SizedBox(
              height: 44,
              child: ListView.builder(
                scrollDirection: Axis.horizontal,
                padding: const EdgeInsets.symmetric(horizontal: 16),
                itemCount: categories.length,
                itemBuilder: (context, index) {
                  final cat = categories[index];
                  final isSelected = poseLibrary.selectedCategory.toLowerCase() == cat.toLowerCase();

                  return Padding(
                    padding: const EdgeInsets.only(right: 8),
                    child: FilterChip(
                      selected: isSelected,
                      label: Text(cat),
                      labelStyle: TextStyle(
                        color: isSelected ? Colors.black : Colors.white,
                        fontSize: 12,
                        fontWeight: isSelected ? FontWeight.bold : FontWeight.normal,
                      ),
                      selectedColor: AppTheme.primaryCyan,
                      backgroundColor: const Color(0xFF1E293B),
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(20),
                        side: BorderSide(color: isSelected ? AppTheme.primaryCyan : Colors.white12),
                      ),
                      onSelected: (_) {
                        poseLibrary.setCategory(cat);
                      },
                    ),
                  );
                },
              ),
            ),

            const SizedBox(height: 8),

            // AI Recommendations Section (shown when category is 'All' and not searching)
            if (poseLibrary.selectedCategory == 'All' && _searchQuery.isEmpty && topRecs.isNotEmpty) ...[
              Padding(
                padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 4),
                child: Row(
                  children: [
                    const Icon(Icons.auto_awesome, color: AppTheme.primaryCyan, size: 16),
                    const SizedBox(width: 6),
                    const Text(
                      'AI Scene Recommendations',
                      style: TextStyle(
                        color: Colors.white,
                        fontSize: 13,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                    const Spacer(),
                    Text(
                      '${topRecs.length} Suggested',
                      style: const TextStyle(color: AppTheme.primaryCyan, fontSize: 11),
                    ),
                  ],
                ),
              ),
              SizedBox(
                height: 116,
                child: ListView.builder(
                  scrollDirection: Axis.horizontal,
                  padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 4),
                  itemCount: topRecs.length,
                  itemBuilder: (context, index) {
                    final pose = topRecs[index];
                    final isSelected = poseLibrary.activeTargetPose?.id == pose.id;
                    final int matchScore = recommender.getMatchPercentage(sceneVector, pose).toInt();

                    return GestureDetector(
                      onTap: () => _selectAndApplyPose(context, pose, poseLibrary),
                      child: Container(
                        width: 96,
                        margin: const EdgeInsets.only(right: 10),
                        decoration: BoxDecoration(
                          color: isSelected ? const Color(0xFF1E293B) : const Color(0xFF0F172A),
                          borderRadius: BorderRadius.circular(14),
                          border: Border.all(
                            color: isSelected ? AppTheme.primaryCyan : Colors.white24,
                            width: isSelected ? 2.0 : 1.0,
                          ),
                          boxShadow: isSelected
                              ? [
                                  BoxShadow(
                                    color: AppTheme.primaryCyan.withAlpha(90),
                                    blurRadius: 8,
                                  ),
                                ]
                              : null,
                        ),
                        child: ClipRRect(
                          borderRadius: BorderRadius.circular(13),
                          child: Stack(
                            fit: StackFit.expand,
                            children: [
                              PoseImageView(pose: pose, fit: BoxFit.cover),
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
                                top: 4,
                                left: 4,
                                child: Container(
                                  padding: const EdgeInsets.symmetric(horizontal: 4, vertical: 2),
                                  decoration: BoxDecoration(
                                    color: AppTheme.primaryCyan,
                                    borderRadius: BorderRadius.circular(4),
                                  ),
                                  child: Text(
                                    '✨ $matchScore%',
                                    style: const TextStyle(
                                      color: Colors.black,
                                      fontSize: 8.0,
                                      fontWeight: FontWeight.bold,
                                    ),
                                  ),
                                ),
                              ),
                              Positioned(
                                bottom: 4,
                                left: 4,
                                right: 4,
                                child: Column(
                                  crossAxisAlignment: CrossAxisAlignment.start,
                                  mainAxisSize: MainAxisSize.min,
                                  children: [
                                    Text(
                                      pose.name,
                                      style: TextStyle(
                                        color: isSelected ? AppTheme.primaryCyan : Colors.white,
                                        fontSize: 9.0,
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
              const SizedBox(height: 6),
            ],

            // Section Header
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 6),
              child: Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Text(
                    '${poseLibrary.selectedCategory} (${displayedPoses.length})',
                    style: const TextStyle(
                      color: AppTheme.textSecondary,
                      fontSize: 12,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                  if (poseLibrary.activeTargetPose != null)
                    InkWell(
                      onTap: () => poseLibrary.clearActivePose(),
                      child: const Text(
                        'Clear Reference Guide',
                        style: TextStyle(color: Color(0xFFEF4444), fontSize: 11, fontWeight: FontWeight.bold),
                      ),
                    ),
                ],
              ),
            ),

            // Poses Grid
            Expanded(
              child: poseLibrary.isLoading
                  ? const Center(
                      child: Column(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          CircularProgressIndicator(color: AppTheme.primaryCyan),
                          SizedBox(height: 12),
                          Text('Loading 12,000+ reference photos...', style: TextStyle(color: AppTheme.textSecondary)),
                        ],
                      ),
                    )
                  : displayedPoses.isEmpty
                      ? const Center(
                          child: Text(
                            'No photos match your criteria.',
                            style: TextStyle(color: AppTheme.textSecondary, fontSize: 14),
                          ),
                        )
                      : GridView.builder(
                          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
                          gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
                            crossAxisCount: 3,
                            mainAxisSpacing: 10,
                            crossAxisSpacing: 10,
                            childAspectRatio: 0.75,
                          ),
                          itemCount: displayedPoses.length,
                          itemBuilder: (context, index) {
                            final pose = displayedPoses[index];
                            final isSelected = poseLibrary.activeTargetPose?.id == pose.id;

                            return GestureDetector(
                              onTap: () => _selectAndApplyPose(context, pose, poseLibrary),
                              child: Container(
                                decoration: BoxDecoration(
                                  color: isSelected ? const Color(0xFF1E293B) : const Color(0xFF0F172A),
                                  borderRadius: BorderRadius.circular(12),
                                  border: Border.all(
                                    color: isSelected ? AppTheme.primaryCyan : Colors.white24,
                                    width: isSelected ? 2.0 : 1.0,
                                  ),
                                  boxShadow: isSelected
                                      ? [
                                          BoxShadow(
                                            color: AppTheme.primaryCyan.withAlpha(80),
                                            blurRadius: 8,
                                          ),
                                        ]
                                      : null,
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
                                                fontWeight: isSelected ? FontWeight.bold : FontWeight.w500,
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
        ),
      ),
    );
  }

  void _selectAndApplyPose(BuildContext context, TargetPose pose, PoseLibraryService poseLibrary) {
    poseLibrary.setCustomActivePose(pose);

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

    widget.onSelectPose?.call(pose);
  }
}

