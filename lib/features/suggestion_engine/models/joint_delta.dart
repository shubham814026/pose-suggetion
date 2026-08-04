class JointDelta {
  final String jointName;
  final double liveAngleDegrees;
  final double targetAngleDegrees;
  final double deltaDegrees; // liveAngle - targetAngle
  final bool isWithinTolerance;

  const JointDelta({
    required this.jointName,
    required this.liveAngleDegrees,
    required this.targetAngleDegrees,
    required this.deltaDegrees,
    required this.isWithinTolerance,
  });

  @override
  String toString() {
    return 'JointDelta($jointName: live=${liveAngleDegrees.toStringAsFixed(1)}°, target=${targetAngleDegrees.toStringAsFixed(1)}°, delta=${deltaDegrees.toStringAsFixed(1)}°)';
  }
}
