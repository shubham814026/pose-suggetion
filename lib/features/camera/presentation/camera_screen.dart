import 'dart:io';
import 'package:camera/camera.dart';
import 'package:flutter/material.dart';
import 'package:google_mlkit_pose_detection/google_mlkit_pose_detection.dart';
import 'package:permission_handler/permission_handler.dart';
import '../../../../core/theme/app_theme.dart';
import '../../pose_detection/presentation/widgets/pose_overlay_painter.dart';
import '../../pose_detection/services/pose_detector_service.dart';
import '../../pose_detection/utils/camera_image_converter.dart';
import '../../pose_library/models/target_pose.dart';
import '../../pose_library/presentation/pose_library_screen.dart';
import '../../pose_library/presentation/widgets/target_pose_stencil_painter.dart';
import 'widgets/permission_denied_view.dart';

class CameraScreen extends StatefulWidget {
  final TargetPose? selectedTargetPose;
  final ValueChanged<TargetPose>? onSelectPose;

  const CameraScreen({
    super.key,
    this.selectedTargetPose,
    this.onSelectPose,
  });

  @override
  State<CameraScreen> createState() => _CameraScreenState();
}

class _CameraScreenState extends State<CameraScreen> with WidgetsBindingObserver {
  PermissionStatus _permissionStatus = PermissionStatus.denied;
  bool _isCheckingPermission = true;

  // Camera Hardware State
  List<CameraDescription> _availableCameras = [];
  CameraController? _cameraController;
  int _selectedCameraIndex = 0;
  bool _isCameraInitializing = false;
  String? _cameraError;

  // Photo Capture & Preview State
  bool _isCapturing = false;
  String? _lastCapturedPath;

  // Real-Time Live Stream Pose Detection State
  final PoseDetectorService _streamPoseDetector = PoseDetectorService(
    mode: PoseDetectionMode.stream,
    model: PoseDetectionModel.base,
  );
  
  bool _isStreamDetecting = false;
  DateTime _lastFrameTimestamp = DateTime.now();
  static const Duration _throttleDuration = Duration(milliseconds: 250);
  List<Pose> _livePoses = [];

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
    _checkPermissionAndInit();
  }

  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
    _disposeCameraController();
    _streamPoseDetector.close();
    super.dispose();
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    final CameraController? controller = _cameraController;
    if (controller == null || !controller.value.isInitialized) {
      return;
    }

    if (state == AppLifecycleState.inactive || state == AppLifecycleState.paused) {
      _disposeCameraController();
    } else if (state == AppLifecycleState.resumed) {
      _checkPermissionAndInit();
    }
  }

  Future<void> _disposeCameraController() async {
    final controller = _cameraController;
    _cameraController = null;
    if (controller != null) {
      if (controller.value.isStreamingImages) {
        await controller.stopImageStream();
      }
      await controller.dispose();
    }
  }

  Future<void> _checkPermissionAndInit() async {
    final status = await Permission.camera.status;
    if (!mounted) return;

    setState(() {
      _permissionStatus = status;
      _isCheckingPermission = false;
    });

    if (status.isGranted) {
      await _loadAvailableCameras();
    }
  }

  Future<void> _requestPermission() async {
    final status = await Permission.camera.request();
    if (!mounted) return;

    setState(() {
      _permissionStatus = status;
    });

    if (status.isGranted) {
      await _loadAvailableCameras();
    }
  }

  Future<void> _loadAvailableCameras() async {
    if (_isCameraInitializing) return;

    setState(() {
      _isCameraInitializing = true;
      _cameraError = null;
    });

    try {
      _availableCameras = await availableCameras();
      if (_availableCameras.isNotEmpty) {
        final frontIndex = _availableCameras.indexWhere(
          (c) => c.lensDirection == CameraLensDirection.front,
        );
        _selectedCameraIndex = frontIndex != -1 ? frontIndex : 0;
        await _initializeController(_availableCameras[_selectedCameraIndex]);
      } else {
        setState(() {
          _cameraError = 'No camera devices found on this device.';
        });
      }
    } on CameraException catch (e) {
      setState(() {
        _cameraError = 'Camera Exception: ${e.description ?? e.code}';
      });
    } catch (e) {
      setState(() {
        _cameraError = 'Failed to load camera devices: $e';
      });
    } finally {
      if (mounted) {
        setState(() {
          _isCameraInitializing = false;
        });
      }
    }
  }

  Future<void> _initializeController(CameraDescription description) async {
    await _disposeCameraController();

    final controller = CameraController(
      description,
      ResolutionPreset.high,
      enableAudio: false,
      imageFormatGroup: ImageFormatGroup.yuv420,
    );

    _cameraController = controller;

    try {
      await controller.initialize();
      await controller.startImageStream(_onLiveCameraFrame);
    } on CameraException catch (e) {
      if (mounted) {
        setState(() {
          _cameraError = 'Failed to initialize camera: ${e.description ?? e.code}';
        });
      }
    }

    if (mounted) {
      setState(() {});
    }
  }

  void _onLiveCameraFrame(CameraImage image) async {
    final now = DateTime.now();
    if (_isStreamDetecting || now.difference(_lastFrameTimestamp) < _throttleDuration) {
      return;
    }

    _isStreamDetecting = true;
    _lastFrameTimestamp = now;

    try {
      if (_availableCameras.isEmpty) return;
      final currentCamera = _availableCameras[_selectedCameraIndex];
      final inputImage = convertCameraImageToInputImage(image, currentCamera);

      if (inputImage != null) {
        final poses = await _streamPoseDetector.processInputImage(inputImage);
        if (mounted) {
          setState(() {
            _livePoses = poses;
          });
        }
      }
    } catch (e) {
      // Silently handle frame processing anomalies during stream transition
    } finally {
      _isStreamDetecting = false;
    }
  }

  Future<void> _toggleCameraLens() async {
    if (_availableCameras.length <= 1 || _isCameraInitializing) return;

    final nextIndex = (_selectedCameraIndex + 1) % _availableCameras.length;
    setState(() {
      _selectedCameraIndex = nextIndex;
      _isCameraInitializing = true;
      _livePoses = [];
    });

    try {
      await _initializeController(_availableCameras[_selectedCameraIndex]);
    } finally {
      if (mounted) {
        setState(() {
          _isCameraInitializing = false;
        });
      }
    }
  }

  void _openPosePickerModal() {
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (context) => DraggableScrollableSheet(
        initialChildSize: 0.75,
        maxChildSize: 0.9,
        minChildSize: 0.5,
        builder: (context, scrollController) => ClipRRect(
          borderRadius: const BorderRadius.vertical(top: Radius.circular(24)),
          child: PoseLibraryScreen(
            selectedPose: widget.selectedTargetPose,
            onSelectPose: (pose) {
              if (widget.onSelectPose != null) {
                widget.onSelectPose!(pose);
              }
              Navigator.pop(context);
            },
          ),
        ),
      ),
    );
  }

  Future<void> _takePicture() async {
    final controller = _cameraController;
    if (controller == null || !controller.value.isInitialized || _isCapturing) {
      return;
    }

    setState(() {
      _isCapturing = true;
    });

    try {
      final XFile photoFile = await controller.takePicture();
      if (!mounted) return;

      setState(() {
        _lastCapturedPath = photoFile.path;
      });

      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          duration: const Duration(seconds: 3),
          backgroundColor: AppTheme.surfaceColor,
          behavior: SnackBarBehavior.floating,
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
          content: Row(
            children: [
              ClipRRect(
                borderRadius: BorderRadius.circular(8),
                child: Image.file(
                  File(photoFile.path),
                  width: 44,
                  height: 44,
                  fit: BoxFit.cover,
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    const Text(
                      'Photo Captured!',
                      style: TextStyle(
                        color: AppTheme.textPrimary,
                        fontWeight: FontWeight.bold,
                        fontSize: 14,
                      ),
                    ),
                    Text(
                      widget.selectedTargetPose != null
                          ? 'Matched against "${widget.selectedTargetPose!.name}"'
                          : 'Saved locally to app cache.',
                      style: const TextStyle(
                        color: AppTheme.textSecondary,
                        fontSize: 12,
                      ),
                    ),
                  ],
                ),
              ),
              const Icon(Icons.check_circle, color: AppTheme.successGreen, size: 22),
            ],
          ),
        ),
      );
    } on CameraException catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          backgroundColor: Colors.redAccent,
          content: Text('Failed to take picture: ${e.description ?? e.code}'),
        ),
      );
    } finally {
      if (mounted) {
        setState(() {
          _isCapturing = false;
        });
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final bool canToggleLens = _availableCameras.length > 1;

    return Scaffold(
      backgroundColor: AppTheme.darkBackground,
      appBar: AppBar(
        title: const Text('Pose Assistant'),
        actions: [
          if (_permissionStatus.isGranted && _cameraController != null && _cameraController!.value.isInitialized) ...[
            IconButton(
              icon: Icon(
                canToggleLens ? Icons.flip_camera_ios : Icons.flip_camera_ios_outlined,
                color: canToggleLens ? AppTheme.primaryCyan : AppTheme.textSecondary,
              ),
              onPressed: canToggleLens ? _toggleCameraLens : null,
              tooltip: canToggleLens ? 'Switch Camera Lens' : 'Single Camera Available',
            ),
          ],
        ],
      ),
      body: SafeArea(
        child: _buildContent(),
      ),
    );
  }

  Widget _buildContent() {
    if (_isCheckingPermission) {
      return const Center(
        child: CircularProgressIndicator(color: AppTheme.primaryCyan),
      );
    }

    if (!_permissionStatus.isGranted) {
      return PermissionDeniedView(
        status: _permissionStatus,
        onRequestPermission: _requestPermission,
      );
    }

    if (_cameraError != null) {
      return Center(
        child: Padding(
          padding: const EdgeInsets.all(24.0),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              const Icon(Icons.error_outline, size: 48, color: Colors.redAccent),
              const SizedBox(height: 16),
              Text(
                _cameraError!,
                textAlign: TextAlign.center,
                style: const TextStyle(color: AppTheme.textPrimary, fontSize: 14),
              ),
              const SizedBox(height: 20),
              ElevatedButton.icon(
                onPressed: _loadAvailableCameras,
                icon: const Icon(Icons.refresh),
                label: const Text('Retry Camera Initialization'),
                style: ElevatedButton.styleFrom(
                  backgroundColor: AppTheme.primaryCyan,
                  foregroundColor: Colors.black,
                ),
              ),
            ],
          ),
        ),
      );
    }

    if (_isCameraInitializing || _cameraController == null || !_cameraController!.value.isInitialized) {
      return const Center(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            CircularProgressIndicator(color: AppTheme.primaryCyan),
            SizedBox(height: 16),
            Text(
              'Initializing Camera Hardware...',
              style: TextStyle(color: AppTheme.textSecondary, fontSize: 13),
            ),
          ],
        ),
      );
    }

    final currentCamera = _availableCameras[_selectedCameraIndex];
    final isFrontFacing = currentCamera.lensDirection == CameraLensDirection.front;
    final detectedLandmarksCount = _livePoses.isNotEmpty ? _livePoses.first.landmarks.length : 0;
    final previewSize = _cameraController!.value.previewSize;
    final activePose = widget.selectedTargetPose;

    return Column(
      children: [
        // Live Camera Preview Viewport with CustomPainter Overlay Stack
        Expanded(
          child: Container(
            margin: const EdgeInsets.all(16),
            decoration: BoxDecoration(
              color: Colors.black,
              borderRadius: BorderRadius.circular(24),
              border: Border.all(
                color: detectedLandmarksCount > 0 ? AppTheme.successGreen : AppTheme.primaryCyan.withOpacity(0.5),
                width: 1.5,
              ),
              boxShadow: [
                BoxShadow(
                  color: Colors.black.withOpacity(0.4),
                  blurRadius: 16,
                  offset: const Offset(0, 6),
                ),
              ],
            ),
            child: ClipRRect(
              borderRadius: BorderRadius.circular(22),
              child: Stack(
                fit: StackViewConstraints.expand,
                children: [
                  // Camera Preview
                  Center(
                    child: CameraPreview(_cameraController!),
                  ),

                  // Target Pose Silhouette Stencil Overlay (Item 10)
                  if (activePose != null)
                    Positioned.fill(
                      child: CustomPaint(
                        painter: TargetPoseStencilPainter(
                          targetPose: activePose,
                          stencilColor: AppTheme.primaryCyan.withOpacity(0.55),
                          lensDirection: currentCamera.lensDirection,
                        ),
                      ),
                    ),

                  // Real-time Live User Skeleton Overlay (Item 7)
                  if (_livePoses.isNotEmpty && previewSize != null)
                    Positioned.fill(
                      child: CustomPaint(
                        painter: PoseOverlayPainter(
                          poses: _livePoses,
                          imageSize: Size(previewSize.height, previewSize.width),
                          lensDirection: currentCamera.lensDirection,
                        ),
                      ),
                    ),

                  // Lens Direction Indicator Badge
                  Positioned(
                    top: 12,
                    left: 12,
                    child: Container(
                      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
                      decoration: BoxDecoration(
                        color: Colors.black54,
                        borderRadius: BorderRadius.circular(12),
                        border: Border.all(color: AppTheme.primaryCyan.withOpacity(0.5)),
                      ),
                      child: Row(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          Icon(
                            isFrontFacing ? Icons.person_pin : Icons.photo_camera,
                            size: 14,
                            color: AppTheme.primaryCyan,
                          ),
                          const SizedBox(width: 6),
                          Text(
                            isFrontFacing ? 'Front Camera' : 'Rear Camera',
                            style: const TextStyle(
                              color: AppTheme.textPrimary,
                              fontSize: 11,
                              fontWeight: FontWeight.w600,
                            ),
                          ),
                        ],
                      ),
                    ),
                  ),

                  // Selected Target Pose Active Badge Bar
                  if (activePose != null)
                    Positioned(
                      bottom: 12,
                      left: 12,
                      right: 12,
                      child: Container(
                        padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
                        decoration: BoxDecoration(
                          color: Colors.black80,
                          borderRadius: BorderRadius.circular(16),
                          border: Border.all(color: AppTheme.primaryCyan, width: 1),
                        ),
                        child: Row(
                          children: [
                            const Icon(Icons.collections_bookmark, color: AppTheme.primaryCyan, size: 18),
                            const SizedBox(width: 8),
                            Expanded(
                              child: Text(
                                'Target Stencil: ${activePose.name}',
                                style: const TextStyle(
                                  color: AppTheme.textPrimary,
                                  fontSize: 12,
                                  fontWeight: FontWeight.bold,
                                ),
                                overflow: TextOverflow.ellipsis,
                              ),
                            ),
                            TextButton(
                              onPressed: _openPosePickerModal,
                              style: TextButton.styleFrom(
                                padding: EdgeInsets.zero,
                                minimumSize: Size.zero,
                                tapTargetSize: MaterialTapTargetSize.shrinkWrap,
                              ),
                              child: const Text(
                                'Change',
                                style: TextStyle(color: AppTheme.primaryCyan, fontSize: 12),
                              ),
                            ),
                          ],
                        ),
                      ),
                    ),

                  // Real-Time Stream Pose Detection Live Status Badge
                  Positioned(
                    top: 12,
                    right: 12,
                    child: AnimatedContainer(
                      duration: const Duration(milliseconds: 200),
                      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
                      decoration: BoxDecoration(
                        color: Colors.black80,
                        borderRadius: BorderRadius.circular(12),
                        border: Border.all(
                          color: detectedLandmarksCount > 0 ? AppTheme.successGreen : AppTheme.warningAmber,
                          width: 1,
                        ),
                      ),
                      child: Row(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          Icon(
                            detectedLandmarksCount > 0 ? Icons.accessibility_new : Icons.person_search_outlined,
                            size: 14,
                            color: detectedLandmarksCount > 0 ? AppTheme.successGreen : AppTheme.warningAmber,
                          ),
                          const SizedBox(width: 6),
                          Text(
                            detectedLandmarksCount > 0
                                ? 'Skeleton Active ($detectedLandmarksCount/33)'
                                : 'Searching Person...',
                            style: TextStyle(
                              color: detectedLandmarksCount > 0 ? AppTheme.successGreen : AppTheme.warningAmber,
                              fontSize: 11,
                              fontWeight: FontWeight.bold,
                            ),
                          ),
                        ],
                      ),
                    ),
                  ),

                  // Flash capture animation overlay
                  if (_isCapturing)
                    Container(
                      color: Colors.white.withOpacity(0.4),
                    ),
                ],
              ),
            ),
          ),
        ),

        // Controls Bar
        Container(
          padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 20),
          decoration: const BoxDecoration(
            color: AppTheme.surfaceColor,
            borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
          ),
          child: Row(
            mainAxisAlignment: MainAxisAlignment.spaceEvenly,
            children: [
              IconButton(
                icon: const Icon(Icons.collections, color: AppTheme.primaryCyan, size: 28),
                onPressed: _openPosePickerModal,
                tooltip: 'Select Target Pose',
              ),

              // Shutter Button
              GestureDetector(
                onTap: _isCapturing ? null : _takePicture,
                child: Container(
                  width: 76,
                  height: 76,
                  decoration: BoxDecoration(
                    shape: BoxShape.circle,
                    border: Border.all(color: Colors.white, width: 4),
                  ),
                  child: Center(
                    child: AnimatedContainer(
                      duration: const Duration(milliseconds: 150),
                      width: _isCapturing ? 48 : 62,
                      height: _isCapturing ? 48 : 62,
                      decoration: BoxDecoration(
                        shape: BoxShape.circle,
                        color: _isCapturing ? AppTheme.accentViolet : AppTheme.primaryCyan,
                      ),
                      child: _isCapturing
                          ? const Center(
                              child: SizedBox(
                                width: 24,
                                height: 24,
                                child: CircularProgressIndicator(
                                  strokeWidth: 2.5,
                                  color: Colors.white,
                                ),
                              ),
                            )
                          : null,
                    ),
                  ),
                ),
              ),

              // Thumbnail Preview or Switch Lens
              _lastCapturedPath != null
                  ? GestureDetector(
                      onTap: () {
                        showDialog(
                          context: context,
                          builder: (context) => Dialog(
                            backgroundColor: AppTheme.surfaceColor,
                            shape: RoundedRectangleBorder(
                              borderRadius: BorderRadius.circular(20),
                            ),
                            child: Column(
                              mainAxisSize: MainAxisSize.min,
                              children: [
                                ClipRRect(
                                  borderRadius: const BorderRadius.vertical(
                                    top: Radius.circular(20),
                                  ),
                                  child: Image.file(
                                    File(_lastCapturedPath!),
                                    fit: BoxFit.cover,
                                  ),
                                ),
                                Padding(
                                  padding: const EdgeInsets.all(16.0),
                                  child: TextButton(
                                    onPressed: () => Navigator.pop(context),
                                    child: const Text(
                                      'Close Preview',
                                      style: TextStyle(color: AppTheme.primaryCyan),
                                    ),
                                  ),
                                ),
                              ],
                            ),
                          ),
                        );
                      },
                      child: Container(
                        width: 40,
                        height: 40,
                        decoration: BoxDecoration(
                          borderRadius: BorderRadius.circular(10),
                          border: Border.all(color: AppTheme.primaryCyan, width: 1.5),
                        ),
                        child: ClipRRect(
                          borderRadius: BorderRadius.circular(8),
                          child: Image.file(
                            File(_lastCapturedPath!),
                            fit: BoxFit.cover,
                          ),
                        ),
                      ),
                    )
                  : IconButton(
                      icon: Icon(
                        canToggleLens ? Icons.flip_camera_ios : Icons.volume_up,
                        color: AppTheme.textSecondary,
                        size: 28,
                      ),
                      onPressed: canToggleLens ? _toggleCameraLens : null,
                      tooltip: canToggleLens ? 'Switch Camera' : 'Voice Guidance',
                    ),
            ],
          ),
        ),
      ],
    );
  }
}
