import 'dart:io';
import 'dart:math' as math;
import 'package:flutter/foundation.dart';
import 'package:google_mlkit_pose_detection/google_mlkit_pose_detection.dart';
import '../../pose_detection/services/pose_detector_service.dart';
import '../../pose_library/data/models/target_pose.dart';
import '../../pose_library/services/pose_library_service.dart';
import '../../pose_recommendation/services/context_frame_scheduler.dart';
import '../../pose_recommendation/services/pose_recommendation_service.dart';
import '../models/photo_analysis_result.dart';

/// On-Device Image Analyzer for lighting, time of day, environment scenes,
/// people count, posture inference, and 100% dynamic AI neural pose generation.
class PhotoContextAnalyzer {
  final PoseDetectorService _poseDetectorService;
  final PoseRecommendationService _recommender;

  PhotoContextAnalyzer({
    PoseDetectorService? poseDetectorService,
    PoseRecommendationService? recommender,
  })  : _poseDetectorService = poseDetectorService ??
            PoseDetectorService(
              model: PoseDetectionModel.accurate,
              mode: PoseDetectionMode.single,
            ),
        _recommender = recommender ?? PoseRecommendationService();

  /// Analyzes a photo snapshot to extract multi-modal context and synthesize dynamic AI poses.
  Future<PhotoAnalysisResult> analyzePhoto({
    required String imagePath,
    required PoseLibraryService poseLibrary,
    bool isFrontCamera = false,
  }) async {
    final file = File(imagePath);
    if (!await file.exists()) {
      throw Exception('Photo file does not exist at $imagePath');
    }

    final Uint8List imageBytes = await file.readAsBytes();

    // Guarantee neural weights are loaded into memory
    if (!_recommender.isInitialized) {
      await _recommender.initialize();
    }

    // 1. Analyze Visual Lighting & Time of Day / Environment Colors
    final visualMetrics = _analyzeVisualColors(imageBytes);

    // 2. Run High-Accuracy Pose Detection on static image
    List<Pose> detectedPoses = [];
    try {
      final inputImage = InputImage.fromFilePath(imagePath);
      detectedPoses = await _poseDetectorService.processImage(inputImage);
    } catch (e) {
      debugPrint('Pose detection on static photo error (non-fatal): $e');
    }

    // Exact Detected Person Count (0 if empty scene, 1 for solo, 2 for duo, etc.)
    final int peopleCount = detectedPoses.length;

    // 3. Stance Detection from detected keypoints
    final StanceType stanceType = _inferStance(detectedPoses);

    // 4. Derive Lighting and Scene Classifications
    final lighting = _classifyLighting(visualMetrics);
    final scene = _classifyScene(visualMetrics, peopleCount);
    final occasionVibe = _inferOccasionVibe(lighting, scene, peopleCount, stanceType);

    // 5. Synthesize 64-d Scene Embedding Vector
    final List<double> sceneVector = _buildSceneVector(visualMetrics, scene, lighting);

    // 6. Build Full 80-d Conditioning Vector for ContextPoseNet
    final int propIndex = _inferPropIndex(scene);
    final List<double> contextVector = _recommender.buildContextVector(
      sceneVector: sceneVector,
      propIndex: propIndex,
      peopleCount: math.max(1, peopleCount),
      isFrontCamera: isFrontCamera,
    );

    // 7. Dynamically Synthesize 5 Diverse Contextual AI Poses via Neural Forward Inference
    final List<TargetPose> dynamicAIPoses = _recommender.generateDynamicPoseRecommendations(
      baseContextVector: contextVector,
      sceneName: scene.$2,
      lightingName: lighting.$2,
      peopleCount: peopleCount,
      count: 5,
    );

    return PhotoAnalysisResult(
      imagePath: imagePath,
      lightingType: lighting.$1,
      lightingName: lighting.$2,
      lightingEmoji: lighting.$3,
      sceneType: scene.$1,
      sceneName: scene.$2,
      sceneEmoji: scene.$3,
      peopleCount: peopleCount,
      stanceType: stanceType,
      occasionVibe: occasionVibe,
      detectedPoses: detectedPoses,
      contextVector: contextVector,
      sceneVector: sceneVector,
      aiSynthesizedPose: dynamicAIPoses.isNotEmpty ? dynamicAIPoses.first : null,
      recommendedPoses: dynamicAIPoses,
      averageLuminance: visualMetrics.avgLuminance,
      colorTemperatureK: visualMetrics.estimatedKelvin,
    );
  }

  /// Extracts color luminance, RGB ratios, saturation and chromatic distribution.
  _VisualColorMetrics _analyzeVisualColors(Uint8List bytes) {
    if (bytes.length < 54) {
      return _VisualColorMetrics.defaults();
    }

    double totalR = 0;
    double totalG = 0;
    double totalB = 0;
    double totalLum = 0;
    double totalSat = 0;
    int samples = 0;

    // Subsample bytes to ensure fast execution (< 15ms) even on large 12MP photos
    final int step = math.max(1, (bytes.length ~/ 8000));
    final int end = bytes.length - 3;

    for (int i = 0; i < end; i += step) {
      final int b = bytes[i];
      final int g = bytes[i + 1];
      final int r = bytes[i + 2];

      final double lum = (0.299 * r) + (0.587 * g) + (0.114 * b);
      final double maxC = math.max(r, math.max(g, b)).toDouble();
      final double minC = math.min(r, math.min(g, b)).toDouble();
      final double sat = maxC > 0 ? (maxC - minC) / maxC : 0.0;

      totalR += r;
      totalG += g;
      totalB += b;
      totalLum += lum;
      totalSat += sat;
      samples++;
    }

    if (samples == 0) return _VisualColorMetrics.defaults();

    final double avgR = totalR / samples;
    final double avgG = totalG / samples;
    final double avgB = totalB / samples;
    final double avgLum = totalLum / samples;
    final double avgSat = totalSat / samples;

    // Calculate estimated color temperature (Kelvin)
    double kelvin = 5500.0;
    if (avgB > 0) {
      final double rbRatio = avgR / avgB;
      if (rbRatio > 1.45) {
        kelvin = 2800.0 + (1.45 / rbRatio) * 1200.0; // Warm amber (Sunset/Golden Hour/Candle)
      } else if (rbRatio < 0.78) {
        kelvin = 7200.0 + (1.0 - rbRatio) * 2800.0; // Cool blue (Dusk/Overcast)
      } else {
        kelvin = 5000.0 + (1.0 - (rbRatio - 1.0)) * 1000.0; // Daylight
      }
    }

    return _VisualColorMetrics(
      avgR: avgR,
      avgG: avgG,
      avgB: avgB,
      avgLuminance: avgLum,
      avgSaturation: avgSat,
      estimatedKelvin: kelvin.clamp(2500.0, 10000.0),
    );
  }

  /// Classifies lighting condition & time of day based on chromaticity & luminance
  (LightingType, String, String) _classifyLighting(_VisualColorMetrics metrics) {
    final lum = metrics.avgLuminance;
    final kelvin = metrics.estimatedKelvin;
    final r = metrics.avgR;
    final b = metrics.avgB;
    final sat = metrics.avgSaturation;

    // 1. Extreme Low-Light & Moody Night
    if (lum < 50.0) {
      if (sat > 0.45) {
        return (LightingType.nightNeonCity, 'Neon & Moody Night City', '🌃');
      }
      return (LightingType.nightLowLight, 'Low-Light & Moody Night', '🌙');
    }

    // 2. Warm Sunset / Golden Hour (Kelvin < 4200K, high red)
    if (kelvin < 4100.0 && r > b * 1.28) {
      if (lum < 95.0) {
        return (LightingType.warmIndoorCandle, 'Warm Ambient & Candlelight', '🕯️');
      }
      return (LightingType.goldenHourSunset, 'Golden Hour & Sunset Glow', '🌅');
    }

    // 3. Dawn / Sunrise Morning
    if (lum >= 65.0 && lum <= 125.0 && kelvin < 4800.0 && r > b * 1.15) {
      return (LightingType.sunriseDawn, 'Sunrise & Morning Dawn', '🌄');
    }

    // 4. Dusk / Blue Hour (Cool tones, Kelvin > 7000K)
    if (kelvin > 7000.0 && b > r * 1.15) {
      if (lum < 85.0) {
        return (LightingType.duskBlueHour, 'Dusk & Blue Hour Sky', '🌆');
      }
      return (LightingType.overcastSoft, 'Overcast & Soft Diffused Sky', '☁️');
    }

    // 5. Studio & Direct Daylight
    if (lum > 140.0) {
      if (sat < 0.18) {
        return (LightingType.studioBright, 'Studio High-Key Bright', '💡');
      }
      return (LightingType.daylight, 'Direct Natural Daylight', '☀️');
    }

    if (sat < 0.22 && lum > 100.0) {
      return (LightingType.overcastSoft, 'Soft Natural Ambient', '⛅');
    }

    return (LightingType.daylight, 'Natural Daylight', '☀️');
  }

  /// Classifies background environment scene across diverse categories
  (SceneType, String, String) _classifyScene(_VisualColorMetrics metrics, int peopleCount) {
    final r = metrics.avgR;
    final g = metrics.avgG;
    final b = metrics.avgB;
    final lum = metrics.avgLuminance;
    final sat = metrics.avgSaturation;

    // Nature / Forest / Garden (Green dominance)
    if (g > r * 1.12 && g > b * 1.10) {
      if (lum > 130.0 && sat > 0.40) {
        return (SceneType.gardenFloral, 'Garden & Floral Landscape', '🌸');
      }
      return (SceneType.naturePark, 'Nature, Forest & Park', '🌲');
    }

    // Beach / Coastal / Poolside (Blue dominance + High luminance)
    if (b > r * 1.15 && lum > 115.0) {
      if (sat > 0.35 && lum > 135.0) {
        return (SceneType.poolsideResort, 'Poolside & Resort', '🏊');
      }
      if (metrics.estimatedKelvin < 6500.0) {
        return (SceneType.beach, 'Beach & Coastal Shoreline', '🏖️');
      }
      return (SceneType.mountainScenic, 'Mountain & Panoramic Vista', '⛰️');
    }

    // Cafe & Restaurant / Dining (Warm ambient, medium luminance)
    if (r > b * 1.25 && lum >= 60.0 && lum <= 140.0) {
      if (lum < 95.0) {
        return (SceneType.indoorLiving, 'Cozy Living & Interior', '🛋️');
      }
      return (SceneType.cafeRestaurant, 'Cafe, Dining & Coffee Vibe', '☕');
    }

    // Studio Minimal / Museum (Neutral grayscale, low saturation)
    if (sat < 0.16) {
      if (lum > 140.0) {
        return (SceneType.studioMinimal, 'Minimalist Studio / Clean Wall', '🏛️');
      } else if (lum > 90.0) {
        return (SceneType.museumGallery, 'Museum & Modern Architecture', '🎨');
      } else {
        return (SceneType.officeWorkspace, 'Modern Workspace & Office', '💼');
      }
    }

    // Rooftop / City Skyline
    if (lum > 120.0 && b > r * 1.05) {
      return (SceneType.rooftopSkyline, 'Rooftop & City Skyline', '🏙️');
    }

    // Urban Street default
    return (SceneType.urbanCity, 'Urban Street & City Architecture', '🌆');
  }

  /// Derives posture stance from detected ML Kit pose keypoints
  StanceType _inferStance(List<Pose> poses) {
    if (poses.isEmpty) return StanceType.standing;

    try {
      final pose = poses.first;
      final hip = pose.landmarks[PoseLandmarkType.leftHip] ?? pose.landmarks[PoseLandmarkType.rightHip];
      final knee = pose.landmarks[PoseLandmarkType.leftKnee] ?? pose.landmarks[PoseLandmarkType.rightKnee];
      final ankle = pose.landmarks[PoseLandmarkType.leftAnkle] ?? pose.landmarks[PoseLandmarkType.rightAnkle];

      if (hip != null && knee != null && ankle != null) {
        final double thighDy = (knee.y - hip.y).abs();
        final double shinDy = (ankle.y - knee.y).abs();

        if (thighDy < shinDy * 0.65) {
          return StanceType.sitting;
        }
      }
    } catch (_) {}

    return StanceType.standing;
  }

  /// Builds natural language occasion vibe description
  String _inferOccasionVibe(
    (LightingType, String, String) lighting,
    (SceneType, String, String) scene,
    int peopleCount,
    StanceType stance,
  ) {
    if (peopleCount == 0) {
      if (lighting.$1 == LightingType.goldenHourSunset) {
        return 'Empty Sunset Scene (Ready for Subject)';
      }
      return 'Scenic ${scene.$2} (Step in to Pose)';
    } else if (peopleCount == 1) {
      if (lighting.$1 == LightingType.goldenHourSunset) {
        return 'Aesthetic Sunset Solo Portrait';
      } else if (scene.$1 == SceneType.cafeRestaurant) {
        return 'Cozy Lifestyle & Coffee Break';
      } else if (scene.$1 == SceneType.naturePark || scene.$1 == SceneType.beach) {
        return 'Travel Explorer & Outdoor Vibe';
      } else if (stance == StanceType.sitting) {
        return 'Relaxed Seated Editorial';
      }
      return 'Modern Solo Fashion & Casual';
    } else if (peopleCount == 2) {
      if (lighting.$1 == LightingType.goldenHourSunset || scene.$1 == SceneType.cafeRestaurant) {
        return 'Romantic Couple & Golden Hour Date';
      }
      return 'Duo & Best Friends Aesthetic';
    } else {
      return 'Vibrant Friends & Group Celebration ($peopleCount People)';
    }
  }

  /// Synthesizes 64-d Scene Embedding Vector representing the environment
  List<double> _buildSceneVector(
    _VisualColorMetrics metrics,
    (SceneType, String, String) scene,
    (LightingType, String, String) lighting,
  ) {
    final vector = List<double>.filled(64, 0.0);

    // Encode normalized color features
    vector[0] = (metrics.avgR / 255.0) * 2.0 - 1.0;
    vector[1] = (metrics.avgG / 255.0) * 2.0 - 1.0;
    vector[2] = (metrics.avgB / 255.0) * 2.0 - 1.0;
    vector[3] = (metrics.avgLuminance / 255.0) * 2.0 - 1.0;
    vector[4] = ((metrics.estimatedKelvin - 5500.0) / 4500.0).clamp(-1.0, 1.0);
    vector[5] = (metrics.avgSaturation * 2.0) - 1.0;

    // Encode scene one-hot basis in dims 10..26
    final sceneIndex = scene.$1.index;
    if (sceneIndex < 17) {
      vector[10 + sceneIndex] = 1.0;
    }

    // Encode lighting one-hot basis in dims 28..37
    final lightingIndex = lighting.$1.index;
    if (lightingIndex < 10) {
      vector[28 + lightingIndex] = 1.0;
    }

    // Fill harmonic contextual basis for cosine similarity matching
    for (int i = 38; i < 64; i++) {
      vector[i] = math.sin((i + sceneIndex * 3 + lightingIndex * 5) * 0.45) * 0.35;
    }

    return vector;
  }

  int _inferPropIndex((SceneType, String, String) scene) {
    switch (scene.$1) {
      case SceneType.cafeRestaurant:
        return 1; // Coffee cup / table
      case SceneType.beach:
      case SceneType.poolsideResort:
        return 2; // Sunglasses / summer
      case SceneType.gymFitness:
        return 3; // Fitness
      case SceneType.officeWorkspace:
        return 4; // Laptop / book
      default:
        return 0; // None
    }
  }
}

class _VisualColorMetrics {
  final double avgR;
  final double avgG;
  final double avgB;
  final double avgLuminance;
  final double avgSaturation;
  final double estimatedKelvin;

  const _VisualColorMetrics({
    required this.avgR,
    required this.avgG,
    required this.avgB,
    required this.avgLuminance,
    required this.avgSaturation,
    required this.estimatedKelvin,
  });

  factory _VisualColorMetrics.defaults() {
    return const _VisualColorMetrics(
      avgR: 128.0,
      avgG: 128.0,
      avgB: 128.0,
      avgLuminance: 128.0,
      avgSaturation: 0.20,
      estimatedKelvin: 5500.0,
    );
  }
}
