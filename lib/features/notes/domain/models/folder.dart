import 'package:freezed_annotation/freezed_annotation.dart';

part 'folder.freezed.dart';
part 'folder.g.dart';

@freezed
class Folder with _$Folder {
  const factory Folder({
    required String id,
    required String name,
    required int iconCodePoint,
    String? iconFontFamily,
    required int colorValue,
    required DateTime createdAt,
    @Default(false) bool isFavorite,
  }) = _Folder;

  factory Folder.fromJson(Map<String, dynamic> json) => _$FolderFromJson(json);
}
