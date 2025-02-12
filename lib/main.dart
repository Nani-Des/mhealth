import 'dart:async';
import 'dart:math';

import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_core/firebase_core.dart';
import 'package:firebase_storage/firebase_storage.dart';
import 'package:flutter/material.dart';
import 'package:flutter_sound/flutter_sound.dart';
import 'package:flutter_speed_dial/flutter_speed_dial.dart';
import 'package:googleapis/streetviewpublish/v1.dart';
import 'dart:io';
import 'package:intl/intl.dart';
import 'package:path_provider/path_provider.dart';
import 'package:flutter/services.dart'; // For copying to clipboard
import 'package:permission_handler/permission_handler.dart';
import 'package:uuid/uuid.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:http/http.dart' as http;
import 'dart:convert';
import 'package:fluttertoast/fluttertoast.dart';
import 'package:flutter_dotenv/flutter_dotenv.dart';
import 'package:logging/logging.dart' as logging;
import 'package:logger/logger.dart' as logger;
import 'experts_community_page.dart';
import 'HealthInsightsPage.dart';


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

      // Ensure proper UTF-8 encoding in the request
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
      // Decode the response body with UTF-8
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
            // Ensure the translated text is properly decoded
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

  // Helper method to decode special characters
  static String _decodeSpecialCharacters(String text) {
    // Replace HTML entities if they appear in the text
    return text
        .replaceAll('&amp;', '&')
        .replaceAll('&lt;', '<')
        .replaceAll('&gt;', '>')
        .replaceAll('&quot;', '"')
        .replaceAll('&#039;', "'")
    // Add more replacements if needed for specific characters
        .replaceAll('\\u', '\\\\u'); // Handle Unicode escape sequences
  }
}

  void main() async {
  await dotenv.load();
  WidgetsFlutterBinding.ensureInitialized();
  await Firebase.initializeApp();
  await ensureTestUserExists();
  runApp(const MyApp());
}

Future<void> ensureTestUserExists() async {
  const String testEmail = "akotomichael255@gmail.com";
  const String testPassword = "Test1234!";

  try {
    UserCredential userCredential;

    // Check if a user with this email exists by attempting to log in
    try {
      userCredential = await FirebaseAuth.instance.signInWithEmailAndPassword(
        email: testEmail,
        password: testPassword,
      );
    } catch (e) {
      // If sign-in fails, create the test user
      userCredential = await FirebaseAuth.instance.createUserWithEmailAndPassword(
        email: testEmail,
        password: testPassword,
      );

      // Store user details in Firestore
      final user = userCredential.user;
      if (user != null) {
        await FirebaseFirestore.instance.collection('Users').doc(user.uid).set({
          'CreatedAt': FieldValue.serverTimestamp(),
          'Email': 'akotomichael255@gmail.com',
          'Fname': 'Michael',
          'Lname': 'Akoto',
          'Mobile Number': '0243472977',
          'Region': 'Ashanti',
          'Role': true,  // Set to true if you want the user to be an expert
          'Status': true,
          'User ID': user.uid,
          'User Pic': '', // Add a profile picture URL if available
        });
      }
    }

    print("Test user is logged in as: ${userCredential.user?.email}");
  } catch (error) {
    print("Error ensuring test user exists: $error");
  }
}

class MyApp extends StatelessWidget {
  const MyApp({super.key});

  @override
  Widget build(BuildContext context) {
    return const MaterialApp(
      title: 'My Chat App',
      home: ChatHomePage(),
    );
  }
}

class ChatHomePage extends StatefulWidget {
  const ChatHomePage({super.key});

  @override
  _ChatHomePageState createState() => _ChatHomePageState();
}

class _ChatHomePageState extends State<ChatHomePage>
    with SingleTickerProviderStateMixin {
  late TabController _tabController;
  //FloatingActionButtonLocation _fabLocation = FloatingActionButtonLocation.endFloat;

  @override
  void initState() {
    super.initState();
    _tabController = TabController(length: 2, vsync: this);

    _tabController.addListener(() {
      if (mounted) {
        setState(() {}); // ✅ Ensures FAB updates correctly when switching tabs
      }
    });
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: Text(
          _tabController.index == 0 ? 'Private Chats' : 'Open Forum',
        ),
        backgroundColor: Colors.lightBlue,
      ),
      body: TabBarView(
        controller: _tabController,
        children: [
          ChatPage(),
          const ForumPage(),
        ],
      ),
      bottomNavigationBar: Container(
        decoration: BoxDecoration(
          gradient: LinearGradient(
            colors: [Colors.blue.shade700, Colors.lightBlue.shade400], // Gradient colors
            begin: Alignment.topLeft,
            end: Alignment.bottomRight,
          ),
          borderRadius: const BorderRadius.only(
            topLeft: Radius.circular(16), // Rounded corners
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
              icon: Icon(Icons.message, size: 28), // Larger icon for better visibility
              text: 'Private Chats',
            ),
            Tab(
              icon: Icon(Icons.forum, size: 28), // Larger icon for better visibility
              text: 'Open Forum',
            ),
          ],
          labelColor: Colors.white, // Selected tab text and icon color
          unselectedLabelColor: Colors.grey[300], // Unselected tab text and icon color
          indicator: UnderlineTabIndicator(
            borderSide: BorderSide(
              color: Colors.white, // Indicator color
              width: 3, // Thicker indicator
            ),
            insets: const EdgeInsets.symmetric(horizontal: 40), // Wider indicator
          ),
          indicatorSize: TabBarIndicatorSize.tab,
          labelStyle: const TextStyle(
            fontSize: 14,
            fontWeight: FontWeight.bold, // Bold text for selected tab
          ),
          unselectedLabelStyle: const TextStyle(
            fontSize: 13,
            fontWeight: FontWeight.normal, // Normal text for unselected tabs
          ),
        ),
      ),
      floatingActionButton: _tabController.index == 0
          ? SpeedDial(
        icon: Icons.add,
        activeIcon: Icons.close,
        backgroundColor: Colors.blue,
        foregroundColor: Colors.white,
        activeBackgroundColor: Colors.blue,
        activeForegroundColor: Colors.white,
        buttonSize: const Size(56.0, 56.0),
        visible: true,
        closeManually: false,
        curve: Curves.bounceIn,
        overlayColor: Colors.black,
        overlayOpacity: 0.5,
        elevation: 8.0,
        shape: const CircleBorder(),
        children: [
          SpeedDialChild(
            child: const Icon(Icons.person_add),
            backgroundColor: Colors.blue,
            foregroundColor: Colors.white,
            label: 'Add User',
            labelStyle: const TextStyle(fontSize: 16.0),
            onTap: () async {
              String? currentUserId = FirebaseAuth.instance.currentUser?.uid;
              if (currentUserId != null) {
                _showUserList(context, currentUserId);
              } else {
                ScaffoldMessenger.of(context).showSnackBar(
                  const SnackBar(content: Text("User not logged in")),
                );
              }
            },
          ),
          SpeedDialChild(
            child: const Icon(Icons.analytics),
            backgroundColor: Colors.green,
            foregroundColor: Colors.white,
            label: 'Health Insights',
            labelStyle: const TextStyle(fontSize: 16.0),
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
          : FloatingActionButton(
        onPressed: () {
          Navigator.push(
            context,
            MaterialPageRoute(
              builder: (context) => const HealthInsightsPage(),
            ),
          );
        },
        backgroundColor: Colors.blue,
        child: const Icon(Icons.analytics, color: Colors.white),
      ),
          //: null,
      floatingActionButtonLocation: CustomFABLocation(), // Hide FAB when on Forum tab
    );
  }
}

class CustomFABLocation extends FloatingActionButtonLocation {
  @override
  Offset getOffset(ScaffoldPrelayoutGeometry scaffoldGeometry) {
    // Get the default position for endFloat (bottom-right corner)
    final defaultOffset = FloatingActionButtonLocation.endFloat.getOffset(scaffoldGeometry);

    // Adjust the vertical position (move it up by 40 pixels)
    return Offset(defaultOffset.dx, defaultOffset.dy - 25); // Subtract from the y-coordinate to move up
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
                    final userPhone = user['Mobile Number'] ?? 'No Phone';
                    final userPic = user['User Pic'] ?? '';
                    final isOnline = user['Status'] ?? false;

                    return ListTile(
                      leading: CircleAvatar(
                        backgroundImage: userPic.isNotEmpty ? NetworkImage(userPic) : null,
                        child: userPic.isEmpty ? Text(userFname[0]) : null,
                      ),
                      title: Text(fullName),
                      subtitle: Text(userPhone),
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

  // Step 4: Create a first dummy message (if needed)
  /*await newChat.collection('messages').add({
    'from_uid': fromUid,
    'to_uid': toUid,
    'content': 'Start chatting!',
    'timestamp': FieldValue.serverTimestamp(),
    'status': 'sent',
    'type': 'text', // Ensures consistency with your schema
  });*/

  return newChat.id; // Return the chat thread ID
}


String truncateMessage(String message, {int maxLength = 50}) {
  if (message.length <= maxLength) {
    return message;
  }
  return '${message.substring(0, maxLength)}...';
}

class ChatPage extends StatelessWidget {
  final FirebaseFirestore _firestore = FirebaseFirestore.instance;

  ChatPage({super.key});

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



  @override
  Widget build(BuildContext context) {
    final String? currentUserId = FirebaseAuth.instance.currentUser?.uid;

    if (currentUserId == null) {
      return const Center(child: Text("User not logged in"));
    }

    return StreamBuilder<QuerySnapshot>(
      stream: _firestore
          .collection('ChatMessages')
          .where('participants', arrayContains: currentUserId) // Filter by current user
          .orderBy('last_time', descending: true)
          .snapshots(),
      builder: (context, snapshot) {
        if (snapshot.hasError) {
          return Center(child: Text('Error: ${snapshot.error}'));
        }
        if (!snapshot.hasData) {
          // Show a single loading indicator in the center
          return const Center(child: CircularProgressIndicator());
        }

        final chats = snapshot.data!.docs;

        // If there are no chats, display a message
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
          separatorBuilder: (context, index) {
            return const Divider(
              thickness: 1.0,
              height: 1.0,
              color: Colors.grey,
            );
          },
          itemBuilder: (context, index) {
            final chat = chats[index].data() as Map<String, dynamic>;
            final lastMessage = chat['last_msg'] ?? '';
            final lastMessageType = chat['type'] ?? '';
            //final audioDuration = chat['audio_duration'] ?? 0;

            // Determine the other participant's ID
            final isCurrentUserSender = chat['from_uid'] == currentUserId;
            final otherParticipantId = isCurrentUserSender ? chat['to_uid'] : chat['from_uid'];

            return FutureBuilder<DocumentSnapshot>(
              future: FirebaseFirestore.instance.collection('Users').doc(otherParticipantId).get(),
              builder: (context, snapshot) {
                if (snapshot.connectionState == ConnectionState.waiting) {
                  // Return an empty container or a placeholder while loading
                  return ListTile(
                    leading: const CircleAvatar(child: Icon(Icons.person)), // Placeholder avatar
                    title: Text("Loading...", style: TextStyle(fontWeight: FontWeight.bold)), // Placeholder text
                    subtitle: const Text("Fetching user details..."), // Placeholder text
                  );
                }
                if (!snapshot.hasData || !snapshot.data!.exists) {
                  return const CircleAvatar(child: Icon(Icons.person)); // Default avatar if user data is missing
                }

                final userData = snapshot.data!.data() as Map<String, dynamic>?;
                final userPic = userData?['User Pic']; // Fetch user pic URL
                final firstName = userData?['Fname'] ?? 'Unknown'; // Fetch first name
                final lastName = userData?['Lname'] ?? ''; // Fetch last name
                final fullName = '$firstName $lastName'.trim(); // Combine first and last names

                return ListTile(
                  leading: CircleAvatar(
                    backgroundImage: userPic != null ? NetworkImage(userPic) : null,
                    child: userPic == null ? Text(firstName[0].toUpperCase()) : null,
                  ),
                  title: Text(fullName, style: TextStyle(fontWeight: FontWeight.bold)), // Display full name
                  subtitle: Row(
                    children: [
                      Expanded(
                        child: Text(
                          lastMessageType == 'audio'
                              ? '🎤 Voice message'
                              : truncateMessage(lastMessage),
                          overflow: TextOverflow.ellipsis,
                          maxLines: 1, // Ensures message stays in one line
                          softWrap: false,
                        ),
                      ),
                    ],
                  ),
                  trailing: Text(
                    formatTimestamp(chat['last_time']),
                    style: const TextStyle(fontSize: 12, color: Colors.blueGrey),
                  ),
                  onTap: () async {
                    String chatId = chat['chat_id'] ?? await _getOrCreateChatThread(
                      currentUserId!,
                      chat[isCurrentUserSender ? 'from_name' : 'to_name'], // Current User Name
                      chat[isCurrentUserSender ? 'from_pic' : 'to_pic'], // Current User Pic
                      otherParticipantId, // Other Participant ID
                      fullName, // Other Participant Name
                      userPic ?? '', // Other Participant Profile Pic
                    );

                    Navigator.push(
                      context,
                      MaterialPageRoute(
                        builder: (context) => ChatThreadDetailsPage(
                          chatId: chatId,
                          toName: fullName,
                          toUid: otherParticipantId,
                          fromUid: currentUserId!,
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
}

class ForumPage extends StatefulWidget {
  const ForumPage({super.key});

  @override
  _ForumPageState createState() => _ForumPageState();
}

class _ForumPageState extends State<ForumPage> {
  final GlobalKey<ScaffoldState> _scaffoldKey = GlobalKey<ScaffoldState>();
  final FirebaseFirestore _firestore = FirebaseFirestore.instance;
  bool? isExpert; // Store user's role

  @override
  void initState() {
    super.initState();
    _fetchUserRole();
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
    return Scaffold(
      key: _scaffoldKey,
      appBar: AppBar(
        title: const SizedBox.shrink(), // No title
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
                      backgroundColor: Colors.blue,
                      foregroundColor: Colors.white,
                    ),
                  ),
                ),
                Padding(
                  padding: const EdgeInsets.only(right: 8.0),
                  child: ElevatedButton(
                    onPressed: (isExpert == true)
                        ? () =>
                        Navigator.push(
                          context,
                          MaterialPageRoute(
                            builder: (context) => ExpertsCommunityPage(),
                          ),
                        )
                        : null,
                    style: ElevatedButton.styleFrom(
                      backgroundColor: isExpert == true ? Colors.blue : Colors
                          .grey,
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
          stream: _firestore.collection('ForumPosts').orderBy(
              'timestamp', descending: true).snapshots(),
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
                            style: const TextStyle(
                                fontSize: 12, color: Colors.grey),
                          ),
                        ],
                      ),
                      trailing: Text(
                        timestamp != null
                            ? DateFormat.yMMMd().add_jm().format(
                            timestamp.toDate())
                            : 'No Date',
                        style: const TextStyle(
                          fontSize: 12,
                          color: Colors.blueGrey,
                        ),
                      ),
                      onTap: () {
                        Navigator.push(
                          context,
                          MaterialPageRoute(
                            builder: (context) =>
                                PostDetailsPage(
                                    postId: postId, postTitle: post['content']),
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
    showModalBottomSheet(
      context: context,
      builder: (context) {
        return Wrap(
          children: [
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
                          child: const Text('Yes'),
                          style: TextButton.styleFrom(
                            foregroundColor: Colors.red,
                          ),
                          onPressed: () => Navigator.pop(context, true),
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
                firestore.collection('ForumPosts').doc(postId).get().then((
                    value) {
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
                _showPostTranslationLanguageSelector(
                    context, postId);
              },
            ),
          ],
        );
      },
    );
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
              Padding(
                padding: const EdgeInsets.all(16.0),
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
              }).toList(),
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
          content: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text('Translated: $translatedText',
                style: TextStyle(fontSize: 18),),
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
              child: const Text('Cancel'),
            ),
            TextButton(
              onPressed: () async {
                if (postController.text.trim().isNotEmpty) {
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
              child: const Text('Post'),
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

/*void _showAddPostDialog(BuildContext context) {
  final FirebaseFirestore firestore = FirebaseFirestore.instance;
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
            child: const Text('Cancel'),
          ),
          TextButton(
            onPressed: () async {
              if (postController.text.trim().isNotEmpty) {
                // Fetch user details from Firestore
                DocumentSnapshot userSnapshot = await firestore.collection('Users').doc(currentUserId).get();
                if (!userSnapshot.exists) {
                  ScaffoldMessenger.of(context).showSnackBar(
                    const SnackBar(content: Text("User data not found")),
                  );
                  return;
                }

                final userData = userSnapshot.data() as Map<String, dynamic>;
                final String fullName = "${userData['Fname'] ?? 'Unknown'} ${userData['Lname'] ?? ''}".trim();

                await firestore.collection('ForumPosts').add({
                  'content': postController.text.trim(),
                  'username': fullName, // Store full name instead of generic "CurrentUser"
                  'userId': currentUserId, // Store userId for reference
                  'timestamp': FieldValue.serverTimestamp(),
                });

                postController.clear();
                Navigator.pop(context);
              }
            },
            child: const Text('Post'),
          ),
        ],
      );
    },
  );
}*/



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

    return Scaffold(
      key: scaffoldMessengerKey,
      appBar: AppBar(
        title: Text('Discussion', style: TextStyle(color: Colors.white)),
        backgroundColor: Colors.lightBlue,
        elevation: 4,
        iconTheme: IconThemeData(color: Colors.white),
      ),
      body: Column(
        children: [
          // Post topic at the top (full-width background)
          Container(
            width: double.infinity,
            padding: const EdgeInsets.all(16.0),
            decoration: BoxDecoration(
              color: Colors.lightBlue[50],
              boxShadow: [
                BoxShadow(
                  color: Colors.grey.withOpacity(0.3),
                  blurRadius: 4,
                  offset: Offset(0, 2),
                ),
              ],
            ),
            child: Text(
              widget.postTitle,
              style: TextStyle(fontSize: 20, fontWeight: FontWeight.bold, color: Colors.lightBlue[900]),
            ),
          ),
          Expanded(
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

                return ListView.builder(
                  controller: _scrollController,
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

                    return FutureBuilder<DocumentSnapshot>(
                      future: FirebaseFirestore.instance.collection('Users').doc(userId).get(),
                      builder: (context, userSnapshot) {
                        if (userSnapshot.connectionState == ConnectionState.waiting) {
                          return const ListTile(title: Text('Loading...'));
                        }
                        if (userSnapshot.hasError || !userSnapshot.hasData || !userSnapshot.data!.exists) {
                          return ListTile(
                            title: Text(comment['content'] ?? 'No Content'),
                            subtitle: const Text('\n Posted by: Unknown User'),
                          );
                        }

                        final userData = userSnapshot.data!.data() as Map<String, dynamic>?;
                        final fname = userData?['Fname'] ?? 'Unknown';
                        final lname = userData?['Lname'] ?? 'User';
                        final fullName = '$fname $lname';

                        return Column(
                          children: [
                            Card(
                              margin: EdgeInsets.symmetric(vertical: 8, horizontal: 16),
                              elevation: 2,
                              shape: RoundedRectangleBorder(
                                borderRadius: BorderRadius.circular(12),
                              ),
                              child: Padding(
                                padding: const EdgeInsets.all(12.0),
                                child: Column(
                                  crossAxisAlignment: CrossAxisAlignment.start,
                                  children: [
                                    if (repliedTo.isNotEmpty)
                                      FutureBuilder<DocumentSnapshot>(
                                        future: FirebaseFirestore.instance.collection('Users').doc(repliedTo).get(),
                                        builder: (context, repliedUserSnapshot) {
                                          if (repliedUserSnapshot.connectionState == ConnectionState.waiting) {
                                            return const ListTile(title: Text('Loading...'));
                                          }
                                          if (repliedUserSnapshot.hasError || !repliedUserSnapshot.hasData || !repliedUserSnapshot.data!.exists) {
                                            return const SizedBox.shrink();
                                          }

                                          final repliedUserData = repliedUserSnapshot.data!.data() as Map<String, dynamic>?;
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
                                                _scrollToMessage(comment['repliedToCommentId'], comments);
                                              },
                                              child: Text(
                                                'Replying to $repliedToName: ${_truncateText(repliedContent, 15)}',
                                                style: TextStyle(
                                                  color: Colors.blue[800],
                                                  fontWeight: FontWeight.bold,
                                                ),
                                              ),
                                            ),
                                          );
                                        },
                                      ),
                                    Row(
                                      children: [
                                        Expanded(
                                          child: ListTile(
                                            contentPadding: EdgeInsets.zero,
                                            title: Text(
                                              comment['content'] ?? 'No Content',
                                              style: TextStyle(fontSize: 16),
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
                                            child: Icon(Icons.reply, color: Colors.lightBlue),
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
                    'Replying to $_replyingToUserName: ${_repliedContent != null && _repliedContent!.isNotEmpty ? _repliedContent!.substring(0, min(_repliedContent!.length, 15)) + '...' : _repliedContent ?? ''}',
                    style: TextStyle(fontWeight: FontWeight.bold, color: Colors.blue[800]),
                  ),
                  Spacer(),
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
                          offset: Offset(0, 2),
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
                        contentPadding: EdgeInsets.symmetric(horizontal: 16, vertical: 12),
                        suffixIcon: IconButton(
                          icon: Icon(Icons.send, color: Colors.lightBlue),
                          onPressed: () async {
                            if (commentController.text.trim().isNotEmpty) {
                              if (currentUserId == null) {
                                ScaffoldMessenger.of(context).showSnackBar(
                                  const SnackBar(content: Text("User not logged in")),
                                );
                                return;
                              }

                              DocumentSnapshot userSnapshot = await FirebaseFirestore.instance.collection('Users').doc(currentUserId).get();
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
    showModalBottomSheet(
      context: context,
      builder: (context) {
        return Wrap(
          children: [
            ListTile(
              leading: const Icon(Icons.delete),
              title: const Text('Delete Comment'),
              onTap: () async {
                // Close the current menu
                Navigator.pop(context);

                // Show confirmation dialog
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
                          child: const Text('Yes'),
                          style: TextButton.styleFrom(
                            foregroundColor: Colors.red,
                          ),
                          onPressed: () => Navigator.pop(context, true),
                        ),
                      ],
                    );
                  },
                ) ?? false; // Default to false if dialog is dismissed

                // Delete if user confirmed
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
                Navigator.pop(context); // Close the menu
                scaffoldMessengerKey.currentState?.showSnackBar(
                  const SnackBar(content: Text('Comment copied to clipboard!')),
                );
              },
            ),
            ListTile(
              leading: const Icon(Icons.translate),
              title: const Text('Translate Comment'),
              onTap: () {
                Navigator.pop(context); // Close the menu
                _showCommentTranslationLanguageSelector(
                  context, // Pass the context
                  scaffoldMessengerKey, // Pass the scaffoldMessengerKey
                  comment, // Pass the comment
                );
              },
            ),
          ],
        );
      },
    );
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
              Padding(
                padding: const EdgeInsets.all(16.0),
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
              }).toList(),
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
          content: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                'Translated: $translatedText',
                style: TextStyle(fontSize: 18),
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
  final Map<String, StreamSubscription<PlaybackDisposition>> _positionSubscriptions = {};
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

    _initializePlayer();

    // Add scroll listener
    _scrollController.addListener(_onScroll);
  }

  Future<void> _initializePlayer() async {
    await _player.openPlayer();
    await _player.setLogLevel(logger.Level.info); // Use logger.Level
  }

  @override
  void dispose() {
    _recorder.closeRecorder();
    _player.closePlayer();
    _recordingTimer?.cancel();
    _playbackTimer?.cancel();
    _scrollController.removeListener(_onScroll); // Remove scroll listener
    _scrollController.dispose(); // Dispose the ScrollController
    _positionSubscriptions.values.forEach((sub) => sub.cancel());
    _playerSubscription?.cancel();
    _player.closePlayer();
    super.dispose();
  }

  void _onVideoCallPressed() {
    // Placeholder for video call functionality
    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(content: Text('Video call feature coming soon!')),
    );

    // Log the action for debugging
    print('Video call button pressed');
  }

  void _onScroll() {
    // Show the FAB if the user has scrolled up more than 100 pixels
    if (_scrollController.position.pixels < _scrollController.position.maxScrollExtent - 100) {
      setState(() {
        _showScrollToBottomButton = true;
      });
    } else {
      setState(() {
        _showScrollToBottomButton = false;
      });
    }
  }

  void _scrollToBottom() {
    // Animate the scroll to the bottom
    _scrollController.animateTo(
      _scrollController.position.maxScrollExtent,
      duration: const Duration(milliseconds: 300),
      curve: Curves.easeOut,
    );
  }

  void _showMessageMenu(QueryDocumentSnapshot<Map<String, dynamic>> message) {
    showModalBottomSheet(
      context: context,
      builder: (context) {
        return Wrap(
          children: [
            ListTile(
              leading: const Icon(Icons.delete),
              title: const Text('Delete Message'),
              onTap: () async {
                // Close the current menu
                Navigator.pop(context);

                // Show confirmation dialog
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
                          child: const Text('Yes'),
                          style: TextButton.styleFrom(
                            foregroundColor: Colors.red,
                          ),
                          onPressed: () => Navigator.pop(context, true),
                        ),
                      ],
                    );
                  },
                ) ?? false; // Default to false if dialog is dismissed

                // Delete if user confirmed
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
                Navigator.pop(context); // Close menu
                _showTranslationLanguageSelector(message);
              },
            ),
          ],
        );
      },
    );
  }


  void _showTranslationLanguageSelector(QueryDocumentSnapshot<Map<String, dynamic>> message) {
    showModalBottomSheet(
      context: context,
      builder: (BuildContext context) {
        return SingleChildScrollView(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              // Add a title here
              Padding(
                padding: const EdgeInsets.all(16.0), // Add some padding around the title
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
              }).toList(),
            ],
          ),
        );
      },
    );
  }

  Future<void> _translateAndShowResult(String text, String languageCode) async {
    try {
      print('Translating: "$text" to "$languageCode"');
      final translatedText = await TranslationService.translateText(
        text: text,
        targetLanguage: languageCode,
      );
      print('Translation Success: $translatedText');

      // Declare the controller as a late variable
      late final ScaffoldFeatureController<SnackBar, SnackBarClosedReason> controller;

      // Create the SnackBar content
      final snackBar = SnackBar(
        content: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text('Translated: $translatedText',
            style: TextStyle(fontSize: 18),),
            const SizedBox(height: 20), // Add spacing between text and buttons
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
        duration: const Duration(days: 365), // Keep the SnackBar open indefinitely
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
        _audioPlaybackDurations[audioUrl] = Duration.zero; // Reset playback position
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
            _audioPlaybackDurations[audioUrl] = event.position; // Update current position
            _audioTotalDurations[audioUrl] = event.duration; // Update total duration
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
        _audioPath = '${dir.path}/${DateTime.now().millisecondsSinceEpoch}.aac';
        await _recorder.startRecorder(toFile: _audioPath, codec: Codec.aacADTS);

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
        _recordingDuration = Duration.zero;
      });

      if (_audioPath != null) {
        final file = File(_audioPath!);

        // Check if the file exists
        if (!await file.exists()) {
          print('Error: Audio file does not exist at $_audioPath');
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(content: Text('Audio file not found')),
          );
          return;
        }

        // Check if the file is empty
        if (await file.length() == 0) {
          print('Error: Audio file is empty at $_audioPath');
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(content: Text('Audio file is empty')),
          );
          return;
        }

        print('Audio file exists at $_audioPath');
        print('File size: ${await file.length()} bytes');

        final fileName = 'audio_${const Uuid().v4()}.aac'; // Use UUID for unique filenames
        final storagePath = 'chat_files/audio/$fileName';

        try {
          // Upload the audio file to Firebase Storage
          final storageRef = FirebaseStorage.instanceFor(
            bucket: 'mhealth-6191e.appspot.com', // Replace with your bucket name
          ).ref().child(storagePath);

          final uploadTask = storageRef.putFile(
            file,
            SettableMetadata(contentType: 'audio/aac'), // Set MIME type
          );

          // Monitor upload progress
          uploadTask.snapshotEvents.listen((taskSnapshot) {
            final progress = (taskSnapshot.bytesTransferred / taskSnapshot.totalBytes) * 100;
            print('Upload progress: $progress%');
            // Update UI with progress if needed
          });

          // Wait for the upload to complete
          await uploadTask;

          // Get the download URL
          final fileUrl = await storageRef.getDownloadURL();
          print('Audio uploaded successfully. Download URL: $fileUrl');

          // Format the duration for display
          final formattedDuration = _formatDuration(_recordingDuration);

          // Add the audio message to Firestore
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
            'audio_duration': _recordingDuration.inSeconds, // Save the audio duration
            'status': 'sent',
          });

          // Update the last message in the chat thread
          await _firestore.collection('ChatMessages').doc(widget.chatId).update({
            'last_msg': '🎤 Voice Message', // Include microphone icon and duration
            'last_time': FieldValue.serverTimestamp(),
          });

          // Clear the audio path and delete the local file
          setState(() {
            _audioPath = null;
          });
          await file.delete();

          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(
              content: Text('Voice recording sent!'),
            ),
          );
        } catch (e) {
          print('Error uploading audio: $e');
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(content: Text('Failed to upload audio: ${e.toString()}')),
          );
        }
      } else {
        print('Error: _audioPath is null');
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('No audio file to upload')),
        );
      }
    }
  }

  void _sendMessage() async {
    if (_messageController.text.trim().isEmpty) return;

    String messageText = _messageController.text.trim();
    final message = {
      'content': messageText,
      'from_uid': widget.fromUid,
      'to_uid': widget.toUid,
      'timestamp': FieldValue.serverTimestamp(),
      'type': 'text',
      'status': 'sent',
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
  }

  Future<void> _processMessageForHealthInsights(String messageText, String userId) async {
    // Fetch user's region from the Users collection
    DocumentSnapshot userDoc = await FirebaseFirestore.instance.collection('Users').doc(userId).get();
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

    // Convert message text to lowercase for case-insensitive matching
    String lowerCaseMessage = messageText.toLowerCase();

    // Identify matched categories
    Map<String, int> matchedCategories = {};
    healthCategories.forEach((category, keywords) {
      for (String keyword in keywords) {
        if (lowerCaseMessage.contains(keyword)) {
          matchedCategories[category] = (matchedCategories[category] ?? 0) + 1;
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
        print("Updated existing document for category: $category, region: $userRegion, messageType: $messageType");
      } else {
        // Document does not exist, create a new one
        await FirebaseFirestore.instance.collection('HealthInsights').add({
          'category': category,
          'count': count,
          'region': userRegion,
          'messageType': messageType,
          'timestamp': FieldValue.serverTimestamp(),
        });
        print("Created new document for category: $category, region: $userRegion, messageType: $messageType");
      }
    }

    print("Processed message for health insights: $matchedCategories");
  }



  String _formatDuration(Duration duration) {
    String twoDigits(int n) => n.toString().padLeft(2, '0');
    String minutes = twoDigits(duration.inMinutes.remainder(60));
    String seconds = twoDigits(duration.inSeconds.remainder(60));
    return '$minutes:$seconds';
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        leadingWidth: 30, // Reduce the leading width to bring everything closer to back button
        title: FutureBuilder<DocumentSnapshot>(
          future: FirebaseFirestore.instance.collection('Users').doc(widget.toUid).get(),
          builder: (context, snapshot) {
            if (snapshot.connectionState == ConnectionState.waiting) {
              return Row(
                children: [
                  CircleAvatar(
                    radius: 20, // Increased size
                    child: Icon(Icons.person, size: 24), // Increased icon size
                  ),
                  const SizedBox(width: 8),
                  Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        widget.toName,
                        style: const TextStyle(
                          fontSize: 18, // Increased font size
                          fontWeight: FontWeight.bold, // Made bold
                        ),
                      ),
                      const Text(
                        "Loading...",
                        style: TextStyle(
                          fontSize: 13, // Slightly increased
                          color: Colors.black, // Changed to black
                        ),
                      ),
                    ],
                  ),
                ],
              );
            }

            if (!snapshot.hasData || !snapshot.data!.exists) {
              return Row(
                children: [
                  CircleAvatar(
                    radius: 20, // Increased size
                    child: Icon(Icons.person, size: 24), // Increased icon size
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
                        "Offline",
                        style: TextStyle(
                          fontSize: 13,
                          color: Colors.black,
                        ),
                      ),
                    ],
                  ),
                ],
              );
            }

            final userData = snapshot.data!.data() as Map<String, dynamic>?;
            final userPic = userData?['User Pic'];
            final isOnline = userData?['Status'] ?? false;

            return Padding(
              padding: const EdgeInsets.only(left: 0), // Reduce left padding to move closer to back button
              child: Row(
                children: [
                  CircleAvatar(
                    radius: 20, // Increased size
                    backgroundImage: userPic != null ? NetworkImage(userPic) : null,
                    child: userPic == null ? Icon(Icons.person, size: 24) : null, // Increased icon size
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
                      Text(
                        isOnline ? "Active now" : "Offline",
                        style: const TextStyle(
                          fontSize: 13,
                          color: Colors.black, // Changed to black regardless of status
                        ),
                      ),
                    ],
                  ),
                ],
              ),
            );
          },
        ),
        backgroundColor: Colors.lightBlue,
        actions: [
          IconButton(
            icon: const Icon(Icons.video_call, color: Colors.white),
            onPressed: _onVideoCallPressed,
          ),
        ],
      ),
      body: Container(
        decoration: const BoxDecoration(
          gradient: LinearGradient(
            begin: Alignment.topLeft,
            end: Alignment.bottomRight,
            colors: [Colors.grey, Colors.grey], // Consistent background
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
                        return Center(child: Text('Error: ${snapshot.error}'));
                      }
                      if (!snapshot.hasData) {
                        return const Center(child: CircularProgressIndicator());
                      }

                      final messages = snapshot.data!.docs;

                      return ListView.builder(
                        controller: _scrollController, // Attach the ScrollController
                        itemCount: messages.length,
                        itemBuilder: (context, index) {
                          final message = messages[index];
                          final isSentByUser = message['from_uid'] == widget.fromUid;

                          return GestureDetector(
                            onLongPress: () => _showMessageMenu(message),
                            child: Align(
                              alignment: isSentByUser
                                  ? Alignment.centerRight
                                  : Alignment.centerLeft,
                              child: ConstrainedBox(
                                constraints: BoxConstraints(
                                  maxWidth: MediaQuery.of(context).size.width * 0.7, // Max width for text bubbles
                                ),
                                child: CustomPaint(
                                  size: Size(double.infinity, double.infinity),
                              painter: ChatBubblePainter(isSentByUser: isSentByUser),
                              child: Padding(
                                padding: const EdgeInsets.all(12.0),
                                child: Column(
                                  crossAxisAlignment: CrossAxisAlignment.start,
                                  children: [
                                    if (message['type'] == 'text') ...[
                                      Text(
                                        message['content'] ?? '', // Fallback to an empty string if 'content' is null
                                        softWrap: true, // Allow text to wrap to the next line
                                        style: TextStyle(
                                          fontWeight: FontWeight.w400, // Make the text bold
                                          fontSize: 15, // Optional: Set a font size for better readability
                                          color: isSentByUser ? Colors.black87 : Colors.black87, // Optional: Adjust text color based on sender
                                        ),
                                      ),
                                    ] else if (message['type'] == 'audio') ...[
                                      _buildAudioMessage(message.data()),
                                    ],
                                    const SizedBox(height: 5),
                                    Align(
                                      alignment: Alignment.bottomRight,
                                      child: Text(
                                        message['timestamp'] != null
                                            ? DateFormat.jm().format(
                                          (message['timestamp'] as Timestamp).toDate(),
                                        )
                                            : 'Sending...',
                                        style: TextStyle(
                                          fontSize: 10,
                                          color: Colors.grey[800], // Deep grey color to match the send icon
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
                        backgroundColor: Colors.blue,
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
                            value: _recordingDuration.inSeconds / 60, // Max 60 seconds
                            backgroundColor: Colors.grey[300],
                            valueColor: const AlwaysStoppedAnimation<Color>(Colors.blue),
                          ),
                          Text(
                            'Recording: ${_recordingDuration.inSeconds}s',
                            style: const TextStyle(color: Colors.red),
                          ),
                        ],
                      ),
                    ),
                    IconButton(
                      icon: const Icon(Icons.send, color: Colors.blue),
                      onPressed: _stopRecordingAndUpload,
                    ),
                  ] else ...[
                    GestureDetector(
                      onTap: _startRecording,
                      child: const Icon(
                        Icons.mic,
                        color: Colors.blue,
                      ),
                    ),
                    const SizedBox(width: 8), // Add space between microphone and text box
                    Expanded(
                      child: Container(
                        decoration: BoxDecoration(
                          color: Colors.white,
                          borderRadius: BorderRadius.circular(30), // Oval shape
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
                              border: InputBorder.none, // Remove default border
                              contentPadding: EdgeInsets.symmetric(horizontal: 16, vertical: 12),
                            ),
                            maxLines: null, // Allow multiple lines
                            keyboardType: TextInputType.multiline, // Enable multi-line input
                          ),
                        ),
                      ),
                    ),
                    const SizedBox(width: 8), // Add space between text box and send button
                    IconButton(
                      icon: const Icon(Icons.send),
                      onPressed: _sendMessage,
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
    final isPlaying = _audioPlaybackStates[audioUrl] == true;
    final position = _audioPlaybackDurations[audioUrl] ?? Duration.zero;
    final duration = _audioTotalDurations[audioUrl] ?? Duration.zero;

    return Container(
      padding: const EdgeInsets.all(8.0),
      decoration: BoxDecoration(
        color: Colors.grey[200],
        borderRadius: BorderRadius.circular(12),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          // Play/Pause Button with Playback Indicator
          Stack(
            alignment: Alignment.center,
            children: [
              IconButton(
                icon: Icon(
                  isPlaying ? Icons.pause : Icons.play_arrow,
                  color: Colors.blue,
                ),
                onPressed: () => _playAudio(audioUrl),
              ),
              if (isPlaying)
                SizedBox(
                  width: 24,
                  height: 24,
                  child: CircularProgressIndicator(
                    strokeWidth: 2,
                    valueColor: AlwaysStoppedAnimation(Colors.white),
                  ),
                ),
            ],
          ),
          Expanded(
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                // Slider for Scrubbing (Thumb Does Not Move)
                SliderTheme(
                  data: SliderThemeData(
                    trackHeight: 2.0,
                    thumbShape: RoundSliderThumbShape(enabledThumbRadius: 6.0),
                  ),
                  child: Slider(
                    value: position.inMilliseconds.toDouble(),
                    max: duration.inMilliseconds > 0
                        ? duration.inMilliseconds.toDouble()
                        : 1.0, // Default to 1 if duration is 0
                    min: 0,
                    onChanged: (value) async {
                      if (_player.isPlaying || _currentlyPlayingUrl == audioUrl) {
                        print('Seeking to: ${Duration(milliseconds: value.toInt())}');
                        await _player.seekToPlayer(Duration(milliseconds: value.toInt()));
                        if (mounted) {
                          setState(() {
                            _audioPlaybackDurations[audioUrl] =
                                Duration(milliseconds: value.toInt());
                          });
                        }
                      }
                    },
                  ),
                ),
                // Removed Timing Display
              ],
            ),
          ),
        ],
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
      ..color = isSentByUser ? Colors.blue[500]! : Colors.grey[200]!
      ..style = PaintingStyle.fill;

    final Paint shadowPaint = Paint()
      ..color = Colors.black.withOpacity(0.1)
      ..maskFilter = MaskFilter.blur(BlurStyle.normal, 6);

    final radius = 20.0;

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
        bottomLeft: Radius.circular(radius),
        bottomRight: Radius.circular(radius),
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