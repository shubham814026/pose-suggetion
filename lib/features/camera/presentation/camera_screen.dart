import 'dart:async';
import 'dart:io';
import 'package:camera/camera.dart';
import 'package:flutter/material.dart';
import 'package:google_mlkit_pose_detection/google_mlkit_pose_detection.dart';
import 'package:permission_handler/permission_handler.dart';
import '../../../../core/services/preferences_service.dart';
import '../../../../core/theme/app_theme.dart';
import '../../pose_detection/presentation/widgets/pose_overlay_painter.dart';
import '../../pose_detection/services/pose_detector_service.dart';
import '../../pose_detection/utils/camera_image_converter.dart';
import '../../pose_library/models/target_pose.dart';
import '../../pose_library/presentation/pose_library_screen.dart';
import '../../pose_library/presentation/widgets/target_pose_stencil_painter.dart';
import '../../suggestion_engine/services/directional_suggestion_engine.dart';
import '../../suggestion_engine/services/pose_comparison_engine.dart';
import '../../suggestion_engine/services/tts_suggestion_service.dart';
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
  bool get canToggleLens => _availableCameras.length > 1;
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

  // Suggestion Engine & Good Pose Trigger Integration
  final PoseComparisonEngine _comparisonEngine = PoseComparisonEngine();
  final DirectionalSuggestionEngine _directionalEngine = DirectionalSuggestionEngine();
  final TtsSuggestionService _ttsService = TtsSuggestionService();
  final PreferencesService _preferencesService = PreferencesService();

  double _matchScore = 0.0;
  String _suggestionText = 'Align your posture with the target stencil.';
  bool _isVoiceMuted = false;
  bool _isGoodPoseTriggered = false;
  String? _fallbackWarningMessage; // Item 22 Fallback Warning Message

  // Phase 7 Auto-Capture Countdown Lock State
  Timer? _autoCaptureTimer;
  int _autoCaptureSeconds = 2;
  bool _hasAutoCapturedForCurrentPose = false;

  // Persisted Stencil Color Toggle
  Color _stencilColor = AppTheme.primaryCyan;
  final List<Color> _stencilColorOptions = const [
    AppTheme.primaryCyan,
    Colors.white,
    Colors.black87,
    AppTheme.accentViolet,
  ];
  int _stencilColorIndex = 0;

  static const double goodPoseThreshold = 80.0;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
    _loadPreferences();
    _checkPermissionAndInit();
  }

  Future<void> _loadPreferences() async {
    final color = await _preferencesService.getStencilColor();
    final voiceEnabled = await _preferencesService.getVoiceEnabled();
    await _ttsService.initialize(voiceOnByDefault: voiceEnabled);

    if (mounted) {
      setState(() {
        _stencilColor = color;
        _isVoiceMuted = !_ttsService.isMuted ? false : !voiceEnabled;
      });
    }
  }

  Future<void> _cycleStencilColor() async {
    final nextIndex = (_stencilColorIndex + 1) % _stencilColorOptions.length;
    final newColor = _stencilColorOptions[nextIndex];
    setState(() {
      _stencilColorIndex = nextIndex;
      _stencilColor = newColor;
    });
    await _preferencesService.saveStencilColor(newColor);
  }

  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
    _autoCaptureTimer?.cancel();
    _disposeCameraController();
    _streamPoseDetector.close();
    _ttsService.stop();
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
      _ttsService.stop();
      _cancelAutoCaptureTimer();
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
        _cameraError = 'Camera Hardware Error: ${e.description ?? e.code}';
      });
    } catch (e) {
      setState(() {
        _cameraError = 'Failed to load camera hardware: $e';
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
          _cameraError = 'Failed to start camera hardware: ${e.description ?? e.code}';
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
        
        double score = 0.0;
        String suggestion = 'Align your posture with the target stencil.';
        bool isGoodPose = false;
        String? warning;

        // Phase 8 Error Handling: Handle No-Person-Detected & Low Lighting / Keypoint Confidence
        if (poses.isEmpty) {
          suggestion = 'No person detected in camera view. Step into frame.';
          warning = 'No person detected';
          _cancelAutoCaptureTimer();
        } else if (widget.selectedTargetPose != null) {
          final livePose = poses.first;
          
          // Check average landmark likelihood (lighting / occlusion check)
          final landmarks = livePose.landmarks.values;
          if (landmarks.isNotEmpty) {
            final avgLikelihood = landmarks.fold<double>(0.0, (sum, l) => sum + l.likelihood) / landmarks.length;
            if (avgLikelihood < 0.6) {
              warning = 'Low lighting or poor visibility detected';
            }
          }

          final deltas = _comparisonEngine.comparePoses(
            livePose: livePose,
            targetPose: widget.selectedTargetPose!,
          );
          score = _comparisonEngine.calculateMatchScore(deltas);
          final suggestionsList = _directionalEngine.generateSuggestions(deltas);
          suggestion = suggestionsList.first;

          isGoodPose = score >= goodPoseThreshold;
          if (isGoodPose) {
            suggestion = 'Perfect pose! Hold still for auto-capture...';
            _triggerAutoCaptureCountdown();
          } else {
            _cancelAutoCaptureTimer();
          }

          _ttsService.speakSuggestion(suggestion);
        }

        if (mounted) {
          setState(() {
            _livePoses = poses;
            _matchScore = score;
            _suggestionText = suggestion;
            _isGoodPoseTriggered = isGoodPose;
            _fallbackWarningMessage = warning;
          });
        }
      }
    } catch (e) {
      // Handle processing anomalies
    } finally {
      _isStreamDetecting = false;
    }
  }

  void _triggerAutoCaptureCountdown() {
    if (_autoCaptureTimer != null || _hasAutoCapturedForCurrentPose || _isCapturing) {
      return;
    }

    setState(() {
      _autoCaptureSeconds = 2;
    });

    _autoCaptureTimer = Timer.periodic(const Duration(seconds: 1), (timer) {
      if (!mounted) {
        timer.cancel();
        return;
      }

      if (_autoCaptureSeconds > 1) {
        setState(() {
          _autoCaptureSeconds--;
        });
      } else {
        timer.cancel();
        _autoCaptureTimer = null;
        _hasAutoCapturedForCurrentPose = true;
        _takePicture();
      }
    });
  }

  void _cancelAutoCaptureTimer() {
    if (_autoCaptureTimer != null) {
      _autoCaptureTimer?.cancel();
      _autoCaptureTimer = null;
      if (mounted) {
        setState(() {
          _autoCaptureSeconds = 2;
        });
      }
    }
  }

  Future<void> _toggleCameraLens() async {
    if (_availableCameras.length <= 1 || _isCameraInitializing) return;

    final nextIndex = (_selectedCameraIndex + 1) % _availableCameras.length;
    setState(() {
      _selectedCameraIndex = nextIndex;
      _isCameraInitializing = true;
      _livePoses = [];
      _hasAutoCapturedForCurrentPose = false;
    });
    _cancelAutoCaptureTimer();

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

  Future<void> _toggleVoiceMute() async {
    final newMuteState = !_isVoiceMuted;
    setState(() {
      _isVoiceMuted = newMuteState;
      _ttsService.setMuted(newMuteState);
    });
    await _preferencesService.saveVoiceEnabled(!newMuteState);
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
              setState(() {
                _hasAutoCapturedForCurrentPose = false;
              });
              _cancelAutoCaptureTimer();
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

      final targetName = widget.selectedTargetPose?.name ?? 'General Pose';

      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          duration: const Duration(seconds: 4),
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
                      'Target: "$targetName" • Match: ${_matchScore.toInt()}%',
                      style: TextStyle(
                        color: _isGoodPoseTriggered ? AppTheme.successGreen : AppTheme.primaryCyan,
                        fontSize: 12,
                        fontWeight: FontWeight.w600,
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
          IconButton(
            icon: Icon(Icons.palette_outlined, color: _stencilColor),
            onPressed: _cycleStencilColor,
            tooltip: 'Cycle Stencil Color',
          ),
          IconButton(
            icon: Icon(
              _isVoiceMuted ? Icons.volume_off : Icons.volume_up,
              color: _isVoiceMuted ? AppTheme.warningAmber : AppTheme.primaryCyan,
            ),
            onPressed: _toggleVoiceMute,
            tooltip: _isVoiceMuted ? 'Unmute Voice Guidance' : 'Mute Voice Guidance',
          ),
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
    final previewSize = _cameraController!.value.previewSize;
    final activePose = widget.selectedTargetPose;

    final scoreInt = _matchScore.toInt();
    final scoreColor = _isGoodPoseTriggered
        ? AppTheme.successGreen
        : scoreInt >= 60
            ? AppTheme.primaryCyan
            : AppTheme.warningAmber;

    return Column(
      children: [
        Expanded(
          child: AnimatedContainer(
            duration: const Duration(milliseconds: 300),
            margin: const EdgeInsets.all(16),
            decoration: BoxDecoration(
              color: Colors.black,
              borderRadius: BorderRadius.circular(24),
              border: Border.all(
                color: scoreColor,
                width: _isGoodPoseTriggered ? 3.5 : 1.8,
              ),
              boxShadow: [
                BoxShadow(
                  color: _isGoodPoseTriggered ? AppTheme.successGreen.withOpacity(0.5) : Colors.black.withOpacity(0.4),
                  blurRadius: _isGoodPoseTriggered ? 24 : 16,
                  offset: const Offset(0, 6),
                ),
              ],
            ),
            child: ClipRRect(
              borderRadius: BorderRadius.circular(22),
              child: Stack(
                fit: StackFit.expand,
                children: [
                  // Camera Preview
                  Center(
                    child: CameraPreview(_cameraController!),
                  ),

                  // Target Pose Silhouette Stencil Overlay
                  if (activePose != null)
                    Positioned.fill(
                      child: CustomPaint(
                        painter: TargetPoseStencilPainter(
                          targetPose: activePose,
                          stencilColor: _isGoodPoseTriggered
                              ? AppTheme.successGreen.withOpacity(0.8)
                              : _stencilColor.withOpacity(0.65),
                          lensDirection: currentCamera.lensDirection,
                        ),
                      ),
                    ),

                  // Real-time Live User Skeleton Overlay
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

                  // Phase 8 Fallback Warning Message Banner (Item 22)
                  if (_fallbackWarningMessage != null && _autoCaptureTimer == null)
                    Positioned(
                      bottom: 16,
                      left: 16,
                      right: 16,
                      child: Container(
                        padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
                        decoration: BoxDecoration(
                          color: AppTheme.warningAmber.withOpacity(0.9),
                          borderRadius: BorderRadius.circular(12),
                        ),
                        child: Row(
                          children: [
                            const Icon(Icons.warning_amber_rounded, color: Colors.black, size: 18),
                            const SizedBox(width: 8),
                            Expanded(
                              child: Text(
                                _fallbackWarningMessage!,
                                style: const TextStyle(
                                  color: Colors.black,
                                  fontSize: 12,
                                  fontWeight: FontWeight.bold,
                                ),
                              ),
                            ),
                          ],
                        ),
                      ),
                    ),

                  // Auto-Capture Countdown Lock Badge Overlay
                  if (_autoCaptureTimer != null)
                    Center(
                      child: Container(
                        padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 16),
                        decoration: BoxDecoration(
                          color: Colors.black.withOpacity(0.85),
                          borderRadius: BorderRadius.circular(24),
                          border: Border.all(color: AppTheme.successGreen, width: 2),
                          boxShadow: [
                            BoxShadow(
                              color: AppTheme.successGreen.withOpacity(0.4),
                              blurRadius: 20,
                            ),
                          ],
                        ),
                        child: Column(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            const Icon(Icons.camera_alt, color: AppTheme.successGreen, size: 36),
                            const SizedBox(height: 8),
                            Text(
                              'Auto-Capturing in $_autoCaptureSeconds',
                              style: const TextStyle(
                                color: Colors.white,
                                fontSize: 18,
                                fontWeight: FontWeight.bold,
                              ),
                            ),
                            const SizedBox(height: 4),
                            const Text(
                              'Hold pose steady!',
                              style: TextStyle(
                                color: AppTheme.successGreen,
                                fontSize: 12,
                                fontWeight: FontWeight.w600,
                              ),
                            ),
                          ],
                        ),
                      ),
                    ),

                  // TOP HUD BANNER
                  Positioned(
                    top: 12,
                    left: 12,
                    right: 12,
                    child: AnimatedContainer(
                      duration: const Duration(milliseconds: 250),
                      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
                      decoration: BoxDecoration(
                        color: Colors.black.withOpacity(0.85),
                        borderRadius: BorderRadius.circular(16),
                        border: Border.all(color: scoreColor.withOpacity(0.8), width: _isGoodPoseTriggered ? 2 : 1),
                      ),
                      child: Row(
                        children: [
                          Container(
                            padding: const EdgeInsets.all(8),
                            decoration: BoxDecoration(
                              color: scoreColor.withOpacity(0.2),
                              shape: BoxShape.circle,
                              border: Border.all(color: scoreColor, width: 1.5),
                            ),
                            child: Row(
                              mainAxisSize: MainAxisSize.min,
                              children: [
                                if (_isGoodPoseTriggered) ...[
                                  const Icon(Icons.check, color: AppTheme.successGreen, size: 14),
                                  const SizedBox(width: 2),
                                ],
                                Text(
                                  '$scoreInt%',
                                  style: TextStyle(
                                    color: scoreColor,
                                    fontSize: 13,
                                    fontWeight: FontWeight.bold,
                                  ),
                                ),
                              ],
                            ),
                          ),
                          const SizedBox(width: 12),
                          Expanded(
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              mainAxisSize: MainAxisSize.min,
                              children: [
                                Text(
                                  _suggestionText,
                                  style: TextStyle(
                                    color: _isGoodPoseTriggered ? AppTheme.successGreen : AppTheme.textPrimary,
                                    fontSize: 13,
                                    fontWeight: FontWeight.bold,
                                  ),
                                  maxLines: 2,
                                  overflow: TextOverflow.ellipsis,
                                ),
                                const SizedBox(height: 2),
                                Text(
                                  activePose != null ? 'Target: ${activePose.name}' : 'Select a target pose',
                                  style: const TextStyle(
                                    color: AppTheme.textSecondary,
                                    fontSize: 11,
                                  ),
                                ),
                              ],
                            ),
                          ),
                          IconButton(
                            icon: Icon(
                              _isVoiceMuted ? Icons.volume_off : Icons.volume_up,
                              size: 20,
                              color: _isVoiceMuted ? AppTheme.textSecondary : AppTheme.primaryCyan,
                            ),
                            onPressed: _toggleVoiceMute,
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
                child: AnimatedContainer(
                  duration: const Duration(milliseconds: 200),
                  width: 76,
                  height: 76,
                  decoration: BoxDecoration(
                    shape: BoxShape.circle,
                    border: Border.all(
                      color: _isGoodPoseTriggered ? AppTheme.successGreen : Colors.white,
                      width: 4,
                    ),
                    boxShadow: _isGoodPoseTriggered
                        ? [
                            BoxShadow(
                              color: AppTheme.successGreen.withOpacity(0.6),
                              blurRadius: 16,
                              spreadRadius: 2,
                            ),
                          ]
                        : [],
                  ),
                  child: Center(
                    child: AnimatedContainer(
                      duration: const Duration(milliseconds: 150),
                      width: _isCapturing ? 48 : 62,
                      height: _isCapturing ? 48 : 62,
                      decoration: BoxDecoration(
                        shape: BoxShape.circle,
                        color: _isCapturing
                            ? AppTheme.accentViolet
                            : _isGoodPoseTriggered
                                ? AppTheme.successGreen
                                : AppTheme.primaryCyan,
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
