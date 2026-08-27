/// Represents a keypoint landmark with 3D coordinates and confidence visibility.
class TargetKeypoint {
  final double x;
  final double y;
  final double z;
  final double visibility;

  const TargetKeypoint({
    required this.x,
    required this.y,
    required this.z,
    required this.visibility,
  });

  factory TargetKeypoint.fromJson(Map<String, dynamic> json) {
    return TargetKeypoint(
      x: (json['x'] as num).toDouble(),
      y: (json['y'] as num).toDouble(),
      z: (json['z'] as num).toDouble(),
      visibility: (json['visibility'] as num?)?.toDouble() ?? 0.99,
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'x': x,
      'y': y,
      'z': z,
      'visibility': visibility,
    };
  }
}

/// In-situ floating limb action badge annotation (e.g. "↗ Raise Right Arm", "🦵 Lift Leg").
class InSituActionTag {
  final int landmarkIndex;
  final String label;
  final String arrow;
  final String bodyPart;

  const InSituActionTag({
    required this.landmarkIndex,
    required this.label,
    required this.arrow,
    required this.bodyPart,
  });

  factory InSituActionTag.fromJson(Map<String, dynamic> json) {
    return InSituActionTag(
      landmarkIndex: (json['landmarkIndex'] as num?)?.toInt() ?? 0,
      label: json['label'] as String? ?? '',
      arrow: json['arrow'] as String? ?? '↗',
      bodyPart: json['bodyPart'] as String? ?? '',
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'landmarkIndex': landmarkIndex,
      'label': label,
      'arrow': arrow,
      'bodyPart': bodyPart,
    };
  }
}

/// Model representing a reference target pose with 33 keypoints, joint angle goals,
/// silhouette contour polygons, and in-situ directional limb action tags.
class TargetPose {
  final String id;
  final String name;
  final String category;
  final String description;
  final String difficulty;
  final String? imageUrl;
  final String? localImagePath;
  final List<TargetKeypoint> keypoints;
  final Map<String, double> targetJointAngles;
  final List<InSituActionTag> actionTags;
  final List<List<double>> silhouetteContour;
  final List<double> embedding;

  const TargetPose({
    required this.id,
    required this.name,
    required this.category,
    required this.description,
    required this.difficulty,
    this.imageUrl,
    this.localImagePath,
    required this.keypoints,
    required this.targetJointAngles,
    this.actionTags = const [],
    this.silhouetteContour = const [],
    required this.embedding,
  });

  factory TargetPose.fromJson(Map<String, dynamic> json) {
    final rawKeypoints = json['keypoints'] as List<dynamic>? ?? [];
    final keypointList = rawKeypoints
        .map((k) => TargetKeypoint.fromJson(k as Map<String, dynamic>))
        .toList();

    final rawAngles = json['targetJointAngles'] as Map<String, dynamic>? ?? {};
    final jointAngles = rawAngles.map(
      (key, value) => MapEntry(key, (value as num).toDouble()),
    );

    final rawTags = json['actionTags'] as List<dynamic>? ?? [];
    final tagsList = rawTags
        .map((t) => InSituActionTag.fromJson(t as Map<String, dynamic>))
        .toList();

    final rawContour = json['silhouetteContour'] as List<dynamic>? ?? [];
    final contourList = rawContour.map((c) {
      if (c is List) {
        return c.map((p) => (p as num).toDouble()).toList();
      }
      return <double>[];
    }).where((c) => c.length >= 2).toList();

    final rawEmbedding = json['embedding'] as List<dynamic>? ?? [];
    final embeddingList = rawEmbedding.map((e) => (e as num).toDouble()).toList();

    return TargetPose(
      id: json['id'] as String? ?? '',
      name: json['name'] as String? ?? 'Reference Pose',
      category: json['category'] as String? ?? 'Standing',
      description: json['description'] as String? ?? '',
      difficulty: json['difficulty'] as String? ?? 'Medium',
      imageUrl: json['imageUrl'] as String?,
      localImagePath: json['localImagePath'] as String?,
      keypoints: keypointList,
      targetJointAngles: jointAngles,
      actionTags: tagsList,
      silhouetteContour: contourList,
      embedding: embeddingList,
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'id': id,
      'name': name,
      'category': category,
      'description': description,
      'difficulty': difficulty,
      'imageUrl': imageUrl,
      'localImagePath': localImagePath,
      'keypoints': keypoints.map((k) => k.toJson()).toList(),
      'targetJointAngles': targetJointAngles,
      'actionTags': actionTags.map((t) => t.toJson()).toList(),
      'silhouetteContour': silhouetteContour,
      'embedding': embedding,
    };
  }
}
