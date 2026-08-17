import 'dart:async';
import 'dart:ui';
import 'package:flutter/material.dart';
import 'package:flutter_background_service/flutter_background_service.dart';
import 'package:flutter_local_notifications/flutter_local_notifications.dart';

Future<void> initializeBackgroundService() async {
  final service = FlutterBackgroundService();

  const AndroidNotificationChannel channel = AndroidNotificationChannel(
    'chronos_foreground', // id
    'Chronos Foreground Service', // name
    description: 'This channel is used for important notifications.', // description
    importance: Importance.low, // low importance prevents sound but shows in notification shade
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
      autoStart: false,
      isForegroundMode: true,
      notificationChannelId: 'chronos_foreground',
      initialNotificationTitle: 'Chronos',
      initialNotificationContent: 'Monitoring session...',
      foregroundServiceNotificationId: 888,
    ),
    iosConfiguration: IosConfiguration(
      autoStart: false,
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

  final FlutterLocalNotificationsPlugin flutterLocalNotificationsPlugin =
      FlutterLocalNotificationsPlugin();

  if (service is AndroidServiceInstance) {
    service.on('setAsForeground').listen((event) {
      service.setAsForegroundService();
    });
    service.on('setAsBackground').listen((event) {
      service.setAsBackgroundService();
    });
  }

  service.on('stopService').listen((event) {
    service.stopSelf();
  });

  service.on('updateNotification').listen((event) {
    if (event != null && event['title'] != null && event['body'] != null) {
      flutterLocalNotificationsPlugin.show(
        id: 888,
        title: event['title'],
        body: event['body'],
        notificationDetails: const NotificationDetails(
          android: AndroidNotificationDetails(
            'chronos_foreground',
            'Chronos Foreground Service',
            icon: 'ic_bg_service_small',
            ongoing: true,
            importance: Importance.low,
          ),
        ),
      );
    }
  });

  // Example of a tick function if you want the background isolate to do something periodically
  // Timer.periodic(const Duration(seconds: 1), (timer) async { ... });
}
