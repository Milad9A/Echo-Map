import 'package:google_maps_flutter/google_maps_flutter.dart';
import 'package:equatable/equatable.dart';

enum CrossingType {
  // Different types of street crossings
  uncontrolled, // No traffic signals
  trafficLight, // With traffic signal
  zebra, // Zebra/pedestrian crossing
  pedestrianBridge, // Overpass/bridge
  underpass, // Pedestrian tunnel/underpass
  island, // Pedestrian island/refuge
}

class StreetCrossing extends Equatable {
  final String id;
  final LatLng position;
  final CrossingType type;
  final bool hasAudibleSignal;
  final bool hasTactilePaving;
  final int? streetWidth; // In meters
  final int? estimatedCrossingTime; // In seconds
  final String? streetName;
  final int? trafficLevel; // 1-10 scale
  final Map<String, dynamic>? additionalInfo;

  const StreetCrossing({
    required this.id,
    required this.position,
    required this.type,
    this.hasAudibleSignal = false,
    this.hasTactilePaving = false,
    this.streetWidth,
    this.estimatedCrossingTime,
    this.streetName,
    this.trafficLevel,
    this.additionalInfo,
  });

  // Create a copy with some fields changed
  StreetCrossing copyWith({
    String? id,
    LatLng? position,
    CrossingType? type,
    bool? hasAudibleSignal,
    bool? hasTactilePaving,
    int? streetWidth,
    int? estimatedCrossingTime,
    String? streetName,
    int? trafficLevel,
    Map<String, dynamic>? additionalInfo,
  }) {
    return StreetCrossing(
      id: id ?? this.id,
      position: position ?? this.position,
      type: type ?? this.type,
      hasAudibleSignal: hasAudibleSignal ?? this.hasAudibleSignal,
      hasTactilePaving: hasTactilePaving ?? this.hasTactilePaving,
      streetWidth: streetWidth ?? this.streetWidth,
      estimatedCrossingTime:
          estimatedCrossingTime ?? this.estimatedCrossingTime,
      streetName: streetName ?? this.streetName,
      trafficLevel: trafficLevel ?? this.trafficLevel,
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
      'hasAudibleSignal': hasAudibleSignal,
      'hasTactilePaving': hasTactilePaving,
      'streetWidth': streetWidth,
      'estimatedCrossingTime': estimatedCrossingTime,
      'streetName': streetName,
      'trafficLevel': trafficLevel,
      'additionalInfo': additionalInfo,
    };
  }

  // Create from map
  factory StreetCrossing.fromMap(Map<String, dynamic> map) {
    return StreetCrossing(
      id: map['id'],
      position: LatLng(
        map['position']['latitude'],
        map['position']['longitude'],
      ),
      type: CrossingType.values[map['type']],
      hasAudibleSignal: map['hasAudibleSignal'] ?? false,
      hasTactilePaving: map['hasTactilePaving'] ?? false,
      streetWidth: map['streetWidth'],
      estimatedCrossingTime: map['estimatedCrossingTime'],
      streetName: map['streetName'],
      trafficLevel: map['trafficLevel'],
      additionalInfo: map['additionalInfo'],
    );
  }

  // Get a user-friendly description of the crossing
  String getDescription() {
    String description = 'Street crossing';

    switch (type) {
      case CrossingType.uncontrolled:
        description = 'Uncontrolled street crossing';
        break;
      case CrossingType.trafficLight:
        description = 'Traffic light crossing';
        if (hasAudibleSignal) description += ' with audible signal';
        break;
      case CrossingType.zebra:
        description = 'Zebra crossing';
        break;
      case CrossingType.pedestrianBridge:
        description = 'Pedestrian bridge';
        break;
      case CrossingType.underpass:
        description = 'Pedestrian underpass';
        break;
      case CrossingType.island:
        description = 'Crossing with pedestrian island';
        break;
    }

    if (streetName != null) {
      description += ' on $streetName';
    }

    return description;
  }

  // Risk assessment (1-5 scale, 5 being highest risk)
  int getRiskLevel() {
    int risk = 3; // Default medium risk

    // Adjust based on crossing type
    switch (type) {
      case CrossingType.uncontrolled:
        risk += 1;
        break;
      case CrossingType.trafficLight:
        risk -= hasAudibleSignal ? 2 : 1;
        break;
      case CrossingType.zebra:
        risk -= 1;
        break;
      case CrossingType.pedestrianBridge:
      case CrossingType.underpass:
        risk -= 2; // Safest options
        break;
      case CrossingType.island:
        break; // No adjustment
    }

    // Adjust based on traffic level
    if (trafficLevel != null) {
      if (trafficLevel! > 7) risk += 1;
      if (trafficLevel! < 3) risk -= 1;
    }

    // Ensure within range
    return risk.clamp(1, 5);
  }

  @override
  List<Object?> get props => [
        id,
        position.latitude,
        position.longitude,
        type,
        hasAudibleSignal,
        hasTactilePaving,
        streetWidth,
        estimatedCrossingTime,
        streetName,
        trafficLevel,
      ];
}
