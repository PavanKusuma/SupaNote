import 'package:speech_to_text/speech_to_text.dart';
import 'package:speech_to_text/speech_recognition_result.dart';

class SpeechService {
  final SpeechToText _speech = SpeechToText();
  bool _isAvailable = false;
  bool _shouldListen = false;
  String _currentSegment = '';
  final List<String> _segments = [];

  Future<bool> initialize() async {
    _isAvailable = await _speech.initialize(
      onError: (_) {},
      onStatus: (status) {
        // Restart listening when a session ends naturally (silence/timeout)
        if ((status == 'done' || status == 'notListening') && _shouldListen) {
          _restartListening();
        }
      },
    );
    return _isAvailable;
  }

  bool get isAvailable => _isAvailable;

  Future<void> startListening() async {
    if (!_isAvailable) return;
    _shouldListen = true;
    _segments.clear();
    _currentSegment = '';
    await _beginSession();
  }

  Future<void> pauseListening() async {
    _shouldListen = false;
    await _speech.stop();
    // Finalize any partial result
    if (_currentSegment.isNotEmpty) {
      _segments.add(_currentSegment);
      _currentSegment = '';
    }
  }

  Future<void> resumeListening() async {
    if (!_isAvailable) return;
    _shouldListen = true;
    await _beginSession();
  }

  Future<String> stopListening() async {
    _shouldListen = false;
    await _speech.stop();
    if (_currentSegment.isNotEmpty) {
      _segments.add(_currentSegment);
      _currentSegment = '';
    }
    return transcript;
  }

  String get transcript {
    final parts = [..._segments];
    if (_currentSegment.isNotEmpty) parts.add(_currentSegment);
    return parts.join(' ').trim();
  }

  Future<void> _beginSession() async {
    if (!_shouldListen || !_isAvailable) return;
    try {
      await _speech.listen(
        onResult: _onResult,
        listenOptions: SpeechListenOptions(
          listenMode: ListenMode.dictation,
          cancelOnError: false,
          partialResults: true,
        ),
      );
    } catch (_) {}
  }

  void _onResult(SpeechRecognitionResult result) {
    _currentSegment = result.recognizedWords;
    if (result.finalResult) {
      if (_currentSegment.isNotEmpty) {
        _segments.add(_currentSegment);
      }
      _currentSegment = '';
    }
  }

  Future<void> _restartListening() async {
    // Small delay before restarting to avoid rapid cycling
    await Future.delayed(const Duration(milliseconds: 200));
    if (_shouldListen) {
      await _beginSession();
    }
  }

  void dispose() {
    _shouldListen = false;
    _speech.cancel();
  }
}
