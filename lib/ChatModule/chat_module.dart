import 'dart:async';
import 'dart:io';
import 'dart:math';
import 'dart:convert';


import 'package:audioplayers/audioplayers.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:firebase_storage/firebase_storage.dart';
import 'package:flutter/material.dart';
import 'package:flutter_dotenv/flutter_dotenv.dart';
import 'package:flutter_sound/flutter_sound.dart';
import 'package:flutter_speed_dial/flutter_speed_dial.dart';
import 'package:flutter_webrtc/flutter_webrtc.dart';
import 'package:intl/intl.dart';
import 'package:path_provider/path_provider.dart';
import 'package:permission_handler/permission_handler.dart';
import 'package:uuid/uuid.dart';
import 'package:http/http.dart' as http;
import 'package:logger/logger.dart';
import 'package:fluttertoast/fluttertoast.dart';
import 'package:flutter/services.dart';

// Import other pages
import 'experts_community_page.dart';
import 'HealthInsightsPage.dart';

// ====================== Translation Service ======================
class TranslationService {
  static String API_KEY = dotenv.env['NLP_API_KEY'] ?? '';
  static String API_URL = dotenv.env['NLP_API_URL'] ?? '';

  static final Map<String, String> ghanaianLanguages = {
    'en': 'English',
    'tw': 'Twi',
    'ee': 'Ewe',
    'gaa': 'Ga',
    'fat': 'Fante',
    'yo': 'Yoruba',
    'dag': 'Dagbani',
    'ki': 'Kikuyu',
    'gur': 'Gurune',
    'luo': 'Luo',
    'mer': 'Kimeru',
    'kus': 'Kusaal',
  };

  static Future<String> translateText({
    required String text,
    required String targetLanguage,
    String sourceLanguage = 'en',
  }) async {
    try {
      print('Starting translation for text: $text to language: $targetLanguage');

      final url = Uri.parse('$API_URL?subscription-key=$API_KEY');

      final response = await http.post(
        url,
        headers: {
          'Content-Type': 'application/json; charset=utf-8',
          'Accept': 'application/json; charset=utf-8',
        },
        body: utf8.encode(jsonEncode({
          'text': text,
          'target_language': targetLanguage,
          'source_language': sourceLanguage,
        })),
      );

      print('Translation Response Status: ${response.statusCode}');
      final decodedBody = utf8.decode(response.bodyBytes);
      print('Translation Response Body: $decodedBody');

      if (response.statusCode == 200) {
        final data = jsonDecode(decodedBody);

        if (data is Map<String, dynamic>) {
          String? translatedText;

          if (data['type'] == 'Success' && data['message'] != null) {
            translatedText = data['message'].toString();
          } else if (data['translatedText'] != null) {
            translatedText = data['translatedText'].toString();
          }

          if (translatedText != null) {
            final decodedText = _decodeSpecialCharacters(translatedText);
            print('Successfully translated to: $decodedText');
            return decodedText;
          }

          throw Exception('Unexpected response format: $decodedBody');
        } else {
          throw Exception('Invalid response format: $decodedBody');
        }
      } else {
        final error = jsonDecode(decodedBody);
        throw Exception('Translation failed: ${error['message'] ?? 'Unknown error'}');
      }
    } catch (e) {
      print('Translation Error: $e');
      rethrow;
    }
  }

  static String _decodeSpecialCharacters(String text) {
    return text
        .replaceAll('&amp;', '&')
        .replaceAll('&lt;', '<')
        .replaceAll('&gt;', '>')
        .replaceAll('&quot;', '"')
        .replaceAll('&#039;', "'")
        .replaceAll('\\u', '\\\\u');
  }
}


class ChatHomePage extends StatefulWidget {
  const ChatHomePage({super.key});

  @override
  _ChatHomePageState createState() => _ChatHomePageState();
}


class _ChatHomePageState extends State<ChatHomePage>
    with SingleTickerProviderStateMixin, AutomaticKeepAliveClientMixin {
  late TabController _tabController;
  final List<Widget> _pages = [ChatPage(), ForumPage()];
  bool? isExpert; // Store user's expert status

  @override
  void initState() {
    super.initState();
    _tabController = TabController(length: 2, vsync: this);
    //CallService().initialize();
    _fetchUserRole(); // Fetch user role when initializing
    _tabController.addListener(() {
      if (mounted) {
        setState(() {}); // ✅ Ensures FAB updates correctly when switching tabs
      }
    });
  }

  Future<void> _fetchUserRole() async {
    final user = FirebaseAuth.instance.currentUser;
    if (user != null) {
      final userDoc = await FirebaseFirestore.instance
          .collection('Users')
          .doc(user.uid)
          .get();
      if (userDoc.exists) {
        setState(() {
          isExpert = userDoc['Role'] ?? false;
        });
      }
    }
  }

  @override
  bool get wantKeepAlive => true;

  @override
  Widget build(BuildContext context) {
    super.build(context); // Call super.build to ensure the mixin works correctly
    return Scaffold(
      appBar: AppBar(
        title: Text(
          _tabController.index == 0 ? 'Private Chats' : 'Open Forum',
          style: TextStyle(color: Colors.white),
        ),
        backgroundColor: Colors.tealAccent,
      ),
      body: IndexedStack(
        index: _tabController.index,
        children: _pages,
      ),
      bottomNavigationBar: Container(
        decoration: BoxDecoration(
          gradient: LinearGradient(
            colors: [Colors.teal.shade700, Colors.tealAccent.shade400],
            begin: Alignment.topLeft,
            end: Alignment.bottomRight,
          ),
          borderRadius: const BorderRadius.only(
            topLeft: Radius.circular(16),
            topRight: Radius.circular(16),
          ),
          boxShadow: [
            BoxShadow(
              color: Colors.black.withOpacity(0.2),
              blurRadius: 10,
              offset: const Offset(0, -5),
            ),
          ],
        ),
        child: TabBar(
          controller: _tabController,
          tabs: const [
            Tab(
              icon: Icon(Icons.message, size: 28),
              text: 'Private Chats',
            ),
            Tab(
              icon: Icon(Icons.forum, size: 28),
              text: 'Open Forum',
            ),
          ],
          labelColor: Colors.white,
          unselectedLabelColor: Colors.grey[300],
          indicator: const UnderlineTabIndicator(
            borderSide: BorderSide(
              color: Colors.white,
              width: 3,
            ),
            insets: EdgeInsets.symmetric(horizontal: 40),
          ),
          indicatorSize: TabBarIndicatorSize.tab,
          labelStyle: const TextStyle(
            fontSize: 14,
            fontWeight: FontWeight.bold,
          ),
          unselectedLabelStyle: const TextStyle(
            fontSize: 13,
            fontWeight: FontWeight.normal,
          ),
        ),
      ),
      floatingActionButton: _tabController.index == 0
          ? SpeedDial(
        icon: Icons.add,
        activeIcon: Icons.close,
        backgroundColor: Colors.teal,
        foregroundColor: Colors.white,
        children: [
          SpeedDialChild(
            child: const Icon(Icons.person_add),
            backgroundColor: Colors.teal,
            label: 'Add User',
            onTap: () async {
              String? currentUserId = FirebaseAuth.instance.currentUser?.uid;
              if (currentUserId != null) {
                _showUserList(context, currentUserId);
              }
            },
          ),
          // Only show Health Insights if user is an expert
          if (isExpert == true)
            SpeedDialChild(
              child: const Icon(Icons.analytics),
              backgroundColor: Colors.teal.shade600,
              label: 'Health Insights',
              onTap: () {
                Navigator.push(
                  context,
                  MaterialPageRoute(
                    builder: (context) => const HealthInsightsPage(),
                  ),
                );
              },
            ),
        ],
      )
          : isExpert == true // Only show FAB in forum tab if expert
          ? FloatingActionButton(
        onPressed: () {
          Navigator.push(
            context,
            MaterialPageRoute(
              builder: (context) => const HealthInsightsPage(),
              fullscreenDialog: true,
            ),
          );
        },
        backgroundColor: Colors.teal,
        child: const Icon(Icons.analytics, color: Colors.white),
      )
          : null, // Hide FAB if not expert // Hide FAB completely if not expert
    );
  }
}

class KeepAlive extends StatefulWidget {
  final Widget child;

  const KeepAlive({Key? key, required this.child}) : super(key: key);

  @override
  _KeepAliveState createState() => _KeepAliveState();
}

class _KeepAliveState extends State<KeepAlive>
    with AutomaticKeepAliveClientMixin {
  @override
  bool get wantKeepAlive => true;

  @override
  Widget build(BuildContext context) {
    super.build(context);
    return widget.child;
  }
}

class CustomFABLocation extends FloatingActionButtonLocation {
  @override
  Offset getOffset(ScaffoldPrelayoutGeometry scaffoldGeometry) {
    // If there's no FAB, return an offset that's off-screen
    if (scaffoldGeometry.floatingActionButtonSize == null) {
      return Offset.zero;
    }

    final defaultOffset = FloatingActionButtonLocation.endFloat
        .getOffset(scaffoldGeometry);
    return Offset(defaultOffset.dx, defaultOffset.dy - 25);
  }
}


void _showUserList(BuildContext context, String currentUserId) {
  showModalBottomSheet(
    context: context,
    builder: (context) {
      return FutureBuilder<QuerySnapshot>(
        future: FirebaseFirestore.instance
            .collection('Users')
            .where(FieldPath.documentId, isNotEqualTo: currentUserId) // Exclude current user
            .get(),
        builder: (context, snapshot) {
          if (snapshot.connectionState == ConnectionState.waiting) {
            return const Center(child: CircularProgressIndicator());
          }
          if (!snapshot.hasData || snapshot.data!.docs.isEmpty) {
            return const Center(child: Text("No users found"));
          }

          final users = snapshot.data!.docs;

          return Column(
            children: [
              Padding(
                padding: const EdgeInsets.all(16.0),
                child: Text(
                  "Select a user to start chatting",
                  style: TextStyle(
                    fontSize: 18,
                    fontWeight: FontWeight.bold,
                    color: Colors.grey[800],
                  ),
                ),
              ),
              Expanded(
                child: ListView.separated(
                  itemCount: users.length,
                  separatorBuilder: (context, index) => const Divider(
                    color: Colors.grey, // Thin grey divider
                    thickness: 0.5,
                    height: 1,
                  ),
                  itemBuilder: (context, index) {
                    final user = users[index].data() as Map<String, dynamic>;
                    final userId = users[index].id;
                    final userFname = user['Fname'] ?? 'Unknown';
                    final userLname = user['Lname'] ?? '';
                    final fullName = "$userFname $userLname";
                    //final userPhone = user['Mobile Number'] ?? 'No Phone';
                    final userPic = user['User Pic'] ?? '';
                    final isOnline = user['Status'] ?? false;

                    return ListTile(
                      leading: CircleAvatar(
                        backgroundImage: userPic.isNotEmpty ? NetworkImage(userPic) : null,
                        child: userPic.isEmpty ? Text(userFname[0]) : null,
                      ),
                      title: Text(fullName),
                      //subtitle: Text(userPhone),
                      trailing: isOnline
                          ? const Icon(Icons.circle, color: Colors.green, size: 12)
                          : null,
                      onTap: () async {
                        Navigator.pop(context); // Close modal

                        // Get the current user details
                        String? fromUid = FirebaseAuth.instance.currentUser?.uid;
                        if (fromUid == null) {
                          print("Error: fromUid is null");
                          return;
                        }

                        DocumentSnapshot fromUserSnapshot = await FirebaseFirestore.instance.collection('Users').doc(fromUid).get();
                        String fromName = '${fromUserSnapshot['Fname'] ?? 'Unknown'} ${fromUserSnapshot['Lname'] ?? ''}'.trim();
                        String fromPic = fromUserSnapshot['User Pic'] ?? '';

                        // Get the tapped user's details
                        String toUid = userId;
                        String toName = fullName;
                        String toPic = userPic ?? '';

                        String chatId = await _getOrCreateChatThread(fromUid, fromName, fromPic, toUid, toName, toPic);

                        if (chatId.isEmpty) {
                          print("Error: chatId is empty!");
                          return;
                        }

                        print("chatId retrieved: $chatId");

                        if (!context.mounted) return; // Ensure the context is still active

                        // Debug logs
                        print("Navigating to ChatThreadDetailsPage with:");
                        print("chatId: $chatId");
                        print("toName: $toName");
                        print("toUid: $toUid");
                        print("fromUid: $fromUid");


                        // Navigate to ChatThreadDetailsPage
                        Navigator.push(
                          context,
                          MaterialPageRoute(
                            builder: (context) => ChatThreadDetailsPage(
                              chatId: chatId,
                              toName: toName,
                              toUid: toUid,
                              fromUid: fromUid,
                            ),
                          ),
                        );
                      },
                    );
                  },
                ),
              ),
            ],
          );
        },
      );
    },
  );
}


Future<String> _getOrCreateChatThread(
    String fromUid, String fromName, String fromPic,
    String toUid, String toName, String toPic) async {
  final chatRef = FirebaseFirestore.instance.collection('ChatMessages');

  // Step 1: Check if a chat already exists
  QuerySnapshot existingChat = await chatRef
      .where('participants', arrayContainsAny: [fromUid, toUid])
      .get();

  for (var doc in existingChat.docs) {
    List<dynamic> participants = doc['participants'];
    if (participants.contains(fromUid) && participants.contains(toUid)) {
      print("Existing chat found: ${doc['chat_id']}");
      return doc['chat_id']; // Return the chat_id field
    }
  }

  // Step 2: If no chat exists, create a new one
  DocumentReference newChat = await chatRef.add({
    'participants': [fromUid, toUid],
    'last_message': '',
    'last_time': FieldValue.serverTimestamp(),

    // Storing both users' details
    'from_uid': fromUid,
    'from_name': fromName,
    'from_pic': fromPic,

    'to_uid': toUid,
    'to_name': toName,
    'to_pic': toPic,

    'chat_id': '', // Placeholder
  });

  // Step 3: Update the chat_id field
  await newChat.update({'chat_id': newChat.id});

  print("New chat created with ID: ${newChat.id}");


  return newChat.id; // Return the chat thread ID
}


String truncateMessage(String message, {int maxLength = 50}) {
  if (message.length <= maxLength) {
    return message;
  }
  return '${message.substring(0, maxLength)}...';
}


class ChatPage extends StatefulWidget {
  const ChatPage({super.key});

  @override
  _ChatPageState createState() => _ChatPageState();
}

class _ChatPageState extends State<ChatPage> with AutomaticKeepAliveClientMixin {
  final FirebaseFirestore _firestore = FirebaseFirestore.instance;
  final Map<String, Map<String, dynamic>> _userCache = {};
  bool _isLoadingUsers = true;

  @override
  bool get wantKeepAlive => true;

  @override
  void initState() {
    super.initState();
    _preloadUserData();
  }

  // Preload all user data at once
  Future<void> _preloadUserData() async {
    final currentUserId = FirebaseAuth.instance.currentUser?.uid;
    if (currentUserId == null) return;

    final chatSnapshot = await _firestore
        .collection('ChatMessages')
        .where('participants', arrayContains: currentUserId)
        .get();

    // Get all unique participant IDs
    final participantIds = <String>{};
    for (final chat in chatSnapshot.docs) {
      final participants = chat['participants'] as List<dynamic>;
      participantIds.addAll(participants.where((id) => id != currentUserId).cast<String>());
    }

    // Load all user data in batch
    if (participantIds.isNotEmpty) {
      final usersSnapshot = await _firestore
          .collection('Users')
          .where(FieldPath.documentId, whereIn: participantIds.toList())
          .get();

      for (final userDoc in usersSnapshot.docs) {
        _userCache[userDoc.id] = userDoc.data() as Map<String, dynamic>;
      }
    }

    setState(() {
      _isLoadingUsers = false;
    });
  }

  // Helper function to format timestamp
  String formatTimestamp(Timestamp? timestamp) {
    if (timestamp == null) return '';
    final messageDate = timestamp.toDate();
    final now = DateTime.now();
    final difference = now.difference(messageDate).inDays;

    if (difference == 0) {
      return DateFormat.jm().format(messageDate);
    } else if (difference == 1) {
      return "Yesterday";
    } else {
      return DateFormat.yMMMd().format(messageDate);
    }
  }

  // Get or create chat thread
  Future<String> _getOrCreateChatThread(
      String fromUid, String fromName, String fromPic,
      String toUid, String toName, String toPic) async {
    final chatRef = FirebaseFirestore.instance.collection('ChatMessages');

    // Step 1: Check if a chat already exists
    QuerySnapshot existingChat = await chatRef
        .where('participants', arrayContainsAny: [fromUid, toUid])
        .get();

    for (var doc in existingChat.docs) {
      List<dynamic> participants = doc['participants'];
      if (participants.contains(fromUid) && participants.contains(toUid)) {
        print("Existing chat found: ${doc['chat_id']}");
        return doc['chat_id']; // Return the chat_id field
      }
    }

    // Step 2: If no chat exists, create a new one
    DocumentReference newChat = await chatRef.add({
      'participants': [fromUid, toUid],
      'last_msg': '',
      'last_time': FieldValue.serverTimestamp(),

      // Storing both users' details
      'from_uid': fromUid,
      'from_name': fromName,
      'from_pic': fromPic,

      'to_uid': toUid,
      'to_name': toName,
      'to_pic': toPic,

      'chat_id': '', // Placeholder
    });

    // Step 3: Update the chat_id field
    await newChat.update({'chat_id': newChat.id});

    print("New chat created with ID: ${newChat.id}");
    return newChat.id; // Return the chat thread ID
  }


  // Mark messages as read when the chat thread is opened
  Future<void> _markMessagesAsRead(String chatId, String currentUserId) async {
    final messagesSnapshot = await _firestore
        .collection('ChatMessages')
        .doc(chatId)
        .collection('messages')
        .where('to_uid', isEqualTo: currentUserId)
        .where('read', isEqualTo: false)
        .get();

    final batch = _firestore.batch();
    for (var doc in messagesSnapshot.docs) {
      batch.update(doc.reference, {'read': true});
    }
    await batch.commit();
  }

  @override
  Widget build(BuildContext context) {
    super.build(context); // Required when using AutomaticKeepAliveClientMixin
    final String? currentUserId = FirebaseAuth.instance.currentUser?.uid;

    if (currentUserId == null) {
      return const Center(child: Text("User not logged in"));
    }

    return StreamBuilder<QuerySnapshot>(
      stream: _firestore
          .collection('ChatMessages')
          .where('participants', arrayContains: currentUserId)
          .orderBy('last_time', descending: true)
          .snapshots(),
      builder: (context, snapshot) {
        if (snapshot.hasError) {
          return Center(child: Text('Error: ${snapshot.error}'));
        }

        if (!snapshot.hasData || _isLoadingUsers) {
          return _buildSkeletonLoading();
        }

        final chats = snapshot.data!.docs;

        if (chats.isEmpty) {
          return const Center(
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                Text(
                  "No chats yet.",
                  style: TextStyle(fontSize: 16, color: Colors.grey),
                ),
                SizedBox(height: 8),
                Text(
                  "Tap on the blue action button below to start a healthy chat...",
                  style: TextStyle(fontSize: 14, color: Colors.grey),
                  textAlign: TextAlign.center,
                ),
              ],
            ),
          );
        }

        // If there are chats, display the list
        return ListView.separated(
          itemCount: chats.length,
          separatorBuilder: (context, index) => const Divider(
            thickness: 1.0,
            height: 1.0,
            color: Colors.grey,
          ),
          itemBuilder: (context, index) {
            final chat = chats[index].data() as Map<String, dynamic>;
            final chatId = chat['chat_id'];
            final lastMessage = chat['last_msg'] ?? '';
            final lastMessageType = chat['type'] ?? '';
            final isCurrentUserSender = chat['from_uid'] == currentUserId;
            final otherParticipantId = isCurrentUserSender ? chat['to_uid'] : chat['from_uid'];
            final userData = _userCache[otherParticipantId];

            // Skeleton loading if user data isn't loaded yet (shouldn't happen after preload)
            if (userData == null) {
              return _buildChatListItemSkeleton();
            }

            final userPic = userData['User Pic'];
            final firstName = userData['Fname'] ?? 'Unknown';
            final lastName = userData['Lname'] ?? '';
            final fullName = '$firstName $lastName'.trim();

            return StreamBuilder<QuerySnapshot>(
              stream: _firestore
                  .collection('ChatMessages')
                  .doc(chatId)
                  .collection('messages')
                  .where('to_uid', isEqualTo: currentUserId)
                  .where('read', isEqualTo: false)
                  .snapshots(),
              builder: (context, unreadSnapshot) {
                final unreadCount = unreadSnapshot.hasData ? unreadSnapshot.data!.docs.length : 0;

                return ListTile(
                  leading: CircleAvatar(
                    backgroundImage: userPic != null ? NetworkImage(userPic) : null,
                    child: userPic == null ? Text(firstName[0].toUpperCase()) : null,
                  ),
                  title: Text(fullName, style: const TextStyle(fontWeight: FontWeight.bold)),
                  subtitle: Row(
                    children: [
                      Expanded(
                        child: Text(
                          lastMessageType == 'audio'
                              ? '🎤 Voice message (${_formatDuration(Duration(seconds: chat['audio_duration'] ?? 0))})'
                              : truncateMessage(lastMessage),
                          overflow: TextOverflow.ellipsis,
                          maxLines: 1,
                          softWrap: false,
                        ),
                      ),
                    ],
                  ),
                  trailing: unreadCount > 0
                      ? AnimatedContainer(
                    duration: const Duration(milliseconds: 300),
                    padding: const EdgeInsets.all(8),
                    decoration: BoxDecoration(
                      color: Colors.green,
                      shape: BoxShape.circle,
                      boxShadow: [
                        BoxShadow(
                          color: Colors.black54.withOpacity(0.3),
                          blurRadius: 6,
                          spreadRadius: 2,
                          offset: const Offset(0, 2),
                        ),
                      ],
                    ),
                    child: Text(
                      unreadCount.toString(),
                      style: const TextStyle(color: Colors.white, fontSize: 12),
                    ),
                  )
                      : Text(
                    formatTimestamp(chat['last_time']),
                    style: const TextStyle(fontSize: 12, color: Colors.blueGrey),
                  ),
                  onTap: () async {
                    await _markMessagesAsRead(chatId, currentUserId);
                    Navigator.push(
                      context,
                      MaterialPageRoute(
                        builder: (context) => ChatThreadDetailsPage(
                          chatId: chatId,
                          toName: fullName,
                          toUid: otherParticipantId,
                          fromUid: currentUserId,
                        ),
                      ),
                    );
                  },
                );
              },
            );
          },
        );

      },
    );
  }

  String _formatDuration(Duration duration) {
    String twoDigits(int n) => n.toString().padLeft(2, '0');
    final minutes = twoDigits(duration.inMinutes.remainder(60));
    final seconds = twoDigits(duration.inSeconds.remainder(60));

    // For durations under 1 minute, just show seconds
    if (duration.inMinutes == 0) {
      return '$seconds sec';
    }
    return '$minutes:$seconds';
  }

  Widget _buildSkeletonLoading() {
    return ListView.builder(
      itemCount: 5,
      itemBuilder: (context, index) {
        return Padding(
          padding: const EdgeInsets.symmetric(vertical: 8.0),
          child: ListTile(
            leading: const CircleAvatar(backgroundColor: Colors.grey),
            title: Container(
              height: 16,
              width: 100,
              color: Colors.grey[300],
            ),
            subtitle: Container(
              height: 14,
              width: double.infinity,
              color: Colors.grey[200],
            ),
          ),
        );
      },
    );
  }

  Widget _buildChatListItemSkeleton() {
    return const ListTile(
      leading: CircleAvatar(backgroundColor: Colors.grey),
      title: Text("Loading...", style: TextStyle(fontWeight: FontWeight.bold)),
      subtitle: Text("Fetching user details..."),
    );
  }

}


class ForumPage extends StatefulWidget {
  const ForumPage({super.key});

  @override
  _ForumPageState createState() => _ForumPageState();
}

class _ForumPageState extends State<ForumPage> with AutomaticKeepAliveClientMixin, TickerProviderStateMixin {
  final GlobalKey<ScaffoldState> _scaffoldKey = GlobalKey<ScaffoldState>();
  final FirebaseFirestore _firestore = FirebaseFirestore.instance;
  bool? isExpert; // Store user's role

  late ScrollController _disclaimerScrollController;
  late AnimationController _animationController;
  late Animation<double> _animation;

  @override
  bool get wantKeepAlive => true; // Add this to keep the state alive

  @override
  void initState() {
    super.initState();
    _fetchUserRole();
    _disclaimerScrollController = ScrollController();
    _animationController = AnimationController(
      duration: const Duration(seconds: 45), // Adjust duration for speed
      vsync: this,
    )..repeat();

    _animation = Tween<double>(begin: 0, end: 1).animate(_animationController)
      ..addListener(() {
        if (_disclaimerScrollController.hasClients) {
          final maxScroll = _disclaimerScrollController.position.maxScrollExtent;
          final currentScroll = maxScroll * _animation.value;
          _disclaimerScrollController.jumpTo(currentScroll);
        }
      });

    _startAutoScroll();
  }

  void _startAutoScroll() {
    Future.delayed(const Duration(seconds: 1), () {
      if (_disclaimerScrollController.hasClients) {
        _disclaimerScrollController.animateTo(
          _disclaimerScrollController.position.maxScrollExtent,
          duration: const Duration(seconds: 20),
          curve: Curves.linear,
        ).then((_) => _startAutoScroll()); // Loop the animation
      }
    });
  }

  @override
  void dispose() {
    _animationController.dispose();
    _disclaimerScrollController.dispose();
    super.dispose();
  }

  Widget _buildScrollingDisclaimer() {
    const disclaimerText = " Disclaimer: This is a public forum. For professional medical advice, please consult a qualified health expert or visit a recognized healthcare facility.";

    return Container(
      height: 30,
      decoration: BoxDecoration(
        color: Colors.teal.withOpacity(0.1),
        border: Border(
          top: BorderSide(color: Colors.grey.shade300),
          bottom: BorderSide(color: Colors.grey.shade300),
        ),
      ),
      child: SingleChildScrollView(
        controller: _disclaimerScrollController,
        scrollDirection: Axis.horizontal,
        physics: const NeverScrollableScrollPhysics(), // Disable user scrolling
        child: Row(
          children: [
            const Padding(
              padding: EdgeInsets.symmetric(horizontal: 8),
              child: Icon(Icons.info_outline, size: 16, color: Colors.red),
            ),
            Text(
              disclaimerText * 5, // Repeat text more times for smoother looping
              style: const TextStyle(
                fontSize: 12,
                color: Colors.red,
                fontWeight: FontWeight.w600,
              ),
            ),
          ],
        ),
      ),
    );
  }

  Future<void> _fetchUserRole() async {
    final user = FirebaseAuth.instance.currentUser;
    if (user != null) {
      final userDoc = await _firestore.collection('Users').doc(user.uid).get();
      if (userDoc.exists) {
        setState(() {
          isExpert = userDoc['Role'] ?? false;
        });
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    super.build(context); // Required when using AutomaticKeepAliveClientMixin
    return Scaffold(
      key: _scaffoldKey,
      appBar: AppBar(
        title: const SizedBox.shrink(),
        bottom: PreferredSize(
          preferredSize: const Size.fromHeight(30), // Height for disclaimer
          child: _buildScrollingDisclaimer(),
        ),
        actions: [
          Expanded(
            child: Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Padding(
                  padding: const EdgeInsets.only(left: 8.0),
                  child: ElevatedButton.icon(
                    onPressed: () => _showAddPostDialog(context),
                    icon: const Icon(Icons.add, color: Colors.white),
                    label: const Text("Add Post"),
                    style: ElevatedButton.styleFrom(
                      backgroundColor: Colors.teal,
                      foregroundColor: Colors.white,
                    ),
                  ),
                ),
                if (isExpert == true)
                  Padding(
                    padding: const EdgeInsets.only(right: 8.0),
                    child: ElevatedButton(
                      onPressed: () {
                        Navigator.push(
                          context,
                          MaterialPageRoute(
                            builder: (context) => const ExpertsCommunityPage(),
                          ),
                        );
                      },
                      style: ElevatedButton.styleFrom(
                        backgroundColor: Colors.teal,
                        foregroundColor: Colors.white,
                      ),
                      child: const Text('Experts Community'),
                    ),
                  ),
              ],
            ),
          ),
        ],
      ),
      body: Container(
        decoration: const BoxDecoration(
          gradient: LinearGradient(
            begin: Alignment.topLeft,
            end: Alignment.bottomRight,
            colors: [Colors.grey, Colors.grey],
          ),
        ),
        child: StreamBuilder<QuerySnapshot>(
          stream: _firestore.collection('ForumPosts').orderBy('timestamp', descending: true).snapshots(),
          builder: (context, snapshot) {
            if (snapshot.hasError) {
              return Center(child: Text('Error: ${snapshot.error}'));
            }
            if (!snapshot.hasData) {
              return const Center(child: CircularProgressIndicator());
            }

            final posts = snapshot.data!.docs;

            return ListView.builder(
              itemCount: posts.length,
              itemBuilder: (context, index) {
                final post = posts[index].data() as Map<String, dynamic>;
                final postId = posts[index].id;
                final username = post['username'] ?? 'Anonymous';
                final timestamp = post['timestamp'] as Timestamp?;

                return GestureDetector(
                  onLongPress: () => _showPostMenu(context, postId),
                  child: Card(
                    margin: const EdgeInsets.all(8.0),
                    child: ListTile(
                      title: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            post['content'] ?? 'No Content',
                            style: const TextStyle(
                              fontSize: 16,
                              fontWeight: FontWeight.bold,
                            ),
                          ),
                          const SizedBox(height: 4),
                          Text(
                            'Posted by: $username',
                            style: TextStyle(
                              fontSize: 12,
                              color: Colors.teal[800],
                            ),
                          ),
                        ],
                      ),
                      trailing: Text(
                        timestamp != null
                            ? DateFormat.yMMMd().add_jm().format(timestamp.toDate())
                            : 'No Date',
                        style: TextStyle(
                          fontSize: 12,
                          color: Colors.teal[600],
                        ),
                      ),
                      onTap: () {
                        Navigator.push(
                          context,
                          MaterialPageRoute(
                            builder: (context) => PostDetailsPage(postId: postId, postTitle: post['content']),
                          ),
                        );
                      },
                    ),
                  ),
                );
              },
            );
          },
        ),
      ),
    );
  }


  void _showPostMenu(BuildContext context, String postId) {
    final FirebaseFirestore firestore = FirebaseFirestore.instance;
    final currentUserId = FirebaseAuth.instance.currentUser?.uid;

    showModalBottomSheet(
      context: context,
      builder: (context) {
        return FutureBuilder<DocumentSnapshot>(
          future: firestore.collection('ForumPosts').doc(postId).get(),
          builder: (context, snapshot) {
            if (snapshot.connectionState == ConnectionState.waiting) {
              return const Center(child: CircularProgressIndicator());
            }

            if (!snapshot.hasData || !snapshot.data!.exists) {
              return const Center(child: Text("Post not found"));
            }

            final post = snapshot.data!.data() as Map<String, dynamic>;
            final postUserId = post['userId'];

            // Only show delete option if current user is the post owner
            final canDelete = currentUserId == postUserId;

            return Wrap(
              children: [
                if (canDelete) // Only show delete option if user owns the post
                  ListTile(
                    leading: const Icon(Icons.delete),
                    title: const Text('Delete Post'),
                    onTap: () async {
                      Navigator.pop(context);
                      final bool shouldDelete = await showDialog(
                        context: context,
                        builder: (BuildContext context) {
                          return AlertDialog(
                            title: const Text('Delete Post'),
                            content: const Text('Are you sure you want to delete this post?'),
                            actions: [
                              TextButton(
                                child: const Text('No'),
                                onPressed: () => Navigator.pop(context, false),
                              ),
                              TextButton(
                                style: TextButton.styleFrom(
                                  foregroundColor: Colors.red,
                                ),
                                onPressed: () => Navigator.pop(context, true),
                                child: const Text('Yes'),
                              ),
                            ],
                          );
                        },
                      ) ?? false;
                      if (shouldDelete) {
                        await firestore.collection('ForumPosts').doc(postId).delete();
                      }
                    },
                  ),
                ListTile(
                  leading: const Icon(Icons.copy),
                  title: const Text('Copy Post'),
                  onTap: () {
                    firestore.collection('ForumPosts').doc(postId).get().then((value) {
                      if (value.exists) {
                        Clipboard.setData(ClipboardData(text: value['content']));
                        Fluttertoast.showToast(
                          msg: 'Post copied to clipboard!',
                          toastLength: Toast.LENGTH_SHORT,
                          gravity: ToastGravity.BOTTOM,
                        );
                      }
                    });
                    Navigator.pop(context);
                  },
                ),
                ListTile(
                  leading: const Icon(Icons.translate),
                  title: const Text('Translate Post'),
                  onTap: () {
                    Navigator.pop(context);
                    _showPostTranslationLanguageSelector(context, postId);
                  },
                ),
                ListTile(
                  leading: const Icon(Icons.report, color: Colors.red),
                  title: const Text('Report Post', style: TextStyle(color: Colors.red)),
                  onTap: () {
                    Navigator.pop(context);
                    _showReportDialog(context, postId, postUserId, post['content']);
                  },
                ),
              ],
            );
          },
        );
      },
    );
  }

  void _showReportDialog(BuildContext context, String postId, String reportedUserId, String postContent) {
    final currentUserId = FirebaseAuth.instance.currentUser?.uid;
    if (currentUserId == null) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text("You need to be logged in to report")),
      );
      return;
    }

    final reportController = TextEditingController();
    String selectedReason = 'Inappropriate content'; // Default reason

    showDialog(
      context: context,
      builder: (context) {
        return AlertDialog(
          title: const Text('Report Post'),
          content: SingleChildScrollView(
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const Text('Please select a reason for reporting this post:'),
                const SizedBox(height: 10),
                DropdownButtonFormField<String>(
                  value: selectedReason,
                  items: const [
                    DropdownMenuItem(
                      value: 'Inappropriate content',
                      child: Text('Inappropriate content'),
                    ),
                    DropdownMenuItem(
                      value: 'Harassment or bullying',
                      child: Text('Harassment or bullying'),
                    ),
                    DropdownMenuItem(
                      value: 'Spam or misleading',
                      child: Text('Spam or misleading'),
                    ),
                    DropdownMenuItem(
                      value: 'Other',
                      child: Text('Other'),
                    ),
                  ],
                  onChanged: (value) {
                    if (value != null) {
                      selectedReason = value;
                    }
                  },
                ),
                if (selectedReason == 'Other')
                  Column(
                    children: [
                      const SizedBox(height: 10),
                      TextField(
                        controller: reportController,
                        decoration: const InputDecoration(
                          hintText: 'Please specify the reason...',
                          border: OutlineInputBorder(),
                        ),
                        maxLines: 3,
                      ),
                    ],
                  ),
              ],
            ),
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(context),
              child: const Text('Cancel'),
            ),
            TextButton(
              onPressed: () async {
                final reason = selectedReason == 'Other'
                    ? reportController.text.trim()
                    : selectedReason;

                if (selectedReason == 'Other' && reason.isEmpty) {
                  ScaffoldMessenger.of(context).showSnackBar(
                    const SnackBar(content: Text("Please provide a reason")),
                  );
                  return;
                }

                await _submitReport(
                  context: context,
                  postId: postId,
                  reportedUserId: reportedUserId,
                  reporterId: currentUserId,
                  postContent: postContent,
                  reason: reason,
                );
              },
              child: const Text('Submit', style: TextStyle(color: Colors.red)),
            ),
          ],
        );
      },
    );
  }

  Future<void> _submitReport({
    required BuildContext context,
    required String postId,
    required String reportedUserId,
    required String reporterId,
    required String postContent,
    required String reason,
  }) async {
    try {
      final reportData = {
        'postId': postId,
        'reportedUserId': reportedUserId,
        'reporterId': reporterId,
        'postContent': postContent,
        'reason': reason,
        'timestamp': FieldValue.serverTimestamp(),
        'status': 'pending', // Can be pending, reviewed, dismissed, etc.
      };

      // Add to reports collection
      await FirebaseFirestore.instance.collection('reportedPosts').add(reportData);

      // Also add to user's report history
      await FirebaseFirestore.instance
          .collection('Users')
          .doc(reporterId)
          .collection('reportsMade')
          .add(reportData);

      // Add to reported user's record
      await FirebaseFirestore.instance
          .collection('Users')
          .doc(reportedUserId)
          .collection('reportsReceived')
          .add(reportData);

      Navigator.pop(context); // Close the dialog
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Report submitted successfully')),
      );
    } catch (e) {
      Navigator.pop(context); // Close the dialog
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Failed to submit report: ${e.toString()}')),
      );
    }
  }

  void _showPostTranslationLanguageSelector(BuildContext context,
      String postId) {
    showModalBottomSheet(
      context: context,
      builder: (BuildContext context) {
        return SingleChildScrollView(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              const Padding(
                padding: EdgeInsets.all(16.0),
                child: Text(
                  'Select a Language to Translate',
                  style: TextStyle(
                    fontSize: 18,
                    fontWeight: FontWeight.bold,
                  ),
                ),
              ),
              ...TranslationService.ghanaianLanguages.entries.map((entry) {
                return ListTile(
                  title: Text(entry.value),
                  onTap: () {
                    Navigator.pop(context);
                    _translatePostAndShowResult(
                        postId, entry.key);
                  },
                );
              }),
            ],
          ),
        );
      },
    );
  }

  Future<void> _translatePostAndShowResult(String postId,
      String languageCode) async {
    final FirebaseFirestore firestore = FirebaseFirestore.instance;
    try {
      final postDoc = await firestore.collection('ForumPosts')
          .doc(postId)
          .get();
      if (postDoc.exists) {
        final postContent = postDoc['content'];
        print('Translating post: "$postContent" to "$languageCode"');
        final translatedText = await TranslationService.translateText(
          text: postContent,
          targetLanguage: languageCode,
        );
        print('Translation Success: $translatedText');

        late final ScaffoldFeatureController<SnackBar,
            SnackBarClosedReason> controller;

        final snackBar = SnackBar(
          backgroundColor: Colors.teal[800],
          content: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text('Translated: $translatedText',
                style: const TextStyle(fontSize: 18),),
              const SizedBox(height: 20),
              Row(
                children: [
                  TextButton(
                    onPressed: () {
                      controller.close();
                    },
                    child: const Text(
                      'Okay',
                      style: TextStyle(color: Colors.white, fontSize: 16),
                    ),
                  ),
                  const SizedBox(width: 25),
                  TextButton(
                    onPressed: () {
                      Clipboard.setData(ClipboardData(text: translatedText));
                      ScaffoldMessenger.of(context).showSnackBar(
                        const SnackBar(content: Text('Translation copied!')),
                      );
                      controller.close();
                    },
                    child: const Text(
                      'Copy',
                      style: TextStyle(color: Colors.white, fontSize: 16),
                    ),
                  ),
                ],
              ),
            ],
          ),
          duration: const Duration(
              days: 365),
        );

        controller = ScaffoldMessenger.of(context).showSnackBar(snackBar);
      } else {
        throw Exception('Post not found');
      }
    } catch (e) {
      print('Translation failed: $e');
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Translation failed: ${e.toString()}')),
      );
    }
  }

  void _showAddPostDialog(BuildContext context) {
    final TextEditingController postController = TextEditingController();
    final String? currentUserId = FirebaseAuth.instance.currentUser?.uid;

    if (currentUserId == null) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text("User not logged in")),
      );
      return;
    }

    showDialog(
      context: context,
      builder: (context) {
        return AlertDialog(
          title: const Text('Create a New Post'),
          backgroundColor: Colors.teal[50],
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(16),
          ),
          content: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              TextField(
                controller: postController,
                decoration: const InputDecoration(
                  hintText: 'Enter your post content...',
                ),
                maxLines: 3,
              ),
            ],
          ),
          actions: [
            TextButton(
              onPressed: () {
                Navigator.pop(context);
              },
              child: Text('Cancel', style: TextStyle(color: Colors.teal[800]),),
            ),
            TextButton(
              style: TextButton.styleFrom(
                backgroundColor: Colors.teal,
              ),
              onPressed: () async {
                if (postController.text.trim().isNotEmpty) {
                  final canPost = await WordFilterService()
                      .canSendMessage(postController.text.trim(), context);
                  if (!canPost) return;
                  DocumentSnapshot userSnapshot = await _firestore.collection('Users').doc(currentUserId).get();
                  if (!userSnapshot.exists) {
                    ScaffoldMessenger.of(context).showSnackBar(
                      const SnackBar(content: Text("User data not found")),
                    );
                    return;
                  }

                  final userData = userSnapshot.data() as Map<String, dynamic>;
                  final String fullName = "${userData['Fname'] ?? 'Unknown'} ${userData['Lname'] ?? ''}".trim();
                  final String userRegion = userData['Region'] ?? 'Unknown Region';

                  await _firestore.collection('ForumPosts').add({
                    'content': postController.text.trim(),
                    'username': fullName,
                    'userId': currentUserId,
                    'timestamp': FieldValue.serverTimestamp(),
                  });

                  await _processMessageForHealthInsights(
                    postController.text.trim(),
                    currentUserId,
                    userRegion,
                  );

                  postController.clear();
                  Navigator.pop(context);
                }
              },
              child: const Text('Post', style: TextStyle(color: Colors.white),),
            ),
          ],
        );
      },
    );
  }

  Future<void> _processMessageForHealthInsights(String messageText, String userId, String userRegion) async {
    final Map<String, List<String>> healthCategories = {
      'symptoms': [
        'fever', 'pain', 'cough', 'fatigue', 'headache', 'nausea',
        'dizziness', 'inflammation', 'rash', 'anxiety', 'malaria',
        'typhoid', 'cholera', 'diarrhea', 'vomiting'
      ],
      'conditions': [
        'diabetes', 'hypertension', 'asthma', 'arthritis', 'depression',
        'obesity', 'cancer', 'allergy', 'infection', 'insomnia',
        'sickle cell', 'tuberculosis', 'HIV', 'hepatitis', 'stroke'
      ],
      'treatments': [
        'medication', 'therapy', 'surgery', 'exercise', 'diet',
        'vaccination', 'rehabilitation', 'counseling', 'prescription', 'supplement',
        'traditional medicine', 'herbs', 'physiotherapy', 'immunization', 'antibiotics'
      ],
      'lifestyle': [
        'nutrition', 'fitness', 'sleep', 'stress', 'wellness',
        'meditation', 'diet', 'exercise', 'hydration', 'mindfulness',
        'traditional food', 'local diet', 'community', 'family health', 'work-life'
      ],
      'preventive': [
        'screening', 'checkup', 'vaccination', 'prevention', 'hygiene',
        'immunization', 'monitoring', 'assessment', 'testing', 'evaluation',
        'sanitation', 'clean water', 'mosquito nets', 'hand washing', 'nutrition'
      ],
    };

    String lowerCaseMessage = messageText.toLowerCase();

    Map<String, Map<String, int>> matchedCategories = {};
    healthCategories.forEach((category, keywords) {
      for (String keyword in keywords) {
        if (lowerCaseMessage.contains(keyword)) {
          matchedCategories.putIfAbsent(category, () => {});
          matchedCategories[category]![keyword] = (matchedCategories[category]![keyword] ?? 0) + 1;
        }
      }
    });

    final healthInsightsCollection = FirebaseFirestore.instance.collection('HealthInsights');

    for (String category in matchedCategories.keys) {
      for (String keyword in matchedCategories[category]!.keys) {
        try {
          final querySnapshot = await healthInsightsCollection
              .where('category', isEqualTo: category)
              .where('messageType', isEqualTo: 'forum')
              .where('region', isEqualTo: userRegion)
              .where('keyword', isEqualTo: keyword)
              .get();

          if (querySnapshot.docs.isNotEmpty) {
            final docId = querySnapshot.docs.first.id;
            await healthInsightsCollection.doc(docId).update({
              'count': FieldValue.increment(matchedCategories[category]![keyword]!),
              'lastUpdated': FieldValue.serverTimestamp(),
            });
          } else {
            await healthInsightsCollection.add({
              'category': category,
              'keyword': keyword,
              'count': matchedCategories[category]![keyword],
              'region': userRegion,
              'messageType': 'forum',
              'timestamp': FieldValue.serverTimestamp(),
              'lastUpdated': FieldValue.serverTimestamp(),
            });
          }
        } catch (e) {
          print('Error processing health insights for category $category and keyword $keyword: $e');
        }
      }
    }

    print("Processed message for health insights: $matchedCategories");
  }
}


class PostDetailsPage extends StatefulWidget {
  final String postId;
  final String postTitle;

  const PostDetailsPage({super.key, required this.postId, required this.postTitle});

  @override
  _PostDetailsPageState createState() => _PostDetailsPageState();
}

class _PostDetailsPageState extends State<PostDetailsPage> with SingleTickerProviderStateMixin {
  final GlobalKey<ScaffoldMessengerState> scaffoldMessengerKey = GlobalKey<ScaffoldMessengerState>();
  final ScrollController _scrollController = ScrollController();
  final TextEditingController commentController = TextEditingController();
  final FocusNode _focusNode = FocusNode(); // FocusNode to manage focus
  String? _replyingToUserId; // To track the user being replied to
  String? _repliedContent; // To store the original message content being replied to
  String? _replyingToCommentId; // To track the comment being replied to
  String? _replyingToUserName; // To store the name of the user being replied to

  // Animation controller for the reply button
  late AnimationController _animationController;
  late Animation<double> _scaleAnimation;

  // Cache for user data
  final Map<String, Map<String, dynamic>> _userDataCache = {};

  @override
  void initState() {
    super.initState();

    // Initialize animation controller and animation
    _animationController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 100),
    );
    _scaleAnimation = Tween<double>(begin: 1.0, end: 0.8).animate(
      CurvedAnimation(
        parent: _animationController,
        curve: Curves.easeInOut,
      ),
    );

    // Fetch and cache user data
    _fetchAndCacheUserData();
  }

  Future<void> _fetchAndCacheUserData() async {
    try {
      // Fetch all users from Firestore
      final usersSnapshot = await FirebaseFirestore.instance.collection('Users').get();
      for (final userDoc in usersSnapshot.docs) {
        _userDataCache[userDoc.id] = userDoc.data() as Map<String, dynamic>;
      }
    } catch (e) {
      print('Error fetching user data: $e');
    }
  }

  @override
  void dispose() {
    _animationController.dispose(); // Dispose the animation controller
    super.dispose();
  }

  void _replyToMessage(BuildContext context, String shortUserName, String content, String replyUserId, String commentId) {
    // Focus the reply TextField to activate the keyboard
    _focusNode.requestFocus();

    setState(() {
      // Set the user and comment details for reply tracking
      _replyingToUserId = replyUserId;
      _repliedContent = content;
      _replyingToCommentId = commentId;
      _replyingToUserName = shortUserName; // Store the name of the user being replied to
    });
  }

  void _cancelReply() {
    // Clear the reply state and hide the reply bar
    setState(() {
      _replyingToUserId = null;
      _repliedContent = null;
      _replyingToCommentId = null;
      _replyingToUserName = null;
    });
    commentController.clear(); // Clear the text input
    _focusNode.unfocus(); // Remove focus from the text input
  }

  void _animateReplyButton() {
    // Play the animation when the reply button is tapped
    _animationController.forward().then((_) {
      _animationController.reverse();
    });
  }

  @override
  Widget build(BuildContext context) {
    final String? currentUserId = FirebaseAuth.instance.currentUser?.uid;
    // Add a cache map for user data
    final Map<String, Map<String, dynamic>> userDataCache = {};

    return Scaffold(
      key: scaffoldMessengerKey,
      appBar: AppBar(
        title: const Text('Discussion', style: TextStyle(color: Colors.white)),
        backgroundColor: Colors.teal,
        elevation: 4,
        iconTheme: const IconThemeData(color: Colors.white),
      ),
      body: Column(
        children: [
          // Post topic at the top (full-width background)
          Container(
            width: double.infinity,
            padding: const EdgeInsets.all(16.0),
            decoration: BoxDecoration(
              color: Colors.teal[50],
              boxShadow: [
                BoxShadow(
                  color: Colors.grey.withOpacity(0.3),
                  blurRadius: 4,
                  offset: const Offset(0, 2),
                ),
              ],
            ),
            child: Text(
              widget.postTitle,
              style: TextStyle(fontSize: 20, fontWeight: FontWeight.bold, color: Colors.tealAccent[900]),
            ),
          ),
          Expanded(
            // Use StreamBuilder with keepAlive to prevent rebuilding
            child: StreamBuilder<QuerySnapshot>(
              stream: FirebaseFirestore.instance
                  .collection('ForumPosts')
                  .doc(widget.postId)
                  .collection('comments')
                  .orderBy('timestamp')
                  .snapshots(),
              builder: (context, snapshot) {
                if (snapshot.hasError) {
                  return Center(child: Text('Error: ${snapshot.error}'));
                }
                if (!snapshot.hasData) {
                  return const Center(child: CircularProgressIndicator());
                }

                final comments = snapshot.data!.docs;

                // Pre-fetch all user data at once to avoid multiple FutureBuilders
                final Set<String> userIds = {};
                for (var comment in comments) {
                  final data = comment.data() as Map<String, dynamic>;
                  userIds.add(data['userId'] as String);
                  if (data['repliedTo'] != null && data['repliedTo'].isNotEmpty) {
                    userIds.add(data['repliedTo'] as String);
                  }
                }

                return FutureBuilder<void>(
                  // Pre-fetch all user data
                  future: _fetchUserData(userIds, userDataCache),
                  builder: (context, fetchSnapshot) {
                    if (fetchSnapshot.connectionState == ConnectionState.waiting) {
                      return const Center(child: CircularProgressIndicator());
                    }

                    return ListView.builder(
                      controller: _scrollController,
                      // Enable caching of items that are off-screen
                      cacheExtent: 1000, // Cache more items than default
                      itemCount: comments.length,
                      itemBuilder: (context, index) {
                        final comment = comments[index].data() as Map<String, dynamic>;
                        final userId = comment['userId'];
                        final commentId = comments[index].id;
                        final repliedTo = comment['repliedTo'] ?? '';
                        final repliedContent = comment['repliedContent'] ?? '';
                        final timestamp = comment['timestamp'] != null
                            ? (comment['timestamp'] as Timestamp).toDate()
                            : DateTime.now();

                        // Use cached user data instead of FutureBuilder
                        final userData = userDataCache[userId];
                        final fname = userData?['Fname'] ?? 'Unknown';
                        final lname = userData?['Lname'] ?? 'User';
                        final fullName = '$fname $lname';

                        return Column(
                          children: [
                            Card(
                              key: ValueKey('comment_$commentId'), // Add a key for better list management
                              margin: const EdgeInsets.symmetric(vertical: 8, horizontal: 16),
                              elevation: 2,
                              shape: RoundedRectangleBorder(
                                borderRadius: BorderRadius.circular(12),
                              ),
                              child: Padding(
                                padding: const EdgeInsets.all(12.0),
                                child: Column(
                                  crossAxisAlignment: CrossAxisAlignment.start,
                                  children: [
                                    if (repliedTo.isNotEmpty) _buildReplyWidget(
                                        repliedTo,
                                        repliedContent,
                                        userDataCache,
                                        comment['repliedToCommentId'] ?? '', // Fixed: Provide empty string as fallback
                                        comments
                                    ),
                                    Row(
                                      children: [
                                        Expanded(
                                          child: ListTile(
                                            contentPadding: EdgeInsets.zero,
                                            title: Text(
                                              comment['content'] ?? 'No Content',
                                              style: const TextStyle(fontSize: 16),
                                            ),
                                            subtitle: Padding(
                                              padding: const EdgeInsets.only(top: 8.0),
                                              child: Text(
                                                'Posted by: $fullName\n${DateFormat('yyyy-MM-dd HH:mm').format(timestamp)}',
                                                style: TextStyle(color: Colors.grey[600]),
                                              ),
                                            ),
                                          ),
                                        ),
                                        // Reply Icon
                                        IconButton(
                                          icon: ScaleTransition(
                                            scale: _scaleAnimation,
                                            child: const Icon(Icons.reply, color: Colors.tealAccent),
                                          ),
                                          onPressed: () {
                                            _animateReplyButton();
                                            _focusNode.requestFocus();
                                            _replyToMessage(context, '$fname $lname', comment['content'], comment['userId'], commentId);
                                          },
                                        ),
                                        // Vertical Dot Icon for Comment Menu
                                        IconButton(
                                          icon: Icon(Icons.more_vert, color: Colors.grey[600]),
                                          onPressed: () {
                                            try {
                                              final commentDoc = comments[index] as QueryDocumentSnapshot<Map<String, dynamic>>;
                                              _showCommentMenu(context, scaffoldMessengerKey, commentDoc);
                                            } catch (e) {
                                              ScaffoldMessenger.of(context).showSnackBar(
                                                SnackBar(content: Text('Error loading comment: ${e.toString()}')),
                                              );
                                            }
                                          },
                                        ),
                                      ],
                                    ),
                                  ],
                                ),
                              ),
                            ),
                            // Divider between comments
                            if (index < comments.length - 1)
                              Divider(
                                height: 1,
                                thickness: 1,
                                color: Colors.grey[300],
                                indent: 16,
                                endIndent: 16,
                              ),
                          ],
                        );
                      },
                    );
                  },
                );
              },
            ),
          ),
          if (_replyingToUserName != null)
            Container(
              color: Colors.grey[200],
              padding: const EdgeInsets.all(8.0),
              child: Row(
                children: [
                  Text(
                    'Replying to $_replyingToUserName: ${_repliedContent != null && _repliedContent!.isNotEmpty ? '${_repliedContent!.substring(0, min(_repliedContent!.length, 15))}...' : _repliedContent ?? ''}',
                    style: TextStyle(fontWeight: FontWeight.bold, color: Colors.teal[800]),
                  ),
                  const Spacer(),
                  IconButton(
                    icon: Icon(Icons.close, color: Colors.grey[600]),
                    onPressed: _cancelReply,
                  ),
                ],
              ),
            ),
          Container(
            color: Colors.grey[200],
            padding: const EdgeInsets.all(8.0),
            child: Row(
              children: [
                Expanded(
                  child: Container(
                    decoration: BoxDecoration(
                      color: Colors.white,
                      borderRadius: BorderRadius.circular(30),
                      boxShadow: [
                        BoxShadow(
                          color: Colors.grey.withOpacity(0.2),
                          blurRadius: 4,
                          offset: const Offset(0, 2),
                        ),
                      ],
                    ),
                    constraints: const BoxConstraints(maxHeight: 120),
                    child: TextField(
                      controller: commentController,
                      focusNode: _focusNode,
                      decoration: InputDecoration(
                        hintText: 'Type comment here...',
                        border: InputBorder.none,
                        contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
                        suffixIcon: Container(
                          width: 36,
                          height: 36,
                          margin: const EdgeInsets.all(8), // Add some margin around the circle
                          decoration: BoxDecoration(
                            color: Colors.tealAccent, // teal background color
                            shape: BoxShape.circle, // Make it circular
                          ),
                          child: IconButton(
                            icon: const Icon(Icons.send, color: Colors.white), // White icon for contrast
                            onPressed: () async {
                              if (commentController.text.trim().isNotEmpty) {
                                if (currentUserId == null) {
                                  ScaffoldMessenger.of(context).showSnackBar(
                                    const SnackBar(content: Text("User not logged in")),
                                  );
                                  return;
                                }

                                final canPost = await WordFilterService().canSendMessage(
                                    commentController.text.trim(),
                                    context
                                );
                                if (!canPost) return;

                                DocumentSnapshot userSnapshot = await FirebaseFirestore.instance
                                    .collection('Users')
                                    .doc(currentUserId)
                                    .get();
                                if (!userSnapshot.exists) {
                                  ScaffoldMessenger.of(context).showSnackBar(
                                    const SnackBar(content: Text("User data not found")),
                                  );
                                  return;
                                }

                                final userData = userSnapshot.data() as Map<String, dynamic>;
                                final fullName = "${userData['Fname'] ?? 'Unknown'} ${userData['Lname'] ?? ''}".trim();
                                final userRegion = userData['Region'] ?? 'Unknown Region';

                                // Prepare the comment data
                                Map<String, dynamic> commentData = {
                                  'content': commentController.text,
                                  'userId': currentUserId,
                                  'username': fullName,
                                  'timestamp': FieldValue.serverTimestamp(),
                                };

                                // Add reply details if replying to a comment
                                if (_replyingToUserId != null) {
                                  commentData['repliedTo'] = _replyingToUserId;
                                  commentData['repliedContent'] = _repliedContent;
                                  commentData['repliedToCommentId'] = _replyingToCommentId;
                                }

                                // Add the comment to Firestore
                                await FirebaseFirestore.instance
                                    .collection('ForumPosts')
                                    .doc(widget.postId)
                                    .collection('comments')
                                    .add(commentData);

                                // Process the message for health insights (for both regular comments and replies)
                                await _processMessageForHealthInsights(
                                  commentController.text, // Process the reply content
                                  currentUserId,
                                  userRegion,
                                );

                                // Clear the comment controller and reply state
                                commentController.clear();
                                setState(() {
                                  _replyingToUserId = null;
                                  _repliedContent = null;
                                  _replyingToCommentId = null;
                                  _replyingToUserName = null;
                                });
                              }
                            },
                          ),
                        ),
                      ),
                      maxLines: null,
                      keyboardType: TextInputType.multiline,
                    ),
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

// Add this helper method to fetch all user data at once
  Future<void> _fetchUserData(Set<String> userIds, Map<String, Map<String, dynamic>> cache) async {
    List<Future> futures = [];

    for (String userId in userIds) {
      if (!cache.containsKey(userId)) {
        futures.add(
            FirebaseFirestore.instance.collection('Users').doc(userId).get().then((snapshot) {
              if (snapshot.exists) {
                cache[userId] = snapshot.data() as Map<String, dynamic>;
              } else {
                cache[userId] = {'Fname': 'Unknown', 'Lname': 'User'};
              }
            }).catchError((error) {
              cache[userId] = {'Fname': 'Unknown', 'Lname': 'User'};
            })
        );
      }
    }

    if (futures.isNotEmpty) {
      await Future.wait(futures);
    }
  }

// Add this helper method for the reply widget
  Widget _buildReplyWidget(String repliedTo, String repliedContent, Map<String, Map<String, dynamic>> userDataCache, String repliedToCommentId, List<QueryDocumentSnapshot> comments) {
    final repliedUserData = userDataCache[repliedTo];
    final repliedFname = repliedUserData?['Fname'] ?? 'Unknown';
    final repliedLname = repliedUserData?['Lname'] ?? 'User';
    final repliedToName = '$repliedFname $repliedLname';

    return Container(
      padding: const EdgeInsets.all(8.0),
      margin: const EdgeInsets.only(bottom: 8.0),
      decoration: BoxDecoration(
        color: Colors.grey[200],
        borderRadius: BorderRadius.circular(8),
      ),
      child: InkWell(
        onTap: () {
          if (repliedToCommentId.isNotEmpty) {
            _scrollToMessage(repliedToCommentId, comments);
          }
        },
        child: Text(
          'Replying to $repliedToName: ${_truncateText(repliedContent, 15)}',
          style: TextStyle(
            color: Colors.teal[800],
            fontWeight: FontWeight.bold,
          ),
        ),
      ),
    );
  }

  // Scroll to the message when user clicks on the user ID
  void _scrollToMessage(String commentId, List<QueryDocumentSnapshot> comments) {
    final index = _getCommentIndexById(commentId, comments);
    if (index != -1) {
      _scrollController.animateTo(
        index * 100.0, // Adjust based on your item height
        duration: const Duration(milliseconds: 300),
        curve: Curves.easeInOut,
      );
    }
  }

  int _getCommentIndexById(String commentId, List<QueryDocumentSnapshot> comments) {
    // Find the index of the comment by ID (this will be used to scroll to that specific comment)
    return comments.indexWhere((comment) => comment.id == commentId);
  }

  void _showCommentMenu(
      BuildContext context,
      GlobalKey<ScaffoldMessengerState> scaffoldMessengerKey,
      QueryDocumentSnapshot<Map<String, dynamic>> comment,
      ) {
    final currentUserId = FirebaseAuth.instance.currentUser?.uid;
    final commentUserId = comment['userId'];

    // Only show delete option if current user is the comment owner
    final canDelete = currentUserId == commentUserId;

    showModalBottomSheet(
      context: context,
      builder: (context) {
        return Wrap(
          children: [
            if (canDelete) // Only show delete option if user owns the comment
              ListTile(
                leading: const Icon(Icons.delete),
                title: const Text('Delete Comment'),
                onTap: () async {
                  Navigator.pop(context);
                  final bool shouldDelete = await showDialog(
                    context: context,
                    builder: (BuildContext context) {
                      return AlertDialog(
                        title: const Text('Delete Comment'),
                        content: const Text('Are you sure you want to delete this comment?'),
                        actions: [
                          TextButton(
                            child: const Text('No'),
                            onPressed: () => Navigator.pop(context, false),
                          ),
                          TextButton(
                            style: TextButton.styleFrom(
                              foregroundColor: Colors.red,
                            ),
                            onPressed: () => Navigator.pop(context, true),
                            child: const Text('Yes'),
                          ),
                        ],
                      );
                    },
                  ) ?? false;

                  if (shouldDelete) {
                    await comment.reference.delete();
                    scaffoldMessengerKey.currentState?.showSnackBar(
                      const SnackBar(content: Text('Comment deleted!')),
                    );
                  }
                },
              ),
            ListTile(
              leading: const Icon(Icons.copy),
              title: const Text('Copy Comment'),
              onTap: () {
                Clipboard.setData(ClipboardData(text: comment['content']));
                Navigator.pop(context);
                scaffoldMessengerKey.currentState?.showSnackBar(
                  const SnackBar(content: Text('Comment copied to clipboard!')),
                );
              },
            ),
            ListTile(
              leading: const Icon(Icons.translate),
              title: const Text('Translate Comment'),
              onTap: () {
                Navigator.pop(context);
                _showCommentTranslationLanguageSelector(
                  context,
                  scaffoldMessengerKey,
                  comment,
                );
              },
            ),
            ListTile(
              leading: const Icon(Icons.report, color: Colors.red),
              title: const Text('Report Comment', style: TextStyle(color: Colors.red)),
              onTap: () {
                Navigator.pop(context);
                _showCommentReportDialog(
                  context: context,
                  commentId: comment.id,
                  commentUserId: commentUserId,
                  commentContent: comment['content'],
                  postId: widget.postId,
                  scaffoldMessengerKey: scaffoldMessengerKey,
                );
              },
            ),
          ],
        );
      },
    );
  }

  void _showCommentReportDialog({
    required BuildContext context,
    required String commentId,
    required String commentUserId,
    required String commentContent,
    required String postId,
    required GlobalKey<ScaffoldMessengerState> scaffoldMessengerKey,
  }) {
    final currentUserId = FirebaseAuth.instance.currentUser?.uid;
    if (currentUserId == null) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text("You need to be logged in to report")),
      );
      return;
    }

    final reportController = TextEditingController();
    String selectedReason = 'Inappropriate content'; // Default reason

    showDialog(
      context: context,
      builder: (context) {
        return Dialog(
          insetPadding: const EdgeInsets.symmetric(horizontal: 20, vertical: 24),
          child: SingleChildScrollView(
            child: Padding(
              padding: const EdgeInsets.all(16.0),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const Text(
                    'Report Comment',
                    style: TextStyle(fontSize: 20, fontWeight: FontWeight.bold),
                  ),
                  const SizedBox(height: 16),
                  const Text('Please select a reason for reporting this comment:'),
                  const SizedBox(height: 10),
                  DropdownButtonFormField<String>(
                    value: selectedReason,
                    isExpanded: true,
                    items: const [
                      DropdownMenuItem(
                        value: 'Inappropriate content',
                        child: Text('Inappropriate content'),
                      ),
                      DropdownMenuItem(
                        value: 'Harassment or bullying',
                        child: Text('Harassment or bullying'),
                      ),
                      DropdownMenuItem(
                        value: 'False information',
                        child: Text('False information'),
                      ),
                      DropdownMenuItem(
                        value: 'Spam or misleading',
                        child: Text('Spam or misleading'),
                      ),
                      DropdownMenuItem(
                        value: 'Other',
                        child: Text('Other'),
                      ),
                    ],
                    onChanged: (value) {
                      if (value != null) {
                        selectedReason = value;
                        // Force rebuild
                        (context as Element).markNeedsBuild();
                      }
                    },
                  ),
                  if (selectedReason == 'Other') ...[
                    const SizedBox(height: 16),
                    TextField(
                      controller: reportController,
                      decoration: const InputDecoration(
                        hintText: 'Please specify the reason...',
                        border: OutlineInputBorder(),
                        contentPadding: EdgeInsets.all(12),
                      ),
                      maxLines: 3,
                      autofocus: true,
                    ),
                  ],
                  const SizedBox(height: 24),
                  Row(
                    mainAxisAlignment: MainAxisAlignment.end,
                    children: [
                      TextButton(
                        onPressed: () => Navigator.pop(context),
                        child: const Text('Cancel'),
                      ),
                      const SizedBox(width: 8),
                      ElevatedButton(
                        onPressed: () async {
                          final reason = selectedReason == 'Other'
                              ? reportController.text.trim()
                              : selectedReason;

                          if (selectedReason == 'Other' && reason.isEmpty) {
                            ScaffoldMessenger.of(context).showSnackBar(
                              const SnackBar(content: Text("Please provide a reason")),
                            );
                            return;
                          }

                          await _submitCommentReport(
                            context: context,
                            commentId: commentId,
                            commentUserId: commentUserId,
                            reporterId: currentUserId,
                            commentContent: commentContent,
                            postId: postId,
                            reason: reason,
                          );
                        },
                        style: ElevatedButton.styleFrom(
                          backgroundColor: Colors.red,
                          foregroundColor: Colors.white,
                        ),
                        child: const Text('Submit'),
                      ),
                    ],
                  ),
                ],
              ),
            ),
          ),
        );
      },
    );
  }

  Future<void> _submitCommentReport({
    required BuildContext context,
    required String commentId,
    required String commentUserId,
    required String reporterId,
    required String commentContent,
    required String postId,
    required String reason,
  }) async {
    try {
      // Show loading indicator
      showDialog(
        context: context,
        barrierDismissible: false,
        builder: (context) => const Center(child: CircularProgressIndicator()),
      );

      final reportData = {
        'commentId': commentId,
        'postId': postId,
        'reportedUserId': commentUserId,
        'reporterId': reporterId,
        'commentContent': commentContent,
        'reason': reason,
        'timestamp': FieldValue.serverTimestamp(),
        'status': 'pending',
      };

      // Add to reports collection
      await FirebaseFirestore.instance.collection('reportedComments').add(reportData);

      // Also add to user's report history
      await FirebaseFirestore.instance
          .collection('Users')
          .doc(reporterId)
          .collection('reportsMade')
          .add(reportData);

      // Add to reported user's record
      await FirebaseFirestore.instance
          .collection('Users')
          .doc(commentUserId)
          .collection('reportsReceived')
          .add(reportData);

      // Close loading indicator and dialog
      Navigator.pop(context); // Loading indicator
      Navigator.pop(context); // Report dialog

      // Show success message
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: const Text('Report submitted successfully! Our team will review it.'),
          duration: const Duration(seconds: 3),
          behavior: SnackBarBehavior.floating,
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(10),
          ),
          backgroundColor: Colors.green,
        ),
      );
    } catch (e) {
      Navigator.pop(context); // Close loading indicator if open
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('Failed to submit report: ${e.toString()}'),
          duration: const Duration(seconds: 3),
          behavior: SnackBarBehavior.floating,
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(10),
          ),
          backgroundColor: Colors.red,
        ),
      );
    }
  }

  void _showCommentTranslationLanguageSelector(
      BuildContext context,
      GlobalKey<ScaffoldMessengerState> scaffoldMessengerKey,
      QueryDocumentSnapshot<Map<String, dynamic>> comment,
      ) {
    final postId = comment.reference.parent.parent?.id; // Get the postId from the comment's parent
    final commentId = comment.id; // Get the commentId

    if (postId == null) {
      // Handle the case where postId is null
      scaffoldMessengerKey.currentState?.showSnackBar(
        const SnackBar(content: Text('Error: Post not found.')),
      );
      return;
    }

    showModalBottomSheet(
      context: context,
      builder: (BuildContext context) {
        return SingleChildScrollView(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              const Padding(
                padding: EdgeInsets.all(16.0),
                child: Text(
                  'Select a Language to Translate',
                  style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
                ),
              ),
              ...TranslationService.ghanaianLanguages.entries.map((entry) {
                return ListTile(
                  title: Text(entry.value),
                  onTap: () {
                    Navigator.pop(context);
                    _translateCommentAndShowResult(
                      postId, // Pass the postId (non-nullable)
                      commentId, // Pass the commentId
                      entry.key, // Pass the languageCode
                    );
                  },
                );
              }),
            ],
          ),
        );
      },
    );
  }

  Future<void> _translateCommentAndShowResult(
      String postId,
      String commentId,
      String languageCode,
      ) async {
    final FirebaseFirestore firestore = FirebaseFirestore.instance;
    try {
      // Fetch the comment document from the sub-collection
      final commentDoc = await firestore
          .collection('ForumPosts')
          .doc(postId)
          .collection('comments')
          .doc(commentId)
          .get();

      if (commentDoc.exists) {
        final commentContent = commentDoc['content'];
        print('Translating comment: "$commentContent" to "$languageCode"');
        final translatedText = await TranslationService.translateText(
          text: commentContent,
          targetLanguage: languageCode,
        );
        print('Translation Success: $translatedText');

        // Declare the controller as a late variable
        late final ScaffoldFeatureController<SnackBar, SnackBarClosedReason> controller;

        // Create the SnackBar content
        final snackBar = SnackBar(
          backgroundColor: Colors.teal[800],
          content: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                'Translated: $translatedText',
                style: const TextStyle(fontSize: 18),
              ),
              const SizedBox(height: 20),
              Row(
                children: [
                  TextButton(
                    onPressed: () {
                      controller.close(); // Dismiss the SnackBar
                    },
                    child: const Text(
                      'Okay',
                      style: TextStyle(color: Colors.white, fontSize: 16),
                    ),
                  ),
                  const SizedBox(width: 25),
                  TextButton(
                    onPressed: () {
                      Clipboard.setData(ClipboardData(text: translatedText));
                      ScaffoldMessenger.of(context).showSnackBar(
                        const SnackBar(content: Text('Translation copied!')),
                      );
                      controller.close(); // Dismiss the SnackBar
                    },
                    child: const Text(
                      'Copy',
                      style: TextStyle(color: Colors.white, fontSize: 16),
                    ),
                  ),
                ],
              ),
            ],
          ),
          duration: const Duration(days: 365), // Keep the SnackBar open indefinitely
        );

        // Assign the controller after showing the SnackBar
        controller = ScaffoldMessenger.of(context).showSnackBar(snackBar);
      } else {
        throw Exception('Comment not found');
      }
    } catch (e) {
      print('Translation failed: $e');
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Translation failed: ${e.toString()}')),
      );
    }
  }

  Future<void> _processMessageForHealthInsights(String messageText,
      String userId, String userRegion) async {
    // Define health categories and keywords
    final Map<String, List<String>> healthCategories = {
      'symptoms': [
        'fever', 'pain', 'cough', 'fatigue', 'headache', 'nausea',
        'dizziness', 'inflammation', 'rash', 'anxiety', 'malaria',
        'typhoid', 'cholera', 'diarrhea', 'vomiting'
      ],
      'conditions': [
        'diabetes', 'hypertension', 'asthma', 'arthritis', 'depression',
        'obesity', 'cancer', 'allergy', 'infection', 'insomnia',
        'sickle cell', 'tuberculosis', 'HIV', 'hepatitis', 'stroke'
      ],
      'treatments': [
        'medication',
        'therapy',
        'surgery',
        'exercise',
        'diet',
        'vaccination',
        'rehabilitation',
        'counseling',
        'prescription',
        'supplement',
        'traditional medicine',
        'herbs',
        'physiotherapy',
        'immunization',
        'antibiotics'
      ],
      'lifestyle': [
        'nutrition',
        'fitness',
        'sleep',
        'stress',
        'wellness',
        'meditation',
        'diet',
        'exercise',
        'hydration',
        'mindfulness',
        'traditional food',
        'local diet',
        'community',
        'family health',
        'work-life'
      ],
      'preventive': [
        'screening',
        'checkup',
        'vaccination',
        'prevention',
        'hygiene',
        'immunization',
        'monitoring',
        'assessment',
        'testing',
        'evaluation',
        'sanitation',
        'clean water',
        'mosquito nets',
        'hand washing',
        'nutrition'
      ],
    };

    // Convert message text to lowercase for case-insensitive matching
    String lowerCaseMessage = messageText.toLowerCase();

    // Identify matched categories and keywords
    Map<String, Map<String, int>> matchedCategories = {};
    healthCategories.forEach((category, keywords) {
      for (String keyword in keywords) {
        if (lowerCaseMessage.contains(keyword)) {
          matchedCategories.putIfAbsent(category, () => {});
          matchedCategories[category]![keyword] =
              (matchedCategories[category]![keyword] ?? 0) + 1;
        }
      }
    });

    // Get reference to the HealthInsights collection
    final healthInsightsCollection = FirebaseFirestore.instance.collection(
        'HealthInsights');

    // Update or create documents for each matched category and keyword
    for (String category in matchedCategories.keys) {
      for (String keyword in matchedCategories[category]!.keys) {
        try {
          // Query for existing document with matching category, messageType, region, and keyword
          final querySnapshot = await healthInsightsCollection
              .where('category', isEqualTo: category)
              .where('messageType', isEqualTo: 'forum')
              .where('region', isEqualTo: userRegion)
              .where('keyword', isEqualTo: keyword)
              .get();

          if (querySnapshot.docs.isNotEmpty) {
            // Document exists, update the count
            final docId = querySnapshot.docs.first.id;
            await healthInsightsCollection.doc(docId).update({
              'count': FieldValue.increment(
                  matchedCategories[category]![keyword]!),
              'lastUpdated': FieldValue.serverTimestamp(),
            });
          } else {
            // Document doesn't exist, create new one
            await healthInsightsCollection.add({
              'category': category,
              'keyword': keyword,
              'count': matchedCategories[category]![keyword],
              'region': userRegion,
              'messageType': 'forum',
              'timestamp': FieldValue.serverTimestamp(),
              'lastUpdated': FieldValue.serverTimestamp(),
            });
          }
        } catch (e) {
          print(
              'Error processing health insights for category $category and keyword $keyword: $e');
        }
      }
    }

    print("Processed message for health insights: $matchedCategories");
  }
}

String _truncateText(String? text, int maxLength) {
  if (text == null || text.isEmpty) {
    return ''; // Return an empty string if the text is null or empty
  }
  if (text.length <= maxLength) {
    return text; // Return the full text if it's shorter than or equal to maxLength
  }
  return '${text.substring(0, maxLength)}...'; // Truncate and append '...'
}


class AudioPlaybackState {
  final String url;
  bool isPlaying = false;
  Duration currentPosition = Duration.zero;
  Duration totalDuration = Duration.zero;

  AudioPlaybackState(this.url);
}


class ChatThreadDetailsPage extends StatefulWidget {
  final String chatId;
  final String toName;
  final String toUid;
  final String fromUid;

  const ChatThreadDetailsPage({
    super.key,
    required this.chatId,
    required this.toName,
    required this.toUid,
    required this.fromUid,
  });

  @override
  _ChatThreadDetailsPageState createState() => _ChatThreadDetailsPageState();
}

class _ChatThreadDetailsPageState extends State<ChatThreadDetailsPage> {
  final TextEditingController _messageController = TextEditingController();
  final FirebaseFirestore _firestore = FirebaseFirestore.instance;
  final FlutterSoundPlayer _player = FlutterSoundPlayer();
  final FlutterSoundRecorder _recorder = FlutterSoundRecorder();
  String? _audioPath;
  String? _cachedUserPic;
  bool? _cachedIsOnline;
  bool _isLoadingUserData = true;
  int _newMessagesCount = 0;

  bool _isUserBlocked = false;
  bool _isCheckingBlockStatus = true;


  bool _isRecording = false;
  Duration _recordingDuration = Duration.zero;
  Timer? _recordingTimer;

  // Track currently playing audio URL
  String? _currentlyPlayingUrl;

  // Track playback state for each audio message
  final Map<String, bool> _audioPlaybackStates = {};
  final Map<String, Duration> _audioPlaybackDurations = {};
  final Map<String, Duration> _audioTotalDurations = {};
  Timer? _playbackTimer;

  // Track current audio position for each message
  final Map<String, Duration> _currentPositions = {};
  final Map<String,
      StreamSubscription<PlaybackDisposition>> _positionSubscriptions = {};
  final Map<String, Duration> _durations = {};

  // Add ScrollController for scroll-to-bottom functionality
  final ScrollController _scrollController = ScrollController();
  bool _showScrollToBottomButton = false;

  // Use a GlobalKey to ensure the context remains valid
  final GlobalKey<_ChatThreadDetailsPageState> _pageKey = GlobalKey();

  // Subscription for position updates
  StreamSubscription? _playerSubscription;

  @override
  void initState() {
    super.initState();
    _player.openPlayer();
    _recorder.openRecorder();
    Permission.microphone.request();

    _fetchAndCacheUserData();

    _initializePlayer();

    // Add scroll listener
    _scrollController.addListener(_onScroll);

    // Initialize call service to listen for incoming calls
    //CallService().initialize();

    // Scroll to bottom when page first loads
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (_scrollController.hasClients) {
        _scrollToBottom();
      }
    });

    _checkBlockStatus();
  }

  Future<void> _checkBlockStatus() async {
    final currentUserId = FirebaseAuth.instance.currentUser?.uid;
    if (currentUserId == null) return;

    try {
      final blockDoc = await FirebaseFirestore.instance
          .collection('UserBlocks')
          .doc(currentUserId)
          .collection('blockedUsers')
          .doc(widget.toUid)
          .get();

      setState(() {
        _isUserBlocked = blockDoc.exists;
        _isCheckingBlockStatus = false;
      });
    } catch (e) {
      print('Error checking block status: $e');
      setState(() {
        _isCheckingBlockStatus = false;
      });
    }
  }

  Future<void> _fetchAndCacheUserData() async {
    try {
      final userDoc = await FirebaseFirestore.instance
          .collection('Users')
          .doc(widget.toUid)
          .get();

      if (userDoc.exists) {
        final userData = userDoc.data() as Map<String, dynamic>?;
        setState(() {
          _cachedUserPic = userData?['User Pic'];
          _cachedIsOnline = userData?['Status'] ?? false;
          _isLoadingUserData = false;
        });
      } else {
        setState(() {
          _isLoadingUserData = false;
        });
      }
    } catch (e) {
      print('Error fetching user data: $e');
      setState(() {
        _isLoadingUserData = false;
      });
    }
  }

  Future<void> _initializePlayer() async {
    _player.openPlayer();  // No await
    _player.setLogLevel(Level.info);  // No await
  }

  @override
  void dispose() {
    _recorder.closeRecorder();
    _player.closePlayer();
    _recordingTimer?.cancel();
    _playbackTimer?.cancel();
    _scrollController.removeListener(_onScroll);
    _scrollController.dispose();
    for (var sub in _positionSubscriptions.values) {
      sub.cancel();
    }
    _playerSubscription?.cancel();
    _player.closePlayer();

    // Dispose the call service
    CallService().dispose();
    // Mark messages as read when the chat thread is closed
    _markMessagesAsRead();

    super.dispose();
  }

  Future<void> _markMessagesAsRead() async {
    final currentUserId = FirebaseAuth.instance.currentUser?.uid;
    if (currentUserId == null) return;

    final messagesSnapshot = await _firestore
        .collection('ChatMessages')
        .doc(widget.chatId)
        .collection('messages')
        .where('to_uid', isEqualTo: currentUserId)
        .where('read', isEqualTo: false)
        .get();

    final batch = _firestore.batch();
    for (var doc in messagesSnapshot.docs) {
      batch.update(doc.reference, {'read': true});
    }
    await batch.commit();
  }

  Future<void> _onVideoCallPressed() async {
    if (_isUserBlocked) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('You have blocked this user')),
      );
      return;
    }

    // Check if you're blocked by the other user
    final isBlockedByOtherUser = await _checkIfBlockedByOtherUser();
    if (isBlockedByOtherUser) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('This user has blocked you')),
      );
      return;
    }
    // Request camera and microphone permissions
    Future.wait([
      Permission.camera.request(),
      Permission.microphone.request(),
    ]).then((statuses) {
      if (statuses[0].isGranted && statuses[1].isGranted) {
        // If permissions are granted, start the call
        CallService().startCall(context, widget.toUid, widget.toName, widget.chatId);
      } else {
        // If permissions are denied, show a message
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text(
                'Camera and microphone permissions are required for video calls'),
            duration: Duration(seconds: 3),
          ),
        );
      }
    });
  }


  void _onScroll() {
    if (_scrollController.hasClients) {
      setState(() {
        _showScrollToBottomButton = _scrollController.position.pixels <
            _scrollController.position.maxScrollExtent - 100;
      });
    }
  }

  void _scrollToBottom() {
    if (_scrollController.hasClients) {
      _scrollController.animateTo(
        _scrollController.position.maxScrollExtent,
        duration: const Duration(milliseconds: 300),
        curve: Curves.easeOut,
      );

      // Reset new messages count
      setState(() {
        _newMessagesCount = 0;
      });
    }
  }

  void _showMessageMenu(QueryDocumentSnapshot<Map<String, dynamic>> message) {
    final currentUserId = FirebaseAuth.instance.currentUser?.uid;
    final isSentByUser = message['from_uid'] == currentUserId;

    showModalBottomSheet(
      context: context,
      builder: (context) {
        return Wrap(
          children: [
            // Only show delete option if the message was sent by the current user
            if (isSentByUser)
              ListTile(
                leading: const Icon(Icons.delete),
                title: const Text('Delete Message'),
                onTap: () async {
                  Navigator.pop(context); // Close the menu

                  final bool shouldDelete = await showDialog(
                    context: context,
                    builder: (BuildContext context) {
                      return AlertDialog(
                        title: const Text('Delete Message'),
                        content: const Text('Are you sure you want to delete this message?'),
                        actions: [
                          TextButton(
                            child: const Text('No'),
                            onPressed: () => Navigator.pop(context, false),
                          ),
                          TextButton(
                            style: TextButton.styleFrom(
                              foregroundColor: Colors.red,
                            ),
                            onPressed: () => Navigator.pop(context, true),
                            child: const Text('Yes'),
                          ),
                        ],
                      );
                    },
                  ) ?? false;

                  if (shouldDelete) {
                    await message.reference.delete();
                  }
                },
              ),
            ListTile(
              leading: const Icon(Icons.copy),
              title: const Text('Copy Message'),
              onTap: () {
                Clipboard.setData(ClipboardData(text: message['content']));
                Navigator.pop(context);
                ScaffoldMessenger.of(context).showSnackBar(
                  const SnackBar(content: Text('Message copied to clipboard!')),
                );
              },
            ),
            ListTile(
              leading: const Icon(Icons.translate),
              title: const Text('Translate Message'),
              onTap: () {
                Navigator.pop(context);
                _showTranslationLanguageSelector(message);
              },
            ),
          ],
        );
      },
    );
  }


  void _showTranslationLanguageSelector(
      QueryDocumentSnapshot<Map<String, dynamic>> message) {
    showModalBottomSheet(
      context: context,
      builder: (BuildContext context) {
        return SingleChildScrollView(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              // Add a title here
              const Padding(
                padding: EdgeInsets.all(16.0),
                // Add some padding around the title
                child: Text(
                  'Select a Language to Translate', // The title text
                  style: TextStyle(
                    fontSize: 18, // Adjust font size as needed
                    fontWeight: FontWeight.bold, // Make it bold for emphasis
                  ),
                ),
              ),
              // Language options
              ...TranslationService.ghanaianLanguages.entries.map((entry) {
                return ListTile(
                  title: Text(entry.value),
                  onTap: () {
                    Navigator.pop(context); // Close the language selection
                    _translateAndShowResult(message['content'], entry.key);
                  },
                );
              }),
            ],
          ),
        );
      },
    );
  }

  Future<void> _translateAndShowResult(String text,
      String languageCode) async {
    try {
      print('Translating: "$text" to "$languageCode"');
      final translatedText = await TranslationService.translateText(
        text: text,
        targetLanguage: languageCode,
      );
      print('Translation Success: $translatedText');

      // Declare the controller as a late variable
      late final ScaffoldFeatureController<SnackBar,
          SnackBarClosedReason> controller;

      // Create the SnackBar content
      final snackBar = SnackBar(
        backgroundColor: Colors.teal[800],
        content: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text('Translated: $translatedText',
              style: const TextStyle(fontSize: 18),),
            const SizedBox(height: 20),
            // Add spacing between text and buttons
            Row(
              children: [
                TextButton(
                  onPressed: () {
                    controller.close(); // Dismiss the SnackBar
                  },
                  child: const Text(
                    'Okay',
                    style: TextStyle(color: Colors.white, fontSize: 16),
                  ),
                ),
                const SizedBox(width: 25), // Add spacing between buttons
                TextButton(
                  onPressed: () {
                    Clipboard.setData(ClipboardData(text: translatedText));
                    ScaffoldMessenger.of(context).showSnackBar(
                      const SnackBar(content: Text('Translation copied!')),
                    );
                    controller.close(); // Dismiss the SnackBar
                  },
                  child: const Text(
                    'Copy',
                    style: TextStyle(color: Colors.white, fontSize: 16),
                  ),
                ),
              ],
            ),
          ],
        ),
        duration: const Duration(
            days: 365), // Keep the SnackBar open indefinitely
      );

      // Assign the controller after showing the SnackBar
      controller = ScaffoldMessenger.of(context).showSnackBar(snackBar);
    } catch (e) {
      print('Translation failed: $e');
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Translation failed: ${e.toString()}')),
      );
    }
  }


  Future _playAudio(String audioUrl) async {
    try {
      print('Attempting to play audio: $audioUrl');
      if (_currentlyPlayingUrl == audioUrl && _player.isPlaying) {
        print('Pausing current audio');
        await _player.pausePlayer();
        _playerSubscription?.cancel();
        setState(() {
          _audioPlaybackStates[audioUrl] = false;
        });
        return;
      }

      if (_currentlyPlayingUrl == audioUrl && !_player.isPlaying) {
        print('Resuming paused audio');
        await _player.resumePlayer();
        _startListeningToProgress(audioUrl);
        setState(() {
          _audioPlaybackStates[audioUrl] = true;
        });
        return;
      }

      // Stop any currently playing audio
      if (_player.isPlaying) {
        print('Stopping previous audio');
        await _player.stopPlayer();
        _playerSubscription?.cancel();
        if (_currentlyPlayingUrl != null) {
          setState(() {
            _audioPlaybackStates[_currentlyPlayingUrl!] = false;
            _audioPlaybackDurations[_currentlyPlayingUrl!] = Duration.zero;
          });
        }
      }

      print('Starting new audio playback');
      await _player.startPlayer(
        fromURI: audioUrl,
        codec: Codec.aacADTS,
        whenFinished: () {
          print('Audio playback finished');
          _onPlaybackComplete(audioUrl);
        },
      );

      // Start listening to progress
      _startListeningToProgress(audioUrl);

      setState(() {
        _currentlyPlayingUrl = audioUrl;
        _audioPlaybackStates[audioUrl] = true;
        _audioPlaybackDurations[audioUrl] =
            Duration.zero; // Reset playback position
      });
    } catch (e) {
      print('Error playing audio: $e');
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Failed to play audio: ${e.toString()}')),
      );
    }
  }

  void _startListeningToProgress(String audioUrl) {
    print('Starting progress listener for $audioUrl');
    _playerSubscription?.cancel(); // Cancel any existing subscription
    _playerSubscription = _player.onProgress?.listen(
          (event) {
        if (mounted) {
          setState(() {
            _audioPlaybackDurations[audioUrl] =
                event.position; // Update current position
            _audioTotalDurations[audioUrl] =
                event.duration; // Update total duration
          });
        }
      },
      onError: (error) {
        print('Progress stream error: $error');
      },
    );
  }

  void _onPlaybackComplete(String audioUrl) {
    print('Playback complete for $audioUrl');
    if (mounted) {
      setState(() {
        _audioPlaybackStates[audioUrl] = false;
        _audioPlaybackDurations[audioUrl] = Duration.zero;
        _currentlyPlayingUrl = null;
      });
    }
    _playerSubscription?.cancel();
  }

  Future<void> _startRecording() async {
    try {
      final status = await Permission.microphone.request();
      if (status.isGranted) {
        final dir = await getApplicationDocumentsDirectory();
        _audioPath = '${dir.path}/${DateTime
            .now()
            .millisecondsSinceEpoch}.aac';
        await _recorder.startRecorder(
            toFile: _audioPath, codec: Codec.aacADTS);

        setState(() {
          _isRecording = true;
          _recordingDuration = Duration.zero;
        });

        _recordingTimer = Timer.periodic(const Duration(seconds: 1), (timer) {
          setState(() {
            _recordingDuration += const Duration(seconds: 1);
          });
        });
      } else {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Microphone permission denied')),
        );
      }
    } catch (e) {
      print('Error starting recording: $e');
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Failed to start recording')),
      );
    }
  }

  Future<void> _stopRecordingAndUpload() async {
    if (_recorder.isRecording) {
      _recordingTimer?.cancel();
      await _recorder.stopRecorder();

      setState(() {
        _isRecording = false;
      });

      // Store the final duration before resetting
      final audioDuration = _recordingDuration;
      setState(() {
        _recordingDuration = Duration.zero;
      });

      if (_audioPath != null) {
        final file = File(_audioPath!);

        if (!await file.exists() || await file.length() == 0) {
          print('Error: Audio file is empty or missing');
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(content: Text('Audio file not found')),
          );
          return;
        }

        final fileName = 'audio_${const Uuid().v4()}.aac';
        final storagePath = 'chat_files/audio/$fileName';

        try {
          final storageRef = FirebaseStorage.instanceFor(
            bucket: 'nhap-6191e.appspot.com',
          ).ref().child(storagePath);

          final uploadTask = storageRef.putFile(
            file,
            SettableMetadata(contentType: 'audio/aac'),
          );

          await uploadTask;
          final fileUrl = await storageRef.getDownloadURL();

          // Add the audio message to Firestore with duration
          await _firestore
              .collection('ChatMessages')
              .doc(widget.chatId)
              .collection('messages')
              .add({
            'from_uid': widget.fromUid,
            'to_uid': widget.toUid,
            'timestamp': FieldValue.serverTimestamp(),
            'type': 'audio',
            'file_url': fileUrl,
            'audio_duration': audioDuration.inSeconds, // Store duration in seconds
            'status': 'sent',
          });

          // Update the last message in the chat thread
          await _firestore.collection('ChatMessages')
              .doc(widget.chatId)
              .update({
            'last_msg': '🎤 Voice Message (${_formatDuration(audioDuration)})',
            'last_time': FieldValue.serverTimestamp(),
          });

          // Clear and delete local file
          setState(() {
            _audioPath = null;
          });
          await file.delete();

          ScaffoldMessenger.of(context).showSnackBar(
              const SnackBar(content: Text('Voice recording sent!'),
              )
          );
        } catch (e) {
          print('Error uploading audio: $e');
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(content: Text('Failed to upload audio: ${e.toString()}')),
          );
        }
      }
    }
  }

  void _sendMessage() async {
    if (_messageController.text
        .trim()
        .isEmpty) return;

    if (_isUserBlocked) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('You have blocked this user')),
      );
      return;
    }

    // Check if you're blocked by the other user
    final isBlockedByOtherUser = await _checkIfBlockedByOtherUser();
    if (isBlockedByOtherUser) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('This user has blocked you')),
      );
      return;
    }

    String messageText = _messageController.text.trim();

    final canSend = await WordFilterService().canSendMessage(messageText, context);
    if (!canSend) return;

    final message = {
      'content': messageText,
      'from_uid': widget.fromUid,
      'to_uid': widget.toUid,
      'timestamp': FieldValue.serverTimestamp(),
      'type': 'text',
      'status': 'sent',
      'read': false,
    };

    // Store message in Firestore
    await _firestore
        .collection('ChatMessages')
        .doc(widget.chatId)
        .collection('messages')
        .add(message);

    // Update last message details
    await _firestore.collection('ChatMessages').doc(widget.chatId).update({
      'last_msg': messageText,
      'last_time': FieldValue.serverTimestamp(),
    });

    // Clear the message input
    _messageController.clear();

    // Process the message for health insights
    await _processMessageForHealthInsights(messageText, widget.fromUid);

    // Scroll to bottom after sending
    _scrollToBottom();
  }

  Future<bool> _checkIfBlockedByOtherUser() async {
    try {
      final blockDoc = await FirebaseFirestore.instance
          .collection('UserBlocks')
          .doc(widget.toUid)
          .collection('blockedUsers')
          .doc(widget.fromUid)
          .get();
      return blockDoc.exists;
    } catch (e) {
      print('Error checking if blocked by other user: $e');
      return false;
    }
  }

  void _showBannedWordWarning(List<String> bannedWords) {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Message Blocked'),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Text('Your message contains inappropriate language and cannot be sent.'),
            const SizedBox(height: 16),
            Text(
              'Banned words detected: ${bannedWords.join(', ')}',
              style: TextStyle(
                color: Colors.red[700],
                fontWeight: FontWeight.bold,
              ),
            ),
          ],
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('OK'),
          ),
        ],
      ),
    );
  }

  Future<void> _processMessageForHealthInsights(String messageText,
      String userId) async {
    // Fetch user's region from the Users collection
    DocumentSnapshot userDoc = await FirebaseFirestore.instance.collection(
        'Users').doc(userId).get();
    String userRegion = userDoc['Region'] ?? 'Unknown';

    // Define health categories and keywords
    final Map<String, List<String>> healthCategories = {
      'symptoms': [
        'fever', 'pain', 'cough', 'fatigue', 'headache', 'nausea',
        'dizziness', 'inflammation', 'rash', 'anxiety', 'malaria',
        'typhoid', 'cholera', 'diarrhea', 'vomiting'
      ],
      'conditions': [
        'diabetes', 'hypertension', 'asthma', 'arthritis', 'depression',
        'obesity', 'cancer', 'allergy', 'infection', 'insomnia',
        'sickle cell', 'tuberculosis', 'HIV', 'hepatitis', 'stroke'
      ],
      'treatments': [
        'medication',
        'therapy',
        'surgery',
        'exercise',
        'diet',
        'vaccination',
        'rehabilitation',
        'counseling',
        'prescription',
        'supplement',
        'traditional medicine',
        'herbs',
        'physiotherapy',
        'immunization',
        'antibiotics'
      ],
      'lifestyle': [
        'nutrition',
        'fitness',
        'sleep',
        'stress',
        'wellness',
        'meditation',
        'diet',
        'exercise',
        'hydration',
        'mindfulness',
        'traditional food',
        'local diet',
        'community',
        'family health',
        'work-life'
      ],
      'preventive': [
        'screening',
        'checkup',
        'vaccination',
        'prevention',
        'hygiene',
        'immunization',
        'monitoring',
        'assessment',
        'testing',
        'evaluation',
        'sanitation',
        'clean water',
        'mosquito nets',
        'hand washing',
        'nutrition'
      ],
    };

    // Convert message text to lowercase for case-insensitive matching
    String lowerCaseMessage = messageText.toLowerCase();

    // Identify matched categories
    Map<String, int> matchedCategories = {};
    healthCategories.forEach((category, keywords) {
      for (String keyword in keywords) {
        if (lowerCaseMessage.contains(keyword)) {
          matchedCategories[category] =
              (matchedCategories[category] ?? 0) + 1;
        }
      }
    });

    // Debugging output
    print("Matched Categories: $matchedCategories");

    // Update HealthInsights collection
    for (String category in matchedCategories.keys) {
      int count = matchedCategories[category]!;
      String messageType = 'private'; // Adjust based on the type of message

      // Query for an existing document with the same category, region, and messageType
      QuerySnapshot querySnapshot = await FirebaseFirestore.instance
          .collection('HealthInsights')
          .where('category', isEqualTo: category)
          .where('region', isEqualTo: userRegion)
          .where('messageType', isEqualTo: messageType)
          .limit(1) // Limit the query to one result
          .get();

      if (querySnapshot.docs.isNotEmpty) {
        // Document exists, increment the count field
        DocumentReference docRef = querySnapshot.docs.first.reference;
        await docRef.update({
          'count': FieldValue.increment(count),
        });
        print(
            "Updated existing document for category: $category, region: $userRegion, messageType: $messageType");
      } else {
        // Document does not exist, create a new one
        await FirebaseFirestore.instance.collection('HealthInsights').add({
          'category': category,
          'count': count,
          'region': userRegion,
          'messageType': messageType,
          'timestamp': FieldValue.serverTimestamp(),
        });
        print(
            "Created new document for category: $category, region: $userRegion, messageType: $messageType");
      }
    }

    print("Processed message for health insights: $matchedCategories");
  }


  String _formatDuration(Duration duration) {
    String twoDigits(int n) => n.toString().padLeft(2, '0');
    final minutes = twoDigits(duration.inMinutes.remainder(60));
    final seconds = twoDigits(duration.inSeconds.remainder(60));

    // For durations under 1 minute, just show seconds
    if (duration.inMinutes == 0) {
      return '$seconds sec';
    }
    return '$minutes:$seconds';
  }

  Widget _buildCallEvent(Map<String, dynamic> message) {
    final duration = Duration(seconds: message['duration'] ?? 0);
    final isInitiator = message['initiator'] == widget.fromUid;
    final status = message['status'] ?? 'ended';
    final callId = message['callId'];

    String callText;
    Color bubbleColor;
    IconData callIcon;

    if (status == 'ended') {
      callText = 'Video call ${isInitiator ? 'made' : 'received'}';
      bubbleColor = Colors.teal.withOpacity(0.1);
      callIcon = Icons.videocam;
    } else {
      callText = 'Video call ${isInitiator ? 'declined' : 'missed'}';
      bubbleColor = Colors.grey.withOpacity(0.1);
      callIcon = Icons.videocam_off;
    }

    return GestureDetector(
      onTap: () {
        _showCallDetailsDialog(context, callId, duration, status);
      },
      child: Center(
        child: Container(
          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
          margin: const EdgeInsets.symmetric(vertical: 4),
          decoration: BoxDecoration(
            color: bubbleColor,
            borderRadius: BorderRadius.circular(20),
          ),
          child: Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              Icon(callIcon, size: 16, color: Colors.grey),
              const SizedBox(width: 8),
              Text(
                '$callText • ${_formatDuration(duration)}',
                style: TextStyle(
                  fontSize: 12,
                  color: Colors.grey[700],
                ),
              ),
              if (status == 'ended') ...[
                const SizedBox(width: 8),
                const Icon(Icons.info_outline, size: 14, color: Colors.grey),
              ],
            ],
          ),
        ),
      ),
    );
  }

  void _showCallDetailsDialog(BuildContext context, String callId, Duration duration, String status) {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: Text(status == 'ended' ? 'Call Details' : 'Missed Call'),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text('Duration: ${_formatDuration(duration)}'),
            if (status == 'ended') const SizedBox(height: 8),
            if (status == 'ended') Text('Call ID: ${callId.substring(0, 8)}...'),
          ],
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('Close'),
          ),
        ],
      ),
    );
  }

  Future<void> _showBlockUserDialog() async {
    final currentUserId = FirebaseAuth.instance.currentUser?.uid;
    if (currentUserId == null) return;

    final shouldBlock = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: Text(_isUserBlocked ? 'Unblock User' : 'Block User'),
        content: Text(
          _isUserBlocked
              ? 'Are you sure you want to unblock ${widget.toName}?'
              : 'Are you sure you want to block ${widget.toName}? They will no longer be able to message or call you.',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            child: const Text('Cancel'),
          ),
          TextButton(
            onPressed: () => Navigator.pop(context, true),
            child: Text(_isUserBlocked ? 'Unblock' : 'Block'),
            style: TextButton.styleFrom(
              foregroundColor: _isUserBlocked ? Colors.green : Colors.red,
            ),
          ),
        ],
      ),
    ) ?? false;

    if (shouldBlock) {
      await _toggleBlockUser(!_isUserBlocked);
    }
  }

  Future<void> _toggleBlockUser(bool block) async {
    final currentUserId = FirebaseAuth.instance.currentUser?.uid;
    if (currentUserId == null) return;

    try {
      final blockRef = FirebaseFirestore.instance
          .collection('UserBlocks')
          .doc(currentUserId)
          .collection('blockedUsers')
          .doc(widget.toUid);

      if (block) {
        await blockRef.set({
          'blockedAt': FieldValue.serverTimestamp(),
          'blockedUserId': widget.toUid,
          'blockedUserName': widget.toName,
        });
      } else {
        await blockRef.delete();
      }

      setState(() {
        _isUserBlocked = block;
      });

      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(
            block
                ? '${widget.toName} has been blocked'
                : '${widget.toName} has been unblocked',
          ),
        ),
      );
    } catch (e) {
      print('Error toggling block status: $e');
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Failed to update block status')),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        leadingWidth: 30,
        title: _isLoadingUserData
            ? Row(
          children: [
            const CircleAvatar(
              radius: 20,
              child: Icon(Icons.person, size: 24),
            ),
            const SizedBox(width: 8),
            Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  widget.toName,
                  style: const TextStyle(
                    fontSize: 18,
                    fontWeight: FontWeight.bold,
                  ),
                ),
                const Text(
                  "Loading...",
                  style: TextStyle(
                    fontSize: 13,
                    color: Colors.black,
                  ),
                ),
              ],
            ),
          ],
        )
            : Row(
          children: [
            CircleAvatar(
              radius: 20,
              backgroundImage: _cachedUserPic != null
                  ? NetworkImage(_cachedUserPic!)
                  : null,
              child: _cachedUserPic == null
                  ? const Icon(Icons.person, size: 24)
                  : null,
            ),
            const SizedBox(width: 8),
            Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  widget.toName,
                  style: const TextStyle(
                    fontSize: 18,
                    fontWeight: FontWeight.bold,
                  ),
                ),
                /*Text(
                      _cachedIsOnline == true ? "Active now" : "Offline",
                      style: const TextStyle(
                        fontSize: 13,
                        color: Colors.black,
                      ),
                    ),*/
              ],
            ),
          ],
        ),
        backgroundColor: Colors.teal,
        actions: [
          IconButton(
            icon: const Icon(Icons.block, color: Colors.white),
            onPressed: () => _showBlockUserDialog(),
          ),
          IconButton(
            icon: const Icon(Icons.video_call, color: Colors.white),
            onPressed: _onVideoCallPressed,
          ),
        ],
      ),

      body: Container(
        decoration: BoxDecoration(
          gradient: LinearGradient(
            begin: Alignment.topLeft,
            end: Alignment.bottomRight,
            colors: [Colors.teal[50]!, Colors.grey[100]!], // Consistent background
          ),
        ),
        child: Column(
          children: [
            Expanded(
              child: Stack(
                children: [
                  StreamBuilder<QuerySnapshot<Map<String, dynamic>>>(
                    stream: _firestore
                        .collection('ChatMessages')
                        .doc(widget.chatId)
                        .collection('messages')
                        .orderBy('timestamp')
                        .snapshots(),
                    builder: (context, snapshot) {
                      if (snapshot.hasError) {
                        return Center(child: Text('Error: ${snapshot
                            .error}'));
                      }
                      if (!snapshot.hasData) {
                        return const Center(
                            child: CircularProgressIndicator());
                      }

                      final messages = snapshot.data!.docs;

                      // Detect new messages when already scrolled up
                      if (_scrollController.hasClients &&
                          _scrollController.position.pixels <
                              _scrollController.position.maxScrollExtent - 100) {
                        WidgetsBinding.instance.addPostFrameCallback((_) {
                          setState(() {
                            _newMessagesCount = messages.length -
                                (_scrollController.position.pixels /
                                    (_scrollController.position.maxScrollExtent / messages.length)).floor();
                          });
                        });
                      }

                      return ListView.builder(
                        controller: _scrollController,
                        // Attach the ScrollController
                        itemCount: messages.length,
                        itemBuilder: (context, index) {
                          final message = messages[index];
                          // Handle call events differently
                          if (message['type'] == 'call') {
                            return _buildCallEvent(message.data());
                          }
                          final isSentByUser = message['from_uid'] ==
                              widget.fromUid;

                          return GestureDetector(
                            onLongPress: () => _showMessageMenu(message),
                            child: Align(
                              alignment: isSentByUser
                                  ? Alignment.centerRight
                                  : Alignment.centerLeft,
                              child: ConstrainedBox(
                                constraints: BoxConstraints(
                                  maxWidth: MediaQuery
                                      .of(context)
                                      .size
                                      .width *
                                      0.7, // Max width for text bubbles
                                ),
                                child: CustomPaint(
                                  size: const Size(
                                      double.infinity, double.infinity),
                                  painter: ChatBubblePainter(
                                      isSentByUser: isSentByUser),
                                  child: Padding(
                                    padding: const EdgeInsets.all(12.0),
                                    child: Column(
                                      crossAxisAlignment: CrossAxisAlignment
                                          .start,
                                      children: [
                                        if (message['type'] == 'text') ...[
                                          Text(
                                            message['content'] ?? '',
                                            // Fallback to an empty string if 'content' is null
                                            softWrap: true,
                                            // Allow text to wrap to the next line
                                            style: TextStyle(
                                              fontWeight: FontWeight.w400,
                                              // Make the text bold
                                              fontSize: 15,
                                              // Optional: Set a font size for better readability
                                              color: isSentByUser ? Colors
                                                  .black87 : Colors
                                                  .black87, // Optional: Adjust text color based on sender
                                            ),
                                          ),
                                        ] else
                                          if (message['type'] == 'audio') ...[
                                            _buildAudioMessage(
                                                message.data()),
                                          ],
                                        const SizedBox(height: 5),
                                        Align(
                                          alignment: Alignment.bottomRight,
                                          child: Text(
                                            message['timestamp'] != null
                                                ? DateFormat.jm().format(
                                              (message['timestamp'] as Timestamp)
                                                  .toDate(),
                                            )
                                                : 'Sending...',
                                            style: TextStyle(
                                              fontSize: 10,
                                              color: Colors
                                                  .grey[800], // Deep grey color to match the send icon
                                            ),
                                          ),
                                        ),
                                      ],
                                    ),
                                  ),
                                ),
                              ),
                            ),
                          );
                        },
                      );
                    },
                  ),
                  // Show the FAB if the user has scrolled up
                  if (_showScrollToBottomButton)
                    Positioned(
                      bottom: 16,
                      right: 16,
                      child: FloatingActionButton(
                        onPressed: _scrollToBottom,
                        mini: true,
                        backgroundColor: Colors.teal,
                        child: const Icon(Icons.arrow_downward),
                      ),
                    ),

                ],
              ),
            ),
            Padding(
              padding: const EdgeInsets.all(8.0),
              child: Row(
                children: [
                  if (_isRecording) ...[
                    IconButton(
                      icon: const Icon(Icons.cancel, color: Colors.red),
                      onPressed: () {
                        setState(() {
                          _isRecording = false;
                          _recordingDuration = Duration.zero;
                        });
                        _recordingTimer?.cancel();
                        _recorder.stopRecorder();
                      },
                    ),
                    Expanded(
                      child: Column(
                        children: [
                          LinearProgressIndicator(
                            value: _recordingDuration.inSeconds / 60,
                            // Max 60 seconds
                            backgroundColor: Colors.grey[300],
                            valueColor: const AlwaysStoppedAnimation<Color>(
                                Colors.teal),
                          ),
                          Text(
                            'Recording: ${_recordingDuration.inSeconds}s',
                            style: const TextStyle(color: Colors.red),
                          ),
                        ],
                      ),
                    ),
                    Container(
                      width: 36, // Adjust the width of the container
                      height: 36, // Adjust the height of the container
                      margin: const EdgeInsets.all(4), // Adjust margin to fit the smaller size
                      decoration: BoxDecoration(
                        color: Colors.teal, // teal background color
                        shape: BoxShape.circle, // Make it circular
                      ),
                      child: IconButton(
                        iconSize: 20, // Adjust the size of the icon
                        icon: const Icon(Icons.send, color: Colors.white), // White icon for contrast
                        onPressed: _stopRecordingAndUpload, // Your existing onPressed function
                      ),
                    ),
                  ] else
                    ...[
                      GestureDetector(
                        onTap: _startRecording,
                        child: const Icon(
                          Icons.mic,
                          color: Colors.teal,
                        ),
                      ),
                      const SizedBox(width: 8),
                      // Add space between microphone and text box
                      Expanded(
                        child: Container(
                          decoration: BoxDecoration(
                            color: Colors.white,
                            borderRadius: BorderRadius.circular(
                                30), // Oval shape
                          ),
                          constraints: const BoxConstraints(
                            maxHeight: 120, // Maximum height for the text box
                          ),
                          child: SingleChildScrollView(
                            // Enable scrolling for multi-line text
                            child: TextField(
                              controller: _messageController,
                              decoration: const InputDecoration(
                                hintText: 'Type a message...',
                                border: InputBorder.none,
                                // Remove default border
                                contentPadding: EdgeInsets.symmetric(
                                    horizontal: 16, vertical: 12),
                              ),
                              maxLines: null, // Allow multiple lines
                              keyboardType: TextInputType
                                  .multiline, // Enable multi-line input
                            ),
                          ),
                        ),
                      ),
                      const SizedBox(width: 8),
                      // Add space between text box and send button
                      Container(
                        width: 36, // Adjust the width of the container
                        height: 36, // Adjust the height of the container
                        margin: const EdgeInsets.all(4), // Adjust margin to fit the smaller size
                        decoration: BoxDecoration(
                          color: Colors.teal, // teal background color
                          shape: BoxShape.circle, // Make it circular
                        ),
                        child: IconButton(
                          iconSize: 20, // Adjust the size of the icon
                          icon: const Icon(Icons.send, color: Colors.white), // White icon for contrast
                          onPressed: _sendMessage, // Your existing onPressed function
                        ),
                      ),
                    ],
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildAudioMessage(Map message) {
    final audioUrl = message['file_url'] as String;
    final isPlaying = _currentlyPlayingUrl == audioUrl && _player.isPlaying;
    final durationInSeconds = message['audio_duration'] as int? ?? 0;
    final duration = Duration(seconds: durationInSeconds);

    return GestureDetector(
      onTap: () => _playAudio(audioUrl),
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
        decoration: BoxDecoration(
          color: Colors.teal.withOpacity(0.1),
          borderRadius: BorderRadius.circular(16),
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // Add the instruction text
            Text(
              'Tap to play audio message',
              style: TextStyle(
                fontSize: 12,
                color: Colors.grey[700],
                fontStyle: FontStyle.italic,
              ),
            ),
            const SizedBox(height: 4),
            Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                // Play/Pause Button
                Container(
                  padding: const EdgeInsets.all(8),
                  decoration: BoxDecoration(
                    color: Colors.teal,
                    borderRadius: BorderRadius.circular(8),
                  ),
                  child: Icon(
                    isPlaying ? Icons.pause : Icons.play_arrow,
                    color: Colors.white,
                    size: 16,
                  ),
                ),

                const SizedBox(width: 8),

                // Duration display
                Text(
                  _formatDuration(duration),
                  style: TextStyle(
                    fontSize: 14,
                    color: Colors.black87,
                    fontWeight: FontWeight.w500,
                  ),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }
}

class ChatBubblePainter extends CustomPainter {
  final bool isSentByUser; // Determines if the message is sent or received
  final double internalPadding; // Internal padding for the chat bubble

  ChatBubblePainter({
    required this.isSentByUser,
    this.internalPadding = 3.0, // Default padding
  });

  @override
  void paint(Canvas canvas, Size size) {
    final Paint bubblePaint = Paint()
      ..color = isSentByUser ? Colors.teal[500]! : Colors.grey[200]!
      ..style = PaintingStyle.fill;

    final Paint shadowPaint = Paint()
      ..color = Colors.black.withOpacity(0.1)
      ..maskFilter = const MaskFilter.blur(BlurStyle.normal, 6);

    const radius = 20.0;

    // Adjust the rectangle size to account for internal padding
    final rect = Rect.fromLTWH(
      internalPadding,
      internalPadding,
      size.width - (internalPadding * 2),
      size.height - (internalPadding * 2),
    );

    final path = Path();

    // Draw the main body of the chat bubble with rounded corners
    path.addRRect(
      RRect.fromRectAndCorners(
        rect,
        topLeft: Radius.circular(isSentByUser ? radius : 0),
        topRight: Radius.circular(isSentByUser ? 0 : radius),
        bottomLeft: const Radius.circular(radius),
        bottomRight: const Radius.circular(radius),
      ),
    );

    // Draw the shadow first
    canvas.drawPath(path, shadowPaint);

    // Draw the chat bubble
    canvas.drawPath(path, bubblePaint);
  }

  @override
  bool shouldRepaint(CustomPainter oldDelegate) => false;
}

class VideoCallScreen extends StatefulWidget {
  final String callId;
  final String remoteName;
  final String remoteUid;
  final String chatId;  // Add this line
  final bool isIncoming;
  final Map<String, dynamic>? offerSdp;

  const VideoCallScreen({
    super.key,
    required this.callId,
    required this.remoteName,
    required this.remoteUid,
    required this.chatId,  // Add this parameter
    required this.isIncoming,
    this.offerSdp,
  });

  @override
  _VideoCallScreenState createState() => _VideoCallScreenState();
}

class _VideoCallScreenState extends State<VideoCallScreen> {
  final RTCVideoRenderer _localRenderer = RTCVideoRenderer();
  final RTCVideoRenderer _remoteRenderer = RTCVideoRenderer();
  MediaStream? _localStream;
  RTCPeerConnection? _peerConnection;
  bool _isMicMuted = false;
  bool _isCameraOff = false;
  bool _isSpeakerOn = true;
  bool _isConnected = false;
  bool _isRemoteVideoReceived = false; // Added flag to track remote video
  Timer? _callTimer;
  Duration _callDuration = Duration.zero;
  StreamSubscription? _callSubscription;
  final FirebaseFirestore _firestore = FirebaseFirestore.instance;
  String remoteUserFullName = '';

  @override
  void initState() {
    super.initState();
    _initRenderers();
    _setupCall();

    // If this is an incoming call, fetch the caller's full name
    if (widget.isIncoming) {
      _fetchRemoteUserName();
    } else {
      // For outgoing calls, use the name we already have
      remoteUserFullName = widget.remoteName;
    }
  }

  Future<void> _fetchRemoteUserName() async {
    try {
      final userDoc = await FirebaseFirestore.instance
          .collection('Users')
          .doc(widget.remoteUid)
          .get();

      if (userDoc.exists) {
        final fname = userDoc.data()?['Fname'] ?? '';
        final lname = userDoc.data()?['Lname'] ?? '';
        final fullName = '$fname $lname'.trim();

        setState(() {
          remoteUserFullName = fullName.isNotEmpty ? fullName : widget.remoteName;
        });
      }
    } catch (e) {
      print('Error fetching remote user name: $e');
    }
  }

  Future<void> _initRenderers() async {
    await _localRenderer.initialize();
    await _remoteRenderer.initialize();
  }

  Future<void> _setupCall() async {
    // Create peer connection
    _peerConnection = await _createPeerConnection();

    // Get user media
    final mediaConstraints = {
      'audio': true,
      'video': {
        'facingMode': 'user',
        'width': {'ideal': 1280},
        'height': {'ideal': 720}
      }
    };

    try {
      _localStream = await navigator.mediaDevices.getUserMedia(mediaConstraints);
      _localRenderer.srcObject = _localStream;

      // Add tracks to peer connection
      _localStream!.getTracks().forEach((track) {
        _peerConnection!.addTrack(track, _localStream!);
      });

      // Listen for remote streams (not just tracks)
      _peerConnection!.onAddStream = (MediaStream stream) {
        print('Remote stream added: ${stream.id}');
        _remoteRenderer.srcObject = stream;
        setState(() {
          _isConnected = true;
          _isRemoteVideoReceived = true;
        });
        _startCallTimer();
      };

      // Also keep the onTrack handler as a fallback
      _peerConnection!.onTrack = (RTCTrackEvent event) {
        print('Remote track added: ${event.track.kind}');
        if (event.streams.isNotEmpty) {
          _remoteRenderer.srcObject = event.streams[0];
          setState(() {
            _isConnected = true;
            _isRemoteVideoReceived = true;
          });
          _startCallTimer();
        }
      };

      // Setup call based on whether it's incoming or outgoing
      if (widget.isIncoming) {
        await _handleIncomingCall();
      } else {
        await _initOutgoingCall();
      }

      // Listen for call status changes
      _listenForCallUpdates();
    } catch (e) {
      print('Error setting up call: $e');
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Failed to access camera/microphone: $e')),
      );
      Navigator.pop(context);
    }
  }

  Future<RTCPeerConnection> _createPeerConnection() async {
    final config = {
      'iceServers': [
        {'urls': 'stun:stun.l.google.com:19302'},
        {'urls': 'stun:stun1.l.google.com:19302'},
        {'urls': 'stun:stun2.l.google.com:19302'},
        {
          'urls': 'turn:numb.viagenie.ca',
          'username': 'webrtc@live.com',
          'credential': 'muazkh'
        }
      ],
      'sdpSemantics': 'unified-plan' // Explicitly use unified plan for compatibility
    };

    final constraints = {
      'mandatory': {
        'OfferToReceiveAudio': true,
        'OfferToReceiveVideo': true,
      },
      'optional': [
        {'DtlsSrtpKeyAgreement': true},
      ],
    };

    final pc = await createPeerConnection(config, constraints);

    // Setup ICE handling
    pc.onIceCandidate = (candidate) {
      if (candidate.candidate != null) {
        _addIceCandidate(candidate);
      }
    };

    pc.onIceConnectionState = (state) {
      print('ICE connection state: $state');
      if (state == RTCIceConnectionState.RTCIceConnectionStateConnected) {
        print("ICE Connection Established!");
      } else if (state == RTCIceConnectionState.RTCIceConnectionStateFailed) {
        print("ICE Connection Failed!");
      }
    };

    pc.onConnectionState = (state) {
      print('Connection state: $state');
      if (state == RTCPeerConnectionState.RTCPeerConnectionStateConnected) {
        setState(() {
          _isConnected = true;
        });
      } else if (state == RTCPeerConnectionState.RTCPeerConnectionStateFailed ||
          state == RTCPeerConnectionState.RTCPeerConnectionStateDisconnected ||
          state == RTCPeerConnectionState.RTCPeerConnectionStateClosed) {
        setState(() {
          _isConnected = false;
          _isRemoteVideoReceived = false; // Reset video flag on disconnection
        });
      }
    };

    return pc;
  }

  Future<void> _initOutgoingCall() async {
    // Create offer with explicit constraints
    final offerConstraints = {
      'offerToReceiveAudio': true,
      'offerToReceiveVideo': true,
    };

    final offer = await _peerConnection!.createOffer(offerConstraints);
    print('Created offer: ${offer.sdp}');

    await _peerConnection!.setLocalDescription(offer);
    print('Set local description');

    // Store the offer in Firestore
    await _firestore.collection('calls').doc(widget.callId).set({
      'callId': widget.callId,
      'callerUid': FirebaseAuth.instance.currentUser!.uid,
      'receiverUid': widget.remoteUid,
      'offer': offer.toMap(),
      'status': 'pending',
      'timestamp': FieldValue.serverTimestamp(),
    });
    print('Stored offer in Firestore');

    // Also notify the user by adding a document to their notifications collection
    await _firestore.collection('Users').doc(widget.remoteUid).collection('callNotifications').doc(widget.callId).set({
      'callId': widget.callId,
      'callerUid': FirebaseAuth.instance.currentUser!.uid,
      'callerName': await _getCurrentUserName(),
      'timestamp': FieldValue.serverTimestamp(),
      'type': 'video',
    });
    print('Added call notification');
  }

  Future<void> _handleIncomingCall() async {
    if (widget.offerSdp != null) {
      print('Received offer SDP: ${widget.offerSdp}');
      final offer = RTCSessionDescription(
        widget.offerSdp!['sdp'],
        widget.offerSdp!['type'],
      );

      await _peerConnection!.setRemoteDescription(offer);
      print('Set remote description from offer');

      // Create answer with explicit constraints
      final answerConstraints = {
        'offerToReceiveAudio': true,
        'offerToReceiveVideo': true,
      };

      final answer = await _peerConnection!.createAnswer(answerConstraints);
      print('Created answer: ${answer.sdp}');

      await _peerConnection!.setLocalDescription(answer);
      print('Set local description for answer');

      // Send answer back
      await _firestore.collection('calls').doc(widget.callId).update({
        'answer': answer.toMap(),
        'status': 'accepted',
      });
      print('Sent answer to Firestore');
    }
  }

  void _listenForCallUpdates() {
    _callSubscription = _firestore.collection('calls').doc(widget.callId).snapshots().listen((snapshot) async {
      try {
        if (!mounted) return;

        if (!snapshot.exists) {
          print('Call document deleted, ending call');
          _endCall();
          return;
        }

        final data = snapshot.data() as Map<String, dynamic>? ?? {};
        if (data.isEmpty) {
          print('Received empty or invalid call data');
          return;
        }

        // Handle call status changes
        if (data['status'] == 'accepted' && !widget.isIncoming && data.containsKey('answer')) {
          try {
            // Verify answer data is valid before using it
            final answerData = data['answer'];
            if (answerData != null &&
                answerData['sdp'] != null &&
                answerData['type'] != null &&
                _peerConnection != null) {

              print('Received answer from Firestore: ${data['answer']}');
              final answer = RTCSessionDescription(
                answerData['sdp'],
                answerData['type'],
              );
              await _peerConnection!.setRemoteDescription(answer);
              print('Set remote description from answer');
            }
          } catch (e) {
            print('Error setting remote description: $e');
          }
        } else if (data['status'] == 'rejected' || data['status'] == 'ended') {
          print('Call ${data['status']} by remote user');

          // Use delayed execution to avoid concurrent navigation issues
          Future.delayed(Duration.zero, () {
            _endCall();
          });
        }

        // Process ICE candidates only if peer connection exists
        if (_peerConnection != null && data.containsKey('candidates')) {
          try {
            // Make sure candidates is not null
            final candidatesList = data['candidates'];
            if (candidatesList != null) {
              for (var candidateData in candidatesList) {
                if (candidateData != null &&
                    candidateData['isProcessed'] == false &&
                    candidateData['candidate'] != null) {

                  print('Processing ICE candidate: ${candidateData['candidate']}');

                  try {
                    final candidate = RTCIceCandidate(
                      candidateData['candidate'],
                      candidateData['sdpMid'],
                      candidateData['sdpMLineIndex'],
                    );

                    if (_peerConnection != null) {
                      await _peerConnection!.addCandidate(candidate);
                      print('Added ICE candidate');

                      // Mark as processed using a transaction
                      try {
                        await FirebaseFirestore.instance.runTransaction((transaction) async {
                          final callDoc = await _firestore.collection('calls').doc(widget.callId).get();
                          if (!callDoc.exists) return;

                          final callData = callDoc.data();
                          if (callData == null || !callData.containsKey('candidates')) return;

                          final updatedCandidates = List<Map<String, dynamic>>.from(callData['candidates']);
                          updatedCandidates.removeWhere((c) =>
                          c['candidate'] == candidateData['candidate'] &&
                              c['sdpMid'] == candidateData['sdpMid'] &&
                              c['sdpMLineIndex'] == candidateData['sdpMLineIndex']
                          );
                          updatedCandidates.add({...candidateData, 'isProcessed': true});

                          transaction.update(callDoc.reference, {'candidates': updatedCandidates});
                        });
                      } catch (e) {
                        print('Error updating candidate status: $e');
                      }
                    }
                  } catch (e) {
                    print('Error adding ICE candidate: $e');
                  }
                }
              }
            }
          } catch (e) {
            print('Error processing candidates: $e');
          }
        }
      } catch (e) {
        print('Error in call update listener: $e');
      }
    }, onError: (error) {
      print('Error in call update listener: $error');
    });
  }

  Future<void> _addIceCandidate(RTCIceCandidate candidate) async {
    print('Adding ICE candidate: ${candidate.candidate}');
    await _firestore.collection('calls').doc(widget.callId).update({
      'candidates': FieldValue.arrayUnion([{
        'candidate': candidate.candidate,
        'sdpMid': candidate.sdpMid,
        'sdpMLineIndex': candidate.sdpMLineIndex,
        'isProcessed': false,
      }]),
    });
    print('Added ICE candidate to Firestore');
  }

  void _startCallTimer() {
    _callTimer = Timer.periodic(const Duration(seconds: 1), (timer) {
      if (mounted) {
        // Only update the state if the widget is still mounted
        setState(() {
          _callDuration = Duration(seconds: timer.tick);
        });
      } else {
        // If the widget is not mounted, cancel the timer to avoid memory leaks
        _callTimer?.cancel();
      }
    });
  }

  Future<String> _getCurrentUserName() async {
    final userId = FirebaseAuth.instance.currentUser!.uid;
    final userDoc = await FirebaseFirestore.instance.collection('Users').doc(userId).get();

    final fname = userDoc.data()?['Fname'] ?? '';
    final lname = userDoc.data()?['Lname'] ?? '';
    final fullName = '$fname $lname'.trim();

    return fullName.isNotEmpty ? fullName : 'Unknown User';
  }

  void _toggleMicrophone() {
    if (_localStream != null) {
      final audioTrack = _localStream!.getAudioTracks()[0];
      setState(() {
        _isMicMuted = !_isMicMuted;
        audioTrack.enabled = !_isMicMuted;
      });
    }
  }

  void _toggleCamera() {
    if (_localStream != null) {
      final videoTrack = _localStream!.getVideoTracks()[0];
      setState(() {
        _isCameraOff = !_isCameraOff;
        videoTrack.enabled = !_isCameraOff;
      });
    }
  }

  void _toggleSpeaker() {
    // This would need platform-specific implementation
    // but for now we'll just update the UI state
    setState(() {
      _isSpeakerOn = !_isSpeakerOn;
    });
  }

  void _switchCamera() async {
    if (_localStream != null) {
      final videoTrack = _localStream!.getVideoTracks()[0];
      await Helper.switchCamera(videoTrack);
    }
  }

  Future<void> _endCall() async {
    try {
      // Add call history before cleaning up
      if (_isConnected && mounted) {
        await _firestore
            .collection('ChatMessages')
            .doc(widget.chatId)
            .collection('messages')
            .add({
          'type': 'call',
          'callId': widget.callId,
          'duration': _callDuration.inSeconds,
          'timestamp': FieldValue.serverTimestamp(),
          'status': 'ended',
          'initiator': FirebaseAuth.instance.currentUser!.uid,
        });
      }

      // Clean up resources
      _cleanupResources();

      // Update call status if still mounted
      if (mounted) {
        await _updateCallStatus();
        _navigateBack();
      }
    } catch (e) {
      debugPrint('Error in _endCall: $e');
      if (mounted) {
        _navigateBack(); // Ensure we always navigate back even on error
      }
    }
  }

  void _cleanupResources() {
    // Cancel timers and subscriptions
    _callTimer?.cancel();
    _callSubscription?.cancel();
    _callTimer = null;
    _callSubscription = null;

    // Stop and clean media tracks
    _localStream?.getTracks().forEach((track) => track.stop());
    _localStream = null;

    // Clean up renderers
    _localRenderer.srcObject = null;
    _remoteRenderer.srcObject = null;

    // Close peer connection
    _peerConnection?.close();
    _peerConnection = null;
  }

  Future<void> _updateCallStatus() async {
    try {
      await _firestore.collection('calls').doc(widget.callId).update({
        'status': 'ended',
        'endedAt': FieldValue.serverTimestamp(),
      });
    } catch (e) {
      debugPrint('Error updating call status: $e');
    }
  }

  void _navigateBack() {
    // Use postFrameCallback to ensure safe navigation
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (mounted) {
        final nav = Navigator.of(context);
        final previousRoute = NavigationManager().previousRoute;

        if (previousRoute != null && nav.canPop()) {
          nav.popUntil(ModalRoute.withName(previousRoute));
        } else if (nav.canPop()) {
          nav.pop();
        }
      }
    });
  }

  @override
  void dispose() {
    print('Disposing VideoCallScreen');
    _callTimer?.cancel();

    // First cancel the subscription to avoid callbacks during cleanup
    _callSubscription?.cancel();

    // Then clean up media resources
    if (_localStream != null) {
      try {
        _localStream!.getTracks().forEach((track) {
          try {
            track.stop();
          } catch (e) {
            print('Error stopping track: $e');
          }
        });
      } catch (e) {
        print('Error cleaning up local stream: $e');
      }
    }

    // Clean up renderers
    try {
      if (_localRenderer.srcObject != null) _localRenderer.srcObject = null;
      if (_remoteRenderer.srcObject != null) _remoteRenderer.srcObject = null;
      _localRenderer.dispose();
      _remoteRenderer.dispose();
    } catch (e) {
      print('Error disposing renderers: $e');
    }

    // Finally close the peer connection
    try {
      _peerConnection?.close();
      _peerConnection = null;
    } catch (e) {
      print('Error closing peer connection: $e');
    }

    super.dispose();
  }

  String _formatDuration(Duration duration) {
    String twoDigits(int n) => n.toString().padLeft(2, '0');
    final minutes = twoDigits(duration.inMinutes.remainder(60));
    final seconds = twoDigits(duration.inSeconds.remainder(60));

    // For durations under 1 minute, just show seconds
    if (duration.inMinutes == 0) {
      return '$seconds sec';
    }
    return '$minutes:$seconds';
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.black,
      body: SafeArea(
        child: Stack(
          children: [
            // Remote video (full screen)
            _isConnected && _isRemoteVideoReceived
                ? RTCVideoView(
              _remoteRenderer,
              objectFit: RTCVideoViewObjectFit.RTCVideoViewObjectFitCover,
            )
                : Center(
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  const CircularProgressIndicator(color: Colors.white),
                  const SizedBox(height: 16),
                  Text(
                    _isConnected
                        ? "Connected but waiting for video..."
                        : widget.isIncoming
                        ? 'Connecting...'
                        : 'Calling ${widget.remoteName}...',
                    style: const TextStyle(color: Colors.white, fontSize: 18),
                  ),
                ],
              ),
            ),

            // Local video (picture-in-picture)
            Positioned(
              top: 16,
              right: 16,
              child: Container(
                width: 100,
                height: 150,
                decoration: BoxDecoration(
                  border: Border.all(color: Colors.white, width: 2),
                  borderRadius: BorderRadius.circular(8),
                ),
                child: ClipRRect(
                  borderRadius: BorderRadius.circular(6),
                  child: _isCameraOff
                      ? Container(
                    color: Colors.grey[900],
                    child: const Center(
                      child: Icon(Icons.videocam_off, color: Colors.white),
                    ),
                  )
                      : RTCVideoView(
                    _localRenderer,
                    mirror: true,
                    objectFit: RTCVideoViewObjectFit.RTCVideoViewObjectFitCover,
                  ),
                ),
              ),
            ),

            // Debug info overlay
            Positioned(
              top: 60,
              left: 16,
              child: Container(
                padding: const EdgeInsets.all(8),
                decoration: BoxDecoration(
                  color: Colors.black.withOpacity(0.6),
                  borderRadius: BorderRadius.circular(8),
                ),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      'Connection: ${_isConnected ? "Yes" : "No"}',
                      style: const TextStyle(color: Colors.white70, fontSize: 12),
                    ),
                    Text(
                      'Video: ${_isRemoteVideoReceived ? "Yes" : "No"}',
                      style: const TextStyle(color: Colors.white70, fontSize: 12),
                    ),
                  ],
                ),
              ),
            ),

            // Call info at the top
            Positioned(
              top: 16,
              left: 16,
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    remoteUserFullName.isNotEmpty ? remoteUserFullName : widget.remoteName,
                    style: const TextStyle(
                      color: Colors.white,
                      fontSize: 20,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                  const SizedBox(height: 4),
                  Text(
                    _isConnected ? _formatDuration(_callDuration) : 'Connecting...',
                    style: TextStyle(
                      color: Colors.white.withOpacity(0.8),
                      fontSize: 16,
                    ),
                  ),
                ],
              ),
            ),

            // Call controls at the bottom
            Positioned(
              bottom: 24,
              left: 0,
              right: 0,
              child: Container(
                padding: const EdgeInsets.symmetric(vertical: 16),
                child: Row(
                  mainAxisAlignment: MainAxisAlignment.spaceEvenly,
                  children: [
                    // Mute/Unmute
                    CircleAvatar(
                      radius: 28,
                      backgroundColor: _isMicMuted ? Colors.red : Colors.white.withOpacity(0.3),
                      child: IconButton(
                        icon: Icon(
                          _isMicMuted ? Icons.mic_off : Icons.mic,
                          color: Colors.white,
                        ),
                        onPressed: _toggleMicrophone,
                      ),
                    ),

                    // Camera on/off
                    CircleAvatar(
                      radius: 28,
                      backgroundColor: _isCameraOff ? Colors.red : Colors.white.withOpacity(0.3),
                      child: IconButton(
                        icon: Icon(
                          _isCameraOff ? Icons.videocam_off : Icons.videocam,
                          color: Colors.white,
                        ),
                        onPressed: _toggleCamera,
                      ),
                    ),

                    // Speaker on/off
                    CircleAvatar(
                      radius: 28,
                      backgroundColor: Colors.white.withOpacity(0.3),
                      child: IconButton(
                        icon: Icon(
                          _isSpeakerOn ? Icons.volume_up : Icons.volume_off,
                          color: Colors.white,
                        ),
                        onPressed: _toggleSpeaker,
                      ),
                    ),

                    // Switch camera (front/back)
                    CircleAvatar(
                      radius: 28,
                      backgroundColor: Colors.white.withOpacity(0.3),
                      child: IconButton(
                        icon: const Icon(
                          Icons.flip_camera_ios,
                          color: Colors.white,
                        ),
                        onPressed: _switchCamera,
                      ),
                    ),

                    // End call
                    CircleAvatar(
                      radius: 32,
                      backgroundColor: Colors.red,
                      child: IconButton(
                        icon: const Icon(
                          Icons.call_end,
                          color: Colors.white,
                          size: 28,
                        ),
                        onPressed: _endCall,
                      ),
                    ),
                  ],
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class NavigationManager {
  static final NavigationManager _instance = NavigationManager._internal();
  String? _previousRoute;

  factory NavigationManager() {
    return _instance;
  }

  NavigationManager._internal();

  String? get previousRoute => _previousRoute;

  void setPreviousRoute(String? route) {
    _previousRoute = route;
  }
}


class IncomingCallScreen extends StatefulWidget {
  final String callId;
  final String callerName;
  final String callerUid;
  final Map<String, dynamic> offerSdp;

  const IncomingCallScreen({
    super.key,
    required this.callId,
    required this.callerName,
    required this.callerUid,
    required this.offerSdp,
  });

  @override
  State<IncomingCallScreen> createState() => _IncomingCallScreenState();
}

class _IncomingCallScreenState extends State<IncomingCallScreen> {
  String? profileImageUrl;
  String callerFullName = '';
  bool isLoading = true;
  final AudioPlayer _ringtonePlayer = AudioPlayer();
  bool _isRinging = false;

  @override
  void initState() {
    super.initState();
    _fetchCallerInfo();
    _startRinging();
  }

  Future<void> _startRinging() async {
    try {
      setState(() => _isRinging = true);
      // Play ringtone (loop it)
      await _ringtonePlayer.setSource(AssetSource('audio/incoming_call.mp3'));
      await _ringtonePlayer.setReleaseMode(ReleaseMode.loop);
      await _ringtonePlayer.resume();
    } catch (e) {
      print('Error playing ringtone: $e');
    }
  }

  Future<void> _stopRinging() async {
    if (_isRinging) {
      try {
        await _ringtonePlayer.stop();
        setState(() => _isRinging = false);
      } catch (e) {
        print('Error stopping ringtone: $e');
      }
    }
  }

  Future<void> _fetchCallerInfo() async {
    try {
      // Fetch the caller's profile info from Firestore
      final userDoc = await FirebaseFirestore.instance
          .collection('Users')
          .doc(widget.callerUid)
          .get();

      if (userDoc.exists) {
        setState(() {
          // Get profile image URL
          profileImageUrl = userDoc.data()?['User Pic'];

          // Update caller name using Fname and Lname
          final fname = userDoc.data()?['Fname'] ?? '';
          final lname = userDoc.data()?['Lname'] ?? '';
          callerFullName = '$fname $lname'.trim();
          if (callerFullName.isEmpty) {
            callerFullName = widget.callerName; // Fallback to passed name
          }

          isLoading = false;
        });
      } else {
        setState(() {
          isLoading = false;
        });
      }
    } catch (e) {
      print('Error fetching caller profile: $e');
      setState(() {
        isLoading = false;
      });
    }
  }

  Future<void> _acceptCall(BuildContext context) async {
    await _stopRinging();
    // Navigate to the video call screen
    Navigator.pushReplacement(
      context,
      MaterialPageRoute(
        builder: (context) => VideoCallScreen(
          callId: widget.callId,
          remoteName: widget.callerName,
          remoteUid: widget.callerUid,
          chatId: widget.callId,  // Or pass the actual chatId if available
          isIncoming: true,
          offerSdp: widget.offerSdp,
        ),
      ),
    );
  }

  Future<void> _rejectCall(BuildContext context) async {
    await _stopRinging();
    try {
      // Add missed call history
      await _addMissedCallHistory();

      // Update call status and clean up notifications
      await _updateCallStatusAndCleanup();

      // Navigate back safely
      _navigateBackAfterRejection(context);
    } catch (e) {
      debugPrint('Error in _rejectCall: $e');
      if (mounted) {
        _navigateBackAfterRejection(context); // Ensure we navigate back even on error
      }
    }
  }

  Future<void> _addMissedCallHistory() async {
    if (!mounted) return;

    await FirebaseFirestore.instance
        .collection('ChatMessages')
        .doc(widget.callId)
        .collection('messages')
        .add({
      'type': 'call',
      'callId': widget.callId,
      'duration': 0,
      'timestamp': FieldValue.serverTimestamp(),
      'status': 'missed',
      'initiator': widget.callerUid,
    });
  }

  Future<void> _updateCallStatusAndCleanup() async {
    if (!mounted) return;

    final currentUserUid = FirebaseAuth.instance.currentUser?.uid;
    if (currentUserUid == null) return;

    final batch = FirebaseFirestore.instance.batch();

    // Update call status
    final callDoc = FirebaseFirestore.instance.collection('calls').doc(widget.callId);
    batch.update(callDoc, {
      'status': 'rejected',
      'endedAt': FieldValue.serverTimestamp(),
    });

    // Remove notification
    final notificationDoc = FirebaseFirestore.instance
        .collection('Users')
        .doc(currentUserUid)
        .collection('callNotifications')
        .doc(widget.callId);
    batch.delete(notificationDoc);

    await batch.commit();
  }

  void _navigateBackAfterRejection(BuildContext context) {
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!mounted) return;

      final nav = Navigator.of(context);
      final previousRoute = NavigationManager().previousRoute;

      if (previousRoute != null && nav.canPop()) {
        nav.popUntil(ModalRoute.withName(previousRoute));
      } else if (nav.canPop()) {
        nav.pop();
      }
    });
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.black87,
      body: SafeArea(
        child: Center(
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              const SizedBox(height: 60),

              // Caller avatar with profile image
              isLoading
                  ? const CircleAvatar(
                radius: 60,
                backgroundColor: Colors.teal,
                child: CircularProgressIndicator(color: Colors.white),
              )
                  : CircleAvatar(
                radius: 60,
                backgroundColor: Colors.teal,
                backgroundImage: profileImageUrl != null && profileImageUrl!.isNotEmpty
                    ? NetworkImage(profileImageUrl!)
                    : null,
                child: profileImageUrl == null || profileImageUrl!.isEmpty
                    ? const Icon(Icons.person, size: 80, color: Colors.white)
                    : null,
              ),

              const SizedBox(height: 24),

              // Caller name
              Text(
                callerFullName.isNotEmpty ? callerFullName : widget.callerName,
                style: const TextStyle(
                  color: Colors.white,
                  fontSize: 28,
                  fontWeight: FontWeight.bold,
                ),
              ),

              const SizedBox(height: 12),

              // Call type
              const Text(
                'Incoming Video Call',
                style: TextStyle(
                  color: Colors.white70,
                  fontSize: 16,
                ),
              ),

              const Spacer(),

              // Call actions
              Padding(
                padding: const EdgeInsets.only(bottom: 50),
                child: Row(
                  mainAxisAlignment: MainAxisAlignment.spaceEvenly,
                  children: [
                    // Reject call
                    Column(
                      children: [
                        CircleAvatar(
                          radius: 32,
                          backgroundColor: Colors.red,
                          child: IconButton(
                            icon: const Icon(
                              Icons.call_end,
                              color: Colors.white,
                              size: 28,
                            ),
                            onPressed: () => _rejectCall(context),
                          ),
                        ),
                        const SizedBox(height: 8),
                        const Text(
                          'Decline',
                          style: TextStyle(color: Colors.white),
                        ),
                      ],
                    ),

                    // Accept call
                    Column(
                      children: [
                        CircleAvatar(
                          radius: 32,
                          backgroundColor: Colors.green,
                          child: IconButton(
                            icon: const Icon(
                              Icons.call,
                              color: Colors.white,
                              size: 28,
                            ),
                            onPressed: () => _acceptCall(context),
                          ),
                        ),
                        const SizedBox(height: 8),
                        const Text(
                          'Accept',
                          style: TextStyle(color: Colors.white),
                        ),
                      ],
                    ),
                  ],
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class CallService {
  static final CallService _instance = CallService._internal();
  factory CallService() => _instance;
  CallService._internal();

  final FirebaseFirestore _firestore = FirebaseFirestore.instance;
  StreamSubscription? _callNotificationSubscription;
  BuildContext? _context;

  void initialize() {
    _listenForIncomingCalls();
  }

  // Call this method from your root widget to provide context
  void setContext(BuildContext context) {
    _context = context;
  }

  void dispose() {
    _callNotificationSubscription?.cancel();
    _context = null;
  }

  void _listenForIncomingCalls() {
    final currentUserUid = FirebaseAuth.instance.currentUser?.uid;
    if (currentUserUid == null) return;

    _callNotificationSubscription = _firestore
        .collection('Users')
        .doc(currentUserUid)
        .collection('callNotifications')
        .orderBy('timestamp', descending: true)
        .limit(1)
        .snapshots()
        .listen((snapshot) async {
      if (snapshot.docs.isNotEmpty && _context != null && Navigator.of(_context!).mounted) {
        final latestCall = snapshot.docs.first;
        final callData = latestCall.data();
        final callId = callData['callId'];

        final callDoc = await _firestore.collection('calls').doc(callId).get();
        if (callDoc.exists) {
          final callDetails = callDoc.data()!;
          if (callDetails['status'] == 'pending') {
            _handleIncomingCall(
              callId,
              callData['callerName'],
              callData['callerUid'],
              callDetails['offer'],
            );
          }
        }
      }
    }, onError: (error) {
      print("Error in call notification listener: $error");
    });
  }

  void _handleIncomingCall(
      String callId,
      String callerName,
      String callerUid,
      Map<String, dynamic> offerSdp,
      ) {
    if (_context == null || !Navigator.of(_context!).mounted) return;

    Navigator.of(_context!).push(
      MaterialPageRoute(
        builder: (context) => IncomingCallScreen(
          callId: callId,
          callerName: callerName,
          callerUid: callerUid,
          offerSdp: offerSdp,
        ),
      ),
    );
  }



  Future<void> _showIncomingCallScreen(
      BuildContext context,
      String callId,
      String callerName,
      String callerUid,
      Map<String, dynamic> offerSdp,
      ) async {
    // Show notification only if context is still valid
    if (!context.mounted) return;

    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(content: Text('Incoming call from $callerName')),
    );

    // Check for existing call screens
    bool isAlreadyShowingCallScreen = false;
    debugPrint("Checking for existing call screens");

    try {
      final currentRoute = ModalRoute.of(context)?.settings.name;
      isAlreadyShowingCallScreen = Navigator.of(context).canPop() &&
          (currentRoute == '/incoming_call' || currentRoute == '/video_call');
    } catch (e) {
      debugPrint("Error checking routes: $e");
      return;
    }

    debugPrint("isAlreadyShowingCallScreen: $isAlreadyShowingCallScreen");

    if (isAlreadyShowingCallScreen || !context.mounted) return;

    debugPrint("Showing incoming call screen");

    // Use a safer navigation approach
    await Future.delayed(Duration.zero);
    if (!context.mounted) return;

    await Navigator.of(context).push(
      MaterialPageRoute(
        settings: const RouteSettings(name: '/incoming_call'),
        builder: (context) => IncomingCallScreen(
          callId: callId,
          callerName: callerName,
          callerUid: callerUid,
          offerSdp: offerSdp,
        ),
      ),
    );
  }


  Future<void> startCall(BuildContext context, String remoteUid, String remoteName, String chatId) async {
    final callId = const Uuid().v4();

    // Store the current route globally
    NavigationManager().setPreviousRoute(ModalRoute.of(context)?.settings.name);

    // Navigate to the video call screen
    Navigator.push(
      context,
      MaterialPageRoute(
        settings: const RouteSettings(name: '/video_call'),
        builder: (context) => VideoCallScreen(
          callId: callId,
          remoteName: remoteName,
          remoteUid: remoteUid,
          chatId: chatId,  // Add this
          isIncoming: false,
        ),
      ),
    );
  }

  Future<void> clearOldNotifications() async {
    final currentUserUid = FirebaseAuth.instance.currentUser?.uid;
    if (currentUserUid == null) return;

    final batch = FirebaseFirestore.instance.batch();
    final snapshot = await _firestore
        .collection('Users')
        .doc(currentUserUid)
        .collection('callNotifications')
        .get();

    for (var doc in snapshot.docs) {
      batch.delete(doc.reference);
    }

    await batch.commit();
    print("Cleared ${snapshot.docs.length} old notifications");
  }
}

class WordFilterService {
  static final WordFilterService _instance = WordFilterService._internal();
  factory WordFilterService() => _instance;

  final FirebaseFirestore _firestore = FirebaseFirestore.instance;
  List<String> _bannedWords = [];
  bool _isInitialized = false;

  WordFilterService._internal();

  Future<void> initialize() async {
    if (_isInitialized) return;

    try {
      final snapshot = await _firestore.collection('bannedWords').doc('wordList').get();
      if (snapshot.exists) {
        _bannedWords = List<String>.from(snapshot.data()?['words'] ?? []);
        _isInitialized = true;
        debugPrint('Loaded ${_bannedWords.length} banned words');
      }
    } catch (e) {
      debugPrint('Error loading banned words: $e');
    }
  }

  List<String> checkForBannedWords(String text) {
    if (!_isInitialized) return [];

    final lowerText = text.toLowerCase();
    return _bannedWords.where((word) {
      return RegExp('\\b${RegExp.escape(word.toLowerCase())}\\b').hasMatch(lowerText);
    }).toList();
  }

  Future<bool> canSendMessage(String text, BuildContext context) async {
    final bannedWords = checkForBannedWords(text);
    if (bannedWords.isNotEmpty) {
      await _showBannedWordWarning(context, text, bannedWords);
      return false;
    }
    return true;
  }

  Future<void> _showBannedWordWarning(
      BuildContext context,
      String originalText,
      List<String> bannedWords,
      ) async {
    // Try to get current language (implement your own logic)
    final currentLanguage = 'en'; // Default to English

    // Prepare translated texts
    String title = 'Content Blocked';
    String message = 'Your content contains inappropriate language:';
    String suggestion = 'Please remove or change the highlighted words.';

    // Translate if needed (remove if not using translations)
    if (currentLanguage != 'en') {
      try {
        title = await TranslationService.translateText(
          text: title,
          targetLanguage: currentLanguage,
        );
        message = await TranslationService.translateText(
          text: message,
          targetLanguage: currentLanguage,
        );
        suggestion = await TranslationService.translateText(
          text: suggestion,
          targetLanguage: currentLanguage,
        );
      } catch (e) {
        debugPrint('Error translating warning: $e');
      }
    }

    await showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: Text(title),
        content: SingleChildScrollView(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(message),
              const SizedBox(height: 12),
              // Highlighted text display
              Container(
                padding: const EdgeInsets.all(12),
                decoration: BoxDecoration(
                  color: Colors.grey[100],
                  borderRadius: BorderRadius.circular(8),
                ),
                child: RichText(
                  text: _highlightBannedWords(originalText, bannedWords),
                ),
              ),
              const SizedBox(height: 12),
              Text(
                suggestion,
                style: TextStyle(color: Colors.grey[600]),
              ),
              const SizedBox(height: 8),
              Text(
                'Banned words: ${bannedWords.join(', ')}',
                style: TextStyle(
                  color: Colors.red[700],
                  fontWeight: FontWeight.bold,
                ),
              ),
            ],
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: Text('OK'), // Could also be translated
          ),
        ],
      ),
    );
  }

  TextSpan _highlightBannedWords(String text, List<String> bannedWords) {
    final spans = <TextSpan>[];
    final pattern = RegExp(
      bannedWords.map((word) => RegExp.escape(word)).join('|'),
      caseSensitive: false,
    );

    int lastMatchEnd = 0;

    for (final match in pattern.allMatches(text)) {
      // Add normal text before match
      if (match.start > lastMatchEnd) {
        spans.add(TextSpan(
          text: text.substring(lastMatchEnd, match.start),
        ));
      }

      // Add highlighted banned word
      spans.add(TextSpan(
        text: text.substring(match.start, match.end),
        style: TextStyle(
          backgroundColor: Colors.red[100],
          color: Colors.red[900],
          fontWeight: FontWeight.bold,
        ),
      ));

      lastMatchEnd = match.end;
    }

    // Add remaining normal text
    if (lastMatchEnd < text.length) {
      spans.add(TextSpan(text: text.substring(lastMatchEnd)));
    }

    return TextSpan(children: spans);
  }

  Future<void> reloadBannedWords() async {
    _isInitialized = false;
    await initialize();
  }
}