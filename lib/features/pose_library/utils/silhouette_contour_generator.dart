import 'package:flutter/material.dart';
import '../data/models/target_pose.dart';

/// Dynamically generates smooth 2D silhouette body contours and limb outlines
/// directly from 33 3D neural keypoint coordinates.
class SilhouetteContourGenerator {
  /// Generates a Path wrapping the 33 keypoints as a smooth anatomical body contour.
  static Path generateDynamicBodyPath({
    required List<TargetKeypoint> keypoints,
    required Size canvasSize,
    bool isFrontCamera = false,
  }) {
    final path = Path();
    if (keypoints.length < 17) return path;

    Offset kp(int idx) {
      if (idx >= keypoints.length) return Offset.zero;
      final p = keypoints[idx];
      double x = p.x * canvasSize.width;
      if (isFrontCamera) {
        x = canvasSize.width - x;
      }
      double y = p.y * canvasSize.height;
      return Offset(x, y);
    }

    final nose = kp(0);
    final lShoulder = kp(11);
    final rShoulder = kp(12);
    final lElbow = kp(13);
    final rElbow = kp(14);
    final lWrist = kp(15);
    final rWrist = kp(16);
    final lHip = kp(23);
    final rHip = kp(24);
    final lKnee = kp(25);
    final rKnee = kp(26);
    final lAnkle = kp(27);
    final rAnkle = kp(28);

    // Compute scale metric from shoulder breadth
    final double shoulderDist = (lShoulder - rShoulder).distance;
    final double unit = (shoulderDist > 10.0 ? shoulderDist : canvasSize.width * 0.20);
    final double headRadius = unit * 0.38;
    final double limbRadius = unit * 0.14;
    final double torsoRadius = unit * 0.22;

    // 1. Head Oval
    final headCenter = (nose != Offset.zero)
        ? nose
        : Offset((lShoulder.dx + rShoulder.dx) / 2, (lShoulder.dy + rShoulder.dy) / 2 - headRadius * 1.2);
    path.addOval(Rect.fromCircle(center: headCenter, radius: headRadius));

    // 2. Torso (Shoulders to Hips)
    if (lShoulder != Offset.zero && rShoulder != Offset.zero && lHip != Offset.zero && rHip != Offset.zero) {
      final torsoPath = Path();
      final midHip = Offset((lHip.dx + rHip.dx) / 2, (lHip.dy + rHip.dy) / 2);
      final midShoulder = Offset((lShoulder.dx + rShoulder.dx) / 2, (lShoulder.dy + rShoulder.dy) / 2);

      final lShoulderExt = _offsetPerp(lShoulder, midShoulder, torsoRadius * 0.6);
      final rShoulderExt = _offsetPerp(rShoulder, midShoulder, torsoRadius * 0.6);
      final lHipExt = _offsetPerp(lHip, midHip, torsoRadius * 0.5);
      final rHipExt = _offsetPerp(rHip, midHip, torsoRadius * 0.5);

      torsoPath.moveTo(lShoulderExt.dx, lShoulderExt.dy);
      torsoPath.lineTo(rShoulderExt.dx, rShoulderExt.dy);
      torsoPath.lineTo(rHipExt.dx, rHipExt.dy);
      torsoPath.lineTo(lHipExt.dx, lHipExt.dy);
      torsoPath.close();
      path.addPath(torsoPath, Offset.zero);
    }

    // 3. Limbs (Capsules around bone segments)
    void addLimbSegment(Offset a, Offset b, double radius) {
      if (a == Offset.zero || b == Offset.zero) return;
      final segPath = _createCapsulePath(a, b, radius);
      path.addPath(segPath, Offset.zero);
    }

    // Arms
    addLimbSegment(lShoulder, lElbow, limbRadius * 1.1);
    addLimbSegment(lElbow, lWrist, limbRadius * 0.85);
    addLimbSegment(rShoulder, rElbow, limbRadius * 1.1);
    addLimbSegment(rElbow, rWrist, limbRadius * 0.85);

    // Legs
    if (keypoints.length > 28) {
      addLimbSegment(lHip, lKnee, limbRadius * 1.4);
      addLimbSegment(lKnee, lAnkle, limbRadius * 1.1);
      addLimbSegment(rHip, rKnee, limbRadius * 1.4);
      addLimbSegment(rKnee, rAnkle, limbRadius * 1.1);
    }

    return path;
  }

  static Path _createCapsulePath(Offset p1, Offset p2, double radius) {
    final path = Path();
    final d = p2 - p1;
    final dist = d.distance;
    if (dist < 1.0) return path;

    final nx = -d.dy / dist;
    final ny = d.dx / dist;

    final p1L = Offset(p1.dx + nx * radius, p1.dy + ny * radius);
    final p1R = Offset(p1.dx - nx * radius, p1.dy - ny * radius);
    final p2L = Offset(p2.dx + nx * radius, p2.dy + ny * radius);
    final p2R = Offset(p2.dx - nx * radius, p2.dy - ny * radius);

    path.moveTo(p1L.dx, p1L.dy);
    path.lineTo(p2L.dx, p2L.dy);
    path.arcToPoint(p2R, radius: Radius.circular(radius));
    path.lineTo(p1R.dx, p1R.dy);
    path.arcToPoint(p1L, radius: Radius.circular(radius));
    path.close();

    return path;
  }

  static Offset _offsetPerp(Offset p, Offset ref, double distance) {
    final d = p - ref;
    final len = d.distance;
    if (len < 0.001) return p;
    return Offset(p.dx + (d.dx / len) * distance, p.dy + (d.dy / len) * distance);
  }
}
