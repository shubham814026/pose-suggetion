import 'package:google_mlkit_pose_detection/google_mlkit_pose_detection.dart';

class PoseDetectorService {
  late final PoseDetector _poseDetector;
  bool _isInitialized = false;

  PoseDetectorService({
    PoseDetectionMode mode = PoseDetectionMode.single,
    PoseDetectionModel model = PoseDetectionModel.base,
  }) {
    _poseDetector = PoseDetector(
      options: PoseDetectorOptions(
        mode: mode,
        model: model,
      ),
    );
    _isInitialized = true;
  }

  /// Process an [InputImage] and return detected poses.
  Future<List<Pose>> processInputImage(InputImage inputImage) async {
    if (!_isInitialized) {
      throw StateError('PoseDetectorService has been closed or not initialized.');
    }
    return await _poseDetector.processImage(inputImage);
  }

  /// Process a static image file at [imagePath] for static image verification.
  Future<List<Pose>> processImageFilePath(String imagePath) async {
    final inputImage = InputImage.fromFilePath(imagePath);
    return await processInputImage(inputImage);
  }

  /// Release detector resources.
  Future<void> close() async {
    if (_isInitialized) {
      _isInitialized = false;
      await _poseDetector.close();
    }
  }
}
