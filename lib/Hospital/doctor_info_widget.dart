// doctor_info_widget.dart
import 'package:flutter/material.dart';
import '../Components/booking_helper.dart';
import 'doctor_availability_calendar.dart';

class DoctorInfoWidget extends StatelessWidget {
  final Map<String, dynamic> doctorDetails;
  final String hospitalName;
  final String departmentName;
  final Function(String) onCall;

  const DoctorInfoWidget({
    Key? key,
    required this.doctorDetails,
    required this.hospitalName,
    required this.departmentName,
    required this.onCall,
  }) : super(key: key);

  @override
  Widget build(BuildContext context) {
    return Stack(
      children: [
        // Scrollable content
        SingleChildScrollView(
          padding: const EdgeInsets.fromLTRB(16.0, 16.0, 16.0, 100.0),  // Adjust padding for the button area
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.center,
            children: [
              // Profile Picture and Doctor's Name with Calendar Icon
              Row(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  // Calendar Icon
                  IconButton(
                    icon: Icon(Icons.calendar_month, color: Colors.blueAccent,size: 30),
                    onPressed: () => _showCalendarDialog(context),
                  ),
                  SizedBox(width: 5),
                  // Profile Picture
                  CircleAvatar(
                    radius: 50,
                    backgroundImage: doctorDetails['userPic']?.isNotEmpty ?? false
                        ? NetworkImage(doctorDetails['userPic'])
                        : AssetImage('assets/default_avatar.png') as ImageProvider,
                  ),
                ],
              ),
              SizedBox(height: 16),

              // Doctor's Name and Status
              Text(
                "${doctorDetails['Title'] ?? ''} ${doctorDetails['Fname'] ?? ''} ${doctorDetails['Lname'] ?? ''}",
                style: TextStyle(fontSize: 24, fontWeight: FontWeight.bold),
                textAlign: TextAlign.center,
              ),
              Text(
                doctorDetails['status'] ?? 'Available',
                style: TextStyle(fontSize: 16, color: Colors.green),
              ),
              SizedBox(height: 20),

              // Grid of Information Boxes
              GridView.count(
                crossAxisCount: 2,
                crossAxisSpacing: 10,
                mainAxisSpacing: 10,
                shrinkWrap: true,
                physics: NeverScrollableScrollPhysics(),
                children: [
                  _buildInfoBox(Icons.local_hospital, 'Hospital', hospitalName),
                  _buildInfoBox(Icons.business, 'Department', departmentName),
                  _buildInfoBox(Icons.location_on, 'Region', doctorDetails['Region']),
                  _buildInfoBox(Icons.work, 'Experience', "${doctorDetails['experience']} years"),
                ],
              ),
              SizedBox(height: 20),

              // Contact Information in Row
              Row(
                children: [
                  Expanded(child: _buildInfoBox(Icons.email, 'Email', doctorDetails['Email'])),
                  SizedBox(width: 10),
                  Expanded(child: _buildInfoBox(Icons.phone, 'Mobile', doctorDetails['Mobile Number'])),
                ],
              ),
            ],
          ),
        ),

        // "Call Doctor" and "Book Appointment" Buttons positioned at the bottom
        Positioned(
          bottom: 16,
          left: 16,
          right: 16,
          child: Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              // Call Doctor Button
              Expanded(
                child: ElevatedButton.icon(
                  icon: Icon(Icons.call, color: Colors.white),
                  label: Text('Call Doctor'),
                  style: ElevatedButton.styleFrom(
                    backgroundColor: Colors.blueAccent,
                    padding: EdgeInsets.symmetric(vertical: 12),
                    textStyle: TextStyle(fontSize: 16, fontWeight: FontWeight.bold),
                  ),
                  onPressed: () {
                    String? mobileNumber = doctorDetails['Mobile Number'];
                    if (mobileNumber != null && mobileNumber.isNotEmpty) {
                      onCall(mobileNumber);
                    } else {
                      ScaffoldMessenger.of(context).showSnackBar(
                        SnackBar(content: Text('Mobile number not available')),
                      );
                    }
                  },
                ),
              ),
              SizedBox(width: 10),  // Space between buttons

              // Book Appointment Button
              Expanded(
                child: ElevatedButton.icon(
                  icon: Icon(Icons.book_online, color: Colors.white),
                  label: Text('     Book Appointment'),
                  style: ElevatedButton.styleFrom(
                    backgroundColor: Colors.greenAccent.shade700,
                    padding: EdgeInsets.symmetric(vertical: 12),
                    textStyle: TextStyle(fontSize: 16, fontWeight: FontWeight.bold),
                  ),
                  onPressed: () => _showCalendarDialog(context),
                ),
              ),
            ],
          ),
        ),
      ],
    );
  }

  // Helper method to build individual info boxes with an icon, label, and value
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

  void _showCalendarDialog(BuildContext context) {
    final String? doctorId = doctorDetails['User ID'];
    final String? hospitalId = doctorDetails['Hospital ID'];

    if (doctorId == null) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Doctor ID is missing')),
      );
      return;
    }

    if (hospitalId == null) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Hospital ID is missing')),
      );
      return;
    }

    showDialog(
      context: context,
      builder: (BuildContext context) {
        return DoctorAvailabilityCalendar(
          doctorId: doctorId,
          hospitalId: hospitalId,
        );
      },
    );
  }



}
