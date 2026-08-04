import 'package:camera/camera.dart';
import 'package:flutter/material.dart';
import 'package:google_mlkit_pose_detection/google_mlkit_pose_detection.dart';
import '../../../../core/theme/app_theme.dart';

/// CustomPainter rendering real-time ML Kit Pose keypoints and skeleton joint lines.
class PoseOverlayPainter extends CustomPainter {
  final List<Pose> poses;
  final Size imageSize;
  final CameraLensDirection lensDirection;

  PoseOverlayPainter({
    required this.poses,
    required this.imageSize,
    required this.lensDirection,
  });

  @override
  void paint(Canvas canvas, Size size) {
    if (poses.isEmpty || imageSize.width == 0 || imageSize.height == 0) return;

    final Paint landmarkPaint = Paint()
      ..color = AppTheme.primaryCyan
      ..style = PaintingStyle.fill;

    final Paint jointLinePaint = Paint()
      ..color = AppTheme.successGreen
      ..strokeWidth = 3.0
      ..style = PaintingStyle.stroke
      ..strokeCap = StrokeCap.round;

    final Paint headPointPaint = Paint()
      ..color = AppTheme.accentViolet
      ..style = PaintingStyle.fill;

    // Coordinate scaling factors
    final double scaleX = size.width / imageSize.width;
    final double scaleY = size.height / imageSize.height;
    final bool isFrontCamera = lensDirection == CameraLensDirection.front;

    for (final pose in poses) {
      // Helper function to translate ML Kit landmark coordinates to canvas offsets
      Offset translateXFile(PoseLandmark landmark) {
        double x = landmark.x * scaleX;
        double y = landmark.y * scaleY;

        // Mirror X axis if using front camera (selfie view)
        if (isFrontCamera) {
          x = size.width - x;
        }

        return Offset(x, y);
      }

      // Draw skeleton joint connection lines
      void drawLine(PoseLandmarkType type1, PoseLandmarkType type2) {
        final landmark1 = pose.landmarks[type1];
        final landmark2 = pose.landmarks[type2];

        if (landmark1 != null && landmark2 != null) {
          // Render line only if both keypoints have acceptable likelihood confidence
          if (landmark1.likelihood > 0.5 && landmark2.likelihood > 0.5) {
            canvas.drawLine(
              translateXFile(landmark1),
              translateXFile(landmark2),
              jointLinePaint,
            );
          }
        }
      }

      // Torso & Limbs Skeleton connections
      drawLine(PoseLandmarkType.leftShoulder, PoseLandmarkType.rightShoulder);
      drawLine(PoseLandmarkType.leftHip, PoseLandmarkType.rightHip);
      drawLine(PoseLandmarkType.leftShoulder, PoseLandmarkType.leftHip);
      drawLine(PoseLandmarkType.rightShoulder, PoseLandmarkType.rightHip);

      // Left Arm
      drawLine(PoseLandmarkType.leftShoulder, PoseLandmarkType.leftElbow);
      drawLine(PoseLandmarkType.leftElbow, PoseLandmarkType.leftWrist);

      // Right Arm
      drawLine(PoseLandmarkType.rightShoulder, PoseLandmarkType.rightElbow);
      drawLine(PoseLandmarkType.rightElbow, PoseLandmarkType.rightWrist);

      // Left Leg
      drawLine(PoseLandmarkType.leftHip, PoseLandmarkType.leftKnee);
      drawLine(PoseLandmarkType.leftKnee, PoseLandmarkType.leftAnkle);

      // Right Leg
      drawLine(PoseLandmarkType.rightHip, PoseLandmarkType.rightKnee);
      drawLine(PoseLandmarkType.rightKnee, PoseLandmarkType.rightAnkle);

      // Draw keypoint dots
      pose.landmarks.forEach((type, landmark) {
        if (landmark.likelihood > 0.5) {
          final offset = translateXFile(landmark);

          final bool isFacial = type == PoseLandmarkType.nose ||
              type == PoseLandmarkType.leftEye ||
              type == PoseLandmarkType.rightEye ||
              type == PoseLandmarkType.leftEar ||
              type == PoseLandmarkType.rightEar;

          canvas.drawCircle(
            offset,
            isFacial ? 4.0 : 6.0,
            isFacial ? headPointPaint : landmarkPaint,
          );
        }
      });
    }
  }

  @override
  bool shouldRepaint(covariant PoseOverlayPainter oldDelegate) {
    return oldDelegate.poses.length != poses.length ||
        oldDelegate.imageSize != imageSize ||
        oldDelegate.lensDirection != lensDirection ||
        (poses.isNotEmpty && oldDelegate.poses.isNotEmpty && oldDelegate.poses.first != poses.first);
  }
}
