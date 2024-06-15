import 'package:firebase_auth/firebase_auth.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/material.dart';
import 'package:mhealth/Registration/Components/phone_number_dialog.dart';

import '../../home.dart';

class RegistrationService {
  static final FirebaseAuth _auth = FirebaseAuth.instance;
  static final FirebaseFirestore _firestore = FirebaseFirestore.instance;

  static Future<void> registerUser(
      BuildContext context,
      String firstName,
      String lastName,
      String email,
      String password,
      ) async {
    try {
      UserCredential userCredential = await _auth.createUserWithEmailAndPassword(
        email: email,
        password: password,
      );

      User? user = userCredential.user;
      if (user != null) {
        await PhoneNumberDialog.showPhoneNumberDialog(context, (phoneNumber, countryCode, region) async {
          await _firestore.collection('Users').doc(user.uid).set({
            'CreatedAt': Timestamp.now(),
            'Role': false,
            'Fname': firstName,
            'Lname': lastName,
            'Email': user.email,
            'User ID': user.uid,
            'Mobile Number': '$countryCode $phoneNumber',
            'Region': region,
            'Status': true,
            'CreateAt': Timestamp.now(),
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

  static bool isValidEmail(String email) {
    final emailRegex = RegExp(r'^[a-zA-Z0-9._%+-]+@[a-zA-Z0-9.-]+\.[a-zA-Z]{2,}$');
    return emailRegex.hasMatch(email);
  }
}
