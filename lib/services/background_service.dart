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
import 'bluetooth_command_router.dart';

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
  // Not awaited: bluetooth auto-connect must not block registering the event
  // listeners below (a slow device would otherwise eat UI commands).
  unawaited(core.init());

  // Background listening for UI events
  service.on('connectBluetooth').listen((event) {
    if (event != null && event['address'] != null) {
      core.connectBluetooth(event['address'], event['name']);
    }
  });

  service.on('disconnectBluetooth').listen((event) {
    core.disconnectBluetooth();
  });

  service.on('saveNote').listen((event) {
    if (event != null && event['note'] != null) {
      core.saveNote(event['note']);
    }
  });

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

  // Job color used to tint the foreground notification.
  Color? _activeColor;

  // The bluetooth connection is owned by THIS isolate so it survives app
  // close/reopen. The vendored plugin was patched to work without an Activity.
  BluetoothConnection? _btConnection;
  BluetoothDevice? _btDevice;
  bool _btConnected = false;
  String _btBuffer = "";
  int _btGeneration = 0;
  
  late BluetoothCommandRouter _commandRouter;

  BackgroundCore(this.service, this.notificationsPlugin) {
    _commandRouter = BluetoothCommandRouter(
      onStartSession: startSession,
      onStopSession: ({String? reason}) => stopSession(reason: reason),
      onPauseSession: pauseSession,
      onResumeSession: resumeSession,
      onGetStatus: () async {
        final active = await db?.getActiveSession();
        if (active == null) return "IDLE";
        final rawDuration = DateTime.now().difference(active.startTime);
        final effectiveDuration = rawDuration.inSeconds - _totalPausedSeconds;
        return "${_isPaused ? 'PAUSED' : 'ACTIVE'}|$effectiveDuration|${active.categoryName}";
      },
    );
  }

  Future<void> init() async {
    db = AppDatabase();
    await _autoConnect();
    
    // Resume active session if exists
    final activeSession = await db!.getActiveSession();
    if (activeSession != null) {
      final job = await db!.getJobByName(activeSession.categoryName);
      _activeColor = _parseColor(job?.colorHex);
      _startTimer(activeSession.categoryName, job?.dailyLimitMinutes);
    }
  }

  Color? _parseColor(String? hex) {
    if (hex == null || hex.isEmpty) return null;
    try {
      return Color(int.parse(hex.replaceFirst('#', 'ff'), radix: 16));
    } catch (_) {
      return null;
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
    _emitBtStatus();
  }

  // --- BLUETOOTH LOGIC (OWNED BY THIS ISOLATE SO IT SURVIVES APP CLOSE) ---

  Future<void> _autoConnect() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final lastMac = prefs.getString('last_bt_mac');
      final lastName = prefs.getString('last_bt_name');
      if (lastMac != null) {
        await connectBluetooth(lastMac, lastName);
      }
    } catch (e) {
      // Auto-connect must never break service startup.
    }
  }

  Future<void> connectBluetooth(String address, String? name) async {
    final generation = ++_btGeneration;
    try {
      // Already connected to this device — just report current state.
      if (_btConnected && _btDevice?.address == address) {
        service.invoke('btConnectResult', {'success': true, 'name': name, 'address': address});
        _emitBtStatus();
        return;
      }

      // Release any stale connection to a previous device first.
      final previous = _btConnection;
      _btConnection = null;
      _btConnected = false;
      _btDevice = null;
      previous?.close();

      final connection = await BluetoothConnection.toAddress(address);

      // A newer request superseded this one — drop it silently.
      if (generation != _btGeneration) {
        connection.close();
        return;
      }

      _btConnection = connection;
      _commandRouter.setConnection(connection);
      _btDevice = BluetoothDevice(address: address, name: name);
      _btConnected = true;
      _btBuffer = "";

      SharedPreferences.getInstance().then((prefs) {
        prefs.setString('last_bt_mac', address);
        if (name != null) prefs.setString('last_bt_name', name);
      });

      service.invoke('btConnectResult', {'success': true, 'name': name, 'address': address});
      _emitBtStatus();

      connection.input!.listen(_onDataReceived).onDone(() {
        if (generation != _btGeneration) return; // superseded connection
        _btConnected = false;
        _btConnection = null;
        _commandRouter.setConnection(null);
        _btDevice = null;
        _emitBtStatus();
        // Session can't continue without the device link.
        stopSession(reason: "Bluetooth disconnected");
      });
    } catch (e) {
      if (generation != _btGeneration) return;
      _btConnected = false;
      _btConnection = null;
      _commandRouter.setConnection(null);
      _btDevice = null;
      service.invoke('btConnectResult', {
        'success': false,
        'message': e.toString(),
      });
    }
  }

  void disconnectBluetooth() {
    _btGeneration++;
    _btConnection?.close();
    _btConnection = null;
    _commandRouter.setConnection(null);
    _btDevice = null;
    _btConnected = false;
    _emitBtStatus();
  }

  void _onDataReceived(Uint8List data) {
    String dataString = utf8.decode(data, allowMalformed: true);
    _btBuffer += dataString;

    int newlineIndex = _btBuffer.indexOf('\n');
    while (newlineIndex >= 0) {
      String message = _btBuffer.substring(0, newlineIndex).trim();
      _btBuffer = _btBuffer.substring(newlineIndex + 1);

      if (message.isNotEmpty) {
        _handleIncomingMessage(message);
      }
      newlineIndex = _btBuffer.indexOf('\n');
    }
  }

  void _handleIncomingMessage(String message) {
    _commandRouter.routeCommand(message);
  }

  void _emitBtStatus() {
    service.invoke('btStatus', {
      'connected': _btConnected,
      'name': _btDevice?.name,
      'address': _btDevice?.address,
    });
  }

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
      await db!.into(db!.jobs).insert(JobsCompanion(
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
    _activeColor = _parseColor(job?.colorHex);
    _startTimer(categoryName, job?.dailyLimitMinutes);
    service.invoke('sessionChanged');
  }

  Future<void> saveNote(String note) async {
    final active = await db!.getActiveSession();
    if (active != null) {
      await db!.updateSession(active.copyWith(notes: drift.Value<String?>(note)));
      service.invoke('sessionChanged');
    }
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
    _updateNotification('⏸ Paused', 'Session paused');
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
      _activeColor = _parseColor(job?.colorHex);
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
      service.invoke('sessionChanged');
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
      _updateNotification('▶ $categoryName', timeStr);
      
      if (limitMinutes != null && limitMinutes > 0) {
        if (effectiveDuration.inMinutes >= limitMinutes) {
          // Buzzer logic removed, handled in UI isolate if needed.
          // Note: Background can now directly send messages via _commandRouter!
        }
      }
    });
  }

  void _updateNotification(String title, String body) {
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
          color: _activeColor,
        ),
      ),
    );
  }
}
