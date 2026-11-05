import 'package:flutter/material.dart';

class CookingLoading extends StatefulWidget {
  final String text;
  const CookingLoading({super.key, this.text = 'Cooking...'});

  @override
  State<CookingLoading> createState() => _CookingLoadingState();
}

class _CookingLoadingState extends State<CookingLoading>
    with SingleTickerProviderStateMixin {
  late final AnimationController _c =
      AnimationController(vsync: this, duration: const Duration(milliseconds: 900))
        ..repeat();
  late final Animation<double> _scale =
      Tween(begin: 0.9, end: 1.1).animate(
        CurvedAnimation(parent: _c, curve: Curves.easeInOut),
      );

  @override
  void dispose() {
    _c.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Center(
      child: Container(
        padding: const EdgeInsets.all(28),
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(28),
        ),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            ScaleTransition(
              scale: _scale,
              child: const Icon(
                Icons.soup_kitchen,
                size: 64,
                color: Color(0xFF99BC85),
              ),
            ),
            const SizedBox(height: 16),
            Text(
              widget.text,
              style: const TextStyle(fontSize: 16),
            ),
          ],
        ),
      ),
    );
  }
}
