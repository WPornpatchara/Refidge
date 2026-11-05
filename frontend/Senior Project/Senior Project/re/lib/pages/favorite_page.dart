import 'package:flutter/material.dart';
import 'package:re/managers/app_locale.dart';
import '../managers/favorite_manager.dart';
import '../services/meal_api_service.dart';
import '../services/download_storage.dart';
import '../models/meal.dart';
import 'recipe_detail_page.dart';
import '../widgets/refridge_app_bar.dart';
import '../pages/profile_page.dart';

class FavoritePage extends StatelessWidget {
  const FavoritePage({super.key, required this.appLocale});

  final AppLocale appLocale;

  Future<bool?> _confirmRemove(BuildContext context) {
    final isThai = appLocale.isThai;

    return showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        backgroundColor: const Color(0xFFD9F2E6),
        title: Text(
          isThai ? 'ลบรายการโปรด?' : 'Remove favorite?',
        ),
        content: Text(
          isThai
              ? 'คุณแน่ใจหรือไม่ว่าต้องการลบเมนูนี้ออกจากรายการโปรด?'
              : 'Are you sure you want to remove this meal from your favorites?',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            child: Text(isThai ? 'ยกเลิก' : 'Cancel'),
          ),
          ElevatedButton(
            style: ElevatedButton.styleFrom(
              backgroundColor: Colors.red,
              foregroundColor: Colors.white,
            ),
            onPressed: () => Navigator.pop(context, true),
            child: Text(isThai ? 'ลบ' : 'Remove'),
          ),
        ],
      ),
    );
  }

  void _goProfile(BuildContext context) {
    Navigator.of(context).push(
      PageRouteBuilder(
        pageBuilder: (_, __, ___) =>
            ProfilePage(appLocale: appLocale),
        transitionDuration: const Duration(milliseconds: 220),
        reverseTransitionDuration: const Duration(milliseconds: 200),
        transitionsBuilder: (_, animation, __, child) {
          return FadeTransition(
            opacity:
                CurvedAnimation(parent: animation, curve: Curves.easeOut),
            child: child,
          );
        },
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final isThai = appLocale.isThai;

    return Scaffold(
      backgroundColor: const Color(0xFFFFF2C6),
      appBar: RefridgeAppBar(
        title: isThai ? 'เมนูโปรด' : 'Favorite Meals',
        appLocale: appLocale,
        items: const [], 
        onProfileTap: () => _goProfile(context),
      ),
      body: Padding(
        padding: const EdgeInsets.all(16),
        child: ValueListenableBuilder<List<String>>(
          valueListenable: FavoriteManager.favorites,
          builder: (context, favorites, _) {
            if (favorites.isEmpty) {
              return Center(
                child: Text(
                  isThai
                      ? 'ยังไม่มีเมนูโปรด 💔\nกด ❤️ เพื่อบันทึกเมนู'
                      : 'No favorite meals yet 💔\nTap ❤️ on a menu to save it',
                  textAlign: TextAlign.center,
                  style: const TextStyle(fontSize: 16),
                ),
              );
            }

            return ListView.builder(
              itemCount: favorites.length,
              itemBuilder: (context, index) {
                return _favoriteMealCard(
                  context,
                  favorites[index],
                  isThai,
                );
              },
            );
          },
        ),
      ),
    );
  }

  Widget _favoriteMealCard(
      BuildContext context, String mealId, bool isThai) {
    return FutureBuilder<Meal>(
      future: MealApiService.fetchMealDetail(mealId),
      builder: (context, snapshot) {
        if (snapshot.connectionState ==
            ConnectionState.waiting) {
          return const Padding(
            padding: EdgeInsets.symmetric(vertical: 12),
            child: LinearProgressIndicator(),
          );
        }

        if (!snapshot.hasData) {
          return const SizedBox.shrink();
        }

        final meal = snapshot.data!;

        return InkWell(
          borderRadius: BorderRadius.circular(22),
          onTap: () {
            Navigator.push(
              context,
              MaterialPageRoute(
                builder: (_) =>
                    RecipeDetailPage(recipeId: meal.id),
              ),
            );
          },
          child: Container(
            margin: const EdgeInsets.only(bottom: 14),
            padding: const EdgeInsets.all(16),
            decoration: BoxDecoration(
              color: const Color(0xFFFFC8A8),
              borderRadius: BorderRadius.circular(22),
            ),
            child: Row(
              children: [
                Expanded(
                  child: Column(
                    crossAxisAlignment:
                        CrossAxisAlignment.start,
                    children: [
                      Text(
                        meal.title,
                        style: const TextStyle(
                            fontSize: 20,
                            fontWeight: FontWeight.bold),
                      ),
                      const SizedBox(height: 6),
                      Text(
                        '${meal.category} • ${meal.area}',
                        style: TextStyle(
                          color:
                              Colors.black.withOpacity(0.6),
                        ),
                      ),
                      const SizedBox(height: 12),

                      // ❤️ Remove
                      IconButton(
                        padding: EdgeInsets.zero,
                        alignment: Alignment.centerLeft,
                        icon: const Icon(Icons.favorite,
                            color: Colors.red),
                        onPressed: () async {
                          final confirmed =
                              await _confirmRemove(context);
                          if (confirmed == true) {
                            FavoriteManager
                                .toggleFavorite(meal.id);
                          }
                        },
                      ),

                      // ⬇ Download
                      ElevatedButton.icon(
                        style: ElevatedButton.styleFrom(
                          backgroundColor: Colors.black,
                          foregroundColor: Colors.white,
                          shape: RoundedRectangleBorder(
                            borderRadius:
                                BorderRadius.circular(14),
                          ),
                        ),
                        onPressed: () async {
                          final detail =
                              await MealApiService
                                  .fetchMealDetail(
                                      meal.id);

                          await DownloadStorage.saveMeal(
                              detail.id, detail.toMap());

                          if (context.mounted) {
                            ScaffoldMessenger.of(context)
                                .showSnackBar(
                              SnackBar(
                                content: Text(
                                  isThai
                                      ? 'ดาวน์โหลดสำเร็จ (ออฟไลน์) ✅'
                                      : 'Downloaded for offline ✅',
                                ),
                              ),
                            );
                          }
                        },
                        icon: const Icon(Icons.download),
                        label: Text(
                          isThai ? 'ดาวน์โหลด' : 'Download',
                        ),
                      ),
                    ],
                  ),
                ),
                ClipRRect(
                  borderRadius: BorderRadius.circular(16),
                  child: Image.network(
                    meal.thumbnail,
                    width: 120,
                    height: 120,
                    fit: BoxFit.cover,
                    errorBuilder: (_, __, ___) =>
                        const Icon(Icons.fastfood,
                            size: 48),
                  ),
                ),
              ],
            ),
          ),
        );
      },
    );
  }
}
