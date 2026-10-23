import 'dart:io';
import 'package:flutter/material.dart';
import '../../../../core/theme/app_theme.dart';
import '../../data/models/target_pose.dart';

/// Renders the real reference photography image of a TargetPose from local disk or web URL.
class PoseImageView extends StatelessWidget {
  final TargetPose pose;
  final BoxFit fit;
  final double? width;
  final double? height;
  final BorderRadius? borderRadius;

  const PoseImageView({
    super.key,
    required this.pose,
    this.fit = BoxFit.cover,
    this.width,
    this.height,
    this.borderRadius,
  });

  @override
  Widget build(BuildContext context) {
    Widget imageWidget;

    final localPath = pose.localImagePath;
    if (localPath != null && localPath.isNotEmpty && File(localPath).existsSync()) {
      imageWidget = Image.file(
        File(localPath),
        width: width,
        height: height,
        fit: fit,
        errorBuilder: (_, __, ___) => _buildNetworkOrPlaceholder(),
      );
    } else {
      imageWidget = _buildNetworkOrPlaceholder();
    }

    if (borderRadius != null) {
      return ClipRRect(
        borderRadius: borderRadius!,
        child: imageWidget,
      );
    }
    return imageWidget;
  }

  Widget _buildNetworkOrPlaceholder() {
    final url = pose.imageUrl;
    if (url != null && url.isNotEmpty && url.startsWith('http')) {
      return Image.network(
        url,
        width: width,
        height: height,
        fit: fit,
        errorBuilder: (_, __, ___) => _buildPlaceholder(),
        loadingBuilder: (context, child, loadingProgress) {
          if (loadingProgress == null) return child;
          return Container(
            width: width,
            height: height,
            color: const Color(0xFF1E293B),
            child: const Center(
              child: SizedBox(
                width: 18,
                height: 18,
                child: CircularProgressIndicator(
                  strokeWidth: 2,
                  color: AppTheme.primaryCyan,
                ),
              ),
            ),
          );
        },
      );
    }
    return _buildPlaceholder();
  }

  Widget _buildPlaceholder() {
    return Container(
      width: width,
      height: height,
      color: const Color(0xFF1E293B),
      child: Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          mainAxisSize: MainAxisSize.min,
          children: [
            const Icon(Icons.person, color: Colors.white54, size: 24),
            const SizedBox(height: 2),
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 4),
              child: Text(
                pose.category,
                style: const TextStyle(color: Colors.white38, fontSize: 8),
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                textAlign: TextAlign.center,
              ),
            ),
          ],
        ),
      ),
    );
  }
}

