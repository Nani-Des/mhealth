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
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
        title: Row(
          children: [
            Icon(
              isError ? Icons.error_outline : Icons.check_circle_outline,
              color: isError ? Colors.red : Colors.green,
            ),
            SizedBox(width: 8),
            Text(title, style: TextStyle(color: isError ? Colors.red : Colors.green)),
          ],
        ),
        content: Text(message),
        actions: [
          TextButton(
            onPressed: () {
              Navigator.pop(context);
              Navigator.pushReplacement(
                context,
                MaterialPageRoute(builder: (context) => HomePage()),
              );
            },
            child: Text("Okay", style: TextStyle(color: Colors.teal)),
          ),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: Text("Referral Summary", style: TextStyle(fontWeight: FontWeight.bold, fontSize: 22, color: Colors.white)),
        backgroundColor: Colors.teal,
        elevation: 0,
        actions: [
          if (showConfirm)
            Padding(
              padding: EdgeInsets.only(right: 16),
              child: ElevatedButton(
                onPressed: () => saveReferralToFirestore(context),
                style: ElevatedButton.styleFrom(
                  backgroundColor: Colors.white,
                  foregroundColor: Colors.teal,
                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                  padding: EdgeInsets.symmetric(horizontal: 16),
                ),
                child: Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Icon(Icons.check, size: 20),
                    SizedBox(width: 8),
                    Text("Confirm", style: TextStyle(fontWeight: FontWeight.bold)),
                  ],
                ),
              ),
            ),
        ],
      ),
      body: Container(
        color: Colors.grey[100],
        child: SingleChildScrollView(
          padding: EdgeInsets.all(16),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              _buildSectionCard(
                context,
                "Patient Information",
                [
                  _buildInfoRow("Serial Number", serialNumber),
                  _buildInfoRow("Patient Reg. No.", patientRegNo ?? "N/A"),
                  _buildInfoRow("Name", patientName),
                  _buildInfoRow("Sex", sex ?? "N/A"),
                  _buildInfoRow("Date of Birth", dateOfBirth),
                  _buildInfoRow("Age", age?.toString() ?? "N/A"),
                ],
              ),
              SizedBox(height: 16),
              _buildSectionCard(
                context,
                "Referee Notes",
                [
                  _buildInfoRow("Examination Findings", examinationFindings),
                  _buildInfoRow("Treatment Administered", treatmentAdministered),
                  _buildInfoRow("Diagnosis", diagnosis ?? "N/A"),
                  _buildInfoRow("Reason for Referral", reasonForReferral),
                ],
              ),
              SizedBox(height: 16),
              _buildSectionCard(
                context,
                "Additional Information",
                [
                  _buildInfoRow("Uploaded Medical Records", uploadedFileName ?? "No file uploaded"),
                  _buildInfoRow("Selected Health Facility", selectedHospitalName ?? "Not selected"),
                ],
              ),
              SizedBox(height: 32),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildSectionCard(BuildContext context, String title, List<Widget> children) {
    return Card(
      elevation: 4,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
      child: Padding(
        padding: EdgeInsets.all(20),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              title,
              style: Theme.of(context).textTheme.headlineSmall?.copyWith(
                color: Colors.teal,
                fontWeight: FontWeight.bold,
              ),
            ),
            SizedBox(height: 16),
            ...children,
          ],
        ),
      ),
    );
  }

  Widget _buildInfoRow(String label, String value) {
    return Padding(
      padding: EdgeInsets.symmetric(vertical: 8),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Expanded(
            flex: 2,
            child: Text(
              "$label:",
              style: TextStyle(fontWeight: FontWeight.bold, fontSize: 16, color: Colors.grey[800]),
            ),
          ),
          Expanded(
            flex: 3,
            child: Text(
              value,
              style: TextStyle(fontSize: 16, color: Colors.grey[700]),
            ),
          ),
        ],
      ),
    );
  }
}