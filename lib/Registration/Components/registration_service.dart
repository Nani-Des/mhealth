import 'package:firebase_auth/firebase_auth.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/material.dart';
import 'package:mhealth/Registration/Components/phone_number_dialog.dart';

class RegistrationService {
  static final FirebaseAuth _auth = FirebaseAuth.instance;
  static final FirebaseFirestore _firestore = FirebaseFirestore.instance;

  /// Registers a user and returns the user ID upon successful registration.
  static Future<String?> registerUser(
      BuildContext context,
      String firstName,
      String lastName,
      String email,
      String password,
      ) async {
    try {
      // Register user with Firebase Authentication
      UserCredential userCredential = await _auth.createUserWithEmailAndPassword(
        email: email,
        password: password,
      );

      User? user = userCredential.user;
      if (user != null) {
        // Prompt user for additional information such as phone number
        await PhoneNumberDialog.showPhoneNumberDialog(
          context,
              (phoneNumber, countryCode, region) async {
            // Save user details to Firestore
            await _firestore.collection('Users').doc(user.uid).set({
              'Role': false,
              'Fname': firstName,
              'Lname': lastName,
              'Email': user.email,
              'User ID': user.uid,
              'Mobile Number': '$countryCode $phoneNumber',
              'Region': region,
              'Status': true,
              'User Pic' : 'https://firebasestorage.googleapis.com/v0/b/mhealth-6191e.appspot.com/o/assets%2Fplaceholder.png?alt=media&token=3350f551-d18e-44ed-939a-095b8a66a2a7',
              'CreatedAt': Timestamp.now(),
            });

            print('User registered successfully');
          },
        );

        // Now, proceed to sign in the user automatically after registration
        // Call the _signInUser method to handle the login
        await _signInUser(context, email, password);

        // Return the User ID after login
        return user.uid;
      }
    } catch (e) {
      print('Error during registration: $e');
    }

    // Return null if registration fails
    return null;
  }

  /// Validates email format
  static bool isValidEmail(String email) {
    final emailRegex = RegExp(r'^[a-zA-Z0-9._%+-]+@[a-zA-Z0-9.-]+\.[a-zA-Z]{2,}$');
    return emailRegex.hasMatch(email);
  }

  /// Signs in the user after registration and returns the user ID
  static Future<void> _signInUser(BuildContext context, String email, String password) async {
    try {
      UserCredential userCredential = await _auth.signInWithEmailAndPassword(
        email: email,
        password: password,
      );

      User? user = userCredential.user;
      if (user != null) {
        print('User signed in successfully with User ID: ${user.uid}');
        // Pass the user ID back to the previous screen
        Navigator.pop(context);
        Navigator.pop(context, user.uid);
      }
    } catch (e) {
      print('Error signing in: $e');
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(
        content: Text('Failed to sign in. Please check your email and password.'),
      ));
    }
  }
}
