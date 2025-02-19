// import 'package:flutter/material.dart';
// import 'package:cloud_firestore/cloud_firestore.dart';
// import 'doctor_profile_screen.dart';
//
// class ReferralDetailsPage extends StatefulWidget {
//   final String hospitalId;
//
//   const ReferralDetailsPage({Key? key, required this.hospitalId}) : super(key: key);
//
//   @override
//   _ReferralDetailsPageState createState() => _ReferralDetailsPageState();
// }
//
// class _ReferralDetailsPageState extends State<ReferralDetailsPage> {
//   Future<Map<String, dynamic>> _fetchReferrerDetails(String userId) async {
//     DocumentSnapshot userDoc =
//     await FirebaseFirestore.instance.collection('Users').doc(userId).get();
//     if (userDoc.exists) {
//       var data = userDoc.data() as Map<String, dynamic>;
//       Map<String, dynamic> hospitalData = await _fetchHospitalDetails(data['Hospital ID']);
//       String departmentName = await _fetchDepartmentName(data['Department ID']);
//       return {
//         'UserId': userId,
//         'Title': data['Title'] ?? 'N/A',
//         'Fname': data['Fname'] ?? '',
//         'Lname': data['Lname'] ?? '',
//         'Email': data['Email'] ?? 'N/A',
//         'Mobile Number': data['Mobile Number'] ?? 'N/A',
//         'User Pic': data['User Pic'] ?? '',
//         'Hospital Name': hospitalData['Hospital Name'],
//         'Hospital Logo': hospitalData['Logo'],
//         'Department Name': departmentName,
//       };
//     }
//     return {};
//   }
//
//   Future<Map<String, dynamic>> _fetchHospitalDetails(String hospitalId) async {
//     DocumentSnapshot hospitalDoc =
//     await FirebaseFirestore.instance.collection('Hospital').doc(hospitalId).get();
//     if (hospitalDoc.exists) {
//       var data = hospitalDoc.data() as Map<String, dynamic>;
//       return {
//         'Hospital Name': data['Hospital Name'] ?? 'N/A',
//         'Logo': data['Logo'] ?? '',
//       };
//     }
//     return {'Hospital Name': 'N/A', 'Logo': ''};
//   }
//
//   Future<String> _fetchDepartmentName(String departmentId) async {
//     DocumentSnapshot departmentDoc =
//     await FirebaseFirestore.instance.collection('Department').doc(departmentId).get();
//     return departmentDoc.exists ? departmentDoc['Department Name'] : 'N/A';
//   }
//
//   @override
//   Widget build(BuildContext context) {
//     return Scaffold(
//       appBar: AppBar(title: Text("Referrals")),
//       body: StreamBuilder(
//         stream: FirebaseFirestore.instance
//             .collection('Hospital')
//             .doc(widget.hospitalId)
//             .collection('Referrals')
//             .orderBy('Timestamp', descending: true)
//             .snapshots(),
//         builder: (context, AsyncSnapshot<QuerySnapshot> snapshot) {
//           if (snapshot.connectionState == ConnectionState.waiting) {
//             return Center(child: CircularProgressIndicator());
//           }
//           if (!snapshot.hasData || snapshot.data!.docs.isEmpty) {
//             return Center(child: Text("No referrals found"));
//           }
//           return ListView(
//             padding: EdgeInsets.all(8.0),
//             children: snapshot.data!.docs.map((doc) {
//               var data = doc.data() as Map<String, dynamic>;
//               return FutureBuilder<Map<String, dynamic>>(
//                 future: _fetchReferrerDetails(data['Referred By']),
//                 builder: (context, refSnapshot) {
//                   if (refSnapshot.connectionState == ConnectionState.waiting) {
//                     return SizedBox.shrink();
//                   }
//                   return Card(
//                     elevation: 4,
//                     shape: RoundedRectangleBorder(
//                       borderRadius: BorderRadius.circular(10),
//                     ),
//                     child: Padding(
//                       padding: EdgeInsets.all(12.0),
//                       child: Column(
//                         crossAxisAlignment: CrossAxisAlignment.start,
//                         children: [
//                           Row(
//                             children: [
//                               refSnapshot.data?['Hospital Logo'] != ''
//                                   ? Image.network(
//                                 refSnapshot.data?['Hospital Logo'],
//                                 height: 50,
//                                 width: 50,
//                                 fit: BoxFit.cover,
//                               )
//                                   : Icon(Icons.local_hospital, size: 50),
//                               SizedBox(width: 10),
//                               Column(
//                                 crossAxisAlignment: CrossAxisAlignment.start,
//                                 children: [
//                                   Text("Patient: ${data['Name']}",
//                                       style: TextStyle(
//                                           fontWeight: FontWeight.bold,
//                                           fontSize: 16)),
//                                   Text("Referral: ${data['Serial Number']}",
//                                       style: TextStyle(color: Colors.grey)),
//                                 ],
//                               ),
//                               Spacer(),
//                               GestureDetector(
//                                 onTap: () {
//                                   Navigator.push(
//                                     context,
//                                     MaterialPageRoute(
//                                       builder: (context) => DoctorProfileScreen(
//                                         userId: refSnapshot.data?['UserId'],
//                                         isReferral: false,
//                                       ),
//                                     ),
//                                   );
//                                 },
//                                 child: refSnapshot.data?['User Pic'] != ''
//                                     ? CircleAvatar(
//                                   backgroundImage:
//                                   NetworkImage(refSnapshot.data?['User Pic']),
//                                   radius: 25,
//                                 )
//                                     : CircleAvatar(
//                                   child: Icon(Icons.person),
//                                   radius: 25,
//                                 ),
//                               ),
//                             ],
//                           ),
//                           Divider(),
//                           Text("Sex: ${data['Sex']}", style: TextStyle(fontWeight: FontWeight.w500)),
//                           Text("DOB: ${data['Date of Birth']}"),
//                           Text("Age: ${data['Age']}"),
//                           ExpansionTile(
//                             title: Text("Diagnosis"),
//                             children: [Text(data['Diagnosis'] ?? 'N/A')],
//                           ),
//                           ExpansionTile(
//                             title: Text("Reason for Referral"),
//                             children: [Text(data['Reason for Referral'] ?? 'N/A')],
//                           ),
//                           ExpansionTile(
//                             title: Text("Examination Findings"),
//                             children: [Text(data['Examination Findings'] ?? 'N/A')],
//                           ),
//                           ExpansionTile(
//                             title: Text("Treatment Administered"),
//                             children: [Text(data['Treatment Administered'] ?? 'N/A')],
//                           ),
//                           SizedBox(height: 8),
//                           Text("Selected Facility:", style: TextStyle(fontWeight: FontWeight.bold)),
//                           Text("${data['Selected Health Facility']}", style: TextStyle(color: Colors.grey)),
//                           SizedBox(height: 8),
//                           Text("Referred By:", style: TextStyle(fontWeight: FontWeight.bold)),
//                           Text("${refSnapshot.data?['Title']} ${refSnapshot.data?['Fname']} ${refSnapshot.data?['Lname']}",
//                               style: TextStyle(fontSize: 16)),
//                           Text("Hospital: ${refSnapshot.data?['Hospital Name']}"),
//                           Text("Department: ${refSnapshot.data?['Department Name']}"),
//                         ],
//                       ),
//                     ),
//                   );
//                 },
//               );
//             }).toList(),
//           );
//         },
//       ),
//     );
//   }
// }
