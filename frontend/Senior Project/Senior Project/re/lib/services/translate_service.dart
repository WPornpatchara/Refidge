import 'dart:convert';
import 'package:http/http.dart' as http;

class TranslateService {
  static final Map<String, String> _cache = {};

  Future<String> enToTh(String text) async {
    if (text.trim().isEmpty) return text;
    if (_cache.containsKey(text)) return _cache[text]!;

    final uri = Uri.parse(
      'https://translate.googleapis.com/translate_a/single'
      '?client=gtx'
      '&sl=en'
      '&tl=th'
      '&dt=t'
      '&q=${Uri.encodeComponent(text)}',
    );

    final res = await http.get(uri);
    if (res.statusCode != 200) {
      throw Exception('Translate failed');
    }

    final body = jsonDecode(res.body);
    final translated = (body[0] as List)
        .map((e) => e[0] as String)
        .join('');

    _cache[text] = translated;
    return translated;
  }
}

