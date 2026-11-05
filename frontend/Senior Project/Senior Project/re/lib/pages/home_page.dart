import 'package:flutter/material.dart';

import '../pages/menu_suggestion_page.dart';
import '../pages/add_ingredients_page.dart';
import '../pages/profile_page.dart';
import '../pages/expense_summary_page.dart';
import '../widgets/refridge_app_bar.dart';
import '../managers/app_locale.dart';
import 'package:re/models/inventory_item.dart';

class HomePage extends StatefulWidget {
  final VoidCallback? onInventoryTap;
  final void Function(InventoryItem item)? onManualAdded;
  final VoidCallback? onExpenseSummaryTap;

  final List<InventoryItem> items;
  final AppLocale appLocale;

  const HomePage({
    super.key,
    required this.items,
    required this.appLocale,
    this.onInventoryTap,
    this.onManualAdded,
    this.onExpenseSummaryTap,
  });

  @override
  State<HomePage> createState() => _HomePageState();
}

class _HomePageState extends State<HomePage> {
  late List<InventoryItem> _items;

  @override
  void initState() {
    super.initState();
    _items = widget.items;
  }

  @override
  void didUpdateWidget(covariant HomePage oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.items != widget.items) {
      setState(() {
        _items = widget.items;
      });
    }
  }

  Color _colorByDays(int days) {
    if (days >= 6) return const Color(0xFFFBEF76);
    if (days >= 4) return const Color(0xFFFEC288);
    if (days >= 3) return const Color(0xFFFD8A6B);
    return const Color(0xFFFA5C5C);
  }

  int _daysLeft(DateTime expire) {
    final now = DateTime.now();
    final a = DateTime(now.year, now.month, now.day);
    final b = DateTime(expire.year, expire.month, expire.day);
    return b.difference(a).inDays;
  }

  void _goProfile(BuildContext context) {
    Navigator.of(context).push(
      MaterialPageRoute(builder: (_) => ProfilePage(appLocale: widget.appLocale)),
    );
  }

  void _goRecommendedMenu(BuildContext context) {
    final products = _items.map((e) => e.displayName(widget.appLocale.isThai)).toList();
    Navigator.of(context).push(
      MaterialPageRoute(
        builder: (_) => MenuSuggestionPage(
          ingredients: products,
          appLocale: widget.appLocale,
        ),
      ),
    );
  }

  Future<void> _goAddIngredients(BuildContext context) async {
    final item = await Navigator.of(context).push<InventoryItem>(
      MaterialPageRoute(
        builder: (_) => AddIngredientsPage(appLocale: widget.appLocale),
      ),
    );

    if (item != null) {
      // ── FIX: ไม่เรียก onInventoryTap อีกต่อไป ──────────────
      // onInventoryTap เรียก _fetchInventory() ซึ่ง race กับ
      // addInventoryItem ที่ยังไม่ finish → fetch ได้ข้อมูลเก่า → item หาย
      //
      // onManualAdded ทำ optimistic update (เพิ่ม item เข้า list ทันที)
      // ซึ่งถูกต้องแล้ว ไม่ต้อง fetch ซ้ำ
      widget.onManualAdded?.call(item);
    }
  }

  // home_page ไม่มี _allItems → ให้ root_page จัดการผ่าน callback
  // ดู onExpenseSummaryTap ใน root_page.dart
  void _goExpenseSummary(BuildContext context) {
    widget.onExpenseSummaryTap?.call();
  }

  @override
  Widget build(BuildContext context) {
    final sorted = [..._items]..sort((a, b) => a.expireDate.compareTo(b.expireDate));
    final reminderItems = sorted.take(4).toList();

    return Scaffold(
      backgroundColor: const Color(0xFFF6F2C6),
      appBar: RefridgeAppBar(
        title: 'Refridge+',
        appLocale: widget.appLocale,
        items: _items,
        onProfileTap: () => _goProfile(context),
      ),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(16),
        child: Column(
          children: [
            Container(
              padding: const EdgeInsets.all(16),
              decoration: BoxDecoration(
                color: Colors.white,
                borderRadius: BorderRadius.circular(26),
                boxShadow: [
                  BoxShadow(
                    color: Colors.black.withOpacity(0.05),
                    blurRadius: 12,
                    offset: const Offset(0, 6),
                  ),
                ],
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    widget.appLocale.isThai ? 'แจ้งเตือน' : 'Reminder',
                    style: const TextStyle(fontSize: 20, fontWeight: FontWeight.bold),
                  ),
                  Text(widget.appLocale.isThai ? 'ใกล้หมดอายุ' : 'Expiring soon'),
                  const SizedBox(height: 12),

                  if (reminderItems.isEmpty)
                    Text(
                      widget.appLocale.isThai
                          ? "ยังไม่มีสินค้า\nเพิ่มจากหน้าหลัก หรือสแกนใบเสร็จ"
                          : "No products yet. Add from Home or Scan receipt.",
                    )
                  else
                    ...reminderItems.map((it) {
                      final d = _daysLeft(it.expireDate);
                      final isExpired = it.freshnessLabel == 'Expired' || it.freshnessLabel.toLowerCase() == 'rotten';
                      final desc = isExpired ? 'Expired' : it.freshnessLabel;

                      return _reminderBubble(
                        alignRight: false,
                        title: it.displayName(widget.appLocale.isThai),
                        qty: it.displayQty(widget.appLocale.isThai),
                        desc: desc,
                        days: isExpired ? 0 : (d < 0 ? 0 : d),
                        isThai: widget.appLocale.isThai,
                      );
                    }),
                ],
              ),
            ),

            const SizedBox(height: 24),

            _bigMenuButton(
              context,
              widget.appLocale.isThai ? 'เมนูแนะนำ' : 'Recommended Menu',
              icon: Icons.restaurant,
              onTap: () => _goRecommendedMenu(context),
            ),

            _bigMenuButton(
              context,
              widget.appLocale.isThai ? 'เพิ่มสินค้า' : 'Add Products',
              icon: Icons.add_circle_outline,
              onTap: () => _goAddIngredients(context),
            ),

            _bigMenuButton(
              context,
              widget.appLocale.isThai ? 'สรุปค่าใช้จ่าย' : 'Expense Summary',
              icon: Icons.receipt_long,
              onTap: () => _goExpenseSummary(context),
            ),
          ],
        ),
      ),
    );
  }

  Widget _reminderBubble({
    required bool alignRight,
    required String title,
    required String qty,
    required String desc,
    required int days,
    required bool isThai,
  }) {
    return Align(
      alignment: alignRight ? Alignment.centerRight : Alignment.centerLeft,
      child: Container(
        width: 320,
        margin: const EdgeInsets.only(bottom: 12),
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
        decoration: BoxDecoration(
          color: _colorByDays(days),
          borderRadius: BorderRadius.circular(22),
        ),
        child: Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Container(
              padding: const EdgeInsets.all(10),
              decoration: BoxDecoration(
                color: const Color(0xFFA6C48A),
                borderRadius: BorderRadius.circular(14),
              ),
              child: const Icon(Icons.timer_outlined, size: 20),
            ),
            const SizedBox(width: 14),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    '$title ($qty)',
                    style: const TextStyle(fontWeight: FontWeight.w600, fontSize: 16),
                  ),
                  const SizedBox(height: 4),
                  Text(desc, style: const TextStyle(fontSize: 12)),
                ],
              ),
            ),
            Column(
              children: [
                const Icon(Icons.schedule, size: 18),
              ],
            ),
          ],
        ),
      ),
    );
  }

  Widget _bigMenuButton(
    BuildContext context,
    String text, {
    required IconData icon,
    VoidCallback? onTap,
  }) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
        margin: const EdgeInsets.only(bottom: 16),
        padding: const EdgeInsets.all(22),
        decoration: BoxDecoration(
          color: const Color(0xFFFFC8A8),
          borderRadius: BorderRadius.circular(26),
        ),
        child: Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            Text(text, style: const TextStyle(fontSize: 22)),
            Icon(icon, size: 42),
          ],
        ),
      ),
    );
  }
}