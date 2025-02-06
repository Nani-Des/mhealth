import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/services.dart';
import 'package:flutter_dotenv/flutter_dotenv.dart';
import 'package:intl/intl.dart';
import 'package:http/http.dart' as http;
import 'dart:convert';
import 'package:fluttertoast/fluttertoast.dart';
import 'expert_post_details_page.dart'; // Import the ExpertPostDetailsPage


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



class ExpertsCommunityPage extends StatefulWidget {
  const ExpertsCommunityPage({super.key});

  @override
  _ExpertsCommunityPageState createState() => _ExpertsCommunityPageState();
}

class _ExpertsCommunityPageState extends State<ExpertsCommunityPage> {
  final GlobalKey<ScaffoldMessengerState> scaffoldMessengerKey = GlobalKey<ScaffoldMessengerState>();


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
      key: scaffoldMessengerKey,
      appBar: AppBar(
        title: const Text('Experts Community'),
        backgroundColor: Colors.lightBlue,
      ),
      body: Column(
        children: [
          // Add Post Button beneath the AppBar
          Align(
            alignment: Alignment.centerLeft, // Align the button to the far left
            child: Padding(
              padding: const EdgeInsets.only(left: 16.0, top: 8.0, bottom: 8.0),
              child: ElevatedButton.icon(
                onPressed: () => _showAddPostDialog(context, _firestore),
                icon: const Icon(Icons.add, color: Colors.white),
                label: const Text("Add Post"),
                style: ElevatedButton.styleFrom(
                  backgroundColor: Colors.blue,
                  foregroundColor: Colors.white,
                ),
              ),
            ),
          ),
          // Rest of the body content
          Expanded(
            child: Container(
              decoration: const BoxDecoration(
                gradient: LinearGradient(
                  begin: Alignment.topLeft,
                  end: Alignment.bottomRight,
                  colors: [Colors.grey, Colors.grey],
                ),
              ),
              child: StreamBuilder<QuerySnapshot>(
                stream: _firestore
                    .collection('ExpertPosts')
                    .orderBy('timestamp', descending: true)
                    .snapshots(),
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
                        onLongPress: () =>
                            _showPostMenu(context, postId),
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
                                      ExpertPostDetailsPage(
                                          postId: postId,
                                          postTitle: post['content']),
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
          ),
        ],
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
                // Close the current menu
                Navigator.pop(context);

                // Show confirmation dialog
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
                ) ?? false; // Default to false if dialog is dismissed

                // Delete if user confirmed
                if (shouldDelete) {
                  await firestore.collection('ExpertPosts').doc(postId).delete();
                }
              },
            ),
            ListTile(
              leading: const Icon(Icons.copy),
              title: const Text('Copy Post'),
              onTap: () {
                firestore.collection('ExpertPosts').doc(postId).get().then((
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
                Navigator.pop(context); // Close menu
                _showPostTranslationLanguageSelector(
                    context, postId); // Pass only context and postId
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
                    Navigator.pop(context); // Close the language selection
                    _translatePostAndShowResult(
                        postId, entry.key); // Pass only postId and languageCode
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
      final postDoc = await firestore.collection('ExpertPosts')
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

        // Declare the controller as a late variable
        late final ScaffoldFeatureController<SnackBar,
            SnackBarClosedReason> controller;

        // Create the SnackBar content
        final snackBar = SnackBar(
          content: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text('Translated: $translatedText',
                style: TextStyle(fontSize: 18),),
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
}

void _showAddPostDialog(BuildContext context, FirebaseFirestore firestore) {
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

                await firestore.collection('ExpertPosts').add({
                  'content': postController.text.trim(),
                  'username': fullName, // Store full name
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
}






