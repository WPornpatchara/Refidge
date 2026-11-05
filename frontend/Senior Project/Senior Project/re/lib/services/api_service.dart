import 'dart:convert';
import 'package:http/http.dart' as http;
import '../models/inventory_item.dart';

class ApiService {
  static const baseUrl = "http://10.0.2.2:8000";

  static Map<String, String> get _headers => {
        "Content-Type": "application/json",
      };

  // ================= FETCH =================

  /// ดึงเฉพาะ inFridge items → ใช้ในหน้า Inventory / Home / Notification
  static Future<List<InventoryItem>> fetchInventory() async {
    return _fetchInventoryFromUrl(Uri.parse("$baseUrl/inventory"));
  }

  /// ดึงทุก item รวม used/wasted → ใช้ในหน้า Expense Summary
  static Future<List<InventoryItem>> fetchAllInventory() async {
    return _fetchInventoryFromUrl(
        Uri.parse("$baseUrl/inventory?include_removed=true"));
  }

  static Future<List<InventoryItem>> _fetchInventoryFromUrl(Uri url) async {
    final response = await http.get(url);

    if (response.statusCode == 200) {
      final decoded = jsonDecode(response.body);

      List<dynamic> itemsJson;
      if (decoded is List) {
        itemsJson = decoded;
      } else if (decoded is Map<String, dynamic>) {
        itemsJson = decoded["items"] ?? [];
      } else {
        throw Exception("Unexpected response format");
      }

      return itemsJson.map((e) => InventoryItem.fromJson(e)).toList();
    } else {
      throw Exception("Fetch failed (${response.statusCode}): ${response.body}");
    }
  }

  // ================= ADD =================

  static Future<void> addInventoryItem(InventoryItem item) async {
    final url  = Uri.parse("$baseUrl/inventory");
    final body = jsonEncode({
      "name":          item.nameEn.isNotEmpty ? item.nameEn : item.nameTh,
      "quantity":      item.quantity,
      "unit":          item.unit,
      "price":         item.price,
      "expiry_date":   item.expireDate.toIso8601String(),
      // ── FIX: ส่ง purchase_date มาด้วย ──────────────────────
      // ถ้าไม่ส่ง backend จะไม่รู้ว่าซื้อเมื่อไหร่
      // → _effectivePurchaseMonth ใช้ now() แทน → group เดือนผิด
      "purchase_date": (item.purchaseDate ?? DateTime.now()).toIso8601String(),
      "freshness":     "fresh",
    });

    final response = await http.post(url, headers: _headers, body: body);
    if (response.statusCode != 200 && response.statusCode != 201) {
      throw Exception("Add failed (${response.statusCode}): ${response.body}");
    }
  }

  // ================= UPDATE =================

  static Future<void> updateInventoryItem(InventoryItem item) async {
    final url  = Uri.parse("$baseUrl/inventory/${item.id}");
    final body = jsonEncode({
      "name":          item.nameEn.isNotEmpty ? item.nameEn : item.nameTh,
      "quantity":      item.quantity,
      "unit":          item.unit,
      "price":         item.price,
      "expiry_date":   item.expireDate.toIso8601String(),
      "purchase_date": (item.purchaseDate ?? DateTime.now()).toIso8601String(),
      "freshness":     "fresh",
    });

    final response = await http.put(url, headers: _headers, body: body);
    if (response.statusCode != 200) {
      throw Exception("Update failed (${response.statusCode}): ${response.body}");
    }
  }

  // ================= DELETE =================

  /// Soft delete → mark wasted (เก็บ history ไว้ นับใน Wasted)
  static Future<void> deleteInventoryItem(String id) async {
    final url      = Uri.parse("$baseUrl/inventory/$id");
    final response = await http.delete(url, headers: _headers);
    if (response.statusCode != 200) {
      throw Exception("Delete failed (${response.statusCode}): ${response.body}");
    }
  }

  /// Hard delete → ลบออกจาก DB จริงๆ ไม่นับใน Spent/Wasted
  /// ใช้เมื่อ user ใส่ผิด ต้องการเอาออกโดยไม่กระทบตัวเลข
  static Future<void> hardDeleteInventoryItem(String id) async {
    final url      = Uri.parse("$baseUrl/inventory/$id/hard");
    final response = await http.delete(url, headers: _headers);
    if (response.statusCode != 200) {
      throw Exception("Hard delete failed (${response.statusCode}): ${response.body}");
    }
  }

  // ================= USE =================

  /// ลด quantity ของ item ลง [qty]
  /// ถ้าเหลือ 0 → backend จะ mark status = "used" อัตโนมัติ
  static Future<void> useInventoryItem(String id, double qty) async {
    final url = Uri.parse("$baseUrl/inventory/$id/use?qty=$qty");
    final response = await http.post(url, headers: _headers);
    if (response.statusCode != 200) {
      throw Exception("Use failed (${response.statusCode}): ${response.body}");
    }
  }
}