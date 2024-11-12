import 'package:flutter/material.dart';
import 'package:firebase_auth/firebase_auth.dart';
import '../Login/login_screen1.dart';

Future<void> handleBookAppointment(BuildContext context) async {
  final user = FirebaseAuth.instance.currentUser;

  if (user == null) {
    // User is not logged in, navigate to LoginScreen1 and wait for login completion
    final userId = await Navigator.push(
      context,
      MaterialPageRoute(builder: (context) => LoginScreen1()),
    );

    if (userId != null) {
      print('Logged in User ID: $userId');
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Booking feature coming soon for User ID: $userId')),
      );
      // Additional booking logic here
    }
  } else {
    // User is already logged in, proceed with booking
    print('Logged in User ID: ${user.uid}');
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(content: Text('Booking feature coming soon for User ID: ${user.uid}')),
    );
    // Additional booking logic here
  }
}
