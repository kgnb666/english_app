import "package:flutter/material.dart";
import "../config/theme.dart";
import "../l10n/zh_CN.dart";
import "../services/stats_service.dart";

class PlanPage extends StatefulWidget {
  const PlanPage({super.key});

  @override
  State<PlanPage> createState() => _PlanPageState();
}

class _PlanPageState extends State<PlanPage> {
  final _svc = StatsService();
  List<Map<String, dynamic>> _plan = [];
  final Map<String, TextEditingController> _ctrls = {};
  bool _loading = true;
  bool _saving = false;
  String? _error;

  static const _meta = {
    "words": (AppStrings.planWords, AppStrings.planUnitWords, Icons.book),
    "ai_minutes": (AppStrings.planAi, AppStrings.planUnitMinutes, Icons.chat),
    "reading": (AppStrings.planReading, AppStrings.planUnitReading, Icons.article),
    "writing": (AppStrings.planWriting, AppStrings.planUnitWriting, Icons.edit),
  };

  @override
  void initState() {
    super.initState();
    _load();
  }

  @override
  void dispose() {
    for (final c in _ctrls.values) {
      c.dispose();
    }
    super.dispose();
  }

  Future<void> _load() async {
    setState(() {
      _loading = true;
      _error = null;
    });
    try {
      final plan = await _svc.getPlan();
      if (!mounted) return;
      setState(() {
        _plan = plan;
        _ctrls.clear();
        for (final item in plan) {
          _ctrls[item["task_type"] as String] =
              TextEditingController(text: "${item["target_count"]}");
        }
      });
    } catch (e) {
      debugPrint("PlanPage load error: $e");
      if (mounted) setState(() => _error = AppStrings.loadFailed);
    } finally {
      if (mounted) setState(() => _loading = false);
    }
  }

  Future<void> _save() async {
    setState(() => _saving = true);
    try {
      final tasks = _plan.map((item) {
        final type = item["task_type"] as String;
        return {
          "task_type": type,
          "target_count": int.tryParse(_ctrls[type]?.text ?? "") ?? 0,
          "enabled": item["enabled"] == true,
        };
      }).toList();
      await _svc.updatePlan(tasks);
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text(AppStrings.planSaved),
          backgroundColor: Colors.green,
          behavior: SnackBarBehavior.floating,
        ),
      );
      Navigator.pop(context);
    } catch (e) {
      debugPrint("PlanPage save error: $e");
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text(AppStrings.planSaveFailed),
          backgroundColor: Colors.red,
          behavior: SnackBarBehavior.floating,
        ),
      );
    } finally {
      if (mounted) setState(() => _saving = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final t = Theme.of(context);
    return Scaffold(
      appBar: AppBar(
        title: const Text(AppStrings.planTitle),
        actions: [
          TextButton(
            onPressed: _saving ? null : _save,
            child: _saving
                ? const SizedBox(
                    width: 18,
                    height: 18,
                    child: CircularProgressIndicator(strokeWidth: 2),
                  )
                : const Text(AppStrings.save),
          ),
        ],
      ),
      body: _loading
          ? const Center(child: CircularProgressIndicator())
          : _error != null
              ? Center(
                  child: Column(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      Text(_error!),
                      const SizedBox(height: 12),
                      OutlinedButton(onPressed: _load, child: const Text(AppStrings.retry)),
                    ],
                  ),
                )
              : ListView(
                  padding: const EdgeInsets.all(16),
                  children: [
                    Container(
                      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
                      decoration: BoxDecoration(
                        color: AppTheme.primaryColor.withAlpha(15),
                        borderRadius: BorderRadius.circular(10),
                      ),
                      child: Row(
                        children: [
                          const Icon(Icons.auto_awesome, size: 18, color: AppTheme.primaryColor),
                          const SizedBox(width: 8),
                          Expanded(
                            child: Text(
                              AppStrings.planHint,
                              style: TextStyle(
                                fontSize: 13,
                                color: t.colorScheme.onSurface.withAlpha(180),
                              ),
                            ),
                          ),
                        ],
                      ),
                    ),
                    const SizedBox(height: 16),
                    Card(
                      child: Column(
                        children: [
                          for (final item in _plan) ...[
                            _taskEditor(item, t),
                            if (item != _plan.last) const Divider(height: 1),
                          ],
                        ],
                      ),
                    ),
                  ],
                ),
    );
  }

  Widget _taskEditor(Map<String, dynamic> item, ThemeData t) {
    final type = item["task_type"] as String;
    final meta = _meta[type];
    if (meta == null) return const SizedBox.shrink();
    final label = meta.$1;
    final unit = meta.$2;
    final icon = meta.$3;
    final enabled = item["enabled"] == true;
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
      child: Row(
        children: [
          Icon(icon, size: 22, color: enabled ? AppTheme.primaryColor : Colors.grey),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  label,
                  style: TextStyle(
                    fontSize: 15,
                    fontWeight: FontWeight.w500,
                    color: enabled ? null : Colors.grey,
                  ),
                ),
                const SizedBox(height: 6),
                Row(
                  children: [
                    SizedBox(
                      width: 90,
                      child: TextField(
                        controller: _ctrls[type],
                        enabled: enabled,
                        keyboardType: TextInputType.number,
                        decoration: InputDecoration(
                          isDense: true,
                          contentPadding: const EdgeInsets.symmetric(horizontal: 10, vertical: 8),
                          border: OutlineInputBorder(
                            borderRadius: BorderRadius.circular(8),
                          ),
                        ),
                      ),
                    ),
                    const SizedBox(width: 6),
                    Text(unit, style: TextStyle(fontSize: 13, color: Colors.grey.shade600)),
                  ],
                ),
              ],
            ),
          ),
          Switch(
            value: enabled,
            onChanged: (v) => setState(() => item["enabled"] = v),
          ),
        ],
      ),
    );
  }
}
