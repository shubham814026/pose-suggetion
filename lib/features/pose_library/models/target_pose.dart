class TargetPose {
  final String id;
  final String name;
  final String category;
  final List<String> tags;
  final String description;
  final Map<String, double> targetAngles;
  final List<PoseKeypointData> keypoints;
  final String? thumbnailAsset;

  const TargetPose({
    required this.id,
    required this.name,
    required this.category,
    required this.tags,
    required this.description,
    required this.targetAngles,
    required this.keypoints,
    this.thumbnailAsset,
  });

  factory TargetPose.fromJson(Map<String, dynamic> json) {
    final Map<String, dynamic> anglesMap = json['target_angles'] ?? {};
    final Map<String, double> parsedAngles = anglesMap.map(
      (key, value) => MapEntry(key, (value as num).toDouble()),
    );

    final List<dynamic> keypointsList = json['keypoints'] ?? [];
    final parsedKeypoints = keypointsList
        .map((k) => PoseKeypointData.fromJson(k as Map<String, dynamic>))
        .toList();

    return TargetPose(
      id: json['id'] as String,
      name: json['name'] as String,
      category: json['category'] as String,
      tags: List<String>.from(json['tags'] ?? []),
      description: json['description'] as String,
      targetAngles: parsedAngles,
      keypoints: parsedKeypoints,
      thumbnailAsset: json['thumbnail_asset'] as String?,
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'id': id,
      'name': name,
      'category': category,
      'tags': tags,
      'description': description,
      'target_angles': targetAngles,
      'keypoints': keypoints.map((k) => k.toJson()).toList(),
      'thumbnail_asset': thumbnailAsset,
    };
  }
}

class PoseKeypointData {
  final String name;
  final double x;
  final double y;

  const PoseKeypointData({
    required this.name,
    required this.x,
    required this.y,
  });

  factory PoseKeypointData.fromJson(Map<String, dynamic> json) {
    return PoseKeypointData(
      name: json['name'] as String,
      x: (json['x'] as num).toDouble(),
      y: (json['y'] as num).toDouble(),
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'name': name,
      'x': x,
      'y': y,
    };
  }
}
