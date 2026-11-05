import 'dart:convert';
import 'package:shared_preferences/shared_preferences.dart';

class DownloadStorage {
  static const _kIndex = 'downloads.index'; // json list of ids
  static String _kMeal(String id) => 'downloads.meal.$id'; // json meal

  static Future<List<String>> loadIds() async {
    final sp = await SharedPreferences.getInstance();
    final raw = sp.getString(_kIndex);
    if (raw == null || raw.trim().isEmpty) return [];
    return (jsonDecode(raw) as List).map((e) => e.toString()).toList();
  }

  static Future<void> saveMeal(String id, Map<String, dynamic> mealMap) async {
    final sp = await SharedPreferences.getInstance();

    // บันทึกตัว meal
    await sp.setString(_kMeal(id), jsonEncode(mealMap));

    // อัปเดต index (id ล่าสุดอยู่บนสุด)
    final ids = await loadIds();
    ids.remove(id);
    ids.insert(0, id);
    await sp.setString(_kIndex, jsonEncode(ids));
  }

  static Future<Map<String, dynamic>?> loadMeal(String id) async {
    final sp = await SharedPreferences.getInstance();
    final raw = sp.getString(_kMeal(id));
    if (raw == null || raw.trim().isEmpty) return null;
    return (jsonDecode(raw) as Map).cast<String, dynamic>();
  }

  static Future<void> remove(String id) async {
    final sp = await SharedPreferences.getInstance();
    await sp.remove(_kMeal(id));
    final ids = await loadIds();
    ids.remove(id);
    await sp.setString(_kIndex, jsonEncode(ids));
  }

  static Future<void> clear() async {
    final sp = await SharedPreferences.getInstance();
    final ids = await loadIds();
    for (final id in ids) {
      await sp.remove(_kMeal(id));
    }
    await sp.remove(_kIndex);
  }
}
