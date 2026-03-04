import 'package:flutter/material.dart';

class MarkdownEditingController extends TextEditingController {
  MarkdownEditingController({super.text});

  @override
  TextSpan buildTextSpan({
    required BuildContext context,
    TextStyle? style,
    required bool withComposing,
  }) {
    final List<TextSpan> children = [];
    final text = this.text;

    // Pattern to match **bold** text
    final RegExp boldExp = RegExp(r'\*\*(.*?)\*\*');
    int lastMatchEnd = 0;

    for (final match in boldExp.allMatches(text)) {
      if (match.start > lastMatchEnd) {
        children.add(TextSpan(
          text: text.substring(lastMatchEnd, match.start),
          style: style,
        ));
      }

      // Add actual bold text, we hide the '**' or not? Let's hide '**' by making it fontSize 0
      children.add(TextSpan(
        text: '**',
        style: style?.copyWith(fontSize: 0, color: Colors.transparent),
      ));
      children.add(TextSpan(
        text: match.group(1),
        style: style?.copyWith(fontWeight: FontWeight.bold) ??
            const TextStyle(fontWeight: FontWeight.bold),
      ));
      children.add(TextSpan(
        text: '**',
        style: style?.copyWith(fontSize: 0, color: Colors.transparent),
      ));

      lastMatchEnd = match.end;
    }

    if (lastMatchEnd < text.length) {
      children.add(TextSpan(
        text: text.substring(lastMatchEnd),
        style: style,
      ));
    }

    return TextSpan(style: style, children: children);
  }
}
