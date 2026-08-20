import "dart:convert";
import "dart:io";

import "package:path_provider/path_provider.dart";

import "api_service.dart";

class BackupFileInfo {
  final String path;
  final String fileName;
  final DateTime modified;
  final int size;

  BackupFileInfo({required this.path, required this.fileName, required this.modified, required this.size});

  String get sizeLabel {
    if (size < 1024) return "$size B";
    if (size < 1024 * 1024) return "${(size / 1024).toStringAsFixed(1)} KB";
    return "${(size / 1024 / 1024).toStringAsFixed(2)} MB";
  }
}

/// 数据备份服务：导出学习数据、保存本地文件、恢复数据
class BackupService {
  final ApiService _api = ApiService();

  /// 调用后端导出全部学习数据
  Future<Map<String, dynamic>> exportData() async {
    final r = await _api.dio.get("/backup/export");
    return Map<String, dynamic>.from(r.data as Map);
  }

  /// 将导出数据保存到 App 文档目录 backups/ 下
  Future<String> saveExportToFile(Map<String, dynamic> data) async {
    final dir = await _backupDir();
    final now = DateTime.now();
    String two(int v) => v.toString().padLeft(2, "0");
    final stamp = "${now.year}${two(now.month)}${two(now.day)}_${two(now.hour)}${two(now.minute)}${two(now.second)}";
    final file = File("${dir.path}/export_$stamp.json");
    const encoder = JsonEncoder.withIndent("  ");
    await file.writeAsString(encoder.convert(data), flush: true);
    return file.path;
  }

  /// 列出本地已保存的备份文件
  Future<List<BackupFileInfo>> listBackupFiles() async {
    final dir = await _backupDir();
    final files = <BackupFileInfo>[];
    await for (final entity in dir.list()) {
      if (entity is! File || !entity.path.endsWith(".json")) continue;
      final stat = await entity.stat();
      files.add(BackupFileInfo(
        path: entity.path,
        fileName: entity.uri.pathSegments.last,
        modified: stat.modified,
        size: stat.size,
      ));
    }
    files.sort((a, b) => b.modified.compareTo(a.modified));
    return files;
  }

  /// 读取备份文件内容
  Future<Map<String, dynamic>> readBackupFile(String path) async {
    final raw = await File(path).readAsString();
    return Map<String, dynamic>.from(jsonDecode(raw) as Map);
  }

  /// 调用后端恢复数据
  Future<Map<String, dynamic>> restoreData(Map<String, dynamic> data) async {
    final r = await _api.dio.post("/backup/restore", data: data);
    return Map<String, dynamic>.from(r.data as Map);
  }

  Future<Directory> _backupDir() async {
    final docs = await getApplicationDocumentsDirectory();
    final dir = Directory("${docs.path}/backups");
    if (!dir.existsSync()) await dir.create(recursive: true);
    return dir;
  }
}
