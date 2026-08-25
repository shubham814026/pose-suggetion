import 'dart:io';
import 'package:camera/camera.dart';
import 'package:flutter/material.dart';
import 'package:google_mlkit_pose_detection/google_mlkit_pose_detection.dart';
import 'package:permission_handler/permission_handler.dart';
import '../../../../core/theme/app_theme.dart';
import '../../pose_detection/presentation/widgets/pose_overlay_painter.dart';
import '../../pose_detection/services/pose_detector_service.dart';
import '../../pose_detection/utils/camera_image_converter.dart';
import 'widgets/permission_denied_view.dart';

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
  bool _isCapturing = false;
  String? _errorMessage;
  XFile? _lastCapturedPhoto;

  // ML Kit Pose Detection & Stream Throttle Latch
  late final PoseDetectorService _poseDetectorService;
  List<Pose> _detectedPoses = [];
  bool _isProcessingFrame = false;
  int _lastFrameTimestamp = 0;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
    _poseDetectorService = PoseDetectorService();
    _checkPermissionAndInit();
  }

  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
    _stopImageStream();
    _controller?.dispose();
    _poseDetectorService.dispose();
    super.dispose();
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    final CameraController? cameraController = _controller;
    if (cameraController == null || !cameraController.value.isInitialized) {
      return;
    }
    if (state == AppLifecycleState.inactive) {
      _stopImageStream();
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
        (cam) => cam.lensDirection == CameraLensDirection.front,
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
    await _stopImageStream();

    final camera = _availableCameras[cameraIndex];

    // Use ResolutionPreset.medium (720p) for 3x faster ML Kit frame processing & lower memory bandwidth
    final controller = CameraController(
      camera,
      ResolutionPreset.medium,
      enableAudio: false,
      imageFormatGroup: Platform.isAndroid ? ImageFormatGroup.nv21 : ImageFormatGroup.bgra8888,
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

      _startImageStream();
    } on CameraException catch (e) {
      if (!mounted) return;
      setState(() {
        _errorMessage = 'Camera hardware error: ${e.description} (Code: ${e.code})';
        _isInitializing = false;
      });
    }
  }

  void _startImageStream() {
    final controller = _controller;
    if (controller == null || !controller.value.isInitialized) return;

    try {
      controller.startImageStream(_processCameraFrame);
    } catch (e) {
      // Ignore if stream already active
    }
  }

  Future<void> _stopImageStream() async {
    final controller = _controller;
    if (controller != null && controller.value.isStreamingImages) {
      try {
        await controller.stopImageStream();
      } catch (e) {
        // Stream stopped
      }
    }
  }

  void _processCameraFrame(CameraImage image) async {
    final now = DateTime.now().millisecondsSinceEpoch;

    // Ultra-Fast 60ms Stream Throttle Latch (up to 16-20 FPS)
    if (_isProcessingFrame || (now - _lastFrameTimestamp < 60)) {
      return;
    }

    _isProcessingFrame = true;
    _lastFrameTimestamp = now;

    try {
      final camera = _availableCameras[_selectedCameraIndex];
      final inputImage = CameraImageConverter.inputImageFromCameraImage(
        image: image,
        camera: camera,
      );

      if (inputImage != null) {
        final poses = await _poseDetectorService.processImage(inputImage);
        if (poses.isNotEmpty) {
          debugPrint('[POSE ENGINE] Success: ${poses.length} pose(s) detected with ${poses.first.landmarks.length} landmarks');
        }
        if (mounted) {
          setState(() {
            _detectedPoses = poses;
          });
        }
      } else {
        debugPrint('[POSE ENGINE] Warning: inputImage conversion returned null');
      }
    } catch (e, stack) {
      debugPrint('[POSE ENGINE] Error processing frame: $e\n$stack');
    } finally {
      _isProcessingFrame = false;
    }
  }

  Future<void> _toggleCameraLens() async {
    if (_availableCameras.length < 2) return;
    final newIndex = (_selectedCameraIndex + 1) % _availableCameras.length;
    await _initCamera(newIndex);
  }

  Future<void> _takePhoto() async {
    final controller = _controller;
    if (controller == null || !controller.value.isInitialized || _isCapturing) {
      return;
    }

    setState(() {
      _isCapturing = true;
    });

    try {
      await _stopImageStream();
      final photo = await controller.takePicture();
      _startImageStream();

      if (!mounted) return;

      setState(() {
        _lastCapturedPhoto = photo;
        _isCapturing = false;
      });

      _showPhotoCapturedBottomSheet(photo);
    } catch (e) {
      _startImageStream();
      if (!mounted) return;
      setState(() {
        _isCapturing = false;
      });
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('Failed to capture photo: $e'),
          backgroundColor: Colors.redAccent,
        ),
      );
    }
  }

  void _showPhotoCapturedBottomSheet(XFile photo) {
    showModalBottomSheet(
      context: context,
      backgroundColor: AppTheme.surfaceColor,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
      ),
      builder: (context) {
        return Padding(
          padding: const EdgeInsets.all(20.0),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Container(
                width: 40,
                height: 4,
                decoration: BoxDecoration(
                  color: AppTheme.textSecondary.withAlpha(102),
                  borderRadius: BorderRadius.circular(2),
                ),
              ),
              const SizedBox(height: 16),
              const Row(
                children: [
                  Icon(Icons.check_circle_outline, color: AppTheme.successGreen, size: 24),
                  SizedBox(width: 10),
                  Text(
                    'Photo Captured',
                    style: TextStyle(
                      color: AppTheme.textPrimary,
                      fontSize: 18,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 16),
              ClipRRect(
                borderRadius: BorderRadius.circular(16),
                child: SizedBox(
                  height: 200,
                  width: double.infinity,
                  child: Image.file(
                    File(photo.path),
                    fit: BoxFit.cover,
                  ),
                ),
              ),
              const SizedBox(height: 16),
              Text(
                'Saved to local cache: ${photo.path.split('/').last}',
                style: const TextStyle(color: AppTheme.textSecondary, fontSize: 12),
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
              ),
              const SizedBox(height: 20),
              ElevatedButton(
                onPressed: () => Navigator.of(context).pop(),
                style: ElevatedButton.styleFrom(
                  backgroundColor: AppTheme.primaryCyan,
                  foregroundColor: Colors.black,
                  minimumSize: const Size.fromHeight(48),
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(12),
                  ),
                ),
                child: const Text('Continue', style: TextStyle(fontWeight: FontWeight.bold)),
              ),
            ],
          ),
        );
      },
    );
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

    Size previewSize = Size.zero;
    if (isInitialized) {
      final size = controller.value.previewSize!;
      previewSize = Size(size.height, size.width);
    }

    return Scaffold(
      backgroundColor: Colors.black,
      body: SafeArea(
        child: Stack(
          fit: StackFit.expand,
          children: [
            // 1. Live Camera Preview Viewport
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
                      'Initializing Camera & AI Engine...',
                      style: TextStyle(color: AppTheme.textPrimary, fontSize: 14),
                    ),
                  ],
                ),
              ),

            // 2. Real-Time ML Kit Skeleton Overlay Layer
            if (isInitialized)
              CustomPaint(
                painter: PoseOverlayPainter(
                  poses: _detectedPoses,
                  previewSize: previewSize,
                  lensDirection: _availableCameras[_selectedCameraIndex].lensDirection,
                ),
              ),

            // 3. Pose Detection Status HUD (Top Left)
            if (isInitialized)
              Positioned(
                top: 16,
                left: 16,
                child: Container(
                  padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                  decoration: BoxDecoration(
                    color: Colors.black.withAlpha(166),
                    borderRadius: BorderRadius.circular(20),
                    border: Border.all(
                      color: _detectedPoses.isNotEmpty ? AppTheme.successGreen : AppTheme.warningAmber,
                      width: 1.5,
                    ),
                  ),
                  child: Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Container(
                        width: 8,
                        height: 8,
                        decoration: BoxDecoration(
                          shape: BoxShape.circle,
                          color: _detectedPoses.isNotEmpty ? AppTheme.successGreen : AppTheme.warningAmber,
                        ),
                      ),
                      const SizedBox(width: 8),
                      Text(
                        _detectedPoses.isNotEmpty
                            ? 'Pose Tracking Active (${_detectedPoses.first.landmarks.length} pts)'
                            : 'Searching for Person...',
                        style: const TextStyle(
                          color: AppTheme.textPrimary,
                          fontSize: 12,
                          fontWeight: FontWeight.w600,
                        ),
                      ),
                    ],
                  ),
                ),
              ),

            // 4. Hardware Error Banner
            if (_errorMessage != null)
              Positioned(
                top: 16,
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

            // 5. Top Right Lens Switcher
            if (isInitialized)
              Positioned(
                top: 16,
                right: 16,
                child: Container(
                  decoration: BoxDecoration(
                    color: Colors.black.withAlpha(128),
                    shape: BoxShape.circle,
                  ),
                  child: IconButton(
                    icon: const Icon(Icons.flip_camera_ios, color: AppTheme.textPrimary),
                    onPressed: _availableCameras.length > 1 ? _toggleCameraLens : null,
                  ),
                ),
              ),

            // 6. Bottom Controls (Shutter Button & Thumbnail)
            if (isInitialized)
              Positioned(
                bottom: 24,
                left: 0,
                right: 0,
                child: Row(
                  mainAxisAlignment: MainAxisAlignment.spaceEvenly,
                  children: [
                    // Last photo thumbnail preview
                    GestureDetector(
                      onTap: () {
                        if (_lastCapturedPhoto != null) {
                          _showPhotoCapturedBottomSheet(_lastCapturedPhoto!);
                        }
                      },
                      child: Container(
                        width: 48,
                        height: 48,
                        decoration: BoxDecoration(
                          color: AppTheme.surfaceColor,
                          shape: BoxShape.circle,
                          border: Border.all(color: AppTheme.primaryCyan, width: 2),
                        ),
                        child: _lastCapturedPhoto != null
                            ? ClipOval(
                                child: Image.file(
                                  File(_lastCapturedPhoto!.path),
                                  fit: BoxFit.cover,
                                ),
                              )
                            : const Icon(Icons.image_outlined, color: AppTheme.textSecondary),
                      ),
                    ),

                    // Shutter button
                    GestureDetector(
                      onTap: _isCapturing ? null : _takePhoto,
                      child: Container(
                        width: 72,
                        height: 72,
                        decoration: BoxDecoration(
                          shape: BoxShape.circle,
                          border: Border.all(color: AppTheme.primaryCyan, width: 4),
                        ),
                        child: Center(
                          child: Container(
                            width: 56,
                            height: 56,
                            decoration: BoxDecoration(
                              color: _isCapturing ? AppTheme.warningAmber : AppTheme.primaryCyan,
                              shape: BoxShape.circle,
                            ),
                            child: _isCapturing
                                ? const Padding(
                                    padding: EdgeInsets.all(16.0),
                                    child: CircularProgressIndicator(color: Colors.black, strokeWidth: 3),
                                  )
                                : null,
                          ),
                        ),
                      ),
                    ),

                    // Spacing balance
                    const SizedBox(width: 48),
                  ],
                ),
              ),
          ],
        ),
      ),
    );
  }
}
