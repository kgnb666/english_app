import "package:flutter/material.dart";

import "../config/theme.dart";
import "../l10n/zh_CN.dart";
import "../services/backup_service.dart";
import "../widgets/common_loading_button.dart";

/// 数据备份页：导出学习数据、查看导出状态、保存文件、恢复数据
class BackupPage extends StatefulWidget {
  const BackupPage({super.key});

  @override
  State<BackupPage> createState() => _BackupPageState();
}

class _BackupPageState extends State<BackupPage> {
  final BackupService _svc = BackupService();
  bool _exporting = false;
  bool _restoring = false;
  List<BackupFileInfo> _files = [];
  Map<String, dynamic>? _lastExport;
  String? _lastExportPath;
  String? _lastStatus;
  bool _lastStatusOk = false;

  @override
  void initState() {
    super.initState();
    _loadFiles();
  }

  Future<void> _loadFiles() async {
    try {
      final files = await _svc.listBackupFiles();
      if (!mounted) return;
      setState(() => _files = files);
    } catch (e) {
      debugPrint("BackupPage load files error: $e");
    }
  }

  Future<void> _export() async {
    setState(() {
      _exporting = true;
      _lastStatus = null;
    });
    try {
      final data = await _svc.exportData();
      final path = await _svc.saveExportToFile(data);
      await _loadFiles();
      if (!mounted) return;
      setState(() {
        _lastExport = data;
        _lastExportPath = path;
        _lastStatus = AppStrings.exportSuccess;
        _lastStatusOk = true;
      });
    } catch (e) {
      debugPrint("BackupPage export error: $e");
      if (!mounted) return;
      setState(() {
        _lastStatus = "${AppStrings.exportFailed}: $e";
        _lastStatusOk = false;
      });
    } finally {
      if (mounted) setState(() => _exporting = false);
    }
  }

  Future<void> _restore(BackupFileInfo file) async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: Text(AppStrings.confirmRestore),
        content: Text(AppStrings.confirmRestoreHint),
        actions: [
          TextButton(onPressed: () => Navigator.pop(ctx, false), child: Text(AppStrings.cancel)),
          TextButton(
            onPressed: () => Navigator.pop(ctx, true),
            child: Text(AppStrings.confirm, style: const TextStyle(color: Colors.red)),
          ),
        ],
      ),
    );
    if (confirmed != true) return;

    setState(() {
      _restoring = true;
      _lastStatus = null;
    });
    try {
      final data = await _svc.readBackupFile(file.path);
      final result = await _svc.restoreData(data);
      if (!mounted) return;
      setState(() {
        _lastStatus = _restoreSummary(result);
        _lastStatusOk = true;
      });
    } catch (e) {
      debugPrint("BackupPage restore error: $e");
      if (!mounted) return;
      setState(() {
        _lastStatus = "${AppStrings.restoreFailed}: $e";
        _lastStatusOk = false;
      });
    } finally {
      if (mounted) setState(() => _restoring = false);
    }
  }

  String _restoreSummary(Map<String, dynamic> r) {
    int n(String k) => (r[k] as num?)?.toInt() ?? 0;
    return "恢复完成：对话 ${n("chat_sessions")} / 消息 ${n("chat_messages")}，单词进度 ${n("word_progress")}，"
        "阅读 ${n("reading_records")}，作文 ${n("writing_records")}，统计 ${n("daily_stats")}，跳过 ${n("skipped")}";
  }

  String _sectionCounts(Map<String, dynamic>? data) {
    if (data == null) return AppStrings.noExportYet;
    int len(String k) => (data[k] as List?)?.length ?? 0;
    return "单词 ${len("word_progress")} · 聊天 ${len("chat_history")} · 阅读 ${len("reading_records")} · 作文 ${len("writing_records")}";
  }

  @override
  Widget build(BuildContext context) {
    final t = Theme.of(context);
    return Scaffold(
      appBar: AppBar(title: Text(AppStrings.dataBackup)),
      body: RefreshIndicator(
        onRefresh: _loadFiles,
        child: ListView(
          padding: const EdgeInsets.all(16),
          children: [
            Card(
              child: Padding(
                padding: const EdgeInsets.all(16),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(AppStrings.backupIncludes, style: t.textTheme.titleSmall?.copyWith(fontWeight: FontWeight.w600)),
                    const SizedBox(height: 8),
                    Text(AppStrings.backupIncludesDetail, style: TextStyle(fontSize: 13, color: Colors.grey.shade600)),
                    const SizedBox(height: 16),
                    CommonLoadingButton(
                      label: AppStrings.exportData,
                      loadingLabel: AppStrings.exporting,
                      icon: Icons.file_download_outlined,
                      loading: _exporting,
                      onPressed: _export,
                    ),
                    if (_lastStatus != null) ...[
                      const SizedBox(height: 12),
                      Row(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Icon(_lastStatusOk ? Icons.check_circle : Icons.error_outline,
                              size: 18, color: _lastStatusOk ? Colors.green : t.colorScheme.error),
                          const SizedBox(width: 8),
                          Expanded(
                            child: Text(_lastStatus!,
                                style: TextStyle(fontSize: 13, color: _lastStatusOk ? Colors.green : t.colorScheme.error)),
                          ),
                        ],
                      ),
                    ],
                    if (_lastExport != null) ...[
                      const SizedBox(height: 8),
                      Text(_sectionCounts(_lastExport), style: const TextStyle(fontSize: 13)),
                      if (_lastExportPath != null)
                        Padding(
                          padding: const EdgeInsets.only(top: 4),
                          child: Text(_lastExportPath!, style: TextStyle(fontSize: 11, color: Colors.grey.shade500)),
                        ),
                    ],
                  ],
                ),
              ),
            ),
            const SizedBox(height: 16),
            Card(
              child: Padding(
                padding: const EdgeInsets.all(16),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      children: [
                        Text(AppStrings.exportStatus, style: t.textTheme.titleSmall?.copyWith(fontWeight: FontWeight.w600)),
                        const Spacer(),
                        Text("${_files.length} ${AppStrings.filesLabel}", style: TextStyle(fontSize: 12, color: Colors.grey.shade600)),
                      ],
                    ),
                    const SizedBox(height: 8),
                    if (_files.isEmpty)
                      Padding(
                        padding: const EdgeInsets.symmetric(vertical: 16),
                        child: Column(children: [
                          Icon(Icons.cloud_outlined, size: 40, color: Colors.grey.shade400),
                          const SizedBox(height: 10),
                          Text(AppStrings.noBackupFiles, style: TextStyle(fontSize: 13, color: Colors.grey.shade600)),
                          const SizedBox(height: 12),
                          OutlinedButton.icon(
                            onPressed: _exporting ? null : _export,
                            icon: const Icon(Icons.file_download_outlined, size: 18),
                            label: Text(AppStrings.exportData),
                          ),
                        ]),
                      )
                    else
                      ..._files.map((f) => ListTile(
                            contentPadding: EdgeInsets.zero,
                            leading: const Icon(Icons.description_outlined, color: AppTheme.primaryColor),
                            title: Text(f.fileName, style: const TextStyle(fontSize: 14), maxLines: 1, overflow: TextOverflow.ellipsis),
                            subtitle: Text(
                              "${f.modified.toLocal().toString().substring(0, 16)} · ${f.sizeLabel}",
                              style: const TextStyle(fontSize: 12),
                            ),
                            trailing: _restoring
                                ? const SizedBox(width: 20, height: 20, child: CircularProgressIndicator(strokeWidth: 2))
                                : const Icon(Icons.restore, color: AppTheme.primaryColor),
                            onTap: _restoring ? null : () => _restore(f),
                          )),
                  ],
                ),
              ),
            ),
            const SizedBox(height: 12),
            Text(
              AppStrings.backupTip,
              style: TextStyle(fontSize: 12, color: t.colorScheme.onSurface.withAlpha(150)),
            ),
          ],
        ),
      ),
    );
  }
}
