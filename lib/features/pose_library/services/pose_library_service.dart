import 'dart:convert';
import 'package:flutter/services.dart' show rootBundle;
import 'package:flutter/foundation.dart';
import '../data/models/target_pose.dart';

/// Service responsible for managing reference target poses and the active camera stencil.
class PoseLibraryService extends ChangeNotifier {
  List<TargetPose> _allPoses = [];
  String _selectedCategory = 'All';
  TargetPose? _activeTargetPose;
  bool _isLoading = true;
  bool _userExplicitlyCleared = false;

  List<TargetPose> get allPoses => _allPoses;
  String get selectedCategory => _selectedCategory;
  bool get isLoading => _isLoading;
  bool get userExplicitlyCleared => _userExplicitlyCleared;

  /// Returns the currently active TargetPose for stencil rendering.
  TargetPose? get activeTargetPose => _activeTargetPose;

  /// Returns all unique categories available across the database.
  List<String> get availableCategories {
    final Set<String> categories = {'All'};
    for (final p in _allPoses) {
      if (p.category.isNotEmpty) {
        categories.add(p.category);
      }
    }
    return categories.toList();
  }

  /// Returns target poses filtered by active category selection.
  List<TargetPose> get filteredPoses {
    if (_selectedCategory == 'All') return _allPoses;
    return _allPoses.where((p) => p.category.toLowerCase() == _selectedCategory.toLowerCase()).toList();
  }

  /// Automatically selects a recommended pose as active if no pose is active and not explicitly cleared.
  void autoSelectRecommendedPose(TargetPose pose) {
    if (_activeTargetPose == null && !_userExplicitlyCleared) {
      _activeTargetPose = pose;
      notifyListeners();
    }
  }

  /// Sets a target pose as the active camera stencil overlay.
  void setCustomActivePose(TargetPose pose) {
    _activeTargetPose = pose;
    _userExplicitlyCleared = false;
    notifyListeners();
  }

  /// Selects a pose by ID.
  void selectPoseById(String id) {
    if (id.isEmpty) {
      clearActivePose();
      return;
    }
    try {
      _activeTargetPose = _allPoses.firstWhere((p) => p.id == id);
      _userExplicitlyCleared = false;
      notifyListeners();
    } catch (_) {
      clearActivePose();
    }
  }

  /// Clears the active stencil overlay completely from the camera.
  void clearActivePose() {
    _activeTargetPose = null;
    _userExplicitlyCleared = true;
    notifyListeners();
  }

  /// Loads target pose database from assets.
  Future<void> loadPoseLibrary() async {
    _isLoading = true;
    notifyListeners();

    try {
      final jsonString = await rootBundle.loadString('assets/poses/target_poses.json');
      final List<dynamic> jsonList = jsonDecode(jsonString) as List<dynamic>;
      _allPoses = jsonList.map((j) => TargetPose.fromJson(j as Map<String, dynamic>)).toList();
      _isLoading = false;
      notifyListeners();
    } catch (e) {
      debugPrint('Error loading pose library: $e');
      _allPoses = [];
      _isLoading = false;
      notifyListeners();
    }
  }

  /// Sets active category filter.
  void setCategory(String category) {
    if (_selectedCategory != category) {
      _selectedCategory = category;
      notifyListeners();
    }
  }
}
