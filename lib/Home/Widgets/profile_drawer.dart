import 'dart:io';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';
import 'package:google_sign_in/google_sign_in.dart';
import 'package:image_picker/image_picker.dart';
import 'package:nhap/Appointments/referral_form.dart';
import 'package:nhap/Appointments/Referral screens/referral_details_page.dart';
import '../../Login/login_screen1.dart';
import '../../booking_page.dart';
import '../../main.dart';
import '../home_page.dart';
import 'package:provider/provider.dart';

class ProfileDrawer extends StatefulWidget {
  final AnimationController controller;
  final Animation<Offset> slideAnimation;
  final bool showProfileDrawer;

  ProfileDrawer({
    required this.controller,
    required this.slideAnimation,
    required this.showProfileDrawer,
  });

  @override
  _ProfileDrawerState createState() => _ProfileDrawerState();
}

class _ProfileDrawerState extends State<ProfileDrawer> {
  Future<DocumentSnapshot>? _userDataFuture;
  final _picker = ImagePicker();
  File? _imageFile;
  bool _isEditing = false;
  TextEditingController _regionController = TextEditingController();
  TextEditingController _mobileController = TextEditingController();
  TextEditingController _emailController = TextEditingController();
  TextEditingController _firstNameController = TextEditingController();
  TextEditingController _lastNameController = TextEditingController();

  @override
  void initState() {
    super.initState();
    _userDataFuture = _fetchUserData();
  }

  Future<DocumentSnapshot> _fetchUserData() async {
    try {
      User? currentUser = FirebaseAuth.instance.currentUser;
      if (currentUser != null) {
        var userDoc = await FirebaseFirestore.instance
            .collection('Users')
            .doc(currentUser.uid)
            .get();

        if (userDoc.exists) {
          return userDoc;
        } else {
          throw Exception("User data does not exist in Firestore.");
        }
      } else {
        throw Exception("User not logged in");
      }
    } catch (e) {
      print("Error loading user data: $e");
      return Future.error(e);
    }
  }

  Future<void> _pickImage() async {
    final pickedFile = await _picker.pickImage(source: ImageSource.gallery);
    if (pickedFile != null) {
      setState(() {
        _imageFile = File(pickedFile.path);
      });
    }
  }

  Future<void> _updateUserData() async {
    User? currentUser = FirebaseAuth.instance.currentUser;
    if (currentUser != null) {
      final userData = {
        'Fname': _firstNameController.text,
        'Lname': _lastNameController.text,
        'Mobile Number': _mobileController.text,
        'Region': _regionController.text,
        'Email': _emailController.text,
      };

      await FirebaseFirestore.instance
          .collection('Users')
          .doc(currentUser.uid)
          .update(userData);

      setState(() {
        _userDataFuture = _fetchUserData();
        _isEditing = false;
      });
    }
  }

  @override
  void didUpdateWidget(covariant ProfileDrawer oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (widget.showProfileDrawer && !oldWidget.showProfileDrawer) {
      setState(() {
        _userDataFuture = _fetchUserData();
      });
    }
  }

  void _checkAndNavigate(BuildContext context, {bool isReferralForm = false}) async {
    User? user = FirebaseAuth.instance.currentUser;

    if (user == null) {
      Navigator.push(
        context,
        MaterialPageRoute(builder: (context) => LoginScreen1()),
      );
      return;
    }

    DocumentSnapshot userDoc = await FirebaseFirestore.instance
        .collection('Users')
        .doc(user.uid)
        .get();

    bool isDoctor = userDoc.exists && userDoc['Role'] == true;

    if (!isDoctor) {
      showDialog(
        context: context,
        builder: (context) => AlertDialog(
          title: Text("Access Denied"),
          content: Text("Only doctors can access ${isReferralForm ? 'Referral Form' : 'Referrals'}."),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(context),
              child: Text("OK"),
            ),
          ],
        ),
      );
      return;
    }

    Navigator.push(
      context,
      MaterialPageRoute(
        builder: (context) => isReferralForm
            ? ReferralForm()
            : ReferralDetailsPage(userId: user.uid),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    if (!widget.showProfileDrawer) return SizedBox.shrink();

    return SlideTransition(
      position: widget.slideAnimation,
      child: GestureDetector(
        onVerticalDragEnd: (_) => widget.controller.reverse(),
        child: Container(
          height: MediaQuery.of(context).size.height * 0.7,
          decoration: BoxDecoration(
            color: Colors.white,
            borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
            boxShadow: [
              BoxShadow(
                color: Colors.black.withOpacity(0.1),
                blurRadius: 12,
                offset: Offset(0, -6),
              ),
            ],
          ),
          padding: EdgeInsets.all(20),
          child: FutureBuilder<DocumentSnapshot>(
            future: _userDataFuture,
            builder: (context, snapshot) {
              if (snapshot.connectionState == ConnectionState.waiting) {
                return Center(
                  child: CircularProgressIndicator(
                    valueColor: AlwaysStoppedAnimation<Color>(Colors.blue),
                  ),
                );
              }

              if (snapshot.hasError) {
                return Center(
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Icon(Icons.error_outline, color: Colors.red, size: 40),
                      SizedBox(height: 8),
                      Text(
                        'Error: ${snapshot.error}',
                        style: TextStyle(color: Colors.redAccent),
                        textAlign: TextAlign.center,
                      ),
                      TextButton(
                        onPressed: () => setState(() => _userDataFuture = _fetchUserData()),
                        child: Text('Retry', style: TextStyle(color: Colors.teal)),
                      ),
                    ],
                  ),
                );
              }

              if (!snapshot.hasData) {
                return Center(child: Text('No user data found.', style: TextStyle(color: Colors.grey)));
              }

              var userData = snapshot.data!.data() as Map<String, dynamic>;
              String? userImageUrl = userData['User Pic'];
              String? firstName = userData['Fname'];
              String? lastName = userData['Lname'];
              String? mobileNumber = userData['Mobile Number'];
              String? region = userData['Region'];
              String? email = userData['Email'];

              if (_isEditing) {
                _regionController.text = region ?? '';
                _mobileController.text = mobileNumber ?? '';
                _emailController.text = email ?? '';
                _firstNameController.text = firstName ?? '';
                _lastNameController.text = lastName ?? '';
              }

              return SingleChildScrollView(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.center,
                  children: [
                    Row(
                      mainAxisAlignment: MainAxisAlignment.end,
                      children: [
                        TextButton(
                          onPressed: () {
                            if (_isEditing) {
                              _updateUserData();
                            } else {
                              setState(() => _isEditing = true);
                            }
                          },
                          child: Text(
                            _isEditing ? 'Save' : 'Edit',
                            style: TextStyle(color: Colors.teal, fontWeight: FontWeight.bold),
                          ),
                        ),
                      ],
                    ),
                    GestureDetector(
                      onTap: _isEditing ? _pickImage : null,
                      child: Stack(
                        alignment: Alignment.bottomRight,
                        children: [
                          CircleAvatar(
                            radius: 50,
                            backgroundColor: Colors.grey[200],
                            backgroundImage: _imageFile != null
                                ? FileImage(_imageFile!)
                                : (userImageUrl != null && userImageUrl.isNotEmpty
                                ? NetworkImage(userImageUrl)
                                : null) as ImageProvider<Object>?,
                            child: (_imageFile == null && (userImageUrl == null || userImageUrl.isEmpty))
                                ? Icon(Icons.person, size: 50, color: Colors.grey)
                                : null,
                          ),
                          if (_isEditing)
                            Container(
                              padding: EdgeInsets.all(4),
                              decoration: BoxDecoration(
                                color: Colors.teal,
                                shape: BoxShape.circle,
                              ),
                              child: Icon(Icons.edit, color: Colors.white, size: 16),
                            ),
                        ],
                      ),
                    ),
                    SizedBox(height: 16),
                    AnimatedSwitcher(
                      duration: Duration(milliseconds: 300),
                      child: _isEditing
                          ? Card(
                        elevation: 2,
                        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                        child: Padding(
                          padding: EdgeInsets.all(16),
                          child: Column(
                            children: [
                              TextFormField(
                                controller: _firstNameController,
                                decoration: InputDecoration(
                                  labelText: 'First Name',
                                  border: OutlineInputBorder(borderRadius: BorderRadius.circular(8)),
                                ),
                              ),
                              SizedBox(height: 12),
                              TextFormField(
                                controller: _lastNameController,
                                decoration: InputDecoration(
                                  labelText: 'Last Name',
                                  border: OutlineInputBorder(borderRadius: BorderRadius.circular(8)),
                                ),
                              ),
                              SizedBox(height: 12),
                              TextFormField(
                                controller: _regionController,
                                decoration: InputDecoration(
                                  labelText: 'Region',
                                  border: OutlineInputBorder(borderRadius: BorderRadius.circular(8)),
                                ),
                              ),
                              SizedBox(height: 12),
                              TextFormField(
                                controller: _emailController,
                                decoration: InputDecoration(
                                  labelText: 'Email',
                                  border: OutlineInputBorder(borderRadius: BorderRadius.circular(8)),
                                ),
                                keyboardType: TextInputType.emailAddress,
                              ),
                            ],
                          ),
                        ),
                      )
                          : Column(
                        children: [
                          Text(
                            '$firstName $lastName',
                            style: TextStyle(fontSize: 22, fontWeight: FontWeight.bold, color: Colors.teal),
                          ),
                          SizedBox(height: 1),
                          Row(
                            mainAxisAlignment: MainAxisAlignment.center,
                            children: [
                              Text(
                                '$email',
                                style: TextStyle(fontSize: 14, color: Colors.grey[700]),
                              ),
                              Text(
                                '  ||  ',
                                style: TextStyle(fontSize: 14, color: Colors.grey[600]),
                              ),
                              Text(
                                '$region region',
                                style: TextStyle(fontSize: 12, color: Colors.grey[700]),
                              )
                            ],
                          ),
                        ],
                      ),
                    ),
                    SizedBox(height: 5),
                    if (!_isEditing)
                      SingleChildScrollView(
                        scrollDirection: Axis.horizontal,
                        child: Row(
                          mainAxisAlignment: MainAxisAlignment.center,
                          children: [
                            _buildInfoBox(
                              Icons.message_outlined,
                              'Bookings',
                              mobileNumber,
                                  () {
                                User? currentUser = FirebaseAuth.instance.currentUser;
                                if (currentUser != null) {
                                  Navigator.push(
                                    context,
                                    MaterialPageRoute(
                                      builder: (context) => BookingPage(currentUserId: currentUser.uid),
                                    ),
                                  );
                                }
                              },
                            ),
                            SizedBox(width: 20),
                            _buildInfoBox(
                              Icons.person_add,
                              'Refer a Patient',
                              region,
                                  () => _checkAndNavigate(context, isReferralForm: true),
                            ),
                            SizedBox(width: 20),
                            _buildInfoBox(
                              Icons.description,
                              'Referrals',
                              region,
                                  () => _checkAndNavigate(context, isReferralForm: false),
                            ),
                          ],
                        ),
                      ),
                    SizedBox(height: 20),
                    Row(
                      mainAxisAlignment: MainAxisAlignment.spaceEvenly,
                      children: [
                        Semantics(
                          label: 'Delete Account',
                          child: ElevatedButton.icon(
                            onPressed: () {
                              // Handle delete logic here
                            },
                            icon: Icon(Icons.delete, size: 18),
                            label: Text('Delete'),
                            style: ElevatedButton.styleFrom(
                              backgroundColor: Colors.red,
                              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
                              padding: EdgeInsets.symmetric(horizontal: 16, vertical: 12),
                            ),
                          ),
                        ),
                        Semantics(
                          label: 'Logout',
                          child: ElevatedButton.icon(
                            onPressed: () async {
                              try {
                                // Sign out from Google
                                await GoogleSignIn().signOut();
                                // Sign out from Firebase
                                await FirebaseAuth.instance.signOut();
                                // Clear user ID from UserModel
                                Provider.of<UserModel>(context, listen: false).clearUserId();
                                // Navigate to HomePage
                                Navigator.pushReplacement(
                                  context,
                                  MaterialPageRoute(builder: (context) => HomePage()),
                                );
                              } catch (e) {
                                // Handle sign-out errors
                                ScaffoldMessenger.of(context).showSnackBar(
                                  SnackBar(content: Text('Logout failed: $e')),
                                );
                              }
                            },
                            icon: Icon(Icons.logout, size: 18),
                            label: Text('Logout'),
                            style: ElevatedButton.styleFrom(
                              backgroundColor: Colors.tealAccent,
                              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
                              padding: EdgeInsets.symmetric(horizontal: 16, vertical: 12),
                            ),
                          ),
                        ),
                      ],
                    ),
                  ],
                ),
              );
            },
          ),
        ),
      ),
    );
  }

  Widget _buildInfoBox(IconData icon, String label, String? value, VoidCallback? onTap) {
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(12),
      child: Container(
        width: 120,
        padding: EdgeInsets.all(12),
        decoration: BoxDecoration(
          color: Colors.grey[100],
          borderRadius: BorderRadius.circular(12),
          boxShadow: [
            BoxShadow(
              color: Colors.grey.withOpacity(0.2),
              blurRadius: 6,
              offset: Offset(0, 2),
            ),
          ],
        ),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(icon, color: Colors.teal, size: 28, semanticLabel: label), // Added for accessibility
            SizedBox(height: 8),
            Text(
              label,
              style: TextStyle(fontSize: 16, fontWeight: FontWeight.w600, color: Colors.black87),
              textAlign: TextAlign.center,
            ),
            SizedBox(height: 4),
            Text(
              value ?? 'N/A',
              style: TextStyle(fontSize: 12, color: Colors.grey[600]),
              textAlign: TextAlign.center,
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
            ),
          ],
        ),
      ),
    );
  }
}