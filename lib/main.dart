import 'dart:async';
import 'dart:convert';
import 'dart:io';
import 'dart:developer' as dev;

import 'package:connectivity_plus/connectivity_plus.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_activity_recognition/flutter_activity_recognition.dart';
import 'package:flutter_blue_plus/flutter_blue_plus.dart';
import 'package:location/location.dart';
import 'package:path_provider/path_provider.dart';
import 'package:permission_handler/permission_handler.dart';
import 'package:permission_handler/permission_handler.dart' as ph;
import 'package:tfg/api/api.dart';
import 'package:tfg/survey.dart';

void main() {
  WidgetsFlutterBinding.ensureInitialized();
  SystemChrome.setPreferredOrientations(
      [DeviceOrientation.portraitUp, DeviceOrientation.portraitDown]);

  runApp(const MyApp());
}

class MyApp extends StatelessWidget {
  const MyApp({super.key});

  // This widget is the root of your application.
  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'TFG',
      theme: ThemeData(
        primarySwatch: Colors.blue,
      ),
      home: const MyHomePage(title: 'TFG'),
    );
  }
}

class MyHomePage extends StatefulWidget {
  const MyHomePage({super.key, required this.title});
  final String title;

  @override
  State<MyHomePage> createState() => _MyHomePageState();
}

class _MyHomePageState extends State<MyHomePage> {
  // connectivity_plus
  ConnectivityResult _connectionStatus = ConnectivityResult.none;
  final Connectivity _connectivity = Connectivity();
  late StreamSubscription<ConnectivityResult> _connectivitySubscription;

  // flutter_activity_recognition
  late StreamSubscription<Activity> _activityStreamSubscription;
  Activity _activity = new Activity(ActivityType.UNKNOWN, ActivityConfidence.LOW);

  // location
  final Location _location = Location();
  late StreamSubscription<LocationData> _locationSubscription;
  LocationData? _locationData;

  // flutter_blue_plus
  final FlutterBluePlus flutterBlue = FlutterBluePlus.instance;
  final List<BluetoothDevice> devicesList = [];

  @override
  void initState() {
    super.initState();
    initSensors();
  }

  @override
  void dispose() {
    stopSampling();
    super.dispose();
  }

  void initSensors() async {
    await requestPermissions();
    initConnectivity();
    initActivity();
    initLocation();
    initBluetooth();
  }

  Future<void> requestPermissions() async {
    // Resquest permissions for activity recognition
    if (await Permission.activityRecognition.request().isGranted)
      dev.log("Activity Recognition Permission Granted");

    // Request permissions for locationAlways
    if (await Permission.location.request().isGranted)
      if (await Permission.locationAlways.request().isGranted)
        dev.log("Location Permission Granted");

    // Request permissions for bluetoothScan
    if (await Permission.bluetoothScan.request().isGranted)
      dev.log("Bluetooth Scan Permission Granted");
  }

  // connectivity_plus
  Future<void> initConnectivity() async {
    late ConnectivityResult result;
    // Platform messages may fail, so we use a try/catch PlatformException.
    try {
      result = await _connectivity.checkConnectivity();
    } on PlatformException catch (e) {
      dev.log('Couldn\'t check connectivity status', error: e);
      return;
    }

    if (!mounted) {
      return Future.value(null);
    }

    _connectivitySubscription = _connectivity.onConnectivityChanged.listen(_updateConnectionStatus);

    return _updateConnectionStatus(result);
  }

  Future<void> _updateConnectionStatus(ConnectivityResult result) async {
    setState(() {
      _connectionStatus = result;
      dev.log(_connectionStatus.toString());
    });
  }

  // flutter_activity_recognition
  Future<void> initActivity() async {
    WidgetsBinding.instance.addPostFrameCallback((_) async {
      final activityRecognition = FlutterActivityRecognition.instance;

      // Check if the user has granted permission. If not, request permission.
      PermissionRequestResult reqResult;
      reqResult = await activityRecognition.checkPermission();
      if (reqResult == PermissionRequestResult.PERMANENTLY_DENIED) {
        dev.log('Permission is permanently denied.');
        return;
      } else if (reqResult == PermissionRequestResult.DENIED) {
        reqResult = await activityRecognition.requestPermission();
        if (reqResult != PermissionRequestResult.GRANTED) {
          dev.log('Permission is denied.');
          return;
        }
      }

      // Subscribe to the activity stream.
      dev.log("Activity Recognition Subscription Start");
      _activityStreamSubscription = activityRecognition.activityStream
          .handleError(_handleError)
          .listen(_onActivityReceive);
    });
  }

  void _onActivityReceive(Activity activity) {
    dev.log('Activity Detected >> ${activity.toJson()}');
    setState(() {
      _activity = activity;
    });
  }

  void _handleError(dynamic error) {
    dev.log('Catch Error >> $error');
  }

  // location
  Future<void> initLocation() async {
    bool serviceEnabled = await _location.serviceEnabled();
    if (!serviceEnabled) {
      serviceEnabled = await _location.requestService();

      if (!serviceEnabled) {
        dev.log("Location service could not be enabled");
        return;
      }
    }

    try {
      await _location.enableBackgroundMode(enable: true);
    } catch(error) {
      dev.log("Location background mode could not be enabled");
    }

    dev.log("Location Subscription Start");
    _locationSubscription = _location.onLocationChanged.listen((LocationData location) {
      setState(() {
        _locationData = location;
        dev.log(location.toString());
      });
    });
  }

  // flutter_blue_plus
  Future<void> initBluetooth() async {
    flutterBlue.connectedDevices
        .asStream()
        .listen((List<BluetoothDevice> devices) {
      for (BluetoothDevice device in devices) {
        _addDeviceTolist(device);
      }
    });
    flutterBlue.scanResults.listen((List<ScanResult> results) {
      for (ScanResult result in results) {
        _addDeviceTolist(result.device);
      }
    });

    dev.log("Bluetooth Start Scan");
    flutterBlue.startScan();
  }

  _addDeviceTolist(final BluetoothDevice device) {
    if (!devicesList.contains(device)) {
      setState(() {
        dev.log("Bluetooth found $device");
        devicesList.add(device);
      });
    }
  }

  // Cancel subscriptions
  void stopSampling() {
    _connectivitySubscription.cancel();
    _activityStreamSubscription.cancel();
    _locationSubscription.cancel();
    flutterBlue.stopScan();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: Text(widget.title),
      ),
      body: ListView(
        children: [
          Container(
            margin: EdgeInsets.all(20),
            child: Text("Test de envío de datapoints:", style: TextStyle(fontSize: 20))
          ),
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceEvenly,
            children: [
              ElevatedButton(
                onPressed: () async {
                  Api api = Api();

                  print("HTTP POST TOKEN");
                  Map<String, dynamic> jsonPostToken = await api.postToken(numAttemps: 5, timeoutDuration: Duration(seconds: 5));

                  print("HTTP GET TOKEN");
                  Map<String, dynamic> jsonGetToken = await api.getToken(jsonPostToken["access_token"], numAttemps: 5, timeoutDuration: Duration(seconds: 5));

                  print("HTTP POST DATAPOINT");
                  Map<String, dynamic> jsonPostDatapoint = await api.postDataPoint(jsonPostToken["access_token"], json.encode(_dataPoint), numAttemps: 5, timeoutDuration: Duration(seconds: 5));
                },
                child: Text("POST Datapoint"),
              ),

              // Boton para probar BATCH de varios datapoints
              ElevatedButton(
                onPressed: () async {
                  Api api = Api();

                  print("HTTP POST TOKEN");
                  Map<String, dynamic> jsonPostToken = await api.postToken(numAttemps: 5, timeoutDuration: Duration(seconds: 5));

                  print("HTTP GET TOKEN");
                  Map<String, dynamic> jsonGetToken = await api.getToken(jsonPostToken["access_token"], numAttemps: 5, timeoutDuration: Duration(seconds: 5));

                  print("HTTP BATCH DATAPOINT");
                  final Directory directory = await getApplicationDocumentsDirectory();
                  final path = '${directory.path}/datapoints.json';
                  await _appendDataPointFile(path, json.encode(_dataPoint));
                  File file = File(path);
                  String datapoints = await file.readAsString();
                  await api.sendBatchDataPoint(jsonPostToken["access_token"], datapoints, numAttemps: 5, timeoutDuration: Duration(seconds: 5));
                  _deleteBatchDataPointFile(path);
                },
                child: Text("BATCH Datapoints"),
              ),
            ],
          ),

          Container(
            margin: EdgeInsets.all(20),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text("Sensores:", style: TextStyle(fontSize: 20)),
                Text("Connectivity: ${_connectionStatus.toString()}"),
                Text("Activity: ${_activity.type.name} (${_activity.confidence.name})"),
                (_locationData == null) ? Text("Location: NULL") : Text("Location: ${_locationData!.latitude}º, ${_locationData!.longitude}º"),
                Text("Bluetooth: ${devicesList.length}"),
              ],
            ),
          ),
          Center(
            child: ElevatedButton(
              child: Text("Encuesta"),
              onPressed: () {
                Navigator.push(
                  context,
                  MaterialPageRoute(builder: (context) => SurveyTaskRoute()),
                );
              },
            ),
          ),
        ],
      ),
    );
  }
}

Future _createDataPointFile(String path) async {
  final File file = File(path);
  await file.writeAsString("[]");
}

Future _appendDataPointFile(String path, String datapoint) async {
  final File file = File(path);
  bool fileExists = await file.exists();

  if(!fileExists)
    await _createDataPointFile(path);

  dynamic datapointsJSON = json.decode(await file.readAsString());
  datapointsJSON.add(json.decode(datapoint));
  await file.writeAsString(json.encode(datapointsJSON));
}

Future _deleteBatchDataPointFile(String path) async {
  final File file = File(path);
  bool fileExists = await file.exists();

  if(fileExists)
    await file.delete();
}

// Example datapoint
final _dataPoint = {
  "carp_header":{
    "study_id":"aFeH8",
    "device_role_name":"masterphone with USER_CODE = A3FNzaFeH8. Local Time = ${DateTime.now().toString()}",
    "user_id":"A3FN",
    "start_time": DateTime.now().toUtc().toIso8601String(),
    "data_format":{
      "namespace":"dk.cachet.carp",
      "name":"adhoc"
    }
  },

  "carp_body":{
    "id":"6f77caed-5067-4877-a26d-f94386c0984b",
    "data":"Activity: STOLL; Confidence: 100"
  }
};