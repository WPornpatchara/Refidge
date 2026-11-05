class ProductNameDict {
  static String normalize(String s) {
    return s.trim().toLowerCase().replaceAll(RegExp(r'\s+'), ' ');
  }

  static String capitalizeFirst(String s) {
    if (s.isEmpty) return s;
    return s[0].toUpperCase() + s.substring(1);
  }

  static const Map<String, String> enToTh = {
    'thyme': 'ไทม์',
    'shallots': 'หอมแดง',
    'cabbage': 'กะหล่ำปลี',
    'eggplant': 'มะเขือยาว',
    'kale': 'เคล',
    'green beans': 'ถั่วแขก',
    'chives': 'กุยช่าย',
    'watermelon': 'แตงโม',
    'lamb': 'เนื้อแกะ',
    'mussels': 'หอยแมลงภู่',
    'mint': 'สะระแหน่',
    'blueberries': 'บลูเบอร์รี',
    'corn': 'ข้าวโพด',
    'strawberries': 'สตรอว์เบอร์รี',
    'asparagus': 'หน่อไม้ฝรั่ง',
    'duck': 'เนื้อเป็ด',
    'tomatoes': 'มะเขือเทศ',
    'carrots': 'แครอท',
    'spinach': 'ผักโขม',
    'apples': 'แอปเปิล',
    'bananas': 'กล้วย',
    'chicken': 'ไก่',
    'salmon': 'แซลมอน',
    'garlic': 'กระเทียม',
    'onion': 'หัวหอมใหญ่',
    'lettuce': 'ผักกาดหอม',
    'potatoes': 'มันฝรั่ง',
    'oranges': 'ส้ม',
    'orange': 'ส้ม',
    'mangoes': 'มะม่วง',
    'beef': 'เนื้อวัว',
    'shrimp': 'กุ้ง',
    'cilantro': 'ผักชี',
    'ginger': 'ขิง',
    'peppers': 'พริกหวาน',
    'cucumbers': 'แตงกวา',
    'broccoli': 'บรอกโคลี',
    'grapes': 'องุ่น',
    'pineapple': 'สับปะรด',
    'pork': 'หมู',
    'tuna': 'ทูน่า',
    'rosemary': 'โรสแมรี',
    'lemongrass': 'ตะไคร้',
    'zucchini': 'ซูกินี',
    'cauliflower': 'ดอกกะหล่ำ',
    'basil': 'โหระพา',
    'papaya': 'มะละกอ',
    'clams': 'หอยกาบ',
  };

  static final Map<String, String> thToEn = {
    for (final e in enToTh.entries) e.value: e.key,
  };

  static List<String> get allEnglish {
    final s = <String>{};
    for (final k in enToTh.keys) {
      final x = k.trim();
      if (x.isNotEmpty) s.add(capitalizeFirst(x));
    }
    final list = s.toList();
    list.sort((a, b) => a.toLowerCase().compareTo(b.toLowerCase()));
    return list;
  }

  static List<String> get allThai {
    final s = <String>{};
    for (final v in enToTh.values) {
      final x = v.trim();
      if (x.isNotEmpty) s.add(capitalizeFirst(x));
    }
    final list = s.toList();
    list.sort((a, b) => a.toLowerCase().compareTo(b.toLowerCase()));
    return list;
  }

  static String toThai(String input) {
    final n = normalize(input);
    final result = enToTh[n] ?? input.trim();
    return capitalizeFirst(result);
  }

  static String toEnglish(String input) {
    final raw = input.trim();
    final hit = thToEn[raw];
    final result = hit ?? normalize(input);
    return capitalizeFirst(result);
  }
}