import 'dart:developer' as dev;
import 'package:flutter_local_notifications/flutter_local_notifications.dart';
import 'package:flutter_timezone/flutter_timezone.dart';
import 'package:timezone/data/latest.dart' as tzdata;
import 'package:timezone/timezone.dart' as tz;

import '../models/inventory_item.dart';
import 'notification_prefs.dart';

class NotificationService {
  NotificationService._();
  static final NotificationService I = NotificationService._();

  final FlutterLocalNotificationsPlugin _plugin =
      FlutterLocalNotificationsPlugin();

  static const _channelId   = 'refridge_expire_channel';
  static const _channelName = 'Refridge Expiration Alerts';
  static const _channelDesc = 'Notifications about expiring items';

  // ── init ──────────────────────────────────────────────────

  Future<void> init() async {
    tzdata.initializeTimeZones();
    try {
      final name = await FlutterTimezone.getLocalTimezone();
      tz.setLocalLocation(tz.getLocation(name));
    } catch (_) {
      tz.setLocalLocation(tz.getLocation('Asia/Bangkok'));
    }

    await _plugin.initialize(
      const InitializationSettings(
        android: AndroidInitializationSettings('@mipmap/ic_launcher'),
        iOS:     DarwinInitializationSettings(),
      ),
    );
    await _requestPermissions();
  }

  Future<void> _requestPermissions() async {
    await _plugin
        .resolvePlatformSpecificImplementation<
            AndroidFlutterLocalNotificationsPlugin>()
        ?.requestNotificationsPermission();
    await _plugin
        .resolvePlatformSpecificImplementation<
            IOSFlutterLocalNotificationsPlugin>()
        ?.requestPermissions(alert: true, badge: true, sound: true);
  }

  int _genId() => DateTime.now().microsecondsSinceEpoch & 0x7FFFFFFF;

  NotificationDetails get _details => NotificationDetails(
    android: AndroidNotificationDetails(
      _channelId, _channelName,
      channelDescription: _channelDesc,
      importance: Importance.max,
      priority:   Priority.high,
      playSound:  true,
      enableVibration: true,
    ),
    iOS: const DarwinNotificationDetails(
      presentAlert: true,
      presentBadge: true,
      presentSound: true,
    ),
  );

  // ── one-shot ──────────────────────────────────────────────

  Future<int> scheduleOneShot({
    required String   title,
    required String   body,
    required DateTime dateTimeLocal,
    int?              id,
  }) async {
    final notiId = id ?? _genId();
    await _plugin.zonedSchedule(
      notiId, title, body,
      tz.TZDateTime.from(dateTimeLocal, tz.local),
      _details,
      androidScheduleMode: AndroidScheduleMode.inexactAllowWhileIdle,
      uiLocalNotificationDateInterpretation:
          UILocalNotificationDateInterpretation.absoluteTime,
    );
    return notiId;
  }

  // ── repeat (one-shot หลายอัน) ─────────────────────────────

  Future<List<int>> scheduleRepeat({
    required String   title,
    required String   body,
    required DateTime startAtLocal,
    required int      everyHours,
    DateTime?         endAtLocal,
  }) async {
    final end  = endAtLocal ?? startAtLocal.add(const Duration(days: 7));
    final ids  = <int>[];
    var   fire = startAtLocal;
    while (fire.isBefore(end)) {
      ids.add(await scheduleOneShot(
          title: title, body: body, dateTimeLocal: fire));
      fire = fire.add(Duration(hours: everyHours));
    }
    return ids;
  }

  // ── AUTO SCHEDULE ─────────────────────────────────────────
  //
  // เรียกทุกครั้งที่ app เปิด และทุกครั้งที่ inventory เปลี่ยน
  // cancel ทั้งหมดก่อน แล้ว reschedule ใหม่จาก inventory
  //
  // logic:
  //   - filter items ที่ inFridge และ daysLeft ∈ [0, daysBefore]
  //   - schedule 1 notification ต่อ item ที่เวลา hour:minute
  //   - ถ้าเวลานั้นผ่านแล้วในวันนี้ → เลื่อนไปพรุ่งนี้

  Future<void> scheduleFromInventory(List<InventoryItem> items) async {
    final prefs = await NotificationPrefs.I.load();
    await cancelAll();

    if (!prefs.enabled) {
      dev.log('[Notif] disabled — skipped', name: 'NotificationService');
      return;
    }

    final now   = DateTime.now();
    final today = DateTime(now.year, now.month, now.day);

    int scheduledCount = 0;

    // คำนวณและตั้งเวลาแจ้งเตือนล่วงหน้าสำหรับ 14 วันข้างหน้า
    // เพื่อให้ทำงานได้ต่อเนื่องแม้ผู้ใช้จะไม่ได้เปิดแอปทุกวัน
    for (int i = 0; i <= 14; i++) {
      var fireAt = DateTime(now.year, now.month, now.day, prefs.hour, prefs.minute).add(Duration(days: i));
      
      // ข้ามถ้าเวลาของวันนี้ผ่านไปแล้ว
      if (fireAt.isBefore(now)) continue;

      final targetDay = today.add(Duration(days: i));
      final expiring = <({InventoryItem item, int daysLeft})>[];

      for (final item in items) {
        if (item.effectiveStatus != ItemStatus.inFridge) continue;
        final expDay   = DateTime(
            item.expireDate.year, item.expireDate.month, item.expireDate.day);
        
        // คำนวณวันเหลือ ณ "วันเป้าหมายในอนาคต (targetDay)" เพื่อให้ข้อความตรงกับวันที่แจ้งเตือนจริง
        final daysLeft = expDay.difference(targetDay).inDays;
        
        if (daysLeft < 0 || daysLeft > prefs.daysBefore) continue;
        expiring.add((item: item, daysLeft: daysLeft));
      }

      if (expiring.isEmpty) continue;

      expiring.sort((a, b) => a.daysLeft.compareTo(b.daysLeft));

      String title;
      String body;

      if (expiring.length == 1) {
        final e    = expiring.first;
        final name = e.item.displayName(false);
        title = e.daysLeft <= 0
            ? '$name expires today!'
            : e.daysLeft == 1
                ? '$name expires tomorrow!'
                : '$name expires in ${e.daysLeft} days';
        body  = 'Use it before it goes to waste';
      } else {
        final todayCount    = expiring.where((e) => e.daysLeft <= 0).length;
        final tomorrowCount = expiring.where((e) => e.daysLeft == 1).length;

        if (todayCount > 0) {
          title = '$todayCount item${todayCount > 1 ? "s" : ""} expire today'
              '${expiring.length > todayCount ? " (+${expiring.length - todayCount} more)" : ""}';
        } else if (tomorrowCount > 0) {
          title = '$tomorrowCount item${tomorrowCount > 1 ? "s" : ""} expire tomorrow'
              '${expiring.length > tomorrowCount ? " (+${expiring.length - tomorrowCount} more)" : ""}';
        } else {
          title = '${expiring.length} ingredients expiring soon';
        }

        final preview = expiring.take(4).map((e) {
          final name = e.item.displayName(false);
          final when = e.daysLeft <= 0
              ? 'today'
              : e.daysLeft == 1 ? 'tomorrow' : '${e.daysLeft} days';
          return '$name · $when';
        }).join('\n');

        body = expiring.length > 4
            ? '$preview\n+${expiring.length - 4} more...'
            : preview;
      }

      // Schedule แจ้งเตือนของแต่ละวันแยกกัน (แยก ID)
      await scheduleOneShot(id: 1000 + i, title: title, body: body, dateTimeLocal: fireAt);
      scheduledCount++;
    }

    dev.log('[Notif] scheduled $scheduledCount future notifications',
        name: 'NotificationService');
  }

  // ── cancel ────────────────────────────────────────────────

  Future<void> cancel(int id) => _plugin.cancel(id);
  Future<void> cancelAll()    => _plugin.cancelAll();

  // ── DEBUG ─────────────────────────────────────────────────
  //
  // scheduleDebugTest ใช้ items จริงจาก inventory
  // เพื่อให้ notification เหมือนของจริงทุกอย่าง
  //
  // logic:
  //   1. หา item ที่ inFridge และใกล้หมดอายุที่สุด (daysLeft น้อยสุด)
  //   2. ถ้าไม่มี item ใกล้หมดอายุ → ใช้ item แรกสุดใน inventory
  //   3. ถ้า inventory ว่างเปล่า → ส่ง placeholder
  //   4. ยิงใน afterSeconds วินาที (default 5)

  Future<void> scheduleDebugTest({
    List<InventoryItem> items       = const [],
    int                 afterSeconds = 5,
  }) async {
    final fireAt = DateTime.now().add(Duration(seconds: afterSeconds));
    final now    = DateTime.now();
    final today  = DateTime(now.year, now.month, now.day);

    String title;
    String body;

    // หา item ที่เหมาะสมที่สุดสำหรับ test
    final inFridge = items
        .where((it) => it.effectiveStatus == ItemStatus.inFridge)
        .toList();

    if (inFridge.isEmpty) {
      title = 'Debug: No items in fridge';
      body  = 'Add some ingredients to test real notifications';
    } else {
      // เรียงตาม daysLeft น้อย → มาก
      inFridge.sort((a, b) => a.expireDate.compareTo(b.expireDate));

      // จำลอง scheduleFromInventory logic เลย
      final expiring = inFridge.map((item) {
        final expDay   = DateTime(item.expireDate.year,
            item.expireDate.month, item.expireDate.day);
        final daysLeft = expDay.difference(today).inDays;
        return (item: item, daysLeft: daysLeft);
      }).toList();

      if (expiring.length == 1) {
        final e    = expiring.first;
        final name = e.item.displayName(false);
        title = e.daysLeft <= 0
            ? '$name expires today!'
            : e.daysLeft == 1
                ? '$name expires tomorrow!'
                : '$name expires in ${e.daysLeft} days';
        body  = 'Use it before it goes to waste';
      } else {
        final todayCount    = expiring.where((e) => e.daysLeft <= 0).length;
        final tomorrowCount = expiring.where((e) => e.daysLeft == 1).length;

        if (todayCount > 0) {
          title = '$todayCount item${todayCount > 1 ? "s" : ""} expire today (+${expiring.length - todayCount} more)';
        } else if (tomorrowCount > 0) {
          title = '$tomorrowCount item${tomorrowCount > 1 ? "s" : ""} expire tomorrow (+${expiring.length - tomorrowCount} more)';
        } else {
          title = '${expiring.length} ingredients expiring soon';
        }

        final preview = expiring.take(4).map((e) {
          final name = e.item.displayName(false);
          final when = e.daysLeft <= 0 ? 'today'
              : e.daysLeft == 1 ? 'tomorrow' : '${e.daysLeft} days';
          return '$name · $when';
        }).join('\n');
        body = expiring.length > 4 ? '$preview\n+${expiring.length - 4} more...' : preview;
      }
    }

    // ใช้ _plugin.show ร่วมกับ Future.delayed แทน zonedSchedule สำหรับการทดสอบ
    // เพื่อบังคับให้แจ้งเตือนเด้งทันทีเป๊ะๆ โดยไม่ถูกระบบ OS (Doze mode) ชะลอเวลา
    final id = _genId();
    Future.delayed(Duration(seconds: afterSeconds), () async {
      await _plugin.show(id, title, body, _details);
    });
    
    dev.log('[Notif] debug test will fire in $afterSeconds seconds (id=$id) title="$title"',
        name: 'NotificationService');
  }
}