import 'dart:convert';

class AudioNote {
  final String id;
  final String title;
  final String filePath;
  final Duration duration;
  final DateTime createdAt;

  AudioNote({
    required this.id,
    required this.title,
    required this.filePath,
    required this.duration,
    required this.createdAt,
  });

  Map<String, dynamic> toJson() => {
        'id': id,
        'title': title,
        'filePath': filePath,
        'durationMs': duration.inMilliseconds,
        'createdAt': createdAt.toIso8601String(),
      };

  factory AudioNote.fromJson(Map<String, dynamic> json) => AudioNote(
        id: json['id'] as String,
        title: json['title'] as String,
        filePath: json['filePath'] as String,
        duration: Duration(milliseconds: json['durationMs'] as int),
        createdAt: DateTime.parse(json['createdAt'] as String),
      );

  static String encodeList(List<AudioNote> notes) =>
      jsonEncode(notes.map((n) => n.toJson()).toList());

  static List<AudioNote> decodeList(String jsonStr) {
    final list = jsonDecode(jsonStr) as List;
    return list.map((e) => AudioNote.fromJson(e as Map<String, dynamic>)).toList();
  }

  String get formattedDuration {
    final minutes = duration.inMinutes.remainder(60).toString().padLeft(2, '0');
    final seconds = duration.inSeconds.remainder(60).toString().padLeft(2, '0');
    if (duration.inHours > 0) {
      final hours = duration.inHours.toString().padLeft(2, '0');
      return '$hours:$minutes:$seconds';
    }
    return '$minutes:$seconds';
  }
}
