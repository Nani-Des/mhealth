import 'package:flutter/material.dart';
import '../Components/booking_helper.dart';
import 'doctor_availability_calendar.dart';

class DoctorInfoWidget extends StatelessWidget {
  final Map<String, dynamic> doctorDetails;
  final String hospitalName;
  final String departmentName;
  final Function(String) onCall;
  final bool isReferral;

  const DoctorInfoWidget({
    Key? key,
    required this.doctorDetails,
    required this.hospitalName,
    required this.departmentName,
    required this.onCall,
    required this.isReferral,
  }) : super(key: key);

  @override
  Widget build(BuildContext context) {
    return Container(
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(16),
        boxShadow: [
          BoxShadow(
            color: Colors.grey.withOpacity(0.1),
            blurRadius: 10,
            spreadRadius: 5,
          ),
        ],
      ),
      margin: const EdgeInsets.all(16.0),
      child: Stack(
        children: [
          SingleChildScrollView(
            padding: const EdgeInsets.all(20.0),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.center,
              children: [
                // Doctor Profile Section
                _buildProfileSection(context),
                const SizedBox(height: 24),

                // Information Grid
                _buildInfoGrid(),
                const SizedBox(height: 24),

              ],
            ),
          ),

          // Action Buttons
          Positioned(
            bottom: 16,
            left: 16,
            right: 16,
            child: _buildActionButtons(context),
          ),
        ],
      ),
    );
  }

  // Profile Section with Avatar and Name
  Widget _buildProfileSection(BuildContext context) {
    return Column(
      children: [
        CircleAvatar(
          radius: 60,
          backgroundColor: Colors.grey[200],
          backgroundImage: doctorDetails['userPic']?.isNotEmpty ?? false
              ? NetworkImage(doctorDetails['userPic'])
              : const AssetImage('assets/default_avatar.png') as ImageProvider,
          child: Container(
            decoration: BoxDecoration(
              shape: BoxShape.circle,
              border: Border.all(color: Colors.teal, width: 2),
            ),
          ),
        ),
        const SizedBox(height: 12),
        Text(
          "${doctorDetails['Title'] ?? ''} ${doctorDetails['Fname'] ?? ''} ${doctorDetails['Lname'] ?? ''}",
          style: const TextStyle(
            fontSize: 26,
            fontWeight: FontWeight.bold,
            color: Colors.black87,
          ),
          textAlign: TextAlign.center,
        ),
        Text(
          doctorDetails['status'] ?? 'Available',
          style: TextStyle(
            fontSize: 16,
            color: doctorDetails['status'] == 'Available' ? Colors.green : Colors.red,
            fontWeight: FontWeight.w500,
          ),
        ),
      ],
    );
  }

  // Information Grid
  Widget _buildInfoGrid() {
    return GridView.count(
      crossAxisCount: 2,
      crossAxisSpacing: 12,
      mainAxisSpacing: 12,
      shrinkWrap: true,
      physics: const NeverScrollableScrollPhysics(),
      children: [
        _buildInfoBox(Icons.local_hospital, 'Hospital', hospitalName),
        _buildInfoBox(Icons.business, 'Department', departmentName),
        _buildInfoBox(Icons.location_on, 'Region', doctorDetails['Region']),
        _buildInfoBox(Icons.work, 'Experience', "${doctorDetails['experience']} years"),
      ],
    );
  }



  // Info Box Widget
  Widget _buildInfoBox(IconData icon, String label, String? value) {
    return Container(
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: Colors.grey[50],
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: Colors.grey[200]!),
      ),
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Icon(icon, color: Colors.teal, size: 28),
          const SizedBox(height: 8),
          Text(
            label,
            style: const TextStyle(fontSize: 16, fontWeight: FontWeight.w600, color: Colors.black87),
          ),
          const SizedBox(height: 4),
          Text(
            value ?? 'Not available',
            style: const TextStyle(fontSize: 14, color: Colors.black54),
            textAlign: TextAlign.center,
            maxLines: 2,
            overflow: TextOverflow.ellipsis,
          ),
        ],
      ),
    );
  }

  // Action Buttons
  Widget _buildActionButtons(BuildContext context) {
    return Row(
      children: [
        Expanded(
          child: ElevatedButton.icon(
            icon: const Icon(Icons.call, color: Colors.white),
            label: const Text('Call Doctor'),
            style: ElevatedButton.styleFrom(
              backgroundColor: Colors.lightBlueAccent,
              padding: const EdgeInsets.symmetric(vertical: 14),
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
              elevation: 4,
            ),
            onPressed: () {
              String? mobileNumber = doctorDetails['Mobile Number'];
              if (mobileNumber != null && mobileNumber.isNotEmpty) {
                onCall(mobileNumber);
              } else {
                ScaffoldMessenger.of(context).showSnackBar(
                  const SnackBar(content: Text('Mobile number not available')),
                );
              }
            },
          ),
        ),
        const SizedBox(width: 12),
        Expanded(
          child: ElevatedButton.icon(
            icon: const Icon(Icons.calendar_month, color: Colors.white),
            label: const Text('Book Appointment'),
            style: ElevatedButton.styleFrom(
              backgroundColor: isReferral ? Colors.grey[400] : Colors.tealAccent,
              padding: const EdgeInsets.symmetric(vertical: 14),
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
              elevation: isReferral ? 0 : 4,
            ),
            onPressed: isReferral ? null : () => _showCalendarDialog(context),
          ),
        ),
      ],
    );
  }

  void _showCalendarDialog(BuildContext context) {
    final String? doctorId = doctorDetails['User ID'];
    final String? hospitalId = doctorDetails['Hospital ID'];

    if (doctorId == null || hospitalId == null) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('${doctorId == null ? 'Doctor' : 'Hospital'} ID is missing')),
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