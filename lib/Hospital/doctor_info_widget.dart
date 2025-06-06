import 'package:flutter/material.dart';
import 'package:nhap/Hospital/specialty_details.dart';
import '../Auth/auth_screen.dart';
import '../ChatModule/chat_module.dart';
import '../Components/booking_helper.dart';
import '../Login/login_screen1.dart';
import '../main.dart';
import 'doctor_availability_calendar.dart';
import 'hospital_page.dart';
import 'package:uuid/uuid.dart';
import 'package:provider/provider.dart';

class DoctorInfoWidget extends StatelessWidget {
  final Map<String, dynamic> doctorDetails;
  final String hospitalName;
  final String departmentName;
  final String departmentId;
  final String hospitalId;
  final Function(String) onCall;
  final bool isReferral;

  const DoctorInfoWidget({
    Key? key,
    required this.doctorDetails,
    required this.hospitalName,
    required this.departmentName,
    required this.departmentId,
    required this.hospitalId,
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
                _buildProfileSection(context),
                const SizedBox(height: 24),
                _buildInfoGrid(context),
                const SizedBox(height: 24),
              ],
            ),
          ),
          Positioned(
            bottom: 0,
            left: 16,
            right: 16,
            child: _buildActionButtons(context),
          ),
        ],
      ),
    );
  }

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
            color: Colors.teal,
          ),
          textAlign: TextAlign.center,
        ),
        Text(
          doctorDetails['status'] ?? 'Available',
          style: TextStyle(
            fontSize: 12,
            color: doctorDetails['status'] == 'Available' ? Colors.green : Colors.red,
            fontWeight: FontWeight.w500,
          ),
        ),
      ],
    );
  }

  Widget _buildInfoGrid(BuildContext context) {
    return GridView.count(
      crossAxisCount: 2,
      crossAxisSpacing: 12,
      mainAxisSpacing: 12,
      shrinkWrap: true,
      physics: const NeverScrollableScrollPhysics(),
      children: [
        _buildInfoBox(
          Icons.local_hospital,
          'Hospital',
          hospitalName,
          onTap: () {
            Navigator.push(
              context,
              MaterialPageRoute(
                builder: (context) => HospitalPage(
                  hospitalId: hospitalId,
                  isReferral: isReferral,
                ),
              ),
            );
          },
        ),
        _buildInfoBox(
          Icons.business,
          'Department',
          departmentName,
          onTap: () {
            Navigator.push(
              context,
              MaterialPageRoute(
                builder: (context) => SpecialtyDetails(
                  hospitalId: hospitalId,
                  isReferral: isReferral,
                  initialDepartmentId: departmentId,
                ),
              ),
            );
          },
        ),
        _buildInfoBox(
          Icons.location_on,
          'Region',
          doctorDetails['Region'],
          onTap: () => _showInfoDialog(context, 'Region', doctorDetails['Region']),
        ),
        _buildInfoBox(
          Icons.work,
          'Experience',
          "${doctorDetails['experience']} years",
          onTap: () => _showInfoDialog(context, 'Experience', "${doctorDetails['experience']} years"),
        ),
      ],
    );
  }

  Widget _buildInfoBox(IconData icon, String label, String? value, {VoidCallback? onTap}) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
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
      ),
    );
  }

  void _showInfoDialog(BuildContext context, String title, String? value) {
    if (value == null || value.isEmpty) return;

    showDialog(
      context: context,
      builder: (BuildContext context) {
        return AlertDialog(
          title: Text(title),
          content: Text(value),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(context),
              child: const Text('Close', style: TextStyle(color: Colors.teal)),
            ),
          ],
        );
      },
    );
  }

  Widget _buildActionButtons(BuildContext context) {
    final userModel = Provider.of<UserModel>(context, listen: false);

    return Row(
      children: [
        Expanded(
          child: ElevatedButton.icon(
            icon: const Icon(Icons.message, color: Colors.white),
            label: const Text('Message Doctor'),
            style: ElevatedButton.styleFrom(
              backgroundColor: Colors.lightBlueAccent,
              padding: const EdgeInsets.symmetric(vertical: 14),
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(22)),
              elevation: 4,
            ),
            onPressed: () async {
              if (userModel.userId == null || userModel.userId!.isEmpty) {
                // User is not logged in, navigate to LoginScreen1
                final result = await Navigator.push(
                  context,
                  MaterialPageRoute(builder: (context) => AuthScreen()),
                );
                if (result != null && result is String && result.isNotEmpty) {
                  // Update UserModel with the new user ID
                  userModel.setUserId(result);
                  // Proceed to ChatThreadDetailsPage
                  _navigateToChat(context, userModel.userId!);
                }
              } else {
                // User is logged in, proceed to ChatThreadDetailsPage
                _navigateToChat(context, userModel.userId!);
              }
            },
          ),
        ),
        const SizedBox(width: 12),
        Expanded(
          child: ElevatedButton.icon(
            icon: const Icon(Icons.calendar_month, color: Colors.white),
            label: const Text('Book'),
            style: ElevatedButton.styleFrom(
              backgroundColor: isReferral ? Colors.grey[400] : Colors.tealAccent,
              padding: const EdgeInsets.symmetric(vertical: 14),
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(22)),
              elevation: isReferral ? 0 : 4,
            ),
            onPressed: isReferral ? null : () => _showCalendarDialog(context),
          ),
        ),
      ],
    );
  }

  void _navigateToChat(BuildContext context, String fromUid) {
    String? toUid = doctorDetails['User ID'];
    String? fname = doctorDetails['Fname'];
    String? lname = doctorDetails['Lname'];
    if (toUid != null && fname != null && lname != null) {
      String chatId = const Uuid().v4();
      String toName = "$fname $lname";
      Navigator.push(
        context,
        MaterialPageRoute(
          builder: (context) => ChatThreadDetailsPage(
            chatId: chatId,
            toName: toName,
            toUid: toUid,
            fromUid: fromUid,
          ),
        ),
      );
    } else {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Doctor details not available')),
      );
    }
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