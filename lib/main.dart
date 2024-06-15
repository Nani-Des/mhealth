import 'package:firebase_core/firebase_core.dart';
import 'package:flutter/material.dart';
import 'package:mhealth/Registration/registration_screen.dart';

void main() async{
  WidgetsFlutterBinding.ensureInitialized();
  await Firebase.initializeApp(
      options: FirebaseOptions(
        apiKey: 'AIzaSyAUt_W7sme9H31aO3dLzqI1aNSeQVMClEo',
        appId: '1:346868082875:android:6e61d878b9540d82c7e19e',
        messagingSenderId: '346868082875',
        projectId: 'mhealth-6191e',
        storageBucket: 'mhealth-6191e.appspot.com',
      )
  );
  runApp(const MyApp());

}

class MyApp extends StatelessWidget {
  const MyApp({super.key});

  // This widget is the root of your application.
  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'mhealth',
      theme: ThemeData(

        colorScheme: ColorScheme.fromSeed(seedColor: Colors.deepPurple),
        useMaterial3: true,
      ),
      home: RegistrationScreen(),
    );
  }
}

