import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:intl/intl.dart';
import '../Appointments/AppointmentScreen.dart';
import '../Login/login_screen1.dart';

Future<void> handleBookAppointment(
    BuildContext context, {
      required String doctorId,
      required String hospitalId,
      required DateTime selectedDate,
    }) async {
  final user = FirebaseAuth.instance.currentUser;

  if (user == null) {
    // User is not logged in, navigate to LoginScreen1 and wait for login completion
    final userId = await Navigator.push(
      context,
      MaterialPageRoute(builder: (context) => LoginScreen1()),
    );

    if (userId != null) {
      await _bookAppointment(
        context,
        patientId: userId,
        doctorId: doctorId,
        hospitalId: hospitalId,
        selectedDate: selectedDate,
      );
    }
  } else {
    // User is already logged in, proceed with booking
    await _bookAppointment(
      context,
      patientId: user.uid,
      doctorId: doctorId,
      hospitalId: hospitalId,
      selectedDate: selectedDate,
    );
  }
}

Future<void> _bookAppointment(
    BuildContext context, {
      required String patientId,
      required String doctorId,
      required String hospitalId,
      required DateTime selectedDate,
    }) async {
  // Prevent a doctor from booking an appointment with themselves
  if (patientId == doctorId) {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(content: Text('You cannot book an appointment with yourself!')),
    );
    return;
  }

  final TextEditingController reasonController = TextEditingController();

  // Show a dialog to get the reason for booking
  final bool isConfirmed = await showDialog(
    context: context,
    builder: (context) {
      return AlertDialog(
        title: Text('Enter Full Name and Why you want to see the Doctor?'),
        content: TextField(
          controller: reasonController,
          maxLines: 3,
          decoration: InputDecoration(
            hintText: 'Enter your reason here',
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(context).pop(false),
            child: Text('Cancel'),
          ),
          TextButton(
            onPressed: () {
              if (reasonController.text.trim().isEmpty) {
                ScaffoldMessenger.of(context).showSnackBar(
                  SnackBar(content: Text('Reason is required!')),
                );
                return;
              }
              Navigator.of(context).pop(true);
            },
            child: Text('Confirm'),
          ),
        ],
      );
    },
  );

  if (isConfirmed == null || !isConfirmed) return;

  final reason = reasonController.text.trim();

  try {
    final selectedTimestamp = Timestamp.fromDate(selectedDate); // Convert to Timestamp

    // Fetch current bookings from Firestore
    final patientDoc = FirebaseFirestore.instance.collection('Bookings').doc(patientId);
    final patientSnapshot = await patientDoc.get();

    // Check if patient has any existing bookings or if document doesn't exist
    if (!patientSnapshot.exists) {
      // If the document doesn't exist, create an empty 'Bookings' array
      await patientDoc.set({
        'Bookings': [],
      });
    }

    // After ensuring the document exists, we fetch the current bookings
    final bookings = patientSnapshot.data()?['Bookings'] ?? [];

    for (var booking in bookings) {
      final existingDate = booking['date']; // This might be a Timestamp or String

      // Ensure existingDate is a Timestamp and then compare
      if (existingDate is Timestamp) {
        if (selectedDate.isAtSameMomentAs(existingDate.toDate())) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(content: Text('You already have an appointment on this date!')),
          );
          return;
        }
      } else if (existingDate is String) {
        try {
          // If it's a String, parse it into a DateTime (this might require adjusting the format)
          DateTime existingDateTime = DateFormat('yyyy-MM-dd HH:mm:ss').parse(existingDate);
          if (selectedDate.isAtSameMomentAs(existingDateTime)) {
            ScaffoldMessenger.of(context).showSnackBar(
              SnackBar(content: Text('You already have an appointment on this date!')),
            );
            return;
          }
        } catch (e) {
          print("Error parsing existing date string: $e");
        }
      }
    }

    final bookingData = {
      'doctorId': doctorId,
      'hospitalId': hospitalId,
      'date': selectedTimestamp, // Store Timestamp
      'status': 'Pending', // Default status
      'reason': reason, // Store the reason for booking
    };

    // Update Firestore by adding the booking to the 'Bookings' array
    await patientDoc.update({
      'Bookings': FieldValue.arrayUnion([bookingData]),
    });

    // Show success message
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(content: Text('Appointment successfully booked!')),
    );

    // Navigate to the AppointmentDetailsScreen with the user ID
    Navigator.push(
      context,
      MaterialPageRoute(
        builder: (context) => AppointmentScreen(userId: patientId),
      ),
    );
  } catch (e) {
    // Show error message
    print('Error occurred: $e');
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(content: Text('Failed to book appointment: $e')),
    );
  }
}
