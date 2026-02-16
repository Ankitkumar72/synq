import 'dart:async';
import 'dart:convert';
import 'dart:io';

import 'package:path_provider/path_provider.dart';

import '../domain/models/note.dart';
import 'notes_repository.dart';

class LocalVaultNotesRepository implements NotesRepository {
  static const String _vaultDirectoryName = 'synq_vault';
  static const String _folderMetadataFileName = '.folder.json';
  static const String _frontmatterDelimiter = '---';

  final StreamController<List<Note>> _controller =
      StreamController<List<Note>>.broadcast();

  Directory? _vaultRoot;
  bool _initialized = false;
  final List<Note> _cache = <Note>[];
  final Map<String, File> _noteFilesById = <String, File>{};

  void dispose() {
    _controller.close();
  }

  @override
  Stream<List<Note>> watchNotes() async* {
    await _ensureInitialized();
    yield List<Note>.unmodifiable(_cache);
    yield* _controller.stream;
  }

  @override
  Future<void> addNote(Note note) async {
    await _ensureInitialized();
    await _writeNote(note);
    _upsertCache(note);
    _emit();
  }

  @override
  Future<void> updateNote(Note note) async {
    await _ensureInitialized();
    await _writeNote(note);
    _upsertCache(note);
    _emit();
  }

  @override
  Future<void> deleteNote(String id) async {
    await _ensureInitialized();

    final existingFile = _noteFilesById[id];
    if (existingFile != null && await existingFile.exists()) {
      await existingFile.delete();
    }

    _noteFilesById.remove(id);
    _cache.removeWhere((note) => note.id == id);
    _emit();
  }

  @override
  Future<void> deleteNotes(List<String> ids) async {
    for (final id in ids) {
      await deleteNote(id);
    }
  }

  Future<void> _ensureInitialized() async {
    if (_initialized) return;

    final docsDir = await getApplicationDocumentsDirectory();
    _vaultRoot = Directory(
      '${docsDir.path}${Platform.pathSeparator}$_vaultDirectoryName',
    );
    if (!await _vaultRoot!.exists()) {
      await _vaultRoot!.create(recursive: true);
    }

    await _reloadFromDisk();
    _initialized = true;
  }

  Future<void> _reloadFromDisk() async {
    _cache.clear();
    _noteFilesById.clear();

    await for (final entity
        in _vaultRoot!.list(recursive: true, followLinks: false)) {
      if (entity is! File) continue;
      if (!_isMarkdown(entity.path)) continue;
      if (_isHiddenPath(entity.path)) continue;

      final parsed = await _readNote(entity);
      if (parsed == null) continue;

      _cache.add(parsed);
      _noteFilesById[parsed.id] = entity;
    }

    _cache.sort((a, b) => b.createdAt.compareTo(a.createdAt));
  }

  Future<void> _writeNote(Note note) async {
    final folderDirectories = await _folderDirectoriesById();
    final targetDirectory = _resolveTargetDirectory(note.folderId, folderDirectories);

    if (!await targetDirectory.exists()) {
      await targetDirectory.create(recursive: true);
    }

    final targetFile = File(
      '${targetDirectory.path}${Platform.pathSeparator}'
      '${_safeFileName(note.title, fallback: 'note')}--${note.id}.md',
    );

    final oldFile = _noteFilesById[note.id];
    await targetFile.writeAsString(_serialize(note));
    _noteFilesById[note.id] = targetFile;

    if (oldFile != null &&
        oldFile.path != targetFile.path &&
        await oldFile.exists()) {
      await oldFile.delete();
    }
  }

  Future<Note?> _readNote(File file) async {
    final content = await file.readAsString();
    final normalized = content.replaceAll('\r\n', '\n');

    final match = RegExp(
      '^$_frontmatterDelimiter\\n([\\s\\S]*?)\\n$_frontmatterDelimiter\\n?',
      dotAll: true,
    ).firstMatch(normalized);
    if (match == null) return null;

    final metadataBlock = match.group(1) ?? '';
    final body = normalized.substring(match.end);
    final metadata = <String, dynamic>{};

    for (final line in const LineSplitter().convert(metadataBlock)) {
      final trimmed = line.trim();
      if (trimmed.isEmpty) continue;

      final separatorIndex = trimmed.indexOf(':');
      if (separatorIndex <= 0) continue;

      final key = trimmed.substring(0, separatorIndex).trim();
      final rawValue = trimmed.substring(separatorIndex + 1).trim();
      if (rawValue.isEmpty) continue;

      try {
        metadata[key] = jsonDecode(rawValue);
      } catch (_) {
        metadata[key] = rawValue;
      }
    }

    metadata['body'] = body.isEmpty ? null : body;

    try {
      return Note.fromJson(metadata);
    } catch (_) {
      return null;
    }
  }

  String _serialize(Note note) {
    final json = Map<String, dynamic>.from(note.toJson());
    final body = note.body ?? '';
    json.remove('body');

    final keys = json.keys.toList()..sort();
    final buffer = StringBuffer()..writeln(_frontmatterDelimiter);

    for (final key in keys) {
      buffer.writeln('$key: ${jsonEncode(json[key])}');
    }

    buffer.writeln(_frontmatterDelimiter);
    if (body.isNotEmpty) {
      buffer.write(body);
    }
    return buffer.toString();
  }

  Future<Map<String, Directory>> _folderDirectoriesById() async {
    final result = <String, Directory>{};

    await for (final entity in _vaultRoot!.list(followLinks: false)) {
      if (entity is! Directory) continue;
      if (_isHiddenPath(entity.path)) continue;

      final metadataFile = File(
        '${entity.path}${Platform.pathSeparator}$_folderMetadataFileName',
      );
      if (!await metadataFile.exists()) continue;

      try {
        final json = jsonDecode(await metadataFile.readAsString())
            as Map<String, dynamic>;
        final id = json['id'];
        if (id is String && id.isNotEmpty) {
          result[id] = entity;
        }
      } catch (_) {
        continue;
      }
    }

    return result;
  }

  Directory _resolveTargetDirectory(
    String? folderId,
    Map<String, Directory> folderDirectories,
  ) {
    if (folderId == null || folderId.isEmpty) {
      return _vaultRoot!;
    }
    return folderDirectories[folderId] ?? _vaultRoot!;
  }

  void _upsertCache(Note note) {
    final index = _cache.indexWhere((n) => n.id == note.id);
    if (index == -1) {
      _cache.add(note);
    } else {
      _cache[index] = note;
    }
    _cache.sort((a, b) => b.createdAt.compareTo(a.createdAt));
  }

  void _emit() {
    _controller.add(List<Note>.unmodifiable(_cache));
  }

  static bool _isMarkdown(String path) {
    return path.toLowerCase().endsWith('.md');
  }

  static bool _isHiddenPath(String path) {
    final normalized = path.replaceAll('\\', '/');
    final segments = normalized.split('/');
    for (final segment in segments) {
      if (segment.startsWith('.')) return true;
    }
    return false;
  }

  static String _safeFileName(String raw, {required String fallback}) {
    final cleaned = raw
        .replaceAll(RegExp(r'[<>:"/\\|?*\x00-\x1F]'), ' ')
        .replaceAll(RegExp(r'\s+'), ' ')
        .trim();
    final base = cleaned.isEmpty ? fallback : cleaned;
    return base.length <= 64 ? base : base.substring(0, 64);
  }
}
