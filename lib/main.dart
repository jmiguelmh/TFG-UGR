import 'package:flutter/material.dart';
import 'package:permission_handler/permission_handler.dart';
import 'package:pruebas/background_service/background.dart';
import 'package:pruebas/research_package/survey.dart';
import 'package:shared_preferences/shared_preferences.dart';

late SharedPreferences preferences;

void main() async {
  WidgetsFlutterBinding.ensureInitialized();
  preferences = await SharedPreferences.getInstance();
  runApp(MyApp());
}

class MyApp extends StatelessWidget {

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      home: MyHomePage(),
    );
  }
}

class MyHomePage extends StatefulWidget {
  @override
  _MyHomePageState createState() => _MyHomePageState();
}

class _MyHomePageState extends State<MyHomePage> {
  BackgroundService backgroundService = BackgroundService();
  bool samplingSensors = false;
  bool surveyReady = false;

  @override
  void initState() {
    super.initState();
    surveyReady = preferences.getBool('surveyReady') ?? false;
    samplingSensors = preferences.getBool('samplingSensors') ?? false;
  }

  @override
  void dispose() {
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {

    if (surveyReady) {
      // Navigating to SurveyTaskRoute after a delay
      WidgetsBinding.instance.addPostFrameCallback((_) {
        Future.delayed(Duration.zero, () {
          Navigator.push(context, MaterialPageRoute(builder: (context) => SurveyTaskRoute()));
        });
      });
    }

    return Scaffold(
      appBar: AppBar(
        title: Text('Home'),
      ),
      body: Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.spaceEvenly,
          children: [
            ElevatedButton(
              child: Text((!samplingSensors) ? "Start sampling" : "Stop sampling"),
              onPressed: () async {
                bool locationPermission = false;
                bool activityRecognitionPermission = false;
                bool bluetoothScanPermission = false;

                // Request permission for location
                if(await Permission.location.request().isGranted)
                  if(await Permission.locationAlways.request().isGranted) {
                    print("LocationAlways permission granted");
                    locationPermission = true;
                  }

                // Request permission for activity recognition
                if(await Permission.activityRecognition.request().isGranted) {
                  print("ActivityRecognition permission granted");
                  activityRecognitionPermission = true;
                }

                // Request permission for bluetooth scanning
                if (await Permission.bluetoothScan.request().isGranted) {
                  print("BluetoothScan permission granted");
                  bluetoothScanPermission = true;
                }

                if (locationPermission && activityRecognitionPermission && bluetoothScanPermission) {
                  setState(() {
                    samplingSensors = !samplingSensors;
                  });

                  await preferences.setBool('samplingSensors', samplingSensors);

                  if (samplingSensors) {
                    backgroundService.initializeService();
                  } else {
                    backgroundService.initializeService();
                    backgroundService.stopService();
                  }
                }
              },
            ),
          ],
        ),
      ),
    );
  }
}