import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import '../../Hospital/doctor_profile.dart';
import 'package:pdf/pdf.dart';
import 'package:pdf/widgets.dart' as pw;
import 'package:printing/printing.dart';

class ReferralDetailsPage extends StatefulWidget {
  final String? hospitalId;
  final String? userId;

  const ReferralDetailsPage({
    Key? key,
    this.hospitalId,
    this.userId,
  }) : assert((hospitalId != null) != (userId != null),
  'Exactly one of hospitalId or userId must be provided'),
        super(key: key);

  @override
  _ReferralDetailsPageState createState() => _ReferralDetailsPageState();
}

class _ReferralDetailsPageState extends State<ReferralDetailsPage> with SingleTickerProviderStateMixin {
  final TextEditingController _searchController = TextEditingController();
  String _searchQuery = '';
  List<Map<String, dynamic>> _allReferrals = [];
  List<Map<String, dynamic>> _filteredReferrals = [];
  late AnimationController _animationController;
  late Animation<double> _progressAnimation;

  @override
  void initState() {
    super.initState();
    _searchController.addListener(_onSearchChanged);
    _animationController = AnimationController(
      vsync: this,
      duration: Duration(seconds: 2),
    )..repeat();
    _progressAnimation = Tween<double>(begin: 0, end: 1).animate(_animationController);
    print('ReferralDetailsPage initialized with: hospitalId=${widget.hospitalId}, userId=${widget.userId}');
  }

  @override
  void dispose() {
    _searchController.removeListener(_onSearchChanged);
    _searchController.dispose();
    _animationController.dispose();
    super.dispose();
  }

  void _onSearchChanged() {
    setState(() {
      _searchQuery = _searchController.text.toLowerCase();
      _filterReferrals();
    });
  }

  void _filterReferrals() {
    if (_searchQuery.isEmpty) {
      _filteredReferrals = List.from(_allReferrals);
      return;
    }

    _filteredReferrals = _allReferrals.where((referral) {
      final patientName = referral['Name']?.toLowerCase() ?? '';
      final serialNumber = referral['SerialNumber']?.toLowerCase() ?? '';
      final diagnosis = referral['Diagnosis']?.toLowerCase() ?? '';
      final reason = referral['ReasonForReferral']?.toLowerCase() ?? '';
      final facility = referral['SelectedHealthFacility']?.toLowerCase() ?? '';
      final referrerName = referral['ReferrerName']?.toLowerCase() ?? '';
      final hospitalName = referral['HospitalName']?.toLowerCase() ?? '';
      final departmentName = referral['DepartmentName']?.toLowerCase() ?? '';

      return patientName.contains(_searchQuery) ||
          serialNumber.contains(_searchQuery) ||
          diagnosis.contains(_searchQuery) ||
          reason.contains(_searchQuery) ||
          facility.contains(_searchQuery) ||
          referrerName.contains(_searchQuery) ||
          hospitalName.contains(_searchQuery) ||
          departmentName.contains(_searchQuery);
    }).toList();
  }

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
        'ReferrerName': '${data['Title'] ?? ''} ${data['Fname'] ?? ''} ${data['Lname'] ?? ''}',
        'Email': data['Email'] ?? 'N/A',
        'Mobile Number': data['Mobile Number'] ?? 'N/A',
        'User Pic': data['User Pic'] ?? '',
        'HospitalName': hospitalData['Hospital Name'],
        'Hospital Logo': hospitalData['Logo'],
        'DepartmentName': departmentName,
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

  Future<pw.Document> _generateReferralPdf(Map<String, dynamic> data, Map<String, dynamic> refData) async {
    final pdf = pw.Document();
    pdf.addPage(
      pw.Page(
        margin: pw.EdgeInsets.all(40),
        build: (pw.Context context) => pw.Column(
          crossAxisAlignment: pw.CrossAxisAlignment.start,
          children: [
            pw.Container(
              alignment: pw.Alignment.center,
              padding: pw.EdgeInsets.all(10),
              decoration: pw.BoxDecoration(
                border: pw.Border(bottom: pw.BorderSide(color: PdfColors.teal, width: 2)),
              ),
              child: pw.Text(
                "Referral Details",
                style: pw.TextStyle(
                  fontSize: 28,
                  fontWeight: pw.FontWeight.bold,
                  color: PdfColors.teal,
                ),
              ),
            ),
            pw.SizedBox(height: 20),
            pw.Text("Patient Information", style: pw.TextStyle(fontSize: 20, fontWeight: pw.FontWeight.bold)),
            pw.Divider(),
            pw.SizedBox(height: 10),
            _buildPdfRow("Patient Name", data['Name'] ?? 'N/A'),
            _buildPdfRow("Serial Number", data['SerialNumber'] ?? 'N/A'),
            _buildPdfRow("Sex", data['Sex'] ?? 'N/A'),
            _buildPdfRow("Date of Birth", data['DateOfBirth'] ?? 'N/A'),
            _buildPdfRow("Age", data['Age'] ?? 'N/A'),
            pw.SizedBox(height: 20),
            pw.Text("Clinical Information", style: pw.TextStyle(fontSize: 20, fontWeight: pw.FontWeight.bold)),
            pw.Divider(),
            pw.SizedBox(height: 10),
            _buildPdfRow("Diagnosis", data['Diagnosis'] ?? 'N/A'),
            _buildPdfRow("Reason for Referral", data['ReasonForReferral'] ?? 'N/A'),
            _buildPdfRow("Examination Findings", data['ExaminationFindings'] ?? 'N/A'),
            _buildPdfRow("Treatment Administered", data['TreatmentAdministered'] ?? 'N/A'),
            pw.SizedBox(height: 20),
            pw.Text("Referral Details", style: pw.TextStyle(fontSize: 20, fontWeight: pw.FontWeight.bold)),
            pw.Divider(),
            pw.SizedBox(height: 10),
            _buildPdfRow("Selected Health Facility", data['SelectedHealthFacility'] ?? 'N/A'),
            _buildPdfRow("Referred By", '${refData['Title'] ?? ''} ${refData['Fname'] ?? ''} ${refData['Lname'] ?? ''}'),
            _buildPdfRow("Hospital", refData['HospitalName'] ?? 'N/A'),
            _buildPdfRow("Department", refData['DepartmentName'] ?? 'N/A'),
            pw.SizedBox(height: 20),
            pw.Spacer(),
            pw.Divider(),
            pw.Text(
              "Generated on: ${DateTime.now().toString().split('.')[0]}",
              style: pw.TextStyle(fontSize: 12, fontStyle: pw.FontStyle.italic, color: PdfColors.grey),
            ),
          ],
        ),
      ),
    );
    return pdf;
  }

  pw.Widget _buildPdfRow(String label, String value) {
    return pw.Padding(
      padding: pw.EdgeInsets.symmetric(vertical: 4),
      child: pw.Row(
        crossAxisAlignment: pw.CrossAxisAlignment.start,
        children: [
          pw.Text(
            "$label: ",
            style: pw.TextStyle(fontSize: 14, fontWeight: pw.FontWeight.bold),
          ),
          pw.Expanded(
            child: pw.Text(
              value,
              style: pw.TextStyle(fontSize: 14),
            ),
          ),
        ],
      ),
    );
  }

  Stream<QuerySnapshot> _getReferralStream() {
    if (widget.hospitalId != null) {
      print('Fetching referrals for hospitalId: ${widget.hospitalId}');
      return FirebaseFirestore.instance
          .collection('Hospital')
          .doc(widget.hospitalId)
          .collection('Referrals')
          .orderBy('Timestamp', descending: true)
          .snapshots();
    } else if (widget.userId != null) {
      print('Fetching referrals for userId: ${widget.userId}');
      return FirebaseFirestore.instance
          .collectionGroup('Referrals')
          .where('Referred By', isEqualTo: widget.userId)
          .orderBy('Timestamp', descending: true)
          .snapshots();
    } else {
      throw Exception('Either hospitalId or userId must be provided');
    }
  }

  Widget _buildSophisticatedProgressIndicator() {
    return AnimatedBuilder(
      animation: _animationController,
      builder: (context, child) {
        return Stack(
          alignment: Alignment.center,
          children: [
            SizedBox(
              width: 80,
              height: 80,
              child: CircularProgressIndicator(
                value: _progressAnimation.value,
                strokeWidth: 8,
                backgroundColor: Colors.teal.withOpacity(0.2),
                valueColor: AlwaysStoppedAnimation<Color>(Colors.teal),
              ),
            ),
            Container(
              width: 60,
              height: 60,
              decoration: BoxDecoration(
                shape: BoxShape.circle,
                gradient: LinearGradient(
                  colors: [Colors.teal.shade100, Colors.teal.shade300],
                  begin: Alignment.topLeft,
                  end: Alignment.bottomRight,
                ),
                boxShadow: [
                  BoxShadow(
                    color: Colors.teal.withOpacity(0.3),
                    blurRadius: 10,
                    offset: Offset(0, 4),
                  ),
                ],
              ),
              child: Center(
                child: Text(
                  '${(_progressAnimation.value * 100).toInt()}%',
                  style: TextStyle(
                    color: Colors.white,
                    fontWeight: FontWeight.bold,
                    fontSize: 18,
                  ),
                ),
              ),
            ),
          ],
        );
      },
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: Text(
          widget.hospitalId != null ? "Referrals To This Hospital" : "My Referrals",
          style: TextStyle(fontWeight: FontWeight.bold, color: Colors.white),
        ),
        backgroundColor: Colors.teal,
        elevation: 0,
      ),
      body: Column(
        children: [
          Padding(
            padding: const EdgeInsets.all(16.0),
            child: TextField(
              controller: _searchController,
              decoration: InputDecoration(
                hintText: 'Search referrals...',
                prefixIcon: Icon(Icons.search, color: Colors.teal),
                border: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(12),
                  borderSide: BorderSide(color: Colors.teal),
                ),
                filled: true,
                fillColor: Colors.white,
                contentPadding: EdgeInsets.symmetric(vertical: 0),
              ),
            ),
          ),
          Expanded(
            child: Container(
              color: Colors.grey[100],
              child: StreamBuilder<QuerySnapshot>(
                stream: _getReferralStream(),
                builder: (context, AsyncSnapshot<QuerySnapshot> snapshot) {
                  if (snapshot.connectionState == ConnectionState.waiting) {
                    return Center(
                      child: Column(
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: [
                          _buildSophisticatedProgressIndicator(),
                          SizedBox(height: 16),
                          Text(
                            "Loading Referrals...",
                            style: TextStyle(fontSize: 16, color: Colors.teal),
                          ),
                        ],
                      ),
                    );
                  }

                  if (snapshot.hasError) {
                    print('Stream error: ${snapshot.error}');
                    return Center(
                      child: Column(
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: [
                          Icon(Icons.error_outline, size: 48, color: Colors.red),
                          SizedBox(height: 16),
                          Text(
                            "Check your Network Connectivity!",
                            style: TextStyle(fontSize: 18, color: Colors.red),
                            textAlign: TextAlign.center,
                          ),
                        ],
                      ),
                    );
                  }

                  if (!snapshot.hasData || snapshot.data!.docs.isEmpty) {
                    print('No referrals found for ${widget.hospitalId != null ? 'hospitalId: ${widget.hospitalId}' : 'userId: ${widget.userId}'}');
                    return Center(
                      child: Column(
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: [
                          Icon(Icons.info_outline, size: 48, color: Colors.grey),
                          SizedBox(height: 16),
                          Text(
                            "No referrals found",
                            style: TextStyle(fontSize: 18, color: Colors.grey),
                          ),
                        ],
                      ),
                    );
                  }

                  _allReferrals.clear();
                  print('Found ${snapshot.data!.docs.length} referrals');
                  for (var doc in snapshot.data!.docs) {
                    var data = doc.data() as Map<String, dynamic>;
                    print('Referral doc: ${doc.id}, Referred By: ${data['Referred By']}');
                    _allReferrals.add({
                      'Name': data['Name'] ?? '',
                      'SerialNumber': data['Serial Number'] ?? '',
                      'Diagnosis': data['Diagnosis'] ?? '',
                      'ReasonForReferral': data['Reason for Referral'] ?? '',
                      'SelectedHealthFacility': data['Selected Health Facility'] ?? '',
                      'Sex': data['Sex'] ?? '',
                      'DateOfBirth': data['Date of Birth'] ?? '',
                      'Age': data['Age'] ?? '',
                      'ExaminationFindings': data['Examination Findings'] ?? '',
                      'TreatmentAdministered': data['Treatment Administered'] ?? '',
                      'ReferredBy': data['Referred By'] ?? '',
                    });
                  }
                  _filterReferrals();

                  if (_filteredReferrals.isEmpty) {
                    return Center(
                      child: Text(
                        "No matching referrals found",
                        style: TextStyle(fontSize: 18, color: Colors.grey),
                      ),
                    );
                  }

                  return ListView.builder(
                    padding: EdgeInsets.all(16),
                    itemCount: _filteredReferrals.length,
                    itemBuilder: (context, index) {
                      var referral = _filteredReferrals[index];
                      return FutureBuilder<Map<String, dynamic>>(
                        future: _fetchReferrerDetails(referral['ReferredBy']),
                        builder: (context, refSnapshot) {
                          if (refSnapshot.connectionState == ConnectionState.waiting) {
                            return Card(
                              elevation: 2,
                              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                              child: Padding(
                                padding: EdgeInsets.all(16),
                                child: Center(child: _buildSophisticatedProgressIndicator()),
                              ),
                            );
                          }
                          var refData = refSnapshot.data ?? {};
                          referral['ReferrerName'] = refData['ReferrerName'];
                          referral['HospitalName'] = refData['HospitalName'];
                          referral['DepartmentName'] = refData['DepartmentName'];
                          return _buildReferralCard(context, referral, refData);
                        },
                      );
                    },
                  );
                },
              ),
            ),
          ),
        ],
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
                        "Referral: ${data['SerialNumber']}",
                        style: TextStyle(fontSize: 14, color: Colors.grey[600]),
                      ),
                    ],
                  ),
                ),
                Column(
                  children: [
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
                    SizedBox(height: 8),
                    IconButton(
                      icon: Icon(Icons.download, color: Colors.teal),
                      tooltip: 'Download Referral as PDF',
                      onPressed: () async {
                        final pdf = await _generateReferralPdf(data, refData);
                        await Printing.layoutPdf(
                          onLayout: (PdfPageFormat format) async => pdf.save(),
                        );
                      },
                    ),
                  ],
                ),
              ],
            ),
            SizedBox(height: 12),
            Divider(color: Colors.grey[300]),
            SizedBox(height: 12),
            _buildInfoRow("Sex", data['Sex']),
            _buildInfoRow("DOB", data['DateOfBirth']),
            _buildInfoRow("Age", data['Age']),
            SizedBox(height: 16),
            _buildExpansionTile("Diagnosis", data['Diagnosis'] ?? 'N/A'),
            _buildExpansionTile("Reason for Referral", data['ReasonForReferral'] ?? 'N/A'),
            _buildExpansionTile("Examination Findings", data['ExaminationFindings'] ?? 'N/A'),
            _buildExpansionTile("Treatment Administered", data['TreatmentAdministered'] ?? 'N/A'),
            SizedBox(height: 16),
            _buildSectionTitle("Selected Facility"),
            Text(data['SelectedHealthFacility'] ?? 'N/A', style: TextStyle(color: Colors.grey[700], fontSize: 16)),
            SizedBox(height: 16),
            _buildSectionTitle("Referred By"),
            Text(
              "${refData['Title']} ${refData['Fname']} ${refData['Lname']}",
              style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold, color: Colors.grey[800]),
            ),
            SizedBox(height: 4),
            Text(
              "Hospital: ${refData['HospitalName']}",
              style: TextStyle(fontSize: 14, color: Colors.grey[600]),
            ),
            Text(
              "Department: ${refData['DepartmentName']}",
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