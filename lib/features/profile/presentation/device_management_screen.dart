import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:intl/intl.dart';
import '../../auth/presentation/providers/user_provider.dart';
import '../../auth/domain/models/synq_user.dart';
import 'package:synq/core/services/device_service.dart';

class DeviceManagementScreen extends ConsumerStatefulWidget {
  const DeviceManagementScreen({super.key});

  @override
  ConsumerState<DeviceManagementScreen> createState() =>
      _DeviceManagementScreenState();
}

class _DeviceManagementScreenState
    extends ConsumerState<DeviceManagementScreen> {
  final DeviceService _deviceService = DeviceService();
  String? _currentDeviceId;

  @override
  void initState() {
    super.initState();
    _loadCurrentDeviceId();
  }

  Future<void> _loadCurrentDeviceId() async {
    final info = await _deviceService.getDeviceInfo();
    if (mounted) {
      setState(() {
        _currentDeviceId = info['id'];
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    final userAsync = ref.watch(userProvider);

    return Scaffold(
      backgroundColor: Colors.white,
      appBar: AppBar(
        backgroundColor: Colors.white,
        elevation: 0,
        leading: IconButton(
          icon: const Icon(Icons.arrow_back, color: Colors.black),
          onPressed: () => Navigator.pop(context),
        ),
        title: Text(
          'Manage Devices',
          style: GoogleFonts.roboto(
            color: Colors.black,
            fontWeight: FontWeight.bold,
          ),
        ),
        centerTitle: true,
      ),
      body: userAsync.when(
        data: (user) {
          if (user == null) return const Center(child: Text('User not found'));

          final devices = user.activeDevices;
          final limit = user.planTier == PlanTier.pro ? 'Unlimited' : '1';

          return Padding(
            padding: const EdgeInsets.all(24.0),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                _buildInfoCard(user.planTier, devices.length, limit),
                const SizedBox(height: 32),
                Text(
                  'ACTIVE DEVICES',
                  style: GoogleFonts.roboto(
                    fontSize: 13,
                    fontWeight: FontWeight.bold,
                    color: Colors.grey[600],
                    letterSpacing: 1.2,
                  ),
                ),
                const SizedBox(height: 16),
                Expanded(
                  child: ListView.separated(
                    itemCount: devices.length,
                    separatorBuilder: (context, index) =>
                        const Divider(height: 32),
                    itemBuilder: (context, index) {
                      final device = devices[index];
                      final isCurrent = device['id'] == _currentDeviceId;
                      return _buildDeviceItem(user.id, device, isCurrent);
                    },
                  ),
                ),
              ],
            ),
          );
        },
        loading: () => const Center(child: CircularProgressIndicator()),
        error: (err, stack) => Center(child: Text('Error: $err')),
      ),
    );
  }

  Widget _buildInfoCard(PlanTier tier, int count, String limit) {
    return Container(
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: const Color(0xFFF8F9FE),
        borderRadius: BorderRadius.circular(24),
        border: Border.all(color: const Color(0xFFE0E6FF)),
      ),
      child: Row(
        children: [
          Container(
            padding: const EdgeInsets.all(12),
            decoration: BoxDecoration(
              color: const Color(0xFF5473F7).withValues(alpha: 0.1),
              shape: BoxShape.circle,
            ),
            child: const Icon(Icons.devices_other, color: Color(0xFF5473F7)),
          ),
          const SizedBox(width: 16),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  tier == PlanTier.pro
                      ? 'Pro Device Sync'
                      : 'Free Device Limit',
                  style: GoogleFonts.roboto(
                    fontWeight: FontWeight.bold,
                    fontSize: 16,
                  ),
                ),
                Text(
                  '$count of $limit devices used',
                  style: GoogleFonts.roboto(
                    color: Colors.grey[600],
                    fontSize: 14,
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildDeviceItem(
    String uid,
    Map<String, dynamic> device,
    bool isCurrent,
  ) {
    String lastSeenStr = 'Unknown';
    final lastSeen = device['last_seen'];
    if (lastSeen != null) {
      try {
        final dt = DateTime.parse(lastSeen.toString());
        lastSeenStr = DateFormat('MMM d, h:mm a').format(dt);
      } catch (_) {
        lastSeenStr = 'Recently';
      }
    }

    return Row(
      children: [
        Icon(
          isCurrent
              ? Icons.phone_android_rounded
              : Icons.desktop_windows_rounded,
          color: isCurrent ? const Color(0xFF5473F7) : Colors.grey,
        ),
        const SizedBox(width: 16),
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                children: [
                  Text(
                    device['name'] ?? 'Unknown Device',
                    style: GoogleFonts.roboto(
                      fontWeight: FontWeight.bold,
                      fontSize: 16,
                    ),
                  ),
                  if (isCurrent) ...[
                    const SizedBox(width: 8),
                    Container(
                      padding: const EdgeInsets.symmetric(
                        horizontal: 6,
                        vertical: 2,
                      ),
                      decoration: BoxDecoration(
                        color: const Color(0xFF5473F7).withValues(alpha: 0.1),
                        borderRadius: BorderRadius.circular(4),
                      ),
                      child: Text(
                        'THIS DEVICE',
                        style: GoogleFonts.roboto(
                          fontSize: 10,
                          fontWeight: FontWeight.bold,
                          color: const Color(0xFF5473F7),
                        ),
                      ),
                    ),
                  ],
                ],
              ),
              Text(
                'Last seen: $lastSeenStr',
                style: GoogleFonts.roboto(
                  color: Colors.grey[600],
                  fontSize: 12,
                ),
              ),
            ],
          ),
        ),
        if (!isCurrent)
          IconButton(
            icon: const Icon(Icons.remove_circle_outline, color: Colors.grey),
            onPressed: () =>
                _confirmRemoveDevice(uid, device['id'], device['name']),
          ),
      ],
    );
  }

  Future<void> _confirmRemoveDevice(
    String uid,
    String deviceId,
    String name,
  ) async {
    final shouldRemove = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Remove Device?'),
        content: Text(
          'Are you sure you want to remove "$name"? You will be signed out on that device.',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            child: const Text('Cancel'),
          ),
          TextButton(
            onPressed: () => Navigator.pop(context, true),
            style: TextButton.styleFrom(foregroundColor: Colors.red),
            child: const Text('Remove'),
          ),
        ],
      ),
    );

    if (shouldRemove == true) {
      final userRepo = ref.read(userRepositoryProvider);
      await userRepo.unregisterDevice(uid, deviceId);
    }
  }
}
