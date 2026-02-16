import 'dart:async';
import 'dart:convert';
import 'dart:io';

import 'package:path_provider/path_provider.dart';

import '../domain/models/folder.dart';
import 'folders_repository.dart';

class LocalVaultFoldersRepository implements FoldersRepository {
  static const String _vaultDirectoryName = 'synq_vault';
  static const String _folderMetadataFileName = '.folder.json';

  final StreamController<List<Folder>> _controller =
      StreamController<List<Folder>>.broadcast();

  Directory? _vaultRoot;
  bool _initialized = false;
  final Map<String, _FolderRecord> _recordsById = <String, _FolderRecord>{};

  void dispose() {
    _controller.close();
  }

  @override
  Stream<List<Folder>> watchFolders() async* {
    await _ensureInitialized();
    yield _currentFolders();
    yield* _controller.stream;
  }

  @override
  Future<void> addFolder(Folder folder) async {
    await _ensureInitialized();

    final directory = await _createDirectoryForFolder(folder);
    await _writeMetadata(directory, folder);

    _recordsById[folder.id] = _FolderRecord(folder: folder, directory: directory);
    _emit();
  }

  @override
  Future<void> updateFolder(Folder folder) async {
    await _ensureInitialized();

    final existing = _recordsById[folder.id];
    if (existing == null) {
      await addFolder(folder);
      return;
    }

    var targetDirectory = existing.directory;
    final proposedDirectoryName = _directoryNameFor(folder.name, folder.id);
    final currentName = _lastSegment(existing.directory.path);

    if (currentName != proposedDirectoryName) {
      final candidate = Directory(
        '${_vaultRoot!.path}${Platform.pathSeparator}$proposedDirectoryName',
      );
      if (!await candidate.exists()) {
        targetDirectory = await existing.directory.rename(candidate.path);
      }
    }

    await _writeMetadata(targetDirectory, folder);
    _recordsById[folder.id] = _FolderRecord(folder: folder, directory: targetDirectory);
    _emit();
  }

  @override
  Future<void> deleteFolder(String folderId) async {
    await _ensureInitialized();

    final record = _recordsById[folderId];
    if (record == null) return;

    final metadataFile = File(
      '${record.directory.path}${Platform.pathSeparator}$_folderMetadataFileName',
    );
    if (await metadataFile.exists()) {
      await metadataFile.delete();
    }

    var hasOtherFiles = false;
    await for (final _ in record.directory.list(followLinks: false)) {
      hasOtherFiles = true;
      break;
    }

    if (!hasOtherFiles) {
      await record.directory.delete();
    }

    _recordsById.remove(folderId);
    _emit();
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

    await _loadFromDisk();
    _initialized = true;
  }

  Future<void> _loadFromDisk() async {
    _recordsById.clear();

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
        final folder = Folder.fromJson(json);
        _recordsById[folder.id] = _FolderRecord(folder: folder, directory: entity);
      } catch (_) {
        continue;
      }
    }
  }

  Future<Directory> _createDirectoryForFolder(Folder folder) async {
    var directoryName = _directoryNameFor(folder.name, folder.id);
    var directory = Directory(
      '${_vaultRoot!.path}${Platform.pathSeparator}$directoryName',
    );

    var suffix = 1;
    while (await directory.exists()) {
      directoryName = '${_directoryNameFor(folder.name, folder.id)}-$suffix';
      directory = Directory(
        '${_vaultRoot!.path}${Platform.pathSeparator}$directoryName',
      );
      suffix++;
    }

    await directory.create(recursive: true);
    return directory;
  }

  Future<void> _writeMetadata(Directory directory, Folder folder) async {
    final metadataFile = File(
      '${directory.path}${Platform.pathSeparator}$_folderMetadataFileName',
    );
    await metadataFile.writeAsString(jsonEncode(folder.toJson()));
  }

  List<Folder> _currentFolders() {
    final folders = _recordsById.values.map((entry) => entry.folder).toList();
    folders.sort((a, b) => b.createdAt.compareTo(a.createdAt));
    return List<Folder>.unmodifiable(folders);
  }

  void _emit() {
    _controller.add(_currentFolders());
  }

  static String _directoryNameFor(String name, String id) {
    final cleaned = _safeName(name, fallback: 'folder');
    final shortId = id.length > 8 ? id.substring(0, 8) : id;
    return '$cleaned--$shortId';
  }

  static String _safeName(String raw, {required String fallback}) {
    final cleaned = raw
        .replaceAll(RegExp(r'[<>:"/\\|?*\x00-\x1F]'), ' ')
        .replaceAll(RegExp(r'\s+'), ' ')
        .trim();
    final base = cleaned.isEmpty ? fallback : cleaned;
    return base.length <= 64 ? base : base.substring(0, 64);
  }

  static String _lastSegment(String path) {
    final normalized = path.replaceAll('\\', '/');
    final segments = normalized.split('/');
    return segments.isEmpty ? path : segments.last;
  }

  static bool _isHiddenPath(String path) {
    final normalized = path.replaceAll('\\', '/');
    final segments = normalized.split('/');
    for (final segment in segments) {
      if (segment.startsWith('.')) return true;
    }
    return false;
  }
}

class _FolderRecord {
  _FolderRecord({
    required this.folder,
    required this.directory,
  });

  final Folder folder;
  final Directory directory;
}
