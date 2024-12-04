import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'delete_post_service.dart';
import 'full_screen.dart';
import 'add_comment.dart';

class PostCard extends StatefulWidget {
  final Map<String, dynamic> postData; // Declare postData as a required field
  final Function refreshCallback; // Callback to refresh the parent widget after deletion

  // Constructor to receive the postData and refreshCallback
  PostCard({required this.postData, required this.refreshCallback});

  @override
  _PostCardState createState() => _PostCardState();
}

class _PostCardState extends State<PostCard> {
  final DeletePostService _deletePostService = DeletePostService();
  final double _fontSize = 16.0;
  bool _isLiked = false;

  @override
  void initState() {
    super.initState();
    _checkIfLiked();
  }

  // Function to check if the user has already liked the post
  void _checkIfLiked() async {
    String userId = 'user_id'; // Replace this with the actual user ID (from Firebase Auth or similar)

    // Check if the user's ID exists in the Likes subcollection for this post
    DocumentSnapshot postSnapshot = await FirebaseFirestore.instance
        .collection('Posts')
        .doc(widget.postData['id'])
        .collection('Likes')
        .doc(userId)
        .get();

    setState(() {
      _isLiked = postSnapshot.exists; // If document exists, the user has liked the post
    });
  }

  // Function to like the post and refresh the data
  void _likePost() async {
    if (!_isLiked) {
      // Add the user's ID to the "Likes" subcollection for the post
      String userId = 'user_id'; // Replace with the actual user ID
      await FirebaseFirestore.instance
          .collection('Posts')
          .doc(widget.postData['id'])
          .collection('Likes')
          .doc(userId)
          .set({
        'User ID': userId,
      });

      // Increment the "Likes" count for the post
      await FirebaseFirestore.instance.collection('Posts').doc(widget.postData['id']).update({
        'Likes': widget.postData['Likes'] + 1,
      });

      setState(() {
        _isLiked = true; // Update local state to reflect the like
        widget.postData['Likes'] += 1; // Update the likes count locally
      });
    }
  }

  // Fetch user profile image and full name from the Users collection
  Future<Map<String, String?>> _fetchUserDetails(String userId) async {
    DocumentSnapshot userDoc = await FirebaseFirestore.instance.collection('Users').doc(userId).get();
    String? userImageUrl = userDoc['User Pic'];
    String? userFullName = '${userDoc['Fname']} ${userDoc['Lname']}';
    return {'imageUrl': userImageUrl, 'fullName': userFullName};
  }

  // Function to open the image in full-screen view
  void _viewImage(String imageUrl) {
    Navigator.push(
      context,
      MaterialPageRoute(
        builder: (context) => FullScreenImageView(imageUrl: imageUrl),
      ),
    );
  }

  // Function to navigate to the AddCommentScreen
  void _viewComments() {
    Navigator.push(
      context,
      MaterialPageRoute(
        builder: (context) => AddCommentScreen(postId: widget.postData['id']),
      ),
    );
  }

  // Function to handle long press on the post to show the delete dialog
  void _onLongPressPost() {
    _deletePostService.deletePost(context, widget.postData['id']).then((_) {
      // After the post is deleted, refresh the page
      widget.refreshCallback();
    });
  }

  @override
  Widget build(BuildContext context) {
    return Card(
      margin: EdgeInsets.all(8.0),
      color: Colors.black87, // Dark background color
      child: GestureDetector(
        onLongPress: _onLongPressPost, // Handle long press on the post to show delete dialog
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // Row for Avatar Image and User's Full Name at the top-left corner
            FutureBuilder<Map<String, String?>>(
              future: _fetchUserDetails(widget.postData['User ID']),
              builder: (context, snapshot) {
                if (snapshot.connectionState == ConnectionState.waiting) {
                  return Center(child: CircularProgressIndicator());
                }
                if (snapshot.hasError) {
                  return Center(child: Text('Error: ${snapshot.error}'));
                }

                var userDetails = snapshot.data!;
                return ListTile(
                  leading: CircleAvatar(
                    backgroundImage: NetworkImage(userDetails['imageUrl'] ?? ''),
                    radius: 20,
                  ),
                  title: Text(
                    userDetails['fullName'] ?? 'Anonymous',
                    style: TextStyle(color: Colors.white),
                  ),
                );
              },
            ),
            // Post Image (if any)
            if (widget.postData['ImageURL'] != null)
              Padding(
                padding: const EdgeInsets.all(8.0),
                child: GestureDetector(
                  onTap: () => _viewImage(widget.postData['ImageURL']),
                  child: Container(
                    width: double.infinity,
                    height: 200,
                    decoration: BoxDecoration(
                      borderRadius: BorderRadius.circular(8.0),
                      color: Colors.grey[800],
                    ),
                    child: ClipRRect(
                      borderRadius: BorderRadius.circular(8.0),
                      child: Image.network(
                        widget.postData['ImageURL'],
                        fit: BoxFit.cover,
                      ),
                    ),
                  ),
                ),
              ),
            // Likes, Comments, and Other Icons Section
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 8.0, vertical: 10),
              child: Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  // Like Button with the number of likes
                  Row(
                    children: [
                      IconButton(
                        icon: Icon(
                          Icons.thumb_up,
                          color: _isLiked ? Colors.blue : Colors.white,
                        ),
                        onPressed: _likePost,
                      ),
                      Text(
                        '${widget.postData['Likes']}',
                        style: TextStyle(color: Colors.white, fontSize: _fontSize),
                      ),
                    ],
                  ),
                  // Comment Button
                  IconButton(
                    icon: Icon(Icons.comment, color: Colors.white),
                    onPressed: _viewComments,
                  ),
                  // Additional Icons
                  IconButton(
                    icon: Icon(Icons.share, color: Colors.white),
                    onPressed: () {
                      // Share functionality here
                    },
                  ),
                  IconButton(
                    icon: Icon(Icons.report, color: Colors.white),
                    onPressed: () {
                      // Report functionality here
                    },
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

class PostListPage extends StatefulWidget {
  @override
  _PostListPageState createState() => _PostListPageState();
}

class _PostListPageState extends State<PostListPage> {
  List<Map<String, dynamic>> _posts = []; // Store posts data

  @override
  void initState() {
    super.initState();
    _loadPosts(); // Load posts when the page is first loaded
  }

  // Function to load posts from Firebase
  void _loadPosts() async {
    QuerySnapshot snapshot = await FirebaseFirestore.instance.collection('Posts').get();
    setState(() {
      _posts = snapshot.docs.map((doc) => doc.data() as Map<String, dynamic>).toList();
    });
  }

  // Function to refresh the page contents
  Future<void> _refreshPosts() async {
    _loadPosts(); // Refresh the posts by re-fetching them from Firebase
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: Text('Posts')),
      body: RefreshIndicator(
        onRefresh: _refreshPosts, // Trigger the refresh when the user drags the page down
        child: ListView.builder(
          itemCount: _posts.length,
          itemBuilder: (context, index) {
            return PostCard(
              postData: _posts[index],
              refreshCallback: _refreshPosts, // Pass the refresh callback to the PostCard widget
            );
          },
        ),
      ),
    );
  }
}
