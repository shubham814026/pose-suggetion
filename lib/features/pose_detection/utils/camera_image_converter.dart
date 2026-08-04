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
    // Direct memory copy across YUV planes avoiding WriteBuffer GC overhead
    final int totalBytes = image.planes.fold<int>(0, (sum, p) => sum + p.bytes.length);
    final Uint8List concatenated = Uint8List(totalBytes);
    int offset = 0;
    for (final Plane plane in image.planes) {
      concatenated.setRange(offset, offset + plane.bytes.length, plane.bytes);
      offset += plane.bytes.length;
    }
    bytes = concatenated;
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
