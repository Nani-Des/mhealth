import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/services.dart';
import 'package:flutter_dotenv/flutter_dotenv.dart';
import 'package:intl/intl.dart';
import 'package:http/http.dart' as http;
import 'dart:convert';
import 'package:fluttertoast/fluttertoast.dart';
import 'chat_module.dart';
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
        backgroundColor: Colors.teal,
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
                  backgroundColor: Colors.teal,
                  foregroundColor: Colors.white,
                ),
              ),
            ),
          ),
          // Rest of the body content
          Expanded(
            child: Container(
              decoration: BoxDecoration(
                gradient: LinearGradient(
                  begin: Alignment.topLeft,
                  end: Alignment.bottomRight,
                  colors: [Colors.teal[50]!, Colors.grey[100]!],
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
                                  style: TextStyle(
                                      fontSize: 12,
                                      color: Colors.teal[800],),
                                ),
                              ],
                            ),
                            trailing: Text(
                              timestamp != null
                                  ? DateFormat.yMMMd().add_jm().format(
                                  timestamp.toDate())
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
    final currentUserId = FirebaseAuth.instance.currentUser?.uid;

    showModalBottomSheet(
      context: context,
      builder: (context) {
        return FutureBuilder<DocumentSnapshot>(
          future: firestore.collection('ExpertPosts').doc(postId).get(),
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
                        await firestore.collection('ExpertPosts').doc(postId).delete();
                      }
                    },
                  ),
                ListTile(
                  leading: const Icon(Icons.copy),
                  title: const Text('Copy Post'),
                  onTap: () {
                    firestore.collection('ExpertPosts').doc(postId).get().then((value) {
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
    String selectedReason = 'Inappropriate content'; // Moved outside the builder

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
                    'Report Post',
                    style: TextStyle(fontSize: 20, fontWeight: FontWeight.bold),
                  ),
                  const SizedBox(height: 16),
                  const Text('Please select a reason for reporting this post:'),
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
                      autofocus: true, // Auto-focus when "Other" is selected
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

                          await _submitReport(
                            context: context,
                            postId: postId,
                            reportedUserId: reportedUserId,
                            reporterId: currentUserId,
                            postContent: postContent,
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

  Future<void> _submitReport({
    required BuildContext context,
    required String postId,
    required String reportedUserId,
    required String reporterId,
    required String postContent,
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
        'postId': postId,
        'reportedUserId': reportedUserId,
        'reporterId': reporterId,
        'postContent': postContent,
        'reason': reason,
        'timestamp': FieldValue.serverTimestamp(),
        'status': 'pending',
        'postType': 'expert',
      };

      // Add to reports collection
      await FirebaseFirestore.instance.collection('reportedExpertPosts').add(reportData);

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
                    Navigator.pop(context); // Close the language selection
                    _translatePostAndShowResult(
                        postId, entry.key); // Pass only postId and languageCode
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
        backgroundColor: Colors.teal[50], // Added teal background
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(16), // Rounded corners
        ),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            TextField(
              controller: postController,
              decoration: InputDecoration(
                hintText: 'Enter your post content...',
                border: OutlineInputBorder(
                  borderRadius:BorderRadius.circular(8),
                  borderSide: BorderSide(color: Colors.teal), // Teal border
                ),
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
            child: Text(
                'Cancel',
                style: TextStyle(color: Colors.teal[800]),
            ),
          ),
          TextButton(
            onPressed: () async {
              if (postController.text.trim().isNotEmpty) {
                final canPost = await WordFilterService().canSendMessage(
                    postController.text.trim(),
                    context
                );
                if (!canPost) return;
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
                final String userRegion = userData['Region'] ?? 'Unknown Region';

                await firestore.collection('ExpertPosts').add({
                  'content': postController.text.trim(),
                  'username': fullName, // Store full name
                  'userId': currentUserId, // Store userId for reference
                  'timestamp': FieldValue.serverTimestamp(),
                });

                // Process the post content for health insights
                await _processMessageForHealthInsights(
                  postController.text.trim(),
                  currentUserId,
                  userRegion,
                );

                postController.clear();
                Navigator.pop(context);
              }
            },
            style: TextButton.styleFrom(
              backgroundColor: Colors.teal, // Teal background
            ),
            child: const Text(
              'Post',
              style: TextStyle(color: Colors.white), // White text
            ),
          ),
        ],
      );
    },
  );
}

Future<void> _processMessageForHealthInsights(String messageText, String userId, String userRegion) async {
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

  // Identify matched categories and keywords
  Map<String, Map<String, int>> matchedCategories = {};
  healthCategories.forEach((category, keywords) {
    for (String keyword in keywords) {
      if (lowerCaseMessage.contains(keyword)) {
        matchedCategories.putIfAbsent(category, () => {});
        matchedCategories[category]![keyword] = (matchedCategories[category]![keyword] ?? 0) + 1;
      }
    }
  });

  // Get reference to the HealthInsights collection
  final healthInsightsCollection = FirebaseFirestore.instance.collection('HealthInsights');

  // Update or create documents for each matched category and keyword
  for (String category in matchedCategories.keys) {
    for (String keyword in matchedCategories[category]!.keys) {
      try {
        // Query for existing document with matching category, messageType, region, and keyword
        final querySnapshot = await healthInsightsCollection
            .where('category', isEqualTo: category)
            .where('messageType', isEqualTo: 'experts')
            .where('region', isEqualTo: userRegion)
            .where('keyword', isEqualTo: keyword)
            .get();

        if (querySnapshot.docs.isNotEmpty) {
          // Document exists, update the count
          final docId = querySnapshot.docs.first.id;
          await healthInsightsCollection.doc(docId).update({
            'count': FieldValue.increment(matchedCategories[category]![keyword]!),
            'lastUpdated': FieldValue.serverTimestamp(),
          });
        } else {
          // Document doesn't exist, create new one
          await healthInsightsCollection.add({
            'category': category,
            'keyword': keyword,
            'count': matchedCategories[category]![keyword],
            'region': userRegion,
            'messageType': 'experts',
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
