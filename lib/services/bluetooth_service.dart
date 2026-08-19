import 'dart:async';
import 'dart:convert';
import 'package:flutter/foundation.dart';
import 'package:flutter/widgets.dart';
import 'package:flutter_bluetooth_serial/flutter_bluetooth_serial.dart';
import 'package:flutter_background_service/flutter_background_service.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:shared_preferences/shared_preferences.dart';

// Riverpod Provider for Bluetooth Service
final bluetoothServiceProvider = ChangeNotifierProvider<BluetoothServiceWrapper>((ref) {
  return BluetoothServiceWrapper();
});

class BluetoothServiceWrapper extends ChangeNotifier with WidgetsBindingObserver {
  final FlutterBluetoothSerial _bluetooth = FlutterBluetoothSerial.instance;

  bool _isConnected = false;
  bool get isConnected => _isConnected;

  BluetoothDevice? _connectedDevice;
  BluetoothDevice? get connectedDevice => _connectedDevice;

  BluetoothConnection? _connection;
  String _buffer = "";

  // True while the engine is being torn down; on close we must NOT kill the
  // still-running session in the background service.
  bool _closingForDetach = false;

  BluetoothServiceWrapper() {
    WidgetsBinding.instance.addObserver(this);
    _autoConnect();
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    // App is going away (engine teardown). Close the RFCOMM socket cleanly so
    // the module frees the link; a stale socket here is exactly what made
    // reconnects fail after reopening the app.
    if (state == AppLifecycleState.detached) {
      _closingForDetach = true;
      _connection?.close();
      _connection = null;
      _connectedDevice = null;
      _isConnected = false;
      notifyListeners();
    }
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
        final error = await connectToDevice(target);
        // A module that was just released (stale link) may need a moment
        // before it accepts a new connection.
        if (error != null && !_isConnected) {
          await Future<void>.delayed(const Duration(seconds: 3));
          await connectToDevice(target);
        }
      }
    } catch (e) {
      // Auto-connect must never break the app.
    }
  }

  Future<List<BluetoothDevice>> getBondedDevices() async {
    return await _bluetooth.getBondedDevices();
  }

  Future<String?> connectToDevice(BluetoothDevice device) async {
    try {
      // Never leave a half-open socket behind when switching devices.
      _closeConnection();

      final connection = await BluetoothConnection.toAddress(device.address);
      _connection = connection;
      _connectedDevice = device;
      _isConnected = true;

      // Save for auto-connect
      SharedPreferences.getInstance().then((prefs) {
        prefs.setString('last_bt_mac', device.address);
      });

      notifyListeners();

      connection.input!.listen(_onDataReceived).onDone(() {
        // Ignore onDone from a socket that was already replaced by a newer
        // connection (device switch).
        if (_connection != connection) return;
        _isConnected = false;
        _connectedDevice = null;
        _connection = null;
        notifyListeners();
        // Only stop the session on a real link drop, not when the app itself
        // is being closed.
        if (_closingForDetach) return;
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
    _closeConnection();
  }

  void _closeConnection() {
    _connection?.close();
    _connection = null;
    _connectedDevice = null;
    _isConnected = false;
    notifyListeners();
  }

  void sendMessage(String text) {
    if (_connection != null && _isConnected) {
      _connection!.output.add(Uint8List.fromList(utf8.encode('$text\n')));
    }
  }

  void _onDataReceived(Uint8List data) {
    String dataString = utf8.decode(data, allowMalformed: true);
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