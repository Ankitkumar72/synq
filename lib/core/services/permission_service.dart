import 'dart:io';
import 'package:flutter/foundation.dart';
import 'package:permission_handler/permission_handler.dart';
import 'package:device_info_plus/device_info_plus.dart';
import 'package:synq/core/services/notification_service.dart';

class PermissionService {
  static final PermissionService _instance = PermissionService._internal();
  factory PermissionService() => _instance;
  PermissionService._internal();

  /// Initial permissions requested on app startup
  Future<void> requestInitialPermissions() async {
    if (kIsWeb) return;

    try {
      // 1. Notifications (using existing service)
      await NotificationService().requestPermissions();

      // 2. Media access (Initial prompt for gallery)
      await _requestMediaPermissions();
      
    } catch (e) {
      debugPrint('Error requesting initial permissions: $e');
    }
  }

  /// Specialized request for photos/gallery access
  Future<bool> requestPhotoPermission() async {
    if (kIsWeb) return true;

    final status = await _getMediaPermissionStatus();
    
    if (status.isGranted || status.isLimited) {
      return true;
    }

    if (status.isPermanentlyDenied) {
      // Logic for permanently denied: we can't request again, so we'd need to show a dialog
      // This will be handled by the caller or a helper here
      return false;
    }

    final result = await _requestMediaPermissions();
    return result.isGranted || result.isLimited;
  }

  /// Specialized request for Camera
  Future<bool> requestCameraPermission() async {
    if (kIsWeb) return true;
    final status = await Permission.camera.request();
    return status.isGranted;
  }

  // --- Helpers ---

  Future<PermissionStatus> _getMediaPermissionStatus() async {
    if (Platform.isAndroid) {
      final androidInfo = await DeviceInfoPlugin().androidInfo;
      if (androidInfo.version.sdkInt >= 33) {
        return await Permission.photos.status;
      } else {
        return await Permission.storage.status;
      }
    } else {
      return await Permission.photos.status;
    }
  }

  Future<PermissionStatus> _requestMediaPermissions() async {
    if (Platform.isAndroid) {
      final androidInfo = await DeviceInfoPlugin().androidInfo;
      if (androidInfo.version.sdkInt >= 33) {
        // Request specific media permissions for Android 13+
        Map<Permission, PermissionStatus> statuses = await [
          Permission.photos,
          Permission.videos,
        ].request();
        return statuses[Permission.photos] ?? PermissionStatus.denied;
      } else {
        // Legacy Android uses storage permission
        return await Permission.storage.request();
      }
    } else {
      // iOS
      return await Permission.photos.request();
    }
  }
}
