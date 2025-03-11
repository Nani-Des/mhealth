import 'package:flutter/material.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:mhealth/Login/login_screen1.dart';
import '../../Appointments/Referral screens/referral_details_page.dart';
import '../../Appointments/referral_form.dart';
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

  Future<void> _navigateBasedOnAuthStatus(
      BuildContext context, Widget Function(String) targetScreen) async {
    User? currentUser = _auth.currentUser;
    String? userId;

    if (currentUser != null) {
      userId = currentUser.uid;
    } else {
      userId = await Navigator.push<String>(
        context,
        MaterialPageRoute(builder: (context) => LoginScreen1()),
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
        MaterialPageRoute(builder: (context) => LoginScreen1()),
      );
      return;
    }

    DocumentSnapshot userDoc =
    await FirebaseFirestore.instance.collection('Users').doc(user.uid).get();

    bool isDoctor = userDoc.exists && userDoc['Role'] == true;
    String? userHospitalId = userDoc.exists ? userDoc['Hospital ID'] : null;

    switch (target) {
      case 'Refer':
        if (!isDoctor) {
          _showAccessDeniedDialog(context, "Only doctors can make referrals.");
          return;
        }
        // Fetch hospital name and pass it to ReferralForm
        String? hospitalName = await _fetchHospitalName(widget.hospitalId);
        _navigateBasedOnAuthStatus(
          context,
              (userId) => ReferralForm(
            selectedHealthFacility: hospitalName ?? "Unknown Hospital",
          ),
        );
        break;

      case 'About':
        _navigateBasedOnAuthStatus(
          context,
              (userId) => HospitalProfileScreen(hospitalId: widget.hospitalId),
        );
        break;

      case 'Referrals':
        if (!isDoctor) {
          _showAccessDeniedDialog(context, "Only doctors can view referrals.");
          return;
        }
        if (hospitalId != null && userHospitalId != null && hospitalId == userHospitalId) {
          _navigateBasedOnAuthStatus(
            context,
                (userId) => ReferralDetailsPage(hospitalId: widget.hospitalId),
          );
        } else {
          _showAccessDeniedDialog(context, "You can only view referrals from your hospital.");
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
      case 2: // Referrals
        _checkAndNavigate(context, 'Referrals', hospitalId: widget.hospitalId);
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
                icon: Icon(Icons.group),
                label: 'Referrals',
              ),
            ],
            currentIndex: _selectedIndex,
            onTap: _onItemTapped,
            selectedItemColor: Colors.teal,
            unselectedItemColor: Colors.grey,
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