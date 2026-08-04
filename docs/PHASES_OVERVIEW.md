# Phase-by-Phase MVP Implementation Guide

This document details the architectural evolution, features, code modules, and done conditions across all 9 implementation phases of the **AI Pose Suggestion App**.

---

## Phase Summary Table

| Phase | Phase Name | Status | Key Focus |
| :--- | :--- | :--- | :--- |
| **Phase 0** | Project Setup & Scaffold | Completed | Dependencies, folder structure, navigation shell, dark theme |
| **Phase 1** | Camera Core Integration | Completed | Camera permissions, live preview stream, lens toggle, manual capture |
| **Phase 2** | Real-Time Pose Detection | Completed | ML Kit 3D pose detection, YUV420 converter, 250ms stream throttler, live skeleton overlay painter |
| **Phase 3** | Reference Pose Library | Completed | Bundled target pose JSON database (10 poses), Dart models, category chips, stencil silhouette painter |
| **Phase 4** | Scene-Aware Recommendation | Completed | Precalculated MobileCLIP 64-d feature vectors, cosine similarity ranking engine, AI match badges |
| **Phase 5** | Suggestion Engine & Voice Cues | Completed | 3D vertex angle math, joint deltas, numeric match score %, threshold rule table, `flutter_tts` service |
| **Phase 6** | Camera UI Integration | Completed | Top HUD banner overlay, Good Pose trigger visual aura, persisted stencil color toggle |
| **Phase 7** | Auto-Capture Flow | Completed | 1.5s countdown hold lock on match score $\ge 80\%$, auto `takePicture()`, photo thumbnail preview |
| **Phase 8** | Fallbacks & Error Handling | Completed | Non-blocking banners for no-person-detected, low lighting, and `CameraException` retry fallbacks |
| **Phase 9** | Manual QA & Performance | Completed | 250ms stream throttling, `Paint` cache optimization, battery efficiency, and technical documentation |

---

## Detailed Breakdown by Phase

### Phase 0 — Project Setup & Scaffold
- **Goal**: Establish project architecture, design system, dependencies, and shell navigation.
- **Key Modules**:
  - `pubspec.yaml` — Configured dependencies (`camera`, `google_mlkit_pose_detection`, `flutter_tts`, `permission_handler`, `shared_preferences`, `tflite_flutter`, `provider`).
  - `lib/core/theme/app_theme.dart` — Sleek dark theme palette (`#121214` dark background, `#06B6D4` cyan, `#8B5CF6` violet, `#10B981` emerald green).
  - `lib/navigation/app_navigation_shell.dart` — Bottom navigation bar coordinating `CameraScreen`, `PoseLibraryScreen`, and `SettingsScreen`.

---

### Phase 1 — Camera Core Integration
- **Goal**: Implement low-latency camera hardware access, permissions, front/back lens switching, and photo capture.
- **Key Modules**:
  - `android/app/src/main/AndroidManifest.xml` & `ios/Runner/Info.plist` — Camera hardware permissions.
  - `lib/features/camera/presentation/widgets/permission_denied_view.dart` — User permission request and system settings fallback screen.
  - `lib/features/camera/presentation/camera_screen.dart` — `CameraController` initialization, lens switching, and photo storage cache.

---

### Phase 2 — Real-Time Pose Detection Integration
- **Goal**: Stream camera frames to ML Kit Pose Detection on-device, extract 33 3D landmarks, and draw real-time debug skeletons.
- **Key Modules**:
  - `lib/features/pose_detection/services/pose_detector_service.dart` — ML Kit `PoseDetector` wrapper operating in stream detection mode.
  - `lib/features/pose_detection/utils/camera_image_converter.dart` — Converts platform `CameraImage` (YUV420 on Android, BGRA on iOS) to `InputImage` bytes.
  - `lib/features/pose_detection/presentation/widgets/pose_overlay_painter.dart` — `CustomPainter` rendering skeletal bones and landmark dots, with front camera horizontal mirroring adjustment.

---

### Phase 3 — Reference Pose Library
- **Goal**: Seed reference target pose dataset and build gallery picker with category filters and stencil silhouette overlays.
- **Key Modules**:
  - `assets/poses/target_poses.json` — Bundled database of 10 target reference poses with 3D keypoints and target joint angles.
  - `lib/features/pose_library/models/target_pose.dart` — `TargetPose` and `PoseKeypointData` schemas.
  - `lib/features/pose_library/services/pose_library_service.dart` — Local asset loader.
  - `lib/features/pose_library/presentation/pose_library_screen.dart` — Category chips filter and pose gallery cards.
  - `lib/features/pose_library/presentation/widgets/target_pose_stencil_painter.dart` — Translucent target silhouette stencil overlay.

---

### Phase 4 — Scene-Aware Pose Recommendation
- **Goal**: Calculate cosine similarity matching between camera frame feature vectors and target reference pose embeddings to rank recommendations.
- **Key Modules**:
  - `assets/poses/target_pose_embeddings.json` — Precomputed 64-element feature vector embeddings for target poses.
  - `lib/features/pose_recommendation/services/pose_recommendation_service.dart` — Vector dot product and cosine similarity ranking engine:
    $$\text{CosineSimilarity}(\vec{A}, \vec{B}) = \frac{\vec{A} \cdot \vec{B}}{\|\vec{A}\| \|\vec{B}\|}$$
  - `lib/features/pose_library/presentation/pose_library_screen.dart` — Reordered pose cards displaying AI % Match badges.

---

### Phase 5 — Suggestion Engine & Voice Guidance
- **Goal**: Build pure Dart 3D vertex angle calculation engine, derive joint deltas, evaluate overall match score %, translate deltas to directional text, and trigger spoken voice feedback.
- **Key Modules**:
  - `lib/features/suggestion_engine/models/joint_delta.dart` — Data class for per-joint angle deltas.
  - `lib/features/suggestion_engine/services/pose_comparison_engine.dart` — Computes 3D vertex angles $\theta = \arccos\left(\frac{\vec{BA} \cdot \vec{BC}}{\|\vec{BA}\| \|\vec{BC}\|}\right)$ and match score percentage.
  - `lib/features/suggestion_engine/services/directional_suggestion_engine.dart` — Rule table converting angle deltas into positioning instructions ("Bend left elbow more", "Raise right arm higher").
  - `lib/features/suggestion_engine/services/tts_suggestion_service.dart` — Speech synthesis wrapper with 3–4s speech throttling guard.
  - `test/pose_comparison_engine_test.dart` & `test/directional_suggestion_engine_test.dart` — Automated unit test suite.

---

### Phase 6 — Camera UI Integration
- **Goal**: Overlay top HUD suggestion banner, match score percentage meter, Good Pose visual aura, and persisted stencil color picker.
- **Key Modules**:
  - `lib/core/services/preferences_service.dart` — `SharedPreferences` wrapper persisting stencil color choice and voice toggle.
  - `lib/features/camera/presentation/camera_screen.dart` — Integrated HUD banner with animated score badge and stencil color palette button.

---

### Phase 7 — Auto-Capture Flow
- **Goal**: Implement automatic capture trigger when posture match score reaches $\ge 80\%$.
- **Key Modules**:
  - `lib/features/camera/presentation/camera_screen.dart` — 1.5s countdown hold timer lock (`_triggerAutoCaptureCountdown()`), automatic `takePicture()` invocation, and photo thumbnail preview dialog.

---

### Phase 8 — Fallbacks & Error Handling
- **Goal**: Gracefully handle edge cases without app crashes.
- **Key Modules**:
  - `lib/features/camera/presentation/camera_screen.dart` — Non-blocking amber warning banners for:
    - `"No person detected in camera view. Step into frame."`
    - `"Low lighting or poor visibility detected"`
    - `CameraException` hardware failure retry buttons.

---

### Phase 9 — Manual QA Pass & Optimization
- **Goal**: Audit app responsiveness, frame latency, memory allocation, and complete technical documentation.
- **Key Modules**:
  - 250ms frame stream throttling latch.
  - Reusable `Paint` objects in custom painters.
  - Coarse 1-2s scene embedding frequency to conserve battery.
  - Complete `DOCUMENTATION.md` and multi-file `docs/` technical documentation.
