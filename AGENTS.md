# Agent Instructions — AI Pose Suggestion App

Whenever working inside `pose-suggetion/`, follow these workflow rules:

1. **Read Progress Status First**: Inspect [`docs/progress.md`](file:///home/pratham/projects/pose-generation-app/pose-suggetion/docs/progress.md) to locate active phases, completed features, and next implementation targets.
2. **Read ML & Epoch Blueprint**: Inspect [`docs/epoch.md`](file:///home/pratham/projects/pose-generation-app/pose-suggetion/docs/epoch.md) for dataset scraping specs, DWPose keypoint annotations, RTMPose evaluation model, PoseDiff-X diffusion generator, loss functions, and 100-epoch hyperparameter schedules.
3. **Decoupled Architecture**: Keep Dart calculation services (`PoseComparisonEngine`, `DirectionalSuggestionEngine`, `PoseRecommendationService`) pure and decoupled from Flutter UI widgets.
4. **Update Progress**: Mark completed milestones in `docs/progress.md` upon verifying implementation.
