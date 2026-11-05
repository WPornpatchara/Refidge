class IngredientMapper {
  static const Map<String, String> thToEn = {
    'กระเทียม': 'garlic',
    'หอมแดง': 'shallot',
    'หอมหัวใหญ่': 'onion',
    'ต้นหอม': 'spring onion',
    'ผักชี': 'coriander',

    'พริก': 'chili pepper',
    'พริกสด': 'chili pepper',
    'พริกแห้ง': 'chili pepper',
    'พริกป่น': 'chili pepper',

    'มะนาว': 'lime',
    'มะเขือเทศ': 'tomato',
    'แตงกวา': 'cucumber',
    'แครอท': 'carrot',
    'กะหล่ำปลี': 'cabbage',

    'ไก่': 'chicken',
    'หมู': 'pork',
    'เนื้อ': 'beef',

    'ไข่': 'egg',
    'นม': 'milk',
    'ข้าว': 'rice',
    'กุ้ง': 'shrimp',
    'ปลา': 'fish',
  };

  static String normalize(String s) {
    var x = s.trim().toLowerCase();
    x = x.replaceAll(RegExp(r'\s+'), ' ');
    x = x.replaceAll(RegExp(r'[^\p{L}\p{N}\s-]+', unicode: true), '');
    return x;
  }

  static final Map<String, String> _thToEnN = {
    for (final e in thToEn.entries) normalize(e.key): e.value,
  };

  static String? toMealDbKey(String rawName) {
    final raw = rawName.trim();
    if (raw.isEmpty) return null;

    final n = normalize(raw);

    // ถ้าเป็นอังกฤษอยู่แล้ว ใช้เลย
    if (RegExp(r'^[a-z\s-]+$', caseSensitive: false).hasMatch(n)) {
      return n;
    }

    // lookup ไทย
    final mapped = _thToEnN[n];
    if (mapped != null) return mapped;

    // ตัดเลข/วงเล็บที่มักติดมา เช่น "เนื้อ (1)"
    final stripped = normalize(raw.replaceAll(RegExp(r'[\d\(\)]'), ''));
    return _thToEnN[stripped];
  }
}
