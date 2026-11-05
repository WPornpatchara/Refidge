// ignore: unused_import
import 'package:intl/intl.dart' as intl;
import 'app_localizations.dart';

// ignore_for_file: type=lint

/// The translations for English (`en`).
class AppLocalizationsEn extends AppLocalizations {
  AppLocalizationsEn([String locale = 'en']) : super(locale);

  @override
  String get appTitle => 'Refridge+';

  @override
  String get reminder => 'Reminder';

  @override
  String get expiringSoon => 'Expiring soon';

  @override
  String get noIngredients => 'No ingredients yet. Add from Home or Scan receipt.';

  @override
  String get recommendedMenu => 'Recommended Menu';

  @override
  String get addIngredients => 'Add Ingredients';

  @override
  String get inventory => 'Inventory';

  @override
  String get ingredients => 'Ingredients';

  @override
  String get instructions => 'Instructions';

  @override
  String get tags => 'Tags';

  @override
  String get watchOnYoutube => 'Watch on YouTube';
}
