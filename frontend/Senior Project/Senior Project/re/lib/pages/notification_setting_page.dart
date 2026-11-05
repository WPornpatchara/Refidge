import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import '../managers/app_locale.dart';
import '../models/inventory_item.dart';
import '../services/notification_service.dart';
import '../services/notification_prefs.dart';

class NotificationSettingsPage extends StatefulWidget {
  final AppLocale          appLocale;
  final List<InventoryItem> items;

  const NotificationSettingsPage({
    super.key,
    required this.appLocale,
    required this.items,
  });

  @override
  State<NotificationSettingsPage> createState() =>
      _NotificationSettingsPageState();
}

class _NotificationSettingsPageState extends State<NotificationSettingsPage> {

  // ── palette ──────────────────────────────────────────────
  static const _bg    = Color(0xFFF6F2C6);
  static const _peach = Color(0xFFFFC8A8);
  static const _green = Color(0xFF3D7A56);
  static const _red   = Color(0xFFC0392B);
  static const _dark  = Color(0xFF2C1A0E);
  static const _amber = Color(0xFFC68B3C);

  // ── state ─────────────────────────────────────────────────
  bool _loading      = true;
  bool _enabled      = true;
  int  _daysBefore   = NotificationPrefs.defaultDaysBefore;
  int  _hour         = NotificationPrefs.defaultHour;
  int  _minute       = NotificationPrefs.defaultMinute;
  bool _saving       = false;

  // DEBUG
  bool    _debugLoading = false;
  String? _debugStatus;

  @override
  void initState() {
    super.initState();
    _loadPrefs();
  }

  Future<void> _loadPrefs() async {
    final p = await NotificationPrefs.I.load();
    if (mounted) setState(() {
      _enabled    = p.enabled;
      _daysBefore = p.daysBefore;
      _hour       = p.hour;
      _minute     = p.minute;
      _loading    = false;
    });
  }

  // ── save & reschedule ─────────────────────────────────────

  Future<void> _save() async {
    setState(() => _saving = true);
    await NotificationPrefs.I.setEnabled(_enabled);
    await NotificationPrefs.I.setDaysBefore(_daysBefore);
    await NotificationPrefs.I.setHour(_hour);
    await NotificationPrefs.I.setMinute(_minute);

    // reschedule ทันทีหลัง save
    await NotificationService.I.scheduleFromInventory(widget.items);

    if (mounted) {
      setState(() => _saving = false);
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(
        content: Text(widget.appLocale.isThai
            ? 'บันทึกแล้ว ✓' : 'Saved ✓'),
        backgroundColor: _green,
        behavior: SnackBarBehavior.floating,
        duration: const Duration(seconds: 2),
      ));
    }
  }

  Future<void> _pickTime() async {
    final picked = await showTimePicker(
      context:     context,
      initialTime: TimeOfDay(hour: _hour, minute: _minute),
    );
    if (picked != null) {
      setState(() { _hour = picked.hour; _minute = picked.minute; });
    }
  }

  // ── debug ─────────────────────────────────────────────────

  Future<void> _runDebugTest() async {
    setState(() { _debugLoading = true; _debugStatus = null; });
    try {
      await NotificationService.I.scheduleDebugTest(
        items:        widget.items,
        afterSeconds: 5,
      );
      // แสดงชื่อ item ที่จะโดน notify จริงๆ
      final now    = DateTime.now();
      final today  = DateTime(now.year, now.month, now.day);
      final inFridge = widget.items
          .where((it) => it.effectiveStatus == ItemStatus.inFridge)
          .toList()
        ..sort((a, b) => a.expireDate.compareTo(b.expireDate));
      final preview = inFridge.isEmpty
          ? 'No items in fridge'
          : () {
              final item     = inFridge.first;
              final expDay   = DateTime(item.expireDate.year,
                  item.expireDate.month, item.expireDate.day);
              final daysLeft = expDay.difference(today).inDays;
              final name     = item.displayName(widget.appLocale.isThai);
              return daysLeft <= 0
                  ? '$name (expired)'
                  : '$name ($daysLeft days left)';
            }();
      setState(() =>
          _debugStatus = '✓ Fires in 5s → "$preview"');
    } catch (e) {
      setState(() => _debugStatus = '✗ $e');
    } finally {
      setState(() => _debugLoading = false);
    }
  }

  // ── helpers ───────────────────────────────────────────────

  String _fmtTime() {
    final h = _hour.toString().padLeft(2, '0');
    final m = _minute.toString().padLeft(2, '0');
    return '$h:$m';
  }

  // ── upcoming notifications preview ───────────────────────
  // แสดงรายชื่อ item ที่จะได้รับ notification ตาม settings ปัจจุบัน

  List<InventoryItem> _upcomingItems() {
    final now   = DateTime.now();
    final today = DateTime(now.year, now.month, now.day);
    return widget.items.where((it) {
      if (it.effectiveStatus != ItemStatus.inFridge) return false;
      final exp      = DateTime(it.expireDate.year, it.expireDate.month,
          it.expireDate.day);
      final daysLeft = exp.difference(today).inDays;
      return daysLeft >= 0 && daysLeft <= _daysBefore;
    }).toList()
      ..sort((a, b) => a.expireDate.compareTo(b.expireDate));
  }

  // ── build ─────────────────────────────────────────────────

  @override
  Widget build(BuildContext context) {
    final isThai = widget.appLocale.isThai;

    if (_loading) {
      return Scaffold(
        backgroundColor: _bg,
        body: const Center(child: CircularProgressIndicator()),
      );
    }

    final upcoming = _upcomingItems();

    return Scaffold(
      backgroundColor: _bg,
      appBar: AppBar(
        backgroundColor: const Color(0xFFA6C48A),
        elevation: 0,
        leading: IconButton(
          icon: const Icon(Icons.arrow_back, color: Colors.black),
          onPressed: () => Navigator.of(context).pop(),
        ),
        title: Text(
          isThai ? 'การแจ้งเตือน' : 'Notifications',
          style: const TextStyle(color: Colors.black, fontSize: 16,
              fontWeight: FontWeight.w700),
        ),
      ),
      body: ListView(
        padding: const EdgeInsets.fromLTRB(16, 20, 16, 32),
        children: [

          // ── DEBUG panel ──────────────────────────────────
          if (kDebugMode) ...[
            _debugPanel(),
            const SizedBox(height: 16),
          ],

          // ── 1. Master toggle ─────────────────────────────
          _card(child: Row(children: [
            Icon(Icons.notifications_outlined,
                color: _enabled ? _green : _dark.withOpacity(0.35), size: 28),
            const SizedBox(width: 14),
            Expanded(child: Column(
                crossAxisAlignment: CrossAxisAlignment.start, children: [
              Text(isThai ? 'เปิดการแจ้งเตือน' : 'Enable notifications',
                  style: const TextStyle(
                      fontSize: 15, fontWeight: FontWeight.w900)),
              Text(
                isThai
                    ? 'แจ้งเตือนเมื่อวัตถุดิบใกล้หมดอายุ'
                    : 'Alert when ingredients are about to expire',
                style: TextStyle(fontSize: 12,
                    color: _dark.withOpacity(0.5))),
            ])),
            Switch(
              value:            _enabled,
              onChanged:        (v) => setState(() => _enabled = v),
              activeColor:      _green,
            ),
          ])),

          const SizedBox(height: 12),

          // ── 2. Days before ───────────────────────────────
          _card(child: Column(
              crossAxisAlignment: CrossAxisAlignment.start, children: [
            Row(children: [
              Icon(Icons.calendar_today_outlined,
                  color: _enabled ? _amber : _dark.withOpacity(0.3), size: 20),
              const SizedBox(width: 10),
              Text(isThai ? 'แจ้งเตือนล่วงหน้า' : 'Alert before expiry',
                  style: const TextStyle(
                      fontSize: 15, fontWeight: FontWeight.w900)),
              const Spacer(),
              // value badge
              Container(
                padding: const EdgeInsets.symmetric(
                    horizontal: 12, vertical: 4),
                decoration: BoxDecoration(
                  color: _enabled
                      ? _amber.withOpacity(0.15)
                      : _dark.withOpacity(0.06),
                  borderRadius: BorderRadius.circular(999),
                ),
                child: Text(
                  isThai ? '$_daysBefore วัน' : '$_daysBefore days',
                  style: TextStyle(
                    fontSize: 13,
                    fontWeight: FontWeight.w900,
                    color: _enabled ? _amber : _dark.withOpacity(0.3),
                  ),
                ),
              ),
            ]),
            const SizedBox(height: 12),
            SliderTheme(
              data: SliderTheme.of(context).copyWith(
                activeTrackColor:   _enabled ? _amber : _dark.withOpacity(0.2),
                inactiveTrackColor: _dark.withOpacity(0.1),
                thumbColor:         _enabled ? _amber : _dark.withOpacity(0.3),
                overlayColor:       _amber.withOpacity(0.15),
                trackHeight:        4,
              ),
              child: Slider(
                value:    _daysBefore.toDouble(),
                min:      1,
                max:      14,
                divisions: 13,
                onChanged: _enabled
                    ? (v) => setState(() => _daysBefore = v.round())
                    : null,
              ),
            ),
            Row(children: [
              Text(isThai ? '1 วัน' : '1 day',
                  style: TextStyle(fontSize: 10,
                      color: _dark.withOpacity(0.35))),
              const Spacer(),
              Text(isThai ? '14 วัน' : '14 days',
                  style: TextStyle(fontSize: 10,
                      color: _dark.withOpacity(0.35))),
            ]),
          ])),

          const SizedBox(height: 12),

          // ── 3. Time picker ───────────────────────────────
          _card(child: Row(children: [
            Icon(Icons.access_time_outlined,
                color: _enabled ? _green : _dark.withOpacity(0.3), size: 20),
            const SizedBox(width: 10),
            Expanded(child: Column(
                crossAxisAlignment: CrossAxisAlignment.start, children: [
              Text(isThai ? 'เวลาที่แจ้งเตือน' : 'Notification time',
                  style: const TextStyle(
                      fontSize: 15, fontWeight: FontWeight.w900)),
              Text(
                isThai
                    ? 'แจ้งเตือนทุกวันที่เวลานี้'
                    : 'Daily alert at this time',
                style: TextStyle(fontSize: 12,
                    color: _dark.withOpacity(0.5))),
            ])),
            GestureDetector(
              onTap: _enabled ? _pickTime : null,
              child: Container(
                padding: const EdgeInsets.symmetric(
                    horizontal: 16, vertical: 10),
                decoration: BoxDecoration(
                  color: _enabled
                      ? _green.withOpacity(0.12)
                      : _dark.withOpacity(0.06),
                  borderRadius: BorderRadius.circular(12),
                  border: Border.all(
                    color: _enabled
                        ? _green.withOpacity(0.3)
                        : _dark.withOpacity(0.1),
                  ),
                ),
                child: Text(
                  _fmtTime(),
                  style: TextStyle(
                    fontSize: 18,
                    fontWeight: FontWeight.w900,
                    color: _enabled ? _green : _dark.withOpacity(0.3),
                  ),
                ),
              ),
            ),
          ])),

          const SizedBox(height: 20),

          // ── 4. Preview: items ที่จะโดน notify ───────────
          if (_enabled) ...[
            Padding(
              padding: const EdgeInsets.only(left: 2, bottom: 8),
              child: Text(
                isThai
                    ? 'ตอนนี้จะแจ้งเตือน ${upcoming.length} รายการ'
                    : '${upcoming.length} item${upcoming.length != 1 ? "s" : ""} will be notified',
                style: TextStyle(fontSize: 13, fontWeight: FontWeight.w700,
                    color: _dark.withOpacity(0.6)),
              ),
            ),
            if (upcoming.isEmpty)
              _card(child: Row(children: [
                Icon(Icons.check_circle_outline,
                    color: _green, size: 22),
                const SizedBox(width: 10),
                Text(
                  isThai
                      ? 'ไม่มีของใกล้หมดอายุตอนนี้ 🎉'
                      : 'Nothing expiring soon 🎉',
                  style: TextStyle(fontSize: 13,
                      color: _dark.withOpacity(0.6)),
                ),
              ]))
            else
              _card(child: Column(
                children: upcoming.map((it) {
                  final now      = DateTime.now();
                  final today    = DateTime(now.year, now.month, now.day);
                  final exp      = DateTime(it.expireDate.year,
                      it.expireDate.month, it.expireDate.day);
                  final daysLeft = exp.difference(today).inDays;

                  final color = daysLeft == 0
                      ? _red
                      : daysLeft <= 2 ? _amber : _dark.withOpacity(0.6);

                  return Padding(
                    padding: const EdgeInsets.symmetric(vertical: 6),
                    child: Row(children: [
                      Icon(Icons.circle, size: 8, color: color),
                      const SizedBox(width: 10),
                      Expanded(child: Text(it.displayName(isThai),
                          style: const TextStyle(
                              fontSize: 13, fontWeight: FontWeight.w700))),
                      Text(
                        daysLeft == 0
                            ? (isThai ? 'หมดวันนี้!' : 'Today!')
                            : (isThai
                                ? 'อีก $daysLeft วัน'
                                : '$daysLeft day${daysLeft > 1 ? "s" : ""}'),
                        style: TextStyle(fontSize: 12,
                            fontWeight: FontWeight.w700, color: color),
                      ),
                    ]),
                  );
                }).toList(),
              )),

            const SizedBox(height: 20),
          ],

          // ── save button ───────────────────────────────────
          SizedBox(
            width: double.infinity,
            child: ElevatedButton(
              onPressed: _saving ? null : _save,
              style: ElevatedButton.styleFrom(
                backgroundColor: _dark,
                disabledBackgroundColor: _dark.withOpacity(0.3),
                foregroundColor: Colors.white,
                padding: const EdgeInsets.symmetric(vertical: 16),
                shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(16)),
              ),
              child: _saving
                  ? const SizedBox(width: 20, height: 20,
                      child: CircularProgressIndicator(
                          strokeWidth: 2, color: Colors.white))
                  : Text(
                      isThai ? 'บันทึกและอัปเดต' : 'Save & Update',
                      style: const TextStyle(
                          fontSize: 16, fontWeight: FontWeight.w900)),
            ),
          ),
        ],
      ),
    );
  }

  // ── widget helpers ────────────────────────────────────────

  Widget _card({required Widget child}) => Container(
    padding: const EdgeInsets.all(18),
    margin:  const EdgeInsets.only(bottom: 0),
    decoration: BoxDecoration(
        color: _peach, borderRadius: BorderRadius.circular(22)),
    child: child,
  );

  Widget _debugPanel() => Container(
    padding: const EdgeInsets.all(14),
    decoration: BoxDecoration(
      color: Colors.red.shade50,
      border: Border.all(color: Colors.red.shade200, width: 1.5),
      borderRadius: BorderRadius.circular(18),
    ),
    child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
      Row(children: [
        const Icon(Icons.bug_report, size: 16, color: Colors.red),
        const SizedBox(width: 6),
        const Text('DEBUG — Notification Tester',
            style: TextStyle(fontSize: 13,
                fontWeight: FontWeight.w900, color: Colors.red)),
      ]),
      const SizedBox(height: 4),
      Text('กด Send แล้วรอ 5 วินาที (ล็อกหน้าจอด้วยจะเห็นชัดขึ้น)',
          style: TextStyle(fontSize: 11, color: Colors.red.shade400)),
      const SizedBox(height: 10),
      Row(children: [
        Expanded(child: ElevatedButton.icon(
          onPressed: _debugLoading ? null : _runDebugTest,
          icon: _debugLoading
              ? const SizedBox(width: 14, height: 14,
                  child: CircularProgressIndicator(
                      strokeWidth: 2, color: Colors.white))
              : const Icon(Icons.send, size: 16),
          label: Text(_debugLoading ? 'Scheduling…' : 'Send test (5s)'),
          style: ElevatedButton.styleFrom(
            backgroundColor: Colors.red.shade400,
            foregroundColor: Colors.white,
            padding: const EdgeInsets.symmetric(vertical: 10),
            shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(10)),
          ),
        )),
        const SizedBox(width: 8),
        Expanded(child: OutlinedButton.icon(
          onPressed: () async {
            await NotificationService.I.cancelAll();
            setState(() => _debugStatus = '✓ All cancelled');
          },
          icon: const Icon(Icons.cancel_outlined, size: 16),
          label: const Text('Cancel all'),
          style: OutlinedButton.styleFrom(
            foregroundColor: Colors.red,
            side: BorderSide(color: Colors.red.shade300),
            padding: const EdgeInsets.symmetric(vertical: 10),
            shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(10)),
          ),
        )),
      ]),
      if (_debugStatus != null) ...[
        const SizedBox(height: 8),
        Text(_debugStatus!,
            style: TextStyle(
              fontSize: 12, fontWeight: FontWeight.w700,
              color: _debugStatus!.startsWith('✓')
                  ? Colors.green.shade700
                  : Colors.red.shade700,
            )),
      ],
    ]),
  );
}