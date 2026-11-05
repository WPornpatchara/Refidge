import 'package:flutter/material.dart';
import '../managers/app_locale.dart';

class ErrorEditIngredientsPage extends StatelessWidget {
  final AppLocale appLocale;

  const ErrorEditIngredientsPage({
    super.key,
    required this.appLocale,
  });

  @override
  Widget build(BuildContext context) {
    final isThai = appLocale.isThai;

    return Scaffold(
      backgroundColor: const Color(0xFFF6F2C6),
      body: Column(
        children: [
          _TopFace(color: const Color(0xFFD11A1A), happy: false),
          const SizedBox(height: 30),
          Text(
            isThai ? 'ผิดพลาด!' : 'Error!',
            style: const TextStyle(
              fontSize: 40,
              fontWeight: FontWeight.w800,
              color: Color(0xFFE56B3D),
            ),
          ),
          const SizedBox(height: 12),
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 28),
            child: Text(
              isThai
                  ? 'กรุณาตรวจสอบข้อมูล\nชื่อห้ามว่าง จำนวนต้องมากกว่า 0 และวันหมดอายุต้องไม่ย้อนหลัง'
                  : "Please check your input.\nName can't be empty, expiration date should not be in the past, and quantity/price must be valid.",
              textAlign: TextAlign.center,
              style: const TextStyle(fontSize: 14),
            ),
          ),
          const Spacer(),
          Padding(
            padding: const EdgeInsets.fromLTRB(40, 0, 40, 40),
            child: SizedBox(
              width: double.infinity,
              height: 52,
              child: ElevatedButton(
                style: ElevatedButton.styleFrom(
                  backgroundColor: const Color(0xFFF0B56C),
                  foregroundColor: Colors.black,
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(26),
                  ),
                ),
                onPressed: () => Navigator.pop(context),
                child: Text(
                  isThai ? 'ลองใหม่' : 'Try again',
                  style: const TextStyle(fontWeight: FontWeight.w700),
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class _TopFace extends StatelessWidget {
  final Color color;
  final bool happy;

  const _TopFace({required this.color, required this.happy});

  @override
  Widget build(BuildContext context) {
    return Container(
      height: 250,
      width: double.infinity,
      decoration: BoxDecoration(
        color: color,
        borderRadius: const BorderRadius.only(
          bottomLeft: Radius.elliptical(420, 140),
          bottomRight: Radius.elliptical(420, 140),
        ),
      ),
      child: Center(
        child: CustomPaint(
          size: const Size(180, 120),
          painter: _FacePainter(happy: happy),
        ),
      ),
    );
  }
}

class _FacePainter extends CustomPainter {
  final bool happy;
  _FacePainter({required this.happy});

  @override
  void paint(Canvas canvas, Size size) {
    final p = Paint()..color = Colors.black.withOpacity(0.65);

    canvas.drawCircle(Offset(size.width * 0.40, size.height * 0.35), 6, p);
    canvas.drawCircle(Offset(size.width * 0.60, size.height * 0.35), 6, p);

    final mouthPaint = Paint()
      ..color = Colors.black.withOpacity(0.65)
      ..style = PaintingStyle.stroke
      ..strokeWidth = 10
      ..strokeCap = StrokeCap.round;

    final rect = Rect.fromCenter(
      center: Offset(size.width * 0.50, size.height * 0.68),
      width: 70,
      height: 40,
    );

    if (happy) {
      canvas.drawArc(rect, 0, 3.14, false, mouthPaint);
    } else {
      canvas.drawArc(rect, 3.14, 3.14, false, mouthPaint);
    }
  }

  @override
  bool shouldRepaint(covariant CustomPainter oldDelegate) => false;
}
