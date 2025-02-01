import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/services.dart';
import 'package:intl/intl.dart';
import 'expert_post_details_page.dart'; // Import the ExpertPostDetailsPage



class ExpertsCommunityPage extends StatefulWidget {
  const ExpertsCommunityPage({super.key});

  @override
  _ExpertsCommunityPageState createState() => _ExpertsCommunityPageState();
}

class _ExpertsCommunityPageState extends State<ExpertsCommunityPage> {
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
                            _showPostMenu(context, postId, _firestore),
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



void _showPostMenu(BuildContext context, String postId, FirebaseFirestore firestore) {
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
              await firestore.collection('ExpertPosts').doc(postId).delete();  // ✅ FIXED FIRESTORE COLLECTION
            },
          ),
          ListTile(
            leading: const Icon(Icons.copy),
            title: const Text('Copy Post'),
            onTap: () {
              firestore.collection('ExpertPosts').doc(postId).get().then((value) {  // ✅ FIXED FIRESTORE COLLECTION
                if (value.exists) {
                  Clipboard.setData(ClipboardData(text: value['content']));
                  ScaffoldMessenger.of(context).showSnackBar(
                    const SnackBar(content: Text('Post copied to clipboard!')),
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
              ScaffoldMessenger.of(context).showSnackBar(
                const SnackBar(content: Text('Translate feature coming soon!')),
              );
            },
          ),
        ],
      );
    },
  );
}

