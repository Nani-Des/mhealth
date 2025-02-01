import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:intl/intl.dart';

class ExpertPostDetailsPage extends StatefulWidget {
  final String postId;
  final String postTitle;

  const ExpertPostDetailsPage({super.key, required this.postId, required this.postTitle});

  @override
  _ExpertPostDetailsPageState createState() => _ExpertPostDetailsPageState();
}

class _ExpertPostDetailsPageState extends State<ExpertPostDetailsPage> with SingleTickerProviderStateMixin {
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
                              onLongPress: () => _showCommentMenu(context, comments[index].reference),
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
}


  void _showCommentMenu(BuildContext context, DocumentReference commentRef) {
    showModalBottomSheet(
      context: context,
      builder: (context) => Wrap(
        children: [
          ListTile(
            leading: const Icon(Icons.delete),
            title: const Text('Delete Comment'),
            onTap: () async {
              await commentRef.delete();
              Navigator.pop(context);
            },
          ),
        ],
      ),
    );
  }