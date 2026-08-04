import 'package:camera/camera.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:google_mlkit_pose_detection/google_mlkit_pose_detection.dart';

/// Utility function converting [CameraImage] to ML Kit [InputImage].
/// Handles Android YUV420 vs iOS BGRA8888 format differences.
InputImage? convertCameraImageToInputImage(
  CameraImage image,
  CameraDescription camera,
) {
  final sensorOrientation = camera.sensorOrientation;
  InputImageRotation? rotation;

  if (defaultTargetPlatform == TargetPlatform.android) {
    var rotationCompensation = sensorOrientation;
    // Android device orientation compensation
    rotation = InputImageRotationValue.fromRawValue(rotationCompensation);
  } else if (defaultTargetPlatform == TargetPlatform.iOS) {
    rotation = InputImageRotationValue.fromRawValue(sensorOrientation);
  }
  rotation ??= InputImageRotation.rotation0deg;

  // Format mapping
  final format = InputImageFormatValue.fromRawValue(image.format.raw);
  if (format == null) return null;

  // Check valid plane data
  if (image.planes.isEmpty) return null;

  // Handle single-plane (e.g. iOS BGRA) vs multi-plane (Android YUV420)
  final Uint8List bytes;
  if (image.planes.length == 1) {
    bytes = image.planes[0].bytes;
  } else {
    // Concatenate bytes from all YUV planes
    final WriteBuffer allBytes = WriteBuffer();
    for (final Plane plane in image.planes) {
      allBytes.putUint8List(plane.bytes);
    }
    bytes = allBytes.done().buffer.asUint8List();
  }

  final metadata = InputImageMetadata(
    size: Size(image.width.toDouble(), image.height.toDouble()),
    rotation: rotation,
    format: format,
    bytesPerRow: image.planes[0].bytesPerRow,
  );

  return InputImage.fromBytes(
    bytes: bytes,
    metadata: metadata,
  );
}
