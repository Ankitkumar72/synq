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
}
