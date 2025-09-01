import 'dart:async';

import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/services.dart';
import 'package:flutter_dotenv/flutter_dotenv.dart';
import 'package:intl/intl.dart';
import 'package:http/http.dart' as http;
import 'dart:convert';
import 'dart:math';

import '../Services/config_service.dart';
import 'chat_module.dart';


class TranslationService {
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

      // Initialize ConfigService
      final configService = ConfigService();
      if (!configService.isInitialized) {
        await configService.init();
      }

      // Get API values from ConfigService
      final apiKey = configService.ghanaNlpApiKey;
      final apiUrl = configService.nlpApiUrl;

      if (apiKey.isEmpty || apiUrl.isEmpty) {
        throw Exception('Translation API configuration not properly initialized');
      }

      final url = Uri.parse('$apiUrl?subscription-key=$apiKey');

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
  final FocusNode _focusNode = FocusNode();
  String? _replyingToUserId;
  String? _repliedContent;
  String? _replyingToCommentId;
  String? _replyingToUserName;

  late AnimationController _animationController;
  late Animation<double> _scaleAnimation;

  bool _isInitialLoadComplete = false;
  List<QueryDocumentSnapshot> _cachedComments = [];
  Map<String, Map<String, dynamic>> _userDataCache = {};
  StreamSubscription<QuerySnapshot>? _commentsSubscription;

  @override
  void initState() {
    super.initState();

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

    _loadInitialData();
  }

  @override
  void dispose() {
    _animationController.dispose();
    _scrollController.dispose();
    _commentsSubscription?.cancel();
    super.dispose();
  }

  Future<void> _loadInitialData() async {
    try {
      // Load all users first
      final usersSnapshot = await FirebaseFirestore.instance.collection('Users').get();
      final newUserCache = <String, Map<String, dynamic>>{};

      for (final userDoc in usersSnapshot.docs) {
        newUserCache[userDoc.id] = userDoc.data() as Map<String, dynamic>;
      }

      // Then load initial comments
      final commentsSnapshot = await FirebaseFirestore.instance
          .collection('ExpertPosts')
          .doc(widget.postId)
          .collection('comments')
          .orderBy('timestamp')
          .get();

      setState(() {
        _userDataCache = newUserCache;
        _cachedComments = commentsSnapshot.docs;
        _isInitialLoadComplete = true;
      });

      // Finally setup real-time updates
      _setupCommentStream();
    } catch (e) {
      print('Initial load error: $e');
      // Consider showing an error to the user
    }
  }

  void _setupCommentStream() {
    _commentsSubscription = FirebaseFirestore.instance
        .collection('ExpertPosts')
        .doc(widget.postId)
        .collection('comments')
        .orderBy('timestamp')
        .snapshots()
        .listen((snapshot) {
      if (mounted) {
        setState(() {
          _cachedComments = snapshot.docs;
        });
      }
    });
  }

  void _replyToMessage(BuildContext context, String shortUserName, String content, String replyUserId, String commentId) {
    _focusNode.requestFocus();

    setState(() {
      _replyingToUserId = replyUserId;
      _repliedContent = content;
      _replyingToCommentId = commentId;
      _replyingToUserName = shortUserName;
    });

    // Scroll to the bottom to show the reply input
    WidgetsBinding.instance.addPostFrameCallback((_) {
      _scrollController.animateTo(
        _scrollController.position.maxScrollExtent,
        duration: const Duration(milliseconds: 300),
        curve: Curves.easeOut,
      );
    });
  }

  void _cancelReply() {
    setState(() {
      _replyingToUserId = null;
      _repliedContent = null;
      _replyingToCommentId = null;
      _replyingToUserName = null;
    });
    commentController.clear();
    _focusNode.unfocus();
  }

  void _animateReplyButton() {
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
        title: const Text('Discussion', style: TextStyle(color: Colors.white)),
        backgroundColor: Colors.tealAccent,
        elevation: 4,
        iconTheme: const IconThemeData(color: Colors.white),
      ),
      body: Column(
        children: [
          Container(
            width: double.infinity,
            padding: const EdgeInsets.all(16.0),
            decoration: BoxDecoration(
              color: Colors.tealAccent[50],
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
              style: TextStyle(fontSize: 20, fontWeight: FontWeight.bold, color: Colors.teal[900]),
            ),
          ),
          Expanded(
            child: !_isInitialLoadComplete
                ? const Center(child: CircularProgressIndicator())
                : ListView.builder(
              controller: _scrollController,
              itemCount: _cachedComments.length,
              itemBuilder: (context, index) {
                final comment = _cachedComments[index].data() as Map<String, dynamic>;
                final userId = comment['userId'];
                final commentId = _cachedComments[index].id;
                final repliedTo = comment['repliedTo'] ?? '';
                final repliedContent = comment['repliedContent'] ?? '';
                final timestamp = comment['timestamp'] != null
                    ? (comment['timestamp'] as Timestamp).toDate()
                    : DateTime.now();

                final userData = _userDataCache[userId] ?? {};
                final fname = userData['Fname'] ?? 'Unknown';
                final lname = userData['Lname'] ?? 'User';
                final fullName = '$fname $lname';

                return Column(
                  children: [
                    Card(
                      key: ValueKey('comment_$commentId'),
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
                            if (repliedTo.isNotEmpty)
                              _buildReplyWidget(repliedTo, repliedContent, comment['repliedToCommentId'] ?? ''),
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
                                IconButton(
                                  icon: Icon(Icons.more_vert, color: Colors.grey[600]),
                                  onPressed: () {
                                    _showCommentMenu(
                                        context,
                                        scaffoldMessengerKey,
                                        _cachedComments[index] as QueryDocumentSnapshot<Map<String, dynamic>>
                                    );
                                  },
                                ),
                              ],
                            ),
                          ],
                        ),
                      ),
                    ),
                    if (index < _cachedComments.length - 1)
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
                            margin: const EdgeInsets.all(4),
                            decoration: BoxDecoration(
                              color: Colors.tealAccent,
                              shape: BoxShape.circle,
                            ),
                            child: IconButton(
                              iconSize: 20,
                              icon: const Icon(Icons.send, color: Colors.white),
                              onPressed: () async {
                                final message = commentController.text.trim();
                                if (message.isEmpty) return;

                                commentController.clear();
                                setState(() {
                                  _replyingToUserId = null;
                                  _repliedContent = null;
                                  _replyingToCommentId = null;
                                  _replyingToUserName = null;
                                });

                                try {
                                  if (currentUserId == null) throw Exception("User not logged in");

                                  final canPost = await WordFilterService().canSendMessage(message, context);
                                  if (!canPost) return;

                                  final userSnapshot = await FirebaseFirestore.instance
                                      .collection('Users')
                                      .doc(currentUserId)
                                      .get();

                                  if (!userSnapshot.exists) throw Exception("User data not found");

                                  final userData = userSnapshot.data()!;
                                  final fullName = "${userData['Fname'] ?? 'Unknown'} ${userData['Lname'] ?? ''}".trim();
                                  final userRegion = userData['Region'] ?? 'Unknown Region';

                                  final commentData = {
                                    'content': message,
                                    'userId': currentUserId,
                                    'username': fullName,
                                    'timestamp': FieldValue.serverTimestamp(),
                                    if (_replyingToUserId != null) 'repliedTo': _replyingToUserId,
                                    if (_repliedContent != null) 'repliedContent': _repliedContent,
                                    if (_replyingToCommentId != null) 'repliedToCommentId': _replyingToCommentId,
                                    if (_replyingToUserName != null) 'repliedToUsername': _replyingToUserName,
                                  };

                                  await FirebaseFirestore.instance
                                      .collection('ExpertPosts')
                                      .doc(widget.postId)
                                      .collection('comments')
                                      .add(commentData);

                                  unawaited(_processMessageForHealthInsights(message, currentUserId, userRegion));

                                } catch (e) {
                                  commentController.text = message;
                                  ScaffoldMessenger.of(context).showSnackBar(
                                    SnackBar(content: Text('Error: ${e.toString()}')),
                                  );
                                }
                              },
                            )
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

  Widget _buildReplyWidget(String repliedTo, String repliedContent, String repliedToCommentId) {
    final repliedUserData = _userDataCache[repliedTo] ?? {};
    final repliedFname = repliedUserData['Fname'] ?? 'Unknown';
    final repliedLname = repliedUserData['Lname'] ?? 'User';
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
            _scrollToMessage(repliedToCommentId);
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

  void _scrollToMessage(String commentId) {
    final index = _cachedComments.indexWhere((comment) => comment.id == commentId);
    if (index != -1) {
      _scrollController.animateTo(
        index * 100.0,
        duration: const Duration(milliseconds: 300),
        curve: Curves.easeInOut,
      );
    }
  }

  String _truncateText(String text, int maxLength) {
    return text.length > maxLength ? '${text.substring(0, maxLength)}...' : text;
  }

  void _showCommentMenu(
      BuildContext context,
      GlobalKey<ScaffoldMessengerState> scaffoldMessengerKey,
      QueryDocumentSnapshot<Map<String, dynamic>> comment,
      ) {
    final currentUserId = FirebaseAuth.instance.currentUser?.uid;
    final commentUserId = comment['userId'];
    final canDelete = currentUserId == commentUserId;

    showModalBottomSheet(
      context: context,
      builder: (context) {
        return Wrap(
          children: [
            if (canDelete)
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
                _showCommentTranslationLanguageSelector(context, scaffoldMessengerKey, comment);
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
    String selectedReason = 'Inappropriate content';

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
        'forumType': 'experts',
      };

      await FirebaseFirestore.instance.collection('reportedExpertComments').add(reportData);

      await FirebaseFirestore.instance
          .collection('Users')
          .doc(reporterId)
          .collection('reportsMade')
          .add(reportData);

      await FirebaseFirestore.instance
          .collection('Users')
          .doc(commentUserId)
          .collection('reportsReceived')
          .add(reportData);

      Navigator.pop(context);
      Navigator.pop(context);

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
      Navigator.pop(context);
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

  void _showCommentTranslationLanguageSelector(BuildContext context, GlobalKey<ScaffoldMessengerState> scaffoldMessengerKey, QueryDocumentSnapshot<Map<String, dynamic>> comment) {
    final postId = comment.reference.parent.parent?.id;
    final commentId = comment.id;

    if (postId == null) {
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
                    _translateCommentAndShowResult(postId, commentId, entry.key);
                  },
                );
              }),
            ],
          ),
        );
      },
    );
  }

  Future<void> _translateCommentAndShowResult(String postId, String commentId, String languageCode) async {
    final FirebaseFirestore firestore = FirebaseFirestore.instance;
    try {
      final commentDoc = await firestore
          .collection('ExpertPosts')
          .doc(postId)
          .collection('comments')
          .doc(commentId)
          .get();

      if (commentDoc.exists) {
        final commentContent = commentDoc['content'];
        final translatedText = await TranslationService.translateText(
          text: commentContent,
          targetLanguage: languageCode,
        );

        late final ScaffoldFeatureController<SnackBar, SnackBarClosedReason> controller;

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
          duration: const Duration(days: 365),
        );

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

    String lowerCaseMessage = messageText.toLowerCase();
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

    final healthInsightsCollection = FirebaseFirestore.instance.collection('HealthInsights');

    for (String category in matchedCategories.keys) {
      for (String keyword in matchedCategories[category]!.keys) {
        try {
          final querySnapshot = await healthInsightsCollection
              .where('category', isEqualTo: category)
              .where('messageType', isEqualTo: 'experts')
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
}