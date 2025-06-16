import 'dart:convert';
import 'dart:ui';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_core/firebase_core.dart';
import 'package:flutter/material.dart';
import 'package:hive/hive.dart';
import 'package:hive_flutter/adapters.dart';
import 'package:firebase_messaging/firebase_messaging.dart';
import 'package:flutter_local_notifications/flutter_local_notifications.dart';
import 'package:cached_network_image/cached_network_image.dart';
import 'package:shared_preferences/shared_preferences.dart';
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
import 'firebase_options.dart';
import 'Services/config_service.dart';

// Debug flags
const bool debugDisableFirebase = false; // Set to true to bypass Firebase
const bool debugDisableServices = true; // Disable CallService/WordFilterService

// Background message handler
@pragma('vm:entry-point')
Future<void> _firebaseMessagingBackgroundHandler(RemoteMessage message) async {
  print('Background: Handling message: ${message.messageId}');
  try {
    if (Firebase.apps.isEmpty) {
      await Firebase.initializeApp(options: DefaultFirebaseOptions.currentPlatform);
      print('Background: Firebase initialized in handler');
    }
    final notification = message.notification;
    final data = message.data;

    if (notification != null || data.isNotEmpty) {
      final localNotificationsPlugin = FlutterLocalNotificationsPlugin();
      const androidSettings = AndroidInitializationSettings('@mipmap/ic_launcher');
      const initSettings = InitializationSettings(android: androidSettings);
      await localNotificationsPlugin.initialize(initSettings);

      const androidDetails = AndroidNotificationDetails(
        'booking_channel',
        'Booking Notifications',
        importance: Importance.high,
        priority: Priority.high,
      );
      const notificationDetails = NotificationDetails(android: androidDetails);

      await localNotificationsPlugin.show(
        notification?.hashCode ?? data.hashCode,
        notification?.title ?? data['title'] ?? 'Booking Update',
        notification?.body ?? data['body'] ?? 'You have a new booking notification.',
        notificationDetails,
        payload: jsonEncode(data),
      );
      print('Background: Displayed notification');

      final prefs = await SharedPreferences.getInstance();
      List<String> notifications = prefs.getStringList('pending_notifications') ?? [];
      notifications.add(jsonEncode({
        'messageId': message.messageId,
        'data': message.data,
        'title': notification?.title,
        'body': notification?.body,
      }));
      await prefs.setStringList('pending_notifications', notifications);
    }
  } catch (e) {
    print('Background: Error processing message: $e');
  }
}

void main() async {
  WidgetsFlutterBinding.ensureInitialized();
  print('Main: Starting app initialization');

  // Check for existing Firebase apps
  if (Firebase.apps.isNotEmpty) {
    print('Main: Firebase apps detected: ${Firebase.apps.map((app) => app.name).join(', ')}');
  } else {
    print('Main: No Firebase apps detected initially');
  }

  // Initialize Firebase
  if (!debugDisableFirebase) {
    try {
      if (Firebase.apps.isEmpty) {
        await Firebase.initializeApp(options: DefaultFirebaseOptions.currentPlatform);
        print('Main: Firebase initialized successfully');
      } else {
        print('Main: Firebase already initialized: ${Firebase.apps.map((app) => app.name).join(', ')}');
      }
    } catch (e) {
      print('Main: Firebase initialization failed: $e');
    }
  } else {
    print('Main: Firebase initialization disabled for debugging');
  }

  // Defer all initialization
  WidgetsBinding.instance.addPostFrameCallback((_) async {
    print('Main: Starting post-frame initialization');

    // Initialize Hive
    try {
      await Hive.initFlutter();
      await Hive.openBox('translations');
      print('Main: Hive initialized');
    } catch (e) {
      print('Main: Hive initialization failed: $e');
    }

    // Initialize ConfigService
    if (!debugDisableFirebase) {
      try {
        await ConfigService().init();
      } catch (e) {
        print('Main: ConfigService initialization failed: $e');
      }
    }

    // Apply Firestore settings
    if (!debugDisableFirebase) {
      try {
        FirebaseFirestore.instance.settings = const Settings(
          persistenceEnabled: true,
          cacheSizeBytes: Settings.CACHE_SIZE_UNLIMITED,
        );
        print('Main: Firestore settings applied');
      } catch (e) {
        print('Main: Firestore settings failed: $e');
      }
    }

    // Initialize FCM
    if (!debugDisableFirebase) {
      try {
        FirebaseMessaging.onBackgroundMessage(_firebaseMessagingBackgroundHandler);
        FirebaseMessaging messaging = FirebaseMessaging.instance;
        await messaging.requestPermission(alert: true, badge: true, sound: true);
        await messaging.setForegroundNotificationPresentationOptions(
          alert: true,
          badge: true,
          sound: true,
        );
        print('Main: FCM permissions requested');

        // Initialize local notifications
        final localNotificationsPlugin = FlutterLocalNotificationsPlugin();
        const androidSettings = AndroidInitializationSettings('@mipmap/ic_launcher');
        const initSettings = InitializationSettings(android: androidSettings);
        await localNotificationsPlugin.initialize(
          initSettings,
          onDidReceiveNotificationResponse: (response) async {
            if (response.payload != null) {
              final data = Map<String, dynamic>.from(jsonDecode(response.payload!));
              final userId = FirebaseAuth.instance.currentUser?.uid;
              if (userId != null &&
                  (data['type'] == 'new_booking' ||
                      data['type'] == 'status_update' ||
                      data['type'] == 'reminder' ||
                      data['type'] == 'appointment_reminder' ||
                      data['type'] == 'booking_accepted')) {
                Navigator.of(navigatorKey.currentContext!).push(
                  MaterialPageRoute(
                      builder: (context) => BookingPage(currentUserId: userId)),
                );
              }
            }
          },
        );
        print('Main: Local notifications initialized');

        // Retry FCM token retrieval
        String? token;
        for (int i = 0; i < 3; i++) {
          try {
            token = await messaging.getToken();
            if (token != null) break;
            await Future.delayed(const Duration(seconds: 2));
          } catch (e) {
            print('Main: FCM token retry $i failed: $e');
          }
        }
        final userId = FirebaseAuth.instance.currentUser?.uid;
        if (token != null && userId != null) {
          await FirebaseFirestore.instance
              .collection('Users')
              .doc(userId)
              .set({'fcmToken': token}, SetOptions(merge: true));
          print('Main: FCM token stored for user $userId: $token');
        } else {
          print('Main: Failed to store FCM token');
        }

        // Handle initial message
        RemoteMessage? initialMessage = await messaging.getInitialMessage();
        if (initialMessage != null && userId != null) {
          if (initialMessage.data['type'] == 'new_booking' ||
              initialMessage.data['type'] == 'status_update' ||
              initialMessage.data['type'] == 'reminder' ||
              initialMessage.data['type'] == 'appointment_reminder' ||
              initialMessage.data['type'] == 'booking_accepted') {
            WidgetsBinding.instance.addPostFrameCallback((_) {
              Navigator.of(navigatorKey.currentContext!).push(
                MaterialPageRoute(
                    builder: (context) => BookingPage(currentUserId: userId)),
              );
            });
            print('Main: Handled initial FCM message');
          }
        }

        // Handle message opened from background
        FirebaseMessaging.onMessageOpenedApp.listen((RemoteMessage message) {
          final userId = FirebaseAuth.instance.currentUser?.uid;
          if (userId != null &&
              (message.data['type'] == 'new_booking' ||
                  message.data['type'] == 'status_update' ||
                  message.data['type'] == 'reminder' ||
                  message.data['type'] == 'appointment_reminder' ||
                  message.data['type'] == 'booking_accepted')) {
            Navigator.of(navigatorKey.currentContext!).push(
              MaterialPageRoute(
                  builder: (context) => BookingPage(currentUserId: userId)),
            );
            print('Main: Handled FCM message opened from background');
          }
        });

        // Handle foreground messages
        FirebaseMessaging.onMessage.listen((RemoteMessage message) {
          print('Main: Foreground message received: ${message.messageId}');
          if (message.notification != null) {
            localNotificationsPlugin.show(
              message.hashCode,
              message.notification!.title,
              message.notification!.body,
              const NotificationDetails(
                android: AndroidNotificationDetails(
                  'booking_channel',
                  'Booking Notifications',
                  importance: Importance.high,
                  priority: Priority.high,
                ),
              ),
              payload: jsonEncode(message.data),
            );
            print('Main: Displayed foreground notification');
          }
        });

        // Handle token refresh
        messaging.onTokenRefresh.listen((newToken) async {
          final userId = FirebaseAuth.instance.currentUser?.uid;
          if (userId != null) {
            await FirebaseFirestore.instance
                .collection('Users')
                .doc(userId)
                .set({'fcmToken': newToken}, SetOptions(merge: true));
            print('Main: FCM token refreshed for user $userId: $newToken');
          }
        });
      } catch (e) {
        print('Main: Error initializing FCM: $e');
      }
    }

    // Initialize cached_network_image
    try {
      CachedNetworkImage.logLevel = CacheManagerLogLevel.debug;
      imageCache.maximumSizeBytes = 100 * 1024 * 1024; // 100 MB
      PaintingBinding.instance.imageCache.maximumSizeBytes = 100 * 1024 * 1024;
      print('Main: Image cache initialized');
    } catch (e) {
      print('Main: Error initializing image cache: $e');
    }

    // Initialize other services
    if (!debugDisableServices) {
      try {
        await CallService().clearOldNotifications();
        await WordFilterService().initialize();
        CallService().initialize();
        print('Main: CallService and WordFilterService initialized');
      } catch (e) {
        print('Main: Error initializing services: $e');
      }
    } else {
      print('Main: CallService and WordFilterService disabled for debugging');
    }
  });

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

class _CustomTransitionScreenState extends State<CustomTransitionScreen>
    with SingleTickerProviderStateMixin {
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
                      MaterialPageRoute(builder: (context) =>  HomePage()),
                    );
                  },
                  child: const Text('Allow Location Access'),
                ),
                const SizedBox(height: 10),
                TextButton(
                  onPressed: () {
                    Navigator.pushReplacement(
                      context,
                      MaterialPageRoute(builder: (context) =>  HomePage()),
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