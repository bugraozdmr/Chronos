import 'dart:convert';
import 'package:flutter_bluetooth_serial/flutter_bluetooth_serial.dart';

/// Bluetooth Komutlarını yöneten ve cevap dönen modüler sınıf
class BluetoothCommandRouter {
  final void Function(String categoryName) onStartSession;
  final void Function({String? reason}) onStopSession;
  final void Function() onPauseSession;
  final void Function() onResumeSession;
  final Future<String> Function() onGetStatus;

  BluetoothConnection? _connection;

  BluetoothCommandRouter({
    required this.onStartSession,
    required this.onStopSession,
    required this.onPauseSession,
    required this.onResumeSession,
    required this.onGetStatus,
  });

  void setConnection(BluetoothConnection? connection) {
    _connection = connection;
  }

  /// Arduino'ya cevap (ACK veya veri) yollamak için kullanılır.
  void sendResponse(String message) {
    if (_connection != null && _connection!.isConnected) {
      print("📤 [BT-ROUTER] Cevap Gönderiliyor: \$message");
      _connection!.output.add(ascii.encode('\$message\n'));
    } else {
      print("⚠️ [BT-ROUTER] Bağlantı yok, mesaj gönderilemedi: \$message");
    }
  }

  /// Gelen string komutu analiz edip işlem yapar
  Future<void> routeCommand(String message) async {
    print("📥 [BT-ROUTER] Komut Geldi: \$message");
    final parts = message.split('|');
    if (parts.isEmpty) return;

    final command = parts[0].toUpperCase();

    try {
      if (command == 'START' && parts.length >= 2) {
        onStartSession(parts[1]);
        sendResponse("ACK:START_OK");
      } else if (command == 'STOP') {
        onStopSession(reason: "Stopped from device");
        sendResponse("ACK:STOP_OK");
      } else if (command == 'PAUSE') {
        onPauseSession();
        sendResponse("ACK:PAUSE_OK");
      } else if (command == 'RESUME') {
        onResumeSession();
        sendResponse("ACK:RESUME_OK");
      } else if (command == 'GET_STATUS') {
        final statusData = await onGetStatus();
        sendResponse("STATUS:\$statusData");
      } else {
        print("❌ [BT-ROUTER] Bilinmeyen Komut: \$command");
        sendResponse("ERR:UNKNOWN_COMMAND");
      }
    } catch (e) {
      print("⚠️ [BT-ROUTER] Komut işlenirken hata oluştu: \$e");
      sendResponse("ERR:INVALID_PAYLOAD");
    }
  }
}
