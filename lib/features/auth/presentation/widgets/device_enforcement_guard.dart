import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:synq/core/services/device_service.dart';
import '../providers/user_provider.dart';

class DeviceEnforcementGuard extends ConsumerStatefulWidget {
  final Widget child;

  const DeviceEnforcementGuard({super.key, required this.child});

  @override
  ConsumerState<DeviceEnforcementGuard> createState() => _DeviceEnforcementGuardState();
}

class _DeviceEnforcementGuardState extends ConsumerState<DeviceEnforcementGuard> {
  final DeviceService _deviceService = DeviceService();
  bool _isChecking = true;
  bool _isAllowed = true;
  String? _currentDeviceId;
  String? _currentDeviceName;

  @override
  void initState() {
    super.initState();
    _checkDevice();
  }

  Future<void> _checkDevice() async {
    final info = await _deviceService.getDeviceInfo();
    _currentDeviceId = info['id'];
    _currentDeviceName = info['name'];

    final user = await ref.read(userProvider.future);
    if (user == null || _currentDeviceId == null) {
      if (mounted) setState(() => _isChecking = false);
      return;
    }

    // Register device first (idempotent)
    final userRepo = ref.read(userRepositoryProvider);
    await userRepo.registerDevice(user.id, _currentDeviceId!, _currentDeviceName!);

    // Re-check allowance
    final allowed = await userRepo.isDeviceAllowed(user.id, _currentDeviceId!);
    
    if (mounted) {
      setState(() {
        _isAllowed = allowed;
        _isChecking = false;
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    if (_isChecking) {
      return const Scaffold(
        body: Center(child: CircularProgressIndicator()),
      );
    }

    if (!_isAllowed) {
      return _buildUpgradeGate();
    }

    return widget.child;
  }

  Widget _buildUpgradeGate() {
    return Scaffold(
      backgroundColor: Colors.white,
      body: Padding(
        padding: const EdgeInsets.all(32.0),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            const Icon(Icons.important_devices_rounded, size: 80, color: Color(0xFF5473F7)),
            const SizedBox(height: 32),
            Text(
              'Device Limit Reached',
              style: GoogleFonts.roboto(
                fontSize: 28,
                fontWeight: FontWeight.w900,
                color: Colors.black,
              ),
              textAlign: TextAlign.center,
            ),
            const SizedBox(height: 16),
            Text(
              'Your current plan allows only 1 active device. Please upgrade to Pro for unlimited devices or remove an existing device.',
              style: GoogleFonts.roboto(
                fontSize: 16,
                color: Colors.grey[600],
                height: 1.5,
              ),
              textAlign: TextAlign.center,
            ),
            const SizedBox(height: 48),
            SizedBox(
              width: double.infinity,
              child: ElevatedButton(
                onPressed: () {
                  // Navigate to subscription screen or show upgrade dialog
                  // For now, let's assume there's a way to trigger upgrade
                },
                style: ElevatedButton.styleFrom(
                  backgroundColor: const Color(0xFF5473F7),
                  foregroundColor: Colors.white,
                  padding: const EdgeInsets.symmetric(vertical: 16),
                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
                  elevation: 0,
                ),
                child: Text(
                  'Upgrade to Pro',
                  style: GoogleFonts.roboto(fontSize: 16, fontWeight: FontWeight.bold),
                ),
              ),
            ),
            const SizedBox(height: 16),
            TextButton(
              onPressed: () async {
                setState(() => _isChecking = true);
                await _checkDevice();
              },
              child: Text(
                'Retry Connection',
                style: GoogleFonts.roboto(color: Colors.grey[600], fontWeight: FontWeight.w600),
              ),
            ),
          ],
        ),
      ),
    );
  }
}
