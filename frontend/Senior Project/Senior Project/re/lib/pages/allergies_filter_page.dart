import 'dart:ui';
import 'package:flutter/material.dart';
import 'package:re/models/inventory_item.dart';
import '../managers/allergy_manager.dart';
import '../widgets/refridge_app_bar.dart';
import '../managers/app_locale.dart';

class AllergiesFilterPage extends StatefulWidget {
  final AppLocale appLocale;

  const AllergiesFilterPage({
    super.key,
    required this.appLocale,
  });

  @override
  State<AllergiesFilterPage> createState() => _AllergiesFilterPageState();
}

class _AllergiesFilterPageState extends State<AllergiesFilterPage> {
  final _searchCtrl = TextEditingController();

  final List<String> _allOptions = const [
    'Thyme','Shallots','Cabbage','Eggplant','Kale','Green beans','Chives','Watermelon','Lamb','Mussels',
    'Mint','Blueberries','Corn','Strawberries','Asparagus','Duck',
    'Tomatoes','Carrots','Spinach','Apples','Bananas','Chicken','Salmon','Garlic','Onion','Lettuce',
    'Potatoes','Oranges','Mangoes','Beef','Shrimp','Cilantro',
    'Ginger','Peppers','Cucumbers','Broccoli','Grapes','Pineapple','Pork','Tuna','Rosemary','Lemongrass',
    'Zucchini','Cauliflower','Basil','Papaya','Clams',
  ];

  static const Map<String, String> _th = {
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

  Set<String> _selected = {};
  List<String> _filtered = [];
  bool _loading = true;

  static const Color _bg = Color(0xFFFFF2C6);
  static const Color _cream = Color(0xFFF6F4DC);
  static const Color _mint = Color(0xFFBEE0C7);
  static const Color _freshLeaf = Color(0xFF339551);
  static const Color _basil = Color(0xFF266533);

  @override
  void initState() {
    super.initState();
    _searchCtrl.addListener(_applySearch);
    _init();
  }

  @override
  void dispose() {
    _searchCtrl.dispose();
    super.dispose();
  }

  String _norm(String s) => s.toLowerCase().trim();

  Future<void> _init() async {
    final loaded = await AllergyManager.load();
    if (!mounted) return;
    setState(() {
      _selected = loaded.map(_norm).toSet();
      _filtered = _allOptions;
      _loading = false;
    });
  }

  String _displayName(String name, bool isThai) {
    if (!isThai) return name;
    return _th[_norm(name)] ?? name;
  }

  String _enFromKey(String key) {
    return _allOptions.firstWhere((o) => _norm(o) == key, orElse: () => key);
  }

  void _toggle(String name) {
    final key = _norm(name);
    setState(() {
      if (_selected.contains(key)) {
        _selected.remove(key);
      } else {
        _selected.add(key);
      }
    });
  }

  void _applySearch() {
    final q = _norm(_searchCtrl.text);
    if (q.isEmpty) {
      setState(() => _filtered = _allOptions);
      return;
    }

    final starts = <String>[];
    final contains = <String>[];

    for (final o in _allOptions) {
      final en = _norm(o);
      final th = _norm(_th[en] ?? '');
      if (en.startsWith(q) || th.startsWith(q)) {
        starts.add(o);
      } else if (en.contains(q) || th.contains(q)) {
        contains.add(o);
      }
    }

    setState(() => _filtered = [...starts, ...contains]);
  }

  void _clearAll() => setState(() => _selected.clear());

  void _selectAllShown() {
    setState(() {
      for (final o in _filtered) {
        _selected.add(_norm(o));
      }
    });
  }

  Future<void> _saveAndBack() async {
    await AllergyManager.save(_selected);
    if (!mounted) return;
    Navigator.pop(context, _selected);
  }

  @override
  Widget build(BuildContext context) {
    final isThai = widget.appLocale.isThai;
    final selectedKeys = (_selected.toList()..sort());

    return Scaffold(
      backgroundColor: _bg,
      appBar: RefridgeAppBar(
        title: isThai ? 'ตัวกรองการแพ้' : 'Allergies Filter',
        appLocale: widget.appLocale,
        items: const <InventoryItem>[],
      ),
      body: _loading
          ? const Center(child: CircularProgressIndicator())
          : SafeArea(
              child: Column(
                children: [
                  Padding(
                    padding: const EdgeInsets.fromLTRB(16, 12, 16, 10),
                    child: _SearchPill(
                      controller: _searchCtrl,
                      hint: isThai
                          ? 'ค้นหา (เช่น กระเทียม / garlic)'
                          : 'Search (e.g. garlic)',
                      onClear: () {
                        _searchCtrl.clear();
                        FocusScope.of(context).unfocus();
                        _applySearch();
                      },
                      cream: _cream,
                      mint: _mint,
                    ),
                  ),

                  if (selectedKeys.isNotEmpty)
                    Padding(
                      padding: const EdgeInsets.fromLTRB(16, 0, 16, 10),
                      child: Container(
                        padding: const EdgeInsets.all(12),
                        decoration: BoxDecoration(
                          color: _mint.withOpacity(0.55),
                          borderRadius: BorderRadius.circular(18),
                          border: Border.all(color: _basil.withOpacity(0.20)),
                        ),
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Row(
                              children: [
                                Text(
                                  isThai ? 'ที่เลือกไว้' : 'Selected',
                                  style: const TextStyle(fontWeight: FontWeight.w900),
                                ),
                                const Spacer(),
                                InkWell(
                                  onTap: _clearAll,
                                  borderRadius: BorderRadius.circular(12),
                                  child: Padding(
                                    padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
                                    child: Text(
                                      isThai ? 'ล้างทั้งหมด' : 'Clear',
                                      style: TextStyle(
                                        fontWeight: FontWeight.w900,
                                        color: _basil.withOpacity(0.85),
                                      ),
                                    ),
                                  ),
                                ),
                              ],
                            ),
                            const SizedBox(height: 10),
                            Wrap(
                              spacing: 8,
                              runSpacing: 8,
                              children: selectedKeys.map((key) {
                                final en = _enFromKey(key);
                                final label = _displayName(en, isThai);

                                return Chip(
                                  backgroundColor: _cream.withOpacity(0.95),
                                  side: BorderSide(color: _basil.withOpacity(0.15)),
                                  label: Text(
                                    label,
                                    style: const TextStyle(fontWeight: FontWeight.w800),
                                  ),
                                  deleteIcon: Icon(Icons.close, size: 18, color: _basil.withOpacity(0.9)),
                                  onDeleted: () => _toggle(en),
                                );
                              }).toList(),
                            ),
                          ],
                        ),
                      ),
                    ),

                  Padding(
                    padding: const EdgeInsets.fromLTRB(16, 0, 16, 10),
                    child: Row(
                      children: [
                        Expanded(
                          child: _MiniAction(
                            text: isThai ? 'เลือกทั้งหมดที่แสดง' : 'Select all shown',
                            icon: Icons.done_all,
                            onTap: _selectAllShown,
                            bg: _mint.withOpacity(0.55),
                            border: _basil.withOpacity(0.18),
                          ),
                        ),
                        const SizedBox(width: 10),
                        Expanded(
                          child: _MiniAction(
                            text: isThai ? 'ล้างการค้นหา' : 'Clear search',
                            icon: Icons.backspace_outlined,
                            onTap: () {
                              _searchCtrl.clear();
                              FocusScope.of(context).unfocus();
                              _applySearch();
                            },
                            bg: _cream.withOpacity(0.92),
                            border: _basil.withOpacity(0.12),
                          ),
                        ),
                      ],
                    ),
                  ),

                  Expanded(
                    child: ListView.separated(
                      padding: const EdgeInsets.fromLTRB(16, 0, 16, 16),
                      itemCount: _filtered.length,
                      separatorBuilder: (_, __) => const SizedBox(height: 10),
                      itemBuilder: (_, i) {
                        final name = _filtered[i];
                        final key = _norm(name);
                        final checked = _selected.contains(key);

                        return _AllergyTile(
                          title: _displayName(name, isThai),
                          subtitle: name,
                          checked: checked,
                          onTap: () => _toggle(name),
                          mint: _mint,
                          cream: _cream,
                          freshLeaf: _freshLeaf,
                          basil: _basil,
                          index: i,
                        );
                      },
                    ),
                  ),

                  Padding(
                    padding: const EdgeInsets.fromLTRB(16, 0, 16, 16),
                    child: Row(
                      children: [
                        Expanded(
                          child: SizedBox(
                            height: 52,
                            child: OutlinedButton(
                              style: OutlinedButton.styleFrom(
                                foregroundColor: Colors.black,
                                backgroundColor: _cream.withOpacity(0.92),
                                side: BorderSide(color: _basil.withOpacity(0.18)),
                                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(18)),
                              ),
                              onPressed: () => Navigator.pop(context),
                              child: Text(isThai ? 'ยกเลิก' : 'Cancel'),
                            ),
                          ),
                        ),
                        const SizedBox(width: 12),
                        Expanded(
                          child: SizedBox(
                            height: 52,
                            child: ElevatedButton(
                              style: ElevatedButton.styleFrom(
                                backgroundColor: _freshLeaf,
                                foregroundColor: Colors.white,
                                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(18)),
                              ),
                              onPressed: _saveAndBack,
                              child: Text(
                                isThai ? 'บันทึก (${_selected.length})' : 'Save (${_selected.length})',
                                style: const TextStyle(fontWeight: FontWeight.w900),
                              ),
                            ),
                          ),
                        ),
                      ],
                    ),
                  ),
                ],
              ),
            ),
    );
  }
}

class _SearchPill extends StatelessWidget {
  final TextEditingController controller;
  final String hint;
  final VoidCallback onClear;
  final Color cream;
  final Color mint;

  const _SearchPill({
    required this.controller,
    required this.hint,
    required this.onClear,
    required this.cream,
    required this.mint,
  });

  @override
  Widget build(BuildContext context) {
    final hasText = controller.text.trim().isNotEmpty;

    return ClipRRect(
      borderRadius: BorderRadius.circular(18),
      child: BackdropFilter(
        filter: ImageFilter.blur(sigmaX: 10, sigmaY: 10),
        child: Container(
          decoration: BoxDecoration(
            color: cream.withOpacity(0.92),
            borderRadius: BorderRadius.circular(18),
            border: Border.all(color: Colors.black.withOpacity(0.06)),
          ),
          child: TextField(
            controller: controller,
            decoration: InputDecoration(
              hintText: hint,
              border: InputBorder.none,
              contentPadding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
              prefixIcon: const Icon(Icons.search),
              suffixIcon: hasText
                  ? IconButton(
                      icon: const Icon(Icons.close),
                      onPressed: onClear,
                    )
                  : null,
            ),
          ),
        ),
      ),
    );
  }
}

class _MiniAction extends StatelessWidget {
  final String text;
  final IconData icon;
  final VoidCallback onTap;
  final Color bg;
  final Color border;

  const _MiniAction({
    required this.text,
    required this.icon,
    required this.onTap,
    required this.bg,
    required this.border,
  });

  @override
  Widget build(BuildContext context) {
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(16),
      child: Container(
        height: 44,
        padding: const EdgeInsets.symmetric(horizontal: 12),
        decoration: BoxDecoration(
          color: bg,
          borderRadius: BorderRadius.circular(16),
          border: Border.all(color: border),
        ),
        child: Row(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(icon, size: 18),
            const SizedBox(width: 8),
            Flexible(
              child: Text(
                text,
                overflow: TextOverflow.ellipsis,
                style: const TextStyle(fontWeight: FontWeight.w900),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _AllergyTile extends StatelessWidget {
  final String title;
  final String subtitle;
  final bool checked;
  final VoidCallback onTap;
  final Color mint;
  final Color cream;
  final Color freshLeaf;
  final Color basil;
  final int index;

  const _AllergyTile({
    required this.title,
    required this.subtitle,
    required this.checked,
    required this.onTap,
    required this.mint,
    required this.cream,
    required this.freshLeaf,
    required this.basil,
    required this.index,
  });

  @override
  Widget build(BuildContext context) {
    final base = (index % 2 == 0) ? mint.withOpacity(0.50) : cream.withOpacity(0.92);
    final bg = checked ? freshLeaf.withOpacity(0.25) : base;
    final border = checked ? basil.withOpacity(0.45) : basil.withOpacity(0.14);

    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(18),
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 160),
        padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
        decoration: BoxDecoration(
          color: bg,
          borderRadius: BorderRadius.circular(18),
          border: Border.all(color: border),
        ),
        child: Row(
          children: [
            AnimatedContainer(
              duration: const Duration(milliseconds: 160),
              width: 22,
              height: 22,
              decoration: BoxDecoration(
                color: checked ? basil : Colors.transparent,
                borderRadius: BorderRadius.circular(7),
                border: Border.all(color: basil.withOpacity(checked ? 0.0 : 0.25)),
              ),
              child: checked ? const Icon(Icons.check, size: 16, color: Colors.white) : null,
            ),
            const SizedBox(width: 12),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(title, style: const TextStyle(fontSize: 14, fontWeight: FontWeight.w900)),
                  const SizedBox(height: 2),
                  Text(
                    subtitle,
                    style: TextStyle(fontSize: 12, color: Colors.black.withOpacity(0.55)),
                  ),
                ],
              ),
            ),
            const SizedBox(width: 10),
            Icon(
              checked ? Icons.check_circle : Icons.circle_outlined,
              color: checked ? basil : basil.withOpacity(0.45),
            ),
          ],
        ),
      ),
    );
  }
}