import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';

class DeletePostService {
  // Function to delete a post and its associated likes and comments
  Future<void> deletePost(BuildContext context, String postId) async {
    try {
      // Fetch the current logged-in user ID
      String currentUserId = FirebaseAuth.instance.currentUser!.uid;

      // Fetch the post from the Firestore collection
      DocumentSnapshot postSnapshot = await FirebaseFirestore.instance.collection('Posts').doc(postId).get();

      // Check if the post exists and compare the User ID field
      if (postSnapshot.exists) {
        String postOwnerId = postSnapshot['User ID']; // User ID in the post document

        // If the current user is the owner of the post
        if (currentUserId == postOwnerId) {
          // Show confirmation dialog to delete the post
          bool? confirmDelete = await showDialog<bool>(
            context: context,
            builder: (context) => AlertDialog(
              title: Text('Delete Post'),
              content: Text('Are you sure you want to delete this post?'),
              actions: [
                TextButton(
                  onPressed: () {
                    Navigator.pop(context, false); // Close dialog and don't delete
                  },
                  child: Text('Cancel'),
                ),
                TextButton(
                  onPressed: () {
                    Navigator.pop(context, true); // Close dialog and delete the post
                  },
                  child: Text('Delete'),
                ),
              ],
            ),
          );

          // If user confirms deletion, proceed to delete the post
          if (confirmDelete == true) {
            await _performDelete(postId);
            ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('Post deleted successfully.')));
          }
        } else {
          ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('You can only delete your own posts.')));
        }
      } else {
        ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('Post does not exist.')));
      }
    } catch (e) {
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('Failed to delete post.')));
    }
  }

  // Perform the actual deletion of the post, likes, and comments
  Future<void> _performDelete(String postId) async {
    try {
      // Delete the post
      await FirebaseFirestore.instance.collection('Posts').doc(postId).delete();

      // Delete comments associated with the post
      await FirebaseFirestore.instance
          .collection('Posts')
          .doc(postId)
          .collection('Comments')
          .get()
          .then((snapshot) {
        for (var doc in snapshot.docs) {
          doc.reference.delete(); // Delete each comment
        }
      });

      // Delete likes associated with the post
      await FirebaseFirestore.instance
          .collection('Posts')
          .doc(postId)
          .collection('Likes')
          .get()
          .then((snapshot) {
        for (var doc in snapshot.docs) {
          doc.reference.delete(); // Delete each like
        }
      });
    } catch (e) {
      throw Exception("Error deleting post: $e");
    }
  }
}
