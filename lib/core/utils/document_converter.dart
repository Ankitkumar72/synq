import 'dart:convert';
import 'package:flutter/foundation.dart';

/// Converts between Quill Delta (used by flutter_quill) and 
/// Neutral JSON (used by Tiptap/Next.js).
class DocumentConverter {
  /// Converts a Quill Delta JSON string to Neutral JSON (ProseMirror format).
  static Map<String, dynamic> deltaToNeutralJson(String deltaString) {
    try {
      // Validate that it's parseable JSON
      jsonDecode(deltaString);
      
      // Basic fallback wrapper for now to satisfy the schema without loss
      return {
        'type': 'doc',
        'content': [
          {
            'type': 'legacy_quill_delta',
            'attrs': {
              'raw_delta': deltaString,
            }
          }
        ]
      };
    } catch (e) {
      // If it's not valid JSON, it's likely plain Markdown text from older notes.
      // Wrap it as legacy markdown so it can sync safely.
      return {
        'type': 'doc',
        'content': [
          {
            'type': 'legacy_markdown',
            'attrs': {
              'raw_markdown': deltaString,
            }
          }
        ]
      };
    }
  }

  /// Converts Neutral JSON (ProseMirror format) back to a Quill Delta JSON string.
  static String neutralJsonToDelta(Map<String, dynamic> neutralJson) {
    try {
      final content = neutralJson['content'] as List<dynamic>? ?? [];
      
      if (content.isNotEmpty) {
        final firstNode = content.first as Map<String, dynamic>;
        
        // If it's our legacy wrapper, unwrap it directly
        if (firstNode['type'] == 'legacy_quill_delta') {
          final attrs = firstNode['attrs'] as Map<String, dynamic>?;
          if (attrs != null && attrs.containsKey('raw_delta')) {
            return attrs['raw_delta'] as String;
          }
        }
        
        // If it's plain markdown, just return it as a string
        if (firstNode['type'] == 'legacy_markdown') {
          final attrs = firstNode['attrs'] as Map<String, dynamic>?;
          if (attrs != null && attrs.containsKey('raw_markdown')) {
            return attrs['raw_markdown'] as String;
          }
        }
      }

      // Fallback
      return '';
    } catch (e, st) {
      debugPrint('Error converting Neutral JSON to Delta: $e\n$st');
      return '';
    }
  }

  /// Best-effort conversion from Tiptap JSON to Markdown format.
  static String tiptapJsonToMarkdown(Map<String, dynamic> json) {
    try {
      if (json['type'] != 'doc' && json['content'] == null) return '';
      final buffer = StringBuffer();
      _convertNode(json, buffer, 0);
      return buffer.toString().trim();
    } catch (e) {
      debugPrint('Error converting Tiptap JSON to Markdown: $e');
      throw Exception('Failed to convert Tiptap JSON to Markdown');
    }
  }

  static void _convertNode(Map<String, dynamic> node, StringBuffer buffer, int listDepth) {
    final type = node['type'] as String?;
    final content = node['content'] as List<dynamic>?;
    final text = node['text'] as String?;
    final marks = node['marks'] as List<dynamic>?;

    if (type == 'text' && text != null) {
      String out = text;
      bool isBold = false;
      bool isItalic = false;
      bool isCode = false;

      if (marks != null) {
        for (final mark in marks) {
          if (mark is Map<String, dynamic>) {
            if (mark['type'] == 'bold') isBold = true;
            if (mark['type'] == 'italic') isItalic = true;
            if (mark['type'] == 'code') isCode = true;
          }
        }
      }

      if (isBold) out = '**$out**';
      if (isItalic) out = '*$out*';
      if (isCode) out = '`$out`';
      
      buffer.write(out);
      return;
    }

    if (type == 'heading') {
      final attrs = node['attrs'] as Map<String, dynamic>?;
      final level = attrs?['level'] as int? ?? 1;
      buffer.write('${'#' * level} ');
      if (content != null) {
        for (final child in content) {
          _convertNode(child as Map<String, dynamic>, buffer, listDepth);
        }
      }
      buffer.writeln('\n');
      return;
    }

    if (type == 'paragraph') {
      if (content != null) {
        for (final child in content) {
          _convertNode(child as Map<String, dynamic>, buffer, listDepth);
        }
      }
      buffer.writeln('\n');
      return;
    }

    if (type == 'bulletList' || type == 'orderedList') {
      if (content != null) {
        for (int i = 0; i < content.length; i++) {
          final child = content[i] as Map<String, dynamic>;
          if (type == 'bulletList') {
            buffer.write('${'  ' * listDepth}- ');
          } else {
            buffer.write('${'  ' * listDepth}${i + 1}. ');
          }
          _convertNode(child, buffer, listDepth + 1);
        }
      }
      buffer.writeln();
      return;
    }

    if (type == 'listItem') {
      if (content != null) {
        for (final child in content) {
          _convertNode(child as Map<String, dynamic>, buffer, listDepth);
        }
      }
      return;
    }

    if (type == 'blockquote') {
      if (content != null) {
        buffer.write('> ');
        for (final child in content) {
          _convertNode(child as Map<String, dynamic>, buffer, listDepth);
        }
      }
      buffer.writeln('\n');
      return;
    }

    if (type == 'codeBlock') {
      buffer.writeln('```');
      if (content != null) {
        for (final child in content) {
          _convertNode(child as Map<String, dynamic>, buffer, listDepth);
        }
      }
      buffer.writeln('```\n');
      return;
    }

    if (type == 'horizontalRule') {
      buffer.writeln('---\n');
      return;
    }

    // Default processing for doc or unhandled node
    if (content != null) {
      for (final child in content) {
        _convertNode(child as Map<String, dynamic>, buffer, listDepth);
      }
    }
  }

  /// Safe plain-text extraction fallback from Tiptap JSON.
  static String extractTextFromTiptapJson(Map<String, dynamic> json) {
    if (json['type'] == 'text' && json.containsKey('text')) {
      return json['text'] as String;
    }
    
    final content = json['content'] as List<dynamic>?;
    if (content != null) {
      final buffer = StringBuffer();
      for (final child in content) {
        if (child is Map<String, dynamic>) {
          final text = extractTextFromTiptapJson(child);
          if (text.isNotEmpty) {
            buffer.write(text);
          }
        }
      }
      if (json['type'] == 'paragraph' || json['type'] == 'heading') {
        buffer.writeln();
      }
      return buffer.toString().trim();
    }
    return '';
  }
}
