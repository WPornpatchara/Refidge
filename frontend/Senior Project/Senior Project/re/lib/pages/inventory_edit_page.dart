import 'package:flutter/material.dart';
import '../widgets/refridge_app_bar.dart';
import '../managers/app_locale.dart';
import '../services/product_name_dict.dart';
import '../services/unit_dict.dart';
import '../services/ingredient_image_service.dart';
import 'package:re/models/inventory_item.dart';

/// ✅ ผลลัพธ์จากหน้าแก้ไข (Save / Delete / Cancel)
class InventoryEditResult {
  final InventoryItem? item;
  final bool deleted;

  const InventoryEditResult._({required this.item, required this.deleted});

  factory InventoryEditResult.saved(InventoryItem item) =>
      InventoryEditResult._(item: item, deleted: false);

  factory InventoryEditResult.deleted() =>
      const InventoryEditResult._(item: null, deleted: true);

  factory InventoryEditResult.cancel() =>
      const InventoryEditResult._(item: null, deleted: false);
}

class InventoryEditPage extends StatefulWidget {
  final InventoryItem item;
  final AppLocale appLocale;

  const InventoryEditPage({
    super.key,
    required this.item,
    required this.appLocale,
  });

  @override
  State<InventoryEditPage> createState() => _InventoryEditPageState();
}

class _InventoryEditPageState extends State<InventoryEditPage> {
  late final TextEditingController _nameCtrl;
  late final TextEditingController _qtyCtrl;
  late final TextEditingController _priceCtrl;

  late DateTime _buyDate;
  late String _unit;

  static const _green = Color(0xFFA6C48A);

  @override
  void initState() {
    super.initState();

    _nameCtrl = TextEditingController(
      text: widget.appLocale.isThai ? widget.item.nameTh : widget.item.nameEn,
    );

    _qtyCtrl = TextEditingController(
      text: widget.item.quantity.toString(),
    );

    _priceCtrl = TextEditingController(
      text: widget.item.price.toStringAsFixed(0),
    );

    _buyDate = widget.item.expireDate;

    // ✅ กันเคส unit ว่าง
    _unit = widget.item.unit.trim().isEmpty ? 'kg' : widget.item.unit.trim();
  }

  @override
  void dispose() {
    _nameCtrl.dispose();
    _qtyCtrl.dispose();
    _priceCtrl.dispose();
    super.dispose();
  }

  String _fmt(DateTime d) =>
      "${d.year}-${d.month.toString().padLeft(2, '0')}-${d.day.toString().padLeft(2, '0')}";

  bool _looksThai(String s) => RegExp(r'[\u0E00-\u0E7F]').hasMatch(s);

  Future<void> _pickDate() async {
    final now = DateTime.now();
    final picked = await showDatePicker(
      context: context,
      initialDate: _buyDate,
      firstDate: DateTime(now.year - 5),
      lastDate: DateTime(now.year + 10),
    );
    if (picked != null) setState(() => _buyDate = picked);
  }

  void _save() {
    final isThai = widget.appLocale.isThai;
    final rawName = _nameCtrl.text.trim();
    final qty = double.tryParse(_qtyCtrl.text.trim()) ?? 0;
    final price = double.tryParse(_priceCtrl.text.trim()) ?? 0;

    if (rawName.isEmpty || qty <= 0) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(
            isThai ? 'กรุณากรอกชื่อและจำนวน' : 'Please enter name and quantity',
          ),
        ),
      );
      return;
    }

    String nameTh = '';
    String nameEn = '';

    // ✅ ใส่มาเป็นไทย -> เก็บไทย + แปลงอังกฤษ
    // ✅ ใส่มาเป็นอังกฤษ -> เก็บอังกฤษ + แปลงไทย
    if (_looksThai(rawName)) {
      nameTh = rawName;
      nameEn = ProductNameDict.toEnglish(rawName);
    } else {
      nameEn = ProductNameDict.normalize(rawName);
      nameTh = ProductNameDict.toThai(nameEn);
    }

    // คำนวณส่วนต่างเผื่อผู้ใช้แก้ไขจำนวน (Quantity) 
    // จะได้ปรับ InitialQuantity (จำนวนตอนซื้อ) ตามไปด้วย ป้องกันปริมาณของเสีย (Wasted) งอกเอง
    final diff = qty - widget.item.quantity;
    final newInitialQty = widget.item.initialQuantity + diff;

    final updated = widget.item.copyWith(
      nameTh: nameTh,
      nameEn: nameEn,
      quantity: qty,
      unit: _unit,
      price: price,
      expireDate: _buyDate,
      initialQuantity: newInitialQty < qty ? qty : newInitialQty,
    );

    Navigator.pop(context, InventoryEditResult.saved(updated));
  }

  Future<void> _delete() async {
    final isThai = widget.appLocale.isThai;

    final confirm = await showDialog<bool>(
      context: context,
      builder: (_) => AlertDialog(
        backgroundColor: _green, // ✅ popup สีเขียวเหมือน top bar
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(24),
        ),
        title: Text(
          isThai ? 'ลบสินค้า?' : 'Delete product?',
          style: const TextStyle(
            fontWeight: FontWeight.w900,
            fontSize: 20,
            color: Colors.black,
          ),
        ),
        content: Text(
          isThai ? 'คุณแน่ใจหรือไม่ว่าจะลบสินค้านี้' : 'Are you sure you want to delete this product?',
          style: const TextStyle(
            fontSize: 15,
            color: Colors.black87,
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            child: Text(
              isThai ? 'ยกเลิก' : 'Cancel',
              style: const TextStyle(color: Colors.black),
            ),
          ),
          ElevatedButton(
            style: ElevatedButton.styleFrom(
              backgroundColor: Colors.black, // ✅ ปุ่มยืนยันสีดำ
              foregroundColor: Colors.white, // ✅ ฟ้อนท์ขาว
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(14),
              ),
            ),
            onPressed: () => Navigator.pop(context, true),
            child: Text(isThai ? 'ยืนยัน' : 'Confirm'),
          ),
        ],
      ),
    );

    if (confirm == true) {
      Navigator.pop(context, InventoryEditResult.deleted());
    }
  }

  @override
  Widget build(BuildContext context) {
    final isThai = widget.appLocale.isThai;

    // ✅ รูปใช้ EN เสมอ (ถ้าพิมพ์ไทยก็แปลงก่อน)
    final inputForImage = _nameCtrl.text.trim().isEmpty
        ? (widget.item.nameEn.isNotEmpty ? widget.item.nameEn : widget.item.nameTh)
        : _nameCtrl.text.trim();

    final imgKey = ProductNameDict.toEnglish(inputForImage);
    final imgUrl = IngredientImageService.fromName(imgKey);

    return Scaffold(
      backgroundColor: const Color(0xFFF7F0B9),
      appBar: RefridgeAppBar(
        title: isThai ? 'แก้ไขสินค้า' : 'Edit Product',
        appLocale: widget.appLocale,
          items: const [], 
      ),
      body: SafeArea(
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 18, vertical: 14),
          child: Container(
            padding: const EdgeInsets.all(18),
            decoration: BoxDecoration(
              color: const Color(0xFFBFE3FF),
              borderRadius: BorderRadius.circular(18),
            ),
            child: Column(
              children: [
                _label(isThai ? 'ชื่อ' : 'Name'),
                TextField(
                  controller: _nameCtrl,
                  decoration: _inputDeco(),
                  onChanged: (_) => setState(() {}),
                ),

                _label(isThai ? 'จำนวน' : 'Quantity'),
                Row(
                  children: [
                    Expanded(
                      child: TextField(
                        controller: _qtyCtrl,
                        keyboardType: const TextInputType.numberWithOptions(decimal: true),
                        decoration: _inputDeco(),
                      ),
                    ),
                    const SizedBox(width: 10),
                    SizedBox(
                      width: 130,
                      child: DropdownButtonFormField<String>(
                        initialValue: _unit,
                        decoration: _inputDeco(),
                        items: [
                          DropdownMenuItem(value: 'kg', child: Text(UnitDict.text('kg', isThai))),
                          DropdownMenuItem(value: 'g', child: Text(UnitDict.text('g', isThai))),
                          DropdownMenuItem(value: 'piece', child: Text(UnitDict.text('piece', isThai))),
                          DropdownMenuItem(value: 'liter', child: Text(UnitDict.text('liter', isThai))),
                        ],
                        onChanged: (v) => setState(() => _unit = (v ?? 'kg')),
                      ),
                    ),
                  ],
                ),

                _label(isThai ? 'ราคา' : 'Price'),
                TextField(
                  controller: _priceCtrl,
                  keyboardType: const TextInputType.numberWithOptions(decimal: true),
                  decoration: _inputDeco(suffixText: isThai ? 'บาท' : 'Baht'),
                ),

                _label(isThai ? 'วันที่ซื้อ' : 'Purchase Date'),
                GestureDetector(
                  onTap: _pickDate,
                  child: AbsorbPointer(
                    child: TextField(
                      decoration: _inputDeco(),
                      controller: TextEditingController(text: _fmt(_buyDate)),
                    ),
                  ),
                ),

                const SizedBox(height: 16),

                // ✅ รูปไม่หายแล้ว (imgUrl ใช้จริง)
                Container(
                  width: 190,
                  height: 150,
                  padding: const EdgeInsets.all(12),
                  decoration: BoxDecoration(
                    color: const Color(0xFFF7F0B9),
                    borderRadius: BorderRadius.circular(18),
                  ),
                  child: ClipRRect(
                    borderRadius: BorderRadius.circular(14),
                    child: Image.network(
                      imgUrl,
                      fit: BoxFit.contain,
                      errorBuilder: (_, __, ___) => const Center(
                        child: Icon(Icons.fastfood, size: 42),
                      ),
                      loadingBuilder: (context, child, progress) {
                        if (progress == null) return child;
                        return const Center(
                          child: SizedBox(
                            width: 18,
                            height: 18,
                            child: CircularProgressIndicator(strokeWidth: 2),
                          ),
                        );
                      },
                    ),
                  ),
                ),

                const Spacer(),

                // ✅ สลับ: Delete อยู่บน / Save อยู่ล่าง
                SizedBox(
                  width: double.infinity,
                  height: 50,
                  child: ElevatedButton(
                    onPressed: _delete,
                    style: ElevatedButton.styleFrom(
                      backgroundColor: Colors.red,
                      foregroundColor: Colors.white,
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(14),
                      ),
                    ),
                    child: Text(
                      isThai ? 'ลบสินค้า' : 'Delete Product',
                      style: const TextStyle(fontWeight: FontWeight.w800),
                    ),
                  ),
                ),

                // ✅ เว้นความห่างปุ่ม
                const SizedBox(height: 18),

                SizedBox(
                  width: double.infinity,
                  height: 54,
                  child: ElevatedButton(
                    onPressed: _save,
                    style: ElevatedButton.styleFrom(
                      backgroundColor: Colors.black,
                      foregroundColor: Colors.white,
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(14),
                      ),
                    ),
                    child: Text(
                      isThai ? 'บันทึก' : 'Save',
                      style: const TextStyle(
                        fontSize: 20,
                        fontWeight: FontWeight.w800,
                        color: Colors.white, // ✅ ฟ้อนท์ขาวตามที่ขอ
                      ),
                    ),
                  ),
                ),

                const SizedBox(height: 10),
              ],
            ),
          ),
        ),
      ),
    );
  }

  Widget _label(String text) => Padding(
        padding: const EdgeInsets.only(left: 10, bottom: 6, top: 10),
        child: Align(
          alignment: Alignment.centerLeft,
          child: Text(
            text,
            style: const TextStyle(fontSize: 13, fontWeight: FontWeight.w600),
          ),
        ),
      );

  InputDecoration _inputDeco({String? suffixText}) => InputDecoration(
        filled: true,
        fillColor: Colors.white,
        contentPadding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
        border: OutlineInputBorder(
          borderRadius: BorderRadius.circular(18),
          borderSide: BorderSide.none,
        ),
        suffixText: suffixText,
        suffixStyle: const TextStyle(fontWeight: FontWeight.w700),
      );
}
