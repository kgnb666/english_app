import "dart:async";
import "dart:io";

import "package:dio/dio.dart";
import "package:flutter/foundation.dart";
import "package:path_provider/path_provider.dart";
import "package:record/record.dart";
import "package:speech_to_text/speech_to_text.dart" as stt;

import "api_service.dart";

/// 语音识别统一封装（单例）：
/// 1. 优先系统 STT（免费、离线、快），适合支持语音服务的机型
/// 2. 系统 STT 不可用（权限/引擎受限）时自动降级：本地录音上传后端 Whisper 转写
class SpeechService {
  SpeechService._();

  static final SpeechService instance = SpeechService._();

  final _api = ApiService();
  final stt.SpeechToText _stt = stt.SpeechToText();
  final AudioRecorder _recorder = AudioRecorder();
  bool _ready = false;
  bool _initializing = false;
  bool _listening = false;
  bool _recording = false;
  bool _systemFailedThisTime = false;
  String? _recordPath;
  Timer? _autoStop;
  String? _lastError;
  void Function(String text, bool isFinal, double? confidence)? _activeOnResult;

  bool get isReady => _ready;
  bool get isListening => _listening || _recording;
  bool get isInitializing => _initializing;
  bool get isRecordingFallback => _recording;
  String? get lastError => _lastError;

  /// 初始化系统 STT；返回是否就绪
  Future<bool> init() async {
    if (_ready) return true;
    if (_initializing) {
      for (var i = 0; i < 50 && _initializing; i++) {
        await Future<void>.delayed(const Duration(milliseconds: 100));
      }
      return _ready;
    }
    _initializing = true;
    _lastError = null;
    try {
      _ready = await _stt.initialize(
        onError: (e) {
          _lastError = e.errorMsg;
          if (e.errorMsg == "error_permission") {
            _systemFailedThisTime = true;
          }
          debugPrint("SpeechService STT error: ${e.errorMsg}");
        },
        onStatus: (s) {
          debugPrint("SpeechService STT status: $s");
          if (s == "done" || s == "notListening") {
            _listening = false;
          }
        },
      );
      if (!_ready) {
        _lastError = "permission";
      }
    } catch (e) {
      debugPrint("SpeechService init error: $e");
      _ready = false;
      _lastError = "init_failed";
    } finally {
      _initializing = false;
    }
    return _ready;
  }

  /// 开始语音输入；内部自动选择系统 STT 或录音 + Whisper
  Future<bool> listen({
    required void Function(String text, bool isFinal, double? confidence) onResult,
    void Function(double level)? onLevel,
  }) async {
    _activeOnResult = onResult;
    _lastError = null;
    // 默认走录音 + 后端 Whisper（不依赖手机系统 STT）
    final ok = await _startRecording(onLevel);
    if (ok) return true;
    // 录音不可用时回退系统 STT
    debugPrint("Recording failed, fallback to system STT");
    return _trySystemListen(onResult, onLevel);
  }

  Future<bool> _trySystemListen(
    void Function(String, bool, double?) onResult,
    void Function(double)? onLevel,
  ) async {
    if (!_ready) await init();
    if (!_ready) return false;
    _systemFailedThisTime = false;
    _listening = true;
    final ok = await _stt.listen(
      onResult: (r) => onResult(r.recognizedWords, r.finalResult, r.confidence),
      onSoundLevelChange: onLevel,
      listenOptions: stt.SpeechListenOptions(localeId: "en_US"),
    );
    if (!ok || _systemFailedThisTime) {
      _listening = false;
      return false;
    }
    return true;
  }

  Future<bool> _startRecording(void Function(double)? onLevel) async {
    if (!await _recorder.hasPermission()) {
      _lastError = "permission";
      return false;
    }
    try {
      final dir = await getTemporaryDirectory();
      _recordPath = "${dir.path}/stt_${DateTime.now().millisecondsSinceEpoch}.m4a";
      await _recorder.start(
        const RecordConfig(
          encoder: AudioEncoder.aacLc,
          sampleRate: 16000,
          numChannels: 1,
        ),
        path: _recordPath!,
      );
      _recording = true;
      _recorder
          .onAmplitudeChanged(const Duration(milliseconds: 200))
          .listen((amp) => onLevel?.call(amp.current));
      // 最多录 6 秒，自动停止并转写
      _autoStop?.cancel();
      _autoStop = Timer(const Duration(seconds: 6), () => stop());
      return true;
    } catch (e) {
      debugPrint("Record start error: $e");
      _lastError = "record_failed";
      return false;
    }
  }

  /// 停止当前输入：系统 STT 停止，或录音停止并触发转写
  Future<void> stop() async {
    if (_recording) {
      await _finishRecording();
    } else {
      try {
        await _stt.stop();
      } catch (e) {
        debugPrint("SpeechService STT stop error: $e");
      }
      _listening = false;
    }
  }

  Future<void> _finishRecording() async {
    _autoStop?.cancel();
    _recording = false;
    String? path;
    try {
      path = await _recorder.stop();
    } catch (e) {
      debugPrint("Record stop error: $e");
    }
    path ??= _recordPath;
    _recordPath = null;
    final cb = _activeOnResult;
    if (path == null || !File(path).existsSync()) {
      _lastError = "record_failed";
      cb?.call("", true, null);
      return;
    }
    try {
      final bytes = await File(path).readAsBytes();
      final form = FormData.fromMap({
        "file": MultipartFile.fromBytes(
          bytes,
          filename: "voice.m4a",
          contentType: DioMediaType("audio", "mp4"),
        ),
      });
      final r = await _api.dio.post("/speech/transcribe", data: form);
      final text = (r.data as Map<String, dynamic>)["text"]?.toString() ?? "";
      cb?.call(text.trim(), true, null);
    } catch (e) {
      debugPrint("Transcribe error: $e");
      _lastError = "transcribe_failed";
      cb?.call("", true, null);
    } finally {
      try {
        File(path).deleteSync();
      } catch (e) {
        debugPrint("Record file cleanup error: $e");
      }
    }
  }
}
