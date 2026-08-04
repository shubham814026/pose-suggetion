import 'dart:convert';
import 'package:flutter/foundation.dart';
import 'package:flutter/services.dart';
import '../models/target_pose.dart';

class PoseLibraryService {
  List<TargetPose> _cachedPoses = [];
  bool _isLoaded = false;

  /// Load reference target poses from bundled JSON asset
  Future<List<TargetPose>> loadTargetPoses() async {
    if (_isLoaded) {
      return _cachedPoses;
    }

    try {
      final jsonString = await rootBundle.loadString('assets/poses/target_poses.json');
      final List<dynamic> jsonList = jsonDecode(jsonString);
      
      _cachedPoses = jsonList
          .map((item) => TargetPose.fromJson(item as Map<String, dynamic>))
          .toList();
      _isLoaded = true;
      return _cachedPoses;
    } catch (e) {
      debugPrint('Failed to load target poses asset: $e');
      return [];
    }
  }

  /// Get pose by ID
  TargetPose? getPoseById(String id) {
    try {
      return _cachedPoses.firstWhere((p) => p.id == id);
    } catch (_) {
      return null;
    }
  }
}
