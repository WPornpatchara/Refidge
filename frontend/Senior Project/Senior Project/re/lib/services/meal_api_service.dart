import 'dart:convert';
import 'dart:math';
import 'package:http/http.dart' as http;
import '../models/meal.dart';

class MealApiService {
  static const String _base = 'https://www.themealdb.com/api/json/v1/1';

  static Future<List<Meal>> fetchMeals({int count = 10}) async {
    final response = await http.get(
      Uri.parse('$_base/search.php?s='),
    );

    if (response.statusCode != 200) {
      throw Exception('Failed to load meals');
    }

    final data = jsonDecode(response.body);
    final List mealsJson = data['meals'];

    final meals = mealsJson.map((e) => Meal.fromJson(e)).toList();
    meals.shuffle(Random());

    return meals.take(count).toList();
  }

  static Future<List<Meal>> fetchMealsByFirstLetter(String letter) async {
    final response = await http.get(
      Uri.parse('$_base/search.php?f=$letter'),
    );

    if (response.statusCode != 200) {
      throw Exception('Failed');
    }

    final data = jsonDecode(response.body);
    final List? mealsJson = data['meals'];
    if (mealsJson == null) return [];

    return mealsJson.map((e) => Meal.fromJson(e)).toList();
  }

  static Future<List<Meal>> fetchAllMeals() async {
    final Map<String, Meal> map = {};

    for (final ch in 'abcdefghijklmnopqrstuvwxyz'.split('')) {
      try {
        final list = await fetchMealsByFirstLetter(ch);
        for (final m in list) {
          map[m.id] = m;
        }
      } catch (_) {}
    }

    return map.values.toList();
  }

  static Future<Meal> fetchMealDetail(String id) async {
    final response = await http.get(
      Uri.parse('$_base/lookup.php?i=$id'),
    );

    if (response.statusCode != 200) {
      throw Exception('Failed to load meal detail');
    }

    final data = jsonDecode(response.body);
    final mealJson = data['meals'][0];

    return Meal.fromJson(mealJson);
  }

  // =========================================================
  // ✅ NEW: เมนูแนะนำตามวัตถุดิบที่มีใน Inventory
  // =========================================================

  /// ingredients: รายการชื่อวัตถุดิบ เช่น ["Egg", "Chicken", "Onion"]
  /// count: จำนวนเมนูที่อยากได้
  /// minMatch: ต้อง match อย่างน้อยกี่วัตถุดิบ (ตั้ง 2 จะเข้มขึ้น)
  static Future<List<Meal>> fetchMealsByIngredients(
    List<String> ingredients, {
    int count = 10,
    int minMatch = 1,
  }) async {
    final cleaned = ingredients
        .map((e) => e.trim())
        .where((e) => e.isNotEmpty)
        .toList();

    if (cleaned.isEmpty) return [];

    // idMeal -> matchCount
    final Map<String, int> score = {};

    // 1) filter ตาม ingredient ทีละตัว
    for (final ing in cleaned) {
      try {
        final ids = await _filterMealsByIngredient(ing);
        for (final id in ids) {
          score[id] = (score[id] ?? 0) + 1;
        }
      } catch (_) {
        // ignore ingredient ที่หาไม่เจอ/ยิงพลาด
      }
    }

    if (score.isEmpty) return [];

    // 2) sort ตามคะแนน match มาก -> น้อย
    final ranked = score.entries
        .where((e) => e.value >= minMatch)
        .toList()
      ..sort((a, b) => b.value.compareTo(a.value));

    if (ranked.isEmpty) return [];

    final topIds = ranked.take(count).map((e) => e.key).toList();

    // 3) lookup รายละเอียดเมนูแต่ละ id
    final List<Meal> results = [];
    for (final id in topIds) {
      try {
        final meal = await _lookupMealById(id);
        results.add(meal);
      } catch (_) {}
    }

    return results;
  }

  /// คืนรายการ idMeal ที่มี ingredient นี้ (จาก filter.php)
  static Future<List<String>> _filterMealsByIngredient(String ingredient) async {
    final uri = Uri.parse('$_base/filter.php?i=${Uri.encodeComponent(ingredient)}');
    final response = await http.get(uri);

    if (response.statusCode != 200) {
      throw Exception('Failed to filter by ingredient');
    }

    final data = jsonDecode(response.body) as Map<String, dynamic>;
    final meals = data['meals'];

    if (meals == null) return [];

    final List<String> ids = [];
    for (final m in meals as List) {
      final id = (m as Map<String, dynamic>)['idMeal']?.toString();
      if (id != null) ids.add(id);
    }
    return ids;
  }

  /// lookup.php เพื่อได้รายละเอียดเต็ม แล้ว parse เป็น Meal
  static Future<Meal> _lookupMealById(String id) async {
    final uri = Uri.parse('$_base/lookup.php?i=$id');
    final response = await http.get(uri);

    if (response.statusCode != 200) {
      throw Exception('Failed to lookup meal');
    }

    final data = jsonDecode(response.body) as Map<String, dynamic>;
    final meals = data['meals'] as List?;
    if (meals == null || meals.isEmpty) {
      throw Exception('Meal not found');
    }

    return Meal.fromJson(meals.first as Map<String, dynamic>);
  }
}
