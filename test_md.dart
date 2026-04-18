import 'package:flutter_quill/flutter_quill.dart';
import 'package:markdown_quill/markdown_quill.dart';

void main() {
  final doc = Document()..insert(0, 'What are you doing buddy ?\n');
  final deltaToMd = DeltaToMarkdown();
  final mdString = deltaToMd.convert(doc.toDelta());
  // ignore: avoid_print
  print(mdString);
}
