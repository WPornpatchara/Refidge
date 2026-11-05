import 'package:flutter/material.dart';
import '../services/download_storage.dart';
import '../models/meal.dart';
import '../pages/recipe_detail_page.dart';
import '../widgets/refridge_app_bar.dart';
import '../managers/app_locale.dart';
import 'package:re/models/inventory_item.dart';
class DownloadsPage extends StatefulWidget {
  final AppLocale appLocale;

  const DownloadsPage({
    super.key,
    required this.appLocale,
  });

  @override
  State<DownloadsPage> createState() => _DownloadsPageState();
}

class _DownloadsPageState extends State<DownloadsPage> {
  List<String> _ids = [];
  bool _loading = true;

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    final ids = await DownloadStorage.loadIds();
    if (!mounted) return;
    setState(() {
      _ids = ids;
      _loading = false;
    });
  }

  Future<void> _refresh() async {
    final ids = await DownloadStorage.loadIds();
    if (!mounted) return;
    setState(() => _ids = ids);
  }

  Future<bool?> _confirmDelete(bool isThai) {
    return showDialog<bool>(
      context: context,
      builder: (_) => AlertDialog(
        title: Text(isThai ? 'ลบเมนู?' : 'Delete download?'),
        content: Text(
          isThai
              ? 'คุณแน่ใจหรือไม่ว่าต้องการลบเมนูนี้'
              : 'Are you sure you want to delete this menu?',
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
            child: Text(isThai ? 'ลบ' : 'Delete'),
          ),
        ],
      ),
    );
  }

  Future<void> _delete(String id, bool isThai) async {
    final ok = await _confirmDelete(isThai);
    if (ok != true) return;

    await DownloadStorage.remove(id);

    setState(() {
      _ids.remove(id);
    });

    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(content: Text(isThai ? 'ลบแล้ว' : 'Deleted')),
    );
  }

  @override
  Widget build(BuildContext context) {
    final isThai = widget.appLocale.isThai;

    return Scaffold(
      backgroundColor: const Color(0xFFF6F2C6),

      /// ✅ แก้ AppBar ให้ถูกต้อง
      appBar: RefridgeAppBar(
        title: isThai ? 'ดาวน์โหลด' : 'Downloads',
        appLocale: widget.appLocale,
        items: const <InventoryItem>[], // หน้านี้ไม่มี inventory
      ),

      body: RefreshIndicator(
        onRefresh: _refresh,
        child: _loading
            ? const Center(child: CircularProgressIndicator())
            : _ids.isEmpty
                ? ListView(
                    physics: const AlwaysScrollableScrollPhysics(),
                    children: [
                      const SizedBox(height: 140),
                      Center(
                        child: Text(
                          isThai
                              ? 'ยังไม่มีเมนูที่ดาวน์โหลด'
                              : 'No downloads yet',
                        ),
                      ),
                    ],
                  )
                : ListView.builder(
                    padding: const EdgeInsets.all(16),
                    itemCount: _ids.length,
                    itemBuilder: (_, i) {
                      final id = _ids[i];

                      return FutureBuilder<Map<String, dynamic>?>(
                        future: DownloadStorage.loadMeal(id),
                        builder: (_, snap) {
                          if (!snap.hasData) {
                            return const Padding(
                              padding: EdgeInsets.symmetric(vertical: 12),
                              child: LinearProgressIndicator(),
                            );
                          }

                          final meal = Meal.fromMap(snap.data!);

                          return ListTile(
                            tileColor: const Color(0xFFFFC8A8),
                            shape: RoundedRectangleBorder(
                              borderRadius: BorderRadius.circular(18),
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
                              style: const TextStyle(
                                  fontWeight: FontWeight.bold),
                            ),
                            subtitle:
                                Text('${meal.category} • ${meal.area}'),

                            trailing: IconButton(
                              icon:
                                  const Icon(Icons.delete_outline),
                              onPressed: () =>
                                  _delete(id, isThai),
                            ),

                            onTap: () {
                              Navigator.push(
                                context,
                                MaterialPageRoute(
                                  builder: (_) =>
                                      RecipeDetailPage(recipeId: id),
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
