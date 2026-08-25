# ML Model Training Lifecycle & Epoch Roadmap (`epoch.md`)

This document defines the complete machine learning lifecycle, dataset scraping pipeline, model architectures, mathematical loss functions, evaluation metrics, and epoch-by-epoch training schedule for **Pose Evaluation** and **Generative Pose Creation**.

---

## 1. Web Dataset Scraping & Curation Pipeline

To train high-precision pose evaluation and novel pose generation models, a curated dataset of aesthetic, well-composed photographs is gathered via automated scraping.

### A. Scraping Infrastructure
* **Target Data Sources**: Unsplash, Pexels, Flickr Commons, Pinterest public photography boards, COCO Pose, MPII Human Pose.
* **Scraper Tech Stack**: Async Python (`httpx`, `Scrapy`, `Playwright`), distributed worker nodes, Phash perceptual deduplication.

### B. Automated Quality Filtering Pipeline
Every scraped image $\mathbf{I}$ undergoes multi-stage automated filtering before entering the training dataset:

```text
Raw Image Stream
       │
       ▼
1. Resolution & Format Check ──► Reject if width or height < 720px
       │
       ▼
2. Person Detection (YOLO11x) ──► Reject if Bounding Box Confidence < 0.80
       │
       ▼
3. LAION-Aesthetic Predictor ──► Reject if Aesthetic Score < 6.5 / 10.0
       │
       ▼
4. DWPose Keypoint Annotator ──► Extract 33 3D Keypoints [x_i, y_i, z_i, v_i]
       │
       ▼
5. MobileCLIP Feature Vector ──► Extract 512-d Scene Embedding Vector
       │
       ▼
 Curated Pose Dataset Index (Parquet / JSON metadata)
```

---

## 2. Model 1: Pose Evaluation & Quality Scoring Model

### Purpose
Evaluates posture alignment accuracy between a live user camera skeleton $\mathbf{K}_{\text{user}}$ and target pose skeleton $\mathbf{K}_{\text{target}}$, outputting a normalized similarity score $S \in [0, 100\%]$ and joint delta errors.

### Model Architecture
* **Backbone**: **RTMPose-tiny / Lightweight GNN-MLP Pose Ranker**.
* **Input Features**: Normalized 33 keypoint coordinates $(x_i, y_i, z_i) \in [0, 1]^3$, keypoint visibilities $v_i$, and 8 primary joint vertex angles $\theta_j$.

### Mathematical Loss Functions

1. **Object Keypoint Similarity (OKS) Loss**:
   Matches keypoint displacements $d_i = \|\mathbf{p}_{\text{pred}, i} - \mathbf{p}_{\text{gt}, i}\|_2$ weighted by person scale $s$ and per-keypoint constant $k_i$:

   $$\mathcal{L}_{\text{OKS}} = 1.0 - \frac{1}{\sum_i v_i} \sum_{i=1}^{N} v_i \exp\left( -\frac{d_i^2}{2 s^2 k_i^2} \right)$$

2. **Hierarchical Wing Loss for Joint Angles**:
   Enforces tight alignment on major limb joint angles ($\theta_{\text{elbow}}, \theta_{\text{shoulder}}, \theta_{\text{hip}}, \theta_{\text{knee}}$):

   $$\mathcal{L}_{\text{angle}} = \sum_{j=1}^{M} \text{WingLoss}(\theta_{\text{pred}, j} - \theta_{\text{target}, j})$$

3. **Total Evaluation Loss**:

   $$\mathcal{L}_{\text{eval}} = \lambda_1 \mathcal{L}_{\text{OKS}} + \lambda_2 \mathcal{L}_{\text{angle}} + \lambda_3 \mathcal{L}_{\text{reg}}$$

   *(Default weights: $\lambda_1 = 1.0$, $\lambda_2 = 0.5$, $\lambda_3 = 10^{-4}$)*

### Evaluation Metrics
* **OKS (Object Keypoint Similarity)**: Normalized COCO metric ($\ge 0.85$ target).
* **PCK@0.2 (Percentage of Correct Keypoints)**: Percentage of keypoints within $0.2 \times \text{head size}$.
* **Angular Delta Error**: Mean absolute angle error across 8 major joints ($\le 15^\circ$ target).

---

## 3. Model 2: Generative Pose Creation Model (PoseDiff-X)

### Purpose
Generates novel, kinematically valid, natural 3D skeleton poses $\mathbf{K}_{\text{gen}} \in \mathbb{R}^{33 \times 3}$ for unseen scene contexts, available props (e.g. chairs, stairs), and camera angles.

### Model Architecture
* **Backbone**: **PoseDiff-X (Context-Conditioned 1D Skeleton Diffusion Transformer)**.
* **Conditioning Context $\mathbf{c}$**:
  * Scene Embedding Vector $\mathbf{v}_{\text{scene}} \in \mathbb{R}^{512}$ (MobileCLIP).
  * Object Prop Tokens $\mathbf{o} \in \{0, 1\}^K$ (YOLO11 detected objects).
  * People Count $N \in \{1, 2, 3+\}$.
  * Camera Orientation & Angle (eye-level, low-angle, high-angle).

### Mathematical Loss Functions

1. **Denoising Score Matching Loss**:
   Predicts noise $\boldsymbol{\epsilon}$ added to skeleton coordinates $\mathbf{x}_t$ at diffusion timestep $t \in [1, T]$:

   $$\mathcal{L}_{\text{simple}} = \mathbb{E}_{t, \mathbf{x}_0, \boldsymbol{\epsilon}} \left[ \left\| \boldsymbol{\epsilon} - \boldsymbol{\epsilon}_\theta(\mathbf{x}_t, t, \mathbf{c}) \right\|^2 \right]$$

2. **Kinematic Bone-Length Invariance Loss**:
   Prevents unnatural limb stretching/shrinking by penalizing bone length deviations from physical human skeletal proportions $L_{uv}$:

   $$\mathcal{L}_{\text{limb}} = \sum_{(u, v) \in E} \left( \|\mathbf{p}_u - \mathbf{p}_v\|_2 - L_{uv} \right)^2$$

3. **Anatomical Joint Rotation Bound Loss**:
   Penalizes joint angles $\theta_j$ that exceed human biomechanical limits $[\theta_{\min}, \theta_{\max}]$:

   $$\mathcal{L}_{\text{anatomical}} = \sum_{j=1}^{M} \max(0, \theta_{\min, j} - \theta_j)^2 + \max(0, \theta_j - \theta_{\max, j})^2$$

4. **Total Diffusion Generator Loss**:

   $$\mathcal{L}_{\text{gen}} = \mathcal{L}_{\text{simple}} + \gamma_1 \mathcal{L}_{\text{limb}} + \gamma_2 \mathcal{L}_{\text{anatomical}}$$

---

## 4. 100-Epoch Training Schedule & Roadmap

```text
┌────────────────────────────────────────────────────────────────────────────────────────┐
│ Phase 1: Epochs 1 – 20  │ Data Ingestion, LAION Filtering & Feature Warmup              │
├─────────────────────────┼──────────────────────────────────────────────────────────────┤
│ Phase 2: Epochs 21 – 50 │ Primary Keypoint Denoising & Context Vector Cross-Attention   │
├─────────────────────────┼──────────────────────────────────────────────────────────────┤
│ Phase 3: Epochs 51 – 80 │ Kinematic Bone Length & Anatomical Rotation Loss Constraints │
├─────────────────────────┼──────────────────────────────────────────────────────────────┤
│ Phase 4: Epochs 81 – 100│ Model Distillation, INT8/FP16 Quantization & Mobile Export    │
└────────────────────────────────────────────────────────────────────────────────────────┘
```

### Detailed Epoch Breakdown

#### Phase 1: Data Preprocessing & Warmup (Epochs 1 – 20)
* **Dataset Size**: 50,000 scraped images $\rightarrow$ Filtered to 15,000 high-aesthetic pose samples ($\text{LAION Score} \ge 6.5$).
* **Hyperparameters**:
  * Optimizer: `AdamW` ($\beta_1 = 0.9, \beta_2 = 0.999$, weight decay $= 0.01$)
  * Initial Learning Rate: $\eta = 10^{-3}$ with linear warmup over first 5 epochs.
  * Batch Size: 128
* **Goal**: Establish stable baseline loss convergence on keypoint coordinate prediction.

#### Phase 2: Context Alignment & Noise Conditioning (Epochs 21 – 50)
* **Diffusion Timesteps**: $T = 1000$ (linear beta schedule $10^{-4}$ to $0.02$).
* **Hyperparameters**:
  * Learning Rate: $\eta = 2 \times 10^{-4}$ with Cosine Annealing decay.
  * Classifier-Free Guidance Dropout: $p_{\text{uncond}} = 0.15$.
* **Goal**: Train Cross-Attention layers to accurately generate skeleton styles matching scene context embeddings (e.g. beach vs graduation).

#### Phase 3: Kinematic Constraint & Aesthetic Tuning (Epochs 51 – 80)
* **Loss Integration**: Activate $\mathcal{L}_{\text{limb}}$ ($\gamma_1 = 0.1$) and $\mathcal{L}_{\text{anatomical}}$ ($\gamma_2 = 0.05$).
* **Goal**: Eliminate anatomical anomalies (disjointed elbows, over-extended knees, varying bone lengths). Achieve $\ge 90\%$ kinematically valid generated skeletons.

#### Phase 4: Distillation, Quantization & Mobile Export (Epochs 81 – 100)
* **DDIM Sampling**: Reduce sampling timesteps from $T=1000$ to $N=20$ DDIM steps for fast mobile inference ($< 100\text{ ms}$).
* **Quantization**: Post-Training Dynamic Range Quantization (FP16 and INT8) for TensorFlow Lite runtime.
* **Goal**: Export optimized `.tflite` model size $< 8\text{ MB}$ maintaining OKS similarity $\ge 0.85$.

---

## 5. Epoch Log Schema & Benchmark Table

| Epoch | Train Loss ($\mathcal{L}_{\text{simple}}$) | Kinematic Loss ($\mathcal{L}_{\text{limb}}$) | Val OKS Score | PCK@0.2 | Mean Angle Error | Model Artifact Status |
| :---: | :---: | :---: | :---: | :---: | :---: | :---: |
| **1** | 0.4820 | 0.1250 | 0.412 | 52.4% | $28.4^\circ$ | Baseline Checkpoint |
| **20** | 0.1450 | 0.0410 | 0.685 | 74.1% | $19.2^\circ$ | Warmup Completed |
| **50** | 0.0520 | 0.0180 | 0.812 | 88.5% | $14.1^\circ$ | Context Conditioned |
| **80** | 0.0210 | 0.0035 | 0.878 | 94.2% | $10.5^\circ$ | Kinematically Sound |
| **100**| **0.0145** | **0.0012** | **0.895** | **96.1%** | **$8.7^\circ$** | **Quantized TFLite Export** |

---

## 6. Model Verification & Mobile Benchmarks

To confirm deployment readiness on mobile hardware, exported models must satisfy the following thresholds:

| Metric / Requirement | Target Benchmark Threshold | Verification Tool |
| :--- | :--- | :--- |
| **Model Size** | $\le 8.0\text{ MB}$ (TFLite INT8 / FP16) | `tflite_convert` inspection |
| **Inference Latency** | $\le 85\text{ ms}$ per generated skeleton | Android / iOS Benchmark Runner |
| **Anatomical Validity** | $0$ limb length violations $> 5\%$ | PyRoki Kinematic Checker |
| **OKS Score vs Ground Truth** | $\ge 0.85$ | COCO OKS Validation Suite |
