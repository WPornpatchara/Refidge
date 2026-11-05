import 'dart:io';
import 'dart:math';

import 'package:camera/camera.dart';
import 'package:flutter/material.dart';
import 'package:image_picker/image_picker.dart';
import 'package:permission_handler/permission_handler.dart';

import '../managers/app_locale.dart';
import '../models/inventory_item.dart';
import '../models/storage_type.dart';
import '../services/receipt_ocr_service.dart';
import 'success_page.dart';
import 'error_page.dart';

class ScanPage extends StatefulWidget {
  final AppLocale appLocale;
  final void Function(List<InventoryItem>)? onScanned;

  const ScanPage({
    super.key,
    required this.appLocale,
    this.onScanned,
  });

  @override
  State<ScanPage> createState() => _ScanPageState();
}

class _ScanPageState extends State<ScanPage> {
  CameraController? _cam;

  bool _busy  = false;
  bool _ready = false;
  String? _camError;

  List<String> _catalogNames = [];

  @override
  void initState() {
    super.initState();
    _initCamera();
    _loadCatalogNames();
  }

  @override
  void dispose() {
    ReceiptOcrService.dispose();
    _cam?.dispose();
    super.dispose();
  }

  Future<void> _loadCatalogNames() async {
    _catalogNames = <String>[
      'Chicken','Chicken Breast','Minced Chicken','ไก่','อกไก่','ไก่สับ','ปีกไก่','น่องไก่',
      'Pork','Minced Pork','Pork Belly','หมู','หมูสับ','หมูสามชั้น','สันคอหมู','ซี่โครงหมู',
      'Beef','Ground Beef','Steak','เนื้อวัว','เนื้อบด','สเต็ก','เนื้อสไลด์',
      'Salmon','Tuna','Fish','Seabass','Tilapia','ปลา','แซลมอน','ทูน่า','ปลากะพง','ปลาทับทิม',
      'Shrimp','Prawns','Squid','Crab','กุ้ง','ปลาหมึก','ปู',
      'Egg','Eggs','Chicken Egg','Duck Egg','ไข่','ไข่ไก่','ไข่เป็ด',
      'Bacon','Ham','Sausage','Meatball','เบคอน','แฮม','ไส้กรอก','ลูกชิ้น',
      'Broccoli','Cabbage','Chinese Cabbage','กะหล่ำปลี','ผักกาดขาว',
      'Carrot','แครอท','Cucumber','แตงกวา','Morning Glory','Water Spinach','ผักบุ้ง',
      'Kale','Chinese Kale','คะน้า','Spinach','ผักโขม','Lettuce','ผักกาดหอม',
      'Tomato','Cherry Tomato','มะเขือเทศ','Potato','มันฝรั่ง',
      'Onion','Red Onion','หอมหัวใหญ่','หอมแดง','ต้นหอม','Garlic','กระเทียม',
      'Chili','Pepper','พริก','พริกไทย','Mushroom','Enoki','เห็ด','เห็ดเข็มทอง',
      'Corn','Baby Corn','ข้าวโพด','ข้าวโพดอ่อน','Pumpkin','ฟักทอง',
      'Lemon','Lime','มะนาว','Ginger','ขิง','Galangal','ข่า','Lemongrass','ตะไคร้',
      'Basil','ใบกะเพรา','Sweet Basil','โหระพา','Coriander','ผักชี',
      'Apple','แอปเปิ้ล','Banana','กล้วย','กล้วยหอม','Orange','ส้ม',
      'Grape','องุ่น','Watermelon','แตงโม','Papaya','มะละกอ','Mango','มะม่วง',
      'Pineapple','สับปะรด','Strawberry','สตรอเบอร์รี่','Durian','ทุเรียน',
      'Mangosteen','มังคุด','Rambutan','เงาะ',
      'Milk','Fresh Milk','นม','นมสด','Yogurt','โยเกิร์ต','Butter','เนย','Cheese','ชีส',
      'Tofu','เต้าหู้','Bread','ขนมปัง','Rice','Jasmine Rice','ข้าว','ข้าวหอมมะลิ','ข้าวสาร',
      'Noodle','เส้นหมี่','บะหมี่','ก๋วยเตี๋ยว',
    ];
  }

  void _goSuccess() =>
      Navigator.push(context, MaterialPageRoute(builder: (_) => const SuccessPage()));

  void _goError() =>
      Navigator.push(context, MaterialPageRoute(builder: (_) => const ErrorPage()));

  Future<void> _initCamera() async {
    final isThai = widget.appLocale.isThai;
    try {
      setState(() { _ready = false; _camError = null; });

      final camPerm = await Permission.camera.request();
      if (!camPerm.isGranted) {
        setState(() {
          _camError = isThai ? 'ไม่ได้รับอนุญาตใช้กล้อง' : 'No camera permission';
          _ready = false;
        });
        return;
      }

      final cams = await availableCameras();
      if (cams.isEmpty) {
        setState(() {
          _camError = isThai ? 'ไม่พบกล้องในเครื่อง' : 'No camera found';
          _ready = false;
        });
        return;
      }

      final back = cams.firstWhere(
        (c) => c.lensDirection == CameraLensDirection.back,
        orElse: () => cams.first,
      );

      final controller = CameraController(back, ResolutionPreset.high, enableAudio: false);
      await controller.initialize();
      try { await controller.setFlashMode(FlashMode.off); } catch (_) {}

      if (!mounted) return;
      setState(() { _cam = controller; _ready = true; _camError = null; });
    } catch (e) {
      if (!mounted) return;
      setState(() {
        _camError = (isThai ? 'เปิดกล้องไม่สำเร็จ: ' : 'Failed to open camera: ') + e.toString();
        _ready = false;
      });
    }
  }

  Future<void> _scanFromCamera() async {
    final isThai = widget.appLocale.isThai;
    if (_cam == null || !_cam!.value.isInitialized || _busy) return;
    setState(() => _busy = true);
    try {
      final shot = await _cam!.takePicture();
      final f = File(shot.path);
      if (!f.existsSync()) throw Exception('Captured file not found: ${shot.path}');
      final result = await ReceiptOcrService.scanFromFile(f);
      if (!mounted) return;
      final txt = result.fullText.trim();
      if (txt.isEmpty) {
        await _showNoTextDialog(isThai);
        return;
      }
      await _openResultSheet(txt);
    } catch (e) {
      if (!mounted) return;
      _toast((isThai ? 'สแกนไม่สำเร็จ: ' : 'Scan failed: ') + e.toString());
      _goError();
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  Future<void> _scanFromGallery() async {
    final isThai = widget.appLocale.isThai;
    if (_busy) return;
    final p1 = await Permission.photos.request();
    final p2 = await Permission.storage.request();
    if (!p1.isGranted && !p2.isGranted) {
      _toast(isThai ? 'ไม่ได้รับอนุญาตเข้าถึงรูปภาพ' : 'No photo permission');
      _goError();
      return;
    }
    setState(() => _busy = true);
    try {
      final x = await ImagePicker().pickImage(source: ImageSource.gallery, imageQuality: 95);
      if (x == null) return;
      final f = File(x.path);
      if (!f.existsSync()) throw Exception('Selected file not found: ${x.path}');
      final result = await ReceiptOcrService.scanFromFile(f);
      if (!mounted) return;
      final txt = result.fullText.trim();
      if (txt.isEmpty) {
        await _showNoTextDialog(isThai);
        return;
      }
      await _openResultSheet(txt);
    } catch (e) {
      if (!mounted) return;
      _toast((isThai ? 'อ่านรูปไม่สำเร็จ: ' : 'Failed to read image: ') + e.toString());
      _goError();
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  Future<void> _showNoTextDialog(bool isThai) async {
    await showDialog<void>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: Text(isThai ? 'ไม่พบข้อความ' : 'No text found'),
        content: Text(isThai
            ? 'ระบบไม่สามารถอ่านข้อความจากรูปภาพได้ กรุณาลองใหม่อีกครั้ง'
            : 'Could not read any text from the image. Please try again.'),
        actions: [TextButton(onPressed: () => Navigator.pop(ctx), child: Text(isThai ? 'ตกลง' : 'OK'))],
      ),
    );
  }

  // ── shelf life helpers ──────────────────────────────────────────────────────

  int _baseShelfDaysFromName(String enLower) {
    final s = enLower;
    final meat    = ['chicken','beef','pork','duck','lamb','meat','bacon','ham','sausage','ไก่','หมู','เนื้อ'];
    final seafood = ['fish','salmon','tuna','shrimp','clam','mussel','seafood','squid','crab','ปลา','กุ้ง','ปลาหมึก'];
    final dairy   = ['milk','cheese','yogurt','butter','egg','cream','นม','ชีส','เนย','ไข่','โยเกิร์ต'];
    final leafy   = ['lettuce','spinach','kale','cabbage','cilantro','basil','mint','morning glory','ผักกาด','ผักโขม','คะน้า','กะหล่ำ','ผักชี','โหระพา','กะเพรา','ผักบุ้ง'];
    final veg     = ['broccoli','cauliflower','cucumber','carrot','eggplant','zucchini','tomato','mushroom','pepper','chili','corn','แตงกวา','แครอท','มะเขือ','เห็ด','พริก','ข้าวโพด'];
    final root    = ['potato','onion','garlic','ginger','lemongrass','มันฝรั่ง','หอม','กระเทียม','ขิง','ตะไคร้'];
    final fruit   = ['apple','banana','orange','mango','pineapple','grape','papaya','watermelon','berry','lemon','lime','แอปเปิ้ล','กล้วย','ส้ม','มะม่วง','สับปะรด','องุ่น','มะละกอ','แตงโม','มะนาว'];
    bool hit(List<String> keys) => keys.any((k) => s.contains(k));
    if (hit(meat) || hit(seafood)) return 3;
    if (hit(dairy)) return 7;
    if (hit(leafy)) return 5;
    if (hit(veg))   return 7;
    if (hit(fruit)) return 7;
    if (hit(root))  return 14;
    return 7;
  }

  bool _isRawMeatOrSeafood(String s) {
    const keys = ['chicken','beef','pork','duck','lamb','salmon','tuna','fish','shrimp','clam','mussel','seafood','squid','crab','ไก่','หมู','เนื้อ','ปลา','กุ้ง','ปลาหมึก','ปู'];
    return keys.any((k) => s.contains(k));
  }

  int _daysFor(StorageType storage, String enLower) {
    final base = _baseShelfDaysFromName(enLower);
    switch (storage) {
      case StorageType.fridge:   return base;
      case StorageType.freezer:  return _isRawMeatOrSeafood(enLower) ? 180 : base * 6;
      case StorageType.pantry:   return _isRawMeatOrSeafood(enLower) ? base : (base * 3).clamp(5, 60);
    }
  }

  DateTime? _tryParsePurchaseDate(String fullText) {
    final t = fullText.replaceAll('\r', ' ');
    final m1 = RegExp(r'\b(\d{1,2})[\/\-](\d{1,2})[\/\-](\d{2,4})\b').firstMatch(t);
    if (m1 != null) {
      int? yy = int.tryParse(m1.group(3)!);
      if (yy != null && yy < 100) yy += 2000;
      final mm = int.tryParse(m1.group(1)!);
      final dd = int.tryParse(m1.group(2)!);
      if (mm != null && dd != null && yy != null) return DateTime(yy, mm, dd);
    }
    final m2 = RegExp(r'\b(\d{4})[\/\-](\d{1,2})[\/\-](\d{1,2})\b').firstMatch(t);
    if (m2 != null) {
      final yy = int.tryParse(m2.group(1)!);
      final mm = int.tryParse(m2.group(2)!);
      final dd = int.tryParse(m2.group(3)!);
      if (yy != null && mm != null && dd != null) return DateTime(yy, mm, dd);
    }
    return null;
  }

  Future<DateTime?> _pickPurchaseDate(DateTime initial) async {
    final now = DateTime.now();
    return showDatePicker(
      context: context,
      initialDate: initial,
      firstDate: DateTime(now.year - 2),
      lastDate: DateTime(now.year + 2),
    );
  }

  // ── result bottom sheet ─────────────────────────────────────────────────────

  Future<void> _openResultSheet(String fullText) async {
    final isThai = widget.appLocale.isThai;
    final parsed = _parseReceipt(fullText);
    DateTime purchaseDate = _tryParsePurchaseDate(fullText) ?? DateTime.now();

    final List<_EditScannedItem> editItems = [];
    for (final p in parsed) {
      final best = bestMatchName(p.rawName, _catalogNames);
      String name = best ?? normalizeReceiptName(p.rawName);
      final isThaiName = RegExp(r'[\u0E00-\u0E7F]').hasMatch(name);

      if (best == null) {
        if (isThaiName) { if (name.length < 2) continue; }
        else {
          if (name.length < 5 || name.contains(RegExp(r'\d'))) continue;
          if (['LIN','NON','B.','NET','CP','PCS','QTY','AMT'].contains(name.toUpperCase())) continue;
        }
      }
      if (name.isEmpty) continue;

      final enLower = name.toLowerCase().trim();
      var st = StorageType.fridge;
      if (_isRawMeatOrSeafood(enLower)) st = StorageType.freezer;

      editItems.add(_EditScannedItem(
        name:       name,
        quantity:   p.quantity,
        unit:       p.unit,
        price:      p.price,
        storage:    st,
        expireDate: purchaseDate.add(Duration(days: _daysFor(st, enLower))),
      ));
    }

    if (editItems.isEmpty) {
      showDialog<void>(
        context: context,
        builder: (ctx) => AlertDialog(
          title:   Text(isThai ? 'ไม่พบรายการสินค้า' : 'No items found'),
          content: Text(isThai
              ? 'ระบบไม่สามารถระบุรายการสินค้าจากภาพได้ กรุณาลองใหม่หรือเพิ่มเอง'
              : 'Could not identify any items. Please try again or add manually.'),
          actions: [TextButton(onPressed: () => Navigator.pop(ctx), child: Text(isThai ? 'ตกลง' : 'OK'))],
        ),
      );
      return;
    }

    List<InventoryItem> toInventoryItems() {
      return editItems.where((i) => i.isSelected).map((m) {
        final expFmt =
            '${m.expireDate.year}-${m.expireDate.month.toString().padLeft(2,"0")}-${m.expireDate.day.toString().padLeft(2,"0")}';
        final now = DateTime.now();
        final today = DateTime(now.year, now.month, now.day);
        final expDay = DateTime(m.expireDate.year, m.expireDate.month, m.expireDate.day);
        final diffDays = expDay.difference(today).inDays;

        String calculatedLabel;
        if (diffDays <= 0) {
          calculatedLabel = 'Expired';
        } else {
          calculatedLabel = 'Exp: $expFmt ($diffDays day${diffDays == 1 ? '' : 's'} left)';
        }

        return InventoryItem(
          id:           '${DateTime.now().microsecondsSinceEpoch}_${Random().nextInt(9999)}',
          nameTh:       m.name,
          nameEn:       m.name,
          quantity:     m.quantity,
          unit:         m.unit,
          price:        m.price,
          purchaseDate: purchaseDate,
          storageType:  m.storage,
          expireDate:   m.expireDate,
          freshnessLabel: calculatedLabel,
        );
      }).toList();
    }

    final result = await showModalBottomSheet<List<InventoryItem>>(
      context:           context,
      isScrollControlled: true,
      backgroundColor:   const Color(0xFFFFF2C6),
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(22)),
      ),
      builder: (ctx) {
        final height = MediaQuery.of(ctx).size.height;

        return StatefulBuilder(
          builder: (ctx, setSheet) {
            String fmt(DateTime d) =>
                '${d.year}-${d.month.toString().padLeft(2,'0')}-${d.day.toString().padLeft(2,'0')}';

            void updateStorage(int index, StorageType newStorage) {
              final item    = editItems[index];
              final enLower = item.name.toLowerCase().trim();
              setSheet(() {
                item.storage    = newStorage;
                item.expireDate = purchaseDate.add(Duration(days: _daysFor(newStorage, enLower)));
              });
            }

            return SafeArea(
              child: Padding(
                padding: EdgeInsets.only(
                  left: 16, right: 16, top: 14,
                  bottom: MediaQuery.of(ctx).viewInsets.bottom + 16,
                ),
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    // drag handle
                    Container(
                      width: 48, height: 5,
                      decoration: BoxDecoration(
                        color: Colors.black.withOpacity(0.2),
                        borderRadius: BorderRadius.circular(99),
                      ),
                    ),
                    const SizedBox(height: 12),
                    Text(isThai ? 'ผลการสแกน' : 'Scan Result',
                        style: const TextStyle(fontSize: 18, fontWeight: FontWeight.w800)),
                    const SizedBox(height: 10),

                    // header row
                    Row(children: [
                      Expanded(
                        child: Text(
                          isThai
                              ? 'ตรวจสอบรายการ (${editItems.where((e) => e.isSelected).length})'
                              : 'Review Items (${editItems.where((e) => e.isSelected).length})',
                          style: const TextStyle(fontWeight: FontWeight.bold),
                        ),
                      ),
                      const SizedBox(width: 10),
                      Expanded(
                        child: _pillButton(
                          label:     isThai ? 'วันที่ซื้อ' : 'Purchase date',
                          valueText: fmt(purchaseDate),
                          onTap: () async {
                            final picked = await _pickPurchaseDate(purchaseDate);
                            if (picked != null) {
                              setSheet(() {
                                purchaseDate = picked;
                                for (final item in editItems) {
                                  final enLower = item.name.toLowerCase().trim();
                                  item.expireDate = purchaseDate.add(Duration(days: _daysFor(item.storage, enLower)));
                                }
                              });
                            }
                          },
                        ),
                      ),
                    ]),
                    const SizedBox(height: 12),

                    // item list
                    Container(
                      height: height * 0.45,
                      decoration: BoxDecoration(
                        color:        Colors.white.withOpacity(0.5),
                        borderRadius: BorderRadius.circular(16),
                      ),
                      child: ListView.separated(
                        padding:          const EdgeInsets.all(8),
                        itemCount:        editItems.length,
                        separatorBuilder: (_, __) => const SizedBox(height: 8),
                        itemBuilder: (_, i) {
                          final item = editItems[i];
                          return Card(
                            key: ObjectKey(item),
                            elevation: 0,
                            color: Colors.white,
                            shape: RoundedRectangleBorder(
                              borderRadius: BorderRadius.circular(12),
                              side: item.isSelected
                                  ? BorderSide.none
                                  : BorderSide(color: Colors.grey.withOpacity(0.3)),
                            ),
                            child: Padding(
                              padding: const EdgeInsets.all(8),
                              child: Column(children: [

                                // ── row 1: checkbox + name + price field ──
                                Row(children: [
                                  Checkbox(
                                    value:       item.isSelected,
                                    activeColor: const Color(0xFF99BC85),
                                    onChanged:   (v) => setSheet(() => item.isSelected = v ?? false),
                                  ),
                                  Expanded(
                                    child: TextFormField(
                                      initialValue: item.name,
                                      enabled:      item.isSelected,
                                      decoration: const InputDecoration(
                                        isDense:        true,
                                        border:         InputBorder.none,
                                        contentPadding: EdgeInsets.zero,
                                      ),
                                      style: TextStyle(
                                        fontWeight: FontWeight.bold,
                                        fontSize:   16,
                                        color:      item.isSelected ? Colors.black : Colors.grey,
                                        decoration: item.isSelected ? null : TextDecoration.lineThrough,
                                      ),
                                      onChanged: (val) => item.name = val,
                                    ),
                                  ),

                                  // ── price field (editable) ──────────────
                                  SizedBox(
                                    width: 80,
                                    height: 36,
                                    child: TextField(
                                      controller:   item.priceCtrl,
                                      enabled:      item.isSelected,
                                      keyboardType: const TextInputType.numberWithOptions(decimal: true),
                                      textAlign:    TextAlign.right,
                                      style: TextStyle(
                                        fontWeight: FontWeight.w900,
                                        fontSize:   14,
                                        color:      item.isSelected
                                            ? const Color(0xFF2C1A0E)
                                            : Colors.grey,
                                      ),
                                      decoration: InputDecoration(
                                        prefixText:     '฿',
                                        prefixStyle:    TextStyle(
                                          fontWeight: FontWeight.w700,
                                          color:      item.isSelected
                                              ? const Color(0xFF2C1A0E)
                                              : Colors.grey,
                                        ),
                                        isDense:        true,
                                        contentPadding: const EdgeInsets.symmetric(
                                            horizontal: 8, vertical: 8),
                                        filled:         true,
                                        fillColor:      item.isSelected
                                            ? Colors.amber.withOpacity(0.12)
                                            : Colors.grey.withOpacity(0.06),
                                        border: OutlineInputBorder(
                                          borderRadius: BorderRadius.circular(8),
                                          borderSide:   BorderSide.none,
                                        ),
                                      ),
                                      onChanged: (v) {
                                        final parsed = double.tryParse(v);
                                        if (parsed != null && parsed >= 0) {
                                          item.price = parsed;
                                        }
                                      },
                                    ),
                                  ),
                                ]),

                                // ── row 2: storage + expiry (only when selected) ──
                                if (item.isSelected) ...[
                                  const Divider(height: 1),
                                  const SizedBox(height: 4),
                                  Row(children: [
                                    Expanded(
                                      flex: 3,
                                      child: Container(
                                        height: 36,
                                        padding: const EdgeInsets.symmetric(horizontal: 8),
                                        decoration: BoxDecoration(
                                          color:        Colors.grey.shade100,
                                          borderRadius: BorderRadius.circular(8),
                                        ),
                                        child: DropdownButtonHideUnderline(
                                          child: DropdownButton<StorageType>(
                                            value:      item.storage,
                                            isExpanded: true,
                                            icon: const Icon(Icons.arrow_drop_down, size: 20),
                                            style: const TextStyle(fontSize: 13, color: Colors.black87),
                                            items: StorageType.values.map((s) => DropdownMenuItem(
                                              value: s,
                                              child: Text(s.label(isThai)),
                                            )).toList(),
                                            onChanged: (v) {
                                              if (v != null) updateStorage(i, v);
                                            },
                                          ),
                                        ),
                                      ),
                                    ),
                                    const SizedBox(width: 8),
                                    Expanded(
                                      flex: 2,
                                      child: InkWell(
                                        onTap: () async {
                                          final picked = await _pickPurchaseDate(item.expireDate);
                                          if (picked != null) setSheet(() => item.expireDate = picked);
                                        },
                                        child: Container(
                                          height: 36,
                                          alignment: Alignment.center,
                                          decoration: BoxDecoration(
                                            color:        Colors.grey.shade100,
                                            borderRadius: BorderRadius.circular(8),
                                          ),
                                          child: Text(fmt(item.expireDate),
                                              style: const TextStyle(fontSize: 12)),
                                        ),
                                      ),
                                    ),
                                  ]),
                                ],
                              ]),
                            ),
                          );
                        },
                      ),
                    ),
                    const SizedBox(height: 12),

                    // action buttons
                    Row(children: [
                      Expanded(
                        child: SizedBox(
                          height: 48,
                          child: ElevatedButton(
                            style: ElevatedButton.styleFrom(
                              backgroundColor: Colors.black,
                              foregroundColor: Colors.white,
                              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
                            ),
                            onPressed: () {
                              Navigator.pop(ctx);
                            },
                            child: Text(isThai ? 'ปิด' : 'Close'),
                          ),
                        ),
                      ),
                      const SizedBox(width: 12),
                      Expanded(
                        child: SizedBox(
                          height: 48,
                          child: ElevatedButton(
                            style: ElevatedButton.styleFrom(
                              backgroundColor: const Color(0xFF99BC85),
                              foregroundColor: Colors.black,
                              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
                            ),
                            onPressed: () {
                              if (editItems.where((e) => e.isSelected).isEmpty) {
                                _toast(isThai
                                    ? 'กรุณาเลือกอย่างน้อย 1 รายการ'
                                    : 'Please select at least one item');
                                return;
                              }
                              FocusScope.of(ctx).unfocus();
                              final items = toInventoryItems();
                              Navigator.pop(ctx, items);
                            },
                            child: Text(isThai ? 'เพิ่มเข้าคลัง' : 'Add to Inventory'),
                          ),
                        ),
                      ),
                    ]),
                  ],
                ),
              ),
            );
          },
        );
      },
    );

    // Delay the disposal to allow the keyboard and cursor to clean up safely, preventing the red screen crash.
    Future.delayed(const Duration(milliseconds: 300), () {
      for (final e in editItems) e.dispose();
    });

    if (result != null && result.isNotEmpty && mounted) {
      widget.onScanned?.call(result);
      _goSuccess();
    }
  }

  // ── widget helpers ──────────────────────────────────────────────────────────

  Widget _pillButton({
    required String label,
    required String valueText,
    required VoidCallback onTap,
  }) {
    return SizedBox(
      height: 44,
      child: InkWell(
        onTap:        onTap,
        borderRadius: BorderRadius.circular(14),
        child: Ink(
          decoration: BoxDecoration(
            color:        Colors.white.withOpacity(0.75),
            borderRadius: BorderRadius.circular(14),
          ),
          child: Padding(
            padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
            child: Row(children: [
              Expanded(
                child: Text('$label: $valueText',
                    style: const TextStyle(fontSize: 13),
                    overflow: TextOverflow.ellipsis),
              ),
              const Icon(Icons.calendar_month, size: 18),
            ]),
          ),
        ),
      ),
    );
  }

  void _toast(String msg) {
    if (!mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(msg)));
  }

  // ── receipt parser ──────────────────────────────────────────────────────────

  List<_ParsedLineItem> _parseReceipt(String text) {
    final lines = text.split('\n').map((e) => e.trim()).where((e) => e.isNotEmpty).toList();

    double? tryMoney(String s) {
      final cleaned = s.trim()
          .replaceAll(RegExp(r'\s+[A-Za-z]$'), '')
          .replaceAll(',', '')
          .trim();
      final v = double.tryParse(cleaned);
      if (v == null || v <= 0 || v >= 100000) return null;
      return v;
    }

    bool isProductCodeLine(String u) {
      if (RegExp(r'^\d{3,}\s+[A-Z]{1,3}\s+\d{2,}$').hasMatch(u)) return true;
      final parts = u.split(RegExp(r'\s+'));
      if (parts.length >= 2 && parts.every((p) => RegExp(r'^[A-Z]{2,6}$').hasMatch(p))) {
        const realFoodWords = {
          'APPLE','APL','GALA','FUJI','POTATO','POTATOES','LEMON','LEMONS','LIME','LIMES',
          'ONION','ONIONS','RED','YLW','YELLOW','TOMATO','TOMATOES','ROMA','NUTS','ALMOND',
          'WALNUT','PECAN','CHICKEN','BEEF','PORK','LAMB','TURKEY','FISH','SHRIMP','SALMON',
          'TUNA','EGG','EGGS','MILK','CHEESE','BUTTER','BREAD','RICE','CORN','CARROT',
          'CARROTS','BANANA','BANANAS','GRAPE','GRAPES','MANGO','ORANGE','ORANGES','SPINACH',
          'KALE','BROCCOLI','CELERY','LETTUCE','MUSHROOM','MUSHROOMS','PEPPER','PEPPERS',
        };
        if (!parts.any((p) => realFoodWords.contains(p))) return true;
      }
      if (RegExp(r'\d{5,}').hasMatch(u)) return true;
      return false;
    }

    bool isNoiseLine(String s) {
      final u = s.toUpperCase().trim();
      if (u.length < 2) return true;
      if (isProductCodeLine(u)) return true;
      if (RegExp(r'^\d{3,5}\s+[A-Z.\-]').hasMatch(u)) return true;
      if (RegExp(r'^\d{3}[-\.]\d{3}[-\.]\d{4}').hasMatch(u)) return true;
      if (u.startsWith('YOUR CASHIER')) return true;
      if (u.startsWith('RIGHT STORE') || u.startsWith('RIGHT PRICE')) return true;
      if (u.startsWith('KROGER')) return true;
      if (RegExp(r'^\d+\.?\d*\s*(LB|KG|G)\s*@').hasMatch(u)) return true;
      if (RegExp(r'^\d+\s*@\s*\d').hasMatch(u)) return true;
      if (RegExp(r'^(WT|WGT|F|N|B|T)$').hasMatch(u)) return true;
      const noiseWords = [
        'TAX','VAT','TOTAL','SUBTOTAL','CHANGE','CASH','DISCOUNT','CASHIER','RECEIPT',
        'INV','BILL','TABLE','ORDER','THANK','DATE','TIME','TEL','POS','STORE','BRANCH',
        'MEMBER','CARD','VISA','MASTER','QR','PAYMENT','AMOUNT','QTY','PRICE','ITEM',
        'NO.','BAHT','THB','SLIP','SHOP','TERMINAL','MID','TID','MERCHANT','TRACE',
        'BATCH','REF','APP','MC','V.NO','APPR','AID','TC','SEQ','NET','REF.','INVOICE',
        'ABB','PLUS','CUSTOMER','KROGER',
      ];
      if (noiseWords.any((w) => u.contains(w))) return true;
      if (RegExp(r'^\d{1,2}[\/\-]\d{1,2}[\/\-]\d{2,4}$').hasMatch(u)) return true;
      if (RegExp(r'^[\d\s\.\,\-\+\*\/]+$').hasMatch(u)) return true;
      if (u.contains('XXXX') || u.contains('****')) return true;
      return false;
    }

    bool isCodeLine(String s) => s.startsWith('(') && s.endsWith(')');

    final netQty  = RegExp(r'(\d+(?:\.\d+)?)\s*(KG|G)\b', caseSensitive: false);
    final perUnit = RegExp(r'@?\s*(\d+(?:\.\d+)?)\s*\/\s*(KG|G|PCS|PC|EA)\b', caseSensitive: false);
    final starRe  = RegExp(r'^(\d+(?:\.\d+)?)\s*\*\s*(\d+(?:\.\d+)?)$');

    final items = <_ParsedLineItem>[];

    String findNameBefore(int idx) {
      int j = idx - 1;
      while (j >= 0) {
        final s = lines[j];
        if (isCodeLine(s)) { j--; continue; }
        if (!isNoiseLine(s)) return s;
        j--;
      }
      return '';
    }

    for (int i = 0; i < lines.length; i++) {
      final line = lines[i];
      if (isCodeLine(line) || isNoiseLine(line)) continue;
      final u = line.toUpperCase();

      final mStar = starRe.firstMatch(u);
      if (mStar != null && i + 1 < lines.length) {
        final qty   = double.tryParse(mStar.group(1)!) ?? 1.0;
        final total = tryMoney(lines[i + 1]) ?? 0;
        if (total > 0) {
          final name = findNameBefore(i);
          if (name.isNotEmpty) {
            items.add(_ParsedLineItem(rawName: name, quantity: qty, unit: 'piece', price: total));
            i++;
          }
        }
        continue;
      }

      final mQty = netQty.firstMatch(u);
      if (mQty != null && (u.contains('NET') || u.contains('KG') || u.contains(' G'))) {
        final qty     = double.tryParse(mQty.group(1)!) ?? 1.0;
        final unitRaw = mQty.group(2)!.toUpperCase();
        final unit    = unitRaw == 'G' ? 'g' : 'kg';
        double total  = 0;
        if (i + 1 < lines.length) {
          final t = tryMoney(lines[i + 1]);
          if (t != null && t > 0) total = t;
        }
        if (total <= 0) {
          final moneyInLine = RegExp(r'(\d+(?:\.\d+)?)$').firstMatch(u);
          if (moneyInLine != null) {
            final t = tryMoney(moneyInLine.group(1)!);
            if (t != null && t > 0) total = t;
          }
        }
        if (total <= 0) continue;
        final name = findNameBefore(i);
        if (name.isEmpty) continue;
        items.add(_ParsedLineItem(rawName: name, quantity: qty, unit: unit, price: total));
        continue;
      }

      final mPer = perUnit.firstMatch(u);
      if (mPer != null && i + 1 < lines.length) {
        final total = tryMoney(lines[i + 1]) ?? 0;
        if (total <= 0) continue;
        String unit = 'piece';
        final uom = mPer.group(2)!.toUpperCase();
        if (uom == 'KG') unit = 'kg';
        if (uom == 'G')  unit = 'g';
        final name = findNameBefore(i);
        if (name.isEmpty) continue;
        items.add(_ParsedLineItem(rawName: name, quantity: 1.0, unit: unit, price: total));
        continue;
      }

      {
        final name = normalizeReceiptName(line);
        if (name.length > 2 && !isNoiseLine(name)) {
          double? foundPrice;
          int priceLineIdx = -1;
          for (int k = i + 1; k < lines.length && k <= i + 3; k++) {
            final kPrice = tryMoney(lines[k]);
            if (kPrice != null) { foundPrice = kPrice; priceLineIdx = k; break; }
            if (!isNoiseLine(lines[k])) break;
          }
          if (foundPrice != null) {
            items.add(_ParsedLineItem(rawName: name, quantity: 1, unit: 'piece', price: foundPrice));
            i = priceLineIdx;
            continue;
          }
        }
      }

      final priceMatch = RegExp(r'(\d+(?:,\d{3})*(?:\.\d{1,2})?)\s*(?:[A-Za-z฿]{0,3})?\s*$').firstMatch(line);
      if (priceMatch != null) {
        final price = double.tryParse(priceMatch.group(1)!.replaceAll(',', ''));
        if (price != null && price > 0) {
          String namePart = line.substring(0, priceMatch.start).trim()
              .replaceAll(RegExp(r'^\d+[\.\s]+'), '')
              .replaceAll(RegExp(r'^\d+\s*[xX]\s*'), '')
              .replaceAll(RegExp(r'[฿]'), '')
              .replaceAll(RegExp(r'^[\.\-\s]+'), '')
              .trim();
          if (namePart.length < 2 || isNoiseLine(namePart) || !RegExp(r'[A-Za-z\u0E00-\u0E7F]').hasMatch(namePart)) {
            final prev = findNameBefore(i);
            if (prev.isNotEmpty) {
              namePart = prev.replaceAll(RegExp(r'^\d+[\.\s]+'), '').replaceAll(RegExp(r'[฿]'), '').replaceAll(RegExp(r'^[\.\-\s]+'), '').trim();
              if (isNoiseLine(namePart)) namePart = '';
            }
          }
          if (namePart.length >= 2 && !isNoiseLine(namePart) && RegExp(r'[A-Za-z\u0E00-\u0E7F]').hasMatch(namePart)) {
            items.add(_ParsedLineItem(rawName: namePart, quantity: 1.0, unit: 'piece', price: price));
            continue;
          }
        }
      }
    }
    return items;
  }

  // ── build ───────────────────────────────────────────────────────────────────

  @override
  Widget build(BuildContext context) {
    final isThai = widget.appLocale.isThai;

    return Scaffold(
      backgroundColor: Colors.black,
      body: SafeArea(
        child: Stack(
          children: [
            Positioned.fill(
              child: _ready && _cam != null
                  ? CameraPreview(_cam!)
                  : Container(
                      color: Colors.black,
                      child: Center(
                        child: Text(
                          _camError ?? (isThai ? 'กำลังเปิดกล้อง...' : 'Opening camera...'),
                          style: const TextStyle(color: Colors.white70),
                          textAlign: TextAlign.center,
                        ),
                      ),
                    ),
            ),
            Positioned.fill(
              child: IgnorePointer(child: CustomPaint(painter: _ScanOverlayPainter())),
            ),
            Positioned(
              left: 16, right: 16, bottom: 18,
              child: Row(children: [
                Expanded(
                  child: SizedBox(
                    height: 52,
                    child: ElevatedButton.icon(
                      onPressed: _busy ? null : _scanFromCamera,
                      style: ElevatedButton.styleFrom(
                        backgroundColor: const Color(0xFF99BC85),
                        foregroundColor: Colors.black,
                        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
                      ),
                      icon: _busy
                          ? const SizedBox(width: 18, height: 18,
                              child: CircularProgressIndicator(strokeWidth: 2))
                          : const Icon(Icons.document_scanner),
                      label: Text(
                        isThai ? 'สแกนใบเสร็จ' : 'Scan Receipt',
                        style: const TextStyle(fontWeight: FontWeight.w800),
                      ),
                    ),
                  ),
                ),
                const SizedBox(width: 12),
                SizedBox(
                  width: 52, height: 52,
                  child: InkWell(
                    onTap:        _busy ? null : _scanFromGallery,
                    borderRadius: BorderRadius.circular(26),
                    child: Container(
                      decoration: BoxDecoration(
                          color: Colors.white, borderRadius: BorderRadius.circular(26)),
                      child: const Icon(Icons.photo, color: Colors.black),
                    ),
                  ),
                ),
              ]),
            ),
          ],
        ),
      ),
    );
  }
}

// ─────────────────────────────────────────────────────────────────────────────
class _ScanOverlayPainter extends CustomPainter {
  @override
  void paint(Canvas canvas, Size size) {
    final dimPaint = Paint()..color = Colors.black.withOpacity(0.55);
    canvas.drawRect(Offset.zero & size, dimPaint);

    final w    = size.width  * 0.78;
    final h    = size.height * 0.58;
    final left = (size.width - w) / 2;
    final top  = size.height * 0.14;

    final cutout = RRect.fromRectAndRadius(
      Rect.fromLTWH(left, top, w, h), const Radius.circular(18));

    canvas.saveLayer(Offset.zero & size, Paint());
    canvas.drawRect(Offset.zero & size, dimPaint);
    canvas.drawRRect(cutout, Paint()..blendMode = BlendMode.clear);
    canvas.restore();

    final cornerPaint = Paint()
      ..color       = Colors.white70
      ..strokeWidth = 3
      ..style       = PaintingStyle.stroke;
    const c = 26.0;
    final r = cutout.outerRect;
    canvas.drawLine(Offset(r.left,     r.top),    Offset(r.left + c, r.top),    cornerPaint);
    canvas.drawLine(Offset(r.left,     r.top),    Offset(r.left,     r.top + c),cornerPaint);
    canvas.drawLine(Offset(r.right-c,  r.top),    Offset(r.right,    r.top),    cornerPaint);
    canvas.drawLine(Offset(r.right,    r.top),    Offset(r.right,    r.top + c),cornerPaint);
    canvas.drawLine(Offset(r.left,     r.bottom), Offset(r.left + c, r.bottom), cornerPaint);
    canvas.drawLine(Offset(r.left,     r.bottom-c),Offset(r.left,    r.bottom), cornerPaint);
    canvas.drawLine(Offset(r.right-c,  r.bottom), Offset(r.right,    r.bottom), cornerPaint);
    canvas.drawLine(Offset(r.right,    r.bottom-c),Offset(r.right,   r.bottom), cornerPaint);
  }

  @override
  bool shouldRepaint(covariant CustomPainter oldDelegate) => false;
}

// ─────────────────────────────────────────────────────────────────────────────
class _ParsedLineItem {
  final String rawName;
  final double quantity;
  final String unit;
  final double price;
  const _ParsedLineItem({
    required this.rawName,
    required this.quantity,
    required this.unit,
    required this.price,
  });
}

class _EditScannedItem {
  String      name;
  double      quantity;
  String      unit;
  double      price;
  StorageType storage;
  DateTime    expireDate;
  bool        isSelected;

  late final TextEditingController priceCtrl;

  _EditScannedItem({
    required this.name,
    required this.quantity,
    required this.unit,
    required this.price,
    required this.storage,
    required this.expireDate,
    this.isSelected = true,
  }) {
    priceCtrl = TextEditingController(
      text: price == price.roundToDouble()
          ? price.toStringAsFixed(0)
          : price.toStringAsFixed(2),
    );
  }

  void dispose() => priceCtrl.dispose();
}

// ─────────────────────────────────────────────────────────────────────────────
String normalizeReceiptName(String s) {
  var x = s.toUpperCase().trim();
  const junkWords = ['SPECIAL','NET','PRICE','AMOUNT','CHANGE','CASH','DISCOUNT','THANK','YOU','DATE','TIME','SUBTOTAL','BAHT','THB'];
  for (final j in junkWords) x = x.replaceAll(RegExp(r'\b' + j + r'\b'), ' ');
  x = x.replaceAll(RegExp(r'@\s*\d+(\.\d+)?\s*\/\s*[A-Z]+'), ' ');
  x = x.replaceAll(RegExp(r'\b(KG|G|LB|PCS|PC|EA|BAG|PACK|ML|L)\b'), ' ');
  x = x.replaceAll(RegExp(r'[^A-Z0-9\u0E00-\u0E7F\s]'), '');
  return x.replaceAll(RegExp(r'\s+'), ' ').trim();
}

const Map<String, String> _receiptAliases = {
  'APL':'Apple','APL GALA':'Apple','APL FUJI':'Apple','APL HONEYCRISP':'Apple',
  'GALA':'Apple','FUJI':'Apple','HONEYCRISP':'Apple','GRANNY':'Apple','GRANNY SMITH':'Apple',
  'ONIONS RED':'Red Onion','ONIONS YLW':'Onion','ONIONS WHT':'Onion','YLW ONION':'Onion','RED ONION':'Red Onion',
  'ROMA TOMATO':'Tomato','ROMA':'Tomato','TOMATOES':'Tomato','CHERRY TOMATO':'Cherry Tomato','GRAPE TOMATO':'Cherry Tomato',
  'POTATOES':'Potato','RUSSET':'Potato','RUSSET POTATO':'Potato','RED POTATO':'Potato',
  'LEMONS':'Lemon','LIMES':'Lime','KRO':'Kroger Item',
  'BANANAS':'Banana','GRAPES':'Grape','RED GRAPE':'Grape','GREEN GRAPE':'Grape',
  'CARROTS':'Carrot','BABY CARROT':'Carrot','BABY CARROTS':'Carrot',
  'BROC':'Broccoli','BROCCOLI CROWN':'Broccoli','CELERY':'Spinach',
  'ROMAINE':'Lettuce','ICEBERG':'Lettuce','GREEN LEAF':'Lettuce',
  'BABY SPINACH':'Spinach','MUSHROOMS':'Mushroom','WHITE MUSHROOM':'Mushroom','BUTTON MUSHROOM':'Mushroom',
  'BELL PEPPER':'Pepper','GREEN PEPPER':'Pepper','RED PEPPER':'Pepper','SWEET CORN':'Corn',
  'GRD BEEF':'Ground Beef','GRND BEEF':'Ground Beef','GND BEEF':'Ground Beef',
  'GRD TURKEY':'Chicken','BRSLS SPROUT':'Broccoli',
  'LARGE EGGS':'Egg','LG EGGS':'Egg','BROWN EGGS':'Egg',
  'WHOLE MILK':'Milk','2% MILK':'Milk','SKIM MILK':'Milk','ORGANIC MILK':'Milk',
  'STRAWBERRIES':'Strawberry','STRAW':'Strawberry',
  'PINEAPPLES':'Pineapple','SEEDLESS WATERMELON':'Watermelon','MANGOES':'Mango',
  'PRSL':'','BSL':'','SL ORG':'',
};

String? bestMatchName(String raw, List<String> catalogNames, {double threshold = 0.6}) {
  final n = normalizeReceiptName(raw);
  if (n.isEmpty) return null;

  final alias = _receiptAliases[n];
  if (alias != null) {
    if (alias.isEmpty) return null;
    return catalogNames.firstWhere((c) => c.toUpperCase() == alias.toUpperCase(), orElse: () => alias);
  }

  final tokens = n.split(' ');
  if (tokens.isNotEmpty) {
    final tokenAlias = _receiptAliases[tokens.first];
    if (tokenAlias != null && tokenAlias.isNotEmpty) {
      return catalogNames.firstWhere((c) => c.toUpperCase() == tokenAlias.toUpperCase(), orElse: () => tokenAlias);
    }
  }

  final nClean = n.replaceAll(RegExp(r'\d'), '').replaceAll(RegExp(r'\s+'), ' ').trim();
  if (nClean.isEmpty) return null;

  String? best;
  double bestScore = 0;

  for (final c in catalogNames) {
    final cn = normalizeReceiptName(c).replaceAll(RegExp(r'\d'), '').replaceAll(RegExp(r'\s+'), ' ').trim();
    if (cn.isEmpty) continue;
    double score = similarity(nClean, cn);
    if (nClean.contains(cn)) score += 0.45;
    else if (cn.contains(nClean) && nClean.length > 3) score += 0.25;
    score = score.clamp(0.0, 1.0);
    if (score > bestScore) { bestScore = score; best = c; }
  }

  return bestScore < threshold ? null : best;
}

double similarity(String a, String b) {
  if (a.isEmpty || b.isEmpty) return 0;
  return 1.0 - (levenshtein(a, b) / max(a.length, b.length));
}

int levenshtein(String a, String b) {
  if (a == b) return 0;
  if (a.isEmpty) return b.length;
  if (b.isEmpty) return a.length;
  final dp = List.generate(a.length + 1, (_) => List<int>.filled(b.length + 1, 0));
  for (int i = 0; i <= a.length; i++) dp[i][0] = i;
  for (int j = 0; j <= b.length; j++) dp[0][j] = j;
  for (int i = 1; i <= a.length; i++) {
    for (int j = 1; j <= b.length; j++) {
      final cost = a[i-1] == b[j-1] ? 0 : 1;
      dp[i][j] = min(dp[i-1][j]+1, min(dp[i][j-1]+1, dp[i-1][j-1]+cost));
    }
  }
  return dp[a.length][b.length];
}