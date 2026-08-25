import 'package:camera/camera.dart';
import 'package:flutter/material.dart';
import 'package:google_mlkit_pose_detection/google_mlkit_pose_detection.dart';
import '../../../../core/theme/app_theme.dart';

class PoseOverlayPainter extends CustomPainter {
  final List<Pose> poses;
  final Size previewSize;
  final CameraLensDirection lensDirection;

  static final Paint _bonePaint = Paint()
    ..color = AppTheme.primaryCyan
    ..strokeWidth = 3.5
    ..style = PaintingStyle.stroke
    ..strokeCap = StrokeCap.round;

  static final Paint _jointDotPaint = Paint()
    ..color = AppTheme.accentViolet
    ..style = PaintingStyle.fill;

  static final Paint _jointDotOuterPaint = Paint()
    ..color = AppTheme.successGreen
    ..style = PaintingStyle.stroke
    ..strokeWidth = 2.0;

  PoseOverlayPainter({
    required this.poses,
    required this.previewSize,
    required this.lensDirection,
  });

  @override
  void paint(Canvas canvas, Size size) {
    if (poses.isEmpty || previewSize.width == 0 || previewSize.height == 0) return;

    final double scaleX = size.width / previewSize.width;
    final double scaleY = size.height / previewSize.height;

    for (final pose in poses) {
      void drawBone(PoseLandmarkType type1, PoseLandmarkType type2) {
        final landmark1 = pose.landmarks[type1];
        final landmark2 = pose.landmarks[type2];
        if (landmark1 != null && landmark2 != null && landmark1.likelihood > 0.15 && landmark2.likelihood > 0.15) {
          final p1 = _translateXy(landmark1.x, landmark1.y, size, scaleX, scaleY);
          final p2 = _translateXy(landmark2.x, landmark2.y, size, scaleX, scaleY);
          canvas.drawLine(p1, p2, _bonePaint);
        }
      }

      // Torso
      drawBone(PoseLandmarkType.leftShoulder, PoseLandmarkType.rightShoulder);
      drawBone(PoseLandmarkType.leftHip, PoseLandmarkType.rightHip);
      drawBone(PoseLandmarkType.leftShoulder, PoseLandmarkType.leftHip);
      drawBone(PoseLandmarkType.rightShoulder, PoseLandmarkType.rightHip);

      // Arms
      drawBone(PoseLandmarkType.leftShoulder, PoseLandmarkType.leftElbow);
      drawBone(PoseLandmarkType.leftElbow, PoseLandmarkType.leftWrist);
      drawBone(PoseLandmarkType.rightShoulder, PoseLandmarkType.rightElbow);
      drawBone(PoseLandmarkType.rightElbow, PoseLandmarkType.rightWrist);

      // Legs
      drawBone(PoseLandmarkType.leftHip, PoseLandmarkType.leftKnee);
      drawBone(PoseLandmarkType.leftKnee, PoseLandmarkType.leftAnkle);
      drawBone(PoseLandmarkType.rightHip, PoseLandmarkType.rightKnee);
      drawBone(PoseLandmarkType.rightKnee, PoseLandmarkType.rightAnkle);

      // Draw Landmark Dots
      pose.landmarks.forEach((_, landmark) {
        if (landmark.likelihood > 0.15) {
          final point = _translateXy(landmark.x, landmark.y, size, scaleX, scaleY);
          canvas.drawCircle(point, 5.0, _jointDotPaint);
          canvas.drawCircle(point, 7.0, _jointDotOuterPaint);
        }
      });
    }
  }

  Offset _translateXy(double x, double y, Size canvasSize, double scaleX, double scaleY) {
    double scaledX = x * scaleX;
    double scaledY = y * scaleY;

    if (lensDirection == CameraLensDirection.front) {
      scaledX = canvasSize.width - scaledX;
    }

    return Offset(scaledX, scaledY);
  }

  @override
  bool shouldRepaint(covariant PoseOverlayPainter oldDelegate) {
    return oldDelegate.poses != poses ||
        oldDelegate.previewSize != previewSize ||
        oldDelegate.lensDirection != lensDirection;
  }
}
