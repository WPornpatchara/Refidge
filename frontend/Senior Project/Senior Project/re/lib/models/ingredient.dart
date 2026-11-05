class Ingredient {
  final String name;
  final int quantity;
  final String freshness;

  Ingredient({
    required this.name,
    required this.quantity,
    required this.freshness,
  });

  factory Ingredient.fromJson(Map<String, dynamic> json) {
    return Ingredient(
      name: json['name'],
      quantity: json['quantity'],
      freshness: json['freshness'] ?? "unknown",
    );
  }
}