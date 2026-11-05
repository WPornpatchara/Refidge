import 'package:flutter/material.dart';
import '../managers/favorite_manager.dart';
import '../pages/recipe_detail_page.dart';
import '../services/meal_api_service.dart';
import '../widgets/cooking_loading.dart';

class MenuCard extends StatefulWidget {
  final String id;
  final String title;
  final String desc;
  final String imageUrl;

  const MenuCard({
    super.key,
    required this.id,
    required this.title,
    required this.desc,
    required this.imageUrl,
  });

  @override
  State<MenuCard> createState() => _MenuCardState();
}

class _MenuCardState extends State<MenuCard> {
  @override
  Widget build(BuildContext context) {
    final isFav = FavoriteManager.isFavorite(widget.id);

    return Container(
      margin: const EdgeInsets.only(bottom: 20),
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: const Color(0xFFFFC8A8),
        borderRadius: BorderRadius.circular(28),
      ),
      child: Row(
        children: [
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  widget.title,
                  style: const TextStyle(
                    fontSize: 32,
                    fontWeight: FontWeight.bold,
                  ),
                ),
                const SizedBox(height: 8),
                Text(
                  widget.desc,
                  style: TextStyle(
                    fontSize: 20,
                    color: Colors.black.withOpacity(0.65),
                  ),
                ),
                const SizedBox(height: 16),

                Row(
                  children: [
                    /// 🍳 Recipe button (with cooking loading)
                    ElevatedButton(
                      style: ElevatedButton.styleFrom(
                        backgroundColor: Colors.black,
                        foregroundColor: Colors.white,
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(18),
                        ),
                      ),
                      onPressed: () async {
                        // 🔥 show cooking loading
                        showDialog(
                          context: context,
                          barrierDismissible: false,
                          builder: (_) => const CookingLoading(
                            text: 'Cooking recipe...',
                          ),
                        );

                        try {
                          // โหลดข้อมูล recipe เต็ม
                          await MealApiService.fetchMealDetail(widget.id);

                          // ปิด loading
                          Navigator.pop(context);

                          // เข้า detail แบบสมูท
                          Navigator.push(
                            context,
                            PageRouteBuilder(
                              pageBuilder: (_, __, ___) =>
                                  RecipeDetailPage(recipeId: widget.id),
                              transitionDuration:
                                  const Duration(milliseconds: 250),
                              transitionsBuilder:
                                  (_, animation, __, child) {
                                return FadeTransition(
                                  opacity: animation,
                                  child: child,
                                );
                              },
                            ),
                          );
                        } catch (e) {
                          Navigator.pop(context);
                          ScaffoldMessenger.of(context).showSnackBar(
                            const SnackBar(
                              content:
                                  Text('Failed to load recipe 😢'),
                            ),
                          );
                        }
                      },
                      child: const Text(
                        'Recipe 🔍',
                        style: TextStyle(color: Colors.white),
                      ),
                    ),

                    const SizedBox(width: 12),

                    /// ❤️ Favorite
                    IconButton(
                      icon: Icon(
                        isFav ? Icons.favorite : Icons.favorite_border,
                        color: isFav ? Colors.red : Colors.black,
                      ),
                      onPressed: () {
                        setState(() {
                          FavoriteManager.toggleFavorite(widget.id);
                        });
                      },
                    ),
                  ],
                ),
              ],
            ),
          ),

          const SizedBox(width: 16),

          ClipRRect(
            borderRadius: BorderRadius.circular(16),
            child: Image.network(
              widget.imageUrl,
              width: 130,
              height: 130,
              fit: BoxFit.cover,
              errorBuilder: (_, __, ___) =>
                  const Icon(Icons.fastfood, size: 48),
            ),
          ),
        ],
      ),
    );
  }
}
