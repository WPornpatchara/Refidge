import 'ingredient_mapper.dart';

class IngredientImageService {
  static String fromName(String name) {
    final key = IngredientMapper.toMealDbKey(name) ?? name;
    final safe = Uri.encodeComponent(key.toLowerCase().trim());
    return "https://www.themealdb.com/images/ingredients/$safe.png";
  }
}
