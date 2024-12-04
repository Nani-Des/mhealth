import 'package:flutter/material.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:mhealth/Login/login_screen1.dart';

import '../../Forums/Public/forum.dart';
class CustomBottomNavBar extends StatefulWidget {
  @override
  _CustomBottomNavBarState createState() => _CustomBottomNavBarState();
}

class _CustomBottomNavBarState extends State<CustomBottomNavBar> {
  int _selectedIndex = 0;

  final FirebaseAuth _auth = FirebaseAuth.instance;

  // Check if user is signed in
  Future<void> _navigateBasedOnAuthStatus(BuildContext context, Widget Function(String) targetScreen) async {
    User? currentUser = _auth.currentUser;
    String? userId;

    if (currentUser != null) {
      userId = currentUser.uid; // Get the user ID if signed in
    } else {
      // Navigate to LoginScreen1 and wait for the user ID after login
      userId = await Navigator.push<String>(
        context,
        MaterialPageRoute(builder: (context) => LoginScreen1()),
      );
    }

    if (userId != null) {
      // Navigate to the target screen with the userId
      Navigator.push(
        context,
        MaterialPageRoute(builder: (context) => targetScreen(userId!)),
      );
    }
  }

  void _onItemTapped(int index) {
    setState(() {
      _selectedIndex = index;
    });

    // Navigate to specific pages based on index
    switch (index) {
      case 0:
        _navigateBasedOnAuthStatus(context, (userId) => Forum(userId: userId));
        break;
      case 1:
        _navigateBasedOnAuthStatus(context, (userId) => Forum(userId: userId)); // Replace with appropriate target screen
        break;
      case 2:
        _navigateBasedOnAuthStatus(context, (userId) => Forum(userId: userId)); // Replace with appropriate target screen
        break;
    }
  }

  @override
  Widget build(BuildContext context) {
    return SafeArea(
      child: BottomAppBar(
        shape: CircularNotchedRectangle(),
        notchMargin: 8.0,
        child: Container(
          decoration: BoxDecoration(
            color: Colors.white,
            borderRadius: BorderRadius.only(
              topLeft: Radius.circular(16.0),
              topRight: Radius.circular(16.0),
            ),
            boxShadow: [
              BoxShadow(
                color: Colors.black26,
                blurRadius: 10,
                offset: Offset(0, -1),
              ),
            ],
          ),
          child: BottomNavigationBar(
            items: <BottomNavigationBarItem>[
              BottomNavigationBarItem(
                icon: Icon(Icons.local_hospital),
                label: 'Hospitals',
              ),
              BottomNavigationBarItem(
                icon: Icon(Icons.medical_services),
                label: 'First Aid',
              ),
              BottomNavigationBarItem(
                icon: Icon(Icons.settings),
                label: 'Settings',
              ),
            ],
            currentIndex: _selectedIndex,
            onTap: _onItemTapped,
            selectedItemColor: Colors.blueAccent,
            unselectedItemColor: Colors.grey,
            selectedLabelStyle:
            TextStyle(fontSize: 10.0, fontWeight: FontWeight.bold),
            unselectedLabelStyle: TextStyle(fontSize: 8.0),
            backgroundColor: Colors.transparent,
            elevation: 0,
          ),
        ),
      ),
    );
  }
}
