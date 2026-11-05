import 'dart:math';
import 'dart:ui';
import 'package:flutter/material.dart';
import 'package:re/pages/profile_page.dart';
import '../services/meal_api_service.dart';
import '../models/meal.dart';
import '../pages/recipe_detail_page.dart';
import '../widgets/refridge_app_bar.dart';
import '../managers/allergy_manager.dart';
import '../managers/favorite_manager.dart';
import 'allergies_filter_page.dart';
import '../widgets/food_loading.dart';
import '../managers/app_locale.dart';

class SearchPage extends StatefulWidget {
  final AppLocale appLocale;

  const SearchPage({
    super.key,
    required this.appLocale,
  });

  @override
  State<SearchPage> createState() => _SearchPageState();
}

class _SearchPageState extends State<SearchPage> {
  final _searchCtrl = TextEditingController();

  bool _loading = true;
  List<Meal> _allMeals = [];
  List<Meal> _filtered = [];
  Set<String> _allergies = {};

  String _searchHint = '';
  bool? _hintWasThai;

  static const List<String> _hintsEn = [
    "What should I eat today?",
    "What can I cook today?",
    "Any quick snack ideas?",
    "What’s for lunch today?",
    "What’s for dinner tonight?",
    "Surprise me with a recipe!",
    "Feeling hungry... what should I make?",
    "Something easy to cook today?",
  ];

  static const List<String> _hintsTh = [
    "วันนี้กินอะไรดี?",
    "วันนี้ทำอะไรกินดี?",
    "มีเมนูง่าย ๆ ไหม?",
    "มื้อเที่ยงกินอะไรดี?",
    "เย็นนี้กินอะไรดี?",
    "สุ่มเมนูให้หน่อย!",
    "หิวแล้ว ทำอะไรกินดี?",
    "อยากได้เมนูทำง่าย ๆ",
  ];

  @override
  void initState() {
    super.initState();
    _searchCtrl.addListener(() {
      setState(() {});
      _applyFilter();
    });
    _init();
  }

  @override
  void dispose() {
    _searchCtrl.dispose();
    super.dispose();
  }

  void _ensureHintMatchesLocale() {
    final isThai = widget.appLocale.isThai;
    if (_hintWasThai == isThai && _searchHint.isNotEmpty) return;
    final list = isThai ? _hintsTh : _hintsEn;
    _searchHint = (list.toList()..shuffle()).first;
    _hintWasThai = isThai;
  }

  String _norm(String s) => s.toLowerCase().trim();

  Future<void> _init() async {
    _allergies = (await AllergyManager.load())
        .map(_norm)
        .where((e) => e.isNotEmpty)
        .toSet();

    final meals = await MealApiService.fetchAllMeals();
    if (!mounted) return;

    setState(() {
      _allMeals = meals;
      _loading = false;
    });

    _applyFilter();
  }

  String _buildSearchBlob(Meal m) {
    final tags = m.tags.join(' ');
    return '${m.title} ${m.area} ${m.category} $tags'.toLowerCase();
  }

  bool _hasAllergy(Meal m) {
    if (_allergies.isEmpty) return false;

    final ingredients = m.ingredients
        .map((e) => (e['ingredient'] ?? '').toString())
        .map(_norm)
        .where((s) => s.isNotEmpty)
        .toList();

    for (final ing in ingredients) {
      for (final a in _allergies) {
        if (ing == a || ing.contains(a)) return true;
      }
    }
    return false;
  }

  void _applyFilter() {
    final q = _norm(_searchCtrl.text);

    final next = _allMeals.where((m) {
      final okSearch = q.isEmpty || _buildSearchBlob(m).contains(q);
      final banned = _hasAllergy(m);
      return okSearch && !banned;
    }).toList();

    setState(() => _filtered = next);
  }

  void _clearSearch() {
    _searchCtrl.clear();
    FocusScope.of(context).unfocus();
    _applyFilter();
  }

  Future<void> _openFilter() async {
    final result = await showGeneralDialog<Set<String>>(
      context: context,
      barrierDismissible: true,
      barrierLabel: 'Filter',
      transitionDuration: const Duration(milliseconds: 280),
      pageBuilder: (_, __, ___) => const SizedBox(),
      transitionBuilder: (context, animation, __, ___) {
        final curved = CurvedAnimation(parent: animation, curve: Curves.easeOutCubic);

        return Stack(
          children: [
            FadeTransition(
              opacity: curved,
              child: BackdropFilter(
                filter: ImageFilter.blur(sigmaX: 12, sigmaY: 12),
                child: Container(color: Colors.black.withOpacity(0.15)),
              ),
            ),
            Align(
              alignment: Alignment.bottomCenter,
              child: SlideTransition(
                position: Tween<Offset>(
                  begin: const Offset(0, 1),
                  end: Offset.zero,
                ).animate(curved),
                child: Container(
                  height: MediaQuery.of(context).size.height * 0.88,
                  decoration: const BoxDecoration(
                    color: Color(0xFFFFF2C6),
                    borderRadius: BorderRadius.vertical(top: Radius.circular(28)),
                  ),
                  child: AllergiesFilterPage(appLocale: widget.appLocale),
                ),
              ),
            ),
          ],
        );
      },
    );

    if (result != null) {
      final normalized = result.map(_norm).where((e) => e.isNotEmpty).toSet();
      setState(() => _allergies = normalized);
      await AllergyManager.save(_allergies);
      _applyFilter();
    }
  }

  Future<void> _removeAllergy(String a) async {
    setState(() => _allergies.remove(a));
    await AllergyManager.save(_allergies);
    _applyFilter();
  }

  Future<void> _clearAllAllergies() async {
    setState(() => _allergies.clear());
    await AllergyManager.save(_allergies);
    _applyFilter();
  }

  void _goProfile(BuildContext context) {
    Navigator.of(context).push(
      PageRouteBuilder(
        pageBuilder: (_, __, ___) => ProfilePage(appLocale: widget.appLocale),
        transitionDuration: const Duration(milliseconds: 220),
        reverseTransitionDuration: const Duration(milliseconds: 200),
        transitionsBuilder: (_, animation, __, child) {
          return FadeTransition(
            opacity: CurvedAnimation(parent: animation, curve: Curves.easeOut),
            child: child,
          );
        },
      ),
    );
  }

  Widget _whiteCircleCloseIcon() {
    return Container(
      decoration: const BoxDecoration(color: Colors.white, shape: BoxShape.circle),
      padding: const EdgeInsets.all(2),
      child: const Icon(Icons.close, size: 16, color: Colors.black),
    );
  }

  @override
  Widget build(BuildContext context) {
    _ensureHintMatchesLocale();
    final isThai = widget.appLocale.isThai;
    final q = _searchCtrl.text.trim();
    final sortedAllergies = (_allergies.toList()..sort());

    return Scaffold(
      backgroundColor: const Color(0xFFFFF2C6),
      appBar: RefridgeAppBar(
        title: isThai ? 'ค้นหา' : 'Search',
        items: const [],
        onProfileTap: () => _goProfile(context),
        appLocale: widget.appLocale,
      ),
      body: _loading
          ? FoodLoading(text: isThai ? 'กำลังค้นหาเมนู...' : 'Searching recipes...')
          : ListView(
              padding: const EdgeInsets.all(16),
              children: [
                Row(
                  children: [
                    Expanded(
                      child: Container(
                        padding: const EdgeInsets.symmetric(horizontal: 12),
                        decoration: BoxDecoration(
                          color: Colors.white,
                          borderRadius: BorderRadius.circular(18),
                        ),
                        child: TextField(
                          controller: _searchCtrl,
                          decoration: InputDecoration(
                            hintText: _searchHint,
                            border: InputBorder.none,
                            suffixIcon: q.isEmpty
                                ? null
                                : IconButton(
                                    icon: const Icon(Icons.close),
                                    onPressed: _clearSearch,
                                  ),
                          ),
                        ),
                      ),
                    ),
                    const SizedBox(width: 10),
                    InkWell(
                      onTap: _openFilter,
                      borderRadius: BorderRadius.circular(14),
                      child: Container(
                        padding: const EdgeInsets.all(10),
                        decoration: BoxDecoration(
                          color: const Color(0xFFFFF2C6),
                          borderRadius: BorderRadius.circular(14),
                        ),
                        child: const Icon(Icons.tune),
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 10),
                if (q.isNotEmpty || _allergies.isNotEmpty)
                  Wrap(
                    spacing: 8,
                    runSpacing: 8,
                    children: [
                      if (q.isNotEmpty)
                        Chip(
                          backgroundColor: const Color(0xFF99BC85),
                          label: Text(
                            isThai ? 'ค้นหา: "$q"' : 'Search: "$q"',
                            style: const TextStyle(color: Colors.white),
                          ),
                          deleteIcon: _whiteCircleCloseIcon(),
                          onDeleted: _clearSearch,
                        ),
                      ...sortedAllergies.map(
                        (a) => Chip(
                          backgroundColor: const Color(0xFF99BC85),
                          label: Text(
                            isThai ? 'ไม่เอา: $a' : 'No: $a',
                            style: const TextStyle(color: Colors.white),
                          ),
                          deleteIcon: _whiteCircleCloseIcon(),
                          onDeleted: () => _removeAllergy(a),
                        ),
                      ),
                      if (_allergies.isNotEmpty)
                        ActionChip(
                          backgroundColor: const Color(0xFF99BC85),
                          label: Text(
                            isThai ? 'ล้างตัวกรอง' : 'Clear filters',
                            style: const TextStyle(color: Colors.white),
                          ),
                          onPressed: _clearAllAllergies,
                        ),
                    ],
                  ),
                const SizedBox(height: 12),
                if (_filtered.isEmpty)
                  Padding(
                    padding: const EdgeInsets.only(top: 90),
                    child: Center(child: Text(isThai ? 'ไม่พบเมนู' : 'No results')),
                  )
                else
                  ..._filtered.map((m) {
                    return _SearchMealCard(meal: m, isThai: isThai);
                  }),
              ],
            ),
    );
  }
}

class _SearchMealCard extends StatelessWidget {
  final Meal meal;
  final bool isThai;

  const _SearchMealCard({
    required this.meal,
    required this.isThai,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      margin: const EdgeInsets.only(bottom: 14),
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: const Color(0xFFFFC8A8),
        borderRadius: BorderRadius.circular(20),
      ),
      child: Row(
        children: [
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  meal.title,
                  style: const TextStyle(fontSize: 22, fontWeight: FontWeight.w800),
                ),
                const SizedBox(height: 6),
                Text(
                  '${meal.category} • ${meal.area}',
                  style: TextStyle(color: Colors.black.withOpacity(0.6)),
                ),
                const SizedBox(height: 12),
                Row(
                  children: [
                    ElevatedButton(
                      style: ElevatedButton.styleFrom(
                        backgroundColor: Colors.black,
                        foregroundColor: Colors.white,
                        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(18)),
                      ),
                      onPressed: () {
                        Navigator.push(
                          context,
                          MaterialPageRoute(builder: (_) => RecipeDetailPage(recipeId: meal.id)),
                        );
                      },
                      child: Row(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          Text(isThai ? 'สูตรอาหาร' : 'Recipe'),
                          const SizedBox(width: 6),
                          const Icon(Icons.search, size: 16),
                        ],
                      ),
                    ),
                    const SizedBox(width: 12),
                    ValueListenableBuilder<List<String>>(
                      valueListenable: FavoriteManager.favorites,
                      builder: (_, favList, __) {
                        final isFav = favList.contains(meal.id);
                        return TikTokLikeButton(
                          isLiked: isFav,
                          onToggle: () => FavoriteManager.toggleFavorite(meal.id),
                        );
                      },
                    ),
                  ],
                ),
              ],
            ),
          ),
          const SizedBox(width: 12),
          ClipRRect(
            borderRadius: BorderRadius.circular(16),
            child: Image.network(
              meal.thumbnail,
              width: 92,
              height: 92,
              fit: BoxFit.cover,
              errorBuilder: (_, __, ___) => const Icon(Icons.fastfood, size: 40),
            ),
          ),
        ],
      ),
    );
  }
}

class TikTokLikeButton extends StatefulWidget {
  final bool isLiked;
  final VoidCallback onToggle;

  const TikTokLikeButton({
    super.key,
    required this.isLiked,
    required this.onToggle,
  });

  @override
  State<TikTokLikeButton> createState() => _TikTokLikeButtonState();
}

class _TikTokLikeButtonState extends State<TikTokLikeButton> with TickerProviderStateMixin {
  late final AnimationController _pop = AnimationController(
    vsync: this,
    duration: const Duration(milliseconds: 200),
  );

  late final AnimationController _burst = AnimationController(
    vsync: this,
    duration: const Duration(milliseconds: 320),
  );

  late final AnimationController _break = AnimationController(
    vsync: this,
    duration: const Duration(milliseconds: 620),
  );

  bool _showBreak = false;
  bool _tapping = false;

  late final Animation<double> _popScale = Tween<double>(begin: 1.0, end: 1.22).animate(
    CurvedAnimation(parent: _pop, curve: Curves.easeOutBack),
  );

  @override
  void dispose() {
    _pop.dispose();
    _burst.dispose();
    _break.dispose();
    super.dispose();
  }

  Future<void> _tap() async {
    if (_tapping) return;
    _tapping = true;

    final wasLiked = widget.isLiked;

    if (!wasLiked) {
      _pop.forward(from: 0);
      _burst.forward(from: 0);
      widget.onToggle();
    } else {
      setState(() => _showBreak = true);
      _break.forward(from: 0);
      widget.onToggle();

      await Future.delayed(const Duration(milliseconds: 620));
      if (mounted) {
        setState(() => _showBreak = false);
        _break.reset();
      }
    }

    await Future.delayed(const Duration(milliseconds: 90));
    _tapping = false;
  }

  @override
  Widget build(BuildContext context) {
    return RepaintBoundary(
      child: GestureDetector(
        onTap: _tap,
        child: SizedBox(
          width: 46,
          height: 46,
          child: Stack(
            alignment: Alignment.center,
            children: [
              IgnorePointer(
                child: AnimatedBuilder(
                  animation: _burst,
                  builder: (_, __) => CustomPaint(
                    painter: _BurstPainter(_burst.value),
                    size: const Size(46, 46),
                    isComplex: false,
                    willChange: true,
                  ),
                ),
              ),
              IgnorePointer(
                child: AnimatedBuilder(
                  animation: _break,
                  builder: (_, __) {
                    if (!_showBreak) return const SizedBox.shrink();

                    final v = _break.value;
                    final crackT = (v / 0.45).clamp(0.0, 1.0);
                    final splitT = ((v - 0.45) / 0.55).clamp(0.0, 1.0);

                    final crackEase = Curves.easeOutCubic.transform(crackT);
                    final splitEase = Curves.easeOutQuint.transform(splitT);

                    final shake = sin(crackEase * pi * 8) * (1.2 * (1 - crackEase));
                    final fade = (1 - splitEase).clamp(0.0, 1.0);
                    final dx = 14 * splitEase;

                    return Opacity(
                      opacity: fade,
                      child: Transform.translate(
                        offset: Offset(shake, 0),
                        child: Transform.scale(
                          scale: 1.12,
                          child: Stack(
                            alignment: Alignment.center,
                            children: [
                              Transform.translate(
                                offset: Offset(-dx, 0),
                                child: ClipRect(
                                  child: Align(
                                    alignment: Alignment.centerLeft,
                                    widthFactor: 0.5,
                                    child: const Icon(
                                      Icons.favorite,
                                      size: 28,
                                      color: Colors.redAccent,
                                    ),
                                  ),
                                ),
                              ),
                              Transform.translate(
                                offset: Offset(dx, 0),
                                child: ClipRect(
                                  child: Align(
                                    alignment: Alignment.centerRight,
                                    widthFactor: 0.5,
                                    child: const Icon(
                                      Icons.favorite,
                                      size: 28,
                                      color: Colors.redAccent,
                                    ),
                                  ),
                                ),
                              ),
                              CustomPaint(
                                painter: _CrackLinePainter(alpha: fade, strength: crackEase),
                                size: const Size(46, 46),
                                isComplex: false,
                                willChange: true,
                              ),
                            ],
                          ),
                        ),
                      ),
                    );
                  },
                ),
              ),
              AnimatedBuilder(
                animation: _popScale,
                builder: (_, __) {
                  return Opacity(
                    opacity: _showBreak ? 0 : 1,
                    child: Transform.scale(
                      scale: widget.isLiked ? _popScale.value : 1.0,
                      child: Icon(
                        widget.isLiked ? Icons.favorite : Icons.favorite_border,
                        size: 26,
                        color: widget.isLiked ? Colors.redAccent : Colors.black,
                      ),
                    ),
                  );
                },
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _BurstPainter extends CustomPainter {
  final double progress;
  _BurstPainter(this.progress);

  @override
  void paint(Canvas canvas, Size size) {
    if (progress <= 0) return;

    final t = Curves.easeOut.transform(progress);
    final center = Offset(size.width / 2, size.height / 2);
    final radius = 18 * t;
    final alpha = (1 - t).clamp(0.0, 1.0);

    final p = Paint()..color = Colors.redAccent.withOpacity(0.85 * alpha);

    for (int i = 0; i < 6; i++) {
      final a = (pi * 2 / 6) * i;
      final pos = Offset(center.dx + cos(a) * radius, center.dy + sin(a) * radius);
      canvas.drawCircle(pos, 3.2, p);
    }
  }

  @override
  bool shouldRepaint(covariant _BurstPainter oldDelegate) => oldDelegate.progress != progress;
}

class _CrackLinePainter extends CustomPainter {
  final double alpha;
  final double strength;

  _CrackLinePainter({
    required this.alpha,
    required this.strength,
  });

  @override
  void paint(Canvas canvas, Size size) {
    if (alpha <= 0) return;

    final c = Offset(size.width / 2, size.height / 2);

    final p = Paint()
      ..color = Colors.black.withOpacity(0.75 * alpha)
      ..strokeWidth = 2.0
      ..style = PaintingStyle.stroke
      ..strokeCap = StrokeCap.round;

    final topY = lerpDouble(c.dy - 4, c.dy - 9, strength)!;
    final botY = lerpDouble(c.dy + 4, c.dy + 9, strength)!;

    final path = Path()
      ..moveTo(c.dx - 0.8, topY)
      ..lineTo(c.dx + 2.6, c.dy - 1.2)
      ..lineTo(c.dx - 3.0, c.dy + 1.8)
      ..lineTo(c.dx + 2.0, botY);

    canvas.drawPath(path, p);
  }

  @override
  bool shouldRepaint(covariant _CrackLinePainter oldDelegate) =>
      oldDelegate.alpha != alpha || oldDelegate.strength != strength;
}