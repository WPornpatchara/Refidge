import 'package:flutter/material.dart';

class FavoriteManager {
  static final ValueNotifier<List<String>> favorites =
      ValueNotifier<List<String>>([]);

  static bool isFavorite(String id) {
    return favorites.value.contains(id);
  }

  static void toggleFavorite(String id) {
    final list = [...favorites.value];
    if (list.contains(id)) {
      list.remove(id);
    } else {
      list.add(id);
    }
    favorites.value = list;
  }
}
