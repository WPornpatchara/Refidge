import 'dart:io';
import 'package:google_mlkit_text_recognition/google_mlkit_text_recognition.dart';

class ReceiptOcrResult {
  final String fullText;
  final List<String> lines;

  ReceiptOcrResult({required this.fullText, required this.lines});
}

class ReceiptOcrService {
  // ✅ ใช้ Latin script เป็นหลัก (Plugin ยังไม่มี enum .thai ให้เลือก)
  static final TextRecognizer _recognizer =
      TextRecognizer(script: TextRecognitionScript.latin);

  static Future<ReceiptOcrResult> scanFromFile(File file) async {
    final input = InputImage.fromFile(file);
    final recognized = await _recognizer.processImage(input);

    final lines = <String>[];
    for (final block in recognized.blocks) {
      for (final line in block.lines) {
        final t = line.text.trim();
        if (t.isNotEmpty) lines.add(t);
      }
    }

    return ReceiptOcrResult(fullText: recognized.text, lines: lines);
  }

  // ✅ เพิ่มฟังก์ชันสำหรับปิด Recognizer ทั้งหมดเมื่อไม่ใช้งาน
  static void dispose() {
    _recognizer.close();
  }
}
