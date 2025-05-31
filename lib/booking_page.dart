import 'dart:convert';
import 'package:firebase_core/firebase_core.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:connectivity_plus/connectivity_plus.dart';
import 'package:firebase_messaging/firebase_messaging.dart';
import 'package:flutter_local_notifications/flutter_local_notifications.dart';
import 'package:cached_network_image/cached_network_image.dart';
import 'package:http/http.dart' as http;
import 'dart:async';
import 'Home/home_page.dart';
import 'booking_details.dart';

// Background message handler (must be top-level or static)
Future<void> _firebaseMessagingBackgroundHandler(RemoteMessage message) async {
  await Firebase.initializeApp();
  if (kDebugMode) {
    print('Handling background message: ${message.messageId}');
    print('Background message data: ${message.data}');
  }

  final notification = message.notification;
  final data = message.data;

  const AndroidInitializationSettings androidSettings = AndroidInitializationSettings('@mipmap/ic_launcher');
  const InitializationSettings initSettings = InitializationSettings(android: androidSettings);
  final FlutterLocalNotificationsPlugin localNotificationsPlugin = FlutterLocalNotificationsPlugin();
  await localNotificationsPlugin.initialize(initSettings);

  const AndroidNotificationDetails androidDetails = AndroidNotificationDetails(
    'booking_channel',
    'Booking Notifications',
    importance: Importance.max,
    priority: Priority.high,
  );
  const NotificationDetails notificationDetails = NotificationDetails(android: androidDetails);

  if (notification != null) {
    await localNotificationsPlugin.show(
      notification.hashCode,
      notification.title,
      notification.body,
      notificationDetails,
      payload: jsonEncode(data),
    );
  } else if (data.isNotEmpty) {
    await localNotificationsPlugin.show(
      data.hashCode,
      data['title'] ?? 'Booking Update',
      data['body'] ?? 'You have a new booking notification.',
      notificationDetails,
      payload: jsonEncode(data),
    );
  }

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

class BookingPage extends StatefulWidget {
  final String currentUserId;
  const BookingPage({required this.currentUserId, Key? key}) : super(key: key);

  @override
  _BookingPageState createState() => _BookingPageState();
}

class _BookingPageState extends State<BookingPage> with SingleTickerProviderStateMixin {
  late Stream<QuerySnapshot> _allBookingsStream;
  late Stream<DocumentSnapshot> _appointmentsStream;
  late AnimationController _animationController;
  late Animation<double> _progressAnimation;
  bool _isDoctor = false;
  bool _isOffline = false;
  List<Map<String, dynamic>> _cachedRequests = [];
  List<Map<String, dynamic>> _cachedAppointments = [];
  int _selectedTabIndex = 0;
  Timer? _reminderTimer;

  final FirebaseMessaging _messaging = FirebaseMessaging.instance;
  final FlutterLocalNotificationsPlugin _localNotificationsPlugin = FlutterLocalNotificationsPlugin();

  @override
  void initState() {
    super.initState();
    _allBookingsStream = FirebaseFirestore.instance.collection('Bookings').snapshots();
    _appointmentsStream = FirebaseFirestore.instance.collection('Bookings').doc(widget.currentUserId).snapshots();
    _animationController = AnimationController(
      vsync: this,
      duration: const Duration(seconds: 2),
    )..repeat();
    _progressAnimation = Tween<double>(begin: 0, end: 1).animate(_animationController);
    _checkUserRole();
    _checkConnectivity();
    _loadCachedData();
    _setupFCM();
    _checkPendingNotifications();
    _checkNewAppointmentsOnLogin();
    _startReminderChecks();
  }

  void _startReminderChecks() {
    _reminderTimer = Timer.periodic(const Duration(hours: 1), (timer) async {
      if (!_isOffline) {
        await _checkUpcomingAppointments();
      }
    });
    _checkUpcomingAppointments();
  }

  Future<void> _sendFCMNotification(String? fcmToken, String title, String body, Map<String, dynamic> data) async {
    if (fcmToken == null) return;
    try {
      final serverKey = 'YOUR_FCM_SERVER_KEY'; // Replace with your FCM server key
      final response = await http.post(
        Uri.parse('https://fcm.googleapis.com/fcm/send'),
        headers: {
          'Content-Type': 'application/json',
          'Authorization': 'key=$serverKey',
        },
        body: jsonEncode({
          'to': fcmToken,
          'notification': {
            'title': title,
            'body': body,
          },
          'data': data,
        }),
      );
      if (response.statusCode == 200) {
        if (kDebugMode) {
          print('FCM notification sent to $fcmToken');
        }
      } else {
        if (kDebugMode) {
          print('Failed to send FCM notification: ${response.body}');
        }
      }
    } catch (e) {
      if (kDebugMode) {
        print('Error sending FCM notification: $e');
      }
    }
  }

  Future<void> _checkUpcomingAppointments() async {
    if (_isOffline) return;
    try {
      final prefs = await SharedPreferences.getInstance();
      final sentReminders = prefs.getStringList('sent_reminders_${widget.currentUserId}') ?? [];

      QuerySnapshot bookingsSnapshot = await FirebaseFirestore.instance.collection('Bookings').get();
      List<Map<String, dynamic>> upcomingAppointments = [];

      for (var doc in bookingsSnapshot.docs) {
        var bookings = doc['Bookings'] as List<dynamic>? ?? [];
        for (var booking in bookings) {
          if ((booking['status'] == 'Active' || booking['status'] == 'Pending') &&
              booking['date'] is Timestamp) {
            final appointmentDate = booking['date'].toDate();
            final now = DateTime.now();
            final difference = appointmentDate.difference(now);
            if (difference.inHours >= 23 && difference.inHours <= 25) {
              upcomingAppointments.add({
                ...booking,
                'userId': doc.id,
              });
            }
          }
        }
      }

      for (var appointment in upcomingAppointments) {
        final reminderId = '${appointment['userId']}_${appointment['doctorId']}_${appointment['date'].seconds}';
        if (!sentReminders.contains(reminderId)) {
          final formattedDate = DateFormat('MMM dd, yyyy HH:mm').format(appointment['date'].toDate());
          final patientDoc = await FirebaseFirestore.instance
              .collection('Users')
              .doc(appointment['userId'])
              .get();
          final doctorDoc = await FirebaseFirestore.instance
              .collection('Users')
              .doc(appointment['doctorId'])
              .get();

          final patientName = patientDoc.exists
              ? '${patientDoc['Fname'] ?? 'Unknown'} ${patientDoc['Lname'] ?? 'Unknown'}'
              : 'Unknown';
          final doctorName = doctorDoc.exists
              ? '${doctorDoc['Fname'] ?? 'Unknown'} ${doctorDoc['Lname'] ?? 'Unknown'}'
              : 'Unknown';
          final patientFcmToken = patientDoc.exists ? patientDoc['fcmToken'] : null;
          final doctorFcmToken = doctorDoc.exists ? doctorDoc['fcmToken'] : null;

          await _sendFCMNotification(
            patientFcmToken,
            'Appointment Reminder',
            'Your appointment with $doctorName on $formattedDate is tomorrow.',
            {
              'type': 'appointment_reminder',
              'bookingDate': appointment['date'].seconds.toString(),
              'userId': appointment['userId'],
              'doctorId': appointment['doctorId'],
            },
          );

          await _sendFCMNotification(
            doctorFcmToken,
            'Appointment Reminder',
            'Your appointment with $patientName on $formattedDate is tomorrow.',
            {
              'type': 'appointment_reminder',
              'bookingDate': appointment['date'].seconds.toString(),
              'userId': appointment['userId'],
              'doctorId': appointment['doctorId'],
            },
          );

          if (widget.currentUserId == appointment['userId'] ||
              widget.currentUserId == appointment['doctorId']) {
            const AndroidNotificationDetails androidDetails = AndroidNotificationDetails(
              'booking_channel',
              'Booking Notifications',
              importance: Importance.max,
              priority: Priority.high,
            );
            const NotificationDetails notificationDetails = NotificationDetails(android: androidDetails);
            await _localNotificationsPlugin.show(
              reminderId.hashCode,
              'Appointment Reminder',
              widget.currentUserId == appointment['userId']
                  ? 'Your appointment with $doctorName on $formattedDate is tomorrow.'
                  : 'Your appointment with $patientName on $formattedDate is tomorrow.',
              notificationDetails,
              payload: jsonEncode({
                'type': 'appointment_reminder',
                'bookingDate': appointment['date'].seconds.toString(),
                'userId': appointment['userId'],
                'doctorId': appointment['doctorId'],
              }),
            );
          }

          sentReminders.add(reminderId);
          await prefs.setStringList('sent_reminders_${widget.currentUserId}', sentReminders);
        }
      }
    } catch (e) {
      if (kDebugMode) {
        print('Error checking upcoming appointments: $e');
      }
      _showModernSnackBar(context, 'Failed to check upcoming appointments', isError: true);
    }
  }

  Future<void> _checkPendingNotifications() async {
    final prefs = await SharedPreferences.getInstance();
    final notifications = prefs.getStringList('pending_notifications') ?? [];
    if (notifications.isNotEmpty) {
      for (var notification in notifications) {
        final data = jsonDecode(notification) as Map<String, dynamic>;
        _handleNotificationTap(data['data'] ?? {});
      }
      await prefs.setStringList('pending_notifications', []);
    }
  }

  Future<void> _checkNewAppointmentsOnLogin() async {
    if (_isOffline) return;
    try {
      final prefs = await SharedPreferences.getInstance();
      final processedAppointments = prefs.getStringList('processed_appointments_${widget.currentUserId}') ?? [];

      QuerySnapshot bookingsSnapshot;
      if (_isDoctor) {
        bookingsSnapshot = await FirebaseFirestore.instance.collection('Bookings').get();
      } else {
        bookingsSnapshot = await FirebaseFirestore.instance
            .collection('Bookings')
            .where(FieldPath.documentId, isEqualTo: widget.currentUserId)
            .get();
      }

      List<Map<String, dynamic>> newAppointments = [];
      for (var doc in bookingsSnapshot.docs) {
        var bookings = doc['Bookings'] as List<dynamic>? ?? [];
        for (var booking in bookings) {
          if (_isDoctor && booking['doctorId'] == widget.currentUserId && booking['status'] == 'Pending') {
            newAppointments.add({...booking, 'userId': doc.id});
          }
          // Skip patient notifications for their own Pending bookings
        }
      }

      for (var appointment in newAppointments) {
        final appointmentId = '${appointment['userId']}_${appointment['date'].seconds}';
        if (!processedAppointments.contains(appointmentId)) {
          final formattedDate = DateFormat('MMM dd, yyyy HH:mm').format(appointment['date'].toDate());
          final userDoc = await FirebaseFirestore.instance
              .collection('Users')
              .doc(appointment['userId'])
              .get();
          final userName = userDoc.exists
              ? '${userDoc['Fname'] ?? 'Unknown'} ${userDoc['Lname'] ?? 'Unknown'}'
              : 'Unknown';
          final doctorFcmToken = _isDoctor ? (await FirebaseFirestore.instance
              .collection('Users')
              .doc(widget.currentUserId)
              .get())['fcmToken'] : null;

          const AndroidNotificationDetails androidDetails = AndroidNotificationDetails(
            'booking_channel',
            'Booking Notifications',
            importance: Importance.max,
            priority: Priority.high,
          );
          const NotificationDetails notificationDetails = NotificationDetails(android: androidDetails);

          // Local notification for doctor (if current user)
          if (_isDoctor) {
            await _localNotificationsPlugin.show(
              appointmentId.hashCode,
              'New Booking Request',
              'New booking request from $userName on $formattedDate',
              notificationDetails,
              payload: jsonEncode({
                'type': 'new_booking',
                'bookingDate': appointment['date'].seconds.toString(),
                'userId': appointment['userId'],
                'doctorId': appointment['doctorId'],
              }),
            );
          }

          // FCM push notification for doctor
          await _sendFCMNotification(
            doctorFcmToken,
            'New Booking Request',
            'New booking request from $userName on $formattedDate',
            {
              'type': 'new_booking',
              'bookingDate': appointment['date'].seconds.toString(),
              'userId': appointment['userId'],
              'doctorId': appointment['doctorId'],
            },
          );

          processedAppointments.add(appointmentId);
        }
      }

      await prefs.setStringList('processed_appointments_${widget.currentUserId}', processedAppointments);
      await _checkUpcomingAppointments();
    } catch (e) {
      if (kDebugMode) {
        print('Error checking new appointments: $e');
      }
      _showModernSnackBar(context, 'Failed to check new appointments', isError: true);
    }
  }

  Future<void> _setupFCM() async {
    NotificationSettings settings = await _messaging.requestPermission();
    if (settings.authorizationStatus != AuthorizationStatus.authorized) {
      _showModernSnackBar(context, 'Notifications disabled', isError: true);
      return;
    }

    try {
      String? token = await _messaging.getToken();
      if (token != null) {
        await FirebaseFirestore.instance.collection('Users').doc(widget.currentUserId).set(
          {'fcmToken': token},
          SetOptions(merge: true),
        );
        if (kDebugMode) {
          print('FCM token stored for user ${widget.currentUserId}: $token');
        }
      }
    } catch (e) {
      print('Error storing FCM token: $e');
    }

    const AndroidInitializationSettings androidSettings = AndroidInitializationSettings('@mipmap/ic_launcher');
    const InitializationSettings initSettings = InitializationSettings(android: androidSettings);
    await _localNotificationsPlugin.initialize(
      initSettings,
      onDidReceiveNotificationResponse: (response) {
        if (response.payload != null) {
          _handleNotificationTap(jsonDecode(response.payload!));
        }
      },
    );

    FirebaseMessaging.onBackgroundMessage(_firebaseMessagingBackgroundHandler);
    FirebaseMessaging.onMessage.listen(_handleForegroundMessage);
    FirebaseMessaging.onMessageOpenedApp.listen((message) {
      _handleNotificationTap(message.data);
    });

    RemoteMessage? initialMessage = await _messaging.getInitialMessage();
    if (initialMessage != null) {
      _handleNotificationTap(initialMessage.data);
    }

    _messaging.onTokenRefresh.listen((newToken) async {
      await FirebaseFirestore.instance.collection('Users').doc(widget.currentUserId).set(
        {'fcmToken': newToken},
        SetOptions(merge: true),
      );
      if (kDebugMode) {
        print('FCM token refreshed for user ${widget.currentUserId}: $newToken');
      }
    });
  }

  Future<void> _handleForegroundMessage(RemoteMessage message) async {
    final notification = message.notification;
    if (notification != null) {
      const AndroidNotificationDetails androidDetails = AndroidNotificationDetails(
        'booking_channel',
        'Booking Notifications',
        importance: Importance.max,
        priority: Priority.high,
      );
      const NotificationDetails notificationDetails = NotificationDetails(android: androidDetails);
      await _localNotificationsPlugin.show(
        notification.hashCode,
        notification.title,
        notification.body,
        notificationDetails,
        payload: jsonEncode(message.data),
      );
      if (kDebugMode) {
        print('Foreground notification: ${notification.title} - ${notification.body}');
      }
    }
  }

  void _handleNotificationTap(Map<String, dynamic> data) {
    final type = data['type'];
    final bookingDateSeconds = data['bookingDate'];
    final userId = data['userId'];
    final doctorId = data['doctorId'];

    setState(() {
      _selectedTabIndex = _isDoctor ? 0 : 1;
    });

    if (bookingDateSeconds != null && userId != null && doctorId != null) {
      Navigator.push(
        context,
        MaterialPageRoute(
          builder: (context) => BookingDetailsPage(
            userId: userId,
            doctorId: doctorId,
            bookingDate: Timestamp.fromMillisecondsSinceEpoch(int.parse(bookingDateSeconds) * 1000),
            currentUserId: widget.currentUserId,
          ),
        ),
      );
    }
  }

  Future<void> _checkConnectivity() async {
    var connectivityResult = await Connectivity().checkConnectivity();
    setState(() {
      _isOffline = connectivityResult.contains(ConnectivityResult.none);
    });

    Connectivity().onConnectivityChanged.listen((List<ConnectivityResult> results) async {
      setState(() {
        _isOffline = results.contains(ConnectivityResult.none);
      });
      if (!_isOffline) {
        _showModernSnackBar(context, 'Back online, syncing data...');
        await _checkPendingNotifications();
        await _loadCachedData();
        await _checkNewAppointmentsOnLogin();
        await _checkUpcomingAppointments();
      }
    });
  }

  Future<void> _loadCachedData() async {
    final prefs = await SharedPreferences.getInstance();
    final cachedRequests = prefs.getString('cached_requests_${widget.currentUserId}');
    final cachedAppointments = prefs.getString('cached_appointments_${widget.currentUserId}');

    setState(() {
      if (cachedRequests != null) {
        _cachedRequests = List<Map<String, dynamic>>.from(jsonDecode(cachedRequests));
      }
      if (cachedAppointments != null) {
        _cachedAppointments = List<Map<String, dynamic>>.from(jsonDecode(cachedAppointments));
      }
    });
  }

  Future<void> _cacheData(String key, List<Map<String, dynamic>> data) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString(key, jsonEncode(data));
  }

  Future<void> _checkUserRole() async {
    try {
      DocumentSnapshot userDoc = await FirebaseFirestore.instance
          .collection('Users')
          .doc(widget.currentUserId)
          .get();
      if (userDoc.exists) {
        setState(() {
          _isDoctor = userDoc['Role'] == true;
        });
        if (kDebugMode) {
          print('User ${widget.currentUserId} role: ${_isDoctor ? 'Doctor' : 'Patient'}');
        }
      } else {
        _showModernSnackBar(context, 'User not found', isError: true);
      }
    } catch (e) {
      print('Error checking user role: $e');
      _showModernSnackBar(context, 'Failed to load user role', isError: true);
    }
  }

  @override
  void dispose() {
    _animationController.dispose();
    _reminderTimer?.cancel();
    super.dispose();
  }

  Widget _buildSophisticatedProgressIndicator() {
    return AnimatedBuilder(
      animation: _animationController,
      builder: (context, child) {
        return Stack(
          alignment: Alignment.center,
          children: [
            SizedBox(
              width: 80,
              height: 80,
              child: CircularProgressIndicator(
                value: _progressAnimation.value,
                strokeWidth: 8,
                backgroundColor: Colors.teal.withOpacity(0.2),
                valueColor: const AlwaysStoppedAnimation<Color>(Colors.teal),
              ),
            ),
            Container(
              width: 60,
              height: 60,
              decoration: BoxDecoration(
                shape: BoxShape.circle,
                gradient: LinearGradient(
                  colors: [Colors.teal[100]!, Colors.teal[300]!],
                  begin: Alignment.topLeft,
                  end: Alignment.bottomRight,
                ),
                boxShadow: [
                  BoxShadow(
                    color: Colors.teal.withOpacity(0.3),
                    blurRadius: 10,
                    offset: const Offset(0, 4),
                  ),
                ],
              ),
              child: Center(
                child: Text(
                  '${(_progressAnimation.value * 100).toInt()}%',
                  style: const TextStyle(
                    color: Colors.white,
                    fontWeight: FontWeight.bold,
                    fontSize: 18,
                  ),
                ),
              ),
            ),
          ],
        );
      },
    );
  }

  @override
  Widget build(BuildContext context) {
    return DefaultTabController(
      length: _isDoctor ? 2 : 1,
      initialIndex: _selectedTabIndex,
      child: Scaffold(
        appBar: AppBar(
          title: const Text(
            'Bookings',
            style: TextStyle(fontWeight: FontWeight.bold, color: Colors.white),
          ),
          backgroundColor: Colors.teal,
          elevation: 0,
          leading: IconButton(
            icon: const Icon(Icons.arrow_back_ios_new, color: Colors.white),
            onPressed: () {
              Navigator.pushAndRemoveUntil(
                context,
                MaterialPageRoute(builder: (context) => HomePage()),
                    (route) => false,
              );
            },
          ),
          bottom: TabBar(
            onTap: (index) => setState(() => _selectedTabIndex = index),
            indicatorColor: Colors.white,
            labelColor: Colors.white,
            unselectedLabelColor: Colors.white70,
            tabs: [
              if (_isDoctor) const Tab(text: 'Requests'),
              const Tab(text: 'Appointments'),
            ],
          ),
        ),
        body: Container(
          color: Colors.grey[100],
          child: TabBarView(
            children: [
              if (_isDoctor) _buildRequests(),
              _buildAppointments(),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildRequests() {
    if (_isOffline && _cachedRequests.isNotEmpty) {
      return _buildBookingList(_cachedRequests, true);
    }

    return StreamBuilder<QuerySnapshot>(
      stream: _allBookingsStream,
      builder: (context, AsyncSnapshot<QuerySnapshot> snapshot) {
        if (snapshot.connectionState == ConnectionState.waiting) {
          return _buildLoadingState('Requests');
        }
        if (snapshot.hasError) {
          if (kDebugMode) {
            print('Error loading requests: ${snapshot.error}');
          }
          return _buildEmptyState('Error loading requests: ${snapshot.error}');
        }
        if (!snapshot.hasData || snapshot.data!.docs.isEmpty) {
          if (kDebugMode) {
            print('No booking requests found for doctorId: ${widget.currentUserId}');
          }
          return _buildEmptyState('No booking requests found');
        }

        List<Map<String, dynamic>> requests = [];
        for (var doc in snapshot.data!.docs) {
          var bookings = doc['Bookings'] as List<dynamic>? ?? [];
          for (var booking in bookings) {
            if (booking['doctorId'] == widget.currentUserId) {
              if (_isDateInPast(booking['date'])) {
                booking['status'] = 'Terminated';
              }
              requests.add({...booking, 'userId': doc.id});
            }
          }
        }

        if (kDebugMode) {
          print('Fetched ${requests.length} requests for doctorId: ${widget.currentUserId}');
          print('Requests: $requests');
        }

        if (requests.isEmpty) {
          return _buildEmptyState('No booking requests found');
        }

        _cacheData('cached_requests_${widget.currentUserId}', requests);
        requests.sort(_sortBookings);

        return _buildBookingList(requests, true);
      },
    );
  }

  Widget _buildAppointments() {
    if (_isOffline && _cachedAppointments.isNotEmpty) {
      return _buildAppointmentTabs(_cachedAppointments);
    }

    return StreamBuilder<DocumentSnapshot>(
      stream: _appointmentsStream,
      builder: (context, AsyncSnapshot<DocumentSnapshot> snapshot) {
        if (snapshot.connectionState == ConnectionState.waiting) {
          return _buildLoadingState('Appointments');
        }
        if (snapshot.hasError) {
          if (kDebugMode) {
            print('Error loading appointments: ${snapshot.error}');
          }
          return _buildEmptyState('Error loading appointments: ${snapshot.error}');
        }
        if (!snapshot.hasData || !snapshot.data!.exists) {
          if (kDebugMode) {
            print('No appointments found for userId: ${widget.currentUserId}');
          }
          return _buildEmptyState('No appointments found');
        }

        var bookings = List<Map<String, dynamic>>.from(snapshot.data!['Bookings'] ?? []);
        for (var booking in bookings) {
          if (_isDateInPast(booking['date'])) {
            booking['status'] = 'Terminated';
          }
          booking['userId'] = widget.currentUserId;
        }

        if (kDebugMode) {
          print('Fetched ${bookings.length} bookings for userId: ${widget.currentUserId}');
          print('Bookings: $bookings');
        }

        if (bookings.isEmpty) {
          return _buildEmptyState('No appointments found');
        }

        _cacheData('cached_appointments_${widget.currentUserId}', bookings);
        _updateBookingStatusInDB(bookings);
        return _buildAppointmentTabs(bookings);
      },
    );
  }

  Widget _buildAppointmentTabs(List<Map<String, dynamic>> bookings) {
    final pending = bookings.where((b) => b['status'] == 'Pending').toList();
    final active = bookings.where((b) => b['status'] == 'Active').toList();
    final terminated = bookings.where((b) => b['status'] == 'Terminated').toList();

    return DefaultTabController(
      length: 3,
      child: Column(
        children: [
          TabBar(
            indicatorColor: Colors.teal,
            labelColor: Colors.teal,
            unselectedLabelColor: Colors.grey[600],
            tabs: [
              Tab(text: 'Pending (${pending.length})'),
              Tab(text: 'Active (${active.length})'),
              Tab(text: 'Terminated (${terminated.length})'),
            ],
          ),
          Expanded(
            child: TabBarView(
              children: [
                _buildBookingList(pending, false),
                _buildBookingList(active, false),
                _buildBookingList(terminated, false),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildBookingList(List<Map<String, dynamic>> bookings, bool isRequest) {
    if (bookings.isEmpty) {
      return _buildEmptyState(isRequest ? 'No requests' : 'No appointments');
    }

    return ListView.builder(
      key: PageStorageKey<String>('bookings_${isRequest ? "requests" : "appointments"}_list'),
      padding: const EdgeInsets.all(16),
      itemCount: bookings.length,
      itemBuilder: (context, index) => _buildAppointmentCard(bookings[index], isRequest),
    );
  }

  Widget _buildAppointmentCard(Map<String, dynamic> appointment, bool isRequest) {
    return FutureBuilder<DocumentSnapshot>(
      future: FirebaseFirestore.instance
          .collection('Users')
          .doc(isRequest ? appointment['userId'] : appointment['doctorId'])
          .get(),
      builder: (context, AsyncSnapshot<DocumentSnapshot> userSnapshot) {
        if (userSnapshot.connectionState == ConnectionState.waiting) {
          return Card(
            elevation: 2,
            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
            margin: const EdgeInsets.symmetric(vertical: 8),
            child: const Padding(
              padding: EdgeInsets.all(16),
              child: Center(child: CircularProgressIndicator()),
            ),
          );
        }
        if (userSnapshot.hasError || !userSnapshot.hasData || !userSnapshot.data!.exists) {
          if (kDebugMode) {
            print('Error fetching user ${isRequest ? appointment['userId'] : appointment['doctorId']}: ${userSnapshot.error}');
          }
          return const SizedBox.shrink();
        }

        var userInfo = userSnapshot.data!.data() as Map<String, dynamic>;
        String formattedDate = appointment['date'] is Timestamp
            ? DateFormat('MMM dd, yyyy HH:mm').format(appointment['date'].toDate())
            : appointment['date'].toString();

        Color borderColor = appointment['status'] == 'Active'
            ? Colors.teal
            : appointment['status'] == 'Pending'
            ? Colors.orange
            : Colors.red;

        return Card(
          elevation: 4,
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(12),
            side: BorderSide(color: borderColor, width: 2),
          ),
          margin: const EdgeInsets.symmetric(vertical: 8),
          child: Padding(
            padding: const EdgeInsets.all(16),
            child: Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                CircleAvatar(
                  radius: 25,
                  backgroundColor: Colors.teal.withOpacity(0.1),
                  child: userInfo['User Pic']?.isNotEmpty == true
                      ? ClipOval(
                    child: CachedNetworkImage(
                      imageUrl: userInfo['User Pic'],
                      fit: BoxFit.cover,
                      placeholder: (context, url) => const CircularProgressIndicator(),
                      errorWidget: (context, url, error) => Image.asset(
                        'assets/Images/placeholder.png',
                        fit: BoxFit.cover,
                      ),
                      cacheKey: 'user-pic-${isRequest ? appointment['userId'] : appointment['doctorId']}',
                      maxHeightDiskCache: 200,
                      maxWidthDiskCache: 200,
                    ),
                  )
                      : Image.asset('assets/Images/placeholder.png'),
                ),
                const SizedBox(width: 16),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        '${userInfo['Fname'] ?? 'Unknown'} ${userInfo['Lname'] ?? 'Unknown'}',
                        style: const TextStyle(fontSize: 18, fontWeight: FontWeight.bold, color: Colors.grey),
                      ),
                      const SizedBox(height: 4),
                      Text(
                        'Reason: ${appointment['reason'] ?? 'N/A'}',
                        style: TextStyle(fontSize: 14, color: Colors.grey[600], fontStyle: FontStyle.italic),
                      ),
                      const SizedBox(height: 4),
                      Text(
                        'Date: $formattedDate',
                        style: TextStyle(fontSize: 14, color: Colors.grey[700]),
                      ),
                      const SizedBox(height: 4),
                      _buildStatusChip(appointment['status']),
                    ],
                  ),
                ),
                if (isRequest && appointment['status'] != 'Active' && !_isOffline)
                  Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      IconButton(
                        icon: const Icon(Icons.check, color: Colors.green),
                        onPressed: () => _updateStatus(
                          appointment['userId'],
                          appointment['date'],
                          'Active',
                        ),
                      ),
                      IconButton(
                        icon: const Icon(Icons.delete, color: Colors.red),
                        onPressed: () => _confirmDelete(
                          appointment['userId'],
                          appointment['date'],
                        ),
                      ),
                    ],
                  )
                else if (!isRequest && appointment['status'] == 'Pending' && !_isOffline)
                  IconButton(
                    icon: const Icon(Icons.delete, color: Colors.red),
                    onPressed: () => _confirmDelete(
                      widget.currentUserId,
                      appointment['date'],
                    ),
                  ),
              ],
            ),
          ),
        );
      },
    );
  }

  Widget _buildStatusChip(String? status) {
    Color color = switch (status) {
      'Active' => Colors.teal,
      'Pending' => Colors.orange,
      'Terminated' => Colors.red,
      _ => Colors.grey,
    };
    return Chip(
      label: Text(status ?? 'Unknown', style: const TextStyle(color: Colors.white, fontWeight: FontWeight.bold)),
      backgroundColor: color.withOpacity(0.8),
      padding: const EdgeInsets.symmetric(horizontal: 8),
    );
  }

  Widget _buildEmptyState(String message) {
    return Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          const Icon(Icons.event_busy, size: 48, color: Colors.grey),
          const SizedBox(height: 16),
          Text(message, style: const TextStyle(fontSize: 18, color: Colors.grey)),
        ],
      ),
    );
  }

  Widget _buildLoadingState(String type) {
    return Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          _buildSophisticatedProgressIndicator(),
          const SizedBox(height: 16),
          Text(
            'Loading $type${_isOffline ? ' (Offline)' : ''}...',
            style: const TextStyle(fontSize: 16, color: Colors.teal),
          ),
        ],
      ),
    );
  }

  int _sortBookings(Map<String, dynamic> a, Map<String, dynamic> b) {
    if (a['status'] == 'Active' && b['status'] != 'Active') return -1;
    if (a['status'] != 'Active' && b['status'] == 'Active') return 1;
    if (a['status'] == 'Terminated' && b['status'] != 'Terminated') return 1;
    if (a['status'] != 'Terminated' && b['status'] == 'Terminated') return -1;
    return 0;
  }

  bool _isDateInPast(Timestamp timestamp) {
    return timestamp.toDate().isBefore(DateTime.now());
  }

  Future<void> _createBooking({
    required String doctorId,
    required DateTime date,
    required String reason,
    required String hospitalId,
  }) async {
    if (_isOffline) {
      _showModernSnackBar(context, 'Cannot create booking offline', isError: true);
      return;
    }
    try {
      DocumentReference docRef = FirebaseFirestore.instance.collection('Bookings').doc(widget.currentUserId);
      DocumentSnapshot doc = await docRef.get();
      List<dynamic> bookings = doc.exists ? List.from(doc['Bookings'] ?? []) : [];
      bookings.add({
        'doctorId': doctorId,
        'hospitalId': hospitalId,
        'date': Timestamp.fromDate(date),
        'status': 'Pending',
        'reason': reason,
      });
      await docRef.set({'Bookings': bookings});
      _showModernSnackBar(context, 'Booking created successfully');
    } catch (e) {
      _showModernSnackBar(context, 'Failed to create booking: $e', isError: true);
    }
  }

  void _updateStatus(String userId, Timestamp date, String newStatus) async {
    if (_isOffline) {
      _showModernSnackBar(context, 'Cannot update status offline', isError: true);
      return;
    }
    try {
      DocumentSnapshot doc = await FirebaseFirestore.instance.collection('Bookings').doc(userId).get();
      if (!doc.exists) {
        _showModernSnackBar(context, 'Booking document not found', isError: true);
        return;
      }

      List<dynamic> bookings = List.from(doc['Bookings'] ?? []);
      int index = bookings.indexWhere((b) =>
      b['date'] is Timestamp &&
          b['date'].toDate().millisecondsSinceEpoch == date.toDate().millisecondsSinceEpoch);
      if (index == -1) {
        _showModernSnackBar(context, 'Booking not found', isError: true);
        return;
      }

      final updatedBooking = await _showUpdateBookingDialog(context, bookings[index], newStatus);
      if (updatedBooking == null) return;

      bookings[index] = updatedBooking;

      await FirebaseFirestore.instance.collection('Bookings').doc(userId).update({
        'Bookings': bookings,
      });
      _showModernSnackBar(context, 'Status updated to $newStatus');

      // Notify patient if booking is accepted (status changed to Active)
      if (newStatus == 'Active') {
        final prefs = await SharedPreferences.getInstance();
        final sentAcceptedNotifications = prefs.getStringList('sent_accepted_notifications_${widget.currentUserId}') ?? [];
        final notificationId = '${userId}_${bookings[index]['doctorId']}_${bookings[index]['date'].seconds}';

        if (!sentAcceptedNotifications.contains(notificationId)) {
          final formattedDate = DateFormat('MMM dd, yyyy HH:mm').format(bookings[index]['date'].toDate());
          final doctorDoc = await FirebaseFirestore.instance
              .collection('Users')
              .doc(bookings[index]['doctorId'])
              .get();
          final doctorName = doctorDoc.exists
              ? '${doctorDoc['Fname'] ?? 'Unknown'} ${doctorDoc['Lname'] ?? 'Unknown'}'
              : 'Unknown';
          final patientFcmToken = (await FirebaseFirestore.instance.collection('Users').doc(userId).get())['fcmToken'];

          // FCM notification to patient
          await _sendFCMNotification(
            patientFcmToken,
            'Booking Accepted',
            'Your appointment with $doctorName on $formattedDate has been accepted.',
            {
              'type': 'booking_accepted',
              'bookingDate': bookings[index]['date'].seconds.toString(),
              'userId': userId,
              'doctorId': bookings[index]['doctorId'],
            },
          );

          // Local notification if patient is current user
          if (widget.currentUserId == userId) {
            const AndroidNotificationDetails androidDetails = AndroidNotificationDetails(
              'booking_channel',
              'Booking Notifications',
              importance: Importance.max,
              priority: Priority.high,
            );
            const NotificationDetails notificationDetails = NotificationDetails(android: androidDetails);
            await _localNotificationsPlugin.show(
              notificationId.hashCode,
              'Booking Accepted',
              'Your appointment with $doctorName on $formattedDate has been accepted.',
              notificationDetails,
              payload: jsonEncode({
                'type': 'booking_accepted',
                'bookingDate': bookings[index]['date'].seconds.toString(),
                'userId': userId,
                'doctorId': bookings[index]['doctorId'],
              }),
            );
          }

          sentAcceptedNotifications.add(notificationId);
          await prefs.setStringList('sent_accepted_notifications_${widget.currentUserId}', sentAcceptedNotifications);
        }
      }

      final prefs = await SharedPreferences.getInstance();
      await prefs.remove('processed_appointments_${widget.currentUserId}');
    } catch (e) {
      _showModernSnackBar(context, 'Failed to update status: $e', isError: true);
    }
  }

  Future<Map<String, dynamic>?> _showUpdateBookingDialog(
      BuildContext context, Map<String, dynamic> booking, String newStatus) async {
    DateTime selectedDateTime = booking['date'].toDate();
    final reasonController = TextEditingController(text: booking['reason']);

    return await showDialog<Map<String, dynamic>>(
      context: context,
      barrierDismissible: true,
      builder: (context) {
        return StatefulBuilder(
          builder: (context, setState) {
            return Dialog(
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
              child: Padding(
                padding: const EdgeInsets.all(16.0),
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    const Text(
                      'Adjust Booking',
                      style: TextStyle(fontSize: 20, fontWeight: FontWeight.bold, color: Colors.teal),
                    ),
                    const SizedBox(height: 16),
                    Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        Text(
                          '${DateFormat('MMM d, yyyy h:mm a').format(selectedDateTime)}',
                          style: const TextStyle(fontSize: 14, color: Colors.grey),
                        ),
                        TextButton(
                          onPressed: () async {
                            final newDate = await _selectDateTime(context);
                            if (newDate != null) {
                              setState(() => selectedDateTime = newDate);
                            }
                          },
                          child: const Text('Change', style: TextStyle(color: Colors.teal)),
                        ),
                      ],
                    ),
                    const SizedBox(height: 16),
                    TextField(
                      controller: reasonController,
                      maxLines: 3,
                      decoration: InputDecoration(
                        hintText: 'Reason for Booking',
                        hintStyle: TextStyle(color: Colors.grey[400]),
                        border: OutlineInputBorder(
                          borderRadius: BorderRadius.circular(12),
                        ),
                        contentPadding: const EdgeInsets.symmetric(vertical: 12, horizontal: 16),
                      ),
                    ),
                    const SizedBox(height: 20),
                    Row(
                      mainAxisAlignment: MainAxisAlignment.end,
                      children: [
                        TextButton(
                          onPressed: () => Navigator.pop(context, null),
                          child: const Text('Cancel', style: TextStyle(color: Colors.grey)),
                        ),
                        const SizedBox(width: 10),
                        ElevatedButton(
                          onPressed: () {
                            Navigator.pop(context, {
                              'doctorId': booking['doctorId'],
                              'hospitalId': booking['hospitalId'],
                              'date': Timestamp.fromDate(selectedDateTime),
                              'status': newStatus,
                              'reason': reasonController.text.trim().isEmpty
                                  ? booking['reason']
                                  : reasonController.text.trim(),
                            });
                          },
                          style: ElevatedButton.styleFrom(
                            backgroundColor: Colors.teal,
                            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                          ),
                          child: const Text('Confirm', style: TextStyle(color: Colors.white)),
                        ),
                      ],
                    ),
                  ],
                ),
              ),
            );
          },
        );
      },
    );
  }

  Future<DateTime?> _selectDateTime(BuildContext context) async {
    final pickedDate = await showDatePicker(
      context: context,
      initialDate: DateTime.now(),
      firstDate: DateTime.now(),
      lastDate: DateTime(2101),
      builder: (context, child) => Theme(
        data: ThemeData.light().copyWith(
          colorScheme: const ColorScheme.light(primary: Colors.teal),
        ),
        child: child!,
      ),
    );

    if (pickedDate == null) return null;

    final pickedTime = await showTimePicker(
      context: context,
      initialTime: TimeOfDay.now(),
      builder: (context, child) => Theme(
        data: ThemeData.light().copyWith(
          colorScheme: const ColorScheme.light(primary: Colors.teal),
        ),
        child: child!,
      ),
    );

    if (pickedTime == null) return null;

    return DateTime(
      pickedDate.year,
      pickedDate.month,
      pickedDate.day,
      pickedTime.hour,
      pickedTime.minute,
    );
  }

  void _confirmDelete(String userId, Timestamp date) {
    if (_isOffline) {
      _showModernSnackBar(context, 'Cannot delete booking offline', isError: true);
      return;
    }
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
        title: const Row(
          children: [
            Icon(Icons.warning, color: Colors.red),
            SizedBox(width: 8),
            Text('Confirm Delete'),
          ],
        ),
        content: const Text('Are you sure you want to delete this booking?'),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('Cancel', style: TextStyle(color: Colors.teal)),
          ),
          TextButton(
            onPressed: () {
              _deleteBooking(userId, date);
              Navigator.pop(context);
            },
            child: const Text('Delete', style: TextStyle(color: Colors.red)),
          ),
        ],
      ),
    );
  }

  void _deleteBooking(String userId, Timestamp date) async {
    try {
      DocumentReference docRef = FirebaseFirestore.instance.collection('Bookings').doc(userId);
      DocumentSnapshot doc = await docRef.get();
      if (!doc.exists) {
        _showModernSnackBar(context, 'Booking document not found', isError: true);
        return;
      }

      List<dynamic> bookings = List.from(doc['Bookings']);
      bookings.removeWhere((booking) =>
      booking['date'] is Timestamp &&
          booking['date'].toDate().millisecondsSinceEpoch == date.toDate().millisecondsSinceEpoch);
      await docRef.update({'Bookings': bookings});
      _showModernSnackBar(context, 'Booking deleted successfully');

      final prefs = await SharedPreferences.getInstance();
      await prefs.remove('processed_appointments_${widget.currentUserId}');
    } catch (e) {
      _showModernSnackBar(context, 'Failed to delete booking: $e', isError: true);
    }
  }

  void _updateBookingStatusInDB(List<Map<String, dynamic>> bookings) async {
    if (_isOffline) return;
    try {
      await FirebaseFirestore.instance.collection('Bookings').doc(widget.currentUserId).update({
        'Bookings': bookings,
      });
    } catch (e) {
      print('Error updating booking status: $e');
    }
  }

  void _showModernSnackBar(BuildContext context, String message, {bool isError = false}) {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Row(
          children: [
            Icon(
              isError ? Icons.error_outline : Icons.check_circle_outline,
              color: Colors.white,
            ),
            const SizedBox(width: 10),
            Expanded(child: Text(message, style: const TextStyle(color: Colors.white))),
          ],
        ),
        backgroundColor: isError ? Colors.redAccent : Colors.teal,
        behavior: SnackBarBehavior.floating,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
        margin: const EdgeInsets.all(10),
        duration: const Duration(seconds: 3),
      ),
    );
  }
}