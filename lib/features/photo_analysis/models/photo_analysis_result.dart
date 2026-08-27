import 'package:google_mlkit_pose_detection/google_mlkit_pose_detection.dart';
import '../../pose_library/data/models/target_pose.dart';
import '../../pose_recommendation/services/context_frame_scheduler.dart';

enum LightingType {
  daylight,
  goldenHourSunset,
  sunriseDawn,
  duskBlueHour,
  nightLowLight,
  nightNeonCity,
  studioBright,
  overcastSoft,
  warmIndoorCandle,
  dramaticSpotlight,
}

enum SceneType {
  beach,
  naturePark,
  urbanCity,
  cafeRestaurant,
  mountainScenic,
  gymFitness,
  studioMinimal,
  indoorLiving,
  rooftopSkyline,
  museumGallery,
  gardenFloral,
  poolsideResort,
  templeHeritage,
  officeWorkspace,
  roadtripScenic,
  festivalEvent,
  autumnWinterLandscape,
}

/// Comprehensive multi-modal analysis outcome extracted from a photo snapshot.
class PhotoAnalysisResult {
  final String imagePath;
  final LightingType lightingType;
  final String lightingName;
  final String lightingEmoji;
  final SceneType sceneType;
  final String sceneName;
  final String sceneEmoji;
  final int peopleCount;
  final StanceType stanceType;
  final String occasionVibe;
  final List<Pose> detectedPoses;
  final List<double> contextVector; // 80-d
  final List<double> sceneVector; // 64-d
  final TargetPose? aiSynthesizedPose;
  final List<TargetPose> recommendedPoses; // Top 5
  final double averageLuminance;
  final double colorTemperatureK;

  PhotoAnalysisResult({
    required this.imagePath,
    required this.lightingType,
    required this.lightingName,
    required this.lightingEmoji,
    required this.sceneType,
    required this.sceneName,
    required this.sceneEmoji,
    required this.peopleCount,
    required this.stanceType,
    required this.occasionVibe,
    required this.detectedPoses,
    required this.contextVector,
    required this.sceneVector,
    this.aiSynthesizedPose,
    required this.recommendedPoses,
    required this.averageLuminance,
    required this.colorTemperatureK,
  });
}
