import '../models/joint_delta.dart';

class DirectionalSuggestionEngine {
  /// Threshold in degrees before triggering directional advice
  static const double minorThresholdDegrees = 15.0;
  static const double majorThresholdDegrees = 30.0;

  /// Map list of [JointDelta] to human-readable directional posture suggestions
  List<String> generateSuggestions(List<JointDelta> deltas) {
    if (deltas.isEmpty) {
      return ['Position yourself in frame to match the target pose stencil.'];
    }

    final List<String> suggestions = [];

    for (final delta in deltas) {
      if (delta.isWithinTolerance) continue;

      final joint = delta.jointName;
      final diff = delta.deltaDegrees; // live - target

      switch (joint) {
        case 'left_elbow':
          if (diff > minorThresholdDegrees) {
            suggestions.add(diff > majorThresholdDegrees ? 'Straighten left arm' : 'Slightly straighten left arm');
          } else if (diff < -minorThresholdDegrees) {
            suggestions.add(diff < -majorThresholdDegrees ? 'Bend left elbow more' : 'Slightly bend left elbow');
          }
          break;

        case 'right_elbow':
          if (diff > minorThresholdDegrees) {
            suggestions.add(diff > majorThresholdDegrees ? 'Straighten right arm' : 'Slightly straighten right arm');
          } else if (diff < -minorThresholdDegrees) {
            suggestions.add(diff < -majorThresholdDegrees ? 'Bend right elbow more' : 'Slightly bend right elbow');
          }
          break;

        case 'left_shoulder':
          if (diff > minorThresholdDegrees) {
            suggestions.add('Lower left arm');
          } else if (diff < -minorThresholdDegrees) {
            suggestions.add('Raise left arm higher');
          }
          break;

        case 'right_shoulder':
          if (diff > minorThresholdDegrees) {
            suggestions.add('Lower right arm');
          } else if (diff < -minorThresholdDegrees) {
            suggestions.add('Raise right arm higher');
          }
          break;

        case 'left_knee':
          if (diff > minorThresholdDegrees) {
            suggestions.add('Straighten left leg');
          } else if (diff < -minorThresholdDegrees) {
            suggestions.add('Bend left knee slightly');
          }
          break;

        case 'right_knee':
          if (diff > minorThresholdDegrees) {
            suggestions.add('Straighten right leg');
          } else if (diff < -minorThresholdDegrees) {
            suggestions.add('Bend right knee slightly');
          }
          break;

        case 'left_hip':
        case 'right_hip':
          if (diff > minorThresholdDegrees) {
            suggestions.add('Stand up straighter');
          } else if (diff < -minorThresholdDegrees) {
            suggestions.add('Lean torso forward slightly');
          }
          break;
      }
    }

    if (suggestions.isEmpty) {
      return ['Great pose! Hold still for capture.'];
    }

    return suggestions;
  }
}
