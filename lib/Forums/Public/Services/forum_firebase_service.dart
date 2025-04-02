import 'package:cloud_firestore/cloud_firestore.dart';

class ForumFirebaseService {
  final FirebaseFirestore _firestore = FirebaseFirestore.instance;

  /// Creates a new post with the document ID set as the "Post ID"
  Future<void> createPost(String userId, String content, String? imageUrl) async {
    // Create a new post document with an auto-generated document ID
    DocumentReference postRef = _firestore.collection('Posts').doc(); // Auto-generated ID
    String postId = postRef.id; // Capture the document ID

    await postRef.set({
      'Post ID': postId, // Store the document ID in the "Post ID" field
      'User ID': userId,
      'Content': content,
      'ImageURL': imageUrl,
      'Timestamp': FieldValue.serverTimestamp(),
      'Likes': 0,
    });
  }

  /// Fetches all posts, ordered by timestamp in descending order
  Future<List<Map<String, dynamic>>> fetchPosts() async {
    QuerySnapshot snapshot = await _firestore
        .collection('Posts')
        .orderBy('Timestamp', descending: true)
        .get();

    return snapshot.docs
        .map((doc) => {'id': doc.id, ...doc.data() as Map<String, dynamic>})
        .toList();
  }

  /// Increments the "Likes" count for a specific post
  Future<void> likePost(String postId) async {
    DocumentReference postRef = _firestore.collection('Posts').doc(postId);

    await _firestore.runTransaction((transaction) async {
      DocumentSnapshot snapshot = await transaction.get(postRef);
      int newLikes = (snapshot['Likes'] as int) + 1;
      transaction.update(postRef, {'Likes': newLikes});
    });
  }
}
