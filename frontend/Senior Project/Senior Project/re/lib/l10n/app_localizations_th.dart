// ignore: unused_import
import 'package:intl/intl.dart' as intl;
import 'app_localizations.dart';

// ignore_for_file: type=lint

/// The translations for Thai (`th`).
class AppLocalizationsTh extends AppLocalizations {
  AppLocalizationsTh([String locale = 'th']) : super(locale);

  @override
  String get appTitle => 'Refridge+';

  @override
  String get reminder => 'แจ้งเตือน';

  @override
  String get expiringSoon => 'ใกล้หมดอายุ';

  @override
  String get noIngredients => 'ยังไม่มีวัตถุดิบ เพิ่มจากหน้า Home หรือสแกนใบเสร็จ';

  @override
  String get recommendedMenu => 'เมนูแนะนำ';

  @override
  String get addIngredients => 'เพิ่มวัตถุดิบ';

  @override
  String get inventory => 'คลังวัตถุดิบ';

  @override
  String get ingredients => 'วัตถุดิบ';

  @override
  String get instructions => 'วิธีทำ';

  @override
  String get tags => 'แท็ก';

  @override
  String get watchOnYoutube => 'ดูใน YouTube';
}
