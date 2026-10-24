import 'dart:io';
import 'dart:math' as math;
import 'dart:ui' as ui;
import 'package:flutter/foundation.dart';
import 'package:google_mlkit_pose_detection/google_mlkit_pose_detection.dart';
import '../../pose_detection/services/face_detector_service.dart';
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
  final FaceDetectorService _faceDetectorService;
  final PoseRecommendationService _recommender;

  PhotoContextAnalyzer({
    PoseDetectorService? poseDetectorService,
    FaceDetectorService? faceDetectorService,
    PoseRecommendationService? recommender,
  })  : _poseDetectorService = poseDetectorService ??
            PoseDetectorService(
              model: PoseDetectionModel.accurate,
              mode: PoseDetectionMode.single,
            ),
        _faceDetectorService = faceDetectorService ?? FaceDetectorService(),
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

    // Guarantee reference pose database is loaded into memory
    if (poseLibrary.allPoses.isEmpty) {
      await poseLibrary.loadPoseLibrary();
    }

    // 1. Analyze Visual Lighting & Time of Day / Environment Colors using TRUE decoded pixels
    final visualMetrics = await _analyzeVisualColors(imageBytes);

    // 2. Run High-Accuracy Multi-Person & Pose Detection on static image
    List<Pose> detectedPoses = [];
    int peopleCount = 0;
    try {
      final inputImage = InputImage.fromFilePath(imagePath);
      final faces = await _faceDetectorService.processImage(inputImage);
      detectedPoses = await _poseDetectorService.processImage(inputImage);

      if (faces.isNotEmpty) {
        peopleCount = faces.length;
      } else if (detectedPoses.isNotEmpty) {
        peopleCount = 1;
      } else {
        peopleCount = 0;
      }
    } catch (e) {
      debugPrint('Person detection on photo error (non-fatal): $e');
    }

    // 3. Stance Detection from detected keypoints
    final StanceType stanceType = _inferStance(detectedPoses);

    // 4. Derive Lighting and Scene Classifications
    final lighting = _classifyLighting(visualMetrics);
    final scene = _classifyScene(visualMetrics, peopleCount);
    final occasionVibe = _inferOccasionVibe(lighting, scene, peopleCount, stanceType);

    // 5. Synthesize 64-d Scene Embedding Vector
    final List<double> sceneVector = _buildSceneVector(visualMetrics, scene, lighting);

    // Strict Zero-Person Gate: If 0 people are detected, return empty recommendations
    if (peopleCount == 0) {
      return PhotoAnalysisResult(
        imagePath: imagePath,
        lightingType: lighting.$1,
        lightingName: lighting.$2,
        lightingEmoji: lighting.$3,
        sceneType: scene.$1,
        sceneName: scene.$2,
        sceneEmoji: scene.$3,
        peopleCount: 0,
        stanceType: StanceType.unknown,
        occasionVibe: 'Empty Scene (No Person Detected)',
        detectedPoses: const [],
        contextVector: List.filled(80, 0.0),
        sceneVector: sceneVector,
        aiSynthesizedPose: null,
        recommendedPoses: const [],
        averageLuminance: visualMetrics.avgLuminance,
        colorTemperatureK: visualMetrics.estimatedKelvin,
        predictedCategory: 'No Person Detected',
        categoryProbability: 0.0,
        neuralConfidenceScore: 0.0,
        inferenceTimeMs: 1,
      );
    }

    // 6. Extract keypoint geometry metrics from detected poses
    double shoulderWidthNorm = 0.16;
    double torsoHeightNorm = 0.40;
    bool isLegsVisible = true;
    double kneeAngleNorm = 0.95;
    double hipAngleNorm = 0.95;

    if (detectedPoses.isNotEmpty) {
      final pose = detectedPoses.first;
      final ls = pose.landmarks[PoseLandmarkType.leftShoulder];
      final rs = pose.landmarks[PoseLandmarkType.rightShoulder];
      final lh = pose.landmarks[PoseLandmarkType.leftHip];
      final rh = pose.landmarks[PoseLandmarkType.rightHip];
      final lk = pose.landmarks[PoseLandmarkType.leftKnee];
      final rk = pose.landmarks[PoseLandmarkType.rightKnee];
      final la = pose.landmarks[PoseLandmarkType.leftAnkle];
      final ra = pose.landmarks[PoseLandmarkType.rightAnkle];

      if (ls != null && rs != null) {
        shoulderWidthNorm = (rs.x - ls.x).abs();
      }
      if (ls != null && rs != null && lh != null && rh != null) {
        torsoHeightNorm = (((lh.y + rh.y) / 2.0) - ((ls.y + rs.y) / 2.0)).abs();
      }
      isLegsVisible = (la != null && la.likelihood > 0.4) || (ra != null && ra.likelihood > 0.4);
      if (lh != null && lk != null && la != null) {
        final double kneeAngle = _calculateAngle(lh, lk, la);
        kneeAngleNorm = (kneeAngle / 180.0).clamp(0.0, 1.0);
      } else if (rh != null && rk != null && ra != null) {
        final double kneeAngle = _calculateAngle(rh, rk, ra);
        kneeAngleNorm = (kneeAngle / 180.0).clamp(0.0, 1.0);
      }
      if (ls != null && lh != null && lk != null) {
        final double hipAngle = _calculateAngle(ls, lh, lk);
        hipAngleNorm = (hipAngle / 180.0).clamp(0.0, 1.0);
      }
    }

    final bool isSelfie = isFrontCamera || (shoulderWidthNorm > 0.22 && !isLegsVisible);

    // Build Full 80-d Conditioning Vector for ContextPoseRecommenderNet
    final int propIndex = _inferPropIndex(scene);
    final List<double> contextVector = _recommender.buildContextVector(
      sceneVector: sceneVector,
      propIndex: propIndex,
      peopleCount: peopleCount,
      isFrontCamera: isFrontCamera,
      isSelfieComposition: isSelfie,
      shoulderWidthNorm: shoulderWidthNorm,
      torsoHeightNorm: torsoHeightNorm,
      isSitting: stanceType == StanceType.sitting,
      isStanding: stanceType == StanceType.standing,
      isLegsVisible: isLegsVisible,
      kneeAngleNorm: kneeAngleNorm,
      hipAngleNorm: hipAngleNorm,
    );

    // 7. Execute On-Device Neural Model (ContextPoseRecommenderNet) to predict & rank Top 3 photos
    final candidatePoses = poseLibrary.allPoses.isNotEmpty
        ? poseLibrary.allPoses
        : poseLibrary.filteredPoses;

    final neuralResult = _recommender.runNeuralRecommendationInference(
      contextVector: contextVector,
      candidatePoses: candidatePoses,
      peopleCount: peopleCount,
      detectedStance: stanceType,
      topK: 3,
    );

    List<TargetPose> suggestedPhotos = List.from(neuralResult.recommendedPoses);

    // Fallback if candidate poses are empty and at least 1 person is detected
    if (suggestedPhotos.isEmpty && candidatePoses.isNotEmpty && peopleCount > 0) {
      final filteredCandidates = _recommender.filterPosesByPeopleCount(candidatePoses, peopleCount);
      suggestedPhotos = filteredCandidates.take(3).toList();
      if (suggestedPhotos.isEmpty) {
        suggestedPhotos = _recommender.generateDynamicPoseRecommendations(
          baseContextVector: contextVector,
          sceneName: scene.$2,
          lightingName: lighting.$2,
          peopleCount: peopleCount,
          count: 3,
        );
      }
    }

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
      aiSynthesizedPose: suggestedPhotos.isNotEmpty ? suggestedPhotos.first : null,
      recommendedPoses: suggestedPhotos,
      averageLuminance: visualMetrics.avgLuminance,
      colorTemperatureK: visualMetrics.estimatedKelvin,
      predictedCategory: neuralResult.predictedCategory,
      categoryProbability: neuralResult.categoryProbability,
      neuralConfidenceScore: neuralResult.confidenceScore,
      inferenceTimeMs: neuralResult.inferenceTimeMs,
    );
  }

  /// Extracts color luminance, RGB ratios, saturation and chromatic distribution using decoded RGBA pixels.
  Future<_VisualColorMetrics> _analyzeVisualColors(Uint8List bytes) async {
    if (bytes.length < 54) {
      return _VisualColorMetrics.defaults();
    }

    try {
      final codec = await ui.instantiateImageCodec(bytes, targetWidth: 64, targetHeight: 64);
      final frameInfo = await codec.getNextFrame();
      final image = frameInfo.image;
      final byteData = await image.toByteData(format: ui.ImageByteFormat.rawRgba);
      image.dispose();

      if (byteData == null) return _VisualColorMetrics.defaults();
      final Uint8List pixels = byteData.buffer.asUint8List();

      double totalR = 0, totalG = 0, totalB = 0, totalLum = 0, totalSat = 0;
      int samples = 0;

      for (int i = 0; i < pixels.length - 3; i += 4) {
        final int r = pixels[i];
        final int g = pixels[i + 1];
        final int b = pixels[i + 2];

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

      double kelvin = 5500.0;
      if (avgB > 0) {
        final double rbRatio = avgR / avgB;
        if (rbRatio > 1.30) {
          kelvin = 2800.0 + (1.30 / rbRatio) * 1200.0;
        } else if (rbRatio < 0.85) {
          kelvin = 7200.0 + (1.0 - rbRatio) * 2800.0;
        } else {
          kelvin = 5000.0 + (1.0 - (rbRatio - 1.0)) * 1000.0;
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
    } catch (e) {
      debugPrint('Native image pixel decode notice: $e');
      return _VisualColorMetrics.defaults();
    }
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

    // 1. Extreme Night / Low-light
    if (lum < 55.0) {
      if (sat > 0.40) {
        return (SceneType.festivalEvent, 'Festivals, Parties & Nightlife', '🎉');
      }
      return (SceneType.indoorLiving, 'Home, Cozy & Balcony', '🏡');
    }

    // 2. Nature / Forest / Garden (Green dominance)
    if (g > r * 1.08 && g > b * 1.06 && sat > 0.18) {
      if (lum > 130.0 && sat > 0.35) {
        return (SceneType.gardenFloral, 'Garden & Outdoor Park', '🌸');
      }
      return (SceneType.naturePark, 'Mountains & Nature Hiking', '⛰️');
    }

    // 3. Genuine Beach & Coastal (High Blue dominance + High daylight luminance + Sky/Ocean)
    // Avoid false positives: Must have high blue compared to BOTH red AND green, and bright daylight!
    if (b > r * 1.30 && b > g * 1.15 && lum > 140.0 && sat > 0.28) {
      return (SceneType.beach, 'Beach & Coastal', '🏖️');
    }

    // 4. Warm Indoor / Living Room / Dining / Cafe
    if (r > b * 1.20 && lum >= 55.0 && lum <= 150.0) {
      if (lum < 95.0 || sat < 0.22) {
        return (SceneType.indoorLiving, 'Home, Cozy & Balcony', '🛋️');
      }
      return (SceneType.cafeRestaurant, 'Cafes, Diners & Restaurants', '☕');
    }

    // 5. Studio Minimal / Clean Wall / Office (Low saturation, neutral tones)
    if (sat < 0.18) {
      if (lum > 140.0) {
        return (SceneType.studioMinimal, 'Minimalist Studio / Clean Wall', '🏛️');
      } else if (lum > 85.0) {
        return (SceneType.officeWorkspace, 'Modern Workspace & Office', '💼');
      } else {
        return (SceneType.museumGallery, 'Museum & Modern Architecture', '🎨');
      }
    }

    // 6. Rooftop / City Skyline
    if (lum > 130.0 && b > r * 1.08) {
      return (SceneType.rooftopSkyline, 'Urban Rooftops & Cityscape', '🏙️');
    }

    // 7. General Urban Street Architecture default
    return (SceneType.urbanCity, 'Standing & Streetwear', '👟');
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

  /// Calculates 2D interior joint angle in degrees
  double _calculateAngle(PoseLandmark a, PoseLandmark b, PoseLandmark c) {
    final double radians = math.atan2(c.y - b.y, c.x - b.x) - math.atan2(a.y - b.y, a.x - b.x);
    double angle = (radians * 180.0 / math.pi).abs();
    if (angle > 180.0) {
      angle = 360.0 - angle;
    }
    return angle;
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

  /// Synthesizes continuous 64-d Scene Embedding Vector representing the environment
  List<double> _buildSceneVector(
    _VisualColorMetrics metrics,
    (SceneType, String, String) scene,
    (LightingType, String, String) lighting,
  ) {
    final vector = List<double>.filled(64, 0.0);

    // Global color & lighting (dims 0..9)
    vector[0] = (metrics.avgR / 255.0) * 2.0 - 1.0;
    vector[1] = (metrics.avgG / 255.0) * 2.0 - 1.0;
    vector[2] = (metrics.avgB / 255.0) * 2.0 - 1.0;
    vector[3] = (metrics.avgLuminance / 255.0) * 2.0 - 1.0;
    vector[4] = ((metrics.estimatedKelvin - 5500.0) / 4500.0).clamp(-1.0, 1.0);
    vector[5] = (metrics.avgSaturation * 2.0) - 1.0;
    vector[6] = ((metrics.avgG - (metrics.avgR + metrics.avgB) * 0.5) / 128.0).clamp(-1.0, 1.0);
    vector[7] = ((metrics.avgB - (metrics.avgR + metrics.avgG) * 0.5) / 128.0).clamp(-1.0, 1.0);
    vector[8] = ((metrics.avgR - (metrics.avgG + metrics.avgB) * 0.5) / 128.0).clamp(-1.0, 1.0);
    vector[9] = 0.45;

    final double blueDom = vector[7];
    final double greenDom = vector[6];

    // 4x4 Spatial Quadrants (dims 10..25: luminance, 26..41: blue-vs-red, 42..57: green-vs-red)
    for (int q = 0; q < 16; q++) {
      final int row = q ~/ 4;
      final double skyBias = row < 2 ? 0.3 : -0.2;
      vector[10 + q] = (vector[3] + skyBias * 0.4 + math.sin(q * 0.5) * 0.15).clamp(-1.0, 1.0);
      vector[26 + q] = (blueDom * (row < 2 ? 0.85 : 0.4) + math.cos(q * 0.4) * 0.1).clamp(-1.0, 1.0);
      vector[42 + q] = (greenDom * (row >= 2 ? 0.85 : 0.3) + math.sin(q * 0.3) * 0.1).clamp(-1.0, 1.0);
    }

    // Edge and Texture Harmonics (dims 58..63)
    vector[58] = (vector[0] - vector[2]).abs() > 0.3 ? 0.8 : -0.2;
    vector[59] = (vector[1] - vector[0]).abs() > 0.3 ? 0.7 : -0.2;
    vector[60] = metrics.avgSaturation < 0.25 ? 0.75 : -0.3;
    vector[61] = metrics.avgLuminance < 60.0 ? 0.8 : 0.0;
    vector[62] = greenDom > 0.2 ? 0.7 : -0.2;
    vector[63] = 0.5;

    // L2 normalization to unit hypersphere
    double normSq = 0.0;
    for (int i = 0; i < 64; i++) {
      normSq += vector[i] * vector[i];
    }
    final double norm = math.sqrt(normSq) + 1e-8;
    for (int i = 0; i < 64; i++) {
      vector[i] /= norm;
    }

    return vector;
  }

  int _inferPropIndex((SceneType, String, String) scene) {
    switch (scene.$1) {
      case SceneType.beach:
      case SceneType.poolsideResort:
        return 0; // Beach & Coastal
      case SceneType.naturePark:
      case SceneType.gardenFloral:
        return 1; // Mountains & Nature Hiking
      case SceneType.rooftopSkyline:
      case SceneType.urbanCity:
      case SceneType.museumGallery:
        return 2; // Urban Rooftops & Cityscape
      case SceneType.cafeRestaurant:
        return 3; // Cafes, Diners & Restaurants
      case SceneType.indoorLiving:
      case SceneType.officeWorkspace:
        return 4; // Home, Cozy & Balcony
      case SceneType.gymFitness:
        return 5; // Gym, Yoga & Fitness
      case SceneType.festivalEvent:
        return 6; // Festivals, Parties & Nightlife
      case SceneType.studioMinimal:
      default:
        return 4; // Default to Home, Cozy & Balcony (4), NEVER Beach (0)
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
