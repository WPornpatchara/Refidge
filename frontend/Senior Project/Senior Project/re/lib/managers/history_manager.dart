import 'dart:convert';
import 'package:shared_preferences/shared_preferences.dart';

class HistoryManager {
  static const _k = 'history.recipe_ids'; // json list

  // เก็บเป็น list ของ {id, ts}
  static Future<List<Map<String, dynamic>>> load() async {
    final sp = await SharedPreferences.getInstance();
    final raw = sp.getString(_k);
    if (raw == null || raw.trim().isEmpty) return [];
    final list = (jsonDecode(raw) as List).cast<Map<String, dynamic>>();
    return list;
  }

  static Future<void> add(String mealId) async {
    final sp = await SharedPreferences.getInstance();
    final list = await load();

    // ลบ id เดิมออก เพื่อให้เด้งไปบนสุด
    list.removeWhere((e) => e['id'] == mealId);

    list.insert(0, {
      'id': mealId,
      'ts': DateTime.now().millisecondsSinceEpoch,
    });

    // จำกัดไม่ให้ยาวเกิน (ปรับได้)
    if (list.length > 50) {
      list.removeRange(50, list.length);
    }

    await sp.setString(_k, jsonEncode(list));
  }

  static Future<void> clear() async {
    final sp = await SharedPreferences.getInstance();
    await sp.remove(_k);
  }
}
