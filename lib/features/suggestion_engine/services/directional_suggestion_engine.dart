import 'package:google_mlkit_pose_detection/google_mlkit_pose_detection.dart';
import '../../pose_library/data/models/target_pose.dart';
import 'pose_comparison_engine.dart';

/// Class containing on-screen and spoken directional suggestion results.
class SuggestionResult {
  final String textPrompt;
  final String speechPrompt;
  final String primaryJoint;
  final double maxErrorDeg;
  final double alignmentScore;

  const SuggestionResult({
    required this.textPrompt,
    required this.speechPrompt,
    required this.primaryJoint,
    required this.maxErrorDeg,
    required this.alignmentScore,
  });
}

/// Service responsible for evaluating joint deltas and generating human-readable
/// directional text and speech instructions for camera HUD rendering.
class DirectionalSuggestionEngine {
  /// Evaluates live pose alignment against target pose and generates clear directional cues.
  static SuggestionResult generateSuggestion({
    required Pose livePose,
    required TargetPose targetPose,
  }) {
    final double alignmentScore = PoseComparisonEngine.computeAlignmentScore(
      livePose: livePose,
      targetPose: targetPose,
    );

    if (alignmentScore >= 85.0) {
      return SuggestionResult(
        textPrompt: '✨ Great posture! Hold steady',
        speechPrompt: 'Great posture! Hold steady',
        primaryJoint: 'none',
        maxErrorDeg: 0.0,
        alignmentScore: alignmentScore,
      );
    }

    final Map<String, double> deltas = PoseComparisonEngine.computeJointDeltas(
      livePose: livePose,
      targetPose: targetPose,
    );

    if (deltas.isEmpty) {
      return SuggestionResult(
        textPrompt: 'Position yourself in the camera frame',
        speechPrompt: 'Position yourself in frame',
        primaryJoint: 'none',
        maxErrorDeg: 0.0,
        alignmentScore: alignmentScore,
      );
    }

    // Find joint with highest absolute angular delta
    String maxJoint = '';
    double maxDelta = 0.0;

    deltas.forEach((joint, delta) {
      if (delta.abs() > maxDelta.abs()) {
        maxJoint = joint;
        maxDelta = delta;
      }
    });

    final String textPrompt = _buildTextInstruction(maxJoint, maxDelta);
    final String speechPrompt = _buildSpeechInstruction(maxJoint, maxDelta);

    return SuggestionResult(
      textPrompt: textPrompt,
      speechPrompt: speechPrompt,
      primaryJoint: maxJoint,
      maxErrorDeg: maxDelta.abs(),
      alignmentScore: alignmentScore,
    );
  }

  static String _buildTextInstruction(String joint, double delta) {
    final bool isTooSmall = delta < 0; // User angle smaller than target angle

    switch (joint) {
      case 'elbowRight':
        return isTooSmall ? 'Raise right arm higher' : 'Bend right arm lower';
      case 'elbowLeft':
        return isTooSmall ? 'Raise left arm higher' : 'Bend left arm lower';
      case 'shoulderRight':
        return isTooSmall ? 'Open right shoulder wider' : 'Lower right arm';
      case 'shoulderLeft':
        return isTooSmall ? 'Open left shoulder wider' : 'Lower left arm';
      case 'kneeRight':
        return isTooSmall ? 'Extend right leg straighter' : 'Bend right knee inward';
      case 'kneeLeft':
        return isTooSmall ? 'Extend left leg straighter' : 'Bend left knee inward';
      case 'hipRight':
      case 'hipLeft':
        return isTooSmall ? 'Stand up taller' : 'Bend at hips slightly';
      default:
        return 'Align your body with target stencil';
    }
  }

  static String _buildSpeechInstruction(String joint, double delta) {
    final bool isTooSmall = delta < 0;

    switch (joint) {
      case 'elbowRight':
        return isTooSmall ? 'Raise your right arm higher' : 'Lower your right arm';
      case 'elbowLeft':
        return isTooSmall ? 'Raise your left arm higher' : 'Lower your left arm';
      case 'shoulderRight':
        return isTooSmall ? 'Open right shoulder' : 'Lower right shoulder';
      case 'shoulderLeft':
        return isTooSmall ? 'Open left shoulder' : 'Lower left shoulder';
      case 'kneeRight':
        return isTooSmall ? 'Straighten right leg' : 'Bend right knee';
      case 'kneeLeft':
        return isTooSmall ? 'Straighten left leg' : 'Bend left knee';
      case 'hipRight':
      case 'hipLeft':
        return isTooSmall ? 'Stand up taller' : 'Lean forward slightly';
      default:
        return 'Adjust your posture into stencil';
    }
  }
}
