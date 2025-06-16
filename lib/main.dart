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

// Global navigator key for notification navigation
final GlobalKey<NavigatorState> navigatorKey = GlobalKey<NavigatorState>();

// Background message handler
@pragma('vm:entry-point')
Future<void> _firebaseMessagingBackgroundHandler(RemoteMessage message) async {
  await Firebase.initializeApp();

  // Get current user ID if available
  final userId = FirebaseAuth.instance.currentUser?.uid;
  final data = message.data;

  // Only process if the message is for the current user
  if (userId != null && data['toUid'] == userId) {
    final flutterLocalNotificationsPlugin = FlutterLocalNotificationsPlugin();

    // Initialize notifications
    await flutterLocalNotificationsPlugin.initialize(
      const InitializationSettings(android: AndroidInitializationSettings('@mipmap/ic_launcher')),
    );

    // Common notification details
    final androidDetails = AndroidNotificationDetails(
      data['type'] == 'new_message' ? 'chat_channel' : 'booking_channel',
      data['type'] == 'new_message' ? 'Chat Notifications' : 'Booking Notifications',
      importance: Importance.max,
      priority: Priority.high,
    );
    final notificationDetails = NotificationDetails(android: androidDetails);

    // Show notification
    await flutterLocalNotificationsPlugin.show(
      0,
      message.notification?.title ?? (data['type'] == 'new_message' ? 'New Message' : 'Booking Update'),
      message.notification?.body ?? 'You have a new notification',
      notificationDetails,
      payload: jsonEncode(data),
    );
  }
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
      // Update the notification tap handler
      onDidReceiveNotificationResponse: (response) async {
        if (response.payload != null) {
          final data = Map<String, dynamic>.from(jsonDecode(response.payload!));
          final userId = FirebaseAuth.instance.currentUser?.uid;

          // Verify the notification is for this user
          if (userId != null && data['toUid'] == userId) {
            if (data['type'] == 'new_message') {
              navigatorKey.currentState?.push(
                MaterialPageRoute(
                  builder: (context) => ChatThreadDetailsPage(
                    chatId: data['chatId'],
                    toName: data['senderName'] ?? 'User',
                    toUid: data['fromUid'],
                    fromUid: userId,
                  ),
                ),
              );
            } else if (data['type'] == 'new_booking' ||
                data['type'] == 'status_update' ||
                data['type'] == 'reminder') {
              navigatorKey.currentState?.pushReplacement(
                MaterialPageRoute(builder: (context) => BookingPage(currentUserId: userId)),
              );
            }
          }
        }
      },
    );

    // Store FCM token and handle refreshes
    String? token = await messaging.getToken();
    final userId = FirebaseAuth.instance.currentUser?.uid;
    if (token != null && userId != null) {
      await FirebaseFirestore.instance.collection('Users').doc(userId).update({
        'fcmToken': token,
      });
    }

    // Handle token refreshes
    FirebaseMessaging.instance.onTokenRefresh.listen((newToken) async {
      final userId = FirebaseAuth.instance.currentUser?.uid;
      if (userId != null) {
        await FirebaseFirestore.instance.collection('Users').doc(userId).update({
          'fcmToken': newToken,
        });
      }
    });

    // Handle initial message
    RemoteMessage? initialMessage = await messaging.getInitialMessage();
    if (initialMessage != null) {
      final userId = FirebaseAuth.instance.currentUser?.uid;
      final data = initialMessage.data;

      if (userId != null && data['toUid'] == userId) {
        WidgetsBinding.instance.addPostFrameCallback((_) {
          if (data['type'] == 'new_message') {
            navigatorKey.currentState?.push(
              MaterialPageRoute(
                builder: (context) => ChatThreadDetailsPage(
                  chatId: data['chatId'],
                  toName: data['senderName'] ?? 'User',
                  toUid: data['fromUid'],
                  fromUid: userId,
                ),
              ),
            );
          } else if (data['type'] == 'new_booking' ||
              data['type'] == 'status_update' ||
              data['type'] == 'reminder') {
            navigatorKey.currentState?.pushReplacement(
              MaterialPageRoute(builder: (context) => BookingPage(currentUserId: userId)),
            );
          }
        });
      }
    }

    // Handle message opened from background
    FirebaseMessaging.onMessageOpenedApp.listen((RemoteMessage message) {
      final userId = FirebaseAuth.instance.currentUser?.uid;
      if (userId != null) {
        if (message.data['type'] == 'new_message') {
          Navigator.of(navigatorKey.currentContext!).push(
            MaterialPageRoute(
              builder: (context) => ChatThreadDetailsPage(
                chatId: message.data['chatId'],
                toName: 'User',
                toUid: message.data['fromUid'],
                fromUid: message.data['toUid'],
              ),
            ),
          );
        } else if (message.data['type'] == 'new_booking' ||
            message.data['type'] == 'status_update' ||
            message.data['type'] == 'reminder') {
          Navigator.of(navigatorKey.currentContext!).pushReplacement(
            MaterialPageRoute(builder: (context) => BookingPage(currentUserId: userId)),
          );
        }
      }
    });

    // Handle foreground messages
    FirebaseMessaging.onMessage.listen((RemoteMessage message) async {
      final userId = FirebaseAuth.instance.currentUser?.uid;
      final data = message.data;

      // Only show if message is for this user
      if (userId != null && data['toUid'] == userId && message.notification != null) {
        final notification = message.notification!;
        final androidDetails = AndroidNotificationDetails(
          data['type'] == 'new_message' ? 'chat_channel' : 'booking_channel',
          data['type'] == 'new_message' ? 'Chat Notifications' : 'Booking Notifications',
          importance: Importance.max,
          priority: Priority.high,
        );
        final notificationDetails = NotificationDetails(android: androidDetails);

        localNotificationsPlugin.show(
          0,
          notification.title,
          notification.body,
          notificationDetails,
          payload: jsonEncode(data),
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
      body: Center(
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