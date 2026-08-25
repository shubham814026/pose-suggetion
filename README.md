Camera
  │
  ▼
Vision Camera
  │
  ▼
Frame Scheduler
  │
  ├── Pose Estimator ───────┐
  │                         │
  ├── Person Tracker ───────┤
  │                         │
  ├── Object Detector ──────┤
  │                         │
  ├── Scene Classifier ─────┤
  │                         │
  ├── Face/Quality Model ───┤
  │                         │
  └── Image Quality ────────┘
                            ↓
                     Context Builder
                            ↓
                 Pose Recommendation
                            ↓
                    Target Skeleton
                            ↓
                  Pose Matching Engine
                            ↓
                  Capture Quality Engine
                       ↓          ↓
                  Guidance     Capture
                       ↓          ↓
                    Overlay → Photograph