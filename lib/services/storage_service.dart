import 'dart:io';
import 'package:path_provider/path_provider.dart';
import 'package:path/path.dart' as p;
import '../models/audio_note.dart';

class StorageService {
  static const _notesFileName = 'audio_notes.json';

  Future<String> get _notesDir async {
    final dir = await getApplicationDocumentsDirectory();
    final notesDir = Directory(p.join(dir.path, 'audio_notes'));
    if (!await notesDir.exists()) {
      await notesDir.create(recursive: true);
    }
    return notesDir.path;
  }

  Future<File> get _notesFile async {
    final dir = await getApplicationDocumentsDirectory();
    return File(p.join(dir.path, _notesFileName));
  }

  Future<String> get recordingsPath async => _notesDir;

  Future<List<AudioNote>> loadNotes() async {
    try {
      final file = await _notesFile;
      if (await file.exists()) {
        final contents = await file.readAsString();
        if (contents.isNotEmpty) {
          final notes = AudioNote.decodeList(contents);
          notes.sort((a, b) => b.createdAt.compareTo(a.createdAt));
          return notes;
        }
      }
    } catch (_) {}
    return [];
  }

  Future<void> saveNotes(List<AudioNote> notes) async {
    final file = await _notesFile;
    await file.writeAsString(AudioNote.encodeList(notes));
  }

  Future<void> addNote(AudioNote note) async {
    final notes = await loadNotes();
    notes.insert(0, note);
    await saveNotes(notes);
  }

  Future<void> deleteNote(String id) async {
    final notes = await loadNotes();
    final index = notes.indexWhere((n) => n.id == id);
    if (index == -1) return;
    final note = notes[index];
    final file = File(note.filePath);
    if (await file.exists()) {
      await file.delete();
    }
    notes.removeAt(index);
    await saveNotes(notes);
  }

  Future<void> updateNote(AudioNote updated) async {
    final notes = await loadNotes();
    final index = notes.indexWhere((n) => n.id == updated.id);
    if (index != -1) {
      notes[index] = updated;
      await saveNotes(notes);
    }
  }
}
