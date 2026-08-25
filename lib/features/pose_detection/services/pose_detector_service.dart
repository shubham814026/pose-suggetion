import 'package:flutter/foundation.dart';
import 'package:google_mlkit_pose_detection/google_mlkit_pose_detection.dart';

class PoseDetectorService {
  late final PoseDetector _poseDetector;
  bool _isClosed = false;

  PoseDetectorService() {
    final options = PoseDetectorOptions(
      model: PoseDetectionModel.base,
      mode: PoseDetectionMode.stream,
    );
    _poseDetector = PoseDetector(options: options);
  }

  Future<List<Pose>> processImage(InputImage inputImage) async {
    if (_isClosed) return [];
    try {
      final poses = await _poseDetector.processImage(inputImage);
      return poses;
    } catch (e, stack) {
      debugPrint('MLKit PoseDetector error: $e\n$stack');
      return [];
    }
  }

  Future<void> dispose() async {
    _isClosed = true;
    await _poseDetector.close();
  }
}
