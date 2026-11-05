import 'package:flutter/material.dart';

class FoodLoading extends StatefulWidget {
  final double size;
  final String? text;

  const FoodLoading({
    super.key,
    this.size = 56,
    this.text,
  });

  @override
  State<FoodLoading> createState() => _FoodLoadingState();
}

class _FoodLoadingState extends State<FoodLoading>
    with SingleTickerProviderStateMixin {
  late final AnimationController _c =
      AnimationController(vsync: this, duration: const Duration(milliseconds: 900))
        ..repeat();
  late final Animation<double> _turn = Tween(begin: 0.0, end: 1.0).animate(
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
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          RotationTransition(
            turns: _turn,
            child: Icon(
              Icons.restaurant_menu,
              size: widget.size,
              color: Colors.black.withOpacity(0.75),
            ),
          ),
          if (widget.text != null) ...[
            const SizedBox(height: 12),
            Text(
              widget.text!,
              style: TextStyle(color: Colors.black.withOpacity(0.7)),
            ),
          ],
        ],
      ),
    );
  }
}
