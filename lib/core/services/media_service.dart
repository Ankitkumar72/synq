import 'dart:io';
import 'package:flutter/foundation.dart';
import 'package:image_picker/image_picker.dart';
import 'package:path_provider/path_provider.dart';

class MediaService {
  final ImagePicker _picker = ImagePicker();

  /// Pick an image from the specified source
  Future<File?> pickImage({ImageSource source = ImageSource.gallery}) async {
    final XFile? pickedFile = await _picker.pickImage(
      source: source,
      maxWidth: 1920,
      maxHeight: 1080,
      imageQuality: 85,
    );
    
    if (pickedFile != null) {
      return File(pickedFile.path);
    }
    return null;
  }

  /// Save an image file to local application documents directory
  Future<String?> saveToLocalDocuments(File file) async {
    try {
      final appDir = await getApplicationDocumentsDirectory();
      final fileName = '${DateTime.now().millisecondsSinceEpoch}_${file.path.split('/').last}';
      final savedImage = await file.copy('${appDir.path}/$fileName');
      return savedImage.path;
    } catch (e) {
      debugPrint('Error saving image locally: $e');
      return null;
    }
  }

  /// Pick and save an image locally, returning the file path
  Future<String?> pickAndSaveImage({ImageSource source = ImageSource.gallery}) async {
    final file = await pickImage(source: source);
    if (file != null) {
      return await saveToLocalDocuments(file);
    }
    return null;
  }
}
