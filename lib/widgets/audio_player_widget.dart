import 'dart:async';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:audioplayers/audioplayers.dart';
import '../services/audio_player_service.dart';
import '../theme/app_theme.dart';

class AudioPlayerWidget extends StatefulWidget {
  final String filePath;
  final Duration totalDuration;
  final String noteTitle;
  final VoidCallback? onClose;
  final VoidCallback? onNext;
  final ValueChanged<bool>? onPlayStateChanged;

  const AudioPlayerWidget({
    super.key,
    required this.filePath,
    required this.totalDuration,
    required this.noteTitle,
    this.onClose,
    this.onNext,
    this.onPlayStateChanged,
  });

  @override
  State<AudioPlayerWidget> createState() => _AudioPlayerWidgetState();
}

class _AudioPlayerWidgetState extends State<AudioPlayerWidget>
    with SingleTickerProviderStateMixin {
  final _player = AudioPlayerService();
  final List<StreamSubscription> _subscriptions = [];
  Duration _position = Duration.zero;
  Duration _duration = Duration.zero;
  bool _isPlaying = false;
  bool _completed = false;
  late AnimationController _animController;

  @override
  void initState() {
    super.initState();
    _duration = widget.totalDuration;
    _animController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 300),
    );

    _subscriptions.add(
      _player.positionStream.listen((pos) {
        if (mounted) setState(() => _position = pos);
      }),
    );
    _subscriptions.add(
      _player.durationStream.listen((dur) {
        if (mounted && dur.inMilliseconds > 0) setState(() => _duration = dur);
      }),
    );
    _subscriptions.add(
      _player.stateStream.listen((state) {
        if (!mounted) return;
        final playing = state == PlayerState.playing;
        setState(() {
          _isPlaying = playing;
          if (state == PlayerState.completed) {
            _completed = true;
            _position = _duration;
          }
        });
        widget.onPlayStateChanged?.call(playing);
        if (playing) {
          _animController.forward();
        } else {
          _animController.reverse();
        }
      }),
    );

    _player.play(widget.filePath);
  }

  @override
  void dispose() {
    for (final sub in _subscriptions) {
      sub.cancel();
    }
    _animController.dispose();
    _player.dispose();
    super.dispose();
  }

  void _togglePlayPause() {
    HapticFeedback.lightImpact();
    if (_isPlaying) {
      _player.pause();
    } else {
      if (_completed || _position >= _duration) {
        setState(() {
          _completed = false;
          _position = Duration.zero;
        });
        _player.play(widget.filePath);
      } else {
        _player.resume();
      }
    }
  }

  void _seekRelative(Duration offset) {
    HapticFeedback.selectionClick();
    final newPos = _position + offset;
    _player.seek(Duration(
      milliseconds: newPos.inMilliseconds.clamp(0, _duration.inMilliseconds),
    ));
  }

  void _handleNext() {
    HapticFeedback.mediumImpact();
    widget.onNext?.call();
  }

  String _formatDuration(Duration d) {
    final minutes = d.inMinutes.remainder(60).toString().padLeft(2, '0');
    final seconds = d.inSeconds.remainder(60).toString().padLeft(2, '0');
    return '$minutes:$seconds';
  }

  @override
  Widget build(BuildContext context) {
    final progress = _duration.inMilliseconds > 0
        ? _position.inMilliseconds / _duration.inMilliseconds
        : 0.0;

    return Container(
      margin: const EdgeInsets.all(20),
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: AppColors.surface,
        borderRadius: BorderRadius.circular(24),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.08),
            blurRadius: 24,
            offset: const Offset(0, 8),
          ),
        ],
      ),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          // Close handle
          if (widget.onClose != null)
            GestureDetector(
              onTap: () {
                HapticFeedback.lightImpact();
                widget.onClose!();
              },
              child: Container(
                width: 36,
                height: 4,
                margin: const EdgeInsets.only(bottom: 12),
                decoration: BoxDecoration(
                  color: AppColors.divider,
                  borderRadius: BorderRadius.circular(2),
                ),
              ),
            ),

          // Note title
          Padding(
            padding: const EdgeInsets.only(bottom: 14),
            child: Text(
              widget.noteTitle,
              style: Theme.of(context).textTheme.titleMedium?.copyWith(
                    fontWeight: FontWeight.w600,
                  ),
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
            ),
          ),

          // Progress bar
          ClipRRect(
            borderRadius: BorderRadius.circular(4),
            child: LinearProgressIndicator(
              value: progress.clamp(0.0, 1.0),
              backgroundColor: AppColors.surfaceVariant,
              valueColor:
                  const AlwaysStoppedAnimation<Color>(AppColors.primary),
              minHeight: 4,
            ),
          ),
          const SizedBox(height: 8),

          // Time labels
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Text(
                _formatDuration(_position),
                style: Theme.of(context).textTheme.bodySmall?.copyWith(
                      fontFeatures: [const FontFeature.tabularFigures()],
                    ),
              ),
              Text(
                _formatDuration(_duration),
                style: Theme.of(context).textTheme.bodySmall?.copyWith(
                      fontFeatures: [const FontFeature.tabularFigures()],
                    ),
              ),
            ],
          ),
          const SizedBox(height: 12),

          // Playback controls
          Row(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              // Rewind 10s
              IconButton(
                onPressed: () => _seekRelative(const Duration(seconds: -10)),
                icon: const Icon(Icons.replay_10_rounded),
                iconSize: 32,
                color: AppColors.textSecondary,
              ),
              const SizedBox(width: 12),

              // Play/Pause
              GestureDetector(
                onTap: _togglePlayPause,
                child: Container(
                  width: 56,
                  height: 56,
                  alignment: Alignment.center,
                  decoration: BoxDecoration(
                    color: AppColors.primary,
                    borderRadius: BorderRadius.circular(18),
                  ),
                  child: AnimatedIcon(
                    icon: AnimatedIcons.play_pause,
                    progress: _animController,
                    color: Colors.white,
                    size: 30,
                  ),
                ),
              ),
              const SizedBox(width: 12),

              // Forward 10s
              IconButton(
                onPressed: () => _seekRelative(const Duration(seconds: 10)),
                icon: const Icon(Icons.forward_10_rounded),
                iconSize: 32,
                color: AppColors.textSecondary,
              ),

              // Next button
              if (widget.onNext != null) ...[
                const SizedBox(width: 4),
                IconButton(
                  onPressed: _handleNext,
                  icon: const Icon(Icons.skip_next_rounded),
                  iconSize: 32,
                  color: AppColors.textSecondary,
                ),
              ],
            ],
          ),
        ],
      ),
    );
  }
}
