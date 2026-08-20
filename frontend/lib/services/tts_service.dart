import "dart:io";

import "package:audioplayers/audioplayers.dart";
import "package:dio/dio.dart";
import "package:flutter/foundation.dart";
import "package:flutter_tts/flutter_tts.dart";
import "package:path_provider/path_provider.dart";

import "api_service.dart";

/// 语音合成封装：
/// 1. 单词固定音频（audio_url）优先：本地内存/磁盘缓存 -> 下载静态音频
/// 2. 无固定音频的文本走后端 Edge TTS 云端合成
/// 3. 系统 TTS 仅作最后兜底
/// 播放器与合成器均为单例，不会重复初始化。
class TtsService {
  TtsService._();

  static final TtsService instance = TtsService._();

  final _api = ApiService();
  final _player = AudioPlayer();
  final _tts = FlutterTts();
  final Map<String, Uint8List> _audioCache = {};
  Directory? _diskDir;
  bool _cloudEnabled = true;
  bool _sysReady = false;
  String? _lastError;
  static const _maxCache = 80;
  static const _maxConcurrent = 3;

  /// 朗读文本（云端合成）；返回是否成功触发播放
  Future<bool> speak(String text) async {
    _lastError = null;
    final bytes = await _getBytes(text, null);
    if (bytes != null) {
      await _playBytes(bytes);
      return true;
    }
    return _speakSystem(text);
  }

  /// 朗读单词：优先固定音频 audio_url，无则先生成固定音频，最后回退云端合成
  Future<bool> speakWord(String word, String? audioUrl) async {
    _lastError = null;
    var bytes = await _getBytes(word, audioUrl);
    // 云端合成文本兜底
    bytes ??= await _fetchCloud(word);
    if (bytes != null) {
      await _playBytes(bytes);
      return true;
    }
    return _speakSystem(word);
  }

  /// 预加载单词音频（有 audio_url 时下载到本地缓存）
  Future<void> preloadWord(String word, String? audioUrl) async {
    if (audioUrl == null || audioUrl.isEmpty) return;
    await _getBytes(word, audioUrl);
  }

  /// 批量预加载音频 URL（限 3 并发）
  Future<void> preloadUrls(List<String> urls) async {
    var inflight = 0;
    final tasks = <Future<void>>[];
    for (final url in urls) {
      if (url.isEmpty || _audioCache.containsKey(url)) continue;
      while (inflight >= _maxConcurrent) {
        await Future<void>.delayed(const Duration(milliseconds: 80));
      }
      inflight += 1;
      tasks.add(_downloadToCache(url).whenComplete(() => inflight -= 1).catchError((e) {
        debugPrint("preload url error: $e");
      }));
    }
    await Future.wait(tasks);
  }

  /// 后台预合成文本（不播放）
  Future<void> preload(String text) async {
    if (!_cloudEnabled || _audioCache.containsKey(text)) return;
    try {
      final bytes = await _fetchCloud(text);
      if (bytes != null) _cachePut(text, bytes);
    } catch (e) {
      debugPrint("TTS preload error: $e");
    }
  }

  /// 批量后台预合成文本
  Future<void> preloadMany(List<String> texts) async {
    final tasks = <Future<void>>[];
    var inflight = 0;
    for (final text in texts) {
      if (_audioCache.containsKey(text) || text.trim().isEmpty) continue;
      while (inflight >= _maxConcurrent) {
        await Future<void>.delayed(const Duration(milliseconds: 100));
      }
      inflight += 1;
      tasks.add(preload(text).whenComplete(() => inflight -= 1));
    }
    await Future.wait(tasks);
  }

  // ===== 内部实现 =====

  /// 获取音频字节：内存 -> 磁盘 -> 网络（audio_url）或云端合成
  Future<Uint8List?> _getBytes(String text, String? audioUrl) async {
    final key = audioUrl ?? text;
    final mem = _audioCache[key];
    if (mem != null) return mem;

    final disk = await _readDisk(key);
    if (disk != null) {
      _cachePut(key, disk);
      return disk;
    }

    Uint8List? bytes;
    if (audioUrl != null && audioUrl.isNotEmpty) {
      bytes = await _downloadAudio(audioUrl);
    }
    if (bytes == null && _cloudEnabled) {
      bytes = await _fetchCloud(text);
    }
    if (bytes != null) {
      _cachePut(key, bytes);
      await _writeDisk(key, bytes);
    }
    return bytes;
  }

  Future<Uint8List?> _downloadAudio(String audioUrl) async {
    try {
      final url = _absoluteUrl(audioUrl);
      final resp = await _api.dio.get(
        url,
        options: Options(responseType: ResponseType.bytes),
      );
      final bytes = resp.data;
      if (bytes is Uint8List && bytes.isNotEmpty) return bytes;
    } catch (e) {
      debugPrint("TTS download audio error: $e");
    }
    return null;
  }

  Future<Uint8List?> _fetchCloud(String text) async {
    try {
      final resp = await _api.dio.get(
        "/tts",
        queryParameters: {"text": text},
        options: Options(responseType: ResponseType.bytes),
      );
      final bytes = resp.data;
      if (bytes is Uint8List && bytes.isNotEmpty) {
        debugPrint("Cloud TTS fetched ${bytes.length} bytes");
        return bytes;
      }
      debugPrint("Cloud TTS returned empty audio");
      _cloudEnabled = false;
    } catch (e) {
      debugPrint("Cloud TTS error: $e");
      _cloudEnabled = false;
      _lastError = e.toString();
    }
    return null;
  }

  Future<void> _downloadToCache(String audioUrl) async {
    final bytes = await _downloadAudio(audioUrl);
    if (bytes != null) {
      _cachePut(audioUrl, bytes);
      await _writeDisk(audioUrl, bytes);
    }
  }

  Future<void> _playBytes(Uint8List bytes) async {
    await _player.stop();
    await _player.play(BytesSource(bytes));
    debugPrint("TTS played ${bytes.length} bytes");
  }

  Future<bool> _speakSystem(String text) async {
    if (!_sysReady) await _initSystem();
    try {
      final ok = await _tts.speak(text);
      debugPrint("System TTS speak -> $ok");
      return ok == true || ok == 1;
    } catch (e) {
      debugPrint("System TTS speak error: $e");
      _lastError = e.toString();
      return false;
    }
  }

  Future<void> _initSystem() async {
    try {
      await _tts.setSharedInstance(true);
      await _tts.awaitSpeakCompletion(true);
      _tts.setErrorHandler((msg) {
        _lastError = msg;
        debugPrint("System TTS error: $msg");
      });
      for (final lang in ["en-US", "en_US", "en"]) {
        final ok = await _tts.setLanguage(lang);
        if (ok == true || ok == 1) break;
      }
      _sysReady = true;
    } catch (e) {
      debugPrint("System TTS init error: $e");
    }
  }

  String _absoluteUrl(String audioUrl) {
    if (audioUrl.startsWith("http")) return audioUrl;
    var base = _api.dio.options.baseUrl;
    if (base.endsWith("/api/v1")) {
      base = base.substring(0, base.length - "/api/v1".length);
    }
    return "$base$audioUrl";
  }

  void _cachePut(String key, Uint8List bytes) {
    if (_audioCache.length >= _maxCache) {
      _audioCache.remove(_audioCache.keys.first);
    }
    _audioCache[key] = bytes;
  }

  Future<Directory> _cacheDir() async {
    if (_diskDir != null) return _diskDir!;
    final dir = await getApplicationSupportDirectory();
    _diskDir = Directory("${dir.path}/tts_cache");
    await _diskDir!.create(recursive: true);
    return _diskDir!;
  }

  String _diskName(String key) {
    final name = key
        .replaceAll(RegExp(r"[^a-zA-Z0-9\-_.]"), "_")
        .replaceAll(RegExp(r"_+"), "_");
    final trimmed = name.length > 80 ? name.substring(name.length - 80) : name;
    return "${trimmed}_${key.hashCode.abs()}.mp3";
  }

  Future<Uint8List?> _readDisk(String key) async {
    try {
      final dir = await _cacheDir();
      final f = File("${dir.path}/${_diskName(key)}");
      if (await f.exists()) {
        return await f.readAsBytes();
      }
    } catch (e) {
      debugPrint("TTS disk read error: $e");
    }
    return null;
  }

  Future<void> _writeDisk(String key, Uint8List bytes) async {
    try {
      final dir = await _cacheDir();
      final f = File("${dir.path}/${_diskName(key)}");
      await f.writeAsBytes(bytes, flush: true);
    } catch (e) {
      debugPrint("TTS disk write error: $e");
    }
  }

  Future<void> stop() async {
    try {
      await _player.stop();
    } catch (e) {
      debugPrint("AudioPlayer stop error: $e");
    }
    try {
      await _tts.stop();
    } catch (e) {
      debugPrint("System TTS stop error: $e");
    }
  }

  Future<void> setRate(double rate) async {
    try {
      await _tts.setSpeechRate(rate);
    } catch (e) {
      debugPrint("System TTS setSpeechRate error: $e");
    }
  }

  String? get lastError => _lastError;
}
