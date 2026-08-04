import 'dart:convert';
import 'dart:math';
import 'package:flutter/services.dart';
import '../../pose_library/models/target_pose.dart';

class PoseEmbeddingData {
  final String poseId;
  final List<double> embedding;

  const PoseEmbeddingData({
    required this.poseId,
    required this.embedding,
  });

  factory PoseEmbeddingData.fromJson(Map<String, dynamic> json) {
    final List<dynamic> list = json['embedding'] ?? [];
    return PoseEmbeddingData(
      poseId: json['pose_id'] as String,
      embedding: list.map((e) => (e as num).toDouble()).toList(),
    );
  }
}

class RankedPoseMatch {
  final TargetPose pose;
  final double similarityScore; // 0.0 to 1.0 (1.0 = identical)

  const RankedPoseMatch({
    required this.pose,
    required this.similarityScore,
  });
}

class PoseRecommendationService {
  List<PoseEmbeddingData> _referenceEmbeddings = [];
  bool _isLoaded = false;

  /// Load precomputed MobileCLIP reference embeddings from local JSON asset
  Future<void> loadReferenceEmbeddings() async {
    if (_isLoaded) return;

    try {
      final jsonString = await rootBundle.loadString('assets/poses/target_pose_embeddings.json');
      final List<dynamic> jsonList = jsonDecode(jsonString);

      _referenceEmbeddings = jsonList
          .map((item) => PoseEmbeddingData.fromJson(item as Map<String, dynamic>))
          .toList();
      _isLoaded = true;
    } catch (e) {
      _referenceEmbeddings = [];
    }
  }

  /// Calculate Cosine Similarity between vector A and vector B
  double calculateCosineSimilarity(List<double> vecA, List<double> vecB) {
    if (vecA.length != vecB.length || vecA.isEmpty) return 0.0;

    double dotProduct = 0.0;
    double normA = 0.0;
    double normB = 0.0;

    for (int i = 0; i < vecA.length; i++) {
      dotProduct += vecA[i] * vecB[i];
      normA += vecA[i] * vecA[i];
      normB += vecB[i] * vecB[i];
    }

    if (normA == 0.0 || normB == 0.0) return 0.0;
    final denominator = sqrt(normA) * sqrt(normB);
    if (denominator == 0.0) return 0.0;
    final similarity = dotProduct / denominator;
    if (similarity.isNaN) return 0.0;
    // Clamp result between 0.0 and 1.0 for normalized score representation
    return similarity.clamp(0.0, 1.0);
  }

  /// Rank target reference poses by cosine similarity matching against live frame embedding
  List<RankedPoseMatch> rankPoses(List<double> liveFrameEmbedding, List<TargetPose> targetPoses) {
    if (_referenceEmbeddings.isEmpty || targetPoses.isEmpty) {
      return targetPoses.map((p) => RankedPoseMatch(pose: p, similarityScore: 0.5)).toList();
    }

    final Map<String, TargetPose> poseMap = {for (var p in targetPoses) p.id: p};
    final List<RankedPoseMatch> matches = [];

    for (final ref in _referenceEmbeddings) {
      final targetPose = poseMap[ref.poseId];
      if (targetPose != null) {
        final score = calculateCosineSimilarity(liveFrameEmbedding, ref.embedding);
        matches.add(RankedPoseMatch(pose: targetPose, similarityScore: score));
      }
    }

    // Sort descending by similarity score
    matches.sort((a, b) => b.similarityScore.compareTo(a.similarityScore));
    return matches;
  }
}
