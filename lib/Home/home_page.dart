import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:showcaseview/showcaseview.dart';
import '../Emergency/emergency_page.dart';
import '../Login/login_screen1.dart';
import 'Widgets/profile_drawer.dart';
import 'Widgets/custom_bottom_navbar.dart';
import 'Widgets/homepage_content.dart';

class HomePage extends StatefulWidget {
  @override
  _HomePageState createState() => _HomePageState();
}

class _HomePageState extends State<HomePage> with TickerProviderStateMixin {
  User? currentUser;
  String? userImageUrl;
  bool showProfileDrawer = false;
  late AnimationController _controller;
  late Animation<Offset> _slideAnimation;
  final GlobalKey _fabKey = GlobalKey();

  late AnimationController _textAnimationController;
  late Animation<double> _textFadeAnimation;

  @override
  void initState() {
    super.initState();
    _controller = AnimationController(
      vsync: this,
      duration: Duration(milliseconds: 400),
    );
    _slideAnimation = Tween<Offset>(begin: Offset(0, 1), end: Offset(0, 0.3)).animate(_controller);

    // Initialize the text animation controller
    _textAnimationController = AnimationController(
      vsync: this,
      duration: Duration(milliseconds: 1200), // Duration of one fade cycle
    )..repeat(reverse: true); // Repeat the animation indefinitely, reversing direction

    // Define the fade animation (from 0.5 opacity to 1.0)
    _textFadeAnimation = Tween<double>(begin: 0.2, end: 1.0).animate(
      CurvedAnimation(
        parent: _textAnimationController,
        curve: Curves.easeInOut,
      ),
    );

    _fetchUserData();
    WidgetsBinding.instance.addPostFrameCallback((_) async {
      final prefs = await SharedPreferences.getInstance();
      final bool hasSeenWalkthrough = prefs.getBool('hasSeenEmergencyWalkthrough') ?? false;
      if (!hasSeenWalkthrough && mounted) {
        ShowCaseWidget.of(context)?.startShowCase([_fabKey]);
        await prefs.setBool('hasSeenEmergencyWalkthrough', true);
      }
    });
  }

  // Method to fetch user data and refresh avatar image
  Future<void> _fetchUserData() async {
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
  void _onAvatarTap() async {
    if (currentUser == null) {
      // If no user is logged in, navigate to the login page
      await Navigator.push(
        context,
        MaterialPageRoute(builder: (context) => LoginScreen1()),
      );

      // After login, fetch user data
      _fetchUserData();
    } else {
      // If user is logged in, toggle the profile drawer
      _toggleProfileDrawer();
    }
  }

  void _toggleProfileDrawer() async {
    if (!showProfileDrawer) {
      await _fetchUserData(); // Fetch latest data before opening
    }

    setState(() {
      showProfileDrawer = !showProfileDrawer;
      showProfileDrawer ? _controller.forward() : _controller.reverse();
    });
  }

  @override
  void dispose() {
    _controller.dispose();
    _textAnimationController.dispose(); // Dispose the text animation controller
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.grey[100],
      appBar: AppBar(
        title: Text(
          'Do you have Health needs?',
          style: TextStyle(
            color: Colors.teal,
            fontSize: 18,
            fontWeight: FontWeight.bold,
          ),
        ),
        backgroundColor: Colors.white,
        actions: [
          GestureDetector(
            onTap: _onAvatarTap,
            child: CircleAvatar(
              backgroundImage: userImageUrl != null && userImageUrl!.isNotEmpty
                  ? NetworkImage(userImageUrl!)
                  : null,
              child: userImageUrl == null || userImageUrl!.isEmpty
                  ? Icon(Icons.person, color: Colors.teal)
                  : null,
            ),
          ),
          SizedBox(width: 16),
        ],
        automaticallyImplyLeading: false,
      ),
      body: RefreshIndicator(
        onRefresh: _fetchUserData,
        child: Stack(
          children: [
            Container(
              decoration: BoxDecoration(
                gradient: LinearGradient(
                  begin: Alignment.topCenter,
                  end: Alignment.bottomCenter,
                  colors: [Colors.teal.withOpacity(0.05), Colors.grey[100]!],
                ),
              ),
              child: HomePageContent(),
            ),
            ProfileDrawer(
              controller: _controller,
              slideAnimation: _slideAnimation,
              showProfileDrawer: showProfileDrawer,
            ),
          ],
        ),
      ),
      bottomNavigationBar: CustomBottomNavBar(selectedIndex: 1),
      floatingActionButton: Showcase(
        key: _fabKey,
        description: 'Tap to access Emergency Assistance.',
        child: GestureDetector(
          onTap: () {
            Navigator.push(context, MaterialPageRoute(builder: (context) => EmergencyPage()));
          },
          child: Row(
            mainAxisSize: MainAxisSize.min,
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Container(
                padding: EdgeInsets.symmetric(horizontal: 10, vertical: 5),
                decoration: BoxDecoration(
                  color: Colors.white,
                  borderRadius: BorderRadius.circular(12),
                  boxShadow: [
                    BoxShadow(
                      color: Colors.black26,
                      blurRadius: 4,
                      offset: Offset(0, 2),
                    ),
                  ],
                  border: Border.all(color: Colors.redAccent.withOpacity(0.5)),
                ),
                child: FadeTransition(
                  opacity: _textFadeAnimation,
                  child: Text(
                    'Emergency >>',
                    style: TextStyle(
                      color: Colors.redAccent,
                      fontSize: 14,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                ),
              ),
              SizedBox(width: 8),
              FloatingActionButton(
                onPressed: () {
                  // Keep the FAB's onPressed for consistency, but it will also trigger the GestureDetector
                  Navigator.push(context, MaterialPageRoute(builder: (context) => EmergencyPage()));
                },
                child: Icon(Icons.medical_services, color:Colors.white),
                backgroundColor: Colors.redAccent,
                elevation: 6,
                tooltip: 'Emergency Assistance',
              ),
            ],
          ),
        ),
      ),
      floatingActionButtonLocation: FloatingActionButtonLocation.centerDocked,
    );
  }
}
