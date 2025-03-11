import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:intl/intl.dart';
import '../Appointments/AppointmentScreen.dart';
import '../Login/login_screen1.dart';
import '../booking_page.dart';

Future<void> handleBookAppointment(
    BuildContext context, {
      required String doctorId,
      required String hospitalId,
      required DateTime selectedDate,
    }) async {
  final user = FirebaseAuth.instance.currentUser;

  if (user == null) {
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
  if (patientId == doctorId) {
    _showModernSnackBar(context, 'You cannot book an appointment with yourself!', isError: true);
    return;
  }

  final TextEditingController reasonController = TextEditingController();

  // Show modern dialog
  final bool? isConfirmed = await showDialog<bool>(
    context: context,
    barrierDismissible: false, // Prevents dismissing by tapping outside
    builder: (context) {
      return Dialog(
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(20),
        ),
        elevation: 10,
        backgroundColor: Colors.white,
        child: Padding(
          padding: const EdgeInsets.all(20.0),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              // Modern Title
              Text(
                'Why visit the Doctor?',
                style: TextStyle(
                  fontSize: 20,
                  fontWeight: FontWeight.bold,
                  color: Colors.blueAccent,
                ),
              ),
              SizedBox(height: 16),
              // Modern TextField
              TextField(
                controller: reasonController,
                maxLines: 3,
                decoration: InputDecoration(
                  hintText: 'Enter your reason here',
                  hintStyle: TextStyle(color: Colors.grey[400]),
                  filled: true,
                  fillColor: Colors.grey[100],
                  border: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(12),
                    borderSide: BorderSide.none,
                  ),
                  contentPadding: EdgeInsets.symmetric(vertical: 12, horizontal: 16),
                ),
              ),
              SizedBox(height: 20),
              // Modern Buttons
              Row(
                mainAxisAlignment: MainAxisAlignment.end,
                children: [
                  TextButton(
                    onPressed: () => Navigator.of(context).pop(false),
                    style: TextButton.styleFrom(
                      foregroundColor: Colors.grey[600],
                    ),
                    child: Text('Cancel'),
                  ),
                  SizedBox(width: 10),
                  ElevatedButton(
                    onPressed: () {
                      if (reasonController.text.trim().isEmpty) {
                        _showModernSnackBar(context, 'Reason is required!', isError: true);
                        return;
                      }
                      Navigator.of(context).pop(true);
                    },
                    style: ElevatedButton.styleFrom(
                      backgroundColor: Colors.blueAccent,
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(12),
                      ),
                      padding: EdgeInsets.symmetric(horizontal: 20, vertical: 12),
                    ),
                    child: Text(
                      'Confirm',
                      style: TextStyle(color: Colors.white),
                    ),
                  ),
                ],
              ),
            ],
          ),
        ),
      );
    },
  );

  if (isConfirmed == null || !isConfirmed) return;

  final reason = reasonController.text.trim();

  try {
    final selectedTimestamp = Timestamp.fromDate(selectedDate);

    final patientDoc = FirebaseFirestore.instance.collection('Bookings').doc(patientId);
    final patientSnapshot = await patientDoc.get();

    if (!patientSnapshot.exists) {
      await patientDoc.set({'Bookings': []});
    }

    final bookings = patientSnapshot.data()?['Bookings'] ?? [];

    for (var booking in bookings) {
      final existingDate = booking['date'];
      if (existingDate is Timestamp) {
        if (selectedDate.isAtSameMomentAs(existingDate.toDate())) {
          _showModernSnackBar(context, 'You already have an appointment on this date!', isError: true);
          return;
        }
      } else if (existingDate is String) {
        try {
          DateTime existingDateTime = DateFormat('yyyy-MM-dd HH:mm:ss').parse(existingDate);
          if (selectedDate.isAtSameMomentAs(existingDateTime)) {
            _showModernSnackBar(context, 'You already have an appointment on this date!', isError: true);
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
      'date': selectedTimestamp,
      'status': 'Pending',
      'reason': reason,
    };

    await patientDoc.update({
      'Bookings': FieldValue.arrayUnion([bookingData]),
    });

    _showModernSnackBar(context, 'Appointment successfully booked!');
    Navigator.push(
      context,
      MaterialPageRoute(
        builder: (context) => BookingPage(currentUserId: patientId),
      ),
    );
  } catch (e) {
    print('Error occurred: $e');
    _showModernSnackBar(context, 'Failed to book appointment: $e', isError: true);
  }
}

// Helper method for modern SnackBar
void _showModernSnackBar(BuildContext context, String message, {bool isError = false}) {
  ScaffoldMessenger.of(context).showSnackBar(
    SnackBar(
      content: Row(
        children: [
          Icon(
            isError ? Icons.error_outline : Icons.check_circle_outline,
            color: Colors.white,
          ),
          SizedBox(width: 10),
          Expanded(
            child: Text(
              message,
              style: TextStyle(color: Colors.white),
            ),
          ),
        ],
      ),
      backgroundColor: isError ? Colors.redAccent : Colors.green,
      behavior: SnackBarBehavior.floating,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(10),
      ),
      margin: EdgeInsets.all(10),
      duration: Duration(seconds: 3),
    ),
  );
}