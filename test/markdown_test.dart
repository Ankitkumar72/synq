// ignore_for_file: avoid_print
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:flutter_quill/flutter_quill.dart';
import 'package:synq/features/notes/utils/markdown_bridge.dart';
import 'dart:io';

void main() {
  test('Simulate replaceText with complex markdown', () async {
    final controller = QuillController.basic();
    final text = await File('test_data.md').readAsString();

    final mdDoc = MarkdownBridge.deltaFromMarkdown(text);
    final delta = mdDoc.toDelta();

    final selection = controller.selection;
    
    try {
      controller.replaceText(
        selection.start,
        selection.end - selection.start,
        delta,
        TextSelection.collapsed(offset: selection.start + mdDoc.length - 1),
      );
      print('REPLACE TEXT SUCCESSFUL');
    } catch (e, stack) {
      print('REPLACE TEXT CRASHED: \$e');
      print(stack);
      fail('Crashed');
    }
  });
}
