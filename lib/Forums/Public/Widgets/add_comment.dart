import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';

class AddCommentScreen extends StatefulWidget {
  final String postId;  // The ID of the post to show comments for

  AddCommentScreen({required this.postId});

  @override
  _AddCommentScreenState createState() => _AddCommentScreenState();
}

class _AddCommentScreenState extends State<AddCommentScreen> {
  TextEditingController _commentController = TextEditingController();
  List<Map<String, dynamic>> _comments = [];
  Map<String, dynamic> _postData = {}; // Store post data

  // Get the current user's ID using Firebase Auth
  String? getCurrentUserId() {
    return FirebaseAuth.instance.currentUser?.uid;
  }

  @override
  void initState() {
    super.initState();
    _fetchPostData();
    _fetchComments();
  }

  // Fetch the post data
  Future<void> _fetchPostData() async {
    DocumentSnapshot postSnapshot = await FirebaseFirestore.instance
        .collection('Posts')
        .doc(widget.postId)
        .get();

    setState(() {
      _postData = postSnapshot.data() as Map<String, dynamic>;
    });
  }

  // Fetch all comments for the post
  Future<void> _fetchComments() async {
    QuerySnapshot snapshot = await FirebaseFirestore.instance
        .collection('Posts')
        .doc(widget.postId)
        .collection('Comments')
        .orderBy('Timestamp', descending: true)
        .get();

    setState(() {
      _comments = snapshot.docs
          .map((doc) => {'id': doc.id, ...doc.data() as Map<String, dynamic>})
          .toList();
    });
  }

  // Add a new comment to the post
  void _addComment() async {
    String? currentUserId = getCurrentUserId();
    if (currentUserId != null && _commentController.text.isNotEmpty) {
      String commentText = _commentController.text;

      // Add comment to Firestore
      await FirebaseFirestore.instance.collection('Posts').doc(widget.postId).collection('Comments').add({
        'Content': commentText,
        'Timestamp': FieldValue.serverTimestamp(),
        'User ID': currentUserId, // Use the current user's ID
      });

      // Refresh the comments
      _commentController.clear();
      _fetchComments();
    }
  }

  // Fetch user profile image and full name from the Users collection using User ID
  Future<Map<String, String?>> _fetchUserDetails(String userId) async {
    DocumentSnapshot userDoc = await FirebaseFirestore.instance.collection('Users').doc(userId).get();
    String? userImageUrl = userDoc['User Pic'];
    String? fullName = '${userDoc['Fname']} ${userDoc['Lname']}';
    return {'imageUrl': userImageUrl, 'fullName': fullName};
  }

  // Function to delete a comment
  Future<void> _deleteComment(String commentId) async {
    String? currentUserId = getCurrentUserId();
    if (currentUserId != null) {
      // Fetch the comment to check if the current user is the one who created it
      DocumentSnapshot commentDoc = await FirebaseFirestore.instance
          .collection('Posts')
          .doc(widget.postId)
          .collection('Comments')
          .doc(commentId)
          .get();

      if (commentDoc.exists) {
        // Get the user ID of the person who created the comment
        String commentUserId = commentDoc['User ID'];

        // If the current user is the one who created the comment, allow deletion
        if (currentUserId == commentUserId) {
          await FirebaseFirestore.instance
              .collection('Posts')
              .doc(widget.postId)
              .collection('Comments')
              .doc(commentId)
              .delete();

          // Refresh the comments list
          _fetchComments();
        } else {
          ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('You can only delete your own comments.')));
        }
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: Text('Comments')),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(8.0),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // Post Content Display
            _postData.isNotEmpty
                ? Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                // Post user and time
                FutureBuilder<Map<String, String?>>(
                  future: _fetchUserDetails(_postData['User ID']),
                  builder: (context, snapshot) {
                    if (snapshot.connectionState == ConnectionState.waiting) {
                      return CircularProgressIndicator();
                    }
                    String? userImageUrl = snapshot.data?['imageUrl'];
                    String? fullName = snapshot.data?['fullName'];

                    return Padding(
                      padding: const EdgeInsets.all(8.0),
                      child: Row(
                        children: [
                          CircleAvatar(
                            radius: 20,
                            backgroundImage: userImageUrl != null && userImageUrl.isNotEmpty
                                ? NetworkImage(userImageUrl)
                                : AssetImage('assets/default_avatar.png') as ImageProvider,
                          ),
                          SizedBox(width: 8),
                          Text(
                            fullName ?? 'User Name',
                            style: TextStyle(fontWeight: FontWeight.bold, fontSize: 16),
                          ),
                          Spacer(),
                          Text(
                            _postData['Timestamp'] != null
                                ? _postData['Timestamp'].toDate().toString()
                                : 'No Timestamp',
                            style: TextStyle(fontSize: 12),
                          ),
                        ],
                      ),
                    );
                  },
                ),

                // Post Content
                Padding(
                  padding: const EdgeInsets.all(8.0),
                  child: Text(
                    _postData['Content'] ?? 'No content',
                    style: TextStyle(fontSize: 16),
                  ),
                ),

                // Post Image (if any)
                if (_postData['ImageURL'] != null)
                  Padding(
                    padding: const EdgeInsets.all(8.0),
                    child: Image.network(
                      _postData['ImageURL'],
                      fit: BoxFit.cover,
                    ),
                  ),
              ],
            )
                : Center(child: CircularProgressIndicator()),

            // Comment Section
            _comments.isNotEmpty
                ? ListView.builder(
              shrinkWrap: true,
              itemCount: _comments.length,
              physics: NeverScrollableScrollPhysics(),
              itemBuilder: (context, index) {
                return FutureBuilder<Map<String, String?>>(
                  future: _fetchUserDetails(_comments[index]['User ID']),
                  builder: (context, snapshot) {
                    if (snapshot.connectionState == ConnectionState.waiting) {
                      return CircularProgressIndicator();
                    }
                    String? userImageUrl = snapshot.data?['imageUrl'];
                    String? fullName = snapshot.data?['fullName'];

                    return GestureDetector(
                      onLongPress: () => _deleteComment(_comments[index]['id']),
                      child: Padding(
                        padding: const EdgeInsets.symmetric(vertical: 8.0),
                        child: Row(
                          children: [
                            CircleAvatar(
                              radius: 20,
                              backgroundImage: userImageUrl != null && userImageUrl.isNotEmpty
                                  ? NetworkImage(userImageUrl)
                                  : AssetImage('assets/default_avatar.png') as ImageProvider,
                            ),
                            SizedBox(width: 8),
                            Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Text(
                                  fullName ?? 'User Name',
                                  style: TextStyle(fontWeight: FontWeight.bold),
                                ),
                                SizedBox(height: 4),
                                Text(
                                  _comments[index]['Content'],
                                  style: TextStyle(fontSize: 14),
                                ),
                                SizedBox(height: 4),
                                Text(
                                  _comments[index]['Timestamp'] != null
                                      ? _comments[index]['Timestamp'].toDate().toString()
                                      : 'No Timestamp',
                                  style: TextStyle(fontSize: 12, color: Colors.grey),
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
            )
                : Padding(
              padding: const EdgeInsets.all(8.0),
              child: Text('No comments yet.', style: TextStyle(color: Colors.grey)),
            ),

            // Add Comment Section
            Padding(
              padding: const EdgeInsets.symmetric(vertical: 10),
              child: Row(
                children: [
                  Expanded(
                    child: TextField(
                      controller: _commentController,
                      decoration: InputDecoration(
                        hintText: 'Add a comment...',
                        border: OutlineInputBorder(),
                      ),
                    ),
                  ),
                  IconButton(
                    icon: Icon(Icons.send),
                    onPressed: _addComment,
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}
