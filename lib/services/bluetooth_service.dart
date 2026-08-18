import 'dart:async';
import 'dart:convert';
import 'dart:typed_data';
import 'package:flutter/foundation.dart';
import 'package:flutter_bluetooth_serial/flutter_bluetooth_serial.dart';
import 'package:flutter_background_service/flutter_background_service.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:shared_preferences/shared_preferences.dart';

// Riverpod Provider for Bluetooth Service
final bluetoothServiceProvider = ChangeNotifierProvider<BluetoothServiceWrapper>((ref) {
  return BluetoothServiceWrapper();
});

class BluetoothServiceWrapper extends ChangeNotifier {
  final FlutterBluetoothSerial _bluetooth = FlutterBluetoothSerial.instance;
  
  bool _isConnected = false;
  bool get isConnected => _isConnected;
  
  BluetoothDevice? _connectedDevice;
  BluetoothDevice? get connectedDevice => _connectedDevice;
  
  BluetoothConnection? _connection;
  String _buffer = "";

  BluetoothServiceWrapper() {
    _autoConnect();
  }

  Future<void> _autoConnect() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final lastMac = prefs.getString('last_bt_mac');
      
      final bonded = await _bluetooth.getBondedDevices();
      
      // Try to find last connected device
      var target = bonded.where((d) => d.address == lastMac).firstOrNull;
      
      // Fallback to any HC-05 module
      target ??= bonded.where((d) => d.name?.contains('HC-05') ?? false).firstOrNull;
      
      if (target != null) {
        await connectToDevice(target);
      }
    } catch (e) {
      print("Auto-connect failed: $e");
    }
  }

  Future<List<BluetoothDiscoveryResult>> startDiscovery() async {
    List<BluetoothDiscoveryResult> results = [];
    try {
      await for (BluetoothDiscoveryResult result in _bluetooth.startDiscovery()) {
        results.add(result);
      }
    } catch (e) {
      print("Error during discovery: $e");
    }
    return results;
  }

  Future<List<BluetoothDevice>> getBondedDevices() async {
    return await _bluetooth.getBondedDevices();
  }

  Future<String?> connectToDevice(BluetoothDevice device) async {
    try {
      _connection = await BluetoothConnection.toAddress(device.address);
      _connectedDevice = device;
      _isConnected = true;
      
      // Save for auto-connect
      SharedPreferences.getInstance().then((prefs) {
        prefs.setString('last_bt_mac', device.address);
      });
      
      notifyListeners();
      
      _connection!.input!.listen(_onDataReceived).onDone(() {
        _isConnected = false;
        _connectedDevice = null;
        _connection = null;
        notifyListeners();
        // Also tell background service to stop session if bluetooth disconnects
        FlutterBackgroundService().invoke('stopSession');
      });
      return null;
    } catch (e) {
      _isConnected = false;
      _connectedDevice = null;
      _connection = null;
      notifyListeners();
      return e.toString();
    }
  }

  void disconnect() {
    _connection?.close();
    _connection = null;
    _connectedDevice = null;
    _isConnected = false;
    notifyListeners();
  }

  void sendMessage(String text) {
    if (_connection != null && _isConnected) {
      _connection!.output.add(Uint8List.fromList(utf8.encode(text + "\n")));
    }
  }

  void _onDataReceived(Uint8List data) {
    String dataString = ascii.decode(data);
    _buffer += dataString;

    int newlineIndex = _buffer.indexOf('\n');
    while (newlineIndex >= 0) {
      String message = _buffer.substring(0, newlineIndex).trim();
      _buffer = _buffer.substring(newlineIndex + 1);
      
      if (message.isNotEmpty) {
        _handleIncomingMessage(message);
      }
      newlineIndex = _buffer.indexOf('\n');
    }
  }

  void _handleIncomingMessage(String message) {
    // Send these commands to the background service since it handles the session now
    final parts = message.split('|');
    if (parts.isEmpty) return;
    
    final command = parts[0].toUpperCase();
    if (command == 'START' && parts.length >= 2) {
      FlutterBackgroundService().invoke('startSession', {'categoryName': parts[1]});
    } else if (command == 'STOP') {
      FlutterBackgroundService().invoke('stopSession');
    } else if (command == 'PAUSE') {
      FlutterBackgroundService().invoke('pauseSession');
    } else if (command == 'RESUME') {
      FlutterBackgroundService().invoke('resumeSession');
    }
  }
}
