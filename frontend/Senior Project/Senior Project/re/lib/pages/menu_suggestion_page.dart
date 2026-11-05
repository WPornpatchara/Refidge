import 'package:flutter/material.dart';
import '../services/meal_api_service.dart';
import '../models/meal.dart';
import '../widgets/menu_card.dart';
import '../widgets/refridge_app_bar.dart';
import '../widgets/food_loading.dart';
import '../managers/app_locale.dart';

class MenuSuggestionPage extends StatefulWidget {
  // ✅ รับวัตถุดิบจาก inventory
  final List<String> ingredients;

  // ✅ รับ locale กลางทั้งแอป
  final AppLocale appLocale;

  const MenuSuggestionPage({
    super.key,
    required this.ingredients,
    required this.appLocale,
  });

  @override
  State<MenuSuggestionPage> createState() => _MenuSuggestionPageState();
}

class _MenuSuggestionPageState extends State<MenuSuggestionPage> {
  late Future<List<Meal>> _mealsFuture;

  @override
  void initState() {
    super.initState();
    _mealsFuture = _load();
  }

  Future<List<Meal>> _load() {
    return MealApiService.fetchMealsByIngredients(
      widget.ingredients,
      count: 10,
      minMatch: 1,
    );
  }

  Future<void> _refresh() async {
    setState(() {
      _mealsFuture = _load();
    });
    await _mealsFuture;
  }

  @override
  Widget build(BuildContext context) {
    final isThai = widget.appLocale.isThai;

    return Scaffold(
      backgroundColor: const Color(0xFFF6F2C6),

      appBar: RefridgeAppBar(
        title: isThai ? 'เมนูแนะนำ' : 'Menu Suggestion',
        appLocale: widget.appLocale,
        items: const [], 
      ),

      body: Column(
        children: [
          // ✅ เพิ่มแถบข้อความเพื่อบอกวิธีการเรียง
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
            width: double.infinity,
            color: const Color(0xFFF6F2C6),
            child: Row(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                const Icon(Icons.sort, size: 16, color: Colors.black54),
                const SizedBox(width: 8),
                Text(
                  isThai ? 'เรียงจากวัตถุดิบที่ใกล้หมดอายุก่อน' : 'Sorted by ingredients expiring soon',
                  style: const TextStyle(color: Colors.black54, fontSize: 13),
                ),
              ],
            ),
          ),
          Expanded(
            child: RefreshIndicator(
              onRefresh: _refresh,
              child: FutureBuilder<List<Meal>>(
                future: _mealsFuture,
                builder: (context, snapshot) {
                  if (snapshot.connectionState == ConnectionState.waiting) {
                    return FoodLoading(
                      text: isThai ? 'กำลังโหลดเมนู...' : 'Loading menu...',
                    );
                  }

                  if (snapshot.hasError) {
                    return ListView(
                      physics: const AlwaysScrollableScrollPhysics(),
                      padding: const EdgeInsets.all(16),
                      children: [
                        const SizedBox(height: 120),
                        Center(
                          child: Text(
                            isThai
                                ? 'โหลดเมนูไม่สำเร็จ\nดึงลงเพื่อรีเฟรช'
                                : 'Failed to load menu\nPull down to refresh',
                            textAlign: TextAlign.center,
                          ),
                        ),
                      ],
                    );
                  }

                  final meals = snapshot.data ?? [];

                  if (meals.isEmpty) {
                    return ListView(
                      physics: const AlwaysScrollableScrollPhysics(),
                      padding: const EdgeInsets.all(16),
                      children: [
                        const SizedBox(height: 120),
                        Center(
                          child: Text(
                            isThai
                                ? 'ไม่มีเมนูที่ตรงกับสินค้าของคุณ\nลองเพิ่มสินค้าให้มากขึ้น'
                                : 'No menu matches your products\nTry adding more products',
                            textAlign: TextAlign.center,
                          ),
                        ),
                      ],
                    );
                  }

                  return ListView.builder(
                    physics: const AlwaysScrollableScrollPhysics(),
                    padding: const EdgeInsets.all(16),
                    itemCount: meals.length,
                    itemBuilder: (context, index) {
                      final meal = meals[index];

                      final category = meal.category.isNotEmpty
                          ? meal.category
                          : (isThai ? 'ไม่ทราบประเภท' : 'Unknown');
                      final area = meal.area.isNotEmpty
                          ? meal.area
                          : (isThai ? 'ไม่ทราบประเทศ' : 'Unknown');

                      return MenuCard(
                        id: meal.id,
                        title: meal.title, // ✅ ตามที่คุณขอ: ไม่แปลชื่อเมนู
                        desc: '$category • $area', // ✅ ไม่แปลประเทศ/พื้นที่ (คงเดิมจาก API)
                        imageUrl: meal.thumbnail,
                      );
                    },
                  );
                },
              ),
            ),
          ),
        ],
      ),
    );
  }
}
