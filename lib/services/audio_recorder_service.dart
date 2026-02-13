import 'dart:async';
import 'dart:io';
import 'package:record/record.dart';
import 'package:path_provider/path_provider.dart';
import 'package:path/path.dart' as p;
import 'package:uuid/uuid.dart';

enum RecordingState { idle, recording, paused }

class AudioRecorderService {
  final AudioRecorder _recorder = AudioRecorder();
  RecordingState _state = RecordingState.idle;
  String? _currentFilePath;
  Timer? _timer;
  Duration _elapsed = Duration.zero;
  final _uuid = const Uuid();

  final _stateController = StreamController<RecordingState>.broadcast();
  final _durationController = StreamController<Duration>.broadcast();
  final _amplitudeController = StreamController<double>.broadcast();
  Timer? _amplitudeTimer;

  Stream<RecordingState> get stateStream => _stateController.stream;
  Stream<Duration> get durationStream => _durationController.stream;
  Stream<double> get amplitudeStream => _amplitudeController.stream;
  RecordingState get state => _state;
  Duration get elapsed => _elapsed;
  String? get currentFilePath => _currentFilePath;

  Future<bool> hasPermission() async {
    return await _recorder.hasPermission();
  }

  Future<void> startRecording() async {
    if (_state != RecordingState.idle) return;

    final hasPerm = await _recorder.hasPermission();
    if (!hasPerm) return;

    final dir = await getApplicationDocumentsDirectory();
    final notesDir = p.join(dir.path, 'audio_notes');
    await _ensureDirectory(notesDir);

    final fileName = '${_uuid.v4()}.m4a';
    _currentFilePath = p.join(notesDir, fileName);

    await _recorder.start(
      const RecordConfig(
        encoder: AudioEncoder.aacLc,
        bitRate: 128000,
        sampleRate: 44100,
      ),
      path: _currentFilePath!,
    );

    _elapsed = Duration.zero;
    _state = RecordingState.recording;
    _stateController.add(_state);
    _durationController.add(_elapsed);
    _startTimer();
    _startAmplitudeMonitor();
  }

  Future<void> pauseRecording() async {
    if (_state != RecordingState.recording) return;

    await _recorder.pause();
    _state = RecordingState.paused;
    _stateController.add(_state);
    _stopTimer();
    _stopAmplitudeMonitor();
  }

  Future<void> resumeRecording() async {
    if (_state != RecordingState.paused) return;

    await _recorder.resume();
    _state = RecordingState.recording;
    _stateController.add(_state);
    _startTimer();
    _startAmplitudeMonitor();
  }

  Future<String?> stopRecording() async {
    if (_state == RecordingState.idle) return null;

    final path = await _recorder.stop();
    _state = RecordingState.idle;
    _stateController.add(_state);
    _stopTimer();
    _stopAmplitudeMonitor();

    final filePath = path ?? _currentFilePath;
    _currentFilePath = null;
    return filePath;
  }

  Future<void> cancelRecording() async {
    final path = await stopRecording();
    if (path != null) {
      try {
        final file = File(path);
        if (await file.exists()) {
          await file.delete();
        }
      } catch (_) {}
    }
  }

  void _startTimer() {
    _timer = Timer.periodic(const Duration(milliseconds: 100), (_) {
      _elapsed += const Duration(milliseconds: 100);
      _durationController.add(_elapsed);
    });
  }

  void _stopTimer() {
    _timer?.cancel();
    _timer = null;
  }

  void _startAmplitudeMonitor() {
    _amplitudeTimer = Timer.periodic(
      const Duration(milliseconds: 100),
      (_) async {
        try {
          final amp = await _recorder.getAmplitude();
          final normalized = (amp.current + 50) / 50;
          _amplitudeController.add(normalized.clamp(0.0, 1.0));
        } catch (_) {
          _amplitudeController.add(0.0);
        }
      },
    );
  }

  void _stopAmplitudeMonitor() {
    _amplitudeTimer?.cancel();
    _amplitudeTimer = null;
  }

  Future<void> _ensureDirectory(String path) async {
    final dir = Directory(path);
    if (!await dir.exists()) {
      await dir.create(recursive: true);
    }
  }

  void dispose() {
    _stopTimer();
    _stopAmplitudeMonitor();
    _stateController.close();
    _durationController.close();
    _amplitudeController.close();
    _recorder.dispose();
  }
}
