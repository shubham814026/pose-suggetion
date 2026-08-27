# 📱 Pose Suggestion App (Flutter)

An on-device AI camera assistant built with Flutter that renders **stylized white body silhouette outlines** and **in-situ limb action badges** to guide users into aesthetic photography poses, inspired by the **Huawei Pura AI Camera**.

---

## ⚡ Quickstart

```bash
# 1. Install Flutter dependencies
flutter pub get

# 2. Verify static analysis & tests
flutter analyze
flutter test

# 3. Launch on connected device / emulator
flutter run
```

---

## 🧠 Model Assets & Bundled Database

- `assets/poses/target_poses.json`: 12,001 real pose photographs with 33 3D keypoints, joint angles, silhouette contours, and action tags.
- `assets/poses/target_pose_embeddings.json`: 64-d cosine similarity feature vectors.
- `assets/models/context_pose_weights.json`: Direct Dart On-Device Execution Weights ($1.2\text{ MB}$) for sub-10ms native neural inference.
- `assets/models/context_pose_generator.onnx`: Mobile ONNX neural model ($472\text{ KB}$).
- `assets/models/context_pose_generator.pt`: PyTorch model state dict.
- `assets/models/pose_landmarker_lite.task`: Google MediaPipe Pose Landmarker model asset.

---

## 🛠️ Python ML Pipelines (`scripts/`)

```bash
# Multi-source proxy-enabled dataset harvester
./venv/bin/python scripts/build_real_online_dataset.py --target 12000 --workers 32

# 4x Dataset augmentation (mirroring, scale/translation jitter, rotation)
./venv/bin/python scripts/augment_dataset.py

# 100-Epoch multi-task deep learning trainer
./venv/bin/python scripts/train_context_pose_model.py
```