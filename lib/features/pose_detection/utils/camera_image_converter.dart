import 'dart:io';
import 'package:camera/camera.dart';
import 'package:flutter/services.dart';
import 'package:google_mlkit_pose_detection/google_mlkit_pose_detection.dart';

class CameraImageConverter {
  static InputImage? inputImageFromCameraImage({
    required CameraImage image,
    required CameraDescription camera,
  }) {
    try {
      final sensorOrientation = camera.sensorOrientation;
      InputImageRotation? rotation;

      if (Platform.isAndroid) {
        var rotationCompensation = _orientations[_getDeviceOrientation()];
        if (rotationCompensation == null) return null;
        if (camera.lensDirection == CameraLensDirection.front) {
          // Front-facing camera
          rotationCompensation = (sensorOrientation + rotationCompensation) % 360;
        } else {
          // Back-facing camera
          rotationCompensation = (sensorOrientation - rotationCompensation + 360) % 360;
        }
        rotation = InputImageRotationValue.fromRawValue(rotationCompensation);
      } else if (Platform.isIOS) {
        rotation = InputImageRotationValue.fromRawValue(sensorOrientation);
      }
      rotation ??= InputImageRotation.rotation0deg;

      if (image.planes.isEmpty) return null;

      Uint8List bytes;
      InputImageFormat format;
      int bytesPerRow;

      if (Platform.isAndroid) {
        bytes = _getNv21Bytes(image);
        format = InputImageFormat.nv21;
        bytesPerRow = image.planes[0].bytesPerRow;
      } else {
        // iOS BGRA8888
        final WriteBuffer allBytes = WriteBuffer();
        for (final Plane plane in image.planes) {
          allBytes.putUint8List(plane.bytes);
        }
        bytes = allBytes.done().buffer.asUint8List();
        format = InputImageFormat.bgra8888;
        bytesPerRow = image.planes[0].bytesPerRow;
      }

      return InputImage.fromBytes(
        bytes: bytes,
        metadata: InputImageMetadata(
          size: Size(image.width.toDouble(), image.height.toDouble()),
          rotation: rotation,
          format: format,
          bytesPerRow: bytesPerRow,
        ),
      );
    } catch (e) {
      return null;
    }
  }

  static Uint8List _getNv21Bytes(CameraImage image) {
    // 1 plane (Native NV21 contiguous buffer)
    if (image.planes.length == 1) {
      return image.planes[0].bytes;
    }

    // 2 planes (Semi-planar Y + VU)
    if (image.planes.length == 2) {
      final WriteBuffer buffer = WriteBuffer();
      buffer.putUint8List(image.planes[0].bytes);
      buffer.putUint8List(image.planes[1].bytes);
      return buffer.done().buffer.asUint8List();
    }

    // 3 planes (YUV420_888)
    final int width = image.width;
    final int height = image.height;
    final int ySize = width * height;
    final int uvSize = ySize ~/ 2;
    final Uint8List nv21 = Uint8List(ySize + uvSize);

    final Plane yPlane = image.planes[0];
    final Plane uPlane = image.planes[1];
    final Plane vPlane = image.planes[2];

    final Uint8List yBuffer = yPlane.bytes;
    final Uint8List uBuffer = uPlane.bytes;
    final Uint8List vBuffer = vPlane.bytes;

    final int yRowStride = yPlane.bytesPerRow;

    // Fast path: direct range copy when row stride matches width (0.1ms memory transfer)
    if (yRowStride == width && yBuffer.length >= ySize) {
      nv21.setRange(0, ySize, yBuffer);
    } else {
      int yIndex = 0;
      final int yPixelStride = yPlane.bytesPerPixel ?? 1;
      for (int r = 0; r < height; r++) {
        final int rowStart = r * yRowStride;
        for (int c = 0; c < width; c++) {
          final int pos = rowStart + c * yPixelStride;
          if (pos < yBuffer.length && yIndex < nv21.length) {
            nv21[yIndex++] = yBuffer[pos];
          }
        }
      }
    }

    int uvIndex = ySize;
    final int uRowStride = uPlane.bytesPerRow;
    final int uPixelStride = uPlane.bytesPerPixel ?? 2;
    final int vRowStride = vPlane.bytesPerRow;
    final int vPixelStride = vPlane.bytesPerPixel ?? 2;
    final int uvWidth = width ~/ 2;
    final int uvHeight = height ~/ 2;

    for (int r = 0; r < uvHeight; r++) {
      final int uRowStart = r * uRowStride;
      final int vRowStart = r * vRowStride;
      for (int c = 0; c < uvWidth; c++) {
        final int uPos = uRowStart + c * uPixelStride;
        final int vPos = vRowStart + c * vPixelStride;

        final byteV = (vPos < vBuffer.length) ? vBuffer[vPos] : 128;
        final byteU = (uPos < uBuffer.length) ? uBuffer[uPos] : 128;

        if (uvIndex + 1 < nv21.length) {
          nv21[uvIndex++] = byteV;
          nv21[uvIndex++] = byteU;
        }
      }
    }

    return nv21;
  }

  static const Map<DeviceOrientation, int> _orientations = {
    DeviceOrientation.portraitUp: 0,
    DeviceOrientation.landscapeLeft: 90,
    DeviceOrientation.portraitDown: 180,
    DeviceOrientation.landscapeRight: 270,
  };

  static DeviceOrientation _getDeviceOrientation() {
    return DeviceOrientation.portraitUp;
  }
}
