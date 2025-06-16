import 'package:equatable/equatable.dart';
import 'package:google_maps_flutter/google_maps_flutter.dart';

enum LocationType {
  streetAddress,
  route,
  intersection,
  political,
  country,
  administrativeAreaLevel1,
  administrativeAreaLevel2,
  locality,
  neighborhood,
  premise,
  subpremise,
  establishment,
  pointOfInterest,
  other,
}

class GeocodingResult extends Equatable {
  final String formattedAddress;
  final LatLng coordinates;
  final String? name;
  final String? placeId;
  final List<LocationType> types;
  final Map<String, String> addressComponents;
  final double? confidence; // 0.0 to 1.0

  const GeocodingResult({
    required this.formattedAddress,
    required this.coordinates,
    this.name,
    this.placeId,
    this.types = const [],
    this.addressComponents = const {},
    this.confidence,
  });

  // Create from Google Maps Geocoding API response
  factory GeocodingResult.fromGoogleMapsJson(Map<String, dynamic> json) {
    final geometry = json['geometry'] as Map<String, dynamic>;
    final location = geometry['location'] as Map<String, dynamic>;

    final coordinates = LatLng(
      (location['lat'] as num).toDouble(),
      (location['lng'] as num).toDouble(),
    );

    // Parse address components
    final addressComponents = <String, String>{};
    final componentsJson = json['address_components'] as List<dynamic>? ?? [];

    for (final component in componentsJson) {
      final componentMap = component as Map<String, dynamic>;
      final types = (componentMap['types'] as List<dynamic>).cast<String>();
      final longName = componentMap['long_name'] as String;

      for (final type in types) {
        addressComponents[type] = longName;
      }
    }

    // Parse types
    final typesJson = (json['types'] as List<dynamic>? ?? []).cast<String>();
    final locationTypes = typesJson.map(_parseLocationType).toList();

    // Calculate confidence based on location type (Google doesn't provide this directly)
    double confidence = 0.5; // Default
    if (typesJson.contains('street_address')) {
      confidence = 0.9;
    } else if (typesJson.contains('establishment')) {
      confidence = 0.8;
    } else if (typesJson.contains('route')) {
      confidence = 0.7;
    } else if (typesJson.contains('locality')) {
      confidence = 0.6;
    }

    return GeocodingResult(
      formattedAddress: json['formatted_address'] as String,
      coordinates: coordinates,
      placeId: json['place_id'] as String?,
      types: locationTypes,
      addressComponents: addressComponents,
      confidence: confidence,
    );
  }

  // Create from Google Places API Place Details response
  factory GeocodingResult.fromPlaceDetailsJson(Map<String, dynamic> json) {
    final geometry = json['geometry'] as Map<String, dynamic>;
    final location = geometry['location'] as Map<String, dynamic>;

    final coordinates = LatLng(
      (location['lat'] as num).toDouble(),
      (location['lng'] as num).toDouble(),
    );

    final typesJson = (json['types'] as List<dynamic>? ?? []).cast<String>();
    final locationTypes = typesJson.map(_parseLocationType).toList();

    return GeocodingResult(
      formattedAddress: json['formatted_address'] as String,
      coordinates: coordinates,
      name: json['name'] as String?,
      placeId: json['place_id'] as String?,
      types: locationTypes,
      confidence: 0.9, // Place details are typically high confidence
    );
  }

  // Parse location type from string
  static LocationType _parseLocationType(String type) {
    switch (type) {
      case 'street_address':
        return LocationType.streetAddress;
      case 'route':
        return LocationType.route;
      case 'intersection':
        return LocationType.intersection;
      case 'political':
        return LocationType.political;
      case 'country':
        return LocationType.country;
      case 'administrative_area_level_1':
        return LocationType.administrativeAreaLevel1;
      case 'administrative_area_level_2':
        return LocationType.administrativeAreaLevel2;
      case 'locality':
        return LocationType.locality;
      case 'neighborhood':
        return LocationType.neighborhood;
      case 'premise':
        return LocationType.premise;
      case 'subpremise':
        return LocationType.subpremise;
      case 'establishment':
        return LocationType.establishment;
      case 'point_of_interest':
        return LocationType.pointOfInterest;
      default:
        return LocationType.other;
    }
  }

  // Get display name for the result
  String get displayName {
    if (name != null && name!.isNotEmpty) {
      return name!;
    }

    // Extract meaningful parts from formatted address
    final parts = formattedAddress.split(',');
    if (parts.isNotEmpty) {
      return parts.first.trim();
    }

    return formattedAddress;
  }

  // Get short description for the result
  String get shortDescription {
    final components = <String>[];

    if (addressComponents.containsKey('route')) {
      components.add(addressComponents['route']!);
    }

    if (addressComponents.containsKey('locality')) {
      components.add(addressComponents['locality']!);
    } else if (addressComponents.containsKey('administrative_area_level_2')) {
      components.add(addressComponents['administrative_area_level_2']!);
    }

    return components.join(', ');
  }

  // Check if this is a specific address
  bool get isSpecificAddress {
    return types.contains(LocationType.streetAddress) ||
        types.contains(LocationType.establishment) ||
        types.contains(LocationType.premise);
  }

  // Check if this is a point of interest
  bool get isPointOfInterest {
    return types.contains(LocationType.pointOfInterest) ||
        types.contains(LocationType.establishment);
  }

  @override
  List<Object?> get props => [
        formattedAddress,
        coordinates.latitude,
        coordinates.longitude,
        name,
        placeId,
        types,
        addressComponents,
        confidence,
      ];

  @override
  String toString() {
    return 'GeocodingResult{name: $name, address: $formattedAddress, '
        'coordinates: ${coordinates.latitude}, ${coordinates.longitude}}';
  }
}
