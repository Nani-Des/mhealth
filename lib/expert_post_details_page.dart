import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/services.dart';
import 'package:flutter_dotenv/flutter_dotenv.dart';
import 'package:intl/intl.dart';
import 'package:http/http.dart' as http;
import 'dart:convert';


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

class ExpertPostDetailsPage extends StatefulWidget {
  final String postId;
  final String postTitle;

  const ExpertPostDetailsPage({super.key, required this.postId, required this.postTitle});

  @override
  _ExpertPostDetailsPageState createState() => _ExpertPostDetailsPageState();
}

class _ExpertPostDetailsPageState extends State<ExpertPostDetailsPage> with SingleTickerProviderStateMixin {
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
    _scrollController.dispose(); // Dispose the ScrollController
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
        title: Text("Discussion"),
        backgroundColor: Colors.lightBlue,
      ),
      body: Column(
        children: [
          // Post topic at the top (full-width background)
          Container(
            width: double.infinity, // Ensure the background covers the entire line
            padding: const EdgeInsets.all(16.0),
            color: Colors.grey[200], // Background color
            child: Text(
              widget.postTitle,
              style: const TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
            ),
          ),
          Expanded(
            child: StreamBuilder<QuerySnapshot>(
              stream: FirebaseFirestore.instance
                  .collection('ExpertPosts')
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
                    final repliedTo = comment['repliedTo'] ?? ''; // User ID of the replied-to user
                    final repliedContent = comment['repliedContent'] ?? ''; // Content of the replied-to message
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
                            subtitle: const Text('Posted by: Unknown User'),
                          );
                        }

                        final userData = userSnapshot.data!.data() as Map<String, dynamic>?;

                        final fname = userData?['Fname'] ?? 'Unknown';
                        final lname = userData?['Lname'] ?? 'User';
                        final fullName = '$fname $lname';

                        return Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            // Show reply box only for the comment that is a reply
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
                                    margin: const EdgeInsets.only(bottom: 4.0),
                                    decoration: BoxDecoration(
                                      color: Colors.grey[300],
                                      borderRadius: BorderRadius.circular(8),
                                    ),
                                    child: Column(
                                      crossAxisAlignment: CrossAxisAlignment.start,
                                      children: [
                                        InkWell(
                                          onTap: () {
                                            // Scroll to the original message if user ID is clicked
                                            _scrollToMessage(comment['repliedToCommentId'], comments);
                                          },
                                          child: Text(
                                            'Replying to $repliedToName: ${repliedContent.length > 10 ? repliedContent.substring(0, 15) + '...' : repliedContent}',
                                            style: TextStyle(
                                              color: Colors.blue,
                                              fontWeight: FontWeight.bold, // Bolden the reply message
                                            ),
                                          ),
                                        ),
                                      ],
                                    ),
                                  );
                                },
                              ),
                            ListTile(
                              title: Text(comment['content'] ?? 'No Content'),
                              subtitle: Text('Posted by: $fullName\n${DateFormat('yyyy-MM-dd HH:mm').format(timestamp)}'),
                              trailing: ScaleTransition(
                                scale: _scaleAnimation,
                                child: IconButton(
                                  icon: const Icon(Icons.reply),
                                  onPressed: () {
                                    // Animate the reply button
                                    _animateReplyButton();
                                    // Focus on the reply field and bring up the keyboard
                                    _focusNode.requestFocus(); // Activate the keyboard
                                    _replyToMessage(context, '$fname $lname', comment['content'], comment['userId'], commentId);
                                  },
                                ),
                              ),
                                onLongPress: () {
                                  try {
                                    final commentDoc = comments[index] as QueryDocumentSnapshot<
                                        Map<String, dynamic>>;
                                    _showCommentMenu(
                                      context,
                                      scaffoldMessengerKey,
                                      commentDoc,
                                    );
                                  } catch (e) {
                                    ScaffoldMessenger.of(context).showSnackBar(
                                      SnackBar(content: Text(
                                          'Error loading comment: ${e.toString()}')),
                                    );
                                  }
                                }
                            ),
                            const Divider(),
                          ],
                        );
                      },
                    );
                  },
                );
              },
            ),
          ),
          // Reply bar (appears when replying to a comment)
          if (_replyingToUserName != null)
            Container(
              color: Colors.grey[300],
              padding: const EdgeInsets.all(8.0),
              child: Row(
                children: [
                  Text(
                    'Replying to $_replyingToUserName: ${_repliedContent!.length > 10 ? _repliedContent!.substring(0, 15) + '...' : _repliedContent}',
                    style: const TextStyle(fontWeight: FontWeight.bold),
                  ),
                  const Spacer(),
                  IconButton(
                    icon: const Icon(Icons.close),
                    onPressed: _cancelReply, // Cancel the reply process
                  ),
                ],
              ),
            ),
          // Input bar for typing comments
          Container(
            color: Colors.grey[300],
            padding: const EdgeInsets.all(8.0),
            child: Row(
              children: [
                Expanded(
                  child: Container(
                    decoration: BoxDecoration(
                      color: Colors.white,
                      borderRadius: BorderRadius.circular(30),
                    ),
                    constraints: const BoxConstraints(maxHeight: 120),
                    child: TextField(
                      controller: commentController,
                      focusNode: _focusNode, // Attach the focusNode
                      decoration: const InputDecoration(
                        hintText: 'Type comment here...',
                        border: InputBorder.none,
                        contentPadding: EdgeInsets.symmetric(horizontal: 16, vertical: 12),
                      ),
                      maxLines: null,
                      keyboardType: TextInputType.multiline,
                    ),
                  ),
                ),
                const SizedBox(width: 8),
                IconButton(
                  icon: const Icon(Icons.send),
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

                      await FirebaseFirestore.instance
                          .collection('ExpertPosts')
                          .doc(widget.postId)
                          .collection('comments')
                          .add({
                        'content': commentController.text,
                        'userId': currentUserId,
                        'username': fullName,
                        'timestamp': FieldValue.serverTimestamp(),
                        'repliedTo': _replyingToUserId, // Add the replied-to comment's userId
                        'repliedContent': _repliedContent, // Add the content of the original message
                        'repliedToCommentId': _replyingToCommentId, // Add the ID of the comment being replied to
                      });

                      // After posting, reset the reply target
                      commentController.clear();
                      setState(() {
                        _replyingToUserId = null; // Reset the replied-to state
                        _repliedContent = null; // Clear the content of the message
                        _replyingToCommentId = null; // Reset the comment being replied to
                        _replyingToUserName = null; // Clear the name of the user being replied to
                      });
                    }
                  },
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
                Navigator.pop(context); // Close the menu
                await comment.reference.delete(); // Delete the comment
                scaffoldMessengerKey.currentState?.showSnackBar(
                  const SnackBar(content: Text('Comment deleted!')),
                );
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
          .collection('ExpertPosts')
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
}

