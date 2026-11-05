import 'package:flutter/material.dart';
import '../managers/history_manager.dart';
import '../services/meal_api_service.dart';
import '../models/meal.dart';
import '../pages/recipe_detail_page.dart';
import '../widgets/refridge_app_bar.dart';
import '../managers/app_locale.dart';
import 'package:re/models/inventory_item.dart';

class HistoryPage extends StatefulWidget {
  final bool skipLoading;

  // ✅ เพิ่ม: ส่ง future ที่โหลดไว้แล้วจากหน้า Profile ได้
  final Future<List<Map<String, dynamic>>>? preloadedFuture;

  final AppLocale appLocale;

  const HistoryPage({
    super.key,
    this.skipLoading = false,
    this.preloadedFuture,
    required this.appLocale,
  });

  @override
  State<HistoryPage> createState() => _HistoryPageState();
}

class _HistoryPageState extends State<HistoryPage> {
  late Future<List<Map<String, dynamic>>> _future;

  @override
  void initState() {
    super.initState();
    _future = widget.preloadedFuture ?? HistoryManager.load();
  }

  Future<void> _refresh() async {
    setState(() => _future = HistoryManager.load());
    await _future.then((_) => null).catchError((_) => null);
  }

  @override
  Widget build(BuildContext context) {
    final isThai = widget.appLocale.isThai;

    return Scaffold(
      backgroundColor: const Color(0xFFF6F2E9),

      /// ✅ AppBar ใหม่ต้องส่ง appLocale + items
      appBar: RefridgeAppBar(
        title: isThai ? 'ประวัติ' : 'History',
        appLocale: widget.appLocale,
        items: const <InventoryItem>[], // หน้านี้ไม่มี items ก็ส่ง [] ไปก่อน
      ),

      body: RefreshIndicator(
        onRefresh: _refresh,
        child: FutureBuilder<List<Map<String, dynamic>>>(
          future: _future,
          builder: (context, snapshot) {
            if (snapshot.connectionState == ConnectionState.waiting) {
              if (widget.skipLoading) {
                return ListView(
                  physics: const AlwaysScrollableScrollPhysics(),
                  children: const [SizedBox(height: 1)],
                );
              }
              return const Center(child: CircularProgressIndicator());
            }

            final items = snapshot.data ?? [];
            if (items.isEmpty) {
              return ListView(
                physics: const AlwaysScrollableScrollPhysics(),
                children: [
                  const SizedBox(height: 140),
                  Center(
                    child: Text(
                      isThai
                          ? 'ยังไม่มีประวัติ\nเปิดสูตรอาหารแล้วจะมาแสดงที่นี่'
                          : 'No history yet\nOpen a recipe to see it here',
                      textAlign: TextAlign.center,
                    ),
                  ),
                ],
              );
            }

            return ListView.builder(
              physics: const AlwaysScrollableScrollPhysics(),
              padding: const EdgeInsets.all(16),
              itemCount: items.length,
              itemBuilder: (_, i) {
                final id = items[i]['id'].toString();

                return FutureBuilder<Meal>(
                  future: MealApiService.fetchMealDetail(id),
                  builder: (context, s) {
                    if (!s.hasData) {
                      return Container(
                        margin: const EdgeInsets.only(bottom: 10),
                        padding: const EdgeInsets.all(14),
                        decoration: BoxDecoration(
                          color: const Color(0xFFFFC8A8),
                          borderRadius: BorderRadius.circular(18),
                        ),
                        child: Row(
                          children: [
                            Container(
                              width: 56,
                              height: 56,
                              decoration: BoxDecoration(
                                color: Colors.black.withOpacity(0.08),
                                borderRadius: BorderRadius.circular(12),
                              ),
                            ),
                            const SizedBox(width: 12),
                            Expanded(
                              child: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  Container(
                                    height: 14,
                                    width: double.infinity,
                                    color: Colors.black.withOpacity(0.08),
                                  ),
                                  const SizedBox(height: 8),
                                  Container(
                                    height: 12,
                                    width: 160,
                                    color: Colors.black.withOpacity(0.06),
                                  ),
                                ],
                              ),
                            ),
                          ],
                        ),
                      );
                    }

                    final meal = s.data!;
                    return Container(
                      margin: const EdgeInsets.only(bottom: 10),
                      child: ListTile(
                        tileColor: const Color(0xFFFFC8A8),
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(18),
                        ),
                        contentPadding: const EdgeInsets.symmetric(
                          horizontal: 14,
                          vertical: 8,
                        ),
                        leading: ClipRRect(
                          borderRadius: BorderRadius.circular(12),
                          child: Image.network(
                            meal.thumbnail,
                            width: 56,
                            height: 56,
                            fit: BoxFit.cover,
                          ),
                        ),
                        title: Text(
                          meal.title,
                          style: const TextStyle(fontWeight: FontWeight.w700),
                        ),
                        subtitle: Text('${meal.category} • ${meal.area}'),
                        onTap: () {
                          Navigator.push(
                            context,
                            MaterialPageRoute(
                              builder: (_) => RecipeDetailPage(recipeId: id),
                            ),
                          );
                        },
                      ),
                    );
                  },
                );
              },
            );
          },
        ),
      ),
    );
  }
}
