import 'package:flutter_test/flutter_test.dart';
import 'package:google_mlkit_pose_detection/google_mlkit_pose_detection.dart';
import 'package:pose_suggestion_app/features/pose_recommendation/services/context_frame_scheduler.dart';
import 'package:pose_suggestion_app/features/pose_recommendation/services/pose_recommendation_service.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  group('ContextFrameScheduler Tests', () {
    late PoseRecommendationService recommender;
    late ContextFrameScheduler scheduler;

    setUp(() {
      recommender = PoseRecommendationService();
      scheduler = ContextFrameScheduler(recommender: recommender);
    });

    test('Initializes with default 80-d context vector', () {
      expect(scheduler.currentContextVector.length, equals(80));
      expect(scheduler.detectedPeopleCount, equals(1));
      expect(scheduler.currentStance, equals(StanceType.standing));
    });

    test('Fast pipeline updates detected people count and reflects in context', () {
      final dummyLandmarks = {
        PoseLandmarkType.nose: PoseLandmark(type: PoseLandmarkType.nose, x: 0.5, y: 0.2, z: 0.0, likelihood: 0.9),
      };

      final pose1 = Pose(landmarks: dummyLandmarks);
      final pose2 = Pose(landmarks: dummyLandmarks);

      scheduler.onFramePoses([pose1, pose2], isFrontCamera: true);

      expect(scheduler.detectedPeopleCount, equals(2));
      expect(scheduler.currentContextVector[75], equals(1.0)); // Duo / Couple one-hot index
    });

    test('Slow pipeline updates scene embedding and prop index', () {
      final newScene = List.filled(64, 0.42);
      scheduler.updateSceneAndProps(sceneVector: newScene, propIndex: 5);

      expect(scheduler.detectedPropIndex, equals(5));
      expect(scheduler.sceneVector[0], equals(0.42));
      expect(scheduler.currentContextVector[64 + 5], equals(1.0)); // Prop index 5 one-hot
    });
  });
}

