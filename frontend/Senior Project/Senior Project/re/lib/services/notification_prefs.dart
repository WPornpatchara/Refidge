import 'package:shared_preferences/shared_preferences.dart';

/// เก็บ settings ของ notification ไว้ใน SharedPreferences
/// ใช้ singleton NotificationPrefs.I
class NotificationPrefs {
  NotificationPrefs._();
  static final NotificationPrefs I = NotificationPrefs._();

  static const _keyEnabled    = 'notif_enabled';
  static const _keyDaysBefore = 'notif_days_before';
  static const _keyHour       = 'notif_hour';
  static const _keyMinute     = 'notif_minute';

  // ── defaults ────────────────────────────────────────────
  static const int  defaultDaysBefore = 4;
  static const int  defaultHour       = 9;
  static const int  defaultMinute     = 0;

  // ── getters ──────────────────────────────────────────────

  Future<bool> isEnabled() async {
    final prefs = await SharedPreferences.getInstance();
    return prefs.getBool(_keyEnabled) ?? true;
  }

  Future<int> daysBefore() async {
    final prefs = await SharedPreferences.getInstance();
    return prefs.getInt(_keyDaysBefore) ?? defaultDaysBefore;
  }

  Future<int> hour() async {
    final prefs = await SharedPreferences.getInstance();
    return prefs.getInt(_keyHour) ?? defaultHour;
  }

  Future<int> minute() async {
    final prefs = await SharedPreferences.getInstance();
    return prefs.getInt(_keyMinute) ?? defaultMinute;
  }

  // ── setters ──────────────────────────────────────────────

  Future<void> setEnabled(bool v) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setBool(_keyEnabled, v);
  }

  Future<void> setDaysBefore(int v) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setInt(_keyDaysBefore, v.clamp(1, 30));
  }

  Future<void> setHour(int v) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setInt(_keyHour, v.clamp(0, 23));
  }

  Future<void> setMinute(int v) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setInt(_keyMinute, v.clamp(0, 59));
  }

  // ── helper: load all at once ─────────────────────────────

  Future<({bool enabled, int daysBefore, int hour, int minute})> load() async {
    final prefs = await SharedPreferences.getInstance();
    return (
      enabled:    prefs.getBool(_keyEnabled)       ?? true,
      daysBefore: prefs.getInt(_keyDaysBefore)     ?? defaultDaysBefore,
      hour:       prefs.getInt(_keyHour)           ?? defaultHour,
      minute:     prefs.getInt(_keyMinute)         ?? defaultMinute,
    );
  }
}