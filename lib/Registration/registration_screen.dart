import 'package:flutter/material.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/services.dart';
import '../Components/EmailInputFormatter.dart';
import '../Login/login_screen.dart';
import '../home.dart';
import 'Components/phone_number_dialog.dart';

class RegistrationScreen extends StatelessWidget {
  final TextEditingController _firstNameController = TextEditingController();
  final TextEditingController _lastNameController = TextEditingController();
  final TextEditingController _emailController = TextEditingController();
  final TextEditingController _passwordController = TextEditingController();
  final TextEditingController _confirmPasswordController = TextEditingController();

  final FirebaseAuth _auth = FirebaseAuth.instance;
  final FirebaseFirestore _firestore = FirebaseFirestore.instance;

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.white,
      body: SingleChildScrollView(
        child: Padding(
          padding: const EdgeInsets.all(20.0),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              const SizedBox(height: 50.0),
              const Text(
                'Register',
                style: TextStyle(
                  fontSize: 34.0,
                  fontWeight: FontWeight.bold,
                  color: Colors.blueAccent,
                ),
              ),
              const SizedBox(height: 3.0),
              Text(
                'Create your account',
                style: TextStyle(
                  fontSize: 14.0,
                  color: Colors.grey[600],
                ),
              ),
              const SizedBox(height: 20.0),
              Row(
                children: [
                  Expanded(
                    child: _buildTextField(
                      controller: _firstNameController,
                      labelText: 'First Name',
                      icon: Icons.person,
                      obscureText: false,
                      inputFormatters: [
                        FilteringTextInputFormatter.allow(RegExp(r'[a-zA-Z]')),
                      ],
                    ),
                  ),
                  const SizedBox(width: 10.0),
                  Expanded(
                    child: _buildTextField(
                      controller: _lastNameController,
                      labelText: 'Last Name',
                      icon: Icons.person,
                      obscureText: false,
                      inputFormatters: [
                        FilteringTextInputFormatter.allow(RegExp(r'[a-zA-Z]')),
                      ],
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 20.0),
              _buildTextField(
                controller: _emailController,
                labelText: 'Email',
                icon: Icons.email,
                obscureText: false,
                inputFormatters: [
                  EmailInputFormatter(),
                ],
              ),
              const SizedBox(height: 20.0),
              _buildTextField(
                controller: _passwordController,
                labelText: 'Password',
                icon: Icons.lock,
                obscureText: true,
                inputFormatters: [
                  LengthLimitingTextInputFormatter(20),
                ],
              ),
              const SizedBox(height: 20.0),
              _buildTextField(
                controller: _confirmPasswordController,
                labelText: 'Confirm Password',
                icon: Icons.lock,
                obscureText: true,
                inputFormatters: [
                  LengthLimitingTextInputFormatter(20),
                ],
              ),
              const SizedBox(height: 30.0),
              Center(
                child: ElevatedButton(
                  style: ElevatedButton.styleFrom(
                    padding: EdgeInsets.symmetric(horizontal: 80.0, vertical: 15.0), backgroundColor: Colors.blueAccent,
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(30.0),
                    ),
                  ),
                  onPressed: () async {
                    if (_passwordController.text == _confirmPasswordController.text) {
                      if (_isValidEmail(_emailController.text.trim())) {
                        await _registerUser(context);
                      } else {
                        print('Invalid email address');
                      }
                    } else {
                      print('Passwords do not match');
                    }
                  },
                  child: const Text(
                    'Continue',
                    style: TextStyle(
                      fontSize: 18.0,
                      color: Colors.white,
                    ),
                  ),
                ),
              ),
              const SizedBox(height: 20.0),
              Center(
                child: TextButton(
                  onPressed: () {
                    Navigator.push(
                      context,
                      MaterialPageRoute(builder: (context) => LoginScreen()),
                    );
                  },
                  child: Text(
                    'Already have an account? Login',
                    style: TextStyle(
                      color: Colors.blueAccent,
                      fontSize: 16.0,
                    ),
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildTextField({
    required TextEditingController controller,
    required String labelText,
    required IconData icon,
    required bool obscureText,
    List<TextInputFormatter>? inputFormatters,
  }) {
    return TextField(
      controller: controller,
      obscureText: obscureText,
      inputFormatters: inputFormatters,
      decoration: InputDecoration(
        labelText: labelText,
        prefixIcon: Icon(icon, color: Colors.blueAccent),
        border: OutlineInputBorder(
          borderRadius: BorderRadius.circular(10.0),
        ),
        filled: true,
        fillColor: Colors.grey[200],
        contentPadding: EdgeInsets.symmetric(vertical: 20.0, horizontal: 20.0),
      ),
      style: TextStyle(
        fontSize: 16.0,
      ),
    );
  }

  Future<void> _registerUser(BuildContext context) async {
    try {
      UserCredential userCredential = await _auth.createUserWithEmailAndPassword(
        email: _emailController.text.trim(),
        password: _passwordController.text.trim(),
      );

      User? user = userCredential.user;
      if (user != null) {
        await PhoneNumberDialog.showPhoneNumberDialog(context, (phoneNumber, countryCode, region) async {
          await _firestore.collection('Users').doc(user.uid).set({
            'Fname': _firstNameController.text.trim(),
            'Lname': _lastNameController.text.trim(),
            'Email': user.email,
            'User ID': user.uid,
            'Mobile Number': '$countryCode $phoneNumber',
            'Region': region,
            'Status': true,
          });

          print('User registered successfully');
          Navigator.pushReplacement(
            context,
            MaterialPageRoute(builder: (context) => HomeScreen()),
          );
        });
      }
    } catch (e) {
      print(e);
    }
  }

  bool _isValidEmail(String email) {
    final emailRegex = RegExp(r'^[a-zA-Z0-9._%+-]+@[a-zA-Z0-9.-]+\.[a-zA-Z]{2,}$');
    return emailRegex.hasMatch(email);
  }
}
