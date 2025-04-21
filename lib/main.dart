import 'dart:ui';

import 'package:firebase_core/firebase_core.dart';
import 'package:flutter/material.dart';
import 'package:hive/hive.dart';
import 'package:hive_flutter/adapters.dart';
import 'package:flutter_dotenv/flutter_dotenv.dart';
import 'package:mhealth/try.dart';
import 'package:showcaseview/showcaseview.dart';
import 'Appointments/referral_form.dart';
import 'ChatModule/chat_module.dart';
import 'Home/home_page.dart';
import 'Maps/map_screen.dart';
import 'package:geolocator/geolocator.dart';

void main() async {
  WidgetsFlutterBinding.ensureInitialized();
  await Hive.initFlutter();
  await Hive.openBox('translations');
  await dotenv.load();
  await Firebase.initializeApp(
    options: FirebaseOptions(
      apiKey: dotenv.env['FIREBASE_API_KEY']!,
      appId: dotenv.env['FIREBASE_APP_ID']!,
      messagingSenderId: dotenv.env['FIREBASE_MESSAGING_SENDER_ID']!,
      projectId: dotenv.env['FIREBASE_PROJECT_ID']!,
      storageBucket: dotenv.env['FIREBASE_STORAGE_BUCKET']!,
    ),
  );

  // Request location permission before app loads
  await _requestLocationPermission();

  await CallService().clearOldNotifications();

  await WordFilterService().initialize();

  CallService().initialize();

  runApp(const MyApp());
}

Future<void> _requestLocationPermission() async {
  LocationPermission permission = await Geolocator.checkPermission();
  if (permission == LocationPermission.denied) {
    permission = await Geolocator.requestPermission();
    if (permission == LocationPermission.denied) {
      print('Location permissions denied');
      return;
    }
  }
  if (permission == LocationPermission.deniedForever) {
    print('Location permissions permanently denied');
    return;
  }
  print('Location permissions granted');
}

class MyApp extends StatelessWidget {
  const MyApp({super.key});

  @override
  Widget build(BuildContext context) {
    return ShowCaseWidget(
      builder: (context) => MaterialApp(
        title: 'mhealth',
        theme: ThemeData(
          colorScheme: ColorScheme.fromSeed(seedColor: Colors.white),
          useMaterial3: true,
        ),
        home: HomePage(), // No need to pass permissionsGranted
        debugShowCheckedModeBanner: false,
      ),
    );
  }
}