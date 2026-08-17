import 'dart:async';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:drift/drift.dart';
import 'package:flutter_background_service/flutter_background_service.dart';
import '../data/database/database.dart';
import 'bluetooth_service.dart';

final databaseProvider = Provider<AppDatabase>((ref) {
  return AppDatabase();
});

final sessionManagerProvider = Provider<SessionManager>((ref) {
  final db = ref.read(databaseProvider);
  final bluetooth = ref.read(bluetoothServiceProvider);
  return SessionManager(db, bluetooth);
});

class SessionManager {
  final AppDatabase _db;
  final BluetoothServiceWrapper _bluetooth;
  Timer? _sessionTimer;

  SessionManager(this._db, this._bluetooth) {
    _bluetooth.onMessageReceived.listen(_handleIncomingMessage);
    _bluetooth.addListener(_handleConnectionChange);
  }

  void _handleConnectionChange() {
    if (!_bluetooth.isConnected) {
      // Disconnected! Auto-stop session.
      _stopActiveSession(reason: "Bluetooth disconnected");
    }
  }

  void _handleIncomingMessage(String message) async {
    final parts = message.split('|');
    if (parts.isEmpty) return;
    
    final command = parts[0].toUpperCase();
    
    if (command == 'START' && parts.length >= 2) {
      final category = parts[1];
      await _startSession(category);
    } else if (command == 'STOP') {
      await _stopActiveSession();
    }
  }

  Future<void> _startSession(String categoryName) async {
    final active = await _db.getActiveSession();
    if (active != null) {
      await _stopActiveSession();
    }
    
    // Find or create Job
    var job = await _db.getJobByName(categoryName);
    if (job == null) {
      final id = await _db.into(_db.jobs).insert(JobsCompanion(
        name: Value(categoryName),
      ));
      job = await _db.getJobByName(categoryName);
    }
    
    final entry = SessionsCompanion(
      categoryName: Value(categoryName),
      jobId: Value(job?.id),
      startTime: Value(DateTime.now()),
      status: const Value('active'),
    );
    
    await _db.addSession(entry);
    
    // Start Background Service
    final service = FlutterBackgroundService();
    if (!await service.isRunning()) {
      await service.startService();
    }
    
    _startTimer(categoryName, job?.dailyLimitMinutes);
  }

  void _startTimer(String categoryName, int? limitMinutes) {
    _sessionTimer?.cancel();
    _sessionTimer = Timer.periodic(const Duration(seconds: 1), (timer) async {
      final active = await _db.getActiveSession();
      if (active == null) {
        timer.cancel();
        return;
      }
      
      final now = DateTime.now();
      final duration = now.difference(active.startTime);
      final minutes = duration.inMinutes;
      final seconds = duration.inSeconds % 60;
      final hours = duration.inHours;
      
      final timeStr = '${hours.toString().padLeft(2, '0')}:${(minutes % 60).toString().padLeft(2, '0')}:${seconds.toString().padLeft(2, '0')}';
      
      // Update notification
      FlutterBackgroundService().invoke('updateNotification', {
        'title': 'Active: $categoryName',
        'body': 'Duration: $timeStr',
      });
      
      // Check limits (example logic for sending alert)
      if (limitMinutes != null && limitMinutes > 0) {
        if (duration.inMinutes >= limitMinutes) {
          _bluetooth.sendMessage('ALERT|BUZZER|LONG'); // Tell arduino to buzz
        } else if (limitMinutes - duration.inMinutes == 5 && seconds == 0) {
          _bluetooth.sendMessage('ALERT|LED|YELLOW'); // 5 mins warning
        }
      }
    });
  }

  Future<void> _stopActiveSession({String? reason}) async {
    _sessionTimer?.cancel();
    FlutterBackgroundService().invoke('stopService');
    
    final active = await _db.getActiveSession();
    if (active != null) {
      final now = DateTime.now();
      final duration = now.difference(active.startTime).inSeconds;
      
      var notes = active.notes;
      if (reason != null) {
        notes = (notes != null && notes.isNotEmpty) ? '$notes\nStopped due to: $reason' : 'Stopped due to: $reason';
      }
      
      final updated = active.copyWith(
        endTime: Value(now),
        durationSeconds: Value(duration),
        status: 'completed',
        notes: Value(notes),
      );
      
      await _db.updateSession(updated);
      print("Session stopped. Duration: $duration seconds");
    }
  }
}
