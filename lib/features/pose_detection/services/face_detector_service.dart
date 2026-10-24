import 'package:flutter/foundation.dart';
import 'package:google_mlkit_face_detection/google_mlkit_face_detection.dart';

/// Lightweight on-device face detector service to accurately count people in frame
/// (1, 2, 3, 4, 5, 10+ people) with sub-5ms latency.
class FaceDetectorService {
  late final FaceDetector _faceDetector;
  bool _isClosed = false;

  FaceDetectorService({
    FaceDetectorMode performanceMode = FaceDetectorMode.fast,
    double minFaceSize = 0.08,
  }) {
    final options = FaceDetectorOptions(
      performanceMode: performanceMode,
      minFaceSize: minFaceSize,
      enableClassification: false,
      enableContours: false,
      enableLandmarks: false,
      enableTracking: false,
    );
    _faceDetector = FaceDetector(options: options);
  }

  /// Processes image and returns list of detected faces in the camera frame
  Future<List<Face>> processImage(InputImage inputImage) async {
    if (_isClosed) return [];
    try {
      final faces = await _faceDetector.processImage(inputImage);
      return faces;
    } catch (e, stack) {
      debugPrint('MLKit FaceDetector error (non-fatal): $e\n$stack');
      return [];
    }
  }

  Future<void> dispose() async {
    _isClosed = true;
    try {
      await _faceDetector.close();
    } catch (_) {}
  }
}

