// import 'package:flutter/material.dart';
//
// class ReferralSummaryScreen extends StatelessWidget {
//   final String serialNumber;
//   // final String? patientRegNo;
//   final String patientName;
//   final String? sex;
//   final String dateOfBirth;
//   final int? age;
//   final String examinationFindings;
//   final String treatmentAdministered;
//   final String? diagnosis;
//   final String reasonForReferral;
//   final String? uploadedFileName;
//   final String? selectedHospitalName;
//
//   ReferralSummaryScreen({
//     required this.serialNumber,
//     required this.patientRegNo,
//     required this.patientName,
//     required this.sex,
//     required this.dateOfBirth,
//     required this.age,
//     required this.examinationFindings,
//     required this.treatmentAdministered,
//     required this.diagnosis,
//     required this.reasonForReferral,
//     required this.uploadedFileName,
//     required this.selectedHospitalName,
//   });
//
//   @override
//   Widget build(BuildContext context) {
//     return Scaffold(
//       appBar: AppBar(
//         title: Text("Referral Summary", style: TextStyle(fontWeight: FontWeight.bold, fontSize: 22)),
//         actions: [
//           TextButton(
//             onPressed: () => Navigator.pop(context),
//             child: Text(
//               "Confirm",
//               style: TextStyle(
//                 color: Colors.blueAccent,
//                 fontWeight: FontWeight.bold,
//                 fontSize: 16,
//               ),
//             ),
//           ),
//         ],
//       ),
//       body: Padding(
//         padding: EdgeInsets.all(16.0),
//         child: ListView(
//           children: [
//             // Patient Information Section
//             _buildSectionTitle(context, "Patient Information"),
//             Divider(),
//             _buildInfoRow(context, "Serial Number", serialNumber),
//             _buildInfoRow(context, "Patient Reg. No.", patientRegNo ?? "N/A"),
//             _buildInfoRow(context, "Name", patientName),
//             _buildInfoRow(context, "Sex", sex ?? "N/A"),
//             _buildInfoRow(context, "Date of Birth", dateOfBirth),
//             _buildInfoRow(context, "Age", age?.toString() ?? "N/A"),
//
//             SizedBox(height: 24),
//
//             // Referee Notes Section
//             _buildSectionTitle(context, "Referee Notes"),
//             Divider(),
//             _buildInfoRow(context, "Examination Findings", examinationFindings),
//             _buildInfoRow(context, "Treatment Administered", treatmentAdministered),
//             _buildInfoRow(context, "Diagnosis", diagnosis ?? "N/A"),
//             _buildInfoRow(context, "Reason for Referral", reasonForReferral),
//
//             SizedBox(height: 24),
//
//             // Additional Information Section
//             _buildSectionTitle(context, "Additional Information"),
//             Divider(),
//             _buildInfoRow(context, "Uploaded Medical Records", uploadedFileName ?? "No file uploaded"),
//             _buildInfoRow(context, "Selected Health Facility", selectedHospitalName ?? "Not selected"),
//
//             SizedBox(height: 32),
//           ],
//         ),
//       ),
//     );
//   }
//
//   // Section Title Widget
//   Widget _buildSectionTitle(BuildContext context, String title) {
//     return Padding(
//       padding: const EdgeInsets.symmetric(vertical: 12.0),
//       child: Text(
//         title,
//         style: TextStyle(
//           fontWeight: FontWeight.bold,
//           color: Colors.blueAccent,
//           fontSize: 20,
//         ),
//       ),
//     );
//   }
//
//   // Info Row Widget for displaying key-value pairs
//   Widget _buildInfoRow(BuildContext context, String label, String value) {
//     return Padding(
//       padding: const EdgeInsets.symmetric(vertical: 8.0),
//       child: Row(
//         crossAxisAlignment: CrossAxisAlignment.start,
//         children: [
//           Expanded(
//             flex: 2,
//             child: Text(
//               "$label:",
//               style: TextStyle(
//                 fontWeight: FontWeight.bold,
//                 fontSize: 16,
//                 color: Colors.black.withOpacity(0.7),
//               ),
//             ),
//           ),
//           Expanded(
//             flex: 3,
//             child: Text(
//               value,
//               style: TextStyle(
//                 fontSize: 16,
//                 color: Colors.black.withOpacity(0.7),
//               ),
//             ),
//           ),
//         ],
//       ),
//     );
//   }
// //ReferralForm() //
// }
