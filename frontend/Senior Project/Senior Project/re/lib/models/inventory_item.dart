import 'storage_type.dart';

enum ItemStatus { inFridge, used, wasted }

class InventoryItem {
  final String id;
  final String nameTh;
  final String nameEn;

  // ── quantity fields ────────────────────────────────────────
  // quantity        = จำนวนที่เหลืออยู่ในตู้ตอนนี้ (ลดได้เมื่อ used)
  // initialQuantity = จำนวนที่ซื้อมาตั้งต้น (ไม่มีวันเปลี่ยน = Bought)
  // usedQuantity    = จำนวนที่ใช้ไปแล้ว (เพิ่มขึ้นทุกครั้งที่กด used)
  //
  // สมการที่ต้องเป็นจริงเสมอ:
  //   initialQuantity = quantity (inFridge) + usedQuantity + wastedQuantity
  //   wastedQuantity  = initialQuantity - quantity - usedQuantity  (คำนวณได้)
  final double quantity;
  final double initialQuantity;
  final double usedQuantity;

  final String unit;
  final double price;  // ราคาต่อหน่วย (per unit)

  final DateTime expireDate;
  final DateTime? purchaseDate;
  final StorageType storageType;

  final ItemStatus status;
  final DateTime? removedDate;

  final String freshnessLabel;
  final String? imageUrl;
  final String source;
  final double? centerX;
  final double? centerY;

  InventoryItem({
    required this.id,
    required this.nameTh,
    required this.nameEn,
    required this.quantity,
    required this.unit,
    required this.price,
    required this.expireDate,
    this.purchaseDate,
    this.storageType    = StorageType.fridge,
    this.status         = ItemStatus.inFridge,
    this.removedDate,
    double? initialQuantity,
    double? usedQuantity,
    required this.freshnessLabel,
    this.imageUrl,
    this.source = 'manual',
    this.centerX,
    this.centerY,
  })  : initialQuantity = initialQuantity ?? quantity,
        usedQuantity    = usedQuantity    ?? 0.0;

  String getLocationString(bool isThai) {
    if (centerX == null || centerX! < 0) return '';
    if (centerX! < 213) return isThai ? 'ซ้าย' : 'Left';
    if (centerX! < 426) return isThai ? 'กลาง' : 'Middle';
    return isThai ? 'ขวา' : 'Right';
  }

  // ── derived ────────────────────────────────────────────────

  DateTime get effectivePurchaseDate =>
      purchaseDate ?? expireDate.subtract(const Duration(days: 7));

  // จำนวนที่เสียไป = ซื้อมา - เหลืออยู่ - ใช้ไปแล้ว
  double get wastedQuantity =>
      (initialQuantity - quantity - usedQuantity).clamp(0.0, initialQuantity);

  // ราคารวมของ record นี้ตาม initialQuantity (= Bought cost)
  double get totalBoughtCost  => price * initialQuantity;
  double get totalUsedCost    => price * usedQuantity;
  double get totalWastedCost  => price * wastedQuantity;
  double get totalInFridgeCost => price * quantity;

  bool get isExpiredByDate {
    final now = DateTime(DateTime.now().year, DateTime.now().month, DateTime.now().day);
    final exp = DateTime(expireDate.year, expireDate.month, expireDate.day);
    return exp.isBefore(now);
  }

  ItemStatus get effectiveStatus {
    if (status == ItemStatus.inFridge && isExpiredByDate) return ItemStatus.wasted;
    return status;
  }

  String displayName(bool isThai) {
    final th = nameTh.trim();
    final en = nameEn.trim();
    if (isThai) return th.isNotEmpty ? th : en;
    return en.isNotEmpty ? en : th;
  }

  String displayQty(bool isThai) {
    final q = quantity.toStringAsFixed(
        quantity == quantity.roundToDouble() ? 0 : 2);
    return '$q $unit';
  }

  // ── copy ───────────────────────────────────────────────────

  InventoryItem copyWith({
    String? id,
    String? nameTh,
    String? nameEn,
    double? quantity,
    double? initialQuantity,
    double? usedQuantity,
    String? unit,
    double? price,
    DateTime? expireDate,
    DateTime? purchaseDate,
    StorageType? storageType,
    bool clearPurchaseDate = false,
    ItemStatus? status,
    DateTime? removedDate,
    bool clearRemovedDate = false,
    String? freshnessLabel,
    String? imageUrl,
  }) {
    return InventoryItem(
      id:              id              ?? this.id,
      nameTh:          nameTh          ?? this.nameTh,
      nameEn:          nameEn          ?? this.nameEn,
      quantity:        quantity        ?? this.quantity,
      initialQuantity: initialQuantity ?? this.initialQuantity,
      usedQuantity:    usedQuantity    ?? this.usedQuantity,
      unit:            unit            ?? this.unit,
      price:           price           ?? this.price,
      expireDate:      expireDate      ?? this.expireDate,
      purchaseDate:    clearPurchaseDate ? null : (purchaseDate ?? this.purchaseDate),
      storageType:     storageType     ?? this.storageType,
      status:          status          ?? this.status,
      removedDate:     clearRemovedDate ? null : (removedDate ?? this.removedDate),
      freshnessLabel:  freshnessLabel  ?? this.freshnessLabel,
      imageUrl:        imageUrl        ?? this.imageUrl,
    );
  }

  InventoryItem markUsed() => copyWith(
    status:      ItemStatus.used,
    removedDate: DateTime.now(),
    // เมื่อ mark used ทั้งหมด usedQuantity = initialQuantity, quantity = 0
    usedQuantity: initialQuantity,
    quantity:     0,
  );

  InventoryItem markWasted() => copyWith(
    status:      ItemStatus.wasted,
    removedDate: DateTime.now(),
  );

  // ── JSON ───────────────────────────────────────────────────

  Map<String, dynamic> toJson() => {
    'id':               id,
    'name':             nameEn.isNotEmpty ? nameEn : nameTh,
    'quantity':         quantity,
    'initial_quantity': initialQuantity,
    'used_quantity':    usedQuantity,
    'unit':             unit,
    'price':            price,
    'expiry_date':      expireDate.toIso8601String(),
    'purchase_date':    purchaseDate?.toIso8601String(),
    'status':           status.name,
    'removed_date':     removedDate?.toIso8601String(),
    'freshness_label':  freshnessLabel,
    'image_url':        imageUrl,
  };

  factory InventoryItem.fromJson(Map<String, dynamic> json) {
    DateTime? tryParseDate(dynamic value) {
      if (value == null) return null;
      final str = value.toString().trim();
      if (str.isEmpty) return null;
      return DateTime.tryParse(str);
    }

    double parseDouble(dynamic v, double fallback) {
      if (v == null) return fallback;
      if (v is num) return v.toDouble();
      return double.tryParse(v.toString()) ?? fallback;
    }

    final rawName   = (json['name'] ?? '').toString().trim();
    final cleanName = rawName.contains('_') ? rawName.split('_').first : rawName;

    final quantity        = parseDouble(json['quantity'], 0.0);
    // initial_quantity: ถ้าไม่มี (ของเก่า) ให้ใช้ quantity เป็น fallback
    final initialQuantity = parseDouble(json['initial_quantity'], quantity);
    final usedQuantity    = parseDouble(json['used_quantity'], 0.0);
    final price           = parseDouble(json['price'], 0.0);

    final expireDate = tryParseDate(json['expiry_date'])
        ?? DateTime.now().add(const Duration(days: 7));
    final purchaseDate = tryParseDate(json['purchase_date']);
    final unit = (json['unit'] ?? 'piece').toString();

    final statusStr = json['status']?.toString() ?? 'inFridge';
    final status    = ItemStatus.values.firstWhere(
      (e) => e.name == statusStr,
      orElse: () => ItemStatus.inFridge,
    );
    final removedDate = tryParseDate(json['removed_date']);

    final rawLabel = (json['freshness_label'] ?? 'Unknown').toString();
    final expFmt =
        '${expireDate.year}-${expireDate.month.toString().padLeft(2, '0')}-${expireDate.day.toString().padLeft(2, '0')}';
    
    final now = DateTime.now();
    final today = DateTime(now.year, now.month, now.day);
    final expDay = DateTime(expireDate.year, expireDate.month, expireDate.day);
    final diffDays = expDay.difference(today).inDays;

    DateTime finalExpireDate = expireDate;
    String freshnessLabel;
    if (diffDays <= 0 || rawLabel.toLowerCase() == 'rotten') {
      freshnessLabel = 'Expired';
      if (rawLabel.toLowerCase() == 'rotten' && diffDays > 0) {
        finalExpireDate = today;
      }
    } else {
      if (rawLabel.isEmpty || rawLabel == 'Unknown') {
        freshnessLabel = 'Exp: $expFmt ($diffDays day${diffDays == 1 ? '' : 's'} left)';
      } else {
        freshnessLabel = rawLabel;
      }
    }

    return InventoryItem(
      id:              (json['id'] ?? '').toString(),
      nameTh:          cleanName,
      nameEn:          cleanName,
      quantity:        quantity,
      initialQuantity: initialQuantity,
      usedQuantity:    usedQuantity,
      unit:            unit,
      price:           price,
      expireDate:      finalExpireDate,
      purchaseDate:    purchaseDate,
      storageType:     StorageType.fridge,
      status:          status,
      removedDate:     removedDate,
      freshnessLabel:  freshnessLabel,
      imageUrl:        (json['image_url'] ?? '').toString().isNotEmpty ? json['image_url'].toString() : null,
      source:          (json['source'] ?? 'manual').toString(),
      centerX:         json['center_x'] != null ? parseDouble(json['center_x'], -1) : null,
      centerY:         json['center_y'] != null ? parseDouble(json['center_y'], -1) : null,
    );
  }
}