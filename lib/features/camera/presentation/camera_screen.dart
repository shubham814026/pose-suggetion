import 'dart:io';
import 'package:camera/camera.dart';
import 'package:flutter/material.dart';
import 'package:permission_handler/permission_handler.dart';
import 'package:provider/provider.dart';
import '../../../../core/theme/app_theme.dart';
import '../../photo_analysis/presentation/photo_analysis_screen.dart';
import '../../photo_analysis/services/photo_context_analyzer.dart';
import '../../pose_library/presentation/widgets/target_pose_stencil_painter.dart';
import '../../pose_library/services/pose_library_service.dart';
import 'widgets/permission_denied_view.dart';

/// Clean, high-performance Camera Viewfinder.
/// Captures photo snapshots for multi-modal scene, lighting, and context pose suggestions.
class CameraScreen extends StatefulWidget {
  const CameraScreen({super.key});

  @override
  State<CameraScreen> createState() => _CameraScreenState();
}

class _CameraScreenState extends State<CameraScreen> with WidgetsBindingObserver {
  List<CameraDescription> _availableCameras = [];
  CameraController? _controller;
  int _selectedCameraIndex = 0;
  bool _isPermissionGranted = false;
  bool _isInitializing = true;
  bool _isAnalyzingPhoto = false;
  String? _errorMessage;
  XFile? _lastCapturedPhoto;

  final PhotoContextAnalyzer _photoContextAnalyzer = PhotoContextAnalyzer();

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
    _checkPermissionAndInit();
  }

  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
    _controller?.dispose();
    super.dispose();
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    final CameraController? cameraController = _controller;
    if (cameraController == null || !cameraController.value.isInitialized) {
      return;
    }
    if (state == AppLifecycleState.inactive) {
      cameraController.dispose();
    } else if (state == AppLifecycleState.resumed) {
      _initCamera(_selectedCameraIndex);
    }
  }

  Future<void> _checkPermissionAndInit() async {
    final status = await Permission.camera.request();
    if (status.isGranted) {
      setState(() {
        _isPermissionGranted = true;
      });
      await _initCameraSystem();
    } else {
      setState(() {
        _isPermissionGranted = false;
        _isInitializing = false;
      });
    }
  }

  Future<void> _initCameraSystem() async {
    try {
      _availableCameras = await availableCameras();
      if (_availableCameras.isEmpty) {
        setState(() {
          _errorMessage = 'No camera hardware found on device.';
          _isInitializing = false;
        });
        return;
      }

      int defaultIndex = _availableCameras.indexWhere(
        (cam) => cam.lensDirection == CameraLensDirection.back,
      );
      if (defaultIndex == -1) defaultIndex = 0;

      await _initCamera(defaultIndex);
    } catch (e) {
      setState(() {
        _errorMessage = 'Failed to discover camera hardware: $e';
        _isInitializing = false;
      });
    }
  }

  Future<void> _initCamera(int cameraIndex) async {
    if (_availableCameras.isEmpty) return;

    setState(() {
      _isInitializing = true;
      _errorMessage = null;
    });

    final previousController = _controller;
    final camera = _availableCameras[cameraIndex];

    final controller = CameraController(
      camera,
      ResolutionPreset.high,
      enableAudio: false,
    );

    await previousController?.dispose();

    try {
      await controller.initialize();
      if (!mounted) return;

      setState(() {
        _controller = controller;
        _selectedCameraIndex = cameraIndex;
        _isInitializing = false;
      });
    } on CameraException catch (e) {
      if (!mounted) return;
      setState(() {
        _errorMessage = 'Camera error: ${e.description}';
        _isInitializing = false;
      });
    }
  }

  Future<void> _toggleCameraLens() async {
    if (_availableCameras.length < 2) return;
    final newIndex = (_selectedCameraIndex + 1) % _availableCameras.length;
    await _initCamera(newIndex);
  }

  /// Snaps a photo from the camera and triggers the deep multi-modal analysis flow
  Future<void> _captureAndAnalyzePhoto() async {
    final controller = _controller;
    if (controller == null || !controller.value.isInitialized || _isAnalyzingPhoto) {
      return;
    }

    setState(() {
      _isAnalyzingPhoto = true;
    });

    try {
      final photo = await controller.takePicture();
      _lastCapturedPhoto = photo;

      if (!mounted) return;
      await _runAnalysisAndOpenScreen(photo.path);
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Failed to capture photo: $e'),
            backgroundColor: Colors.redAccent,
          ),
        );
      }
    } finally {
      if (mounted) {
        setState(() {
          _isAnalyzingPhoto = false;
        });
      }
    }
  }

  Future<void> _runAnalysisAndOpenScreen(String imagePath) async {
    final poseLibrary = Provider.of<PoseLibraryService>(context, listen: false);
    final isFrontCamera = _availableCameras.isNotEmpty &&
        _availableCameras[_selectedCameraIndex].lensDirection == CameraLensDirection.front;

    try {
      final result = await _photoContextAnalyzer.analyzePhoto(
        imagePath: imagePath,
        poseLibrary: poseLibrary,
        isFrontCamera: isFrontCamera,
      );

      if (!mounted) return;

      // Navigate to Photo Analysis & Recommendation Screen
      await Navigator.of(context).push<bool>(
        MaterialPageRoute(
          builder: (context) => PhotoAnalysisScreen(analysis: result),
        ),
      );
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Analysis failed: $e'),
            backgroundColor: Colors.redAccent,
          ),
        );
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    if (!_isPermissionGranted) {
      return PermissionDeniedView(
        onRequestPermission: _checkPermissionAndInit,
      );
    }

    final controller = _controller;
    final isInitialized = controller != null && controller.value.isInitialized;
    final poseLibrary = Provider.of<PoseLibraryService>(context);

    final isFrontCamera = _availableCameras.isNotEmpty &&
        _availableCameras[_selectedCameraIndex].lensDirection == CameraLensDirection.front;

    return Scaffold(
      backgroundColor: Colors.black,
      body: SafeArea(
        child: Stack(
          fit: StackFit.expand,
          children: [
            // 1. Live Camera Viewfinder
            if (isInitialized)
              Center(
                child: CameraPreview(controller),
              )
            else if (_isInitializing)
              const Center(
                child: Column(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    CircularProgressIndicator(color: AppTheme.primaryCyan),
                    SizedBox(height: 16),
                    Text(
                      'Initializing Camera...',
                      style: TextStyle(color: AppTheme.textPrimary, fontSize: 14),
                    ),
                  ],
                ),
              ),

            // 2. Active Target Pose Silhouette Stencil Overlay (When a pose is selected)
            if (isInitialized && poseLibrary.activeTargetPose != null)
              CustomPaint(
                painter: TargetPoseStencilPainter(
                  targetPose: poseLibrary.activeTargetPose,
                  isFrontCamera: isFrontCamera,
                  showSilhouette: true,
                  showActionTags: true,
                ),
              ),

            // 3. Top Header Bar: Camera Switcher, Active Pose HUD Badge
            if (isInitialized)
              Positioned(
                top: 16,
                left: 16,
                right: 16,
                child: Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    // Active Stencil Indicator + Remove Button
                    if (poseLibrary.activeTargetPose != null)
                      Flexible(
                        child: Row(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            Flexible(
                              child: Container(
                                padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                                decoration: BoxDecoration(
                                  color: Colors.black.withAlpha(210),
                                  borderRadius: BorderRadius.circular(20),
                                  border: Border.all(color: AppTheme.primaryCyan.withAlpha(200)),
                                ),
                                child: Row(
                                  mainAxisSize: MainAxisSize.min,
                                  children: [
                                    const Icon(Icons.accessibility_new, color: AppTheme.primaryCyan, size: 16),
                                    const SizedBox(width: 6),
                                    Flexible(
                                      child: Text(
                                        poseLibrary.activeTargetPose!.name,
                                        style: const TextStyle(
                                          color: Colors.white,
                                          fontSize: 12,
                                          fontWeight: FontWeight.bold,
                                        ),
                                        overflow: TextOverflow.ellipsis,
                                      ),
                                    ),
                                  ],
                                ),
                              ),
                            ),
                            const SizedBox(width: 8),
                            InkWell(
                              onTap: () => poseLibrary.clearActivePose(),
                              borderRadius: BorderRadius.circular(20),
                              child: Container(
                                padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
                                decoration: BoxDecoration(
                                  color: const Color(0xFFEF4444).withAlpha(220),
                                  borderRadius: BorderRadius.circular(20),
                                  boxShadow: const [
                                    BoxShadow(color: Colors.black45, blurRadius: 4),
                                  ],
                                ),
                                child: const Row(
                                  mainAxisSize: MainAxisSize.min,
                                  children: [
                                    Icon(Icons.close_rounded, color: Colors.white, size: 14),
                                    SizedBox(width: 4),
                                    Text(
                                      'Remove',
                                      style: TextStyle(color: Colors.white, fontSize: 11, fontWeight: FontWeight.bold),
                                    ),
                                  ],
                                ),
                              ),
                            ),
                          ],
                        ),
                      )
                    else
                      Container(
                        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                        decoration: BoxDecoration(
                          color: Colors.black.withAlpha(160),
                          borderRadius: BorderRadius.circular(20),
                          border: Border.all(color: Colors.white24),
                        ),
                        child: const Row(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            Icon(Icons.auto_awesome, color: AppTheme.primaryCyan, size: 14),
                            SizedBox(width: 6),
                            Text(
                              'Snap Photo for AI Scene Poses',
                              style: TextStyle(color: Colors.white, fontSize: 11, fontWeight: FontWeight.w600),
                            ),
                          ],
                        ),
                      ),

                    // Lens Switcher Button
                    Container(
                      decoration: BoxDecoration(
                        color: Colors.black.withAlpha(150),
                        shape: BoxShape.circle,
                        border: Border.all(color: Colors.white24),
                      ),
                      child: IconButton(
                        icon: const Icon(Icons.flip_camera_ios, color: Colors.white, size: 20),
                        onPressed: _availableCameras.length > 1 ? _toggleCameraLens : null,
                      ),
                    ),
                  ],
                ),
              ),

            // Hardware Error Banner
            if (_errorMessage != null)
              Positioned(
                top: 70,
                left: 16,
                right: 16,
                child: Container(
                  padding: const EdgeInsets.all(12),
                  decoration: BoxDecoration(
                    color: AppTheme.warningAmber.withAlpha(230),
                    borderRadius: BorderRadius.circular(12),
                  ),
                  child: Row(
                    children: [
                      const Icon(Icons.warning_amber_rounded, color: Colors.black),
                      const SizedBox(width: 10),
                      Expanded(
                        child: Text(
                          _errorMessage!,
                          style: const TextStyle(color: Colors.black, fontSize: 13, fontWeight: FontWeight.w600),
                        ),
                      ),
                      IconButton(
                        icon: const Icon(Icons.refresh, color: Colors.black),
                        onPressed: () => _initCamera(_selectedCameraIndex),
                      ),
                    ],
                  ),
                ),
              ),

            // 4. Loading Analysis Overlay
            if (_isAnalyzingPhoto)
              Container(
                color: Colors.black87,
                child: const Center(
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      CircularProgressIndicator(color: AppTheme.primaryCyan, strokeWidth: 3),
                      SizedBox(height: 16),
                      Text(
                        '✨ Analyzing Scene, Lighting & Context...',
                        style: TextStyle(
                          color: Colors.white,
                          fontSize: 15,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                      SizedBox(height: 6),
                      Text(
                        'Extracting atmosphere, sunset/daylight & people count',
                        style: TextStyle(color: AppTheme.textSecondary, fontSize: 12),
                      ),
                    ],
                  ),
                ),
              ),

            // 5. Bottom Control Deck (Capture Shutter, Last Photo Quick Re-Analyze)
            if (isInitialized && !_isAnalyzingPhoto)
              Positioned(
                bottom: 24,
                left: 0,
                right: 0,
                child: Row(
                  mainAxisAlignment: MainAxisAlignment.spaceEvenly,
                  children: [
                    // Flip camera lens or quick action
                    GestureDetector(
                      onTap: _availableCameras.length > 1 ? _toggleCameraLens : null,
                      child: Container(
                        width: 52,
                        height: 52,
                        decoration: BoxDecoration(
                          color: const Color(0xFF1E293B),
                          shape: BoxShape.circle,
                          border: Border.all(color: Colors.white24, width: 1.5),
                        ),
                        child: const Icon(Icons.cameraswitch_outlined, color: Colors.white, size: 24),
                      ),
                    ),

                    // Main Snapshot & Scene Analysis Shutter Button
                    GestureDetector(
                      onTap: _captureAndAnalyzePhoto,
                      child: Container(
                        width: 76,
                        height: 76,
                        decoration: BoxDecoration(
                          shape: BoxShape.circle,
                          border: Border.all(color: AppTheme.primaryCyan, width: 4),
                          boxShadow: [
                            BoxShadow(
                              color: AppTheme.primaryCyan.withAlpha(80),
                              blurRadius: 12,
                              spreadRadius: 2,
                            ),
                          ],
                        ),
                        child: Center(
                          child: Container(
                            width: 60,
                            height: 60,
                            decoration: const BoxDecoration(
                              color: AppTheme.primaryCyan,
                              shape: BoxShape.circle,
                            ),
                            child: const Center(
                              child: Icon(Icons.camera_alt, color: Colors.black, size: 28),
                            ),
                          ),
                        ),
                      ),
                    ),

                    // Last Photo Preview / Quick Re-Open Analysis
                    GestureDetector(
                      onTap: () {
                        if (_lastCapturedPhoto != null) {
                          _runAnalysisAndOpenScreen(_lastCapturedPhoto!.path);
                        } else {
                          _captureAndAnalyzePhoto();
                        }
                      },
                      child: Container(
                        width: 52,
                        height: 52,
                        decoration: BoxDecoration(
                          color: const Color(0xFF1E293B),
                          shape: BoxShape.circle,
                          border: Border.all(color: AppTheme.primaryCyan, width: 1.5),
                        ),
                        child: _lastCapturedPhoto != null
                            ? ClipOval(
                                child: Image.file(
                                  File(_lastCapturedPhoto!.path),
                                  fit: BoxFit.cover,
                                ),
                              )
                            : const Icon(Icons.auto_awesome, color: AppTheme.primaryCyan, size: 22),
                      ),
                    ),
                  ],
                ),
              ),
          ],
        ),
      ),
    );
  }
}
