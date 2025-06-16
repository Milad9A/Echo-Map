import 'package:equatable/equatable.dart';
import 'package:google_maps_flutter/google_maps_flutter.dart';

enum PlaceCategory {
  home,
  work,
  restaurant,
  shopping,
  health,
  transit,
  address,
  other,
}

class RecentPlace extends Equatable {
  final String id;
  final String name;
  final String? description;
  final LatLng position;
  final DateTime lastUsed;
  final int usageCount;
  final PlaceCategory category;
  final bool isFavorite;
  final String? placeId; // Google Places ID
  final Map<String, dynamic>? metadata;

  const RecentPlace({
    required this.id,
    required this.name,
    this.description,
    required this.position,
    required this.lastUsed,
    this.usageCount = 1,
    this.category = PlaceCategory.other,
    this.isFavorite = false,
    this.placeId,
    this.metadata,
  });

  // Create a copy with some fields changed
  RecentPlace copyWith({
    String? id,
    String? name,
    String? description,
    LatLng? position,
    DateTime? lastUsed,
    int? usageCount,
    PlaceCategory? category,
    bool? isFavorite,
    String? placeId,
    Map<String, dynamic>? metadata,
  }) {
    return RecentPlace(
      id: id ?? this.id,
      name: name ?? this.name,
      description: description ?? this.description,
      position: position ?? this.position,
      lastUsed: lastUsed ?? this.lastUsed,
      usageCount: usageCount ?? this.usageCount,
      category: category ?? this.category,
      isFavorite: isFavorite ?? this.isFavorite,
      placeId: placeId ?? this.placeId,
      metadata: metadata ?? this.metadata,
    );
  }

  // Convert to JSON for storage
  Map<String, dynamic> toJson() {
    return {
      'id': id,
      'name': name,
      'description': description,
      'position': {
        'latitude': position.latitude,
        'longitude': position.longitude,
      },
      'lastUsed': lastUsed.millisecondsSinceEpoch,
      'usageCount': usageCount,
      'category': category.index,
      'isFavorite': isFavorite,
      'placeId': placeId,
      'metadata': metadata,
    };
  }

  // Create from JSON
  factory RecentPlace.fromJson(Map<String, dynamic> json) {
    return RecentPlace(
      id: json['id'] as String,
      name: json['name'] as String,
      description: json['description'] as String?,
      position: LatLng(
        (json['position']['latitude'] as num).toDouble(),
        (json['position']['longitude'] as num).toDouble(),
      ),
      lastUsed: DateTime.fromMillisecondsSinceEpoch(json['lastUsed'] as int),
      usageCount: json['usageCount'] as int? ?? 1,
      category: PlaceCategory
          .values[json['category'] as int? ?? PlaceCategory.other.index],
      isFavorite: json['isFavorite'] as bool? ?? false,
      placeId: json['placeId'] as String?,
      metadata: json['metadata'] as Map<String, dynamic>?,
    );
  }

  // Get category display name
  String get categoryDisplayName {
    switch (category) {
      case PlaceCategory.home:
        return 'Home';
      case PlaceCategory.work:
        return 'Work';
      case PlaceCategory.restaurant:
        return 'Restaurant';
      case PlaceCategory.shopping:
        return 'Shopping';
      case PlaceCategory.health:
        return 'Health';
      case PlaceCategory.transit:
        return 'Transit';
      case PlaceCategory.address:
        return 'Address';
      case PlaceCategory.other:
        return 'Other';
    }
  }

  // Get category icon
  String get categoryIcon {
    switch (category) {
      case PlaceCategory.home:
        return '🏠';
      case PlaceCategory.work:
        return '🏢';
      case PlaceCategory.restaurant:
        return '🍽️';
      case PlaceCategory.shopping:
        return '🛍️';
      case PlaceCategory.health:
        return '🏥';
      case PlaceCategory.transit:
        return '🚇';
      case PlaceCategory.address:
        return '📍';
      case PlaceCategory.other:
        return '📌';
    }
  }

  // Get human-readable last used time
  String get lastUsedText {
    final now = DateTime.now();
    final difference = now.difference(lastUsed);

    if (difference.inDays > 7) {
      return '${difference.inDays} days ago';
    } else if (difference.inDays > 0) {
      return '${difference.inDays} day${difference.inDays == 1 ? '' : 's'} ago';
    } else if (difference.inHours > 0) {
      return '${difference.inHours} hour${difference.inHours == 1 ? '' : 's'} ago';
    } else if (difference.inMinutes > 0) {
      return '${difference.inMinutes} minute${difference.inMinutes == 1 ? '' : 's'} ago';
    } else {
      return 'Just now';
    }
  }

  // Get short description for display
  String get shortDescription {
    if (description != null && description!.isNotEmpty) {
      final parts = description!.split(',');
      return parts.length > 1 ? parts.sublist(0, 2).join(', ') : description!;
    }
    return 'No description';
  }

  @override
  List<Object?> get props => [
        id,
        name,
        description,
        position.latitude,
        position.longitude,
        lastUsed,
        usageCount,
        category,
        isFavorite,
        placeId,
      ];

  @override
  String toString() {
    return 'RecentPlace{name: $name, category: $category, usageCount: $usageCount, lastUsed: $lastUsed}';
  }
}
