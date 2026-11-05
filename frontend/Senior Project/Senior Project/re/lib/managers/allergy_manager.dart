import 'package:shared_preferences/shared_preferences.dart';

class AllergyManager {
  static const _kAllergies = 'user.allergies';

  static Future<Set<String>> load() async {
    final sp = await SharedPreferences.getInstance();
    final list = sp.getStringList(_kAllergies) ?? <String>[];
    return list.map((e) => e.toLowerCase().trim()).where((e) => e.isNotEmpty).toSet();
  }

  static Future<void> save(Set<String> allergies) async {
    final sp = await SharedPreferences.getInstance();
    await sp.setStringList(_kAllergies, allergies.toList());
  }
}
