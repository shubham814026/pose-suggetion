# API & Module Reference

This document provides a detailed contract reference for all major components, services, data models, custom painters, and utility modules in the codebase.

---

## 1. Feature Modules Summary

```
lib/
├── core/
│   ├── services/
│   │   └── preferences_service.dart
│   └── theme/
│       └── app_theme.dart
├── features/
│   ├── camera/
│   │   └── presentation/
│   │       ├── camera_screen.dart
│   │       └── widgets/
│   │           └── permission_denied_view.dart
│   ├── pose_detection/
│   │   ├── presentation/
│   │   │   └── widgets/
│   │   │       └── pose_overlay_painter.dart
│   │   ├── services/
│   │   │   └── pose_detector_service.dart
│   │   └── utils/
│   │       └── camera_image_converter.dart
│   ├── pose_library/
│   │   ├── models/
│   │   │   └── target_pose.dart
│   │   ├── presentation/
│   │   │   ├── pose_library_screen.dart
│   │   │   └── widgets/
│   │   │       └── target_pose_stencil_painter.dart
│   │   └── services/
│   │       └── pose_library_service.dart
│   ├── pose_recommendation/
│   │   └── services/
│   │       └── pose_recommendation_service.dart
│   └── suggestion_engine/
│       ├── models/
│       │   └── joint_delta.dart
│       └── services/
│           ├── pose_comparison_engine.dart
│           ├── directional_suggestion_engine.dart
│           └── tts_suggestion_service.dart
```

---

## 2. Core & Utility Services

### `PreferencesService` ([lib/core/services/preferences_service.dart](file:///d:/pose-suggetion/lib/core/services/preferences_service.dart))
- **Purpose**: Persists user UI preferences (stencil outline color, voice mute state) using `SharedPreferences`.
- **Methods**:
  - `saveStencilColor(Color color)`: Saves outline color hex string.
  - `getStencilColor()`: Reads stencil color choice (Default `0xFF06B6D4` Cyan).
  - `saveVoiceEnabled(bool enabled)`: Saves TTS voice preference.
  - `getVoiceEnabled()`: Reads voice guidance preference (Default `true`).

---

## 3. Camera & Pose Detection Modules

### `PoseDetectorService` ([lib/features/pose_detection/services/pose_detector_service.dart](file:///d:/pose-suggetion/lib/features/pose_detection/services/pose_detector_service.dart))
- **Purpose**: Wraps Google ML Kit `PoseDetector` operating in stream mode.
- **Methods**:
  - `processInputImage(InputImage inputImage)`: Evaluates frame and returns `Future<List<Pose>>`.
  - `close()`: Releases ML Kit native resources.

### `convertCameraImageToInputImage` ([lib/features/pose_detection/utils/camera_image_converter.dart](file:///d:/pose-suggetion/lib/features/pose_detection/utils/camera_image_converter.dart))
- **Purpose**: Converts Flutter `CameraImage` (YUV420 on Android, BGRA on iOS) to ML Kit `InputImage`.
- **Parameters**: `CameraImage image`, `CameraDescription camera`.

### `PoseOverlayPainter` ([lib/features/pose_detection/presentation/widgets/pose_overlay_painter.dart](file:///d:/pose-suggetion/lib/features/pose_detection/presentation/widgets/pose_overlay_painter.dart))
- **Purpose**: `CustomPainter` rendering 33 live detected skeleton bones and joint landmark dots.
- **Props**: `List<Pose> poses`, `Size imageSize`, `CameraLensDirection lensDirection`.

---

## 4. Pose Library & Recommendation Engine

### `TargetPose` ([lib/features/pose_library/models/target_pose.dart](file:///d:/pose-suggetion/lib/features/pose_library/models/target_pose.dart))
- **Schema**:
  - `String id`, `String name`, `String category`, `List<String> tags`, `String description`.
  - `Map<String, double> targetAngles` — Expected target joint angles.
  - `List<PoseKeypointData> keypoints` — Normalized 2D/3D silhouette coordinates.

### `TargetPoseStencilPainter` ([lib/features/pose_library/presentation/widgets/target_pose_stencil_painter.dart](file:///d:/pose-suggetion/lib/features/pose_library/presentation/widgets/target_pose_stencil_painter.dart))
- **Purpose**: Renders a translucent target pose silhouette stencil overlay over `CameraPreview`.
- **Props**: `TargetPose targetPose`, `Color stencilColor`, `CameraLensDirection lensDirection`.

### `PoseRecommendationService` ([lib/features/pose_recommendation/services/pose_recommendation_service.dart](file:///d:/pose-suggetion/lib/features/pose_recommendation/services/pose_recommendation_service.dart))
- **Purpose**: Cosine similarity matching engine for scene-aware pose ranking.
- **Methods**:
  - `loadReferenceEmbeddings()`: Loads `assets/poses/target_pose_embeddings.json`.
  - `calculateCosineSimilarity(List<double> vecA, List<double> vecB)`: Returns double between `0.0` and `1.0`.
  - `rankPoses(List<double> liveFrameEmbedding, List<TargetPose> targetPoses)`: Returns sorted list of `RankedPoseMatch` objects.

---

## 5. Suggestion Engine Modules

### `PoseComparisonEngine` ([lib/features/suggestion_engine/services/pose_comparison_engine.dart](file:///d:/pose-suggetion/lib/features/suggestion_engine/services/pose_comparison_engine.dart))
- **Purpose**: Computes 3D vertex joint angles, joint deltas, and match score percentage.
- **Methods**:
  - `calculateAngle(PoseLandmark first, PoseLandmark mid, PoseLandmark last)`: Returns vertex angle in degrees (`0° - 180°`).
  - `comparePoses({required Pose livePose, required TargetPose targetPose})`: Returns `List<JointDelta>`.
  - `calculateMatchScore(List<JointDelta> deltas)`: Returns normalized match score percentage (`0.0% - 100.0%`).

### `DirectionalSuggestionEngine` ([lib/features/suggestion_engine/services/directional_suggestion_engine.dart](file:///d:/pose-suggetion/lib/features/suggestion_engine/services/directional_suggestion_engine.dart))
- **Purpose**: Maps joint deltas against an actionable feedback rule table.
- **Methods**:
  - `generateSuggestions(List<JointDelta> deltas)`: Returns `List<String>` positioning advice.

### `TtsSuggestionService` ([lib/features/suggestion_engine/services/tts_suggestion_service.dart](file:///d:/pose-suggetion/lib/features/suggestion_engine/services/tts_suggestion_service.dart))
- **Purpose**: Delivers real-time spoken directional feedback with a 3–4s throttling guard.
- **Methods**:
  - `initialize({bool voiceOnByDefault = true})`: Configures platform TTS settings.
  - `speakSuggestion(String text)`: Speaks text if text changed or 3–4s interval elapsed.
  - `setMuted(bool muted)`: Mutes/unmutes speech synthesis.
