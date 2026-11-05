import 'package:flutter/material.dart';
import 'package:url_launcher/url_launcher.dart';

import '../services/meal_api_service.dart';
import '../models/meal.dart';
import '../managers/history_manager.dart';
import '../services/download_storage.dart';
import '../services/translate_service.dart';
import '../l10n/tr.dart';

class RecipeDetailPage extends StatefulWidget {
  final String recipeId;

  const RecipeDetailPage({
    super.key,
    required this.recipeId,
  });

  @override
  State<RecipeDetailPage> createState() => _RecipeDetailPageState();
}

class _RecipeDetailPageState extends State<RecipeDetailPage> {
  late Future<Meal> _mealFuture;

  final _translator = TranslateService();

  bool _isTranslating = false;

  // ✅ แปลเฉพาะ 2 อย่างนี้
  String? _thInstructions;
  List<String>? _thIngredientNames;

  @override
  void initState() {
    super.initState();
    HistoryManager.add(widget.recipeId);
    _mealFuture = _loadMealSmart();
  }

  Future<Meal> _loadMealSmart() async {
    final cached = await DownloadStorage.loadMeal(widget.recipeId);
    if (cached != null) return Meal.fromMap(cached);
    return MealApiService.fetchMealDetail(widget.recipeId);
  }

  // ✅ ตัดข้อความยาวเป็นท่อน ๆ เพื่อกัน 400
  List<String> _chunkText(String text, {int maxChars = 900}) {
    final t = text.trim();
    if (t.isEmpty) return [];

    // แยกเป็นย่อหน้า/บรรทัดก่อน
    final blocks = t
        .split(RegExp(r'\n\s*\n')) // ช่องว่างบรรทัด
        .map((e) => e.trim())
        .where((e) => e.isNotEmpty)
        .toList();

    final out = <String>[];
    for (final b in blocks) {
      if (b.length <= maxChars) {
        out.add(b);
        continue;
      }

      // ถ้าย่อหน้ายาวมาก ตัดเพิ่มด้วยประโยค
      final sentences = b.split(RegExp(r'(?<=[.!?])\s+'));
      var buf = '';
      for (final s in sentences) {
        if (buf.isEmpty) {
          buf = s;
        } else if ((buf.length + 1 + s.length) <= maxChars) {
          buf = '$buf $s';
        } else {
          out.add(buf.trim());
          buf = s;
        }
      }
      if (buf.trim().isNotEmpty) out.add(buf.trim());
    }

    return out;
  }

  Future<String> _translateLongEnglishToThai(String english) async {
    final chunks = _chunkText(english, maxChars: 900);
    if (chunks.isEmpty) return '';

    final translatedChunks = <String>[];
    for (final c in chunks) {
      final th = await _translator.enToTh(c);
      translatedChunks.add(th);
    }

    // ต่อกลับแบบเว้นบรรทัด 1 บรรทัดเหมือนเดิม
    return translatedChunks.join('\n\n');
  }

  Future<void> _translateIfNeeded(Meal meal) async {
    if (!mounted) return;
    if (!Tr.isThai(context)) return;

    // ✅ กันเรียกซ้ำ
    if (_isTranslating) return;
    if (_thInstructions != null && _thIngredientNames != null) return;

    setState(() => _isTranslating = true);

    try {
      // ---------- Translate Instructions (ยาว) ----------
      final thInstr = await _translateLongEnglishToThai(meal.instructions);

      // ---------- Translate Ingredient Names (หลายบรรทัด แต่สั้นกว่า) ----------
      final ingNames = meal.ingredients
          .map((e) => (e['ingredient'] ?? '').toString().trim())
          .where((s) => s.isNotEmpty)
          .toList();

      List<String>? thIngNames;
      if (ingNames.isNotEmpty) {
        final thJoined = await _translator.enToTh(ingNames.join('\n'));
        final lines = thJoined
            .split('\n')
            .map((e) => e.trim())
            .where((e) => e.isNotEmpty)
            .toList();

        // ถ้าจำนวนไม่ตรง → fallback ใช้เดิม
        if (lines.length == ingNames.length) {
          thIngNames = lines;
        }
      }

      if (!mounted) return;
      setState(() {
        _thInstructions = thInstr.isNotEmpty ? thInstr : null;
        _thIngredientNames = thIngNames; // อาจเป็น null ถ้า fallback
        _isTranslating = false;
      });
    } catch (e) {
      if (!mounted) return;
      setState(() => _isTranslating = false);
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('แปลไม่สำเร็จ: $e')),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    final isThai = Tr.isThai(context);

    return Scaffold(
      backgroundColor: const Color(0xFFF6F2E9),
      appBar: AppBar(
        backgroundColor: const Color(0xFFA6C48A),
        elevation: 0,
        leading: IconButton(
          icon: const Icon(Icons.arrow_back, color: Colors.black),
          onPressed: () => Navigator.pop(context),
        ),
        title: Text(Tr.recipe(context), style: const TextStyle(color: Colors.black)),
        actions: [
          if (isThai && _isTranslating)
            const Padding(
              padding: EdgeInsets.only(right: 14),
              child: Center(
                child: SizedBox(
                  width: 16,
                  height: 16,
                  child: CircularProgressIndicator(strokeWidth: 2),
                ),
              ),
            ),
        ],
      ),
      body: FutureBuilder<Meal>(
        future: _mealFuture,
        builder: (context, snapshot) {
          if (snapshot.connectionState == ConnectionState.waiting) {
            return const Center(child: CircularProgressIndicator());
          }

          if (snapshot.hasError || !snapshot.hasData) {
            return Center(child: Text(Tr.loadFail(context)));
          }

          final meal = snapshot.data!;

          // ✅ สำคัญ: อย่าแปลตรง ๆ ใน build ให้เรียกหลังเฟรม
          if (isThai) {
            WidgetsBinding.instance.addPostFrameCallback((_) {
              _translateIfNeeded(meal);
            });
          }

          // ✅ ไม่แปลชื่อเมนู / ไม่แปลประเทศ
          final titleToShow = meal.title;
          final metaToShow = '${meal.category} • ${meal.area}';

          final instrToShow =
              isThai ? (_thInstructions ?? meal.instructions) : meal.instructions;

          final ingNamesOriginal = meal.ingredients
              .map((e) => (e['ingredient'] ?? '').toString().trim())
              .where((s) => s.isNotEmpty)
              .toList();

          final ingNamesToShow =
              (isThai && _thIngredientNames != null) ? _thIngredientNames! : ingNamesOriginal;

          final measures = meal.ingredients
              .map((e) => (e['measure'] ?? '').toString().trim())
              .toList();

          return SingleChildScrollView(
            padding: const EdgeInsets.all(16),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                ClipRRect(
                  borderRadius: BorderRadius.circular(24),
                  child: Image.network(
                    meal.thumbnail,
                    width: double.infinity,
                    height: 220,
                    fit: BoxFit.cover,
                    errorBuilder: (_, __, ___) => Container(
                      height: 220,
                      alignment: Alignment.center,
                      child: const Icon(Icons.fastfood, size: 60),
                    ),
                  ),
                ),
                const SizedBox(height: 16),

                Text(
                  titleToShow,
                  style: const TextStyle(fontSize: 28, fontWeight: FontWeight.bold),
                ),
                const SizedBox(height: 6),
                Text(
                  metaToShow,
                  style: TextStyle(fontSize: 16, color: Colors.black.withOpacity(0.6)),
                ),
                const SizedBox(height: 16),

                Text(
                  Tr.ingredients(context),
                  style: const TextStyle(fontSize: 20, fontWeight: FontWeight.bold),
                ),
                const SizedBox(height: 8),
                for (int i = 0; i < ingNamesToShow.length; i++)
                  Text('• ${ingNamesToShow[i]} - ${i < measures.length ? measures[i] : ''}'),

                const SizedBox(height: 20),

                Text(
                  Tr.instructions(context),
                  style: const TextStyle(fontSize: 20, fontWeight: FontWeight.bold),
                ),
                const SizedBox(height: 8),
                Text(
                  instrToShow,
                  style: const TextStyle(fontSize: 16, height: 1.4),
                ),

                if (meal.tags.isNotEmpty) ...[
                  const SizedBox(height: 20),
                  Text(
                    Tr.tags(context),
                    style: const TextStyle(fontSize: 20, fontWeight: FontWeight.bold),
                  ),
                  const SizedBox(height: 8),
                  Wrap(
                    spacing: 8,
                    children: meal.tags
                        .map((tag) => Chip(
                              label: Text(tag),
                              backgroundColor: const Color(0xFFFFC8A8),
                            ))
                        .toList(),
                  ),
                ],

                if (meal.youtube.isNotEmpty) ...[
                  const SizedBox(height: 24),
                  ElevatedButton.icon(
                    style: ElevatedButton.styleFrom(
                      backgroundColor: Colors.red,
                      foregroundColor: Colors.white,
                      padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 12),
                      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
                    ),
                    onPressed: () async {
                      final uri = Uri.parse(meal.youtube);
                      if (await canLaunchUrl(uri)) {
                        await launchUrl(uri);
                      }
                    },
                    icon: const Icon(Icons.play_arrow),
                    label: Text(Tr.watchYoutube(context)),
                  ),
                ],
              ],
            ),
          );
        },
      ),
    );
  }
}
