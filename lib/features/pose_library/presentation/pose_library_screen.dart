import 'package:flutter/material.dart';
import '../../../core/theme/app_theme.dart';
import '../../pose_recommendation/services/pose_recommendation_service.dart';
import '../models/target_pose.dart';
import '../services/pose_library_service.dart';

class PoseLibraryScreen extends StatefulWidget {
  final TargetPose? selectedPose;
  final ValueChanged<TargetPose>? onSelectPose;
  final List<double>? liveFrameEmbedding;

  const PoseLibraryScreen({
    super.key,
    this.selectedPose,
    this.onSelectPose,
    this.liveFrameEmbedding,
  });

  @override
  State<PoseLibraryScreen> createState() => _PoseLibraryScreenState();
}

class _PoseLibraryScreenState extends State<PoseLibraryScreen> {
  final PoseLibraryService _poseLibraryService = PoseLibraryService();
  final PoseRecommendationService _recommendationService = PoseRecommendationService();
  
  List<TargetPose> _targetPoses = [];
  List<RankedPoseMatch> _rankedMatches = [];
  bool _isLoading = true;
  String? _selectedCategory;

  @override
  void initState() {
    super.initState();
    _loadData();
  }

  Future<void> _loadData() async {
    final poses = await _poseLibraryService.loadTargetPoses();
    await _recommendationService.loadReferenceEmbeddings();

    if (mounted) {
      setState(() {
        _targetPoses = poses;
        _updateRankings();
        _isLoading = false;
      });
    }
  }

  void _updateRankings() {
    if (_targetPoses.isEmpty) return;
    
    final dummyLiveEmbedding = widget.liveFrameEmbedding ?? [
      0.12, -0.04, 0.08, 0.14, -0.09, 0.01, -0.11, 0.07,
      0.03, 0.18, -0.15, 0.02, 0.09, -0.06, 0.11, -0.08,
      0.04, -0.13, 0.06, 0.10, -0.07, 0.03, -0.09, 0.08,
      0.01, 0.14, -0.12, 0.04, 0.07, -0.05, 0.13, -0.06,
      0.08, -0.02, 0.11, 0.09, -0.10, 0.04, -0.08, 0.06,
      0.02, 0.16, -0.14, 0.01, 0.08, -0.07, 0.10, -0.09,
      0.05, -0.11, 0.05, 0.12, -0.06, 0.02, -0.10, 0.07,
      0.01, 0.13, -0.11, 0.03, 0.06, -0.04, 0.11, -0.05
    ];

    _rankedMatches = _recommendationService.rankPoses(dummyLiveEmbedding, _targetPoses);
  }

  @override
  Widget build(BuildContext context) {
    final categories = ['All', ...{..._targetPoses.map((p) => p.category)}];
    
    final displayMatches = _rankedMatches.where((match) {
      if (_selectedCategory == null || _selectedCategory == 'All') return true;
      return match.pose.category == _selectedCategory;
    }).toList();

    return Scaffold(
      backgroundColor: AppTheme.darkBackground,
      appBar: AppBar(
        title: const Text('Target Pose Library'),
      ),
      body: SafeArea(
        child: _isLoading
            ? const Center(child: CircularProgressIndicator(color: AppTheme.primaryCyan))
            : Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  // Category Filter Chips
                  SingleChildScrollView(
                    scrollDirection: Axis.horizontal,
                    padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
                    child: Row(
                      children: categories.map((cat) {
                        final isSelected = (_selectedCategory ?? 'All') == cat;
                        return Padding(
                          padding: const EdgeInsets.only(right: 8.0),
                          child: FilterChip(
                            selected: isSelected,
                            label: Text(cat),
                            labelStyle: TextStyle(
                              color: isSelected ? Colors.black : AppTheme.textPrimary,
                              fontWeight: isSelected ? FontWeight.bold : FontWeight.normal,
                              fontSize: 12,
                            ),
                            selectedColor: AppTheme.primaryCyan,
                            backgroundColor: AppTheme.surfaceColor,
                            onSelected: (_) {
                              setState(() {
                                _selectedCategory = cat;
                              });
                            },
                          ),
                        );
                      }).toList(),
                    ),
                  ),

                  const Padding(
                    padding: EdgeInsets.symmetric(horizontal: 16.0, vertical: 4),
                    child: Row(
                      children: [
                        Icon(Icons.auto_awesome, color: AppTheme.primaryCyan, size: 16),
                        SizedBox(width: 6),
                        Text(
                          'AI Scene-Ranked Reference Poses (Cosine Match):',
                          style: TextStyle(
                            color: AppTheme.textSecondary,
                            fontSize: 13,
                            fontWeight: FontWeight.w600,
                          ),
                        ),
                      ],
                    ),
                  ),

                  const SizedBox(height: 8),

                  // Ranked ListView (Item 12)
                  Expanded(
                    child: ListView.separated(
                      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
                      itemCount: displayMatches.length,
                      separatorBuilder: (context, index) => const SizedBox(height: 12),
                      itemBuilder: (context, index) {
                        final match = displayMatches[index];
                        final pose = match.pose;
                        final isSelected = widget.selectedPose?.id == pose.id;
                        final isTopRecommendation = index == 0 && (_selectedCategory ?? 'All') == 'All';
                        final matchPercentage = (match.similarityScore * 100).toInt();

                        return Container(
                          decoration: BoxDecoration(
                            color: AppTheme.surfaceColor,
                            borderRadius: BorderRadius.circular(16),
                            border: Border.all(
                              color: isSelected
                                  ? AppTheme.primaryCyan
                                  : isTopRecommendation
                                      ? AppTheme.accentViolet
                                      : Colors.transparent,
                              width: 2,
                            ),
                            boxShadow: isSelected || isTopRecommendation
                                ? [
                                    BoxShadow(
                                      color: (isSelected ? AppTheme.primaryCyan : AppTheme.accentViolet).withOpacity(0.3),
                                      blurRadius: 8,
                                      offset: const Offset(0, 2),
                                    ),
                                  ]
                                : [],
                          ),
                          child: ListTile(
                            contentPadding: const EdgeInsets.all(12),
                            leading: Container(
                              width: 48,
                              height: 48,
                              decoration: BoxDecoration(
                                color: isSelected
                                    ? AppTheme.primaryCyan.withOpacity(0.2)
                                    : isTopRecommendation
                                        ? AppTheme.accentViolet.withOpacity(0.2)
                                        : AppTheme.cardColor,
                                borderRadius: BorderRadius.circular(12),
                              ),
                              child: Center(
                                child: Icon(
                                  _getCategoryIcon(pose.category),
                                  color: isSelected
                                      ? AppTheme.primaryCyan
                                      : isTopRecommendation
                                          ? AppTheme.accentViolet
                                          : AppTheme.textSecondary,
                                ),
                              ),
                            ),
                            title: Row(
                              children: [
                                Expanded(
                                  child: Text(
                                    pose.name,
                                    style: const TextStyle(
                                      color: AppTheme.textPrimary,
                                      fontSize: 15,
                                      fontWeight: FontWeight.bold,
                                    ),
                                  ),
                                ),
                                Container(
                                  padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                                  decoration: BoxDecoration(
                                    color: isTopRecommendation
                                        ? AppTheme.accentViolet
                                        : AppTheme.cardColor,
                                    borderRadius: BorderRadius.circular(10),
                                  ),
                                  child: Text(
                                    '$matchPercentage% Match',
                                    style: TextStyle(
                                      color: isTopRecommendation ? Colors.white : AppTheme.primaryCyan,
                                      fontSize: 11,
                                      fontWeight: FontWeight.bold,
                                    ),
                                  ),
                                ),
                              ],
                            ),
                            subtitle: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                const SizedBox(height: 4),
                                Text(
                                  pose.description,
                                  maxLines: 2,
                                  overflow: TextOverflow.ellipsis,
                                  style: const TextStyle(
                                    color: AppTheme.textSecondary,
                                    fontSize: 12,
                                  ),
                                ),
                                const SizedBox(height: 6),
                                Wrap(
                                  spacing: 4,
                                  children: pose.tags.map((tag) {
                                    return Container(
                                      padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                                      decoration: BoxDecoration(
                                        color: AppTheme.cardColor,
                                        borderRadius: BorderRadius.circular(6),
                                      ),
                                      child: Text(
                                        '#$tag',
                                        style: const TextStyle(
                                          color: AppTheme.textSecondary,
                                          fontSize: 10,
                                        ),
                                      ),
                                    );
                                  }).toList(),
                                ),
                              ],
                            ),
                            trailing: isSelected
                                ? const Icon(Icons.check_circle, color: AppTheme.primaryCyan, size: 24)
                                : OutlinedButton(
                                    style: OutlinedButton.styleFrom(
                                      foregroundColor: AppTheme.primaryCyan,
                                      side: const BorderSide(color: AppTheme.primaryCyan),
                                      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 4),
                                    ),
                                    onPressed: () {
                                      if (widget.onSelectPose != null) {
                                        widget.onSelectPose!(pose);
                                      }
                                    },
                                    child: const Text('Select', style: TextStyle(fontSize: 12)),
                                  ),
                            onTap: () {
                              if (widget.onSelectPose != null) {
                                widget.onSelectPose!(pose);
                              }
                            },
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

  IconData _getCategoryIcon(String category) {
    switch (category.toLowerCase()) {
      case 'standing':
        return Icons.accessibility_new;
      case 'sitting':
        return Icons.event_seat;
      case 'selfie':
        return Icons.camera_front;
      case 'portrait':
        return Icons.portrait;
      case 'outdoor':
        return Icons.nature_people;
      default:
        return Icons.person;
    }
  }
}
