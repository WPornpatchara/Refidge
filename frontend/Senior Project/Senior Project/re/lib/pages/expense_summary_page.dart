import 'dart:math';
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:re/models/inventory_item.dart';
import 'package:re/managers/app_locale.dart';
import '../widgets/refridge_app_bar.dart';
import '../services/ingredient_image_service.dart';

enum MonthViewMode { rolling12, year12 }

class ExpenseSummaryPage extends StatefulWidget {
  final AppLocale appLocale;
  final List<InventoryItem> items; // รับ ALL items (inFridge + used + wasted)

  const ExpenseSummaryPage({
    super.key,
    required this.appLocale,
    required this.items,
  });

  @override
  State<ExpenseSummaryPage> createState() => _ExpenseSummaryPageState();
}

class _ExpenseSummaryPageState extends State<ExpenseSummaryPage> {
  static const _bg    = Color(0xFFF6F2C6);
  static const _peach = Color(0xFFFFC8A8);
  static const _red   = Color(0xFFC0392B);
  static const _green = Color(0xFF3D7A56);
  static const _amber = Color(0xFFC68B3C);
  static const _dark  = Color(0xFF2C1A0E);

  MonthViewMode _mode = MonthViewMode.rolling12;
  late int _selectedYear;

  // ── DEBUG ─────────────────────────────────────────────────
  final List<InventoryItem> _debugItems = [];
  static const _debugPresets = [
    (nameEn: 'Strawberry', nameTh: 'สตรอเบอร์รี่', price: 45.0, qty: 1.0, daysAgo: 3),
    (nameEn: 'Spinach',    nameTh: 'ผักโขม',        price: 30.0, qty: 1.0, daysAgo: 1),
    (nameEn: 'Yoghurt',    nameTh: 'โยเกิร์ต',      price: 65.0, qty: 1.0, daysAgo: 5),
    (nameEn: 'Tofu',       nameTh: 'เต้าหู้',       price: 25.0, qty: 1.0, daysAgo: 2),
    (nameEn: 'Milk',       nameTh: 'นม',             price: 55.0, qty: 1.0, daysAgo: 4),
  ];

  List<InventoryItem> get _allItems => [...widget.items, ..._debugItems];

  @override
  void initState() {
    super.initState();
    _selectedYear = DateTime.now().year;
  }

  // ══════════════════════════════════════════════════════════
  // LOGIC
  // ══════════════════════════════════════════════════════════
  //
  // ทุก item เก็บ:
  //   initialQuantity  = จำนวนที่ซื้อมา (Bought) — ไม่เปลี่ยน
  //   usedQuantity     = จำนวนที่ใช้ไปแล้ว
  //   wastedQuantity   = initialQty - quantity - usedQty  (คำนวณ)
  //   quantity         = จำนวนที่ยังอยู่ในตู้ (In fridge)
  //
  //   price = ราคาต่อหน่วย → cost = price × qty
  //
  // Bought    = Σ price × initialQuantity
  // Used      = Σ price × usedQuantity
  // Wasted    = Σ price × wastedQuantity
  // In fridge = Σ price × quantity (ยังอยู่)
  //
  // Most Used = ชื่อที่มี usedQuantity รวมมากที่สุด
  //             ถ้ายังไม่มี used เลย → ไม่แสดง card

  String _displayName(InventoryItem it, bool isThai) {
    try { return it.displayName(isThai); } catch (_) {
      final raw = (isThai ? it.nameTh : it.nameEn).trim();
      if (raw.isNotEmpty) return raw;
      return (it.nameEn.isNotEmpty ? it.nameEn : it.nameTh).trim().isNotEmpty
          ? (it.nameEn.isNotEmpty ? it.nameEn : it.nameTh).trim()
          : (isThai ? 'Unknown' : 'Unknown');
    }
  }

  // ── group by purchase month ───────────────────────────────
  DateTime _monthKey(DateTime d) => DateTime(d.year, d.month, 1);

  // หา "effective purchase date" ของ item
  // Priority:
  //   1. purchaseDate (ถ้า user ตั้งไว้)
  //   2. removedDate - expireDate window (ถ้า used/wasted และ expireDate ไกลเกินไป)
  //   3. DateTime.now() ถ้ายังอยู่ใน fridge และไม่มี purchaseDate
  //
  // เหตุผล: ถ้าใช้ expireDate ตรงๆ ของที่ expire ไกล (เช่น Sep 2026)
  // จะถูก group เข้าเดือนนั้น ทั้งที่ซื้อวันนี้
  DateTime _effectivePurchaseMonth(InventoryItem it) {
    // มี purchaseDate → ใช้เลย
    if (it.purchaseDate != null) return it.purchaseDate!;

    // ถ้าไม่มี purchaseDate ให้ใช้ effectivePurchaseDate (คำนวณย้อนหลังจาก expireDate)
    // เพื่อให้เดือนที่บันทึกมีความคงที่ ไม่เลื่อนไปตาม DateTime.now() เวลาเปิดแอป
    return it.effectivePurchaseDate;
  }

  Map<DateTime, List<InventoryItem>> _groupByMonth() {
    final map = <DateTime, List<InventoryItem>>{};
    for (final it in _allItems) {
      final k = _monthKey(_effectivePurchaseMonth(it));
      (map[k] ??= []).add(it);
    }
    return map;
  }

  // ── override stale backend data ───────────────────────────
  ({
    double boughtQty, double usedQty, double wastedQty, double inFridgeQty,
    double boughtCost, double usedCost, double wastedCost, double inFridgeCost
  }) _getCorrectedStats(InventoryItem it) {
    double bQty = it.initialQuantity;
    double uQty = it.usedQuantity;
    double wQty = it.wastedQuantity;
    double fQty = it.quantity;

    // แก้ปัญหา Backend ไม่บันทึก initialQuantity ตอนเปลี่ยนจำนวน:
    // บังคับคำนวณ Initial (Bought) ใหม่จาก จำนวนปัจจุบัน(Quantity) + จำนวนที่ใช้(Used) 
    // เพื่อให้สรุปค่าใช้จ่ายตรงกับจำนวนใหม่ที่ผู้ใช้แก้ไขเสมอ
    if (it.status == ItemStatus.inFridge) {
      wQty = 0.0;
      bQty = fQty + uQty;
    } else if (it.status == ItemStatus.used) {
      wQty = 0.0;
      bQty = fQty + uQty; 
    } else if (it.status == ItemStatus.wasted) {
      wQty = bQty - uQty;
      if (wQty < 0) wQty = 0;
    }

    return (
      boughtQty: bQty,
      usedQty: uQty,
      wastedQty: wQty,
      inFridgeQty: fQty,
      boughtCost: bQty * it.price,
      usedCost: uQty * it.price,
      wastedCost: wQty * it.price,
      inFridgeCost: fQty * it.price,
    );
  }

  // ── per-month stats ───────────────────────────────────────
  ({
    double boughtCost,
    double usedCost,
    double wastedCost,
    double inFridgeCost,
    double boughtQty,
    double usedQty,
    double wastedQty,
    double inFridgeQty,
    String? topWastedName,
  }) _calcStats(List<InventoryItem> list, bool isThai) {
    double boughtCost = 0, usedCost = 0, wastedCost = 0, inFridgeCost = 0;
    double boughtQty  = 0, usedQty  = 0, wastedQty  = 0, inFridgeQty  = 0;
    final wastedMap = <String, double>{};

    for (final it in list) {
      final st = _getCorrectedStats(it);

      boughtCost   += st.boughtCost;
      usedCost     += st.usedCost;
      wastedCost   += st.wastedCost;
      inFridgeCost += st.inFridgeCost;

      boughtQty    += st.boughtQty;
      usedQty      += st.usedQty;
      wastedQty    += st.wastedQty;
      inFridgeQty  += st.inFridgeQty;

      if (st.wastedQty > 0) {
        final key = (it.nameEn.isNotEmpty ? it.nameEn : it.nameTh).trim().toLowerCase();
        wastedMap[key] = (wastedMap[key] ?? 0) + st.wastedCost;
      }
    }

    String? topWastedName;
    if (wastedMap.isNotEmpty) {
      final topKey = (wastedMap.entries.toList()
            ..sort((a, b) => b.value.compareTo(a.value)))
          .first
          .key;
      final found = list.firstWhere(
        (e) => (e.nameEn.isNotEmpty ? e.nameEn : e.nameTh).trim().toLowerCase() == topKey,
        orElse: () => list.first,
      );
      topWastedName = _displayName(found, isThai);
    }

    return (
      boughtCost:   boughtCost,
      usedCost:     usedCost,
      wastedCost:   wastedCost,
      inFridgeCost: inFridgeCost,
      boughtQty:    boughtQty,
      usedQty:      usedQty,
      wastedQty:    wastedQty,
      inFridgeQty:  inFridgeQty,
      topWastedName: topWastedName,
    );
  }

  // ── item key helpers ─────────────────────────────────────
  String _itemName(InventoryItem it) =>
      (it.nameEn.isNotEmpty ? it.nameEn : it.nameTh).trim().toLowerCase();

  // key = "name|unit" เพื่อไม่รวม piece กับ kg ของชื่อเดียวกัน
  String _itemKey(InventoryItem it) => '${_itemName(it)}|${it.unit.trim().toLowerCase()}';

  // ── most used / most wasted ──────────────────────────────
  //
  // วัดด้วย Normalized Quantity แทน Cost
  // เพื่อให้เปรียบเทียบ 1 kg กับ 20 g ได้สมเหตุสมผลตามความรู้สึกคน (1000 > 20)
  //
  // หลักการ dominant (ต่อ 1 unit):
  //   ถ้า usedQty > wastedQty → จัดเป็น Most Used
  //   ถ้า wastedQty >= usedQty → จัดเป็น Most Wasted

  // typedef ชัดเจนเพื่อใช้ซ้ำได้โดยไม่ต้องเขียน record type ยาวๆ
  static const _zeroStats = (
    usedCost:   0.0,
    usedQty:    0.0,
    wastedCost: 0.0,
    wastedQty:  0.0,
  );

  Map<String, ({double usedCost, double usedQty, double wastedCost, double wastedQty, InventoryItem item})>
      _perKeyStats() {
    final map = <String, ({double usedCost, double usedQty, double wastedCost, double wastedQty, InventoryItem item})>{};
    for (final it in _allItems) {
      final key = _itemKey(it);
      if (key.isEmpty) continue;
      final prev = map[key];
      
      final st = _getCorrectedStats(it);
      
      map[key] = (
        usedCost:   (prev?.usedCost   ?? 0.0) + st.usedCost,
        usedQty:    (prev?.usedQty    ?? 0.0) + st.usedQty,
        wastedCost: (prev?.wastedCost ?? 0.0) + st.wastedCost,
        wastedQty:  (prev?.wastedQty  ?? 0.0) + st.wastedQty,
        item:       prev?.item ?? it,
      );
    }
    return map;
  }

  double _normQty(String unit, double qty) {
    final u = unit.trim().toLowerCase();
    if (u == 'kg' || u == 'กก.') return qty * 1000;
    if (u == 'liter' || u == 'ลิตร' || u == 'l') return qty * 1000;
    return qty;
  }

  ({InventoryItem item, double totalUsed, String unit})? _mostUsedEntry() {
    final stats = _perKeyStats();
    // eligible: usedQty > 0 และ used > wasted (dominant used)
    final eligible = stats.entries
        .where((e) => e.value.usedQty > 0 && e.value.usedQty > e.value.wastedQty)
        .toList()
      ..sort((a, b) {
        final normA = _normQty(a.value.item.unit, a.value.usedQty);
        final normB = _normQty(b.value.item.unit, b.value.usedQty);
        return normB.compareTo(normA);
      });
    if (eligible.isEmpty) return null;
    final top = eligible.first;
    return (
      item:      top.value.item,
      totalUsed: top.value.usedQty,
      unit:      top.value.item.unit,
    );
  }

  ({InventoryItem item, double totalWasted, String unit})? _mostWastedEntry() {
    final stats = _perKeyStats();
    // eligible: wastedQty > 0 และ wasted >= used (dominant wasted)
    final eligible = stats.entries
        .where((e) => e.value.wastedQty > 0 && e.value.wastedQty >= e.value.usedQty)
        .toList()
      ..sort((a, b) {
        final normA = _normQty(a.value.item.unit, a.value.wastedQty);
        final normB = _normQty(b.value.item.unit, b.value.wastedQty);
        return normB.compareTo(normA);
      });
    if (eligible.isEmpty) return null;
    final top = eligible.first;
    return (
      item:         top.value.item,
      totalWasted:  top.value.wastedQty,
      unit:         top.value.item.unit,
    );
  }

  // ── text helpers ──────────────────────────────────────────
  String _money(double v) {
    final n = v.isNaN ? 0.0 : v.clamp(0.0, double.infinity);
    return '${n.toStringAsFixed(0)} THB';
  }

  String _fmtQty(double q) =>
      q == q.roundToDouble() ? q.toStringAsFixed(0) : q.toStringAsFixed(1);

  String _couldBuy(double wasted, bool isThai) {
    if (wasted < 10)    return isThai ? "แค่ค่าขนม 🍬" : "That's a snack 🍬";
    if (wasted < 50)    return isThai ? "ชานมไข่มุก 1 แก้ว 🧋" : 'A bubble tea 🧋';
    if (wasted < 150)   return isThai ? "ข้าวมื้อนึงเลยนะ 🍛" : 'Almost a meal 🍛';
    if (wasted < 500)   return isThai ? "บุฟเฟต์มื้อย่อมๆ 🍽️" : 'Small buffet 🍽️';
    if (wasted < 2000)  return isThai ? "หูฟังใหม่ได้เลย 🎧" : 'Earbuds money 🎧';
    if (wasted < 10000) return isThai ? "สมาร์ทวอทช์สักเรือน ⌚" : 'Smartwatch vibes ⌚';
    if (wasted < 25000) return isThai ? "ดาวน์โทรศัพท์ได้เลย 📱" : 'Entering iPhone vibes 📱';
    return isThai ? "ซื้อไอโฟนได้เลยนะเนี่ย 📱💸" : "That's iPhone money 📱💸";
  }

  String _bully({required double wasted, required String? topName, required bool isThai}) {
    if (wasted <= 0) return isThai ? 'เยี่ยมมาก — เดือนนี้ไม่มีของเสียเลย 👏' : 'Nice — no waste this month 👏';
    final name = (topName?.trim().isNotEmpty ?? false) ? topName!.trim() : (isThai ? 'บางอย่าง' : 'something');
    final buy  = _couldBuy(wasted, isThai);
    if (wasted < 50)   return isThai ? 'มี "$name" เสียนิดหน่อย 😶 · $buy' : 'A little "$name" slipped 😶 · $buy';
    if (wasted < 200)  return isThai ? '"$name" ที่ไม่ได้กิน ทำเงินปลิวไป ${_money(wasted)} 💸 · $buy' : '"$name" you didn\'t eat burned ${_money(wasted)} 💸 · $buy';
    if (wasted < 1000) return isThai ? 'เดือนนี้ "$name" ทำเจ็บใจอยู่ — เสียไป ${_money(wasted)} 💸 · $buy' : '"$name" did damage this month — ${_money(wasted)} 💸 · $buy';
    return isThai ? 'อูย… ปล่อย "$name" หมดอายุ ทิ้งเงินไปตั้ง: ${_money(wasted)} 💸 · $buy' : 'Oof… "$name" you let expire: ${_money(wasted)} 💸 · $buy';
  }

  String _monthLabel(DateTime d) {
    const m = ['Jan','Feb','Mar','Apr','May','Jun','Jul','Aug','Sep','Oct','Nov','Dec'];
    return '${m[d.month - 1]} ${d.year}';
  }

  String _monthShort(DateTime d) {
    const m = ['Jan','Feb','Mar','Apr','May','Jun','Jul','Aug','Sep','Oct','Nov','Dec'];
    return m[d.month - 1];
  }

  List<DateTime> _rolling12(DateTime now) {
    final cur = DateTime(now.year, now.month, 1);
    return List.generate(12, (i) => DateTime(cur.year, cur.month - (11 - i), 1));
  }

  List<DateTime> _year12(int year) =>
      List.generate(12, (i) => DateTime(year, i + 1, 1));

  Set<int> _availableYears() {
    final years = <int>{DateTime.now().year};
    for (final it in _allItems) {
      years.add(_effectivePurchaseMonth(it).year);
    }
    return (years.toList()..sort()).toSet();
  }

  // ══════════════════════════════════════════════════════════
  // BUILD
  // ══════════════════════════════════════════════════════════

  @override
  Widget build(BuildContext context) {
    final isThai  = widget.appLocale.isThai;
    final monthly = _groupByMonth();
    final now     = DateTime.now();

    final thisKey    = DateTime(now.year, now.month, 1);
    final thisItems  = monthly[thisKey] ?? const <InventoryItem>[];
    final thisStats  = _calcStats(thisItems, isThai);

    // All-time totals
    final allStats   = _calcStats(_allItems, isThai);

    // 12-month rows
    final keys12     = _mode == MonthViewMode.rolling12
        ? _rolling12(now) : _year12(_selectedYear);

    final rows = keys12.map((k) {
      final list  = monthly[k] ?? const <InventoryItem>[];
      final stats = _calcStats(list, isThai);
      return _MonthRow(
        key:          k,
        boughtCost:   stats.boughtCost,
        wastedCost:   stats.wastedCost,
        boughtQty:    stats.boughtQty,
        wastedQty:    stats.wastedQty,
        topWastedName: stats.topWastedName,
      );
    }).toList();

    final spent12  = rows.fold(0.0, (p, r) => p + r.boughtCost);
    final wasted12 = rows.fold(0.0, (p, r) => p + r.wastedCost);
    final maxCost  = max(1.0, rows.map((r) => r.boughtCost).fold(0.0, max));
    final maxWaste = max(1.0, rows.map((r) => r.wastedCost).fold(0.0, max));
    final years    = _availableYears().toList()..sort();

    final usedEntry   = _mostUsedEntry();
    final wastedEntry = _mostWastedEntry();

    // waste % based on cost (บาท) — แม่นกว่า qty เพราะข้าม unit ได้
    final wasteQtyPct = thisStats.boughtCost == 0
        ? 0 : (thisStats.wastedCost / thisStats.boughtCost * 100).round();

    return Scaffold(
      backgroundColor: _bg,
      appBar: RefridgeAppBar(
        title: isThai ? 'สรุปค่าใช้จ่าย' : 'Expense Summary',
        appLocale: widget.appLocale,
        items: const [],
      ),
      body: ListView(
        padding: const EdgeInsets.fromLTRB(16, 16, 16, 32),
        children: [

          // ── DEBUG ──────────────────────────────────────────
          if (kDebugMode) _buildDebugPanel(isThai),

          // ── 1. THIS MONTH HERO ─────────────────────────────
          _card(child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(children: [
                Text(isThai ? 'เดือนนี้' : 'This Month',
                    style: const TextStyle(fontSize: 18, fontWeight: FontWeight.w900)),
                const Spacer(),
                Text(_monthLabel(thisKey),
                    style: TextStyle(fontSize: 12, color: _dark.withOpacity(0.5))),
              ]),
              const SizedBox(height: 14),

              Row(crossAxisAlignment: CrossAxisAlignment.center, children: [
                _WasteDonut(
                  wastedQty:  thisStats.wastedCost,
                  totalQty:   thisStats.boughtCost,
                  isThai:     isThai,
                ),
                const SizedBox(width: 18),
                Expanded(child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                  _statRow(isThai ? 'ใช้จ่ายไป' : 'Spent',
                      _money(thisStats.boughtCost), _dark),
                  const SizedBox(height: 8),
                  _statRow(isThai ? 'ใช้แล้ว' : 'Used value',
                      _money(thisStats.usedCost), _green),
                  const SizedBox(height: 8),
                  _statRow(isThai ? 'ของเสีย' : 'Wasted',
                      _money(thisStats.wastedCost), _red),
                  const SizedBox(height: 12),
                  Container(
                    padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 5),
                    decoration: BoxDecoration(
                      color: wasteQtyPct == 0
                          ? _green.withOpacity(0.13)
                          : _red.withOpacity(0.10),
                      borderRadius: BorderRadius.circular(999),
                    ),
                    child: Text(
                      wasteQtyPct == 0 
                          ? (isThai ? '🎉 ไม่มีของเสียเลย!' : '🎉 Zero waste!') 
                          : (isThai ? 'เสีย $wasteQtyPct%' : '$wasteQtyPct% wasted'),
                      style: TextStyle(fontSize: 12, fontWeight: FontWeight.w800,
                          color: wasteQtyPct == 0 ? _green : _red),
                    ),
                  ),
                ])),
              ]),

              if (thisStats.wastedCost > 0) ...[
                const SizedBox(height: 12),
                _bullyBox(_bully(
                    wasted: thisStats.wastedCost,
                    topName: thisStats.topWastedName,
                    isThai: isThai)),
              ],
            ],
          )),

          const SizedBox(height: 16),

          // ── 2. MOST USED + MOST WASTED ──────────────────
          IntrinsicHeight(
            child: Row(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                Expanded(child: _ingredientCard(
                  label: isThai ? 'ใช้บ่อยสุด' : 'Most used',
                  entry: usedEntry == null ? null
                      : (name: _displayName(usedEntry.item, isThai),
                         imgName: usedEntry.item.nameEn.trim().isNotEmpty
                             ? usedEntry.item.nameEn : usedEntry.item.nameTh,
                         detail: '${_fmtQty(usedEntry.totalUsed)} ${usedEntry.unit} used'),
                  accentColor: _green,
                  emptyText: isThai ? 'ยังไม่มีวัตถุดิบ\nที่ใช้ไป' : 'No ingredients\nused yet',
                  quote: isThai
                      ? 'ของที่ใช้บ่อยสุด\nคือของที่คุ้มค่าที่สุด'
                      : 'The ingredient\nyou use most\ndefines your cooking',
                )),
                const SizedBox(width: 12),
                Expanded(child: _ingredientCard(
                  label: isThai ? 'เสียบ่อยสุด' : 'Most wasted',
                  entry: wastedEntry == null ? null
                      : (name: _displayName(wastedEntry.item, isThai),
                         imgName: wastedEntry.item.nameEn.trim().isNotEmpty
                             ? wastedEntry.item.nameEn : wastedEntry.item.nameTh,
                         detail: '${_fmtQty(wastedEntry.totalWasted)} ${wastedEntry.unit} wasted'),
                  accentColor: _red,
                  emptyText: isThai ? 'ยังไม่มีของเสีย\nเลย!' : 'No waste\nso far!',
                  quote: isThai
                      ? 'ของที่เสียบ่อยสุด\nคือสัญญาณที่ควร\nซื้อน้อยลง'
                      : 'The ingredient\nyou waste most\nis a hint to buy less',
                )),
              ],
            ),
          ),

          const SizedBox(height: 16),

          // ── 3. 12-MONTH HISTORY ─────────────────────────────
          _card(child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
            Row(children: [
              Text(isThai ? '12 เดือน' : '12-Month History',
                  style: const TextStyle(fontSize: 16, fontWeight: FontWeight.w900)),
              const Spacer(),
              _modeSwitch(isThai),
            ]),
            const SizedBox(height: 8),

            if (_mode == MonthViewMode.year12)
              Padding(
                padding: const EdgeInsets.only(bottom: 8),
                child: Row(children: [
                  Text(isThai ? 'ปี: ' : 'Year: ',
                      style: const TextStyle(fontWeight: FontWeight.w800)),
                  const SizedBox(width: 8),
                  DropdownButton<int>(
                    value: _selectedYear, isDense: true,
                    items: years.map((y) =>
                        DropdownMenuItem(value: y, child: Text('$y'))).toList(),
                    onChanged: (v) {
                      if (v != null) setState(() => _selectedYear = v);
                    },
                  ),
                ]),
              ),

            Row(children: [
              Expanded(child: _moneyCol(isThai ? 'รวม 12 เดือน' : 'Total 12 months',
                  _money(spent12), _dark)),
              Expanded(child: _moneyCol(isThai ? 'ของเสีย 12 เดือน' : 'Wasted 12 months',
                  _money(wasted12), _red)),
            ]),
            const SizedBox(height: 16),

            ...rows.map((r) => Padding(
              padding: const EdgeInsets.only(bottom: 10),
              child: _historyBarRow(
                month:       r.key,
                boughtCost:  r.boughtCost,
                wastedCost:  r.wastedCost,
                wastedQty:   r.wastedQty,
                spentRatio:  (r.boughtCost / maxCost ).clamp(0.0, 1.0),
                wastedRatio: (r.wastedCost / maxWaste).clamp(0.0, 1.0),
                isThai:      isThai,
              ),
            )),
          ])),

          const SizedBox(height: 16),

          // ── 4. ALL-TIME WASTED ──────────────────────────────
          _card(child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
            Text(isThai ? 'ของเสียทั้งหมด' : 'Total Wasted (All Time)',
                style: const TextStyle(fontSize: 16, fontWeight: FontWeight.w900)),
            const SizedBox(height: 10),
            Row(crossAxisAlignment: CrossAxisAlignment.end, children: [
              Text(allStats.wastedCost.toStringAsFixed(0),
                  style: TextStyle(
                      fontSize: 34, fontWeight: FontWeight.w900, color: _red)),
              const SizedBox(width: 6),
              Padding(
                padding: const EdgeInsets.only(bottom: 5),
                child: Text('THB',
                    style: TextStyle(fontSize: 14, color: _dark.withOpacity(0.5))),
              ),
              const Spacer(),
              Column(crossAxisAlignment: CrossAxisAlignment.end, children: [
                Text(isThai ? 'ใช้จ่ายรวม' : 'Total spent',
                    style: TextStyle(fontSize: 10, color: _dark.withOpacity(0.5))),
                Text(_money(allStats.boughtCost),
                    style: const TextStyle(
                        fontSize: 14, fontWeight: FontWeight.w800)),
              ]),
            ]),
            const SizedBox(height: 10),
            _bullyBox(_bully(
                wasted: allStats.wastedCost,
                topName: allStats.topWastedName,
                isThai: isThai)),
          ])),

          const SizedBox(height: 16),

          // ── 5. MONTHLY DETAIL CARDS ─────────────────────────
          ...rows.reversed.map((r) => Padding(
            padding: const EdgeInsets.only(bottom: 12),
            child: _card(child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
              Row(children: [
                Text(_monthLabel(r.key),
                    style: const TextStyle(
                        fontSize: 15, fontWeight: FontWeight.w900)),
                const Spacer(),
                if (r.wastedQty > 0)
                  _pill(isThai ? 'เสีย ${_fmtQty(r.wastedQty)}' : '${_fmtQty(r.wastedQty)} wasted', _red)
                else
                  _pill(isThai ? '✓ ไม่มีของเสีย' : '✓ No Waste', _green),
              ]),
              const SizedBox(height: 12),
              _stackedBar(
                  spent: r.boughtCost,
                  wasted: r.wastedCost,
                  maxSpent: maxCost),
              const SizedBox(height: 10),
              Row(children: [
                Expanded(child: _kv(isThai ? 'ใช้จ่าย' : 'Spent', _money(r.boughtCost), _dark)),
                Expanded(child: _kv(isThai ? 'ของเสีย' : 'Wasted', _money(r.wastedCost), _red)),
              ]),
              if (r.wastedCost > 0) ...[
                const SizedBox(height: 8),
                Text(
                  _bully(wasted: r.wastedCost, topName: r.topWastedName, isThai: isThai),
                  style: TextStyle(fontSize: 11,
                      color: _dark.withOpacity(0.6), height: 1.5),
                ),
              ],
            ])),
          )),
        ],
      ),
    );
  }

  // ══════════════════════════════════════════════════════════
  // DEBUG PANEL
  // ══════════════════════════════════════════════════════════

  Widget _buildDebugPanel(bool isThai) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 12),
      child: Container(
        padding: const EdgeInsets.all(14),
        decoration: BoxDecoration(
          color: Colors.red.shade50,
          border: Border.all(color: Colors.red.shade200, width: 1.5),
          borderRadius: BorderRadius.circular(18),
        ),
        child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
          Row(children: [
            const Icon(Icons.bug_report, size: 16, color: Colors.red),
            const SizedBox(width: 6),
            const Text('DEBUG — Waste Tester',
                style: TextStyle(
                    fontSize: 13,
                    fontWeight: FontWeight.w900,
                    color: Colors.red)),
            const Spacer(),
            if (_debugItems.isNotEmpty)
              GestureDetector(
                onTap: () => setState(() => _debugItems.clear()),
                child: Container(
                  padding: const EdgeInsets.symmetric(
                      horizontal: 10, vertical: 4),
                  decoration: BoxDecoration(
                    color: Colors.red.shade100,
                    borderRadius: BorderRadius.circular(999)),
                  child: const Text('Clear all',
                      style: TextStyle(
                          fontSize: 11,
                          fontWeight: FontWeight.w700,
                          color: Colors.red)),
                ),
              ),
          ]),
          const SizedBox(height: 4),
          Text(
            'Added ${_debugItems.length} items  •  Hidden in release',
            style: TextStyle(fontSize: 10, color: Colors.red.shade400),
          ),
          const SizedBox(height: 10),
          Wrap(
            spacing: 8, runSpacing: 8,
            children: _debugPresets.map((p) {
              // debug items: ½ used, ½ wasted เพื่อทดสอบหลาย path
              return GestureDetector(
                onTap: () => setState(() {
                  final now      = DateTime.now();
                  // debug preset = wasted item ล้วนๆ
                  // usedQuantity=0 เพื่อให้ไปอยู่ฝั่ง most wasted เท่านั้น
                  _debugItems.add(InventoryItem(
                    id:              'debug_${DateTime.now().millisecondsSinceEpoch}',
                    nameEn:          p.nameEn,
                    nameTh:          p.nameTh,
                    expireDate:      now.subtract(Duration(days: p.daysAgo)),
                    purchaseDate:    now.subtract(Duration(days: p.daysAgo + 5)),
                    price:           p.price,
                    quantity:        0,        // ของหมดแล้ว
                    initialQuantity: p.qty,    // ซื้อมา
                    usedQuantity:    0,        // ไม่ได้ใช้เลย → wasted ทั้งหมด
                    unit:            'piece',
                    status:          ItemStatus.wasted,
                    removedDate:     now.subtract(Duration(days: p.daysAgo)),
                    freshnessLabel:  'Expired',
                  ));
                }),
                child: Container(
                  padding: const EdgeInsets.symmetric(
                      horizontal: 12, vertical: 7),
                  decoration: BoxDecoration(
                    color: Colors.white,
                    border: Border.all(color: Colors.red.shade200),
                    borderRadius: BorderRadius.circular(999),
                  ),
                  child: Text(
                    '+ ${p.nameEn} (${p.daysAgo}d ago)',
                    style: TextStyle(
                        fontSize: 11,
                        fontWeight: FontWeight.w700,
                        color: Colors.red.shade700),
                  ),
                ),
              );
            }).toList(),
          ),
        ]),
      ),
    );
  }

  // ══════════════════════════════════════════════════════════
  // WIDGET HELPERS
  // ══════════════════════════════════════════════════════════

  Widget _card({required Widget child}) => Container(
    padding: const EdgeInsets.all(18),
    decoration: BoxDecoration(
        color: _peach, borderRadius: BorderRadius.circular(28)),
    child: child,
  );

  // ── ingredient highlight card (used / wasted) ────────────
  Widget _ingredientCard({
    required String label,
    required ({String name, String imgName, String detail})? entry,
    required Color accentColor,
    required String emptyText,
    required String quote,
  }) {
    // ── content area สูงคงที่ทั้ง 2 state ─────────────────
    // ใช้ ConstrainedBox + Column ที่มี mainAxisSize.max
    // เพื่อให้ทั้ง 2 card stretch ให้ความสูงเท่ากันเสมอ
    Widget content;
    if (entry != null) {
      content = Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(crossAxisAlignment: CrossAxisAlignment.center, children: [
            ClipRRect(
              borderRadius: BorderRadius.circular(10),
              child: Image.network(
                IngredientImageService.fromName(entry.imgName),
                width: 48, height: 48, fit: BoxFit.cover,
                errorBuilder: (_, __, ___) => Container(
                  width: 48, height: 48,
                  decoration: BoxDecoration(
                    color: _dark.withOpacity(0.08),
                    borderRadius: BorderRadius.circular(10)),
                  child: Icon(Icons.fastfood, size: 22,
                      color: _dark.withOpacity(0.3)),
                ),
              ),
            ),
            const SizedBox(width: 10),
            Expanded(child: Column(
                crossAxisAlignment: CrossAxisAlignment.start, children: [
              Text('"${entry.name}"',
                  style: const TextStyle(
                      fontSize: 14, fontWeight: FontWeight.w900),
                  maxLines: 1, overflow: TextOverflow.ellipsis),
              const SizedBox(height: 3),
              Text(entry.detail,
                  style: TextStyle(fontSize: 11,
                      color: accentColor, fontWeight: FontWeight.w700)),
            ])),
          ]),
          const SizedBox(height: 10),
          Text(quote,
              style: TextStyle(fontSize: 10,
                  color: _dark.withOpacity(0.45),
                  height: 1.5,
                  fontStyle: FontStyle.italic)),
        ],
      );
    } else {
      // empty state — placeholder รูปขนาดเดียวกับมีข้อมูล เพื่อ layout เท่ากัน
      content = Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(crossAxisAlignment: CrossAxisAlignment.center, children: [
            Container(
              width: 48, height: 48,
              decoration: BoxDecoration(
                color: accentColor.withOpacity(0.08),
                borderRadius: BorderRadius.circular(10)),
              child: Icon(Icons.help_outline, size: 22,
                  color: accentColor.withOpacity(0.3)),
            ),
            const SizedBox(width: 10),
            Expanded(child: Column(
                crossAxisAlignment: CrossAxisAlignment.start, children: [
              Text(emptyText,
                  style: TextStyle(fontSize: 13, fontWeight: FontWeight.w800,
                      color: accentColor.withOpacity(0.45), height: 1.3),
                  maxLines: 2),
            ])),
          ]),
          const SizedBox(height: 10),
          Text(quote,
              style: TextStyle(fontSize: 10,
                  color: _dark.withOpacity(0.4),
                  height: 1.5,
                  fontStyle: FontStyle.italic)),
        ],
      );
    }

    return Container(
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
          color: _peach, borderRadius: BorderRadius.circular(22)),
      child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
        Text(label,
            style: TextStyle(fontSize: 10, fontWeight: FontWeight.w700,
                color: accentColor)),
        const SizedBox(height: 10),
        content,
      ]),
    );
  }

  Widget _statRow(String label, String value, Color color) => Row(children: [
    Container(
      width: 8, height: 8,
      margin: const EdgeInsets.only(right: 8),
      decoration: BoxDecoration(color: color, shape: BoxShape.circle),
    ),
    Text(label,
        style: TextStyle(fontSize: 11,
            color: _dark.withOpacity(0.5), fontWeight: FontWeight.w600)),
    const Spacer(),
    Text(value,
        style: TextStyle(
            fontSize: 15, fontWeight: FontWeight.w900, color: color)),
  ]);

  Widget _moneyCol(String label, String value, Color color) =>
      Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
    Text(label,
        style: TextStyle(fontSize: 10,
            color: _dark.withOpacity(0.45), fontWeight: FontWeight.w600)),
    const SizedBox(height: 2),
    Text(value,
        style: TextStyle(
            fontSize: 14, fontWeight: FontWeight.w900, color: color)),
  ]);

  Widget _kv(String k, String v, Color color) =>
      Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
    Text(k,
        style: TextStyle(fontSize: 10,
            color: _dark.withOpacity(0.45), fontWeight: FontWeight.w600)),
    const SizedBox(height: 2),
    Text(v,
        style: TextStyle(
            fontSize: 13, fontWeight: FontWeight.w900, color: color)),
  ]);

  Widget _pill(String text, Color color) => Container(
    padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
    decoration: BoxDecoration(
        color: color.withOpacity(0.10),
        borderRadius: BorderRadius.circular(999)),
    child: Text(text,
        style: TextStyle(
            fontSize: 11, fontWeight: FontWeight.w800, color: color)),
  );

  Widget _bullyBox(String text) => Container(
    padding: const EdgeInsets.all(12),
    decoration: BoxDecoration(
        color: _red.withOpacity(0.07),
        borderRadius: BorderRadius.circular(14)),
    child: Text(text,
        style: TextStyle(
            fontSize: 12, color: _dark.withOpacity(0.7), height: 1.5)),
  );

  Widget _stackedBar({
    required double spent,
    required double wasted,
    required double maxSpent,
  }) {
    final spentRatio  = (spent  / maxSpent).clamp(0.0, 1.0);
    final wastedRatio = spent > 0 ? (wasted / spent).clamp(0.0, 1.0) : 0.0;
    return ClipRRect(
      borderRadius: BorderRadius.circular(999),
      child: Container(
        height: 10, color: _dark.withOpacity(0.08),
        child: FractionallySizedBox(
          widthFactor: spentRatio,
          alignment: Alignment.centerLeft,
          child: Stack(children: [
            Container(color: _dark.withOpacity(0.18)),
            Align(
              alignment: Alignment.centerRight,
              child: FractionallySizedBox(
                widthFactor: wastedRatio,
                child: Container(color: _red.withOpacity(0.75)),
              ),
            ),
          ]),
        ),
      ),
    );
  }

  Widget _historyBarRow({
    required DateTime month,
    required double boughtCost,
    required double wastedCost,
    required double wastedQty,
    required double spentRatio,
    required double wastedRatio,
    required bool isThai,
  }) {
    return Row(children: [
      SizedBox(width: 46,
        child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
          Text(_monthShort(month),
              style: const TextStyle(fontWeight: FontWeight.w900, fontSize: 12)),
          Text('${month.year}',
              style: TextStyle(fontSize: 9, color: _dark.withOpacity(0.45))),
        ])),
      const SizedBox(width: 8),
      Expanded(child: Column(children: [
        ClipRRect(
          borderRadius: BorderRadius.circular(999),
          child: Container(height: 10, color: _dark.withOpacity(0.08),
            child: Align(alignment: Alignment.centerLeft,
              child: FractionallySizedBox(widthFactor: spentRatio,
                child: Container(color: _dark.withOpacity(0.25))))),
        ),
        const SizedBox(height: 5),
        ClipRRect(
          borderRadius: BorderRadius.circular(999),
          child: Container(height: 7, color: _dark.withOpacity(0.06),
            child: Align(alignment: Alignment.centerLeft,
              child: FractionallySizedBox(widthFactor: wastedRatio,
                child: Container(color: _red.withOpacity(0.65))))),
        ),
      ])),
      const SizedBox(width: 10),
      SizedBox(width: 80,
        child: Column(crossAxisAlignment: CrossAxisAlignment.end, children: [
          Text(_money(boughtCost),
              style: const TextStyle(
                  fontSize: 11, fontWeight: FontWeight.w900)),
          if (wastedQty > 0)
            Text(isThai ? 'เสีย ${_fmtQty(wastedQty)}' : '${_fmtQty(wastedQty)} wasted',
                style: TextStyle(
                    fontSize: 10, color: _red, fontWeight: FontWeight.w700))
          else
            Text(isThai ? '✓ คุ้มค่า' : '✓ Clean',
                style: TextStyle(
                    fontSize: 10,
                    color: _green,
                    fontWeight: FontWeight.w700)),
        ])),
    ]);
  }

  Widget _modeSwitch(bool isThai) => Container(
    padding: const EdgeInsets.all(3),
    decoration: BoxDecoration(
        color: _dark.withOpacity(0.08),
        borderRadius: BorderRadius.circular(999)),
    child: Row(mainAxisSize: MainAxisSize.min, children: [
      _segBtn(
        active: _mode == MonthViewMode.rolling12,
        text: isThai ? '12 ล่าสุด' : 'Rolling 12',
        onTap: () => setState(() => _mode = MonthViewMode.rolling12),
      ),
      _segBtn(
        active: _mode == MonthViewMode.year12,
        text: isThai ? 'ทั้งปี' : 'Year',
        onTap: () => setState(() => _mode = MonthViewMode.year12),
      ),
    ]),
  );

  Widget _segBtn({
    required bool active,
    required String text,
    required VoidCallback onTap,
  }) =>
      InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(999),
        child: AnimatedContainer(
          duration: const Duration(milliseconds: 160),
          padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 7),
          decoration: BoxDecoration(
            color: active ? _dark : Colors.transparent,
            borderRadius: BorderRadius.circular(999),
          ),
          child: Text(text,
              style: TextStyle(
                fontSize: 12,
                fontWeight: FontWeight.w900,
                color: active ? Colors.white : _dark.withOpacity(0.6),
              )),
        ),
      );
}

// ══════════════════════════════════════════════════════════════
// DONUT
// ══════════════════════════════════════════════════════════════

class _WasteDonut extends StatelessWidget {
  final double wastedQty;
  final double totalQty;
  final bool isThai;
  const _WasteDonut({required this.wastedQty, required this.totalQty, required this.isThai});

  static const _green = Color(0xFF3D7A56);
  static const _red   = Color(0xFFC0392B);
  static const _dark  = Color(0xFF2C1A0E);

  @override
  Widget build(BuildContext context) {
    final pct     = totalQty > 0 ? (wastedQty / totalQty * 100).round() : 0;
    final isClean = pct == 0;
    final centerColor = isClean ? _green : _red;
    return CustomPaint(
      size: const Size(130, 130),
      painter: _DonutPainter(wastedQty: wastedQty, totalQty: totalQty),
      child: SizedBox(
        width: 130, height: 130,
        child: Column(mainAxisAlignment: MainAxisAlignment.center, children: [
          Text('$pct%',
              style: TextStyle(
                  fontSize: 26, fontWeight: FontWeight.w900, color: centerColor)),
          Text(isThai ? 'ของเสีย' : 'wasted',
              style: TextStyle(fontSize: 10, color: _dark.withOpacity(0.5))),
        ]),
      ),
    );
  }
}

class _DonutPainter extends CustomPainter {
  final double wastedQty;
  final double totalQty;
  static const _green = Color(0xFF3D7A56);
  static const _red   = Color(0xFFC0392B);
  static const _track = Color(0x1A2C1A0E);

  const _DonutPainter({required this.wastedQty, required this.totalQty});

  @override
  void paint(Canvas canvas, Size size) {
    final cx = size.width / 2, cy = size.height / 2;
    final r  = size.width * 0.44;
    const sw = 14.0, start = -pi / 2, full = 2 * pi;
    final rect = Rect.fromCircle(center: Offset(cx, cy), radius: r);

    canvas.drawArc(rect, start, full, false,
        Paint()
          ..style = PaintingStyle.stroke
          ..strokeWidth = sw
          ..color = _track);

    if (totalQty > 0) {
      final notWasted = (totalQty - wastedQty).clamp(0.0, totalQty);
      final usedSweep   = full * notWasted  / totalQty;
      final wastedSweep = full * wastedQty.clamp(0, totalQty) / totalQty;

      if (usedSweep > 0)
        canvas.drawArc(rect, start, usedSweep, false,
            Paint()
              ..style = PaintingStyle.stroke
              ..strokeWidth = sw
              ..strokeCap = StrokeCap.round
              ..color = _green);

      if (wastedSweep > 0)
        canvas.drawArc(rect, start + usedSweep, wastedSweep, false,
            Paint()
              ..style = PaintingStyle.stroke
              ..strokeWidth = sw
              ..strokeCap = StrokeCap.round
              ..color = _red);
    }
  }

  @override
  bool shouldRepaint(_DonutPainter old) =>
      old.wastedQty != wastedQty || old.totalQty != totalQty;
}

// ══════════════════════════════════════════════════════════════
// DATA ROW
// ══════════════════════════════════════════════════════════════

class _MonthRow {
  final DateTime key;
  final double boughtCost, wastedCost, boughtQty, wastedQty;
  final String? topWastedName;

  const _MonthRow({
    required this.key,
    required this.boughtCost,
    required this.wastedCost,
    required this.boughtQty,
    required this.wastedQty,
    required this.topWastedName,
  });
}