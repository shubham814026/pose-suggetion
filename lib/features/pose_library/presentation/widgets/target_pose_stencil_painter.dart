import 'package:camera/camera.dart';
import 'package:flutter/material.dart';
import '../../models/target_pose.dart';

/// CustomPainter rendering a target reference pose outline stencil over the camera.
class TargetPoseStencilPainter extends CustomPainter {
  final TargetPose targetPose;
  final Color stencilColor;
  final CameraLensDirection lensDirection;

  final Map<String, Paint> _paintCache = {};

  TargetPoseStencilPainter({
    required this.targetPose,
    this.stencilColor = Colors.white70,
    required this.lensDirection,
  });

  Paint _getLinePaint(Color color) {
    final key = 'line_${color.value}';
    return _paintCache.putIfAbsent(
      key,
      () => Paint()
        ..color = color
        ..strokeWidth = 3.5
        ..style = PaintingStyle.stroke
        ..strokeCap = StrokeCap.round
        ..strokeJoin = StrokeJoin.round,
    );
  }

  Paint _getDotPaint(Color color) {
    final key = 'dot_${color.value}';
    return _paintCache.putIfAbsent(
      key,
      () => Paint()
        ..color = color
        ..style = PaintingStyle.fill,
    );
  }

  @override
  void paint(Canvas canvas, Size size) {
    if (targetPose.keypoints.isEmpty || size.width == 0 || size.height == 0) return;

    final linePaint = _getLinePaint(stencilColor);
    final dotPaint = _getDotPaint(stencilColor);
    final bool isFrontCamera = lensDirection == CameraLensDirection.front;

    // Convert keypoint list to name map
    final Map<String, PoseKeypointData> keypointMap = {
      for (var k in targetPose.keypoints) k.name: k
    };

    // Translate normalized keypoint (0.0 - 1.0) to canvas offsets
    Offset? getOffset(String name) {
      final k = keypointMap[name];
      if (k == null) return null;
      double x = k.x * size.width;
      double y = k.y * size.height;

      if (isFrontCamera) {
        x = size.width - x;
      }
      return Offset(x, y);
    }

    void drawBone(String name1, String name2) {
      final p1 = getOffset(name1);
      final p2 = getOffset(name2);
      if (p1 != null && p2 != null) {
        canvas.drawLine(p1, p2, linePaint);
      }
    }

    // Draw Target Skeleton Stencil Lines
    drawBone('left_shoulder', 'right_shoulder');
    drawBone('left_hip', 'right_hip');
    drawBone('left_shoulder', 'left_hip');
    drawBone('right_shoulder', 'right_hip');

    // Left Arm
    drawBone('left_shoulder', 'left_elbow');
    drawBone('left_elbow', 'left_wrist');

    // Right Arm
    drawBone('right_shoulder', 'right_elbow');
    drawBone('right_elbow', 'right_wrist');

    // Left Leg
    drawBone('left_hip', 'left_knee');
    drawBone('left_knee', 'left_ankle');

    // Right Leg
    drawBone('right_hip', 'right_knee');
    drawBone('right_knee', 'right_ankle');

    // Draw Target Joint Stencil Dots
    for (final k in targetPose.keypoints) {
      final offset = getOffset(k.name);
      if (offset != null) {
        canvas.drawCircle(offset, 4.5, dotPaint);
      }
    }
  }

  @override
  bool shouldRepaint(covariant TargetPoseStencilPainter oldDelegate) {
    return oldDelegate.targetPose.id != targetPose.id ||
        oldDelegate.stencilColor != stencilColor ||
        oldDelegate.lensDirection != lensDirection;
  }
}
