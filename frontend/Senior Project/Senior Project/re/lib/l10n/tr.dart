import 'package:flutter/material.dart';

class Tr {
  static bool isThai(BuildContext context) =>
      Localizations.localeOf(context).languageCode == 'th';

  static String recipe(BuildContext c) => isThai(c) ? 'สูตรอาหาร' : 'Recipe';
  static String ingredients(BuildContext c) => isThai(c) ? 'วัตถุดิบ' : 'Ingredients';
  static String instructions(BuildContext c) => isThai(c) ? 'วิธีทำ' : 'Instructions';
  static String tags(BuildContext c) => isThai(c) ? 'แท็ก' : 'Tags';
  static String watchYoutube(BuildContext c) => isThai(c) ? 'ดูใน YouTube' : 'Watch on YouTube';
  static String loadFail(BuildContext c) => isThai(c) ? 'โหลดสูตรไม่สำเร็จ' : 'Failed to load recipe';
}
