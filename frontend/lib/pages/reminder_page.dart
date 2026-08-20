import "package:flutter/material.dart";
import "package:shared_preferences/shared_preferences.dart";

import "../config/theme.dart";
import "../l10n/zh_CN.dart";
import "../services/notification_service.dart";

/// 学习提醒设置页：开关 + 每日提醒时间
class ReminderPage extends StatefulWidget {
  const ReminderPage({super.key});

  @override
  State<ReminderPage> createState() => _ReminderPageState();
}

class _ReminderPageState extends State<ReminderPage> {
  static const _enabledKey = "reminder_enabled";
  static const _hourKey = "reminder_hour";
  static const _minuteKey = "reminder_minute";

  bool _enabled = false;
  TimeOfDay _time = const TimeOfDay(hour: 20, minute: 0);
  bool _saving = false;
  String? _status;

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    final prefs = await SharedPreferences.getInstance();
    if (!mounted) return;
    setState(() {
      _enabled = prefs.getBool(_enabledKey) ?? false;
      _time = TimeOfDay(
        hour: prefs.getInt(_hourKey) ?? 20,
        minute: prefs.getInt(_minuteKey) ?? 0,
      );
    });
  }

  Future<void> _apply({bool? enabled, TimeOfDay? time}) async {
    setState(() => _saving = true);
    final nextEnabled = enabled ?? _enabled;
    final nextTime = time ?? _time;

    if (nextEnabled) {
      final granted = await NotificationService.instance.requestPermissions();
      if (!granted) {
        if (!mounted) return;
        setState(() {
          _saving = false;
          _enabled = false;
          _status = AppStrings.notificationPermissionDenied;
        });
        return;
      }
    }

    try {
      await NotificationService.instance.scheduleDailyReminder(
        enabled: nextEnabled,
        hour: nextTime.hour,
        minute: nextTime.minute,
      );
      final prefs = await SharedPreferences.getInstance();
      await prefs.setBool(_enabledKey, nextEnabled);
      await prefs.setInt(_hourKey, nextTime.hour);
      await prefs.setInt(_minuteKey, nextTime.minute);
      if (!mounted) return;
      setState(() {
        _enabled = nextEnabled;
        _time = nextTime;
        _status = nextEnabled ? AppStrings.reminderScheduled : AppStrings.reminderCancelled;
      });
    } catch (e) {
      debugPrint("ReminderPage apply error: $e");
      if (!mounted) return;
      setState(() => _status = "${AppStrings.reminderFailed}: $e");
    } finally {
      if (mounted) setState(() => _saving = false);
    }
  }

  Future<void> _pickTime() async {
    final picked = await showTimePicker(context: context, initialTime: _time);
    if (picked != null) await _apply(time: picked);
  }

  String get _timeLabel {
    String two(int v) => v.toString().padLeft(2, "0");
    return "${two(_time.hour)}:${two(_time.minute)}";
  }

  @override
  Widget build(BuildContext context) {
    final t = Theme.of(context);
    return Scaffold(
      appBar: AppBar(title: Text(AppStrings.reminderSettings)),
      body: ListView(
        padding: const EdgeInsets.all(16),
        children: [
          Card(
            child: Column(
              children: [
                SwitchListTile(
                  secondary: const Icon(Icons.notifications_active, color: AppTheme.primaryColor),
                  title: Text(AppStrings.enableReminder),
                  subtitle: Text(AppStrings.enableReminderSub),
                  value: _enabled,
                  onChanged: _saving ? null : (v) => _apply(enabled: v),
                ),
                const Divider(height: 1),
                ListTile(
                  enabled: _enabled,
                  leading: const Icon(Icons.schedule, color: AppTheme.primaryColor),
                  title: Text(AppStrings.reminderTime),
                  trailing: Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Text(_timeLabel, style: const TextStyle(fontSize: 16, fontWeight: FontWeight.w600)),
                      const Icon(Icons.chevron_right),
                    ],
                  ),
                  onTap: _enabled && !_saving ? _pickTime : null,
                ),
              ],
            ),
          ),
          if (_status != null) ...[
            const SizedBox(height: 12),
            Row(
              children: [
                Icon(Icons.info_outline, size: 18, color: AppTheme.primaryColor),
                const SizedBox(width: 8),
                Expanded(child: Text(_status!, style: const TextStyle(fontSize: 13))),
              ],
            ),
          ],
          const SizedBox(height: 12),
          if (_enabled)
            Card(
              color: AppTheme.primaryColor.withAlpha(12),
              child: ListTile(
                leading: const Icon(Icons.notifications_none, color: AppTheme.primaryColor),
                title: Text(AppStrings.nextReminder),
                subtitle: Text("${AppStrings.dailyReminderText}（$_timeLabel）"),
              ),
            ),
          const SizedBox(height: 8),
          Text(
            AppStrings.reminderTip,
            style: TextStyle(fontSize: 12, color: t.colorScheme.onSurface.withAlpha(150)),
          ),
        ],
      ),
    );
  }
}
