import 'package:flutter/material.dart';

class AppLocale extends ChangeNotifier {
  Locale _locale = const Locale('en');

  Locale get locale => _locale;

  bool get isThai => _locale.languageCode == 'th';

  void setThai() {
    _locale = const Locale('th');
    notifyListeners();
  }

  void setEnglish() {
    _locale = const Locale('en');
    notifyListeners();
  }

  void toggle() => isThai ? setEnglish() : setThai();
}
