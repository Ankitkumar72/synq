import 'package:flutter/foundation.dart';
import 'package:html2md/html2md.dart' as html2md;
import 'package:flutter_quill/flutter_quill.dart';
import 'package:synq/features/notes/utils/markdown_bridge.dart';

class HtmlParser {
  /// Converts raw HTML string (usually from a clipboard paste) into a Quill Document
  /// by first translating it to Markdown via `html2md`, then using our `MarkdownBridge`
  /// to parse it into a structured Delta format.
  /// 
  /// This ensures all data passing into Synq adheres to our standardized Markdown schema.
  static Document deltaFromHtml(String html) {
    try {
      // 1. Convert HTML to Markdown (strips weird inline styles, normalizes layout)
      final markdownString = html2md.convert(html);
      
      // 2. Pass the standardized markdown string into our existing Delta bridge
      return MarkdownBridge.deltaFromMarkdown(markdownString);
      
    } catch (e) {
      debugPrint('Error parsing HTML to Delta: $e');
      final doc = Document();
      doc.insert(0, html);
      return doc;
    }
  }
}
