import 'package:flutter/material.dart';
import 'package:url_launcher/url_launcher.dart';
import '../Services/firebase_service.dart';
import 'doctor_info_widget.dart'; // Import the new widget

class DoctorProfileScreen extends StatefulWidget {
  final String userId;

  DoctorProfileScreen({required this.userId});

  @override
  _DoctorProfileScreenState createState() => _DoctorProfileScreenState();
}

class _DoctorProfileScreenState extends State<DoctorProfileScreen> {
  final FirebaseService _firebaseService = FirebaseService();
  Map<String, dynamic> _doctorDetails = {};
  String _departmentName = '';
  String _hospitalName = '';
  bool _isLoading = true;

  @override
  void initState() {
    super.initState();
    _loadDoctorDetails();
  }

  Future<void> _loadDoctorDetails() async {
    try {
      // Fetch doctor's details
      Map<String, dynamic> doctorDetails = await _firebaseService.getDoctorDetails(widget.userId);

      // Check if the doctor details contain all necessary fields
      String departmentName = await _firebaseService.getDepartmentName(doctorDetails['departmentId']);
      String hospitalName = await _firebaseService.getHospitalName(doctorDetails['hospitalId']);

      // Assuming these fields are directly returned in the doctorDetails map
      String region = doctorDetails['Region'] ?? 'Not available';
      String experience = doctorDetails['Experience'] ?? 'Not available';
      String email = doctorDetails['Email'] ?? 'Not available';
      String mobile = doctorDetails['Mobile'] ?? 'Not available';

      setState(() {
        _doctorDetails = doctorDetails;
        _departmentName = departmentName;
        _hospitalName = hospitalName;
        _doctorDetails['Region'] = region;
        _doctorDetails['Experience'] = experience;
        _doctorDetails['Email'] = email;
        _doctorDetails['Mobile'] = mobile;
        _isLoading = false;
      });
    } catch (error) {
      print('Error fetching doctor details: $error');
    }
  }


  // Method to initiate a phone call
  Future<void> _makePhoneCall(String phoneNumber) async {
    final Uri launchUri = Uri(
      scheme: 'tel',
      path: phoneNumber,
    );
    await launchUrl(launchUri);
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: Center(
          child: Text(
            "${_doctorDetails['Title'] ?? ''}  ${_doctorDetails['Lname'] ?? ''}",
            style: TextStyle(
              fontSize: 16,
              color: Colors.black,
            ),
          ),
        ),
      ),
      body: _isLoading
          ? Center(child: CircularProgressIndicator())
          : DoctorInfoWidget(
        doctorDetails: _doctorDetails,
        hospitalName: _hospitalName,
        departmentName: _departmentName,
        onCall: _makePhoneCall,
      ),
    );
  }
}

