import 'dart:async';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:uuid/uuid.dart';
import '../models/audio_note.dart';
import '../services/audio_recorder_service.dart';
import '../services/storage_service.dart';
import '../theme/app_theme.dart';
import '../widgets/waveform_painter.dart';

class RecordingScreen extends StatefulWidget {
  const RecordingScreen({super.key});

  @override
  State<RecordingScreen> createState() => _RecordingScreenState();
}

class _RecordingScreenState extends State<RecordingScreen>
    with TickerProviderStateMixin {
  final _recorder = AudioRecorderService();
  final _storage = StorageService();
  final _titleController = TextEditingController();

  RecordingState _state = RecordingState.idle;
  Duration _elapsed = Duration.zero;
  final List<double> _amplitudes = [];
  bool _isSaving = false;

  late AnimationController _pulseController;
  late Animation<double> _pulseAnimation;
  late AnimationController _fadeController;

  final List<StreamSubscription> _subscriptions = [];

  @override
  void initState() {
    super.initState();

    _pulseController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 1200),
    );
    _pulseAnimation = Tween<double>(begin: 1.0, end: 1.15).animate(
      CurvedAnimation(parent: _pulseController, curve: Curves.easeInOut),
    );

    _fadeController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 400),
    );
    _subscriptions.add(
      _recorder.stateStream.listen((state) {
        if (!mounted) return;
        setState(() => _state = state);
        if (state == RecordingState.recording) {
          _pulseController.repeat(reverse: true);
        } else {
          _pulseController.stop();
          _pulseController.value = 0;
        }
      }),
    );

    _subscriptions.add(
      _recorder.durationStream.listen((d) {
        if (mounted) setState(() => _elapsed = d);
      }),
    );

    _subscriptions.add(
      _recorder.amplitudeStream.listen((amp) {
        if (mounted) {
          setState(() => _amplitudes.add(amp));
        }
      }),
    );

    // Auto-start recording
    _startRecording();
  }

  @override
  void dispose() {
    for (final sub in _subscriptions) {
      sub.cancel();
    }
    _pulseController.dispose();
    _fadeController.dispose();
    _titleController.dispose();
    _recorder.dispose();
    super.dispose();
  }

  Future<void> _startRecording() async {
    HapticFeedback.mediumImpact();
    await _recorder.startRecording();
  }

  Future<void> _togglePauseResume() async {
    HapticFeedback.lightImpact();
    if (_state == RecordingState.recording) {
      await _recorder.pauseRecording();
    } else if (_state == RecordingState.paused) {
      await _recorder.resumeRecording();
    }
  }

  Future<void> _stopAndSave() async {
    HapticFeedback.mediumImpact();
    final filePath = await _recorder.stopRecording();
    if (filePath == null) return;

    setState(() => _isSaving = true);
    _fadeController.forward();

    final title = await _showTitleDialog();

    if (title == null) {
      // User cancelled - delete the file
      await _recorder.cancelRecording();
      if (mounted) Navigator.of(context).pop();
      return;
    }

    final note = AudioNote(
      id: const Uuid().v4(),
      title: title.isEmpty ? _defaultTitle() : title,
      filePath: filePath,
      duration: _elapsed,
      createdAt: DateTime.now(),
    );

    await _storage.addNote(note);
    if (mounted) Navigator.of(context).pop(note);
  }

  Future<void> _cancelRecording() async {
    HapticFeedback.lightImpact();
    final confirm = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        backgroundColor: AppColors.surface,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
        title: const Text('Discard Recording?'),
        content: const Text('This recording will be permanently deleted.'),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            child: Text('Keep Recording',
                style: TextStyle(color: AppColors.textSecondary)),
          ),
          TextButton(
            onPressed: () => Navigator.pop(context, true),
            child:
                const Text('Discard', style: TextStyle(color: AppColors.error)),
          ),
        ],
      ),
    );

    if (confirm == true) {
      await _recorder.cancelRecording();
      if (mounted) Navigator.of(context).pop();
    }
  }

  Future<String?> _showTitleDialog() async {
    _titleController.text = _defaultTitle();
    _titleController.selection = TextSelection(
      baseOffset: 0,
      extentOffset: _titleController.text.length,
    );

    return showDialog<String>(
      context: context,
      barrierDismissible: false,
      builder: (context) => AlertDialog(
        backgroundColor: AppColors.surface,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
        title: const Text('Save Note'),
        titleTextStyle: Theme.of(context).textTheme.titleLarge,
        content: TextField(
          controller: _titleController,
          autofocus: true,
          textCapitalization: TextCapitalization.sentences,
          decoration: InputDecoration(
            hintText: 'Note title',
            hintStyle: TextStyle(color: AppColors.textTertiary),
            filled: true,
            fillColor: AppColors.surfaceVariant,
            border: OutlineInputBorder(
              borderRadius: BorderRadius.circular(12),
              borderSide: BorderSide.none,
            ),
            contentPadding:
                const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, null),
            child: Text('Discard',
                style: TextStyle(color: AppColors.textSecondary)),
          ),
          TextButton(
            onPressed: () => Navigator.pop(context, _titleController.text),
            child: const Text('Save',
                style: TextStyle(
                    color: AppColors.primary, fontWeight: FontWeight.w600)),
          ),
        ],
      ),
    );
  }

  String _defaultTitle() {
    final now = DateTime.now();
    final hour = now.hour;
    String timeOfDay;
    if (hour < 12) {
      timeOfDay = 'Morning';
    } else if (hour < 17) {
      timeOfDay = 'Afternoon';
    } else {
      timeOfDay = 'Evening';
    }
    return '$timeOfDay Note';
  }

  String _formatElapsed(Duration d) {
    final minutes = d.inMinutes.remainder(60).toString().padLeft(2, '0');
    final seconds = d.inSeconds.remainder(60).toString().padLeft(2, '0');
    final tenths = (d.inMilliseconds.remainder(1000) ~/ 100).toString();
    if (d.inHours > 0) {
      final hours = d.inHours.toString().padLeft(2, '0');
      return '$hours:$minutes:$seconds.$tenths';
    }
    return '$minutes:$seconds.$tenths';
  }

  @override
  Widget build(BuildContext context) {
    final isRecording = _state == RecordingState.recording;
    final isPaused = _state == RecordingState.paused;

    return Scaffold(
      backgroundColor: AppColors.background,
      body: SafeArea(
        child: Column(
          children: [
            _buildTopBar(),
            const Spacer(flex: 2),
            _buildTimer(context),
            const SizedBox(height: 8),
            _buildStateLabel(context, isRecording, isPaused),
            const Spacer(flex: 1),
            _buildWaveform(),
            const Spacer(flex: 1),
            _buildControls(isRecording, isPaused),
            const Spacer(flex: 2),
          ],
        ),
      ),
    );
  }

  Widget _buildTopBar() {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 8),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          IconButton(
            onPressed: _state == RecordingState.idle ? null : _cancelRecording,
            icon: const Icon(Icons.close_rounded),
            iconSize: 26,
            color: AppColors.textSecondary,
          ),
          if (_state != RecordingState.idle)
            TextButton(
              onPressed: _isSaving ? null : _stopAndSave,
              child: Text(
                'Done',
                style: TextStyle(
                  color: _isSaving ? AppColors.textTertiary : AppColors.primary,
                  fontWeight: FontWeight.w600,
                  fontSize: 16,
                ),
              ),
            ),
        ],
      ),
    );
  }

  Widget _buildTimer(BuildContext context) {
    return Text(
      _formatElapsed(_elapsed),
      style: TextStyle(
        fontSize: 56,
        fontWeight: FontWeight.w300,
        color: AppColors.textPrimary,
        letterSpacing: 2,
        fontFeatures: const [FontFeature.tabularFigures()],
      ),
    );
  }

  Widget _buildStateLabel(
      BuildContext context, bool isRecording, bool isPaused) {
    final label = isRecording
        ? 'Recording'
        : isPaused
            ? 'Paused'
            : 'Ready';
    final color = isRecording
        ? AppColors.recording
        : isPaused
            ? AppColors.paused
            : AppColors.textTertiary;

    return Row(
      mainAxisAlignment: MainAxisAlignment.center,
      children: [
        if (isRecording)
          Container(
            width: 8,
            height: 8,
            margin: const EdgeInsets.only(right: 8),
            decoration: BoxDecoration(
              color: color,
              shape: BoxShape.circle,
            ),
          ),
        if (isPaused)
          Container(
            width: 8,
            height: 8,
            margin: const EdgeInsets.only(right: 8),
            decoration: BoxDecoration(
              color: color,
              borderRadius: BorderRadius.circular(2),
            ),
          ),
        Text(
          label,
          style: TextStyle(
            fontSize: 15,
            fontWeight: FontWeight.w500,
            color: color,
          ),
        ),
      ],
    );
  }

  Widget _buildWaveform() {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 32),
      child: LiveWaveform(
        amplitudes: _amplitudes,
        height: 100,
        color: _state == RecordingState.paused
            ? AppColors.paused.withValues(alpha: 0.5)
            : AppColors.primary,
      ),
    );
  }

  Widget _buildControls(bool isRecording, bool isPaused) {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 40),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceEvenly,
        children: [
          // Cancel button
          _buildControlButton(
            onTap: _cancelRecording,
            icon: Icons.delete_outline_rounded,
            label: 'Discard',
            color: AppColors.textSecondary,
            size: 52,
          ),

          // Main pause/resume button
          ScaleTransition(
            scale: _pulseAnimation,
            child: _buildMainButton(isRecording, isPaused),
          ),

          // Stop/Save button
          _buildControlButton(
            onTap: _isSaving ? null : _stopAndSave,
            icon: Icons.check_rounded,
            label: 'Save',
            color: AppColors.primary,
            size: 52,
          ),
        ],
      ),
    );
  }

  Widget _buildMainButton(bool isRecording, bool isPaused) {
    return GestureDetector(
      onTap: _togglePauseResume,
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 250),
        curve: Curves.easeInOut,
        width: 80,
        height: 80,
        decoration: BoxDecoration(
          color: isRecording ? AppColors.recording : AppColors.primary,
          borderRadius: BorderRadius.circular(isRecording ? 24 : 40),
          boxShadow: [
            BoxShadow(
              color: (isRecording ? AppColors.recording : AppColors.primary)
                  .withValues(alpha: 0.3),
              blurRadius: 20,
              offset: const Offset(0, 6),
            ),
          ],
        ),
        child: AnimatedSwitcher(
          duration: const Duration(milliseconds: 200),
          child: Icon(
            isPaused ? Icons.mic_rounded : Icons.pause_rounded,
            key: ValueKey(isPaused),
            color: Colors.white,
            size: 36,
          ),
        ),
      ),
    );
  }

  Widget _buildControlButton({
    required VoidCallback? onTap,
    required IconData icon,
    required String label,
    required Color color,
    required double size,
  }) {
    return GestureDetector(
      onTap: onTap,
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Container(
            width: size,
            height: size,
            decoration: BoxDecoration(
              color: color.withValues(alpha: 0.1),
              borderRadius: BorderRadius.circular(size / 3),
            ),
            child: Icon(icon, color: color, size: 24),
          ),
          const SizedBox(height: 8),
          Text(
            label,
            style: TextStyle(
              fontSize: 12,
              fontWeight: FontWeight.w500,
              color: color,
            ),
          ),
        ],
      ),
    );
  }
}
