import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:showcaseview/showcaseview.dart';
import '../Auth/auth_screen.dart';
import '../ChatModule/chat_module.dart';
import '../Emergency/emergency_page.dart';
import '../Login/login_screen1.dart';
import 'Widgets/profile_drawer.dart';
import 'Widgets/custom_bottom_navbar.dart';
import 'Widgets/homepage_content.dart';
import 'package:nhap/ml_ui/screens/disease_prediction_screen.dart';

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
  late AnimationController _animationController;

  @override
  void initState() {
    super.initState();

    // Initialize animation controllers in order
    _controller = AnimationController(
      vsync: this,
      duration: Duration(milliseconds: 400),
    );

    _slideAnimation = Tween<Offset>(
      begin: Offset(0, 1),
      end: Offset(0, 0.3),
    ).animate(_controller);

    _textAnimationController = AnimationController(
      vsync: this,
      duration: Duration(milliseconds: 1200),
    )..repeat(reverse: true);

    _textFadeAnimation = Tween<double>(
      begin: 0.2,
      end: 1.0,
    ).animate(
      CurvedAnimation(
        parent: _textAnimationController,
        curve: Curves.easeInOut,
      ),
    );

    _animationController = AnimationController(
      vsync: this,
      duration: Duration(seconds: 2),
    )..repeat(reverse: true);

    WidgetsBinding.instance.addPostFrameCallback((_) {
      CallService().setContext(context);
    });

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
        MaterialPageRoute(builder: (context) => AuthScreen()),
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
    _animationController.dispose();
    _textAnimationController.dispose();
    _controller.dispose();
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
              child: Column(
                children: [
                  // _buildAIDetectionButton(),
                  Expanded(child: HomePageContent()),
                ],
              ),
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

  // Widget _buildAIDetectionButton() {
  //   return Padding(
  //     padding: const EdgeInsets.symmetric(horizontal: 16.0, vertical: 10.0),
  //     child: Stack(
  //       alignment: Alignment.center,
  //       children: [
  //         // Base glow (static)
  //         Container(
  //           decoration: BoxDecoration(
  //             borderRadius: BorderRadius.circular(16),
  //             boxShadow: [
  //               BoxShadow(
  //                 color: Colors.teal.withOpacity(0.2),
  //                 blurRadius: 8,
  //                 spreadRadius: 2,
  //               ),
  //             ],
  //           ),
  //         ),
  //         // Animated glow
  //         AnimatedBuilder(
  //           animation: _animationController,
  //           builder: (context, child) {
  //             return Container(
  //               decoration: BoxDecoration(
  //                 borderRadius: BorderRadius.circular(16),
  //                 boxShadow: [
  //                   BoxShadow(
  //                     color: Colors.teal.withOpacity(0.4 * _animationController.value),
  //                     blurRadius: 15 * _animationController.value,
  //                     spreadRadius: 5 * _animationController.value,
  //                   ),
  //                 ],
  //               ),
  //             );
  //           },
  //         ),
  //         // The actual button
  //         ElevatedButton.icon(
  //           onPressed: () {
  //             Navigator.push(
  //               context,
  //               MaterialPageRoute(builder: (context) => DiseasePredictionScreen()),
  //             );
  //           },
  //           icon: Icon(Icons.psychology_alt, color: Colors.white, size: 22),
  //           label: Text(
  //             'AI Disease Detection',
  //             style: TextStyle(
  //               fontWeight: FontWeight.bold,
  //               fontSize: 16,
  //               letterSpacing: 0.5,
  //               shadows: [
  //                 Shadow(
  //                   color: Colors.white.withOpacity(0.3),
  //                   blurRadius: 2,
  //                   offset: Offset(0, 1),
  //                 ),
  //               ],
  //             ),
  //           ),
  //           style: ElevatedButton.styleFrom(
  //             backgroundColor: Colors.teal[700],
  //             foregroundColor: Colors.white,
  //             padding: EdgeInsets.symmetric(vertical: 10, horizontal: 24),
  //             shape: RoundedRectangleBorder(
  //               borderRadius: BorderRadius.circular(16),
  //             ),
  //             elevation: 8,
  //             shadowColor: Colors.teal.withOpacity(0.3),
  //           ),
  //         ),
  //       ],
  //     ),
  //   );
  // }
}
