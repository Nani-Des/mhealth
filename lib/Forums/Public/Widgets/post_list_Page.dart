import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/cupertino.dart';
import 'package:flutter/material.dart';
import 'package:nhap/Forums/Public/Widgets/post_card.dart';

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