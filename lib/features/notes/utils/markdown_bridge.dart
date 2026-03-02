import 'dart:convert';
import 'package:flutter_quill/flutter_quill.dart';
import 'package:markdown_quill/markdown_quill.dart';
import 'package:quill_markdown/quill_markdown.dart';

class MarkdownBridge {
  static final MarkdownQuill _markdownQuill = MarkdownQuill(
    options: const MarkdownQuillOptions(),
  );

  /// Converts a Markdown string from Firestore into a Quill [Document] Delta format
  /// Allows the editor to render the `.md` content natively.
  static Document deltaFromMarkdown(String? markdown) {
    if (markdown == null || markdown.trim().isEmpty) {
      return Document();
    }

    try {
      final delta = _markdownQuill.parse(markdown);
      return Document.fromDelta(delta);
    } catch (e) {
      // Fallback in case of terrible parse failure to prevent app crash
      print('Error parsing markdown to delta: $e');
      final doc = Document();
      doc.insert(0, markdown);
      return doc;
    }
  }

  /// Converts the current Quill [Document] back into a Markdown string
  /// Allows us to save the rich text content seamlessly to Firestore
  static String markdownFromDelta(Document document) {
    try {
      final delta = document.toDelta();
      return delta.toMarkdown();
    } catch (e) {
      print('Error parsing delta to markdown: $e');
      return document.toPlainText();
    }
  }
}
