# AI Pose Suggestion App — Progress & Roadmap (`progress.md`)

This document tracks the end-to-end development, implementation status, and technical roadmap of the **AI Pose Suggestion App**. It unifies the on-device mobile execution pipeline with the server-side dataset scraping, model training, pose evaluation, and generative pose creation engines.

---

## 1. Unified System Overview

```text
                               AI Pose Suggestion Engine
┌─────────────────────────────────────────────────────────────────────────────────────────┐
│                               Server & Data Pipeline                                    │
│   Web Scraper (Unsplash/Pinterest/Pexels) ──► LAION Aesthetic Filter (>=6.5)            │
│                                                     │                                   │
│                                                     ▼                                   │
│   DWPose Keypoint Annotator + MobileCLIP Vectorizer ──► Dataset Index (JSON/Parquet)  │
│                                                     │                                   │
│                                                     ▼                                   │
│   PoseDiff-X Generator Training (100 Epochs) ───────► TFLite/ONNX Quantized Export      │
└─────────────────────────────────────────────────────────────────────────────────────────┘
                                          │
                                          ▼
┌─────────────────────────────────────────────────────────────────────────────────────────┐
│                                Mobile Runtime Application                               │
│                         Flutter / React Native Vision Camera                            │
└─────────────────────────────────────────────────────────────────────────────────────────┘
                                          │
                                          ▼
                               Multi-Tier Frame Scheduler
                                          │
        ┌─────────────────────────────────┼────────────────────────────────┐
        │                                 │                                │
        ▼                                 ▼                                ▼
  FAST PIPELINE                     MEDIUM PIPELINE                   SLOW PIPELINE
  (30 FPS / 250ms)                  (2 FPS / 500ms)                   (0.5 FPS / 2s)
  ML Kit / RTMPose-tiny             YOLO11n Objects                   MobileCLIP Scene
  (17-33 Body Keypoints)            (Chair, Stairs, Flowers...)       (Beach, Park, Outdoor...)
        │                                 │                                │
        └─────────────────────────┬───────┴────────────────────────────────┘
                                  │
                                  ▼
                     Context Builder (Shared State)
                                  │
                                  ▼
                       Pose Intelligence Engine
                                  │
          ┌───────────────────────┼───────────────────────┐
          ▼                       ▼                       ▼
   Pose Retrieval           Pose Ranking           Pose Adaptation
   (Target Database /      (Cosine Similarity      (Scale / Mirror /
    PoseDiff-X Model)       Ranker)                 Target Stencil)
          │                       │                       │
          └───────────────────────┴───────────────────────┘
                                  │
                                  ▼
                        Pose Matching Engine
               (3D Angle Deltas + OKS Similarity Score)
                                  │
        ┌─────────────────────────┼─────────────────────────┐
        ▼                         ▼                         ▼
 Guidance Engine           Skia Overlay Engine        Auto-Capture
 (TTS Voice Cues)          (Skeleton Stencil HUD)     (1.5s Hold Lock >=80%)
```

---

## 2. Phase-by-Phase Implementation Status

| Phase | Phase Name | Status | Technology Stack | Key Deliverables & Done Criteria |
| :--- | :--- | :--- | :--- | :--- |
| **Phase 0** | Project Setup & Scaffold | **Completed** | Flutter / Dart | Clean baseline scaffold, `AGENTS.md` instructions referencing `progress.md` & `epoch.md`, dark theme (`#0F172A`), bottom navigation shell. |
| **Phase 1** | Camera Core Integration | **Completed** | `camera` | Hardware permission handling, YUV420/BGRA stream initialization, front/back camera lens toggling, manual shutter capture. |
| **Phase 2** | Real-Time Pose Detection | **Completed** | `google_mlkit_pose_detection` | Stream throttle latch (250ms), 33 3D keypoint extraction, custom `PoseOverlayPainter` skeleton rendering with front-camera horizontal mirroring. |
| **Phase 3** | Reference Pose Library | **Ready** | Bundled JSON | Database of target poses (`target_poses.json`), category chips filter (Standing, Sitting, Couple), translucent `TargetPoseStencilPainter`. |
| **Phase 4** | Scene-Aware Recommendation | **Ready** | `tflite_flutter` / Cosine Sim | MobileCLIP 64-d feature vectors (`target_pose_embeddings.json`), dot-product cosine similarity ranking engine, visual AI % Match badges. |
| **Phase 5** | Suggestion Engine & TTS | **Ready** | Pure Dart Math / `flutter_tts` | 3D Euclidean vertex angle engine $\theta = \arccos\left(\frac{\vec{BA}\cdot\vec{BC}}{\|\vec{BA}\|\|\vec{BC}\|}\right)$, joint deltas, speech synthesis wrapper with 3–4s throttling guard. |
| **Phase 6** | Camera UI Integration | **Ready** | `CustomPainter` / State | Top HUD banner overlay, animated match score percentage badge, Good Pose visual aura, persisted stencil color picker (`shared_preferences`). |
| **Phase 7** | Auto-Capture Flow | **Ready** | Dart Timers | 1.5s countdown hold lock when match score $\ge 80\%$, automatic `takePicture()` trigger, photo thumbnail preview dialog. |
| **Phase 8** | Fallbacks & Error Handling | **Ready** | Flutter Widgets | Non-blocking amber warning banners for `"No person detected"`, `"Low lighting"`, and hardware `CameraException` retry fallbacks. |
| **Phase 9** | Manual QA & Performance | **Ready** | Dart Profiler | 250ms frame stream throttling, reusable `Paint` cache objects, battery optimization, complete documentation suite (`DOCUMENTATION.md`). |
| **Phase 10** | Dataset Scraping & Annotation | **In Progress** | Python / Scrapy / DWPose | Multi-threaded web scrapers (Unsplash/Pexels/Pinterest), LAION-Aesthetic filter ($\ge 6.5$), DWPose 33-keypoint annotation, MobileCLIP feature indexing. |
| **Phase 11** | Pose Evaluation Engine | **Planned** | RTMPose-tiny / OKS | Object Keypoint Similarity (OKS) metric integration, confidence-weighted joint delta loss, 3D kinematic angle normalization. |
| **Phase 12** | Generative Pose Generator | **Planned** | PoseDiff-X / PyRoki IK | 1D Skeleton Diffusion Transformer training over 100 epochs, Inverse Kinematics (IK) bone length solver, ONNX/TFLite model export. |
| **Phase 13** | Context Builder Engine | **Planned** | YOLO11n + MobileCLIP | 3-tier frame scheduler integration (Fast 30fps pose stream, Medium 2fps YOLO11 prop detection, Slow 0.5fps scene embedding). |
| **Phase 14** | Dynamic Stencil Generation | **Planned** | Skia / Flutter Canvas | Real-time rendering of generated pose skeletons from PoseDiff-X model directly into dynamic canvas overlay stencils. |


---

## 3. Feature Verification Matrix

| Feature Module | Model / Algorithm | Latency Target | Status | Verification Benchmark |
| :--- | :--- | :--- | :--- | :--- |
| **Pose Estimation** | ML Kit / RTMPose-tiny | 15–30 ms | **Active** | 33 3D Keypoints detected at $\ge 25\text{ FPS}$ on mid-tier mobile hardware. |
| **Scene Embeddings** | MobileCLIP (Quantized TFLite) | 150–200 ms | **Active** | 64-d cosine similarity match score computed every 1–2 seconds. |
| **Angle Calculation** | 3D Euclidean Vector Dot Product | $< 1\text{ ms}$ | **Active** | 8 major joint angles ($\theta_{\text{elbow}}, \theta_{\text{shoulder}}, \theta_{\text{hip}}, \theta_{\text{knee}}$) calculated per frame. |
| **Directional Guidance** | Rule Table + Speech Synthesis | 3–4 s | **Active** | Spoken directional cues ("Raise right arm higher") with speech throttle lock. |
| **Auto-Capture** | 1.5s Hold Lock | 1500 ms | **Active** | Camera triggers photo snapshot automatically upon score $\ge 80\%$. |
| **Web Dataset Scraping** | Async Python + LAION Filter | Off-Line | **In Progress** | Harvests $\ge 10,000$ high-aesthetic pose images with ground-truth DWPose keypoints. |
| **Novel Pose Generation** | PoseDiff-X Diffusion Transformer | 50–100 ms | **Planned** | Generates novel 3D skeleton keypoints for unseen scene/prop context combinations. |

---

## 4. Milestone Verification Checklist

- [x] **Milestone 1**: 100% On-device Flutter MVP baseline verified (`flutter run`).
- [x] **Milestone 2**: Real-time pose overlay and target stencil alignment rendering.
- [x] **Milestone 3**: Auto-capture hold lock and directional TTS voice feedback operational.
- [ ] **Milestone 4**: Web scraper harvest of 10k pose images with LAION Aesthetic score $\ge 6.5$.
- [ ] **Milestone 5**: 100-Epoch training of PoseDiff-X model completed with OKS validation score $\ge 0.85$.
- [ ] **Milestone 6**: Quantized TFLite export integrated into dynamic mobile stencil painter.
