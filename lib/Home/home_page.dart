import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';
import 'package:mhealth/Hospital/specialty_details.dart';
import '../Emergency/emergency_page.dart';
import '../Emergency/knowledge_packs_page.dart';
import '../Login/login_screen1.dart';
import 'Widgets/profile_drawer.dart';
import 'Widgets/custom_bottom_navbar.dart';
import 'Widgets/homepage_content.dart';

class HomePage extends StatefulWidget {
  @override
  _HomePageState createState() => _HomePageState();
}

class _HomePageState extends State<HomePage> with SingleTickerProviderStateMixin {
  User? currentUser;
  String? userImageUrl;
  bool showProfileDrawer = false;
  late AnimationController _controller;
  late Animation<Offset> _slideAnimation;

  @override
  void initState() {
    super.initState();
    _controller = AnimationController(
      vsync: this,
      duration: Duration(milliseconds: 400),
    );
    _slideAnimation = Tween<Offset>(begin: Offset(0, 1), end: Offset(0, 0.3)).animate(_controller);

    _fetchUserData();
  }

  // Method to fetch user data and refresh avatar image
  void _fetchUserData() async {
    User? user = FirebaseAuth.instance.currentUser;
    if (user != null) {
      final docSnapshot = await FirebaseFirestore.instance.collection('Users').doc(user.uid).get();
      setState(() {
        currentUser = user;
        userImageUrl = docSnapshot['User Pic'] ?? '';  // Load user image if available
      });
    } else {
      setState(() {
        currentUser = null;
        userImageUrl = null;  // If not logged in, clear user image
      });
    }
  }

  // Method to check login status before performing the action
  void _onAvatarTap() {
    if (currentUser == null) {
      // If no user is logged in, show a login prompt
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('Please log in to view your profile'),
          action: SnackBarAction(
            label: 'Log in',
            onPressed: () {
              // Navigate to login screen when user presses 'Log in'
              Navigator.push(context, MaterialPageRoute(builder: (context) => LoginScreen1()));
            },
          ),
        ),
      );
    } else {
      // If user is logged in, toggle the profile drawer
      _toggleProfileDrawer();
    }
  }

  void _toggleProfileDrawer() {
    setState(() {
      showProfileDrawer = !showProfileDrawer;
      showProfileDrawer ? _controller.forward() : _controller.reverse();
    });
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: Text(
          'Do you have Health needs?',
          style: TextStyle(
            color: Colors.grey,
            fontSize: 20,
            fontWeight: FontWeight.w900,
          ),
        ),
        backgroundColor: Colors.white,
        actions: [
          GestureDetector(
            onTap: () {
              _fetchUserData(); // Refresh the user data when the avatar is tapped
              _onAvatarTap(); // Check login status and open profile drawer if logged in
            },
            child: CircleAvatar(
              backgroundImage: userImageUrl != null && userImageUrl!.isNotEmpty
                  ? NetworkImage(userImageUrl!)
                  : null,
              child: userImageUrl == null || userImageUrl!.isEmpty
                  ? Icon(Icons.person, color: Colors.white) // Placeholder icon
                  : null,
            ),
          ),
          SizedBox(width: 16),
        ],
      ),
      body: Stack(
        children: [
          HomePageContent(
            onMessagePressed: () {
              print('Message icon tapped');
            },
          ),
          ProfileDrawer(
            controller: _controller,
            slideAnimation: _slideAnimation,
            showProfileDrawer: showProfileDrawer,
          ),
        ],
      ),
      backgroundColor: Colors.white,
      bottomNavigationBar: CustomBottomNavBar(),
      floatingActionButton: FloatingActionButton(
        onPressed: () {
          Navigator.push(context, MaterialPageRoute(builder: (context) => EmergencyPage()));
        },
        child: Icon(Icons.add),
        backgroundColor: Colors.blueAccent,
      ),
      floatingActionButtonLocation: FloatingActionButtonLocation.centerDocked,
    );
  }
}
