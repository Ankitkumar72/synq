import '../domain/models/folder.dart';
import '../domain/models/note.dart';

class FolderSearchEngine {
  FolderSearchEngine({
    required List<Folder> folders,
    required List<Note> notes,
  })  : _folderOrder = folders.map((f) => f.id).toList(),
        _folderOrderIndex = {
          for (var i = 0; i < folders.length; i++) folders[i].id: i,
        } {
    final notesByFolder = <String, List<Note>>{};
    for (final note in notes) {
      final folderId = note.folderId;
      if (folderId == null || folderId.isEmpty) continue;
      notesByFolder.putIfAbsent(folderId, () => <Note>[]).add(note);
    }

    for (final folder in folders) {
      final normalizedFolderName = _normalize(folder.name);
      _folderNameById[folder.id] = normalizedFolderName;

      final buffer = StringBuffer(folder.name);
      final folderNotes = notesByFolder[folder.id] ?? const <Note>[];
      for (final note in folderNotes) {
        buffer
          ..write(' ')
          ..write(note.title)
          ..write(' ')
          ..write(note.body ?? '');
        if (note.tags.isNotEmpty) {
          buffer
            ..write(' ')
            ..writeAll(note.tags, ' ');
        }
      }

      final corpus = _normalize(buffer.toString());
      _folderCorpusById[folder.id] = corpus;

      final tokens = _tokenize(corpus);
      _folderTokensById[folder.id] = tokens;
      for (final token in tokens) {
        _tokenToFolderIds.putIfAbsent(token, () => <String>{}).add(folder.id);
        for (final trigram in _trigrams(token)) {
          _trigramToFolderIds
              .putIfAbsent(trigram, () => <String>{})
              .add(folder.id);
        }
      }
    }
  }

  final List<String> _folderOrder;
  final Map<String, int> _folderOrderIndex;
  final Map<String, String> _folderNameById = <String, String>{};
  final Map<String, String> _folderCorpusById = <String, String>{};
  final Map<String, Set<String>> _folderTokensById = <String, Set<String>>{};
  final Map<String, Set<String>> _tokenToFolderIds = <String, Set<String>>{};
  final Map<String, Set<String>> _trigramToFolderIds = <String, Set<String>>{};

  static final RegExp _nonWordRegExp = RegExp(r'[^a-z0-9\s]+');
  static final RegExp _spacesRegExp = RegExp(r'\s+');

  List<String> searchFolderIds(String query) {
    final normalizedQuery = _normalize(query).trim();
    if (normalizedQuery.isEmpty) {
      return List<String>.from(_folderOrder);
    }

    final queryTokens = _tokenize(normalizedQuery);
    if (queryTokens.isEmpty) {
      return const <String>[];
    }

    final scores = <String, double>{};

    void bump(Iterable<String> folderIds, double points) {
      for (final id in folderIds) {
        scores[id] = (scores[id] ?? 0) + points;
      }
    }

    for (final token in queryTokens) {
      final exactMatches = _tokenToFolderIds[token];
      if (exactMatches != null) {
        bump(exactMatches, 14);
      }

      for (final entry in _tokenToFolderIds.entries) {
        final vocabularyToken = entry.key;
        if (vocabularyToken == token) continue;
        if (vocabularyToken.startsWith(token)) {
          bump(entry.value, 6);
        }
      }

      final fuzzyCandidateTokens = _collectFuzzyCandidates(token);
      for (final candidateToken in fuzzyCandidateTokens) {
        final ids = _tokenToFolderIds[candidateToken];
        if (ids == null) continue;
        final distance = _levenshteinDistanceWithin(token, candidateToken, 2);
        if (distance == 1) {
          bump(ids, 7);
        } else if (distance == 2) {
          bump(ids, 4);
        }
      }

      for (final trigram in _trigrams(token)) {
        final ids = _trigramToFolderIds[trigram];
        if (ids != null) {
          bump(ids, 1.5);
        }
      }
    }

    for (final folderId in _folderOrder) {
      final folderName = _folderNameById[folderId] ?? '';
      if (folderName.contains(normalizedQuery)) {
        scores[folderId] = (scores[folderId] ?? 0) + 20;
      }

      final corpus = _folderCorpusById[folderId] ?? '';
      if (corpus.contains(normalizedQuery)) {
        scores[folderId] = (scores[folderId] ?? 0) + 8;
      }
    }

    final ranked = scores.entries.where((entry) => entry.value >= 3).toList()
      ..sort((a, b) {
        final scoreCompare = b.value.compareTo(a.value);
        if (scoreCompare != 0) return scoreCompare;
        return (_folderOrderIndex[a.key] ?? 0)
            .compareTo(_folderOrderIndex[b.key] ?? 0);
      });

    return ranked.map((entry) => entry.key).toList(growable: false);
  }

  Set<String> _collectFuzzyCandidates(String token) {
    final candidates = <String>{};

    for (final trigram in _trigrams(token)) {
      final ids = _trigramToFolderIds[trigram];
      if (ids == null) continue;
      for (final id in ids) {
        final folderTokens = _folderTokensById[id];
        if (folderTokens != null) {
          candidates.addAll(folderTokens);
        }
      }
    }

    if (candidates.isEmpty && token.isNotEmpty) {
      for (final vocabularyToken in _tokenToFolderIds.keys) {
        if (vocabularyToken.startsWith(token[0])) {
          candidates.add(vocabularyToken);
        }
      }
    }

    return candidates;
  }

  static String _normalize(String input) {
    return input
        .toLowerCase()
        .replaceAll(_nonWordRegExp, ' ')
        .replaceAll(_spacesRegExp, ' ')
        .trim();
  }

  static Set<String> _tokenize(String input) {
    if (input.isEmpty) return <String>{};
    return input
        .split(' ')
        .where((token) => token.length >= 2)
        .toSet();
  }

  static Set<String> _trigrams(String token) {
    if (token.isEmpty) return <String>{};
    if (token.length <= 3) return <String>{token};

    final framed = '^$token\$';
    final grams = <String>{};
    for (var i = 0; i <= framed.length - 3; i++) {
      grams.add(framed.substring(i, i + 3));
    }
    return grams;
  }

  static int _levenshteinDistanceWithin(String a, String b, int maxDistance) {
    final lengthDiff = (a.length - b.length).abs();
    if (lengthDiff > maxDistance) return maxDistance + 1;

    var previous = List<int>.generate(b.length + 1, (i) => i);

    for (var i = 1; i <= a.length; i++) {
      final current = List<int>.filled(b.length + 1, 0);
      current[0] = i;
      var rowMin = current[0];

      for (var j = 1; j <= b.length; j++) {
        final substitutionCost = a.codeUnitAt(i - 1) == b.codeUnitAt(j - 1) ? 0 : 1;
        final deletion = previous[j] + 1;
        final insertion = current[j - 1] + 1;
        final substitution = previous[j - 1] + substitutionCost;

        var best = deletion;
        if (insertion < best) best = insertion;
        if (substitution < best) best = substitution;

        current[j] = best;
        if (best < rowMin) rowMin = best;
      }

      if (rowMin > maxDistance) return maxDistance + 1;
      previous = current;
    }

    return previous[b.length];
  }
}
