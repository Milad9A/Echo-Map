import 'package:google_maps_flutter/google_maps_flutter.dart';
import 'package:equatable/equatable.dart';

enum HazardType {
  construction, // Construction zone
  obstacle, // Physical obstacle on path
  steepIncline, // Steep hill or ramp
  steepDecline, // Steep downhill section
  narrowPath, // Narrow sidewalk or path
  uneven, // Uneven surface
  slippery, // Slippery surface
  roadWork, // Road work zone
  crossingClosure, // Crossing is closed
  temporaryBarrier, // Temporary barrier
  missingPaving, // Missing pavement/tactile surface
  other, // Other hazard types
}

enum HazardSeverity {
  low, // Minimal impact, awareness recommended
  medium, // Moderate impact, caution advised
  high, // Significant impact, strong caution required
  critical, // Extremely dangerous, avoid if possible
}

class Hazard extends Equatable {
  final String id;
  final LatLng position;
  final HazardType type;
  final HazardSeverity severity;
  final String description;
  final DateTime reportedAt;
  final DateTime? validUntil;
  final bool isVerified;
  final double radius; // Area of effect in meters
  final String? reportedBy;
  final int? verificationCount;
  final Map<String, dynamic>? additionalInfo;

  const Hazard({
    required this.id,
    required this.position,
    required this.type,
    required this.severity,
    required this.description,
    required this.reportedAt,
    this.validUntil,
    this.isVerified = false,
    this.radius = 10.0,
    this.reportedBy,
    this.verificationCount,
    this.additionalInfo,
  });

  // Create a copy with some fields changed
  Hazard copyWith({
    String? id,
    LatLng? position,
    HazardType? type,
    HazardSeverity? severity,
    String? description,
    DateTime? reportedAt,
    DateTime? validUntil,
    bool? isVerified,
    double? radius,
    String? reportedBy,
    int? verificationCount,
    Map<String, dynamic>? additionalInfo,
  }) {
    return Hazard(
      id: id ?? this.id,
      position: position ?? this.position,
      type: type ?? this.type,
      severity: severity ?? this.severity,
      description: description ?? this.description,
      reportedAt: reportedAt ?? this.reportedAt,
      validUntil: validUntil ?? this.validUntil,
      isVerified: isVerified ?? this.isVerified,
      radius: radius ?? this.radius,
      reportedBy: reportedBy ?? this.reportedBy,
      verificationCount: verificationCount ?? this.verificationCount,
      additionalInfo: additionalInfo ?? this.additionalInfo,
    );
  }

  // Convert to map for storage
  Map<String, dynamic> toMap() {
    return {
      'id': id,
      'position': {
        'latitude': position.latitude,
        'longitude': position.longitude,
      },
      'type': type.index,
      'severity': severity.index,
      'description': description,
      'reportedAt': reportedAt.millisecondsSinceEpoch,
      'validUntil': validUntil?.millisecondsSinceEpoch,
      'isVerified': isVerified,
      'radius': radius,
      'reportedBy': reportedBy,
      'verificationCount': verificationCount,
      'additionalInfo': additionalInfo,
    };
  }

  // Create from map
  factory Hazard.fromMap(Map<String, dynamic> map) {
    return Hazard(
      id: map['id'],
      position: LatLng(
        map['position']['latitude'],
        map['position']['longitude'],
      ),
      type: HazardType.values[map['type']],
      severity: HazardSeverity.values[map['severity']],
      description: map['description'],
      reportedAt: DateTime.fromMillisecondsSinceEpoch(map['reportedAt']),
      validUntil: map['validUntil'] != null
          ? DateTime.fromMillisecondsSinceEpoch(map['validUntil'])
          : null,
      isVerified: map['isVerified'] ?? false,
      radius: map['radius'] ?? 10.0,
      reportedBy: map['reportedBy'],
      verificationCount: map['verificationCount'],
      additionalInfo: map['additionalInfo'],
    );
  }

  // Check if hazard is still valid
  bool isValid() {
    if (validUntil == null) return true;
    return validUntil!.isAfter(DateTime.now());
  }

  // Get a user-friendly description of the hazard
  String getFullDescription() {
    String severityText = '';
    switch (severity) {
      case HazardSeverity.low:
        severityText = 'Minor';
        break;
      case HazardSeverity.medium:
        severityText = 'Moderate';
        break;
      case HazardSeverity.high:
        severityText = 'Major';
        break;
      case HazardSeverity.critical:
        severityText = 'Critical';
        break;
    }

    return '$severityText hazard: $description';
  }

  // Get priority level for notifications (1-10)
  int getPriorityLevel() {
    int priority = 5; // Default medium priority

    // Adjust based on severity
    switch (severity) {
      case HazardSeverity.low:
        priority = 3;
        break;
      case HazardSeverity.medium:
        priority = 5;
        break;
      case HazardSeverity.high:
        priority = 7;
        break;
      case HazardSeverity.critical:
        priority = 10;
        break;
    }

    // Increase priority for verified hazards
    if (isVerified) priority += 1;

    // Adjust based on verification count
    if (verificationCount != null && verificationCount! > 3) {
      priority += 1;
    }

    return priority.clamp(1, 10);
  }

  @override
  List<Object?> get props => [
    id,
    position.latitude,
    position.longitude,
    type,
    severity,
    description,
    reportedAt,
    validUntil,
    isVerified,
    radius,
  ];
}
