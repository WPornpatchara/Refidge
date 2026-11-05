import 'package:flutter/material.dart';
import 'package:re/models/inventory_item.dart';
import '../widgets/refridge_app_bar.dart';
import '../managers/app_locale.dart';
import '../services/product_name_dict.dart';
import '../services/unit_dict.dart';
import '../models/storage_type.dart';
//real one
class AddIngredientsPage extends StatefulWidget {
  final AppLocale appLocale;

  const AddIngredientsPage({
    super.key,
    required this.appLocale,
  });

  @override
  State<AddIngredientsPage> createState() => _AddIngredientsPageState();
}

class _AddIngredientsPageState extends State<AddIngredientsPage> {
  final _nameCtrl = TextEditingController();
  final _qtyCtrl = TextEditingController(text: '1');
  final _priceCtrl = TextEditingController(text: '1');
  final _dateCtrl = TextEditingController();

  final FocusNode _nameFocus = FocusNode();

  DateTime? _purchaseDate;
  String _unit = 'g';
  StorageType _storage = StorageType.fridge;

  static const List<String> _units = ['kg', 'g', 'piece', 'liter'];

  late final List<String> _allSuggestions;

  @override
  void initState() {
    super.initState();
    _allSuggestions = _buildSuggestionList();
  }

  @override
  void dispose() {
    _nameCtrl.dispose();
    _qtyCtrl.dispose();
    _priceCtrl.dispose();
    _dateCtrl.dispose();
    _nameFocus.dispose();
    super.dispose();
  }

  List<String> _buildSuggestionList() {
    final names = <String>{};

    for (final n in ProductNameDict.allEnglish) {
      final x = n.trim();
      if (x.isNotEmpty) names.add(x);
    }
    for (final n in ProductNameDict.allThai) {
      final x = n.trim();
      if (x.isNotEmpty) names.add(x);
    }

    final list = names.toList()
      ..sort((a, b) => a.toLowerCase().compareTo(b.toLowerCase()));
    return list;
  }

  String _fmt(DateTime d) =>
      "${d.year}-${d.month.toString().padLeft(2, '0')}-${d.day.toString().padLeft(2, '0')}";

  Future<void> _pickDate() async {
    final now = DateTime.now();
    final initial = _purchaseDate ?? now;

    final picked = await showDatePicker(
      context: context,
      initialDate: initial,
      firstDate: DateTime(now.year - 2),
      lastDate: DateTime(now.year + 2),
    );

    if (picked != null) {
      setState(() {
        _purchaseDate = picked;
        _dateCtrl.text = _fmt(picked);
      });
    }
  }

  String _unitLabel(String unit, bool isThai) {
    return UnitDict.text(unit, isThai);
  }

  int _baseShelfDaysFromName(String enLower) {
    final s = enLower;

    final meat = ['chicken', 'beef', 'pork', 'duck', 'lamb', 'meat'];
    final seafood = ['fish', 'salmon', 'tuna', 'shrimp', 'clam', 'clams', 'mussels', 'seafood'];
    final dairy = ['milk', 'cheese', 'yogurt', 'butter', 'egg', 'eggs'];

    final leafy = ['lettuce', 'spinach', 'kale', 'cabbage', 'cilantro', 'basil', 'mint', 'chives'];
    final veg = ['broccoli', 'cauliflower', 'cucumber', 'carrot', 'eggplant', 'zucchini', 'tomato', 'tomatoes'];
    final root = ['potato', 'potatoes', 'onion', 'garlic', 'ginger', 'lemongrass'];
    final fruit = [
      'apple',
      'apples',
      'banana',
      'bananas',
      'orange',
      'oranges',
      'mango',
      'mangoes',
      'pineapple',
      'grape',
      'grapes',
      'papaya',
      'watermelon',
      'peas'
    ];

    bool hit(List<String> keys) => keys.any((k) => s.contains(k));

    if (hit(meat) || hit(seafood)) return 2;
    if (hit(dairy)) return 7;

    if (hit(leafy)) return 5;
    if (hit(veg)) return 7;
    if (hit(fruit)) return 7;
    if (hit(root)) return 21;

    return 7;
  }

  bool _isRawMeatOrSeafood(String enLower) {
    final s = enLower;
    const keys = [
      'chicken',
      'beef',
      'pork',
      'duck',
      'lamb',
      'salmon',
      'tuna',
      'fish',
      'shrimp',
      'clam',
      'clams',
      'mussels',
      'seafood'
    ];
    return keys.any((k) => s.contains(k));
  }

  int _daysFor(StorageType storage, String enLower) {
    final base = _baseShelfDaysFromName(enLower);

    switch (storage) {
      case StorageType.fridge:
        return base;
      case StorageType.freezer:
        if (_isRawMeatOrSeafood(enLower)) return 180;
        return base * 6;
      case StorageType.pantry:
        if (_isRawMeatOrSeafood(enLower)) return base;
        return (base * 3).clamp(5, 60);
    }
  }

  bool _looksThai(String s) => RegExp(r'[\u0E00-\u0E7F]').hasMatch(s);

  void _submit() {
    FocusScope.of(context).unfocus();

    final isThai = widget.appLocale.isThai;

    final rawName = _nameCtrl.text.trim();
    if (rawName.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text(isThai ? 'กรุณากรอกชื่อสินค้า' : 'Please fill product name')),
      );
      return;
    }

    final qty = double.tryParse(_qtyCtrl.text.trim());
    if (qty == null || qty <= 0) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text(isThai ? 'กรุณากรอกจำนวนให้ถูกต้อง' : 'Please enter valid quantity')),
      );
      return;
    }

    // ปกติเวลา Add Manually ผู้ใช้จะกรอก "ราคารวม" 
    // แต่ระบบใช้ price เป็น "ราคาต่อหน่วย" (per unit) 
    // จึงต้องเอามาหาร qty ให้เป็นราคาต่อหน่วยก่อน มิฉะนั้นจะคูณเบิ้ลและบวกผิด
    final totalPrice =
        double.tryParse(_priceCtrl.text.trim().isEmpty ? '0' : _priceCtrl.text.trim()) ?? 0;
    final unitPrice = qty > 0 ? totalPrice / qty : 0.0;

    if (_purchaseDate == null) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text(isThai ? 'กรุณาเลือกวันที่ซื้อ' : 'Please select purchase date')),
      );
      return;
    }

    String nameTh = '';
    String nameEn = '';

    // ✅ [แก้ไข] ตรวจสอบภาษาที่พิมพ์ ถ้าพิมพ์ไทยให้เก็บลง nameTh โดยตรง
    if (_looksThai(rawName)) {
      nameTh = rawName;
      nameEn = ProductNameDict.toEnglish(rawName); // พยายามแปลเป็นอังกฤษ
    } else {
      nameEn = ProductNameDict.normalize(rawName);
      nameTh = ProductNameDict.toThai(nameEn); // พยายามแปลเป็นไทย
    }

    var st = _storage;
    final enLower = nameEn.toLowerCase().trim();
    if (st == StorageType.pantry && _isRawMeatOrSeafood(enLower)) {
      st = StorageType.fridge;
    }

    final expire = _purchaseDate!.add(Duration(days: _daysFor(st, enLower)));
    final expFmt =
        '${expire.year}-${expire.month.toString().padLeft(2, '0')}-${expire.day.toString().padLeft(2, '0')}';

    final now = DateTime.now();
    final today = DateTime(now.year, now.month, now.day);
    final expDay = DateTime(expire.year, expire.month, expire.day);
    final diffDays = expDay.difference(today).inDays;

    String calculatedLabel;
    if (diffDays <= 0) {
      calculatedLabel = 'Expired';
    } else {
      calculatedLabel = 'Exp: $expFmt ($diffDays day${diffDays == 1 ? '' : 's'} left)';
    }

    final item = InventoryItem(
      id: DateTime.now().microsecondsSinceEpoch.toString(),
      nameTh: nameTh,
      nameEn: nameEn,
      quantity: qty,
      unit: _unit,
      price: unitPrice,
      expireDate: expire,
      purchaseDate: _purchaseDate,
      storageType: st,
      freshnessLabel: calculatedLabel,
    );

    Navigator.of(context).pop(item);
  }

  Iterable<String> _optionsFor(String query) {
    final q = query.trim();
    if (q.isEmpty) return const Iterable<String>.empty();

    final ql = q.toLowerCase();
    final starts = <String>[];
    final contains = <String>[];

    for (final s in _allSuggestions) {
      final sl = s.toLowerCase();
      if (sl.startsWith(ql)) {
        starts.add(s);
      } else if (sl.contains(ql)) {
        contains.add(s);
      }
    }

    final merged = [...starts, ...contains];
    if (merged.length > 8) return merged.take(8);
    return merged;
  }

  @override
  Widget build(BuildContext context) {
    final isThai = widget.appLocale.isThai;

    return Scaffold(
      backgroundColor: const Color(0xFFF7F0B9),
      appBar: RefridgeAppBar(
        title: isThai ? 'เพิ่มสินค้า' : 'Add Product',
        appLocale: widget.appLocale,
        items: const [],
      ),
      body: SafeArea(
        child: Center(
          child: SingleChildScrollView(
            padding: const EdgeInsets.symmetric(horizontal: 18, vertical: 22),
            child: Container(
              width: 340,
              padding: const EdgeInsets.symmetric(horizontal: 18, vertical: 18),
              decoration: BoxDecoration(
                color: const Color(0xFFBFD7F2),
                borderRadius: BorderRadius.circular(10),
              ),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  RawAutocomplete<String>(
                    textEditingController: _nameCtrl,
                    focusNode: _nameFocus,
                    optionsBuilder: (TextEditingValue v) => _optionsFor(v.text),
                    displayStringForOption: (s) => s,
                    onSelected: (s) {
                      _nameCtrl
                        ..text = s
                        ..selection = TextSelection.collapsed(offset: s.length);
                      _nameFocus.unfocus();
                    },
                    fieldViewBuilder: (context, controller, focusNode, onFieldSubmitted) {
                      return _pillField(
                        controller: controller,
                        hint: isThai ? 'ชื่อสินค้า' : 'Product name',
                        focusNode: focusNode,
                      );
                    },
                    optionsViewBuilder: (context, onSelected, options) {
                      final list = options.toList();
                      return Align(
                        alignment: Alignment.topLeft,
                        child: Material(
                          color: Colors.transparent,
                          child: ConstrainedBox(
                            constraints: const BoxConstraints(maxWidth: 340),
                            child: Container(
                              margin: const EdgeInsets.only(top: 6),
                              decoration: BoxDecoration(
                                color: Colors.white,
                                borderRadius: BorderRadius.circular(14),
                                boxShadow: [
                                  BoxShadow(
                                    color: Colors.black.withOpacity(0.12),
                                    blurRadius: 16,
                                    offset: const Offset(0, 8),
                                  ),
                                ],
                              ),
                              child: ListView.separated(
                                padding: const EdgeInsets.symmetric(vertical: 6),
                                shrinkWrap: true,
                                itemCount: list.length,
                                separatorBuilder: (_, __) => Divider(
                                  height: 1,
                                  color: Colors.black.withOpacity(0.06),
                                ),
                                itemBuilder: (_, i) {
                                  final s = list[i];
                                  return InkWell(
                                    onTap: () => onSelected(s),
                                    child: Padding(
                                      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
                                      child: Text(
                                        s,
                                        style: const TextStyle(fontSize: 13, fontWeight: FontWeight.w600),
                                      ),
                                    ),
                                  );
                                },
                              ),
                            ),
                          ),
                        ),
                      );
                    },
                  ),

                  const SizedBox(height: 14),

                  Row(
                    children: [
                      Expanded(
                        child: _pillField(
                          controller: _qtyCtrl,
                          hint: isThai ? 'จำนวน' : 'Quantity',
                          keyboardType: const TextInputType.numberWithOptions(decimal: true),
                        ),
                      ),
                      const SizedBox(width: 10),
                      SizedBox(
                        width: 130,
                        height: 40,
                        child: DropdownButtonFormField<String>(
                          initialValue: _unit,
                          decoration: InputDecoration(
                            filled: true,
                            fillColor: Colors.white.withOpacity(0.75),
                            contentPadding: const EdgeInsets.symmetric(horizontal: 12),
                            border: OutlineInputBorder(
                              borderRadius: BorderRadius.circular(14),
                              borderSide: BorderSide.none,
                            ),
                          ),
                          items: _units.map((u) {
                            return DropdownMenuItem(
                              value: u,
                              child: Text(_unitLabel(u, isThai)),
                            );
                          }).toList(),
                          onChanged: (v) {
                            if (v != null) setState(() => _unit = v);
                          },
                          selectedItemBuilder: (context) {
                            return _units
                                .map((u) => Align(
                                      alignment: Alignment.centerLeft,
                                      child: Text(_unitLabel(u, isThai)),
                                    ))
                                .toList();
                          },
                        ),
                      ),
                    ],
                  ),

                  const SizedBox(height: 14),

                  _pillStorage(isThai),

                  const SizedBox(height: 14),

                  _pillField(
                    controller: _priceCtrl,
                    hint: isThai ? 'ราคา' : 'Price',
                    keyboardType: const TextInputType.numberWithOptions(decimal: true),
                    suffixText: isThai ? 'บาท' : 'Baht',
                  ),

                  const SizedBox(height: 14),

                  GestureDetector(
                    onTap: _pickDate,
                    child: AbsorbPointer(
                      child: _pillField(
                        controller: _dateCtrl,
                        hint: isThai ? 'วันที่ซื้อ' : 'Purchase date',
                      ),
                    ),
                  ),

                  const SizedBox(height: 18),

                  SizedBox(
                    width: 190,
                    height: 42,
                    child: ElevatedButton(
                      onPressed: _submit,
                      style: ElevatedButton.styleFrom(
                        backgroundColor: const Color(0xFF1E1E1E),
                        foregroundColor: Colors.white,
                        elevation: 0,
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(6),
                        ),
                      ),
                      child: Text(
                        isThai ? 'เพิ่มสินค้า' : 'Add product',
                        style: const TextStyle(fontWeight: FontWeight.w600),
                      ),
                    ),
                  ),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }

  Widget _pillStorage(bool isThai) {
    return SizedBox(
      height: 40,
      child: DropdownButtonFormField<StorageType>(
        initialValue: _storage,
        decoration: InputDecoration(
          filled: true,
          fillColor: Colors.white.withOpacity(0.75),
          contentPadding: const EdgeInsets.symmetric(horizontal: 12),
          border: OutlineInputBorder(
            borderRadius: BorderRadius.circular(14),
            borderSide: BorderSide.none,
          ),
        ),
        items: StorageType.values
            .map(
              (t) => DropdownMenuItem(
                value: t,
                child: Text(isThai ? 'ที่เก็บ: ${t.label(true)}' : 'Storage: ${t.label(false)}'),
              ),
            )
            .toList(),
        onChanged: (v) {
          if (v != null) setState(() => _storage = v);
        },
      ),
    );
  }

  Widget _pillField({
    required TextEditingController controller,
    required String hint,
    FocusNode? focusNode,
    TextInputType? keyboardType,
    String? suffixText,
  }) {
    return SizedBox(
      height: 40,
      child: TextField(
        controller: controller,
        focusNode: focusNode,
        keyboardType: keyboardType,
        style: const TextStyle(fontSize: 13),
        decoration: InputDecoration(
          hintText: hint,
          hintStyle: TextStyle(
            color: Colors.grey.shade500,
            fontSize: 12,
          ),
        suffixText: suffixText,
        suffixStyle: TextStyle(
          color: Colors.grey.shade600,
          fontSize: 12,
        ),
          filled: true,
          fillColor: Colors.white.withOpacity(0.75),
          contentPadding: const EdgeInsets.symmetric(horizontal: 14),
          border: OutlineInputBorder(
            borderRadius: BorderRadius.circular(14),
            borderSide: BorderSide.none,
          ),
        ),
      ),
    );
  }
}