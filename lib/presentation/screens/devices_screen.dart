import 'package:flutter/material.dart';
import 'package:flutter_bluetooth_serial/flutter_bluetooth_serial.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:toastification/toastification.dart';
import '../../services/bluetooth_service.dart';

class DevicesScreen extends ConsumerStatefulWidget {
  const DevicesScreen({super.key});

  @override
  ConsumerState<DevicesScreen> createState() => _DevicesScreenState();
}

class _DevicesScreenState extends ConsumerState<DevicesScreen> {
  List<BluetoothDevice> _devices = [];
  bool _isLoading = true;

  @override
  void initState() {
    super.initState();
    _loadDevices();
  }

  Future<void> _loadDevices() async {
    final bluetooth = ref.read(bluetoothServiceProvider);
    try {
      final devices = await bluetooth.getBondedDevices();
      setState(() {
        _devices = devices;
        _isLoading = false;
      });
    } catch (e) {
      setState(() {
        _isLoading = false;
      });
      toastification.show(
        context: context,
        title: const Text('Error'),
        description: const Text('Could not load devices.'),
        type: ToastificationType.error,
        style: ToastificationStyle.flat,
        alignment: Alignment.topCenter,
        autoCloseDuration: const Duration(seconds: 3),
      );
    }
  }

  void _connectToDevice(BluetoothDevice device) async {
    final bluetooth = ref.read(bluetoothServiceProvider);
    
    showDialog(
      context: context,
      barrierDismissible: false,
      builder: (context) => const Center(child: CircularProgressIndicator(color: Colors.white)),
    );

    final success = await bluetooth.connectToDevice(device);
    
    if (mounted) {
      Navigator.pop(context); // Remove dialog
      if (success) {
        toastification.show(
          context: context,
          title: const Text('Connected'),
          description: Text('Successfully connected to ${device.name}'),
          type: ToastificationType.success,
          style: ToastificationStyle.flat,
          alignment: Alignment.topCenter,
          autoCloseDuration: const Duration(seconds: 3),
        );
        Navigator.pop(context); // Go back to Home
      } else {
        toastification.show(
          context: context,
          title: const Text('Connection Failed'),
          description: Text('Could not connect to ${device.name}'),
          type: ToastificationType.error,
          style: ToastificationStyle.flat,
          alignment: Alignment.topCenter,
          autoCloseDuration: const Duration(seconds: 4),
        );
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Paired Devices'),
      ),
      body: _isLoading 
        ? const Center(child: CircularProgressIndicator())
        : _devices.isEmpty 
          ? const Center(child: Text("No paired devices found.\nPlease pair in Android Settings.", textAlign: TextAlign.center))
          : ListView.separated(
              padding: const EdgeInsets.all(16),
              itemCount: _devices.length,
              separatorBuilder: (_, __) => const SizedBox(height: 12),
              itemBuilder: (context, index) {
                final device = _devices[index];
                return Container(
                  decoration: BoxDecoration(
                    color: Theme.of(context).colorScheme.surface,
                    borderRadius: BorderRadius.circular(12),
                    border: Border.all(color: Colors.grey.withOpacity(0.2)),
                  ),
                  child: ListTile(
                    contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
                    leading: Container(
                      padding: const EdgeInsets.all(10),
                      decoration: BoxDecoration(
                        color: Theme.of(context).colorScheme.primary.withOpacity(0.1),
                        borderRadius: BorderRadius.circular(8),
                      ),
                      child: Icon(Icons.bluetooth, color: Theme.of(context).colorScheme.primary),
                    ),
                    title: Text(
                      device.name ?? "Unknown Device",
                      style: const TextStyle(fontWeight: FontWeight.w600),
                    ),
                    subtitle: Text(
                      device.address,
                      style: TextStyle(color: Colors.grey[500]),
                    ),
                    trailing: OutlinedButton(
                      style: OutlinedButton.styleFrom(
                        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
                      ),
                      onPressed: () => _connectToDevice(device),
                      child: const Text('Connect'),
                    ),
                  ),
                );
              },
            ),
    );
  }
}
