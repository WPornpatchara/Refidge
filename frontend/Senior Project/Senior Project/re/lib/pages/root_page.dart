import 'package:flutter/material.dart';

import '../managers/app_locale.dart';
import '../services/api_service.dart';
import '../services/notification_service.dart';
import 'home_page.dart';
import 'favorite_page.dart';
import 'scan_page.dart';
import 'search_page.dart';
import 'inventory_page.dart';
import 'expense_summary_page.dart';
import 'add_ingredients_page.dart';

import 'package:re/models/inventory_item.dart';

class RootPage extends StatefulWidget {
  final AppLocale appLocale;

  const RootPage({
    super.key,
    required this.appLocale,
  });

  @override
  State<RootPage> createState() => _RootPageState();
}

class _RootPageState extends State<RootPage> {
  int _currentIndex = 0;

  // inFridge items → ใช้กับ Inventory / Home / Notification
  List<InventoryItem> _items = [];

  // ALL items (inFridge + used + wasted) → ใช้กับ Expense Summary เท่านั้น
  List<InventoryItem> _allItems = [];

  // ป้องกัน fetch ซ้อนกันตอนกำลัง save item อยู่
  bool _isSaving = false;

  @override
  void initState() {
    super.initState();
    _fetchInventory();
  }

  Future<void> _fetchInventory() async {
    if (_isSaving) return; // รอ save เสร็จก่อน ไม่งั้น item หายได้
    try {
      // ดึงพร้อมกัน 2 endpoint
      final results = await Future.wait([
        ApiService.fetchInventory(),      // inFridge only
        ApiService.fetchAllInventory(),   // inFridge + used + wasted
      ]);

      if (mounted) {
        setState(() {
          _items    = results[0];
          _allItems = results[1];
        });

        // reschedule notification ทุกครั้งที่ inventory เปลี่ยน
        await NotificationService.I.scheduleFromInventory(_items);
      }
    } catch (e) {
      debugPrint('Fetch inventory failed: $e');
    }
  }

  void _setItems(List<InventoryItem> next) {
    setState(() => _items = List<InventoryItem>.from(next));
    // refresh allItems ด้วยเพื่อให้ expense summary อัปเดต
    ApiService.fetchAllInventory().then((all) {
      if (mounted) setState(() => _allItems = all);
      NotificationService.I.scheduleFromInventory(next);
    }).catchError((e) => debugPrint('Fetch allItems failed: $e'));
  }

  void _addManualItem(InventoryItem item) {
    // optimistic update ก่อน — user เห็นทันที ไม่ต้องรอ backend
    setState(() {
      _items        = [item, ..._items];
      _allItems     = [item, ..._allItems];
      _currentIndex = 1;
    });

    // save ลง backend แล้ว refresh ให้ได้ id จริงจาก server
    _isSaving = true;
    ApiService.addInventoryItem(item).then((_) {
      _isSaving = false;
      // backend save สำเร็จ → fetch ใหม่เพื่อได้ id และ initial_quantity ที่ถูกต้อง
      _fetchInventory();
    }).catchError((e) {
      _isSaving = false;
      debugPrint('Add manual item failed: $e');
      // ถ้า save ไม่สำเร็จ → เอา item ออกจาก list
      if (mounted) {
        setState(() {
          _items    = _items.where((i) => i.id != item.id).toList();
          _allItems = _allItems.where((i) => i.id != item.id).toList();
        });
      }
    });
  }

  Future<void> _addScannedItems(List<InventoryItem> items) async {
    if (items.isEmpty) return;
    setState(() {
      _items    = [...items, ..._items];
      _allItems = [...items, ..._allItems];
      _currentIndex = 1;
    });

    _isSaving = true; // ✅ ป้องกัน fetch ซ้อนตอนกำลัง Add
    try {
      for (final item in items) {
        await ApiService.addInventoryItem(item);
      }
      _isSaving = false;
      _fetchInventory(); // ✅ ดึงข้อมูลจากเซิร์ฟเวอร์อีกรอบเพื่อให้ได้ ID จริง และโชว์ใน Expense ได้ทันที
    } catch (e) {
      _isSaving = false;
      debugPrint('Add scanned items failed: $e');
    }
  }

  Future<void> _openAddIngredient() async {
    final newItem = await Navigator.push<InventoryItem>(
      context,
      MaterialPageRoute(
        builder: (_) => AddIngredientsPage(appLocale: widget.appLocale),
      ),
    );
    if (newItem != null) _addManualItem(newItem);
  }

  // ── open expense summary ──────────────────────────────────
  // refresh allItems ก่อนเปิดเสมอ เพื่อให้ได้ข้อมูลล่าสุด
  Future<void> _openExpenseSummary() async {
    try {
      final all = await ApiService.fetchAllInventory();
      if (mounted) setState(() => _allItems = all);
    } catch (_) {}
    if (!mounted) return;
    Navigator.push(
      context,
      MaterialPageRoute(
        builder: (_) => ExpenseSummaryPage(
          appLocale: widget.appLocale,
          items: _allItems,   // ← ส่ง ALL items เสมอ
        ),
      ),
    );
  }

  List<Widget> _buildPages() => [
        /// 0 - Home
        HomePage(
          items: _items,
          appLocale: widget.appLocale,
          onInventoryTap: () {
            setState(() => _currentIndex = 1);
            _fetchInventory();
          },
          onManualAdded:       _addManualItem,
          onExpenseSummaryTap: _openExpenseSummary,
        ),

        /// 1 - Inventory
        InventoryPage(
          items:         _items,
          appLocale:     widget.appLocale,
          onItemsChanged: _setItems,
          isVisible:     _currentIndex == 1,
        ),

        /// 2 - Scan
        ScanPage(
          appLocale: widget.appLocale,
          onScanned: _addScannedItems,
        ),

        /// 3 - Favorite
        FavoritePage(appLocale: widget.appLocale),

        /// 4 - Search
        SearchPage(appLocale: widget.appLocale),
      ];

  @override
  Widget build(BuildContext context) {
    final pages = _buildPages();

    return Scaffold(
      body: IndexedStack(index: _currentIndex, children: pages),
      bottomNavigationBar: _bottomBar(),
    );
  }

  Widget _bottomBar() {
    return Container(
      height: 72,
      color: const Color(0xFFA6C48A),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceAround,
        children: [
          _nav(Icons.home, 0),
          _nav(Icons.inventory_2_outlined, 1),
          _scanButton(),
          _nav(Icons.favorite, 3),
          _nav(Icons.search, 4),
        ],
      ),
    );
  }

  Widget _nav(IconData icon, int index) {
    return IconButton(
      icon: Icon(icon,
          color: _currentIndex == index ? Colors.black : Colors.black54),
      onPressed: () {
        setState(() => _currentIndex = index);
        // fetch เฉพาะตอนสลับไป Inventory (tab 1)
        // ไม่ fetch ตอนสลับไป Home เพราะอาจ overwrite optimistic update
        if (index == 1) _fetchInventory();
      },
    );
  }

  Widget _scanButton() {
    return GestureDetector(
      onTap: () => setState(() => _currentIndex = 2),
      child: Container(
        height: 58, width: 58,
        decoration: const BoxDecoration(
          color: Color(0xFFD9F2E6),
          shape: BoxShape.circle,
        ),
        child: const Icon(Icons.document_scanner,
            size: 30, color: Colors.black),
      ),
    );
  }
}