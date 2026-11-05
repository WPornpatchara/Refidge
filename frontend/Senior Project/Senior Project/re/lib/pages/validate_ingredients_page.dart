import 'package:flutter/material.dart';
import 'package:re/models/inventory_item.dart';
import '../managers/app_locale.dart';

class ValidateIngredientsPage extends StatelessWidget {
  final List<InventoryItem> items;
  final AppLocale appLocale;
  final void Function(List<InventoryItem>) onConfirm;

  const ValidateIngredientsPage({
    super.key,
    required this.items,
    required this.appLocale,
    required this.onConfirm,
  });

  bool _isValid() {
    for (final i in items) {
      if (i.nameEn.trim().isEmpty) return false;
      if (i.quantity <= 0) return false;
      if (i.price < 0) return false;
      if (i.expireDate.isBefore(DateTime.now())) return false;
    }
    return true;
  }

  @override
  Widget build(BuildContext context) {

    return Scaffold(
      backgroundColor: const Color(0xFFFFF2C6),
      body: SafeArea(
        child: Column(
          children: [
            const SizedBox(height: 20),

            const Text(
              "Ingredient List",
              style: TextStyle(fontSize: 22, fontWeight: FontWeight.bold),
            ),

            const SizedBox(height: 20),

            Expanded(
              child: ListView.builder(
                padding: const EdgeInsets.all(16),
                itemCount: items.length,
                itemBuilder: (_, i) {
                  final item = items[i];
                  return Padding(
                    padding: const EdgeInsets.only(bottom: 12),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          item.nameEn,
                          style: const TextStyle(fontWeight: FontWeight.bold),
                        ),
                        Text("• ${item.quantity} ${item.unit}"),
                        Text("• ${item.price} บาท"),
                      ],
                    ),
                  );
                },
              ),
            ),

            Row(
              children: [
                Expanded(
                  child: ElevatedButton(
                    style: ElevatedButton.styleFrom(
                      backgroundColor: Colors.orange,
                    ),
                    onPressed: () {
                      Navigator.pop(context);
                    },
                    child: const Text("Edit"),
                  ),
                ),
                Expanded(
                  child: ElevatedButton(
                    style: ElevatedButton.styleFrom(
                      backgroundColor: Colors.green,
                    ),
                    onPressed: () {
                      if (_isValid()) {
                        onConfirm(items);
                        Navigator.pushReplacementNamed(
                            context, '/success');
                      } else {
                        Navigator.pushReplacementNamed(
                            context, '/error');
                      }
                    },
                    child: const Text("Confirm"),
                  ),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }
}
