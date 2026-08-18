import 'dart:async';
import 'dart:ui';
import 'dart:convert';
import 'dart:typed_data';
import 'package:flutter/material.dart';
import 'package:flutter_background_service/flutter_background_service.dart';
import 'package:flutter_local_notifications/flutter_local_notifications.dart';
import 'package:flutter_bluetooth_serial/flutter_bluetooth_serial.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:drift/drift.dart' as drift;
import '../data/database/database.dart';

@pragma('vm:entry-point')
void notificationTapBackground(NotificationResponse response) async {
  WidgetsFlutterBinding.ensureInitialized();
  FlutterBackgroundService().invoke('notificationAction', {'action': response.actionId});
}

Future<void> initializeBackgroundService() async {
  final service = FlutterBackgroundService();

  const AndroidNotificationChannel channel = AndroidNotificationChannel(
    'chronos_foreground',
    'Chronos Foreground Service',
    description: 'This channel is used for important notifications.',
    importance: Importance.low,
  );

  final FlutterLocalNotificationsPlugin flutterLocalNotificationsPlugin =
      FlutterLocalNotificationsPlugin();

  await flutterLocalNotificationsPlugin
      .resolvePlatformSpecificImplementation<
          AndroidFlutterLocalNotificationsPlugin>()
      ?.createNotificationChannel(channel);

  await service.configure(
    androidConfiguration: AndroidConfiguration(
      onStart: onStart,
      autoStart: true,
      isForegroundMode: true,
      notificationChannelId: 'chronos_foreground',
      initialNotificationTitle: 'Chronos',
      initialNotificationContent: 'Background service active',
      foregroundServiceNotificationId: 888,
    ),
    iosConfiguration: IosConfiguration(
      autoStart: true,
      onForeground: onStart,
      onBackground: onIosBackground,
    ),
  );
}

@pragma('vm:entry-point')
Future<bool> onIosBackground(ServiceInstance service) async {
  WidgetsFlutterBinding.ensureInitialized();
  DartPluginRegistrant.ensureInitialized();
  return true;
}

@pragma('vm:entry-point')
void onStart(ServiceInstance service) async {
  DartPluginRegistrant.ensureInitialized();

  final flutterLocalNotificationsPlugin = FlutterLocalNotificationsPlugin();

  // We instantiate a local core logic handler to keep state
  final core = BackgroundCore(service, flutterLocalNotificationsPlugin);
  await core.init();

  await flutterLocalNotificationsPlugin.initialize(
    settings: const InitializationSettings(
      android: AndroidInitializationSettings('launcher_icon'),
    ),
    onDidReceiveNotificationResponse: (NotificationResponse response) {
      core.handleNotificationAction(response.actionId);
    },
    onDidReceiveBackgroundNotificationResponse: notificationTapBackground,
  );

  // Background listening for UI events
  service.on('notificationAction').listen((event) {
    if (event != null && event['action'] != null) {
      core.handleNotificationAction(event['action']);
    }
  });

    // Bluetooth logic removed from here, handled in UI isolate

  service.on('startSession').listen((event) {
    if (event != null && event['categoryName'] != null) {
      core.startSession(event['categoryName']);
    }
  });

  service.on('stopSession').listen((event) {
    core.stopSession(reason: "Stopped from UI");
  });

  service.on('pauseSession').listen((event) {
    core.pauseSession();
  });

  service.on('resumeSession').listen((event) {
    core.resumeSession();
  });

    // Send message logic removed from here, handled in UI isolate

  service.on('syncState').listen((event) {
    core.syncStateToUI();
  });
}

class BackgroundCore {
  final ServiceInstance service;
  final FlutterLocalNotificationsPlugin notificationsPlugin;
  
  AppDatabase? db;
  Timer? _sessionTimer;
  
  bool _isPaused = false;
  DateTime? _pauseStartTime;
  int _totalPausedSeconds = 0;
  
  BackgroundCore(this.service, this.notificationsPlugin);

  Future<void> init() async {
    db = AppDatabase();
    // Auto-connect and Bluetooth logic handled in UI isolate
    
    // Resume active session if exists
    final activeSession = await db!.getActiveSession();
    if (activeSession != null) {
      final job = await db!.getJobByName(activeSession.categoryName);
      _startTimer(activeSession.categoryName, job?.dailyLimitMinutes);
    }
  }

  void syncStateToUI() async {
    service.invoke('sessionStatus', {
      'isPaused': _isPaused,
    });
    
    final active = await db!.getActiveSession();
    if (active != null) {
      final effectiveDuration = DateTime.now().difference(active.startTime).inSeconds - _totalPausedSeconds;
      service.invoke('updateDuration', {'seconds': effectiveDuration});
    } else {
      service.invoke('updateDuration', {'seconds': 0});
    }
  }

  void handleNotificationAction(String? actionId) {
    switch (actionId) {
      case 'stop_session':
        stopSession(reason: "Stopped from notification");
        break;
      case 'pause_session':
        pauseSession();
        break;
      case 'resume_session':
        resumeSession();
        break;
    }
  }

  // --- BLUETOOTH LOGIC (MOVED TO UI ISOLATE) ---

  // --- SESSION LOGIC ---

  Future<void> startSession(String categoryName) async {
    final active = await db!.getActiveSession();
    if (active != null) {
      await stopSession();
    }
    
    _isPaused = false;
    _pauseStartTime = null;
    _totalPausedSeconds = 0;
    
    var job = await db!.getJobByName(categoryName);
    if (job == null) {
      final id = await db!.into(db!.jobs).insert(JobsCompanion(
        name: drift.Value(categoryName),
      ));
      job = await db!.getJobByName(categoryName);
    }
    
    final entry = SessionsCompanion(
      categoryName: drift.Value(categoryName),
      jobId: drift.Value(job?.id),
      startTime: drift.Value(DateTime.now()),
      status: const drift.Value('active'),
    );
    
    await db!.addSession(entry);
    _startTimer(categoryName, job?.dailyLimitMinutes);
    service.invoke('sessionChanged');
  }

  void pauseSession() async {
    if (_isPaused) return;
    _isPaused = true;
    _pauseStartTime = DateTime.now();
    _sessionTimer?.cancel();
    
    final active = await db!.getActiveSession();
    if (active != null) {
      await db!.updateSession(active.copyWith(status: 'paused'));
    }
    
    syncStateToUI();
    service.invoke('sessionChanged');
    _updateNotification('⏸ Paused', 'Session paused. Tap CONTINUE to resume.', true);
  }

  void resumeSession() async {
    if (!_isPaused) return;
    if (_pauseStartTime != null) {
      _totalPausedSeconds += DateTime.now().difference(_pauseStartTime!).inSeconds;
      _pauseStartTime = null;
    }
    _isPaused = false;
    
    final active = await db!.getActiveSession();
    if (active != null) {
      await db!.updateSession(active.copyWith(status: 'active'));
      var job = await db!.getJobByName(active.categoryName);
      _startTimer(active.categoryName, job?.dailyLimitMinutes);
    }
    
    syncStateToUI();
    service.invoke('sessionChanged');
  }

  Future<void> stopSession({String? reason}) async {
    _sessionTimer?.cancel();
    
    if (_isPaused && _pauseStartTime != null) {
      _totalPausedSeconds += DateTime.now().difference(_pauseStartTime!).inSeconds;
    }
    
    _isPaused = false;
    _pauseStartTime = null;
    service.invoke('sessionStatus', {'isPaused': false});
    service.invoke('updateDuration', {'seconds': 0});
    
    // Clear notification
    notificationsPlugin.cancel(id: 888);
    
    final active = await db!.getActiveSession();
    if (active != null) {
      final now = DateTime.now();
      final effectiveDuration = now.difference(active.startTime).inSeconds - _totalPausedSeconds;
      
      var notes = active.notes;
      if (reason != null) {
        notes = (notes != null && notes.isNotEmpty) ? '$notes\nStopped due to: $reason' : 'Stopped due to: $reason';
      }
      
      final updated = active.copyWith(
        endTime: drift.Value(now),
        durationSeconds: drift.Value(effectiveDuration),
        status: 'completed',
        notes: drift.Value(notes),
      );
      
      await db!.updateSession(updated);
    }
    _totalPausedSeconds = 0;
  }

  void _startTimer(String categoryName, int? limitMinutes) {
    _sessionTimer?.cancel();
    _sessionTimer = Timer.periodic(const Duration(seconds: 1), (timer) async {
      if (_isPaused) return;
      
      final active = await db!.getActiveSession();
      if (active == null) {
        timer.cancel();
        return;
      }
      
      final rawDuration = DateTime.now().difference(active.startTime);
      final effectiveDuration = rawDuration - Duration(seconds: _totalPausedSeconds);
      
      final hours = effectiveDuration.inHours;
      final minutes = effectiveDuration.inMinutes.remainder(60);
      final seconds = effectiveDuration.inSeconds.remainder(60);
      
      service.invoke('updateDuration', {'seconds': effectiveDuration.inSeconds});

      final timeStr = '${hours.toString().padLeft(2, '0')}:${minutes.toString().padLeft(2, '0')}:${seconds.toString().padLeft(2, '0')}';
      _updateNotification('▶ $categoryName', timeStr, false);
      
      if (limitMinutes != null && limitMinutes > 0) {
        if (effectiveDuration.inMinutes >= limitMinutes) {
          // Buzzer logic removed, handled in UI isolate if needed.
          // Note: Since bluetooth is in UI, the background can't directly send bluetooth messages.
        }
      }
    });
  }

  void _updateNotification(String title, String body, bool isPaused) {
    final actions = isPaused
        ? const [
            AndroidNotificationAction('resume_session', '▶ CONTINUE', cancelNotification: false, showsUserInterface: false),
            AndroidNotificationAction('stop_session', '⏹ STOP', cancelNotification: false, showsUserInterface: false),
          ]
        : const [
            AndroidNotificationAction('pause_session', '⏸ PAUSE', cancelNotification: false, showsUserInterface: false),
            AndroidNotificationAction('stop_session', '⏹ STOP', cancelNotification: false, showsUserInterface: false),
          ];

    notificationsPlugin.show(
      id: 888,
      title: title,
      body: body,
      notificationDetails: NotificationDetails(
        android: AndroidNotificationDetails(
          'chronos_foreground',
          'Chronos Foreground Service',
          icon: 'launcher_icon',
          ongoing: true,
          autoCancel: false,
          importance: Importance.low,
          priority: Priority.low,
          actions: actions,
        ),
      ),
    );
  }
}
