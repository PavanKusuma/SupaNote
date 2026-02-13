import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import '../models/audio_note.dart';
import '../services/storage_service.dart';
import '../theme/app_theme.dart';
import '../widgets/note_card.dart';
import '../widgets/audio_player_widget.dart';
import 'note_detail_screen.dart';
import 'recording_screen.dart';

class HomeScreen extends StatefulWidget {
  const HomeScreen({super.key});

  @override
  State<HomeScreen> createState() => _HomeScreenState();
}

class _HomeScreenState extends State<HomeScreen> with TickerProviderStateMixin {
  final _storage = StorageService();
  List<AudioNote> _notes = [];
  String? _playingNoteId;
  bool _isActuallyPlaying = false;
  bool _isLoading = true;

  @override
  void initState() {
    super.initState();
    _loadNotes();
  }

  Future<void> _loadNotes() async {
    final notes = await _storage.loadNotes();
    if (mounted) {
      setState(() {
        _notes = notes;
        _isLoading = false;
      });
    }
  }

  void _openRecording() async {
    HapticFeedback.mediumImpact();
    final result = await Navigator.of(context).push<AudioNote>(
      PageRouteBuilder(
        pageBuilder: (context, animation, secondaryAnimation) =>
            const RecordingScreen(),
        transitionsBuilder: (context, animation, secondaryAnimation, child) {
          final tween = Tween(begin: const Offset(0, 1), end: Offset.zero)
              .chain(CurveTween(curve: Curves.easeOutCubic));
          return SlideTransition(position: animation.drive(tween), child: child);
        },
        transitionDuration: const Duration(milliseconds: 400),
        reverseTransitionDuration: const Duration(milliseconds: 300),
      ),
    );

    if (result != null) {
      await _loadNotes();
    }
  }

  void _togglePlay(AudioNote note) {
    setState(() {
      if (_playingNoteId == note.id) {
        _playingNoteId = null;
        _isActuallyPlaying = false;
      } else {
        _playingNoteId = note.id;
        _isActuallyPlaying = true;
      }
    });
  }

  void _playNext() {
    if (_playingNoteId == null) return;
    final currentIndex = _notes.indexWhere((n) => n.id == _playingNoteId);
    if (currentIndex == -1) return;
    final nextIndex = (currentIndex + 1) % _notes.length;
    setState(() {
      _playingNoteId = _notes[nextIndex].id;
      _isActuallyPlaying = true;
    });
  }

  void _openDetail(AudioNote note) {
    // Close the bottom player if open
    if (_playingNoteId != null) {
      setState(() {
        _playingNoteId = null;
        _isActuallyPlaying = false;
      });
    }
    Navigator.of(context).push(
      MaterialPageRoute(
        builder: (context) => NoteDetailScreen(note: note),
      ),
    );
  }

  void _deleteNote(String id) async {
    HapticFeedback.mediumImpact();
    if (_playingNoteId == id) {
      setState(() {
        _playingNoteId = null;
        _isActuallyPlaying = false;
      });
    }
    await _storage.deleteNote(id);
    await _loadNotes();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: SafeArea(
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            _buildHeader(context),
            Expanded(
              child: _isLoading
                  ? const Center(
                      child: CircularProgressIndicator(color: AppColors.primary),
                    )
                  : _notes.isEmpty
                      ? _buildEmptyState(context)
                      : _buildNotesList(),
            ),
            if (_playingNoteId != null) _buildPlayer(),
          ],
        ),
      ),
      floatingActionButton: _buildFAB(),
    );
  }

  Widget _buildHeader(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.fromLTRB(24, 20, 24, 8),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            'SupaNote',
            style: Theme.of(context).textTheme.headlineLarge,
          ),
          const SizedBox(height: 4),
          Text(
            _notes.isEmpty
                ? 'Capture your thoughts'
                : '${_notes.length} note${_notes.length == 1 ? '' : 's'}',
            style: Theme.of(context).textTheme.bodyLarge,
          ),
        ],
      ),
    );
  }

  Widget _buildEmptyState(BuildContext context) {
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(48),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Container(
              width: 80,
              height: 80,
              decoration: BoxDecoration(
                color: AppColors.primary.withValues(alpha: 0.1),
                borderRadius: BorderRadius.circular(24),
              ),
              child: const Icon(
                Icons.mic_none_rounded,
                size: 40,
                color: AppColors.primary,
              ),
            ),
            const SizedBox(height: 24),
            Text(
              'No notes yet',
              style: Theme.of(context).textTheme.headlineMedium,
            ),
            const SizedBox(height: 8),
            Text(
              'Tap the button below to\nrecord your first audio note',
              textAlign: TextAlign.center,
              style: Theme.of(context).textTheme.bodyLarge,
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildNotesList() {
    return RefreshIndicator(
      onRefresh: _loadNotes,
      color: AppColors.primary,
      child: ListView.builder(
        padding: const EdgeInsets.only(top: 8, bottom: 100),
        itemCount: _notes.length,
        itemBuilder: (context, index) {
          final note = _notes[index];
          return NoteCard(
            note: note,
            isPlaying: _playingNoteId == note.id && _isActuallyPlaying,
            onPlay: () => _togglePlay(note),
            onDelete: () => _deleteNote(note.id),
            onTap: () => _openDetail(note),
          );
        },
      ),
    );
  }

  Widget _buildPlayer() {
    final index = _notes.indexWhere((n) => n.id == _playingNoteId);
    if (index == -1) {
      WidgetsBinding.instance.addPostFrameCallback((_) {
        if (mounted) setState(() => _playingNoteId = null);
      });
      return const SizedBox.shrink();
    }
    final note = _notes[index];
    final hasNext = _notes.length > 1;
    return AudioPlayerWidget(
      key: ValueKey(note.id),
      filePath: note.filePath,
      totalDuration: note.duration,
      noteTitle: note.title,
      onClose: () {
        setState(() {
          _playingNoteId = null;
          _isActuallyPlaying = false;
        });
      },
      onNext: hasNext ? _playNext : null,
      onPlayStateChanged: (isPlaying) {
        if (mounted) {
          setState(() => _isActuallyPlaying = isPlaying);
        }
      },
    );
  }

  Widget _buildFAB() {
    return FloatingActionButton.extended(
      onPressed: _openRecording,
      icon: const Icon(Icons.mic_rounded, size: 22),
      label: const Text(
        'Record',
        style: TextStyle(fontWeight: FontWeight.w600, fontSize: 15),
      ),
      elevation: 3,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(18)),
    );
  }
}
