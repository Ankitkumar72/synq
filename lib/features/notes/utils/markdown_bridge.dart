import 'dart:convert';
import 'package:flutter/foundation.dart';
import 'package:flutter_quill/flutter_quill.dart';
import 'package:markdown/markdown.dart' as md;
import 'package:markdown_quill/markdown_quill.dart';

class MarkdownBridge {
  static final md.Document _mdDocument = md.Document(
    encodeHtml: false,
    extensionSet: md.ExtensionSet.gitHubFlavored,
  );
  static final MarkdownToDelta _mdToDelta = MarkdownToDelta(
    markdownDocument: _mdDocument,
  );
  static final DeltaToMarkdown _deltaToMd = DeltaToMarkdown();

  /// Helper to reliably detect both forms of legacy Quill Delta JSON
  static bool looksLikeLegacyDeltaJson(String? value) {
    if (value == null) return false;
    final trimmed = value.trim();
    return trimmed.startsWith('[{"insert":') || trimmed.startsWith('{"ops":');
  }

  /// Converts a Markdown string from Firestore into a Quill [Document] Delta format
  /// Allows the editor to render the `.md` content natively.
  static Document deltaFromMarkdown(String? markdown) {
    if (markdown == null || markdown.trim().isEmpty) {
      return Document();
    }

    final trimmed = markdown.trim();
    if (looksLikeLegacyDeltaJson(trimmed)) {
      try {
        final decoded = jsonDecode(trimmed);
        if (decoded is List) {
          return Document.fromJson(decoded);
        } else if (decoded is Map && decoded.containsKey('ops')) {
          return Document.fromJson(decoded['ops'] as List);
        }
      } catch (e) {
        debugPrint('Error parsing legacy delta json: $e');
      }
      // If it looks like a legacy delta but parsing fails, returning an empty document
      // prevents leaking raw JSON string into the editor and potentially resaving it as plain text.
      return Document();
    }

    try {
      final delta = _mdToDelta.convert(markdown);
      return Document.fromDelta(delta);
    } catch (e) {
      // Fallback in case of terrible parse failure to prevent app crash
      debugPrint('Error parsing markdown to delta: $e');
      final doc = Document();
      doc.insert(0, markdown);
      return doc;
    }
  }

  /// Extracts plain text from a Markdown string or legacy Delta JSON string for previews.
  static String previewTextFromMarkdown(String? body) {
    if (body == null || body.trim().isEmpty) {
      return '';
    }
    
    final trimmed = body.trim();
    if (looksLikeLegacyDeltaJson(trimmed)) {
      try {
        final decoded = jsonDecode(trimmed);
        if (decoded is List) {
          return Document.fromJson(decoded).toPlainText().trim();
        } else if (decoded is Map && decoded.containsKey('ops')) {
          return Document.fromJson(decoded['ops'] as List).toPlainText().trim();
        }
      } catch (_) {}
      // Prevent leaking raw JSON into preview if parsing legacy delta fails
      return '';
    }

    try {
      final delta = _mdToDelta.convert(body);
      return Document.fromDelta(delta).toPlainText().trim();
    } catch (_) {
      return trimmed;
    }
  }

  /// Converts the current Quill [Document] back into a Markdown string
  /// Allows us to save the rich text content seamlessly to Firestore
  static String markdownFromDelta(Document document) {
    try {
      final delta = document.toDelta();
      final mdString = _deltaToMd.convert(delta);
      
      // Fallback: If markdown_quill fails to parse simple text and returns empty, 
      // but the editor has text, we use plain text so we don't lose data.
      if (mdString.trim().isEmpty) {
        final plainText = document.toPlainText().trim();
        if (plainText.isNotEmpty) {
          return plainText;
        }
      }
      return mdString;
    } catch (e) {
      debugPrint('Error parsing delta to markdown: $e');
      return document.toPlainText();
    }
  }
}
