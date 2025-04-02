import 'package:cloud_firestore/cloud_firestore.dart';

class Post {
  final String postId;
  final String userId;
  final String content;
  final String? imageUrl;
  final DateTime timestamp;
  final int likes;

  Post({
    required this.postId,
    required this.userId,
    required this.content,
    this.imageUrl,
    required this.timestamp,
    required this.likes,
  });

  factory Post.fromMap(Map<String, dynamic> data, String documentId) {
    return Post(
      postId: documentId,
      userId: data['User ID'],
      content: data['Content'],
      imageUrl: data['ImageURL'],
      timestamp: (data['Timestamp'] as Timestamp).toDate(),
      likes: data['Likes'],
    );
  }

  Map<String, dynamic> toMap() {
    return {
      'User ID': userId,
      'Content': content,
      'ImageURL': imageUrl,
      'Timestamp': timestamp,
      'Likes': likes,
    };
  }
}
