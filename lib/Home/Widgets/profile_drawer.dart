import 'dart:io';

import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';
import 'package:image_picker/image_picker.dart';

import '../home_page.dart';

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
    User? currentUser = FirebaseAuth.instance.currentUser;
    if (currentUser != null) {
      return FirebaseFirestore.instance
          .collection('Users')
          .doc(currentUser.uid)
          .get();
    }
    throw Exception("User not logged in");
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

      // Refresh the data in the UI
      setState(() {
        _userDataFuture = _fetchUserData();
        _isEditing = false;
      });
    }
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
            borderRadius: BorderRadius.only(
              topLeft: Radius.circular(20),
              topRight: Radius.circular(20),
            ),
            boxShadow: [
              BoxShadow(
                color: Colors.black26,
                blurRadius: 10,
                offset: Offset(0, -5),
              ),
            ],
          ),
          padding: EdgeInsets.symmetric(vertical: 20, horizontal: 16),
          child: FutureBuilder<DocumentSnapshot>(
            future: _userDataFuture,
            builder: (context, snapshot) {
              if (snapshot.connectionState == ConnectionState.waiting) {
                return Center(child: CircularProgressIndicator());
              }

              if (snapshot.hasError || !snapshot.hasData) {
                return Center(child: Text('Error loading user data'));
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

              return Column(
                mainAxisAlignment: MainAxisAlignment.start,
                children: [
                  Align(
                    alignment: Alignment.topRight,
                    child: TextButton(
                      onPressed: () {
                        if (_isEditing) {
                          _updateUserData();
                        } else {
                          setState(() {
                            _isEditing = true;
                          });
                        }
                      },
                      child: Text(
                        _isEditing ? 'Save' : 'Edit',
                        style: TextStyle(color: Colors.blue),
                      ),
                    ),
                  ),
                  GestureDetector(
                    onTap: _isEditing ? _pickImage : null,
                    child: CircleAvatar(
                      radius: 40,
                      backgroundImage: _imageFile != null
                          ? FileImage(_imageFile!)
                          : (userImageUrl != null && userImageUrl.isNotEmpty
                          ? NetworkImage(userImageUrl)
                          : null) as ImageProvider<Object>?,
                      child: (_imageFile == null && (userImageUrl == null || userImageUrl.isEmpty))
                          ? Icon(Icons.person, size: 40)
                          : null,
                    ),
                  ),
                  SizedBox(height: 10),
                  if (_isEditing)
                    ...[
                      TextField(
                        controller: _firstNameController,
                        decoration: InputDecoration(labelText: 'First Name'),
                      ),
                      TextField(
                        controller: _lastNameController,
                        decoration: InputDecoration(labelText: 'Last Name'),
                      ),
                      TextField(
                        controller: _mobileController,
                        decoration: InputDecoration(labelText: 'Mobile Number'),
                        keyboardType: TextInputType.phone,
                      ),
                      TextField(
                        controller: _regionController,
                        decoration: InputDecoration(labelText: 'Region'),
                      ),
                      TextField(
                        controller: _emailController,
                        decoration: InputDecoration(labelText: 'Email'),
                        keyboardType: TextInputType.emailAddress,
                      ),
                    ]
                  else
                    Row(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        Text('$firstName $lastName', style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold)),
                        SizedBox(width: 8),
                        Text('-', style: TextStyle(fontSize: 15, fontWeight: FontWeight.bold)),
                        SizedBox(width: 8),
                        Text('$region region', style: TextStyle(fontSize: 10)),
                        SizedBox(width: 1),
                        Text('||', style: TextStyle(fontSize: 15, fontWeight: FontWeight.bold)),
                        SizedBox(width: 1),
                        Text('$email', style: TextStyle(fontSize: 10)),
                      ],
                    ),
                  SizedBox(height: 10),
                  if (!_isEditing)
                    Row(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        _buildInfoBox(Icons.message_outlined, 'Bookings', mobileNumber),
                        SizedBox(width: 16),
                        _buildInfoBox(Icons.location_pin, 'Region', region),
                      ],
                    ),
                  SizedBox(height: 10),
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      ElevatedButton(
                        onPressed: () {
                          // Handle delete logic here
                        },
                        child: Text('Delete'),
                        style: ElevatedButton.styleFrom(
                          backgroundColor: Colors.red,
                        ),
                      ),
                      ElevatedButton(
                        onPressed: () async {
                          await FirebaseAuth.instance.signOut();
                          Navigator.pushReplacement(
                            context,
                            MaterialPageRoute(builder: (context) => HomePage()),
                          );
                        },
                        child: Text('Logout'),
                        style: ElevatedButton.styleFrom(
                          backgroundColor: Colors.blue,
                        ),
                      ),
                    ],
                  ),
                ],
              );
            },
          ),
        ),
      ),
    );
  }

  Widget _buildInfoBox(IconData icon, String label, String? value) {
    return Container(
      padding: EdgeInsets.all(8),
      decoration: BoxDecoration(
        color: Colors.grey[100],
        borderRadius: BorderRadius.circular(6),
        boxShadow: [
          BoxShadow(
            color: Colors.grey.shade200,
            offset: Offset(1, 1),
            blurRadius: 4,
          ),
        ],
      ),
      child: Column(
        children: [
          Icon(icon, color: Colors.blueAccent, size: 24),
          SizedBox(height: 8),
          Text(
            label,
            style: TextStyle(fontSize: 16, fontWeight: FontWeight.w500, color: Colors.black87),
          ),
          SizedBox(height: 4),
          Text(
            value ?? 'Not available',
            style: TextStyle(fontSize: 12, color: Colors.black54),
            textAlign: TextAlign.center,
          ),
        ],
      ),
    );
  }
}
