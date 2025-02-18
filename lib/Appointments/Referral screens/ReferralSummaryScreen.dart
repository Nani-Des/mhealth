import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_storage/firebase_storage.dart';
import 'dart:io';
import 'package:file_picker/file_picker.dart';
import 'package:mhealth/Home/home_page.dart';

class ReferralSummaryScreen extends StatelessWidget {
  final String serialNumber;
  final String? patientRegNo;
  final String patientName;
  final String? sex;
  final String dateOfBirth;
  final int? age;
  final String examinationFindings;
  final String treatmentAdministered;
  final String? diagnosis;
  final String reasonForReferral;
  final String? uploadedFileName;
  final String? selectedHospitalName;
  final File? uploadedFile;
  final bool showConfirm;

  ReferralSummaryScreen({
    required this.serialNumber,
    required this.patientRegNo,
    required this.patientName,
    required this.sex,
    required this.dateOfBirth,
    required this.age,
    required this.examinationFindings,
    required this.treatmentAdministered,
    required this.diagnosis,
    required this.reasonForReferral,
    required this.uploadedFileName,
    required this.selectedHospitalName,
    this.uploadedFile,
    required this.showConfirm,
  });

  Future<void> saveReferralToFirestore(BuildContext context) async {
    if (selectedHospitalName == null || selectedHospitalName!.isEmpty) {
      _showMessage(context, "Error", "Selected hospital is required", isError: true);
      return;
    }
    String? userId = FirebaseAuth.instance.currentUser?.uid;


    try {
      String? fileUrl;
      if (uploadedFile != null) {
        fileUrl = await _uploadFile();
      }

      QuerySnapshot hospitalQuery = await FirebaseFirestore.instance
          .collection('Hospital')
          .where('Hospital Name', isEqualTo: selectedHospitalName)
          .get();

      if (hospitalQuery.docs.isEmpty) {
        _showMessage(context, "Error", "Hospital not found", isError: true);
        return;
      }

      String hospitalId = hospitalQuery.docs.first.id;
      await FirebaseFirestore.instance
          .collection('Hospital')
          .doc(hospitalId)
          .collection('Referrals')
          .doc(serialNumber)
          .set({
        'Serial Number': serialNumber,
        'Patient Reg. No.': patientRegNo ?? "N/A",
        'Name': patientName,
        'Sex': sex ?? "N/A",
        'Date of Birth': dateOfBirth,
        'Age': age?.toString() ?? "N/A",
        'Examination Findings': examinationFindings,
        'Treatment Administered': treatmentAdministered,
        'Diagnosis': diagnosis ?? "N/A",
        'Reason for Referral': reasonForReferral,
        'Uploaded Medical Records': fileUrl ?? "No file uploaded",
        'Selected Health Facility': selectedHospitalName,
        'Timestamp': FieldValue.serverTimestamp(),
        'Referred By': userId,
      });

      _showMessage(context, "Success", "Referral sent successfully");
    } catch (e) {
      _showMessage(context, "Error", "Check internet connectivity!", isError: true);
    }
  }

  Future<String?> _uploadFile() async {
    try {
      if (uploadedFile == null) return null;
      Reference storageRef = FirebaseStorage.instance.ref().child('referral_files/$serialNumber');
      UploadTask uploadTask = storageRef.putFile(uploadedFile!);
      TaskSnapshot snapshot = await uploadTask;
      return await snapshot.ref.getDownloadURL();
    } catch (e) {
      return null;
    }
  }

  void _showMessage(BuildContext context, String title, String message, {bool isError = false}) {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: Text(title, style: TextStyle(color: isError ? Colors.red : Colors.green)),
        content: Text(message),
        actions: [
          TextButton(
            onPressed: () {
              Navigator.pop(context); // Close the dialog
              // Navigate directly to the Homepage widget and replace the current screen
              Navigator.pushReplacement(
                context,
                MaterialPageRoute(builder: (context) => HomePage()), // Replace with your Homepage widget
              );
            },
            child: Text("Okay"),
          ),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: Text("Referral Summary", style: TextStyle(fontWeight: FontWeight.bold, fontSize: 22)),
        actions: [
          if (showConfirm) // Only show the Confirm button when showConfirm is true
            TextButton(
              onPressed: () => saveReferralToFirestore(context),
              child: Text(
                "Confirm",
                style: TextStyle(
                  color: Colors.blueAccent,
                  fontWeight: FontWeight.bold,
                  fontSize: 16,
                ),
              ),
            ),
        ],
      ),
      body: Padding(
        padding: EdgeInsets.all(16.0),
        child: ListView(
          children: [
            _buildSectionTitle(context, "Patient Information"),
            Divider(),
            _buildInfoRow(context, "Serial Number", serialNumber),
            _buildInfoRow(context, "Patient Reg. No.", patientRegNo ?? "N/A"),
            _buildInfoRow(context, "Name", patientName),
            _buildInfoRow(context, "Sex", sex ?? "N/A"),
            _buildInfoRow(context, "Date of Birth", dateOfBirth),
            _buildInfoRow(context, "Age", age?.toString() ?? "N/A"),
            SizedBox(height: 24),
            _buildSectionTitle(context, "Referee Notes"),
            Divider(),
            _buildInfoRow(context, "Examination Findings", examinationFindings),
            _buildInfoRow(context, "Treatment Administered", treatmentAdministered),
            _buildInfoRow(context, "Diagnosis", diagnosis ?? "N/A"),
            _buildInfoRow(context, "Reason for Referral", reasonForReferral),
            SizedBox(height: 24),
            _buildSectionTitle(context, "Additional Information"),
            Divider(),
            _buildInfoRow(context, "Uploaded Medical Records", uploadedFileName ?? "No file uploaded"),
            _buildInfoRow(context, "Selected Health Facility", selectedHospitalName ?? "Not selected"),
            SizedBox(height: 32),
          ],
        ),
      ),
    );
  }

  Widget _buildSectionTitle(BuildContext context, String title) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 12.0),
      child: Text(
        title,
        style: TextStyle(fontWeight: FontWeight.bold, color: Colors.blueAccent, fontSize: 20),
      ),
    );
  }

  Widget _buildInfoRow(BuildContext context, String label, String value) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 8.0),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Expanded(flex: 2, child: Text("$label:", style: TextStyle(fontWeight: FontWeight.bold, fontSize: 16))),
          Expanded(flex: 3, child: Text(value, style: TextStyle(fontSize: 16))),
        ],
      ),
    );
  }
}
