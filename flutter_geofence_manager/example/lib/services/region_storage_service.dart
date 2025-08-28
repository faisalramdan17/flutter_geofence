import 'package:shared_preferences/shared_preferences.dart';
import '../models/region_model.dart';

class RegionStorageService {
  static const String _regionsKey = 'geo_fence_regions';

  // Save regions to local storage
  static Future<bool> saveRegions(List<RegionModel> regions) async {
    final SharedPreferences prefs = await SharedPreferences.getInstance();
    final String regionsJson = RegionModel.encodeList(regions);
    return await prefs.setString(_regionsKey, regionsJson);
  }

  // Load regions from local storage
  static Future<List<RegionModel>> loadRegions() async {
    final SharedPreferences prefs = await SharedPreferences.getInstance();
    final String? regionsJson = prefs.getString(_regionsKey);
    
    if (regionsJson == null || regionsJson.isEmpty) {
      return [];
    }
    
    return RegionModel.decodeList(regionsJson);
  }

  // Clear all regions from local storage
  static Future<bool> clearRegions() async {
    final SharedPreferences prefs = await SharedPreferences.getInstance();
    return await prefs.remove(_regionsKey);
  }
}
