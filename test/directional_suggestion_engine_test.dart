import 'package:flutter_test/flutter_test.dart';
import 'package:pose_suggestion_app/features/suggestion_engine/models/joint_delta.dart';
import 'package:pose_suggestion_app/features/suggestion_engine/services/directional_suggestion_engine.dart';

void main() {
  group('DirectionalSuggestionEngine Unit Tests', () {
    final engine = DirectionalSuggestionEngine();

    test('generateSuggestions returns praise when all joints are matched', () {
      final deltas = [
        const JointDelta(
          jointName: 'left_elbow',
          liveAngleDegrees: 90.0,
          targetAngleDegrees: 90.0,
          deltaDegrees: 0.0,
          isWithinTolerance: true,
        ),
      ];

      final suggestions = engine.generateSuggestions(deltas);
      expect(suggestions.first, contains('Great pose'));
    });

    test('generateSuggestions returns "Bend left elbow more" when delta is negative', () {
      final deltas = [
        const JointDelta(
          jointName: 'left_elbow',
          liveAngleDegrees: 140.0,
          targetAngleDegrees: 90.0,
          deltaDegrees: -25.0,
          isWithinTolerance: false,
        ),
      ];

      final suggestions = engine.generateSuggestions(deltas);
      expect(suggestions.first, equals('Bend left elbow more'));
    });

    test('generateSuggestions returns "Straighten left arm" when delta is positive', () {
      final deltas = [
        const JointDelta(
          jointName: 'left_elbow',
          liveAngleDegrees: 60.0,
          targetAngleDegrees: 120.0,
          deltaDegrees: 35.0,
          isWithinTolerance: false,
        ),
      ];

      final suggestions = engine.generateSuggestions(deltas);
      expect(suggestions.first, equals('Straighten left arm'));
    });
  });
}
