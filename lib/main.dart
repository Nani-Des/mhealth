import 'dart:convert';
import 'dart:ui';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_core/firebase_core.dart';
import 'package:flutter/material.dart';
import 'package:hive/hive.dart';
import 'package:hive_flutter/adapters.dart';
import 'package:flutter_dotenv/flutter_dotenv.dart';
import 'package:firebase_messaging/firebase_messaging.dart';
import 'package:flutter_local_notifications/flutter_local_notifications.dart';
import 'package:cached_network_image/cached_network_image.dart';
import 'package:nhap/try.dart';
import 'package:showcaseview/showcaseview.dart';
import 'Appointments/referral_form.dart';
import 'Auth/auth_screen.dart';
import 'Auth/auth_service.dart';
import 'ChatModule/chat_module.dart';
import 'Home/home_page.dart';
import 'Maps/map_screen.dart';
import 'package:geolocator/geolocator.dart';
import 'package:provider/provider.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'booking_page.dart';

// Background message handler
Future<void> _firebaseMessagingBackgroundHandler(RemoteMessage message) async {
  await Firebase.initializeApp();
  print('Handling background message: ${message.messageId}');
}

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
  FirebaseFirestore.instance.settings = const Settings(persistenceEnabled: true);

  // Initialize FCM
  try {
    FirebaseMessaging.onBackgroundMessage(_firebaseMessagingBackgroundHandler);
    FirebaseMessaging messaging = FirebaseMessaging.instance;
    await messaging.requestPermission(
      alert: true,
      badge: true,
      sound: true,
    );
    await messaging.setForegroundNotificationPresentationOptions(
      alert: true,
      badge: true,
      sound: true,
    );

    // Initialize local notifications
    final FlutterLocalNotificationsPlugin localNotificationsPlugin = FlutterLocalNotificationsPlugin();
    const AndroidInitializationSettings androidSettings = AndroidInitializationSettings('@mipmap/ic_launcher');
    const InitializationSettings initSettings = InitializationSettings(android: androidSettings);
    await localNotificationsPlugin.initialize(
      initSettings,
      onDidReceiveNotificationResponse: (response) async {
        if (response.payload != null) {
          final data = Map<String, dynamic>.from(jsonDecode(response.payload!));
          final userId = FirebaseAuth.instance.currentUser?.uid;
          if (userId != null && (data['type'] == 'new_booking' || data['type'] == 'status_update' || data['type'] == 'reminder')) {
            Navigator.of(navigatorKey.currentContext!).pushReplacement(
              MaterialPageRoute(builder: (context) => BookingPage(currentUserId: userId)),
            );
          }
        }
      },
    );

    // Store FCM token
    String? token = await messaging.getToken();
    final userId = FirebaseAuth.instance.currentUser?.uid;
    if (token != null && userId != null) {
      await FirebaseFirestore.instance.collection('Users').doc(userId).update({
        'fcmToken': token,
      });
    }

    // Handle initial message
    RemoteMessage? initialMessage = await messaging.getInitialMessage();
    if (initialMessage != null && userId != null) {
      if (initialMessage.data['type'] == 'new_booking' || initialMessage.data['type'] == 'status_update' || initialMessage.data['type'] == 'reminder') {
        WidgetsBinding.instance.addPostFrameCallback((_) {
          Navigator.of(navigatorKey.currentContext!).pushReplacement(
            MaterialPageRoute(builder: (context) => BookingPage(currentUserId: userId)),
          );
        });
      }
    }

    // Handle message opened from background
    FirebaseMessaging.onMessageOpenedApp.listen((RemoteMessage message) {
      final userId = FirebaseAuth.instance.currentUser?.uid;
      if (userId != null && (message.data['type'] == 'new_booking' || message.data['type'] == 'status_update' || message.data['type'] == 'reminder')) {
        Navigator.of(navigatorKey.currentContext!).pushReplacement(
          MaterialPageRoute(builder: (context) => BookingPage(currentUserId: userId)),
        );
      }
    });
  } catch (e) {
    print('Error initializing FCM: $e');
  }

  // Initialize cached_network_image
  try {
    CachedNetworkImage.logLevel = CacheManagerLogLevel.debug;
    imageCache.maximumSizeBytes = 100 * 1024 * 1024; // 100 MB
    PaintingBinding.instance.imageCache.maximumSizeBytes = 100 * 1024 * 1024;
  } catch (e) {
    print('Error initializing image cache: $e');
  }

  await CallService().clearOldNotifications();
  await WordFilterService().initialize();
  CallService().initialize();

  runApp(const MyApp());
}

// Global navigator key for notification navigation
final GlobalKey<NavigatorState> navigatorKey = GlobalKey<NavigatorState>();

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
    return MultiProvider(
      providers: [
        ChangeNotifierProvider(create: (_) => AuthService()),
        ChangeNotifierProvider(
          create: (context) {
            final userModel = UserModel();
            try {
              final userId = FirebaseAuth.instance.currentUser?.uid;
              userModel.setUserId(userId);
            } catch (e) {
              print('Error initializing user ID: $e');
            }
            return userModel;
          },
        ),
      ],
      child: ShowCaseWidget(
        builder: (context) => MaterialApp(
          title: 'nhap',
          theme: ThemeData(
            colorScheme: ColorScheme.fromSeed(seedColor: Colors.white),
            useMaterial3: true,
            scaffoldBackgroundColor: Colors.white,
          ),
          home: const CustomTransitionScreen(),
          debugShowCheckedModeBanner: false,
          navigatorKey: navigatorKey,
        ),
      ),
    );
  }
}

class CustomTransitionScreen extends StatefulWidget {
  const CustomTransitionScreen({super.key});

  @override
  _CustomTransitionScreenState createState() => _CustomTransitionScreenState();
}

class _CustomTransitionScreenState extends State<CustomTransitionScreen> with SingleTickerProviderStateMixin {
  late AnimationController _controller;
  late Animation<double> _rotationAnimation;
  late Animation<double> _scaleAnimation;

  @override
  void initState() {
    super.initState();
    _controller = AnimationController(
      duration: const Duration(seconds: 2),
      vsync: this,
    );

    _rotationAnimation = Tween<double>(begin: 0, end: 2 * 3.14159).animate(
      CurvedAnimation(parent: _controller, curve: Curves.easeInOut),
    );

    _scaleAnimation = Tween<double>(begin: 2.0, end: 0.5).animate(
      CurvedAnimation(parent: _controller, curve: Curves.easeInOut),
    );

    _controller.forward().then((_) {
      Navigator.pushReplacement(
        context,
        MaterialPageRoute(builder: (context) => const LocationPermissionScreen()),
      );
    });
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.white,
      body: Center(
        child: AnimatedBuilder(
          animation: _controller,
          builder: (context, child) {
            return Transform.rotate(
              angle: _rotationAnimation.value,
              child: Transform.scale(
                scale: _scaleAnimation.value,
                child: Image.asset('assets/Icons/Icon.png', width: 200, height: 200),
              ),
            );
          },
        ),
      ),
    );
  }
}

class LocationPermissionScreen extends StatelessWidget {
  const LocationPermissionScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.white,
      body: SafeArea(
        child: Center(
          child: Padding(
            padding: const EdgeInsets.all(20.0),
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                Image.asset('assets/Icons/Icon.png', width: 100, height: 100),
                const SizedBox(height: 20),
                const Text(
                  'We Need Your Location',
                  style: TextStyle(
                    fontSize: 24,
                    fontWeight: FontWeight.bold,
                  ),
                ),
                const SizedBox(height: 10),
                const Text(
                  'To provide you with the best experience, we need your location to find healthcare providers, professionals, and hospitals near you.',
                  textAlign: TextAlign.center,
                  style: TextStyle(fontSize: 16),
                ),
                const SizedBox(height: 30),
                ElevatedButton(
                  onPressed: () async {
                    await _requestLocationPermission();
                    Navigator.pushReplacement(
                      context,
                      MaterialPageRoute(builder: (context) => HomePage()),
                    );
                  },
                  child: const Text('Allow Location Access'),
                ),
                const SizedBox(height: 10),
                TextButton(
                  onPressed: () {
                    Navigator.pushReplacement(
                      context,
                      MaterialPageRoute(builder: (context) => HomePage()),
                    );
                  },
                  child: const Text('Skip for Now'),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

class UserModel with ChangeNotifier {
  String? _userId;

  String? get userId => _userId;

  void setUserId(String? userId) {
    _userId = userId;
    notifyListeners();
  }

  void clearUserId() {
    _userId = null;
    notifyListeners();
  }
}