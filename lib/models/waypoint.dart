import 'package:equatable/equatable.dart';
import 'package:google_maps_flutter/google_maps_flutter.dart';
import 'dart:math';

enum WaypointType {
  origin,
  destination,
  intermediate,
  hazard,
  crossing,
  landmark,
}

class Waypoint extends Equatable {
  final String id;
  final LatLng position;
  final String name;
  final String? description;
  final WaypointType type;
  final DateTime createdAt;
  final Map<String, dynamic>? metadata;

  Waypoint({
    String? id,
    required this.position,
    required this.name,
    this.description,
    required this.type,
    DateTime? createdAt,
    this.metadata,
  }) : id = id ?? DateTime.now().millisecondsSinceEpoch.toString(),
       createdAt = createdAt ?? DateTime.now();

  // Create a copy of this waypoint with optional new values
  Waypoint copyWith({
    String? id,
    LatLng? position,
    String? name,
    String? description,
    WaypointType? type,
    DateTime? createdAt,
    Map<String, dynamic>? metadata,
  }) {
    return Waypoint(
      id: id ?? this.id,
      position: position ?? this.position,
      name: name ?? this.name,
      description: description ?? this.description,
      type: type ?? this.type,
      createdAt: createdAt ?? this.createdAt,
      metadata: metadata ?? this.metadata,
    );
  }

  // Get a human-readable type name
  String get typeName {
    switch (type) {
      case WaypointType.origin:
        return 'Starting Point';
      case WaypointType.destination:
        return 'Destination';
      case WaypointType.intermediate:
        return 'Waypoint';
      case WaypointType.hazard:
        return 'Hazard';
      case WaypointType.crossing:
        return 'Crossing';
      case WaypointType.landmark:
        return 'Landmark';
    }
  }

  // Get distance to another waypoint in meters
  double distanceTo(Waypoint other) {
    // Calculate using the Haversine formula
    // This is a simple implementation - for more accuracy, use geolocator package
    const double earthRadius = 6371000; // in meters

    double lat1Rad = position.latitude * (3.141592653589793 / 180);
    double lat2Rad = other.position.latitude * (3.141592653589793 / 180);
    double lon1Rad = position.longitude * (3.141592653589793 / 180);
    double lon2Rad = other.position.longitude * (3.141592653589793 / 180);

    double dLat = lat2Rad - lat1Rad;
    double dLon = lon2Rad - lon1Rad;
    double a =
        pow(sin(dLat / 2), 2) +
        pow(sin(dLon / 2), 2) * cos(lat1Rad) * cos(lat2Rad);
    double c = 2 * atan2(sqrt(a), sqrt(1 - a));

    return earthRadius * c;
  }

  // Convert to map for storage
  Map<String, dynamic> toMap() {
    return {
      'id': id,
      'position': {
        'latitude': position.latitude,
        'longitude': position.longitude,
      },
      'name': name,
      'description': description,
      'type': type.index,
      'createdAt': createdAt.millisecondsSinceEpoch,
      'metadata': metadata,
    };
  }

  // Create from map for storage retrieval
  factory Waypoint.fromMap(Map<String, dynamic> map) {
    return Waypoint(
      id: map['id'],
      position: LatLng(
        map['position']['latitude'],
        map['position']['longitude'],
      ),
      name: map['name'],
      description: map['description'],
      type: WaypointType.values[map['type']],
      createdAt: DateTime.fromMillisecondsSinceEpoch(map['createdAt']),
      metadata: map['metadata'],
    );
  }

  @override
  List<Object?> get props => [
    id,
    position.latitude,
    position.longitude,
    name,
    description,
    type,
    createdAt,
  ];
}
