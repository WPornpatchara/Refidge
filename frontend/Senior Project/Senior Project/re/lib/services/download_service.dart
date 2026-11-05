import 'dart:io';
import 'package:path/path.dart' as p;
import 'package:path_provider/path_provider.dart';

class DownloadService {
  /// ดาวน์โหลดรูปแล้วคืน path ไฟล์ในเครื่อง
  /// onProgress ส่งค่า 0.0 - 1.0
  static Future<String> downloadImage(
    String url, {
    required void Function(double progress) onProgress,
  }) async {
    final client = HttpClient();
    final req = await client.getUrl(Uri.parse(url));
    final res = await req.close();

    if (res.statusCode != 200) {
      throw HttpException('Failed to download. status=${res.statusCode}');
    }

    final total = res.contentLength; // -1 ถ้าไม่รู้ขนาด
    int received = 0;

    final dir = await getApplicationDocumentsDirectory();
    final fileName = 'thumb_${DateTime.now().millisecondsSinceEpoch}.jpg';
    final file = File(p.join(dir.path, fileName));
    final sink = file.openWrite();

    await for (final chunk in res) {
      received += chunk.length;
      sink.add(chunk);

      if (total > 0) {
        onProgress(received / total);
      } else {
        // ถ้าไม่รู้ขนาดไฟล์ ให้ไต่ขึ้นแบบเนียนๆ
        onProgress((received / (received + 500000)).clamp(0.0, 0.98));
      }
    }

    await sink.flush();
    await sink.close();
    client.close();

    onProgress(1.0);
    return file.path;
  }
}
