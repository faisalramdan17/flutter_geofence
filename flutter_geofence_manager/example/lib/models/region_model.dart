import 'dart:convert';

class RegionModel {
  final String id;
  final double latitude;
  final double longitude;
  final double radius;

  RegionModel({
    required this.id,
    required this.latitude,
    required this.longitude,
    required this.radius,
  });

  // Convert to GeoFenceRegion
  Map<String, dynamic> toJson() {
    return {
      'id': id,
      'latitude': latitude,
      'longitude': longitude,
      'radius': radius,
    };
  }

  // Create from JSON
  factory RegionModel.fromJson(Map<String, dynamic> json) {
    return RegionModel(
      id: json['id'],
      latitude: json['latitude'],
      longitude: json['longitude'],
      radius: json['radius'],
    );
  }

  // Convert list to JSON string
  static String encodeList(List<RegionModel> regions) {
    return jsonEncode(regions.map((region) => region.toJson()).toList());
  }

  // Create list from JSON string
  static List<RegionModel> decodeList(String jsonString) {
    if (jsonString.isEmpty) return [];
    
    final List<dynamic> jsonList = jsonDecode(jsonString);
    return jsonList.map((json) => RegionModel.fromJson(json)).toList();
  }
}
