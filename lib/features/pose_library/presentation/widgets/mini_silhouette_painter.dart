import 'package:flutter/material.dart';
import '../../data/models/target_pose.dart';
import '../../utils/silhouette_contour_generator.dart';

/// Lightweight painter that renders a vector silhouette thumbnail preview
/// of a target pose inside bottom carousel cards.
class MiniSilhouettePainter extends CustomPainter {
  final TargetPose pose;
  final bool isSelected;
  final Color accentColor;

  const MiniSilhouettePainter({
    required this.pose,
    this.isSelected = false,
    this.accentColor = const Color(0xFF38BDF8),
  });

  @override
  void paint(Canvas canvas, Size size) {
    if (pose.keypoints.isEmpty) return;

    // 1. Draw Dynamic Body Silhouette Contour
    final dynamicBodyPath = SilhouetteContourGenerator.generateDynamicBodyPath(
      keypoints: pose.keypoints,
      canvasSize: size,
      isFrontCamera: false,
    );

    final fillPaint = Paint()
      ..color = isSelected ? accentColor.withAlpha(60) : Colors.white.withAlpha(25)
      ..style = PaintingStyle.fill;

    final strokePaint = Paint()
      ..color = isSelected ? accentColor : Colors.white.withAlpha(180)
      ..strokeWidth = 1.2
      ..style = PaintingStyle.stroke;

    canvas.drawPath(dynamicBodyPath, fillPaint);
    canvas.drawPath(dynamicBodyPath, strokePaint);

    // 2. Draw Essential Stick Bone Connections
    final linePaint = Paint()
      ..color = isSelected ? accentColor : Colors.white.withAlpha(200)
      ..strokeWidth = 1.4
      ..strokeCap = StrokeCap.round;

    final kps = pose.keypoints;

    Offset getOffset(int idx) {
      if (idx >= kps.length) return Offset.zero;
      return Offset(
        kps[idx].x.clamp(0.0, 1.0) * size.width,
        kps[idx].y.clamp(0.0, 1.0) * size.height,
      );
    }

    final connections = [
      (11, 12), (11, 23), (12, 24), (23, 24), // Torso
      (11, 13), (13, 15),                     // Left Arm
      (12, 14), (14, 16),                     // Right Arm
      (23, 25), (25, 27),                     // Left Leg
      (24, 26), (26, 28),                     // Right Leg
      (0, 11), (0, 12),                       // Head / Neck
    ];

    for (final conn in connections) {
      final p1 = getOffset(conn.$1);
      final p2 = getOffset(conn.$2);
      if (p1 != Offset.zero && p2 != Offset.zero) {
        canvas.drawLine(p1, p2, linePaint);
      }
    }

    // 3. Head Joint Circle
    final headPos = getOffset(0);
    if (headPos != Offset.zero) {
      final headPaint = Paint()
        ..color = isSelected ? accentColor : Colors.white
        ..style = PaintingStyle.fill;
      canvas.drawCircle(headPos, 2.5, headPaint);
    }
  }

  @override
  bool shouldRepaint(covariant MiniSilhouettePainter oldDelegate) {
    return oldDelegate.pose.id != pose.id ||
        oldDelegate.isSelected != isSelected ||
        oldDelegate.accentColor != accentColor;
  }
}
