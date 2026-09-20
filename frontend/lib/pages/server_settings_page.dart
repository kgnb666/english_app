import "package:dio/dio.dart";
import "package:flutter/material.dart";
import "package:go_router/go_router.dart";

import "../config/api_config.dart";
import "../l10n/zh_CN.dart";
import "../services/api_service.dart";

/// 服务器设置页：查看/修改 API 地址并测试连接
class ServerSettingsPage extends StatefulWidget {
  const ServerSettingsPage({super.key});

  @override
  State<ServerSettingsPage> createState() => _ServerSettingsPageState();
}

class _ServerSettingsPageState extends State<ServerSettingsPage> {
  late final TextEditingController _urlCtrl;
  bool _saving = false;
  bool _testing = false;
  String? _statusText;
  bool _statusOk = false;

  @override
  void initState() {
    super.initState();
    // 地址框显示不含 /api/v1 的基础地址，避免测试连接时拼出错误路径
    _urlCtrl = TextEditingController(
      text: ApiConfig.baseUrl.replaceFirst(RegExp(r"/api/v1$"), ""),
    );
  }

  @override
  void dispose() {
    _urlCtrl.dispose();
    super.dispose();
  }

  Future<void> _save() async {
    setState(() {
      _saving = true;
      _statusText = null;
    });
    try {
      await ApiConfig.setUserBaseUrl(_urlCtrl.text);
      ApiService().updateBaseUrl(ApiConfig.baseUrl);
      if (!mounted) return;
      setState(() => _statusText = AppStrings.serverSaved);
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text(AppStrings.serverSaved), backgroundColor: Colors.green),
      );
    } catch (e) {
      if (!mounted) return;
      setState(() => _statusText = "$e");
    } finally {
      if (mounted) setState(() => _saving = false);
    }
  }

  Future<void> _testConnection() async {
    setState(() {
      _testing = true;
      _statusText = null;
    });
    // 测试连接时去掉 /api/v1 后缀（/health 是顶层路径）
    final normalized = _normalize(_urlCtrl.text);
    final candidate = normalized.replaceFirst(RegExp(r"/api/v1$"), "");
    try {
      final dio = Dio(BaseOptions(
        baseUrl: candidate,
        connectTimeout: const Duration(milliseconds: 8000),
        receiveTimeout: const Duration(milliseconds: 10000),
      ));
      final r = await dio.get("/health");
      if (!mounted) return;
      setState(() {
        _statusOk = r.statusCode == 200;
        _statusText = r.statusCode == 200 ? AppStrings.serverConnected : AppStrings.serverFailed;
      });
    } on DioException catch (e) {
      if (!mounted) return;
      setState(() {
        _statusOk = false;
        _statusText = "${AppStrings.serverFailed}${e.message != null ? " (${e.message})" : ""}";
      });
    }
    if (mounted) setState(() => _testing = false);
  }

  String _normalize(String url) {
    var u = url.trim();
    if (!u.startsWith("http://") && !u.startsWith("https://")) u = "http://$u";
    return u;
  }

  @override
  Widget build(BuildContext context) {
    final t = Theme.of(context);
    return Scaffold(
      appBar: AppBar(title: Text(AppStrings.serverSettings)),
      body: ListView(
        padding: const EdgeInsets.all(16),
        children: [
          Card(
            child: Padding(
              padding: const EdgeInsets.all(16),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(AppStrings.serverSettings, style: t.textTheme.titleSmall?.copyWith(fontWeight: FontWeight.w600)),
                  const SizedBox(height: 4),
                  Text(AppStrings.serverSettingsHint, style: TextStyle(fontSize: 12, color: Colors.grey.shade600)),
                  const SizedBox(height: 12),
                  _infoRow(t, AppStrings.currentEnv, ApiConfig.env.toUpperCase()),
                  const Divider(height: 20),
                  TextField(
                    controller: _urlCtrl,
                    keyboardType: TextInputType.url,
                    decoration: InputDecoration(
                      labelText: AppStrings.apiAddress,
                      hintText: "http://192.168.x.x:8002/api/v1",
                      border: const OutlineInputBorder(),
                      suffixIcon: IconButton(
                        icon: const Icon(Icons.restore),
                        tooltip: AppStrings.resetToDefault,
                        onPressed: () async {
                          await ApiConfig.clearUserOverride();
                          ApiService().updateBaseUrl(ApiConfig.baseUrl);
                          if (!mounted) return;
                          _urlCtrl.text = ApiConfig.baseUrl;
                          setState(() {
                            _statusText = AppStrings.usingDefault;
                            _statusOk = false;
                          });
                        },
                      ),
                    ),
                  ),
                  if (_statusText != null) ...[
                    const SizedBox(height: 12),
                    Row(
                      children: [
                        Icon(_statusOk ? Icons.check_circle : Icons.error_outline,
                            size: 18, color: _statusOk ? Colors.green : t.colorScheme.error),
                        const SizedBox(width: 8),
                        Expanded(
                          child: Text(_statusText!,
                              style: TextStyle(fontSize: 13, color: _statusOk ? Colors.green : t.colorScheme.error)),
                        ),
                      ],
                    ),
                  ],
                ],
              ),
            ),
          ),
          const SizedBox(height: 16),
          Row(
            children: [
              Expanded(
                child: OutlinedButton.icon(
                  onPressed: _testing ? null : _testConnection,
                  icon: _testing
                      ? const SizedBox(width: 16, height: 16, child: CircularProgressIndicator(strokeWidth: 2))
                      : const Icon(Icons.wifi_tethering),
                  label: Text(AppStrings.testConnection),
                  style: OutlinedButton.styleFrom(padding: const EdgeInsets.symmetric(vertical: 14)),
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: ElevatedButton.icon(
                  onPressed: _saving ? null : _save,
                  icon: _saving
                      ? const SizedBox(width: 16, height: 16, child: CircularProgressIndicator(strokeWidth: 2, color: Colors.white))
                      : const Icon(Icons.save),
                  label: Text(AppStrings.save),
                  style: ElevatedButton.styleFrom(padding: const EdgeInsets.symmetric(vertical: 14)),
                ),
              ),
            ],
          ),
          const SizedBox(height: 24),
          Card(
            child: Padding(
              padding: const EdgeInsets.all(16),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(AppStrings.configDocs, style: t.textTheme.titleSmall?.copyWith(fontWeight: FontWeight.w600)),
                  const SizedBox(height: 8),
                  Text(AppStrings.configDocsBody, style: TextStyle(fontSize: 13, height: 1.6, color: Colors.grey.shade700)),
                ],
              ),
            ),
          ),
          const SizedBox(height: 16),
          OutlinedButton.icon(
            onPressed: () => context.pop(),
            icon: const Icon(Icons.arrow_back),
            label: Text(AppStrings.back),
            style: OutlinedButton.styleFrom(padding: const EdgeInsets.symmetric(vertical: 14)),
          ),
        ],
      ),
    );
  }

  Widget _infoRow(ThemeData t, String label, String value) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 4),
      child: Row(
        children: [
          Text(label, style: TextStyle(fontSize: 13, color: Colors.grey.shade600)),
          const Spacer(),
          Text(value, style: const TextStyle(fontSize: 13, fontWeight: FontWeight.w600)),
        ],
      ),
    );
  }
}
