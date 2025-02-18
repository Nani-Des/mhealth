import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import '../../Hospital/doctor_profile.dart';
import 'Services/forum_firebase_service.dart';
import 'Widgets/create_post_dialog.dart';
import 'Widgets/post_card.dart';

class Forum extends StatefulWidget {
  final String userId;

  const Forum({required this.userId});
  @override
  _ForumPageState createState() => _ForumPageState();
}

class _ForumPageState extends State<Forum> {
  final ForumFirebaseService _firebaseService = ForumFirebaseService();
  List<Map<String, dynamic>> _posts = [];
  String? _userProfileImageUrl;

  @override
  void initState() {
    super.initState();
    _loadPosts();
    _loadUserProfile();
  }

  Future<void> _loadPosts() async {
    List<Map<String, dynamic>> posts = await _firebaseService.fetchPosts();
    setState(() {
      _posts = posts;
    });
  }

  Future<void> _loadUserProfile() async {
    DocumentSnapshot userDoc = await FirebaseFirestore.instance
        .collection('Users')
        .doc(widget.userId)
        .get();

    if (userDoc.exists) {
      setState(() {
        _userProfileImageUrl = userDoc['User Pic'] ?? '';
      });
    }
  }

  void _createPost() {
    showDialog(
      context: context,
      builder: (context) => CreatePostDialog(userId: widget.userId),
    ).then((_) => _loadPosts()); // Reload posts after creating a new post
  }

  void _navigateToProfile() async {
    DocumentSnapshot userDoc = await FirebaseFirestore.instance
        .collection('Users')
        .doc(widget.userId)
        .get();

    if (userDoc.exists && userDoc['Role'] == true) {
      Navigator.push(
        context,
        MaterialPageRoute(
          builder: (context) => DoctorProfileScreen(userId: widget.userId, isReferral: false),
        ),
      );
    } else {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('You are not authorized to view this profile.')),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: Text('Home'),
        actions: [
          GestureDetector(
            onTap: _navigateToProfile,
            child: Padding(
              padding: const EdgeInsets.only(right: 16.0),
              child: CircleAvatar(
                backgroundImage: _userProfileImageUrl != null && _userProfileImageUrl!.isNotEmpty
                    ? NetworkImage(_userProfileImageUrl!)
                    : AssetImage('assets/default_avatar.png') as ImageProvider,
                radius: 20,
              ),
            ),
          ),
        ],
      ),
      body: ListView.builder(
        itemCount: _posts.length,
        itemBuilder: (context, index) {
          return PostCard(
            postData: _posts[index],
            refreshCallback: _loadPosts, // Pass the refreshCallback here
          );
        },
      ),
      floatingActionButton: FloatingActionButton(
        onPressed: _createPost,
        child: Icon(Icons.add),
      ),
    );
  }
}
