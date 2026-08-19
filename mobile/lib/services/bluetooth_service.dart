import 'dart:async';
import 'package:flutter/foundation.dart';
import 'package:flutter_bluetooth_serial/flutter_bluetooth_serial.dart';
import 'package:flutter_background_service/flutter_background_service.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

// Riverpod Provider for Bluetooth Service
final bluetoothServiceProvider = ChangeNotifierProvider<BluetoothServiceWrapper>((ref) {
  return BluetoothServiceWrapper();
});

// Thin proxy: the actual bluetooth connection lives in the background service
// isolate so it survives app close/reopen. This wrapper only reflects its
// state and forwards commands.
class BluetoothServiceWrapper extends ChangeNotifier {
  final FlutterBluetoothSerial _bluetooth = FlutterBluetoothSerial.instance;

  bool _isConnected = false;
  bool get isConnected => _isConnected;

  BluetoothDevice? _connectedDevice;
  BluetoothDevice? get connectedDevice => _connectedDevice;

  // Completed when the background service reports the outcome of a connect.
  Completer<String?>? _pendingConnect;

  BluetoothServiceWrapper() {
    _init();
  }

  void _init() {
    final service = FlutterBackgroundService();

    // Pull current Bluetooth state from the background service isolate.
    service.invoke('syncState');

    service.on('btStatus').listen((event) {
      if (event == null) return;
      _isConnected = event['connected'] == true;
      if (_isConnected) {
        _connectedDevice = BluetoothDevice(
          address: event['address'] ?? '',
          name: event['name'],
        );
      } else {
        _connectedDevice = null;
      }
      notifyListeners();
    });

    service.on('btConnectResult').listen((event) {
      if (event == null) return;
      final completer = _pendingConnect;
      _pendingConnect = null;
      final success = event['success'] == true;
      if (completer != null && !completer.isCompleted) {
        completer.complete(success ? null : (event['message'] ?? 'Connection failed'));
      }
    });
  }

  Future<List<BluetoothDevice>> getBondedDevices() async {
    return await _bluetooth.getBondedDevices();
  }

  Future<String?> connectToDevice(BluetoothDevice device) async {
    final completer = Completer<String?>();
    _pendingConnect = completer;
    FlutterBackgroundService().invoke('connectBluetooth', {
      'address': device.address,
      'name': device.name,
    });
    try {
      return await completer.future.timeout(
        const Duration(seconds: 25),
        onTimeout: () => 'Connection timed out',
      );
    } finally {
      if (identical(_pendingConnect, completer)) {
        _pendingConnect = null;
      }
    }
  }

  void disconnect() {
    FlutterBackgroundService().invoke('disconnectBluetooth');
  }
}