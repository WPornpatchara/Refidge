import 'package:flutter/material.dart';
import 'package:flutter_localizations/flutter_localizations.dart';

import 'pages/root_page.dart';
import 'managers/app_locale.dart';
import 'services/notification_service.dart';
import 'services/notification_prefs.dart';
import 'services/api_service.dart';

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();

  await NotificationService.I.init();

  // ── Auto schedule ตอน app เปิด ───────────────────────────
  // โหลด inventory แล้ว reschedule notification ทันที
  // ถ้า fetch ไม่ได้ (offline) ก็ไม่ crash แค่ skip
  try {
    final items = await ApiService.fetchInventory();
    await NotificationService.I.scheduleFromInventory(items);
  } catch (_) {
    // offline หรือ backend ไม่ตอบ → ข้ามได้ จะ reschedule ตอน inventory refresh
  }

  runApp(const MyApp());
}

class MyApp extends StatefulWidget {
  const MyApp({super.key});

  @override
  State<MyApp> createState() => _MyAppState();
}

class _MyAppState extends State<MyApp> {
  final appLocale = AppLocale();

  @override
  Widget build(BuildContext context) {
    return AnimatedBuilder(
      animation: appLocale,
      builder: (context, _) {
        return MaterialApp(
          debugShowCheckedModeBanner: false,
          locale:             appLocale.locale,
          supportedLocales:   const [Locale('en'), Locale('th')],
          localizationsDelegates: const [
            GlobalMaterialLocalizations.delegate,
            GlobalWidgetsLocalizations.delegate,
            GlobalCupertinoLocalizations.delegate,
          ],
          home: RootPage(appLocale: appLocale),
        );
      },
    );
  }
}