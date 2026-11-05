import 'dart:convert';
import 'package:http/http.dart' as http;
import '../models/meal.dart';

class MealApiService {
  static const String _baseUrl =
      'https://www.themealdb.com/api/json/v1/1/search.php?s=';

  static Future<List<Meal>> fetchMeals() async {
    final response = await http.get(Uri.parse(_baseUrl));

    if (response.statusCode != 200) {
      throw Exception('Failed to load meals');
    }

    final data = json.decode(response.body);
    final List mealsJson = data['meals'];

    return mealsJson.map((json) => Meal.fromJson(json)).toList();
  }
}
