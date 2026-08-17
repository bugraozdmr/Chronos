import 'dart:async';
import 'dart:convert';
import 'dart:typed_data';
import 'package:flutter/foundation.dart';
import 'package:flutter_bluetooth_serial/flutter_bluetooth_serial.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

// Riverpod Provider for Bluetooth Service
final bluetoothServiceProvider = ChangeNotifierProvider<BluetoothServiceWrapper>((ref) {
  return BluetoothServiceWrapper();
});

class BluetoothServiceWrapper extends ChangeNotifier {
  final FlutterBluetoothSerial _bluetooth = FlutterBluetoothSerial.instance;
  BluetoothConnection? _connection;
  
  // Stream controller for broadcasting parsed messages
  final StreamController<String> _messageStreamController = StreamController<String>.broadcast();
  Stream<String> get onMessageReceived => _messageStreamController.stream;

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

  Future<bool> connectToDevice(BluetoothDevice device) async {
    try {
      _connection = await BluetoothConnection.toAddress(device.address);
      print('Connected to the device: ${device.name}');
      notifyListeners();

      _connection!.input!.listen(_onDataReceived).onDone(() {
        print('Disconnected by remote request');
        _connection = null;
        notifyListeners();
      });
      return true;
    } catch (exception) {
      print('Cannot connect, exception occurred: $exception');
      _connection = null;
      notifyListeners();
      return false;
    }
  }

  void disconnect() {
    _connection?.close();
    _connection = null;
    notifyListeners();
  }

  bool get isConnected => _connection != null && _connection!.isConnected;

  void sendMessage(String text) {
    if (isConnected) {
      _connection!.output.add(Uint8List.fromList(utf8.encode(text + "\n")));
      _connection!.output.allSent.then((_) {
        print("Message sent: $text");
      });
    }
  }

  // Handle incoming data stream and split by newline
  String _buffer = "";
  void _onDataReceived(Uint8List data) {
    String dataString = ascii.decode(data);
    _buffer += dataString;

    int newlineIndex = _buffer.indexOf('\n');
    while (newlineIndex >= 0) {
      String message = _buffer.substring(0, newlineIndex).trim();
      _buffer = _buffer.substring(newlineIndex + 1);
      
      if (message.isNotEmpty) {
        _messageStreamController.add(message);
      }
      
      newlineIndex = _buffer.indexOf('\n');
    }
  }
}

