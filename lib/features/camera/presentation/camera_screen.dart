import 'dart:io';
import 'dart:math' as math;
import 'package:camera/camera.dart';
import 'package:flutter/material.dart';
import 'package:google_mlkit_face_detection/google_mlkit_face_detection.dart';
import 'package:google_mlkit_pose_detection/google_mlkit_pose_detection.dart';
import 'package:permission_handler/permission_handler.dart';
import 'package:provider/provider.dart';
import '../../../../core/theme/app_theme.dart';
import '../../photo_analysis/presentation/photo_analysis_screen.dart';
import '../../photo_analysis/services/photo_context_analyzer.dart';
import '../../pose_detection/services/face_detector_service.dart';
import '../../pose_detection/services/pose_detector_service.dart';
import '../../pose_detection/utils/camera_image_converter.dart';
import '../../pose_library/data/models/target_pose.dart';
import '../../pose_library/presentation/widgets/pose_image_view.dart';
import '../../pose_library/presentation/widgets/smart_pose_carousel.dart';
import '../../pose_library/services/pose_library_service.dart';
import '../../pose_recommendation/services/context_frame_scheduler.dart';
import '../../pose_recommendation/services/pose_recommendation_service.dart';
import 'widgets/permission_denied_view.dart';

/// Clean, high-performance Camera Viewfinder.
/// Captures photo snapshots for multi-modal scene, lighting, and context pose suggestions.
class CameraScreen extends StatefulWidget {
  final bool? isPermissionGrantedForTesting;

  const CameraScreen({
    super.key,
    this.isPermissionGrantedForTesting,
  });

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
  late final PoseDetectorService _livePoseDetector;
  late final FaceDetectorService _faceDetectorService;
  bool _isProcessingFrame = false;
  int _lastFrameProcessTimestamp = 0;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
    _livePoseDetector = PoseDetectorService(
      model: PoseDetectionModel.base,
      mode: PoseDetectionMode.stream,
    );
    _faceDetectorService = FaceDetectorService(
      performanceMode: FaceDetectorMode.fast,
      minFaceSize: 0.08,
    );
    if (widget.isPermissionGrantedForTesting == true) {
      _isPermissionGranted = true;
      _isInitializing = false;
    } else {
      _checkPermissionAndInit();
    }
    _autoSelectInitialRecommendedPose();
  }

  void _autoSelectInitialRecommendedPose() {
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!mounted) return;
      final poseLibrary = Provider.of<PoseLibraryService>(context, listen: false);
      final recommender = Provider.of<PoseRecommendationService>(context, listen: false);
      ContextFrameScheduler? scheduler;
      try {
        scheduler = Provider.of<ContextFrameScheduler>(context, listen: false);
      } catch (_) {}

      final int detectedCount = scheduler?.detectedPeopleCount ?? 0;
      // Strict Zero-Person Gate: Never auto-select or recommend poses if 0 people are detected!
      if (detectedCount == 0) return;

      if (poseLibrary.activeTargetPose == null && !poseLibrary.userExplicitlyCleared) {
        if (poseLibrary.allPoses.isNotEmpty) {
          final contextVector = scheduler?.currentContextVector ??
              recommender.buildContextVector(
                sceneVector: scheduler?.sceneVector ?? List.filled(64, 0.0),
                propIndex: scheduler?.detectedPropIndex ?? 4,
                peopleCount: detectedCount,
              );
          final result = recommender.runNeuralRecommendationInference(
            contextVector: contextVector,
            candidatePoses: poseLibrary.allPoses,
            peopleCount: detectedCount,
            detectedStance: scheduler?.currentStance ?? StanceType.standing,
            topK: 1,
          );
          if (result.recommendedPoses.isNotEmpty) {
            poseLibrary.autoSelectRecommendedPose(result.recommendedPoses.first);
            return;
          }
        }
      }
    });
  }

  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
    _stopLiveStream();
    _livePoseDetector.dispose();
    _faceDetectorService.dispose();
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
      _stopLiveStream();
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
      imageFormatGroup: Platform.isAndroid ? ImageFormatGroup.nv21 : ImageFormatGroup.bgra8888,
    );

    await _stopLiveStream();
    await previousController?.dispose();

    try {
      await controller.initialize();
      if (!mounted) return;

      setState(() {
        _controller = controller;
        _selectedCameraIndex = cameraIndex;
        _isInitializing = false;
      });

      // Start real-time live ML frame analysis stream
      await _startLiveStream(controller, camera);
    } on CameraException catch (e) {
      if (!mounted) return;
      setState(() {
        _errorMessage = 'Camera error: ${e.description}';
        _isInitializing = false;
      });
    }
  }

  Future<void> _startLiveStream(CameraController controller, CameraDescription camera) async {
    if (!controller.value.isInitialized || controller.value.isStreamingImages) return;
    final bool isFront = camera.lensDirection == CameraLensDirection.front;
    try {
      await controller.startImageStream((CameraImage image) {
        _processLiveCameraFrame(image, camera, isFront);
      });
    } catch (e) {
      debugPrint('Error starting live camera stream: $e');
    }
  }

  Future<void> _stopLiveStream() async {
    final controller = _controller;
    if (controller != null && controller.value.isInitialized && controller.value.isStreamingImages) {
      try {
        await controller.stopImageStream();
      } catch (e) {
        debugPrint('Error stopping camera image stream: $e');
      }
    }
  }

  void _processLiveCameraFrame(CameraImage image, CameraDescription camera, bool isFront) async {
    final now = DateTime.now().millisecondsSinceEpoch;
    // Throttle to ~250ms (4 FPS) to ensure viewfinder stays 60 FPS smooth
    if (now - _lastFrameProcessTimestamp < 250) return;
    if (_isProcessingFrame || _isAnalyzingPhoto || !mounted) return;
    _isProcessingFrame = true;
    _lastFrameProcessTimestamp = now;

    try {
      final inputImage = CameraImageConverter.inputImageFromCameraImage(
        image: image,
        camera: camera,
      );

      List<Pose> poses = [];
      List<Face> faces = [];
      if (inputImage != null) {
        final results = await Future.wait([
          _livePoseDetector.processImage(inputImage),
          _faceDetectorService.processImage(inputImage),
        ]);
        poses = results[0] as List<Pose>;
        faces = results[1] as List<Face>;
      }

      // Accurately determine people count (0, 1, 2, 3, 4, 5, 10+)
      final int peopleCount = faces.isNotEmpty
          ? faces.length
          : (poses.isNotEmpty ? 1 : 0);

      // Extract real-time 64-d scene embedding vector & prop index directly from camera stream
      final sceneMetrics = _extractLiveSceneMetrics(image);

      if (!mounted) return;
      ContextFrameScheduler? scheduler;
      try {
        scheduler = Provider.of<ContextFrameScheduler>(context, listen: false);
      } catch (_) {}

      if (scheduler != null) {
        scheduler.onFramePoses(poses, isFrontCamera: isFront, peopleCount: peopleCount);
        scheduler.updateSceneAndProps(
          sceneVector: sceneMetrics.vector,
          propIndex: sceneMetrics.propIndex,
        );
      }
    } catch (e) {
      debugPrint('Live frame processing error (non-fatal): $e');
    } finally {
      _isProcessingFrame = false;
    }
  }

  /// Extracts real-time 64-d scene embedding vector & prop index by spatial grid sampling of camera frame
  ({List<double> vector, int propIndex}) _extractLiveSceneMetrics(CameraImage image) {
    final List<double> vector = List.filled(64, 0.0);
    int propIndex = 4; // Default to Home, Cozy & Balcony (4)

    if (image.planes.isEmpty) return (vector: vector, propIndex: propIndex);

    try {
      final plane0 = image.planes[0];
      final bytes0 = plane0.bytes;
      final int bytesPerRow0 = plane0.bytesPerRow;
      final int width = image.width;
      final int height = image.height;

      if (width <= 0 || height <= 0 || bytes0.isEmpty) {
        return (vector: vector, propIndex: propIndex);
      }

      double totalR = 0.0;
      double totalG = 0.0;
      double totalB = 0.0;
      double totalLum = 0.0;
      int sampledCount = 0;

      final bool isAndroid = Platform.isAndroid;
      final bool hasChromaPlanes = image.planes.length >= 2;

      // Sample an 8x8 spatial grid (64 patches) across the frame
      for (int gy = 0; gy < 8; gy++) {
        final int py = ((gy + 0.5) * height / 8.0).toInt().clamp(0, height - 1);
        final int rowOffset0 = py * bytesPerRow0;

        for (int gx = 0; gx < 8; gx++) {
          final int px = ((gx + 0.5) * width / 8.0).toInt().clamp(0, width - 1);
          final int idx = gy * 8 + gx;

          int r = 128;
          int g = 128;
          int b = 128;
          int lumValue = 128;

          if (isAndroid) {
            final int yIdx = rowOffset0 + px;
            if (yIdx < bytes0.length) {
              lumValue = bytes0[yIdx];
            }

            if (hasChromaPlanes) {
              if (image.planes.length >= 3) {
                final planeU = image.planes[1];
                final planeV = image.planes[2];
                final int uRow = (py ~/ 2) * planeU.bytesPerRow;
                final int uPixel = (px ~/ 2) * (planeU.bytesPerPixel ?? 1);
                final int vRow = (py ~/ 2) * planeV.bytesPerRow;
                final int vPixel = (px ~/ 2) * (planeV.bytesPerPixel ?? 1);

                final int uIdx = uRow + uPixel;
                final int vIdx = vRow + vPixel;
                if (uIdx < planeU.bytes.length && vIdx < planeV.bytes.length) {
                  final int uVal = planeU.bytes[uIdx] - 128;
                  final int vVal = planeV.bytes[vIdx] - 128;
                  r = (lumValue + 1.402 * vVal).round().clamp(0, 255);
                  g = (lumValue - 0.344136 * uVal - 0.714136 * vVal).round().clamp(0, 255);
                  b = (lumValue + 1.772 * uVal).round().clamp(0, 255);
                }
              } else if (image.planes.length == 2) {
                // NV21 (plane 1 has VU interleaved)
                final planeVU = image.planes[1];
                final int vuRow = (py ~/ 2) * planeVU.bytesPerRow;
                final int vuCol = (px ~/ 2) * 2;
                final int vIdx = vuRow + vuCol;
                final int uIdx = vIdx + 1;
                if (uIdx < planeVU.bytes.length) {
                  final int vVal = planeVU.bytes[vIdx] - 128;
                  final int uVal = planeVU.bytes[uIdx] - 128;
                  r = (lumValue + 1.402 * vVal).round().clamp(0, 255);
                  g = (lumValue - 0.344136 * uVal - 0.714136 * vVal).round().clamp(0, 255);
                  b = (lumValue + 1.772 * uVal).round().clamp(0, 255);
                }
              }
            } else {
              r = lumValue;
              g = lumValue;
              b = lumValue;
            }
          } else {
            // iOS BGRA8888 (4 bytes per pixel: B, G, R, A)
            final int byteIdx = rowOffset0 + (px * 4);
            if (byteIdx + 2 < bytes0.length) {
              b = bytes0[byteIdx];
              g = bytes0[byteIdx + 1];
              r = bytes0[byteIdx + 2];
              lumValue = (0.299 * r + 0.587 * g + 0.114 * b).toInt();
            }
          }

          final double normalized = (lumValue / 255.0) - 0.5;
          vector[idx] = normalized;

          totalR += r;
          totalG += g;
          totalB += b;
          totalLum += lumValue;
          sampledCount++;
        }
      }

      final double avgLum = sampledCount > 0 ? (totalLum / sampledCount) : 128.0;
      final double avgR = sampledCount > 0 ? (totalR / sampledCount) : 128.0;
      final double avgG = sampledCount > 0 ? (totalG / sampledCount) : 128.0;
      final double avgB = sampledCount > 0 ? (totalB / sampledCount) : 128.0;

      // Extract 64-d Visual Scene Embedding matching ContextPoseRecommenderNet
      final double maxC = math.max(avgR, math.max(avgG, avgB));
      final double minC = math.min(avgR, math.min(avgG, avgB));
      final double sat = maxC > 0 ? ((maxC - minC) / maxC) * 2.0 - 1.0 : 0.0;
      final double kelvinWarmth = ((avgR - avgB) / 128.0).clamp(-1.0, 1.0);
      final double greenDom = ((avgG - (avgR + avgB) * 0.5) / 128.0).clamp(-1.0, 1.0);
      final double blueDom = ((avgB - (avgR + avgG) * 0.5) / 128.0).clamp(-1.0, 1.0);
      final double warmDom = ((avgR - (avgG + avgB) * 0.5) / 128.0).clamp(-1.0, 1.0);

      // Global color & lighting (dims 0..9)
      vector[0] = ((avgR / 255.0) * 2.0 - 1.0).clamp(-1.0, 1.0);
      vector[1] = ((avgG / 255.0) * 2.0 - 1.0).clamp(-1.0, 1.0);
      vector[2] = ((avgB / 255.0) * 2.0 - 1.0).clamp(-1.0, 1.0);
      vector[3] = ((avgLum / 255.0) * 2.0 - 1.0).clamp(-1.0, 1.0);
      vector[4] = (-kelvinWarmth).clamp(-1.0, 1.0);
      vector[5] = sat.clamp(-1.0, 1.0);
      vector[6] = greenDom;
      vector[7] = blueDom;
      vector[8] = warmDom;
      vector[9] = 0.45;

      // 4x4 Spatial Patches (dims 10..25: luminance, 26..41: blue, 42..57: green)
      for (int q = 0; q < 16; q++) {
        final int row = q ~/ 4;
        final double skyBias = row < 2 ? 0.3 : -0.2;
        vector[10 + q] = (vector[3] + skyBias * 0.4 + math.sin(q * 0.5) * 0.15).clamp(-1.0, 1.0);
        vector[26 + q] = (blueDom * (row < 2 ? 0.85 : 0.4) + math.cos(q * 0.4) * 0.1).clamp(-1.0, 1.0);
        vector[42 + q] = (greenDom * (row >= 2 ? 0.85 : 0.3) + math.sin(q * 0.3) * 0.1).clamp(-1.0, 1.0);
      }

      // Edge and texture harmonics (dims 58..63)
      vector[58] = (avgR - avgB).abs() > 35 ? 0.8 : -0.2;
      vector[59] = (avgG - avgR).abs() > 30 ? 0.7 : -0.2;
      vector[60] = sat < 0.2 ? 0.75 : -0.3;
      vector[61] = avgLum < 60.0 ? 0.8 : 0.0;
      vector[62] = greenDom > 0.2 ? 0.7 : -0.2;
      vector[63] = 0.5;

      // L2 normalize
      double normSq = 0.0;
      for (int i = 0; i < 64; i++) {
        normSq += vector[i] * vector[i];
      }
      final double norm = math.sqrt(normSq) + 1e-8;
      for (int i = 0; i < 64; i++) {
        vector[i] /= norm;
      }

      // Infer auxiliary prop index
      if (avgLum < 60.0) {
        propIndex = 6; // Festivals, Parties & Nightlife (Night / Dark)
      } else if (avgG > avgR * 1.15 && avgG > avgB * 1.15) {
        propIndex = 1; // Mountains & Nature Hiking (Greenery)
      } else if (avgB > avgR * 1.35 && avgB > avgG * 1.20 && avgLum > 145.0) {
        propIndex = 0; // Beach & Coastal (Bright daylight + strong ocean/sky blue)
      } else if (avgR > avgB * 1.30 && avgR > avgG * 1.12 && avgLum > 95.0 && avgLum < 185.0) {
        propIndex = 3; // Cafes, Diners & Restaurants (Warm tones)
      } else if (avgLum > 165.0 && (avgR - avgB).abs() < 25 && (avgR - avgG).abs() < 25) {
        propIndex = 2; // Urban Rooftops & Cityscape (Bright architectural daylight)
      } else {
        propIndex = 4; // Home, Cozy & Balcony (Standard indoor room)
      }
    } catch (_) {}

    return (vector: vector, propIndex: propIndex);
  }

  Future<void> _toggleCameraLens() async {
    if (_availableCameras.length < 2) return;
    await _stopLiveStream();
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
      // Android Camera HAL safety: stop image stream before taking still photo
      await _stopLiveStream();

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
        if (_controller != null && _controller!.value.isInitialized && _availableCameras.isNotEmpty) {
          _startLiveStream(_controller!, _availableCameras[_selectedCameraIndex]);
        }
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

  void _showReferenceCoachingModal(BuildContext context, TargetPose pose) {
    showModalBottomSheet(
      context: context,
      backgroundColor: const Color(0xFF0F172A),
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
      ),
      builder: (context) {
        return SafeArea(
          child: Padding(
            padding: const EdgeInsets.all(16),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Center(
                  child: Container(
                    width: 36,
                    height: 4,
                    decoration: BoxDecoration(
                      color: Colors.white24,
                      borderRadius: BorderRadius.circular(2),
                    ),
                  ),
                ),
                const SizedBox(height: 12),
                Row(
                  children: [
                    ClipRRect(
                      borderRadius: BorderRadius.circular(10),
                      child: SizedBox(
                        width: 64,
                        height: 88,
                        child: PoseImageView(pose: pose, fit: BoxFit.cover),
                      ),
                    ),
                    const SizedBox(width: 14),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            pose.name,
                            style: const TextStyle(
                              color: Colors.white,
                              fontSize: 16,
                              fontWeight: FontWeight.bold,
                            ),
                          ),
                          const SizedBox(height: 4),
                          Text(
                            pose.category,
                            style: const TextStyle(
                              color: AppTheme.primaryCyan,
                              fontSize: 12,
                              fontWeight: FontWeight.w600,
                            ),
                          ),
                          const SizedBox(height: 6),
                          Text(
                            pose.description,
                            style: const TextStyle(
                              color: AppTheme.textSecondary,
                              fontSize: 12,
                            ),
                            maxLines: 2,
                            overflow: TextOverflow.ellipsis,
                          ),
                        ],
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 16),
                Row(
                  mainAxisAlignment: MainAxisAlignment.end,
                  children: [
                    TextButton(
                      onPressed: () {
                        Provider.of<PoseLibraryService>(context, listen: false).clearActivePose();
                        Navigator.of(context).pop();
                      },
                      child: const Text('Clear Guide', style: TextStyle(color: Color(0xFFEF4444))),
                    ),
                    const SizedBox(width: 8),
                    ElevatedButton(
                      onPressed: () => Navigator.of(context).pop(),
                      style: ElevatedButton.styleFrom(backgroundColor: AppTheme.primaryCyan),
                      child: const Text('Keep Posing', style: TextStyle(color: Colors.black, fontWeight: FontWeight.bold)),
                    ),
                  ],
                ),
              ],
            ),
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
    final poseLibrary = Provider.of<PoseLibraryService>(context);

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
              )
            else
              Center(
                child: Container(
                  width: double.infinity,
                  height: double.infinity,
                  color: const Color(0xFF090D16),
                  child: Center(
                    child: Column(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        Icon(Icons.camera_alt_outlined, size: 56, color: AppTheme.primaryCyan.withAlpha(120)),
                        const SizedBox(height: 12),
                        const Text(
                          'Viewfinder Simulation Mode',
                          style: TextStyle(color: AppTheme.textPrimary, fontSize: 15, fontWeight: FontWeight.bold),
                        ),
                        const SizedBox(height: 4),
                        Text(
                          _errorMessage ?? 'Camera preview offline.',
                          style: const TextStyle(color: AppTheme.textSecondary, fontSize: 11),
                          textAlign: TextAlign.center,
                        ),
                      ],
                    ),
                  ),
                ),
              ),

            // 2. Active Reference Photo Guide (Floating PiP Card, NO line stencils on camera)
            if (poseLibrary.activeTargetPose != null)
              Positioned(
                top: 68,
                right: 16,
                child: GestureDetector(
                  onTap: () => _showReferenceCoachingModal(context, poseLibrary.activeTargetPose!),
                  child: Container(
                    width: 82,
                    height: 114,
                    decoration: BoxDecoration(
                      color: const Color(0xFF0F172A),
                      borderRadius: BorderRadius.circular(14),
                      border: Border.all(color: AppTheme.primaryCyan, width: 2.0),
                      boxShadow: [
                        BoxShadow(
                          color: Colors.black.withAlpha(160),
                          blurRadius: 10,
                          offset: const Offset(0, 4),
                        ),
                        BoxShadow(
                          color: AppTheme.primaryCyan.withAlpha(80),
                          blurRadius: 8,
                        ),
                      ],
                    ),
                    child: ClipRRect(
                      borderRadius: BorderRadius.circular(12),
                      child: Stack(
                        fit: StackFit.expand,
                        children: [
                          PoseImageView(
                            pose: poseLibrary.activeTargetPose!,
                            fit: BoxFit.cover,
                          ),
                          Container(
                            decoration: const BoxDecoration(
                              gradient: LinearGradient(
                                begin: Alignment.topCenter,
                                end: Alignment.bottomCenter,
                                colors: [
                                  Colors.black54,
                                  Colors.transparent,
                                  Colors.black87,
                                ],
                              ),
                            ),
                          ),
                          Positioned(
                            top: 4,
                            left: 4,
                            child: Container(
                              padding: const EdgeInsets.symmetric(horizontal: 5, vertical: 2),
                              decoration: BoxDecoration(
                                color: AppTheme.primaryCyan,
                                borderRadius: BorderRadius.circular(6),
                              ),
                              child: const Text(
                                'Reference',
                                style: TextStyle(
                                  color: Colors.black,
                                  fontSize: 8.0,
                                  fontWeight: FontWeight.bold,
                                ),
                              ),
                            ),
                          ),
                          Positioned(
                            top: 2,
                            right: 2,
                            child: GestureDetector(
                              onTap: () => poseLibrary.clearActivePose(),
                              child: Container(
                                padding: const EdgeInsets.all(2),
                                decoration: const BoxDecoration(
                                  color: Colors.black87,
                                  shape: BoxShape.circle,
                                ),
                                child: const Icon(Icons.close, color: Colors.white, size: 14),
                              ),
                            ),
                          ),
                          Positioned(
                            bottom: 4,
                            left: 4,
                            right: 4,
                            child: Text(
                              poseLibrary.activeTargetPose!.name,
                              style: const TextStyle(
                                color: Colors.white,
                                fontSize: 8.5,
                                fontWeight: FontWeight.bold,
                              ),
                              maxLines: 1,
                              overflow: TextOverflow.ellipsis,
                            ),
                          ),
                        ],
                      ),
                    ),
                  ),
                ),
              ),

            // 3. Top Header Bar: Camera Switcher, Active Reference Guide Badge
            Positioned(
              top: 16,
              left: 16,
              right: 16,
              child: Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  // Active Reference Guide Indicator + Remove Button
                  if (poseLibrary.activeTargetPose != null)
                    Flexible(
                      child: Row(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          Flexible(
                            child: InkWell(
                              onTap: () => _showReferenceCoachingModal(context, poseLibrary.activeTargetPose!),
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
                                    const Icon(Icons.photo_library_outlined, color: AppTheme.primaryCyan, size: 16),
                                    const SizedBox(width: 6),
                                    Flexible(
                                      child: Text(
                                        'Ref: ${poseLibrary.activeTargetPose!.name}',
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
                                    'Clear',
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
                            'Click Photo to get 3 Suggestions',
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

             // 4.5. Smart Recommended Pose Carousel Tray (Huawei AI Camera style)
            if (!_isAnalyzingPhoto)
              const Positioned(
                bottom: 112,
                left: 0,
                right: 0,
                child: SmartPoseCarousel(),
              ),

            // 5. Bottom Control Deck (Capture Shutter, Last Photo Quick Re-Analyze)
            if (!_isAnalyzingPhoto)
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
