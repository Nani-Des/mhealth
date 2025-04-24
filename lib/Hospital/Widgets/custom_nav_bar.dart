import 'package:flutter/material.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:nhap/Login/login_screen1.dart';
import '../../Appointments/Referral screens/referral_details_page.dart';
import '../../Appointments/referral_form.dart';
import '../../Auth/auth_screen.dart';
import '../../booking_page.dart';
import '../hospital_profile_screen.dart';

class CustomBottomNavBarHospital extends StatefulWidget {
  final String hospitalId;

  CustomBottomNavBarHospital({required this.hospitalId});

  @override
  _CustomBottomNavBarHospitalState createState() => _CustomBottomNavBarHospitalState();
}

class _CustomBottomNavBarHospitalState extends State<CustomBottomNavBarHospital> {
  int _selectedIndex = 0;
  final FirebaseAuth _auth = FirebaseAuth.instance;
  bool _isDoctor = false;
  bool _isActive = false;

  @override
  void initState() {
    super.initState();
    _checkUserRoleAndStatus();
  }

  Future<void> _checkUserRoleAndStatus() async {
    User? user = _auth.currentUser;
    if (user != null) {
      DocumentSnapshot userDoc = await FirebaseFirestore.instance
          .collection('Users')
          .doc(user.uid)
          .get();
      setState(() {
        _isDoctor = userDoc.exists && userDoc['Role'] == true;
        _isActive = userDoc.exists && userDoc['Status'] == true;
      });
    }
  }

  Future<void> _navigateBasedOnAuthStatus(
      BuildContext context, Widget Function(String) targetScreen) async {
    User? currentUser = _auth.currentUser;
    String? userId;

    if (currentUser != null) {
      userId = currentUser.uid;
    } else {
      userId = await Navigator.push<String>(
        context,
        MaterialPageRoute(builder: (context) => AuthScreen()),
      );
    }

    if (userId != null) {
      Navigator.push(
        context,
        MaterialPageRoute(builder: (context) => targetScreen(userId!)),
      );
    }
  }

  Future<String?> _fetchHospitalName(String hospitalId) async {
    try {
      DocumentSnapshot hospitalDoc = await FirebaseFirestore.instance
          .collection('Hospital')
          .doc(hospitalId)
          .get();

      if (hospitalDoc.exists) {
        return hospitalDoc['Hospital Name'] as String?;
      } else {
        print('Hospital with ID $hospitalId not found');
        return null;
      }
    } catch (e) {
      print('Error fetching hospital name: $e');
      return null;
    }
  }

  Future<void> _checkAndNavigate(BuildContext context, String target, {String? hospitalId}) async {
    User? user = _auth.currentUser;

    if (user == null) {
      Navigator.push(
        context,
        MaterialPageRoute(builder: (context) => AuthScreen()),
      );
      return;
    }

    DocumentSnapshot userDoc =
    await FirebaseFirestore.instance.collection('Users').doc(user.uid).get();

    bool isDoctor = userDoc.exists && userDoc['Role'] == true;
    bool isActive = userDoc.exists && userDoc['Status'] == true;
    // Safely access 'Hospital ID' field
    String? userHospitalId = userDoc.exists && userDoc.data() != null
        ? (userDoc.data() as Map<String, dynamic>)['Hospital ID']
        : null;

    switch (target) {
      case 'Refer':
        if (!isDoctor || !isActive) {
          _showAccessDeniedDialog(context, "Only active doctors can make referrals.");
          return;
        }
        String? hospitalName = await _fetchHospitalName(widget.hospitalId);
        String selectedHealthFacility = hospitalName ?? "Loading Hospital..";
        _navigateBasedOnAuthStatus(
          context,
              (userId) => ReferralForm(
            selectedHealthFacility: selectedHealthFacility,
          ),
        );
        break;

      case 'About':
        _navigateBasedOnAuthStatus(
          context,
              (userId) => HospitalProfileScreen(hospitalId: widget.hospitalId),
        );
        break;

      case 'ReferralsOrBookings':
        if (isDoctor && isActive && userHospitalId != null && hospitalId == userHospitalId) {
          _navigateBasedOnAuthStatus(
            context,
                (userId) => ReferralDetailsPage(hospitalId: widget.hospitalId),
          );
        } else {
          _navigateBasedOnAuthStatus(
            context,
                (userId) => BookingPage(currentUserId: userId),
          );
        }
        break;
    }
  }

  void _showAccessDeniedDialog(BuildContext context, String message) {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: Text("Access Denied"),
        content: Text(message),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: Text("OK"),
          ),
        ],
      ),
    );
  }

  void _onItemTapped(int index) {
    setState(() {
      _selectedIndex = index;
    });

    switch (index) {
      case 0: // Refer
        _checkAndNavigate(context, 'Refer');
        break;
      case 1: // About
        _checkAndNavigate(context, 'About');
        break;
      case 2: // Referrals or Bookings
        _checkAndNavigate(context, 'ReferralsOrBookings', hospitalId: widget.hospitalId);
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
                icon: Icon(Icons.person_add),
                label: 'Refer',
              ),
              BottomNavigationBarItem(
                icon: Icon(Icons.info),
                label: 'About',
              ),
              BottomNavigationBarItem(
                icon: Icon(_isDoctor && _isActive ? Icons.group : Icons.event),
                label: _isDoctor && _isActive ? 'Referrals' : 'Bookings',
              ),
            ],
            currentIndex: _selectedIndex,
            onTap: _onItemTapped,
            selectedItemColor: Colors.teal,
            unselectedItemColor: Colors.teal,
            selectedLabelStyle: TextStyle(fontSize: 10.0, fontWeight: FontWeight.bold),
            unselectedLabelStyle: TextStyle(fontSize: 8.0),
            backgroundColor: Colors.transparent,
            elevation: 0,
          ),
        ),
      ),
    );
  }
}