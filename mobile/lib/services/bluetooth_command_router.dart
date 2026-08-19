import 'dart:convert';
import 'package:flutter/foundation.dart';
import 'package:flutter_bluetooth_serial/flutter_bluetooth_serial.dart';

/// Bluetooth Komutlarını yöneten ve cevap dönen modüler sınıf
class BluetoothCommandRouter {
  final void Function(String categoryName) onStartSession;
  final void Function({String? reason}) onStopSession;
  final void Function() onPauseSession;
  final void Function() onResumeSession;
  final Future<String> Function() onGetStatus;
  final Future<String> Function()? onGetJobs;

  BluetoothConnection? _connection;

  BluetoothCommandRouter({
    required this.onStartSession,
    required this.onStopSession,
    required this.onPauseSession,
    required this.onResumeSession,
    required this.onGetStatus,
    this.onGetJobs,
  });

  void setConnection(BluetoothConnection? connection) {
    _connection = connection;
  }

  /// Arduino'ya cevap (ACK veya veri) yollamak için kullanılır.
  void sendResponse(String message) {
    if (_connection != null && _connection!.isConnected) {
      debugPrint("📤 [BT-ROUTER] Cevap Gönderiliyor: $message");
      _connection!.output.add(ascii.encode('$message\n'));
    } else {
      debugPrint("⚠️ [BT-ROUTER] Bağlantı yok, mesaj gönderilemedi: $message");
    }
  }

  /// Arduino'ya proaktif olarak güncel durumu iter (Push).
  void pushStatus(String statusData) {
    sendResponse("STATUS:$statusData");
  }

  /// Gelen string komutu analiz edip işlem yapar
  Future<void> routeCommand(String message) async {
    debugPrint("📥 [BT-ROUTER] Komut Geldi: $message");
    final parts = message.split('|');
    if (parts.isEmpty) return;

    final command = parts[0].replaceAll(RegExp(r'[^a-zA-Z0-9_]'), '').toUpperCase();

    if (command.isEmpty) {
      // Donanım başlatılırken (Arduino reset vb.) gelen 'null byte' veya anlamsız
      // karakterleri algıladığımızda sessizce kalmak yerine, Arduino'nun yeni
      // başladığını varsayıp "Auto-Recovery" (Otomatik Kurtarma) yapıyoruz.
      debugPrint("🔄 [BT-ROUTER] Glitch yakalandı. Auto-Recovery (Otomatik Kurtarma) başlatılıyor...");
      if (onGetJobs != null) {
        final jobsData = await onGetJobs!();
        sendResponse("JOBS:$jobsData");
      }
      final statusData = await onGetStatus();
      sendResponse("STATUS:$statusData");
      return;
    }

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
        sendResponse("STATUS:$statusData");
      } else if (command == 'GET_JOBS') {
        if (onGetJobs != null) {
          final jobsData = await onGetJobs!();
          sendResponse("JOBS:$jobsData");
        } else {
          sendResponse("ERR:NOT_IMPLEMENTED");
        }
      } else {
        debugPrint("❌ [BT-ROUTER] Bilinmeyen Komut: $command");
        sendResponse("ERR:UNKNOWN_COMMAND");
      }
    } catch (e) {
      debugPrint("⚠️ [BT-ROUTER] Komut işlenirken hata oluştu: $e");
      sendResponse("ERR:INVALID_PAYLOAD");
    }
  }
}
