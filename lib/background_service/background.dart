import 'dart:async';
import 'dart:convert';
import 'dart:ui';
import 'dart:developer' as dev;

import 'package:flutter/material.dart';
import 'package:flutter_background_service/flutter_background_service.dart';
import 'package:flutter_background_service_android/flutter_background_service_android.dart';
import 'package:flutter_local_notifications/flutter_local_notifications.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'package:connectivity_plus/connectivity_plus.dart';
import 'package:flutter_blue_plus/flutter_blue_plus.dart';
import 'package:flutter_activity_recognition/flutter_activity_recognition.dart' as ar;
import 'package:geolocator/geolocator.dart';

import '../web_services_api/api.dart';

// this will be used as notification channel id
const notificationChannelId = 'my_foreground';

// this will be used for notification id, So you can update your custom notification with this id.
const notificationIdService = 888;
const notificationIdSurveys = 889;

class BackgroundService {
  late FlutterBackgroundService service;

  ar.Activity activity =
      ar.Activity(ar.ActivityType.UNKNOWN, ar.ActivityConfidence.LOW);
  late StreamSubscription<ar.Activity> _activitySubscription;

  BackgroundService() {
    service = FlutterBackgroundService();
  }

  void setActivitySubscription() {
    _activitySubscription =
        ar.FlutterActivityRecognition.instance.activityStream.listen((_act) {
      activity = _act;
      dev.log("Detected activity: ${activity.toJson()}");
    });
  }

  Future<void> initializeService() async {
    const AndroidNotificationChannel channel = AndroidNotificationChannel(
      notificationChannelId, // id
      'MY FOREGROUND SERVICE', // title
      description:
          'This channel is used for important notifications.', // description
      importance: Importance.high, // importance must be at low or higher level
    );

    final FlutterLocalNotificationsPlugin flutterLocalNotificationsPlugin =
        FlutterLocalNotificationsPlugin();

    await flutterLocalNotificationsPlugin
        .resolvePlatformSpecificImplementation<
            AndroidFlutterLocalNotificationsPlugin>()
        ?.createNotificationChannel(channel);

    await service.configure(
      androidConfiguration: AndroidConfiguration(
        // this will be executed when app is in foreground or background in separated isolate
        onStart: onStart,

        // auto start service
        autoStart: true,
        isForegroundMode: true,

        notificationChannelId: notificationChannelId,
        // this must match with notification channel you created above.
        initialNotificationTitle: 'POSTCOVID-AI',
        initialNotificationContent: 'Initializing',
        foregroundServiceNotificationId: notificationIdService,
      ),
      iosConfiguration: IosConfiguration(
        autoStart: true,
        onForeground: onStart,
        onBackground: onIosBackground,
      ),
    );
  }

  Future<void> stopService() async {
    dev.log("Stop service");
    if (await service.isRunning()) {
      service.invoke("stopService");
    }
  }

  @pragma('vm:entry-point')
  Future<bool> onIosBackground(ServiceInstance service) async {
    WidgetsFlutterBinding.ensureInitialized();
    DartPluginRegistrant.ensureInitialized();

    SharedPreferences preferences = await SharedPreferences.getInstance();
    await preferences.reload();
    final log = preferences.getStringList('log') ?? <String>[];
    log.add(DateTime.now().toIso8601String());
    await preferences.setStringList('log', log);

    return true;
  }
}

Future<void> onStart(ServiceInstance service) async {
// Only available for flutter 3.0.0 and later
  DartPluginRegistrant.ensureInitialized();

  final BackgroundService backgroundService = BackgroundService();
  backgroundService.setActivitySubscription();

  final FlutterLocalNotificationsPlugin flutterLocalNotificationsPlugin =
      FlutterLocalNotificationsPlugin();

  service.on('stopService').listen((event) {
    service.stopSelf();
  });

// Code for sensor sampling
  _sampleSensors(service, backgroundService, flutterLocalNotificationsPlugin);
  Timer.periodic(const Duration(minutes: 10), (timer) async {
    await _sampleSensors(service, backgroundService, flutterLocalNotificationsPlugin);
  });

// Timer for showing survey notification
  Timer.periodic(const Duration(minutes: 10), (timer) async {
    await _sendSurveyNotification(flutterLocalNotificationsPlugin);
  });
}

Future<void> _sampleSensors(ServiceInstance service, BackgroundService backgroundService, FlutterLocalNotificationsPlugin flutterLocalNotificationsPlugin) async {
  if (service is AndroidServiceInstance) {
    if (await service.isForegroundService()) {
      flutterLocalNotificationsPlugin.show(
        notificationIdService,
        'POSTCOVID-AI',
        'Last update: ${DateTime.now()}',
        const NotificationDetails(
          android: AndroidNotificationDetails(
            notificationChannelId,
            'MY FOREGROUND SERVICE',
            icon: 'ic_bg_service_small',
            ongoing: true,
          ),
        ),
      );
    }
  }

// Code to sample sensors goes here
// Sensors
// Location
  Position? position;
  position = await Geolocator.getCurrentPosition(desiredAccuracy: LocationAccuracy.high);

// Connectivity
  Connectivity connectivity = Connectivity();
  ConnectivityResult connectivityResult =
  await connectivity.checkConnectivity();

// Bluetooth
  final FlutterBluePlus flutterBlue = FlutterBluePlus.instance;
  final List<BluetoothDevice> devicesList = [];

  flutterBlue.scanResults.listen((List<ScanResult> results) {
    for (ScanResult result in results) {
      if (!devicesList.contains(result.device)) {
        devicesList.add(result.device);
      }
    }
  });

  const Duration scanDuration = Duration(seconds: 10);
  flutterBlue.startScan(scanMode: ScanMode.lowPower, timeout: scanDuration);
  await Future.delayed(scanDuration);
  flutterBlue.stopScan();

    // Sensor logs
  dev.log("Connectivity: $connectivityResult");
  dev.log("Activity: ${backgroundService.activity.type} (${backgroundService.activity.confidence})");
  dev.log("${position.latitude}º, ${position.longitude}º");
  dev.log("Bluetooth: ${devicesList.length}");
  for (BluetoothDevice device in devicesList) {
    dev.log(device.toString());
  }

// REST API
  final _dataPoint = {
    "carp_header": {
      "study_id": "aFeH8",
      "device_role_name":
      "masterphone with USER_CODE = A3FNzaFeH8. Local Time = ${DateTime.now().toString()}",
      "user_id": "A3FN",
      "start_time": DateTime.now().toUtc().toIso8601String(),
      "data_format": {"namespace": "dk.cachet.carp", "name": "adhoc"}
    },
    "carp_body": {
      "id": "6f77caed-5067-4877-a26d-f94386c0984b",
      "location_data": "${position.latitude}, ${position.longitude}",
      "connectivity_data": "$connectivityResult",
      "activity_data":
      "Activity: ${backgroundService.activity.type.name}, Confidence: ${backgroundService.activity.confidence.name}",
      "bluetooth_data": devicesList.length,
    }
  };

  dev.log(json.encode(_dataPoint));

  Api api = Api();

  dev.log("HTTP POST TOKEN");
  Map<String, dynamic> jsonPostToken = await api.postToken(
      numAttemps: 5, timeoutDuration: const Duration(seconds: 5));

  dev.log("HTTP GET TOKEN");
  Map<String, dynamic> jsonGetToken = await api.getToken(
      jsonPostToken["access_token"],
      numAttemps: 5,
      timeoutDuration: const Duration(seconds: 5));

  dev.log("HTTP POST DATAPOINT");
  Map<String, dynamic> jsonPostDatapoint = await api.postDataPoint(
      jsonPostToken["access_token"], json.encode(_dataPoint),
      numAttemps: 5, timeoutDuration: const Duration(seconds: 5));
  dev.log(jsonPostDatapoint.toString());
}

Future<void> _sendSurveyNotification(FlutterLocalNotificationsPlugin flutterLocalNotificationsPlugin) async {
  SharedPreferences preferences = await SharedPreferences.getInstance();
  await preferences.setBool('surveyReady', true);

  flutterLocalNotificationsPlugin.show(
    notificationIdSurveys,
    "Nueva encuesta",
    "Toca para realizarla",
    const NotificationDetails(
      android: AndroidNotificationDetails(
          notificationChannelId, 'MY FOREGROUND SERVICE',
          icon: 'ic_bg_service_small'),
    ),
  );
}