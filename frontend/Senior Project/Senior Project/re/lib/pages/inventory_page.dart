import 'package:flutter/material.dart';
import 'package:re/managers/app_locale.dart';
import '../widgets/refridge_app_bar.dart';
import '../services/ingredient_image_service.dart';
import '../services/product_name_dict.dart';
import '../services/api_service.dart';
import '../services/unit_dict.dart';
import 'inventory_edit_page.dart';
import 'add_ingredients_page.dart';
import 'package:re/models/inventory_item.dart';

class InventoryPage extends StatefulWidget {
  final AppLocale appLocale;
  final List<InventoryItem> items;
  final void Function(List<InventoryItem>) onItemsChanged;
  final bool isVisible;

  const InventoryPage({
    super.key,
    required this.appLocale,
    required this.items,
    required this.onItemsChanged,
    this.isVisible = false,
  });

  @override
  State<InventoryPage> createState() => _InventoryPageState();
}

class _InventoryPageState extends State<InventoryPage> {
  bool _isLoading = false;
  TextEditingController? _useCtrl;
  Map<String, bool> _expandedGroups = {};
  final Map<String, String> _locationCache = {};

  static const _bg    = Color(0xFFF7F0B9);
  static const _card  = Color(0xFFBFE3FF);
  static const _green = Color(0xFF3D7A56);
  static const _red   = Color(0xFFC0392B);
  static const _dark  = Color(0xFF2C1A0E);

  @override
  void initState() {
    super.initState();
    _refreshFromBackend();
  }

  @override
  void dispose() {
    _useCtrl?.dispose();
    super.dispose();
  }

  Future<void> _refreshFromBackend() async {
    if (widget.items.isEmpty) setState(() => _isLoading = true);
    try {
      final freshItems = await ApiService.fetchInventory();
      widget.onItemsChanged(freshItems);
    } catch (e) {
      debugPrint("Fetch error: $e");
    }
    if (mounted) setState(() => _isLoading = false);
  }

  Future<void> _handleAdd() async {
    final result = await Navigator.push<InventoryItem>(
      context,
      MaterialPageRoute(builder: (_) => AddIngredientsPage(appLocale: widget.appLocale)),
    );
    if (result == null) return;
    try {
      await ApiService.addInventoryItem(result);
      await _refreshFromBackend();
    } catch (e) {
      debugPrint("Add error: $e");
    }
  }

  Future<void> _openEdit(InventoryItem item) async {
    final result = await Navigator.push<InventoryEditResult>(
      context,
      MaterialPageRoute(
          builder: (_) => InventoryEditPage(item: item, appLocale: widget.appLocale)),
    );
    if (result == null) return;
    try {
      if (result.deleted) {
        // ── Option C: ถามก่อนลบ ──────────────────────────────
        await _showDeleteReasonSheet(item);
        return; // _showDeleteReasonSheet จัดการ API call เอง
      } else if (result.item != null) {
        await ApiService.updateInventoryItem(result.item!);
      }
      await _refreshFromBackend();
    } catch (e) {
      debugPrint("Update/Delete error: $e");
    }
  }

  // ── delete reason bottom sheet ────────────────────────────────────────────
  //
  // แสดง 3 ตัวเลือก:
  //   1. ใส่ผิด → hard delete (ไม่นับใน Spent)
  //   2. ใช้หมดแล้ว → mark used (นับใน Used)
  //   3. ของเสีย/หมดอายุ → mark wasted (นับใน Wasted)

  Future<void> _showDeleteReasonSheet(InventoryItem item) async {
    final isThai = widget.appLocale.isThai;

    await showModalBottomSheet(
      context: context,
      backgroundColor: Colors.transparent,
      isScrollControlled: true,
      builder: (ctx) => Container(
        padding: const EdgeInsets.fromLTRB(24, 20, 24, 32),
        decoration: const BoxDecoration(
          color: Color(0xFFF6F2C6),
          borderRadius: BorderRadius.vertical(top: Radius.circular(28)),
        ),
        child: Column(mainAxisSize: MainAxisSize.min, children: [

          // handle bar
          Center(child: Container(
            width: 40, height: 4,
            margin: const EdgeInsets.only(bottom: 16),
            decoration: BoxDecoration(
              color: _dark.withOpacity(0.15),
              borderRadius: BorderRadius.circular(999),
            ),
          )),

          // title
          Text(
            isThai ? 'ลบเพราะอะไร?' : 'Why are you removing this?',
            style: const TextStyle(fontSize: 18, fontWeight: FontWeight.w900),
          ),
          const SizedBox(height: 6),
          Text(
            item.displayName(isThai),
            style: TextStyle(fontSize: 13, color: _dark.withOpacity(0.5)),
          ),
          const SizedBox(height: 24),

          // ── Option 1: ใส่ผิด ──────────────────────────────────
          _reasonTile(
            ctx: ctx,
            icon: Icons.edit_off_outlined,
            iconColor: const Color(0xFF888888),
            title: isThai ? 'ใส่ผิด / เพิ่มมาผิด' : 'Added by mistake',
            subtitle: isThai
                ? 'ลบออกจากระบบ ไม่นับใน Spent'
                : 'Remove completely · not counted in Spent',
            onTap: () async {
              Navigator.pop(ctx);
              // hard delete — ลบออกจาก DB จริงๆ
              // backend ต้องมี endpoint DELETE /inventory/{id}?reason=cancelled
              // หรือ DELETE จริง ขึ้นอยู่กับที่ implement
              try {
                await ApiService.hardDeleteInventoryItem(item.id);
                await _refreshFromBackend();
                if (mounted) {
                  ScaffoldMessenger.of(context).showSnackBar(SnackBar(
                    content: Text(isThai ? 'ลบออกแล้ว' : 'Removed'),
                    behavior: SnackBarBehavior.floating,
                    duration: const Duration(seconds: 2),
                  ));
                }
              } catch (e) {
                debugPrint('Hard delete error: $e');
              }
            },
          ),

          const SizedBox(height: 12),

          // ── Option 2: ใช้หมดแล้ว ─────────────────────────────
          _reasonTile(
            ctx: ctx,
            icon: Icons.check_circle_outline,
            iconColor: _green,
            title: isThai ? 'ใช้หมดแล้ว' : 'All used up',
            subtitle: isThai
                ? 'นับใน Used · Spent ยังคงเดิม'
                : 'Counted in Used · Spent stays the same',
            onTap: () async {
              Navigator.pop(ctx);
              try {
                // mark used ทั้งหมด = use qty เท่ากับที่เหลือ
                await ApiService.useInventoryItem(item.id, item.quantity);
                await _refreshFromBackend();
                if (mounted) {
                  ScaffoldMessenger.of(context).showSnackBar(SnackBar(
                    content: Text(isThai
                        ? '${item.displayName(isThai)} ใช้หมดแล้ว ✓'
                        : '${item.displayName(isThai)} marked as used ✓'),
                    backgroundColor: _green,
                    behavior: SnackBarBehavior.floating,
                    duration: const Duration(seconds: 2),
                  ));
                }
              } catch (e) {
                debugPrint('Mark used error: $e');
              }
            },
          ),

          const SizedBox(height: 12),

          // ── Option 3: ของเสีย ─────────────────────────────────
          _reasonTile(
            ctx: ctx,
            icon: Icons.delete_outline,
            iconColor: _red,
            title: isThai ? 'ของเสีย / หมดอายุ' : 'Spoiled / expired',
            subtitle: isThai
                ? 'นับใน Wasted · เตือนว่าซื้อเกิน'
                : 'Counted in Wasted · signals overbuying',
            onTap: () async {
              Navigator.pop(ctx);
              try {
                await ApiService.deleteInventoryItem(item.id);
                await _refreshFromBackend();
                if (mounted) {
                  ScaffoldMessenger.of(context).showSnackBar(SnackBar(
                    content: Text(isThai
                        ? '${item.displayName(isThai)} บันทึกเป็นของเสีย'
                        : '${item.displayName(isThai)} marked as wasted'),
                    backgroundColor: _red,
                    behavior: SnackBarBehavior.floating,
                    duration: const Duration(seconds: 2),
                  ));
                }
              } catch (e) {
                debugPrint('Mark wasted error: $e');
              }
            },
          ),

          const SizedBox(height: 16),

          // cancel
          SizedBox(
            width: double.infinity,
            child: TextButton(
              onPressed: () => Navigator.pop(ctx),
              child: Text(
                isThai ? 'ยกเลิก' : 'Cancel',
                style: TextStyle(color: _dark.withOpacity(0.5), fontSize: 14),
              ),
            ),
          ),
        ]),
      ),
    );
  }

  Widget _reasonTile({
    required BuildContext ctx,
    required IconData icon,
    required Color iconColor,
    required String title,
    required String subtitle,
    required VoidCallback onTap,
  }) {
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(16),
      child: Container(
        padding: const EdgeInsets.all(16),
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(16),
          border: Border.all(color: _dark.withOpacity(0.08)),
        ),
        child: Row(children: [
          Container(
            width: 42, height: 42,
            decoration: BoxDecoration(
              color: iconColor.withOpacity(0.1),
              borderRadius: BorderRadius.circular(12),
            ),
            child: Icon(icon, color: iconColor, size: 22),
          ),
          const SizedBox(width: 14),
          Expanded(child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(title,
                  style: const TextStyle(
                      fontSize: 15, fontWeight: FontWeight.w800)),
              const SizedBox(height: 2),
              Text(subtitle,
                  style: TextStyle(
                      fontSize: 12, color: _dark.withOpacity(0.5))),
            ],
          )),
          Icon(Icons.chevron_right, color: _dark.withOpacity(0.3), size: 20),
        ]),
      ),
    );
  }

  // ── "ใช้แล้ว" bottom sheet ─────────────────────────────────────────────────
  Future<void> _showUseSheet(InventoryItem item) async {
    final isThai      = widget.appLocale.isThai;
    final maxQty      = item.quantity;
    final isWholeUnit = item.unit == 'piece' || item.unit == 'ชิ้น';

    _useCtrl?.dispose();
    _useCtrl = TextEditingController(text: isWholeUnit ? '1' : '0.1');
    final ctrl = _useCtrl!;

    await showModalBottomSheet(
      context: context,
      backgroundColor: Colors.transparent,
      isScrollControlled: true,
      builder: (ctx) {
        return StatefulBuilder(builder: (ctx, setSheet) {
          final parsed    = (double.tryParse(ctrl.text) ?? 0).clamp(0.0, maxQty);
          final remaining = (maxQty - parsed).clamp(0.0, maxQty);
          final isMax     = parsed >= maxQty;
          final valid     = parsed > 0;

          void setQty(double v) {
            final clamped = v.clamp(0.0, maxQty);
            ctrl.text = isWholeUnit
                ? clamped.toStringAsFixed(0)
                : clamped.toStringAsFixed(1);
            setSheet(() {});
          }

          return Container(
            padding: EdgeInsets.only(
              left: 24, right: 24, top: 20,
              bottom: MediaQuery.of(ctx).viewInsets.bottom + 24,
            ),
            decoration: const BoxDecoration(
              color: Color(0xFFF6F2C6),
              borderRadius: BorderRadius.vertical(top: Radius.circular(28)),
            ),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [

                // handle bar
                Center(child: Container(
                  width: 40, height: 4,
                  margin: const EdgeInsets.only(bottom: 16),
                  decoration: BoxDecoration(
                    color: _dark.withOpacity(0.15),
                    borderRadius: BorderRadius.circular(999),
                  ),
                )),

                Text(isThai ? 'ใช้วัตถุดิบ' : 'Mark as Used',
                    style: const TextStyle(fontSize: 18, fontWeight: FontWeight.w900)),
                const SizedBox(height: 4),
                Text(
                  '${item.displayName(isThai)}  ·  ${isThai ? "มี" : "Stock:"} ${maxQty.toStringAsFixed(maxQty == maxQty.roundToDouble() ? 0 : 1)} ${UnitDict.text(item.unit, isThai)}',
                  style: TextStyle(fontSize: 13, color: _dark.withOpacity(0.55)),
                ),

                const SizedBox(height: 20),

                // ── stepper row ──────────────────────────────────────────────
                Row(crossAxisAlignment: CrossAxisAlignment.center, children: [
                  Text(isThai ? 'จำนวนที่ใช้' : 'Qty used',
                      style: const TextStyle(fontWeight: FontWeight.w700, fontSize: 14)),
                  const Spacer(),

                  // − button
                  _stepBtn(
                    icon: Icons.remove,
                    enabled: parsed > (isWholeUnit ? 1 : 0.1),
                    onTap: () => setQty(isWholeUnit
                        ? (parsed - 1)
                        : double.parse((parsed - 0.1).toStringAsFixed(1))),
                  ),
                  const SizedBox(width: 8),

                  // text field
                  SizedBox(
                    width: 70,
                    child: TextField(
                      controller: ctrl,
                      keyboardType:
                          const TextInputType.numberWithOptions(decimal: true),
                      textAlign: TextAlign.center,
                      style: const TextStyle(
                          fontSize: 20, fontWeight: FontWeight.w900),
                      decoration: InputDecoration(
                        isDense: true,
                        contentPadding: const EdgeInsets.symmetric(
                            vertical: 8, horizontal: 6),
                        filled: true,
                        fillColor: Colors.white,
                        border: OutlineInputBorder(
                          borderRadius: BorderRadius.circular(10),
                          borderSide: BorderSide.none,
                        ),
                        suffix: Text(UnitDict.text(item.unit, isThai),
                            style: TextStyle(
                                fontSize: 11,
                                color: _dark.withOpacity(0.5))),
                      ),
                      onChanged: (_) => setSheet(() {}),
                    ),
                  ),
                  const SizedBox(width: 8),

                  // + button
                  _stepBtn(
                    icon: Icons.add,
                    enabled: parsed < maxQty,
                    onTap: () => setQty(isWholeUnit
                        ? (parsed + 1)
                        : double.parse((parsed + 0.1).toStringAsFixed(1))),
                  ),
                  const SizedBox(width: 8),

                  // ── MAX button ────────────────────────────────────────────
                  GestureDetector(
                    onTap: isMax ? null : () => setQty(maxQty),
                    child: AnimatedContainer(
                      duration: const Duration(milliseconds: 150),
                      padding: const EdgeInsets.symmetric(
                          horizontal: 12, vertical: 8),
                      decoration: BoxDecoration(
                        color: isMax ? _green : _green.withOpacity(0.12),
                        borderRadius: BorderRadius.circular(10),
                        border: Border.all(
                          color: isMax ? _green : _green.withOpacity(0.35),
                          width: 1.5,
                        ),
                      ),
                      child: Text('MAX',
                          style: TextStyle(
                            fontSize: 12,
                            fontWeight: FontWeight.w900,
                            color: isMax ? Colors.white : _green,
                          )),
                    ),
                  ),
                ]),

                const SizedBox(height: 10),

                // remaining info
                Row(children: [
                  Icon(
                    valid ? Icons.check_circle_outline : Icons.error_outline,
                    size: 14, color: valid ? _green : _red,
                  ),
                  const SizedBox(width: 6),
                  Text(
                    valid
                        ? (isThai
                            ? 'เหลือ ${remaining.toStringAsFixed(remaining == remaining.roundToDouble() ? 0 : 1)} ${UnitDict.text(item.unit, isThai)}'
                            : 'Remaining: ${remaining.toStringAsFixed(remaining == remaining.roundToDouble() ? 0 : 1)} ${UnitDict.text(item.unit, isThai)}')
                        : (isThai ? 'กรุณาใส่จำนวน' : 'Enter a quantity'),
                    style: TextStyle(
                        fontSize: 12,
                        color: valid ? _dark.withOpacity(0.55) : _red),
                  ),
                  if (isMax && valid) ...[
                    const SizedBox(width: 6),
                    Container(
                      padding: const EdgeInsets.symmetric(
                          horizontal: 8, vertical: 2),
                      decoration: BoxDecoration(
                        color: _green.withOpacity(0.12),
                        borderRadius: BorderRadius.circular(999),
                      ),
                      child: Text(
                        isThai ? '✓ ใช้หมดเลย' : '✓ All used up',
                        style: TextStyle(
                            fontSize: 10,
                            color: _green,
                            fontWeight: FontWeight.w700),
                      ),
                    ),
                  ],
                ]),

                const SizedBox(height: 20),

                // confirm button
                SizedBox(
                  width: double.infinity,
                  child: ElevatedButton(
                    onPressed: valid
                        ? () async {
                            Navigator.pop(ctx);
                            await _confirmUse(item, parsed);
                          }
                        : null,
                    style: ElevatedButton.styleFrom(
                      backgroundColor: _green,
                      disabledBackgroundColor: _dark.withOpacity(0.1),
                      foregroundColor: Colors.white,
                      padding: const EdgeInsets.symmetric(vertical: 14),
                      shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(16)),
                    ),
                    child: Text(
                      isThai ? 'ยืนยัน ✓' : 'Confirm ✓',
                      style: const TextStyle(
                          fontSize: 15, fontWeight: FontWeight.w900),
                    ),
                  ),
                ),
              ],
            ),
          );
        });
      },
    );
  }

  Future<void> _confirmUse(InventoryItem item, double qty) async {
    try {
      await ApiService.useInventoryItem(item.id, qty);
      await _refreshFromBackend();
      if (mounted) {
        final isThai = widget.appLocale.isThai;
        final qtyStr = qty == qty.roundToDouble()
            ? qty.toStringAsFixed(0) : qty.toStringAsFixed(1);
        ScaffoldMessenger.of(context).showSnackBar(SnackBar(
          content: Text(isThai
              ? 'บันทึกแล้ว: ${item.displayName(isThai)} ×$qtyStr'
              : 'Marked used: ${item.displayName(isThai)} ×$qtyStr'),
          backgroundColor: _green,
          behavior: SnackBarBehavior.floating,
          duration: const Duration(seconds: 2),
        ));
      }
    } catch (e) {
      debugPrint("Use error: $e");
    }
  }

  Widget _stepBtn({
    required IconData icon,
    required bool enabled,
    required VoidCallback onTap,
  }) {
    return GestureDetector(
      onTap: enabled ? onTap : null,
      child: Container(
        width: 36, height: 36,
        decoration: BoxDecoration(
          color: enabled ? _dark : _dark.withOpacity(0.12),
          borderRadius: BorderRadius.circular(10),
        ),
        child: Icon(icon,
            color: enabled ? Colors.white : _dark.withOpacity(0.3), size: 18),
      ),
    );
  }

  Widget _buildSummaryCard(String groupKey, InventoryItem earliestItem, double totalQty, double totalVal, bool isExpanded, bool isThai) {
    final displayName = earliestItem.displayName(isThai);
    final imgKey = earliestItem.nameEn.trim().isNotEmpty
        ? earliestItem.nameEn.trim()
        : ProductNameDict.toEnglish(earliestItem.nameTh);
    final fallbackImgUrl = IngredientImageService.fromName(
        imgKey.toLowerCase().replaceAll(' ', '_'));

    final displayImgUrl = (earliestItem.imageUrl != null && earliestItem.imageUrl!.isNotEmpty)
        ? (earliestItem.imageUrl!.startsWith('/') ? '${ApiService.baseUrl}${earliestItem.imageUrl}' : earliestItem.imageUrl!)
        : fallbackImgUrl;

    final now      = DateTime.now();
    final daysLeft = earliestItem.expireDate
        .difference(
            DateTime(now.year, now.month, now.day))
        .inDays;
    final isExpired = earliestItem.freshnessLabel == 'Expired' || earliestItem.freshnessLabel.toLowerCase() == 'rotten';
    final expColor = (daysLeft <= 0 || isExpired)
        ? _red
        : daysLeft <= 2
            ? Colors.orange
            : _dark.withOpacity(0.55);
    final expText = isExpired ? 'Expired' : earliestItem.freshnessLabel;

    return GestureDetector(
      onTap: () {
        setState(() {
          _expandedGroups[groupKey] = !isExpanded;
        });
      },
      child: Container(
        margin: const EdgeInsets.only(bottom: 14),
        padding: const EdgeInsets.all(14),
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(16),
          border: Border.all(color: _card, width: 2),
        ),
        child: Row(
          crossAxisAlignment: CrossAxisAlignment.center,
          children: [
            ClipRRect(
              borderRadius: BorderRadius.circular(10),
              child: Image.network(
                displayImgUrl,
                width: 70, height: 70, fit: BoxFit.cover,
                errorBuilder: (_, __, ___) => Container(
                  width: 70, height: 70,
                  color: Colors.grey.shade300,
                  child: const Icon(Icons.fastfood),
                ),
              ),
            ),
            const SizedBox(width: 14),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(displayName,
                      style: const TextStyle(
                          fontSize: 16,
                          fontWeight: FontWeight.bold)),
                  const SizedBox(height: 4),
                  Text(
                    '${isThai ? 'ทั้งหมด' : 'Total'} ${totalQty.toStringAsFixed(totalQty == totalQty.roundToDouble() ? 0 : 2)} ${UnitDict.text(earliestItem.unit, isThai)}',
                    style: TextStyle(
                        fontSize: 13,
                        fontWeight: FontWeight.w600,
                        color: _dark.withOpacity(0.7)),
                  ),
                  const SizedBox(height: 2),
                  Text(
                    isThai 
                        ? 'มูลค่ารวม ฿${totalVal == totalVal.roundToDouble() ? totalVal.toStringAsFixed(0) : totalVal.toStringAsFixed(2)}'
                        : 'Total Value ฿${totalVal == totalVal.roundToDouble() ? totalVal.toStringAsFixed(0) : totalVal.toStringAsFixed(2)}',
                    style: TextStyle(
                        fontSize: 12,
                        color: _dark.withOpacity(0.55)),
                  ),
                  const SizedBox(height: 4),
                  Row(children: [
                    Icon(Icons.warning_amber_rounded,
                        size: 14, color: expColor),
                    const SizedBox(width: 4),
                    Text(
                        isThai ? 'ใกล้หมดอายุสุด: $expText' : 'Soonest: $expText',
                        style: TextStyle(
                            fontSize: 12,
                            color: expColor,
                            fontWeight: daysLeft <= 1
                                ? FontWeight.w700
                                : FontWeight.normal)),
                  ]),
                ],
              ),
            ),
            Icon(
              isExpanded ? Icons.keyboard_arrow_up : Icons.keyboard_arrow_down,
              color: _dark.withOpacity(0.5),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildItemCard(InventoryItem it, bool isThai, {bool isChild = false, String locationOverride = ''}) {
    final locationText = locationOverride.isNotEmpty ? locationOverride : '';
    final displayName = it.displayName(isThai) + (locationText.isNotEmpty ? ' ($locationText)' : '');
    final imgKey = it.nameEn.trim().isNotEmpty
        ? it.nameEn.trim()
        : ProductNameDict.toEnglish(it.nameTh);
    final fallbackImgUrl = IngredientImageService.fromName(
        imgKey.toLowerCase().replaceAll(' ', '_'));

    final displayImgUrl = (it.imageUrl != null && it.imageUrl!.isNotEmpty)
        ? (it.imageUrl!.startsWith('/') ? '${ApiService.baseUrl}${it.imageUrl}' : it.imageUrl!)
        : fallbackImgUrl;

    final now      = DateTime.now();
    final daysLeft = it.expireDate
        .difference(
            DateTime(now.year, now.month, now.day))
        .inDays;
    final isExpired = it.freshnessLabel == 'Expired' || it.freshnessLabel.toLowerCase() == 'rotten';
    final expColor = (daysLeft <= 0 || isExpired)
        ? _red
        : daysLeft <= 2
            ? Colors.orange
            : _dark.withOpacity(0.55);
    final expText = isExpired ? 'Expired' : it.freshnessLabel;

    final totalPrice = it.price * it.quantity;
    final priceStr = (it.price == it.price.roundToDouble()) ? it.price.toStringAsFixed(0) : it.price.toStringAsFixed(2);

    return Container(
      margin: EdgeInsets.only(
        bottom: 14,
        left: isChild ? 24 : 0,
      ),
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: _card,
        borderRadius: BorderRadius.circular(16),
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // image
          ClipRRect(
            borderRadius: BorderRadius.circular(10),
            child: Image.network(
              displayImgUrl,
              width: 70, height: 70, fit: BoxFit.cover,
              errorBuilder: (_, __, ___) => Container(
                width: 70, height: 70,
                color: Colors.grey.shade300,
                child: const Icon(Icons.fastfood),
              ),
            ),
          ),
          const SizedBox(width: 14),

          // info
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(displayName,
                    style: const TextStyle(
                        fontSize: 16,
                        fontWeight: FontWeight.bold)),
                const SizedBox(height: 4),
                Text(
                  '${it.quantity.toStringAsFixed(it.quantity == it.quantity.roundToDouble() ? 0 : 2)} ${UnitDict.text(it.unit, isThai)}',
                  style: TextStyle(
                      fontSize: 13,
                      color: _dark.withOpacity(0.7)),
                ),
                const SizedBox(height: 2),
                // แสดง price per unit + total ชัดเจน
                Text(
                  isThai 
                      ? '฿$priceStr/${UnitDict.text(it.unit, isThai)}  ·  รวม ฿${totalPrice == totalPrice.roundToDouble() ? totalPrice.toStringAsFixed(0) : totalPrice.toStringAsFixed(2)}'
                      : '฿$priceStr/${UnitDict.text(it.unit, isThai)}  ·  Total ฿${totalPrice == totalPrice.roundToDouble() ? totalPrice.toStringAsFixed(0) : totalPrice.toStringAsFixed(2)}',
                  style: TextStyle(
                      fontSize: 12,
                      color: _dark.withOpacity(0.55)),
                ),
                const SizedBox(height: 4),
                Row(children: [
                  Icon(Icons.schedule,
                      size: 12, color: expColor),
                  const SizedBox(width: 4),
                  Text(expText,
                      style: TextStyle(
                          fontSize: 12,
                          color: expColor,
                          fontWeight: daysLeft <= 1
                              ? FontWeight.w700
                              : FontWeight.normal)),
                ]),
              ],
            ),
          ),

          // ── action column ──────────────────────────
          Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              IconButton(
                icon: const Icon(Icons.edit, size: 20),
                onPressed: () => _openEdit(it),
                padding: EdgeInsets.zero,
                constraints: const BoxConstraints(),
              ),
              const SizedBox(height: 8),

              // ── "ใช้แล้ว" button — solid green เด่นชัด ──
              GestureDetector(
                onTap: () => _showUseSheet(it),
                child: Container(
                  padding: const EdgeInsets.symmetric(
                      horizontal: 12, vertical: 7),
                  decoration: BoxDecoration(
                    color: _green,
                    borderRadius: BorderRadius.circular(10),
                    boxShadow: [
                      BoxShadow(
                        color: _green.withOpacity(0.35),
                        blurRadius: 6,
                        offset: const Offset(0, 3),
                      ),
                    ],
                  ),
                  child: Text(
                    isThai ? 'ใช้แล้ว' : 'Used',
                    style: const TextStyle(
                      fontSize: 12,
                      fontWeight: FontWeight.w900,
                      color: Colors.white,
                    ),
                  ),
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final isThai = widget.appLocale.isThai;
    final items  = widget.items;

    final Map<String, List<InventoryItem>> groupedMap = {};
    for (var it in items) {
      final key = it.nameEn.trim().isNotEmpty ? it.nameEn.trim() : it.nameTh.trim();
      groupedMap.putIfAbsent(key, () => []).add(it);
    }
    final groups = groupedMap.entries.toList();
    groups.sort((a, b) {
       final earliestA = a.value.reduce((x, y) => x.expireDate.compareTo(y.expireDate) < 0 ? x : y);
       final earliestB = b.value.reduce((x, y) => x.expireDate.compareTo(y.expireDate) < 0 ? x : y);
       return earliestA.expireDate.compareTo(earliestB.expireDate);
    });

    return Scaffold(
      backgroundColor: _bg,
      appBar: RefridgeAppBar(
        title: isThai ? 'คลังสินค้า' : 'Inventory',
        appLocale: widget.appLocale,
        items: items,
      ),
      floatingActionButton: FloatingActionButton(
        onPressed: _handleAdd,
        backgroundColor: Colors.white,
        elevation: 2,
        child: const Icon(Icons.add, color: Colors.black),
      ),
      body: _isLoading
          ? const Center(child: CircularProgressIndicator())
          : items.isEmpty
              ? Center(
                  child: Text(isThai ? 'ยังไม่มีสินค้า' : 'No products yet.'))
              : RefreshIndicator(
                  onRefresh: _refreshFromBackend,
                  child: ListView.builder(
                    padding: const EdgeInsets.all(12),
                    itemCount: groups.length,
                    itemBuilder: (context, i) {
                      final group = groups[i];
                      final groupKey = group.key;
                      final groupItems = group.value;
                      groupItems.sort((a, b) => a.expireDate.compareTo(b.expireDate));

                      final autoItems = groupItems.where((it) => it.source == 'auto' && it.centerX != null && it.centerX! >= 0).toList();
                      autoItems.sort((a, b) => a.centerX!.compareTo(b.centerX!));
                      
                      final Map<String, String> locOverrides = {};
                      if (autoItems.length == 1) {
                        locOverrides[autoItems[0].id] = _locationCache[autoItems[0].id] ?? autoItems[0].getLocationString(isThai);
                      } else if (autoItems.length == 2) {
                        locOverrides[autoItems[0].id] = isThai ? 'ซ้าย' : 'Left';
                        locOverrides[autoItems[1].id] = isThai ? 'ขวา' : 'Right';
                      } else if (autoItems.length == 3) {
                        locOverrides[autoItems[0].id] = isThai ? 'ซ้าย' : 'Left';
                        locOverrides[autoItems[1].id] = isThai ? 'กลาง' : 'Middle';
                        locOverrides[autoItems[2].id] = isThai ? 'ขวา' : 'Right';
                      } else if (autoItems.length > 3) {
                        for (int k = 0; k < autoItems.length; k++) {
                          locOverrides[autoItems[k].id] = isThai ? 'ชิ้นที่ ${k+1} จากซ้าย' : '${k+1}th from left';
                        }
                      }

                      if (autoItems.length > 1) {
                        for (final it in autoItems) {
                          _locationCache[it.id] = locOverrides[it.id]!;
                        }
                      }
                      
                      final earliestItem = groupItems.first;
                      final totalQty = groupItems.fold<double>(0, (sum, item) => sum + item.quantity);
                      final totalVal = groupItems.fold<double>(0, (sum, item) => sum + (item.price * item.quantity));
                      final isExpanded = _expandedGroups[groupKey] ?? false;
                      
                      return Column(
                        children: [
                          _buildSummaryCard(groupKey, earliestItem, totalQty, totalVal, isExpanded, isThai),
                          if (isExpanded)
                            ...groupItems.map((it) => _buildItemCard(it, isThai, isChild: true, locationOverride: locOverrides[it.id] ?? '')).toList(),
                        ]
                      );
                    },
                  ),
                ),
    );
  }
}