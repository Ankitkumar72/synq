import 'package:flutter/foundation.dart';
import 'package:flutter_quill/flutter_quill.dart';
import 'package:markdown/markdown.dart' as md;
import 'package:markdown_quill/markdown_quill.dart';

class MarkdownBridge {
  static final md.Document _mdDocument = md.Document(encodeHtml: false);
  static final MarkdownToDelta _mdToDelta = MarkdownToDelta(
    markdownDocument: _mdDocument,
  );
  static final DeltaToMarkdown _deltaToMd = DeltaToMarkdown();

  /// Converts a Markdown string from Firestore into a Quill [Document] Delta format
  /// Allows the editor to render the `.md` content natively.
  static Document deltaFromMarkdown(String? markdown) {
    if (markdown == null || markdown.trim().isEmpty) {
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

  /// Converts the current Quill [Document] back into a Markdown string
  /// Allows us to save the rich text content seamlessly to Firestore
  static String markdownFromDelta(Document document) {
    try {
      final delta = document.toDelta();
      return _deltaToMd.convert(delta);
    } catch (e) {
      debugPrint('Error parsing delta to markdown: $e');
      return document.toPlainText();
    }
  }
}
