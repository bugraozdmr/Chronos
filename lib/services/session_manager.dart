import 'dart:async';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_background_service/flutter_background_service.dart';
import '../data/database/database.dart';

final databaseProvider = Provider<AppDatabase>((ref) {
  return AppDatabase();
});

final sessionManagerProvider = Provider<SessionManager>((ref) {
  final db = ref.read(databaseProvider);
  return SessionManager(db);
});

class SessionManager {
  final AppDatabase _db;
  
  bool _isPaused = false;
  bool get isPaused => _isPaused;

  final StreamController<Duration> _durationController = StreamController<Duration>.broadcast();
  Stream<Duration> get durationStream => _durationController.stream;

  final StreamController<bool> _pauseController = StreamController<bool>.broadcast();
  Stream<bool> get pauseStream => _pauseController.stream;

  SessionManager(this._db) {
    _init();
  }

  void _init() {
    final service = FlutterBackgroundService();
    
    // Request initial state from background service
    service.invoke('syncState');
    
    // Listen for state updates from background service
    service.on('sessionStatus').listen((event) {
      if (event != null && event['isPaused'] != null) {
        _isPaused = event['isPaused'];
        _pauseController.add(_isPaused);
      }
    });

    service.on('updateDuration').listen((event) {
      if (event != null && event['seconds'] != null) {
        _durationController.add(Duration(seconds: event['seconds'] as int));
      }
    });

    service.on('sessionChanged').listen((event) {
      _db.forceRefresh();
    });
  }

  Future<void> startSession(String categoryName) async {
    final service = FlutterBackgroundService();
    if (!await service.isRunning()) {
      await service.startService();
    }
    service.invoke('startSession', {'categoryName': categoryName});
  }

  void pauseSession() {
    FlutterBackgroundService().invoke('pauseSession');
  }

  void resumeSession() {
    FlutterBackgroundService().invoke('resumeSession');
  }

  Future<void> stopActiveSession({String? reason}) async {
    FlutterBackgroundService().invoke('stopSession');
  }

  void dispose() {
    _durationController.close();
    _pauseController.close();
  }
}
