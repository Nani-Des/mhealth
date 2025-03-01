import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import '../../Hospital/doctor_profile.dart';

class ReferralDetailsPage extends StatefulWidget {
  final String hospitalId;

  const ReferralDetailsPage({Key? key, required this.hospitalId}) : super(key: key);

  @override
  _ReferralDetailsPageState createState() => _ReferralDetailsPageState();
}

class _ReferralDetailsPageState extends State<ReferralDetailsPage> {
  Future<Map<String, dynamic>> _fetchReferrerDetails(String userId) async {
    DocumentSnapshot userDoc = await FirebaseFirestore.instance.collection('Users').doc(userId).get();
    if (userDoc.exists) {
      var data = userDoc.data() as Map<String, dynamic>;
      Map<String, dynamic> hospitalData = await _fetchHospitalDetails(data['Hospital ID']);
      String departmentName = await _fetchDepartmentName(data['Department ID']);
      return {
        'UserId': userId,
        'Title': data['Title'] ?? 'N/A',
        'Fname': data['Fname'] ?? '',
        'Lname': data['Lname'] ?? '',
        'Email': data['Email'] ?? 'N/A',
        'Mobile Number': data['Mobile Number'] ?? 'N/A',
        'User Pic': data['User Pic'] ?? '',
        'Hospital Name': hospitalData['Hospital Name'],
        'Hospital Logo': hospitalData['Logo'],
        'Department Name': departmentName,
      };
    }
    return {};
  }

  Future<Map<String, dynamic>> _fetchHospitalDetails(String hospitalId) async {
    DocumentSnapshot hospitalDoc = await FirebaseFirestore.instance.collection('Hospital').doc(hospitalId).get();
    if (hospitalDoc.exists) {
      var data = hospitalDoc.data() as Map<String, dynamic>;
      return {
        'Hospital Name': data['Hospital Name'] ?? 'N/A',
        'Logo': data['Logo'] ?? '',
      };
    }
    return {'Hospital Name': 'N/A', 'Logo': ''};
  }

  Future<String> _fetchDepartmentName(String departmentId) async {
    DocumentSnapshot departmentDoc = await FirebaseFirestore.instance.collection('Department').doc(departmentId).get();
    return departmentDoc.exists ? departmentDoc['Department Name'] : 'N/A';
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: Text("Referrals", style: TextStyle(fontWeight: FontWeight.bold, color: Colors.white)),
        backgroundColor: Colors.teal,
        elevation: 0,
      ),
      body: Container(
        color: Colors.grey[100],
        child: StreamBuilder(
          stream: FirebaseFirestore.instance
              .collection('Hospital')
              .doc(widget.hospitalId)
              .collection('Referrals')
              .orderBy('Timestamp', descending: true)
              .snapshots(),
          builder: (context, AsyncSnapshot<QuerySnapshot> snapshot) {
            if (snapshot.connectionState == ConnectionState.waiting) {
              return Center(child: CircularProgressIndicator(color: Colors.teal));
            }
            if (!snapshot.hasData || snapshot.data!.docs.isEmpty) {
              return Center(
                child: Column(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    Icon(Icons.info_outline, size: 48, color: Colors.grey),
                    SizedBox(height: 16),
                    Text("No referrals found", style: TextStyle(fontSize: 18, color: Colors.grey)),
                  ],
                ),
              );
            }
            return ListView.builder(
              padding: EdgeInsets.all(16),
              itemCount: snapshot.data!.docs.length,
              itemBuilder: (context, index) {
                var data = snapshot.data!.docs[index].data() as Map<String, dynamic>;
                return FutureBuilder<Map<String, dynamic>>(
                  future: _fetchReferrerDetails(data['Referred By']),
                  builder: (context, refSnapshot) {
                    if (refSnapshot.connectionState == ConnectionState.waiting) {
                      return Card(
                        elevation: 2,
                        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                        child: Padding(
                          padding: EdgeInsets.all(16),
                          child: Center(child: CircularProgressIndicator(color: Colors.teal)),
                        ),
                      );
                    }
                    return _buildReferralCard(context, data, refSnapshot.data ?? {});
                  },
                );
              },
            );
          },
        ),
      ),
    );
  }

  Widget _buildReferralCard(BuildContext context, Map<String, dynamic> data, Map<String, dynamic> refData) {
    return Card(
      elevation: 4,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
      margin: EdgeInsets.only(bottom: 16),
      child: Padding(
        padding: EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                _buildHospitalLogo(refData['Hospital Logo']),
                SizedBox(width: 12),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        "Patient: ${data['Name']}",
                        style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold, color: Colors.teal),
                      ),
                      SizedBox(height: 4),
                      Text(
                        "Referral: ${data['Serial Number']}",
                        style: TextStyle(fontSize: 14, color: Colors.grey[600]),
                      ),
                    ],
                  ),
                ),
                GestureDetector(
                  onTap: () {
                    Navigator.push(
                      context,
                      MaterialPageRoute(
                        builder: (context) => DoctorProfileScreen(
                          userId: refData['UserId'],
                          isReferral: true,
                        ),
                      ),
                    );
                  },
                  child: _buildDoctorAvatar(refData['User Pic']),
                ),
              ],
            ),
            SizedBox(height: 12),
            Divider(color: Colors.grey[300]),
            SizedBox(height: 12),
            _buildInfoRow("Sex", data['Sex']),
            _buildInfoRow("DOB", data['Date of Birth']),
            _buildInfoRow("Age", data['Age']),
            SizedBox(height: 16),
            _buildExpansionTile("Diagnosis", data['Diagnosis'] ?? 'N/A'),
            _buildExpansionTile("Reason for Referral", data['Reason for Referral'] ?? 'N/A'),
            _buildExpansionTile("Examination Findings", data['Examination Findings'] ?? 'N/A'),
            _buildExpansionTile("Treatment Administered", data['Treatment Administered'] ?? 'N/A'),
            SizedBox(height: 16),
            _buildSectionTitle("Selected Facility"),
            Text(data['Selected Health Facility'] ?? 'N/A', style: TextStyle(color: Colors.grey[700], fontSize: 16)),
            SizedBox(height: 16),
            _buildSectionTitle("Referred By"),
            Text(
              "${refData['Title']} ${refData['Fname']} ${refData['Lname']}",
              style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold, color: Colors.grey[800]),
            ),
            SizedBox(height: 4),
            Text(
              "Hospital: ${refData['Hospital Name']}",
              style: TextStyle(fontSize: 14, color: Colors.grey[600]),
            ),
            Text(
              "Department: ${refData['Department Name']}",
              style: TextStyle(fontSize: 14, color: Colors.grey[600]),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildHospitalLogo(String? logoUrl) {
    return Container(
      width: 50,
      height: 50,
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(8),
        color: Colors.teal.withOpacity(0.1),
      ),
      child: logoUrl != null && logoUrl.isNotEmpty
          ? ClipRRect(
        borderRadius: BorderRadius.circular(8),
        child: Image.network(
          logoUrl,
          fit: BoxFit.cover,
          errorBuilder: (context, error, stackTrace) => Icon(Icons.local_hospital, size: 30, color: Colors.teal),
        ),
      )
          : Icon(Icons.local_hospital, size: 30, color: Colors.teal),
    );
  }

  Widget _buildDoctorAvatar(String? picUrl) {
    return CircleAvatar(
      radius: 25,
      backgroundColor: Colors.teal.withOpacity(0.1),
      child: picUrl != null && picUrl.isNotEmpty
          ? ClipOval(
        child: Image.network(
          picUrl,
          fit: BoxFit.cover,
          width: 50,
          height: 50,
          errorBuilder: (context, error, stackTrace) => Icon(Icons.person, size: 30, color: Colors.teal),
        ),
      )
          : Icon(Icons.person, size: 30, color: Colors.teal),
    );
  }

  Widget _buildSectionTitle(String title) {
    return Padding(
      padding: EdgeInsets.only(bottom: 8),
      child: Text(
        title,
        style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold, color: Colors.teal),
      ),
    );
  }

  Widget _buildInfoRow(String label, String value) {
    return Padding(
      padding: EdgeInsets.symmetric(vertical: 4),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            "$label: ",
            style: TextStyle(fontSize: 14, fontWeight: FontWeight.bold, color: Colors.grey[800]),
          ),
          Expanded(
            child: Text(
              value,
              style: TextStyle(fontSize: 14, color: Colors.grey[700]),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildExpansionTile(String title, String content) {
    return ExpansionTile(
      title: Text(
        title,
        style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold, color: Colors.grey[800]),
      ),
      collapsedBackgroundColor: Colors.grey[50],
      backgroundColor: Colors.white,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
      childrenPadding: EdgeInsets.all(12),
      children: [
        Text(
          content,
          style: TextStyle(fontSize: 14, color: Colors.grey[700]),
        ),
      ],
    );
  }
}