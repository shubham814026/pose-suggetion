import 'package:flutter/material.dart';
import '../../data/models/target_pose.dart';
import '../../utils/silhouette_contour_generator.dart';

/// CustomPainter that renders a Huawei-style stylized white body silhouette stencil
/// and in-situ directional action badges dynamically generated from 33 3D keypoints.
class TargetPoseStencilPainter extends CustomPainter {
  final TargetPose? targetPose;
  final Color stencilColor;
  final bool isFrontCamera;
  final bool showSilhouette;
  final bool showActionTags;

  TargetPoseStencilPainter({
    required this.targetPose,
    this.stencilColor = const Color(0xFF38BDF8), // Sky blue HUD accent
    this.isFrontCamera = true,
    this.showSilhouette = true,
    this.showActionTags = true,
  });

  @override
  void paint(Canvas canvas, Size size) {
    if (targetPose == null || targetPose!.keypoints.isEmpty) return;

    final keypoints = targetPose!.keypoints;

    // 1. Draw Dynamic Anatomical Body Silhouette Contour (Huawei AI / Vogue Stencil Style)
    if (showSilhouette) {
      Path dynamicBodyPath = SilhouetteContourGenerator.generateDynamicBodyPath(
        keypoints: keypoints,
        canvasSize: size,
        isFrontCamera: isFrontCamera,
      );

      // Fallback: If dynamic skeleton contour generation is empty, use stored silhouette contour points
      if (dynamicBodyPath.getBounds().isEmpty && targetPose!.silhouetteContour.isNotEmpty) {
        final contourPath = Path();
        final contour = targetPose!.silhouetteContour;
        for (int i = 0; i < contour.length; i++) {
          double x = contour[i][0] * size.width;
          if (isFrontCamera) x = size.width - x;
          double y = contour[i][1] * size.height;
          if (i == 0) {
            contourPath.moveTo(x, y);
          } else {
            contourPath.lineTo(x, y);
          }
        }
        contourPath.close();
        dynamicBodyPath = contourPath;
      }

      final contourGlowPaint = Paint()
        ..color = Colors.white.withAlpha(50)
        ..strokeWidth = 6.0
        ..style = PaintingStyle.stroke
        ..maskFilter = const MaskFilter.blur(BlurStyle.normal, 4.0);

      final contourStrokePaint = Paint()
        ..color = Colors.white.withAlpha(220)
        ..strokeWidth = 2.5
        ..style = PaintingStyle.stroke
        ..strokeCap = StrokeCap.round;

      final contourFillPaint = Paint()
        ..color = stencilColor.withAlpha(35)
        ..style = PaintingStyle.fill;

      canvas.drawPath(dynamicBodyPath, contourFillPaint);
      canvas.drawPath(dynamicBodyPath, contourGlowPaint);
      canvas.drawPath(dynamicBodyPath, contourStrokePaint);
    }

    // 2. Draw Skeleton Bones
    final linePaint = Paint()
      ..color = Colors.white.withAlpha(200)
      ..strokeWidth = 3.0
      ..style = PaintingStyle.stroke
      ..strokeCap = StrokeCap.round;

    final glowPaint = Paint()
      ..color = stencilColor.withAlpha(100)
      ..strokeWidth = 7.0
      ..style = PaintingStyle.stroke
      ..strokeCap = StrokeCap.round;

    Offset getKeypointOffset(int idx) {
      if (idx >= keypoints.length) return Offset.zero;
      final kp = keypoints[idx];
      double x = kp.x * size.width;
      if (isFrontCamera) {
        x = size.width - x;
      }
      double y = kp.y * size.height;
      return Offset(x, y);
    }

    final connections = [
      // Torso
      (11, 12), (11, 23), (12, 24), (23, 24),
      // Left Arm
      (11, 13), (13, 15),
      // Right Arm
      (12, 14), (14, 16),
      // Left Leg
      (23, 25), (25, 27),
      // Right Leg
      (24, 26), (26, 28),
      // Neck
      (0, 11), (0, 12),
    ];

    for (final conn in connections) {
      final p1 = getKeypointOffset(conn.$1);
      final p2 = getKeypointOffset(conn.$2);

      if (p1 != Offset.zero && p2 != Offset.zero) {
        canvas.drawLine(p1, p2, glowPaint);
        canvas.drawLine(p1, p2, linePaint);
      }
    }

    // 3. Render Joint Nodes
    final jointPaint = Paint()
      ..color = Colors.white
      ..style = PaintingStyle.fill;

    final outerJointPaint = Paint()
      ..color = stencilColor.withAlpha(180)
      ..style = PaintingStyle.stroke
      ..strokeWidth = 2.0;

    final majorJointIndices = [0, 11, 12, 13, 14, 15, 16, 23, 24, 25, 26, 27, 28];
    for (final idx in majorJointIndices) {
      final p = getKeypointOffset(idx);
      if (p != Offset.zero) {
        canvas.drawCircle(p, 4.0, jointPaint);
        canvas.drawCircle(p, 6.0, outerJointPaint);
      }
    }

    // 4. Render In-Situ Directional Action Badges
    if (showActionTags && targetPose!.actionTags.isNotEmpty) {
      for (final tag in targetPose!.actionTags) {
        final pos = getKeypointOffset(tag.landmarkIndex);
        if (pos == Offset.zero) continue;

        final badgeOffset = Offset(pos.dx + 12, pos.dy - 12);
        _drawActionBadge(canvas, size, badgeOffset, '${tag.arrow} ${tag.label}');
      }
    }
  }

  void _drawActionBadge(Canvas canvas, Size canvasSize, Offset offset, String text) {
    final textSpan = TextSpan(
      text: text,
      style: const TextStyle(
        color: Colors.white,
        fontSize: 11,
        fontWeight: FontWeight.bold,
        shadows: [Shadow(color: Colors.black, blurRadius: 4)],
      ),
    );

    final textPainter = TextPainter(
      text: textSpan,
      textDirection: TextDirection.ltr,
    )..layout();

    const padding = EdgeInsets.symmetric(horizontal: 8, vertical: 4);
    final badgeWidth = textPainter.width + padding.horizontal;
    final badgeHeight = textPainter.height + padding.vertical;

    final clampedX = offset.dx.clamp(8.0, (canvasSize.width - badgeWidth - 8.0).clamp(8.0, canvasSize.width));
    final clampedY = offset.dy.clamp(8.0, (canvasSize.height - badgeHeight - 8.0).clamp(8.0, canvasSize.height));

    final badgeRect = RRect.fromRectAndRadius(
      Rect.fromLTWH(clampedX, clampedY, badgeWidth, badgeHeight),
      const Radius.circular(8),
    );

    final badgeBgPaint = Paint()
      ..color = Colors.black.withAlpha(200)
      ..style = PaintingStyle.fill;

    final badgeBorderPaint = Paint()
      ..color = stencilColor.withAlpha(200)
      ..style = PaintingStyle.stroke
      ..strokeWidth = 1.0;

    canvas.drawRRect(badgeRect, badgeBgPaint);
    canvas.drawRRect(badgeRect, badgeBorderPaint);

    textPainter.paint(
      canvas,
      Offset(clampedX + padding.left, clampedY + padding.top),
    );
  }

  @override
  bool shouldRepaint(covariant TargetPoseStencilPainter oldDelegate) {
    return oldDelegate.targetPose?.id != targetPose?.id ||
        oldDelegate.isFrontCamera != isFrontCamera;
  }
}
