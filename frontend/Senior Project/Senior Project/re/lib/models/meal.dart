class Meal {
  final String id;
  final String title;
  final String thumbnail;
  final String category;
  final String area;

  final String instructions; // ✅
  final List<Map<String, String>> ingredients; // ✅
  final List<String> tags; // ✅
  final String youtube; // ✅

  Meal({
    required this.id,
    required this.title,
    required this.thumbnail,
    required this.category,
    required this.area,
    required this.instructions,
    required this.ingredients,
    required this.tags,
    required this.youtube,
  });

  factory Meal.fromJson(Map<String, dynamic> json) {
    final List<Map<String, String>> ingredients = [];

    for (int i = 1; i <= 20; i++) {
      final ingredient = json['strIngredient$i'];
      final measure = json['strMeasure$i'];

      if (ingredient != null &&
          ingredient.toString().trim().isNotEmpty) {
        ingredients.add({
          'ingredient': ingredient.toString().trim(),
          'measure': (measure ?? '').toString().trim(),
        });
      }
    }

    final rawTags = (json['strTags'] ?? '').toString().trim();
    final tags = rawTags.isEmpty
        ? <String>[]
        : rawTags.split(',').map((e) => e.trim()).where((e) => e.isNotEmpty).toList();

    return Meal(
      id: (json['idMeal'] ?? '').toString(),
      title: (json['strMeal'] ?? '').toString(),
      thumbnail: (json['strMealThumb'] ?? '').toString(),
      category: (json['strCategory'] ?? '').toString(),
      area: (json['strArea'] ?? '').toString(),
      instructions: (json['strInstructions'] ?? '').toString(), // ✅
      ingredients: ingredients, // ✅
      tags: tags, // ✅
      youtube: (json['strYoutube'] ?? '').toString(), // ✅
    );
  }

Map<String, dynamic> toMap() => {
  'id': id,
  'title': title,
  'thumbnail': thumbnail,
  'category': category,
  'area': area,
  'instructions': instructions,
  'ingredients': ingredients,
  'tags': tags,
  'youtube': youtube,
};

factory Meal.fromMap(Map<String, dynamic> map) {
  return Meal(
    id: map['id']?.toString() ?? '',
    title: map['title']?.toString() ?? '',
    thumbnail: map['thumbnail']?.toString() ?? '',
    category: map['category']?.toString() ?? '',
    area: map['area']?.toString() ?? '',
    instructions: map['instructions']?.toString() ?? '',
    ingredients: (map['ingredients'] as List? ?? [])
        .map((e) => (e as Map).map((k, v) => MapEntry(k.toString(), v.toString())))
        .toList(),
    tags: (map['tags'] as List? ?? []).map((e) => e.toString()).toList(),
    youtube: map['youtube']?.toString() ?? '',
  );
}


}

