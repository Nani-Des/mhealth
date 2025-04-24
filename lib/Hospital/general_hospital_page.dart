import 'package:flutter/material.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import '../Appointments/Referral screens/referral_details_page.dart';
import '../Appointments/referral_form.dart';
import '../Auth/auth_screen.dart';
import '../Home/Widgets/custom_bottom_navbar.dart';
import '../Home/Widgets/organization_list_view.dart';
import '../Login/login_screen1.dart';

class GeneralHospitalPage extends StatelessWidget {
  // Function to check if the user is an active doctor
  Future<bool> _isActiveDoctor() async {
    final user = FirebaseAuth.instance.currentUser;
    if (user == null) return false;

    final userDoc = await FirebaseFirestore.instance
        .collection('Users')
        .doc(user.uid)
        .get();

    if (!userDoc.exists) return false;

    final data = userDoc.data()!;
    final bool isDoctor = data['Role'] == true;
    final bool isActive = data['Status'] == true;

    return isDoctor && isActive;
  }

  // Function to get the hospital ID
  Future<String?> _getHospitalId() async {
    final user = FirebaseAuth.instance.currentUser;
    if (user == null) return null;

    final userDoc = await FirebaseFirestore.instance
        .collection('Users')
        .doc(user.uid)
        .get();

    // Safely access 'Hospital ID' field
    return userDoc.exists && userDoc.data() != null
        ? (userDoc.data()!['Hospital ID'] as String?)
        : null;
  }

  // Function to show the redesigned dropdown menu
  void _showDoctorMenu(BuildContext context) async {
    final bool isActiveDoctor = await _isActiveDoctor();
    if (!isActiveDoctor) {
      // Navigate to login screen if not an active doctor
      Navigator.push(
        context,
        MaterialPageRoute(builder: (context) => AuthScreen()),
      );
      return;
    }

    final String? hospitalId = await _getHospitalId();
    if (hospitalId == null) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Hospital ID not found')),
      );
      return;
    }

    // Get screen dimensions for top-right positioning
    final screenSize = MediaQuery.of(context).size;
    final position = RelativeRect.fromLTRB(
      screenSize.width - 160, // Adjust for menu width (~150px) from right edge
      0, // Top edge of the screen (below status bar)
      0, // Right edge of the screen
      screenSize.height, // Allow menu to extend downward
    );

    await showMenu(
      context: context,
      position: position,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(12.0),
      ),
      color: Colors.white,
      elevation: 8.0,
      items: [
        PopupMenuItem(
          value: 'refer',
          child: _MenuItem(
            icon: Icons.send,
            label: 'Refer',
          ),
        ),
        PopupMenuItem(
          value: 'referrals',
          child: _MenuItem(
            icon: Icons.list_alt,
            label: 'Referrals',
          ),
        ),
      ],
    ).then((value) {
      if (value == 'refer') {
        Navigator.push(
          context,
          MaterialPageRoute(builder: (context) => ReferralForm()),
        );
      } else if (value == 'referrals') {
        Navigator.push(
          context,
          MaterialPageRoute(
            builder: (context) => ReferralDetailsPage(hospitalId: hospitalId),
          ),
        );
      }
    });
  }

  @override
  Widget build(BuildContext context) {
    return FutureBuilder<bool>(
      future: _isActiveDoctor(),
      builder: (context, snapshot) {
        bool isActiveDoctor = snapshot.data ?? false;

        return Scaffold(
          body: Container(
            decoration: BoxDecoration(
              gradient: LinearGradient(
                begin: Alignment.topCenter,
                end: Alignment.bottomCenter,
                colors: [Colors.teal.shade100, Colors.teal.shade50],
              ),
            ),
            child: CustomScrollView(
              slivers: [
                SliverAppBar(
                  expandedHeight: 200.0,
                  floating: false,
                  pinned: true,
                  flexibleSpace: FlexibleSpaceBar(
                    title: Text(
                      'Health Facilities',
                      style: TextStyle(
                        color: Colors.white,
                        fontWeight: FontWeight.bold,
                        shadows: [
                          Shadow(
                            blurRadius: 4.0,
                            color: Colors.black26,
                            offset: Offset(2.0, 2.0),
                          ),
                        ],
                      ),
                    ),
                    background: Stack(
                      fit: StackFit.expand,
                      children: [
                        Image.asset(
                          'assets/Images/General Hospital Page.jpeg',
                          fit: BoxFit.cover,
                        ),
                        Container(
                          decoration: BoxDecoration(
                            gradient: LinearGradient(
                              begin: Alignment.topCenter,
                              end: Alignment.bottomCenter,
                              colors: [
                                Colors.black.withOpacity(0.3),
                                Colors.black.withOpacity(0.5),
                              ],
                            ),
                          ),
                        ),
                      ],
                    ),
                  ),
                  backgroundColor: Colors.teal,
                  elevation: 4.0,
                  automaticallyImplyLeading: false,
                  actions: [
                    if (isActiveDoctor)
                      IconButton(
                        icon: Icon(Icons.filter_list, color: Colors.white),
                        onPressed: () => _showDoctorMenu(context),
                        tooltip: 'Doctor Options',
                      ),
                  ],
                ),
                SliverToBoxAdapter(
                  child: Padding(
                    padding: const EdgeInsets.all(16.0),
                    child: SizedBox(
                      height: MediaQuery.of(context).size.height * 0.6,
                      child: OrganizationListView(
                        showSearchBar: true,
                        isReferral: false,
                      ),
                    ),
                  ),
                ),
              ],
            ),
          ),
          bottomNavigationBar: CustomBottomNavBar(selectedIndex: 0),
        );
      },
    );
  }
}

// Custom widget for popup menu items
class _MenuItem extends StatefulWidget {
  final IconData icon;
  final String label;

  const _MenuItem({required this.icon, required this.label});

  @override
  __MenuItemState createState() => __MenuItemState();
}

class __MenuItemState extends State<_MenuItem> with SingleTickerProviderStateMixin {
  late AnimationController _controller;
  late Animation<double> _scaleAnimation;

  @override
  void initState() {
    super.initState();
    _controller = AnimationController(
      duration: const Duration(milliseconds: 200),
      vsync: this,
    );
    _scaleAnimation = Tween<double>(begin: 0.95, end: 1.0).animate(
      CurvedAnimation(parent: _controller, curve: Curves.easeOut),
    );
    _controller.forward();
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return MouseRegion(
      onEnter: (_) => _controller.forward(),
      onExit: (_) => _controller.reverse(),
      child: ScaleTransition(
        scale: _scaleAnimation,
        child: Container(
          padding: EdgeInsets.symmetric(vertical: 12.0, horizontal: 16.0),
          child: Row(
            children: [
              Icon(
                widget.icon,
                color: Colors.teal,
                size: 20.0,
              ),
              SizedBox(width: 12.0),
              Text(
                widget.label,
                style: TextStyle(
                  color: Colors.teal.shade900,
                  fontSize: 16.0,
                  fontWeight: FontWeight.w500,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}