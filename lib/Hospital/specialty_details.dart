import 'package:flutter/material.dart';

import '../Services/firebase_service.dart';
class SpecialtyDetails extends StatefulWidget {
  final String hospitalId;

  SpecialtyDetails({required this.hospitalId});

  @override
  _SpecialtyDetailsState createState() => _SpecialtyDetailsState();
}

class _SpecialtyDetailsState extends State<SpecialtyDetails>
    with SingleTickerProviderStateMixin {
  late AnimationController _controller;
  late Animation<Color?> _animation;
  FirebaseService _firebaseService = FirebaseService();

  Map<String, String> _hospitalDetails = {'hospitalName': '', 'logo': ''}; // For hospital name and logo
  List<String> _departments = [];
  List<Map<String, dynamic>> _doctors = []; // List of doctors for a selected department

  bool _isLoading = true;
  bool _isDoctorsLoading = false;

  @override
  void initState() {
    super.initState();

    _controller = AnimationController(
      duration: const Duration(seconds: 1),
      vsync: this,
    )..repeat(reverse: true);

    _animation = ColorTween(
      begin: Colors.blueAccent,
      end: Colors.blue[200],
    ).animate(_controller);

    _loadHospitalData();
  }

  Future<void> _loadHospitalData() async {
    try {
      // Fetch hospital details (name and logo)
      Map<String, String> hospitalDetails = await _firebaseService.getHospitalDetails(widget.hospitalId);
      // Fetch departments
      List<String> departments = await _firebaseService.getDepartmentsForHospital(widget.hospitalId);
      setState(() {
        _hospitalDetails = hospitalDetails;
        _departments = departments;
        _isLoading = false;
      });
    } catch (error) {
      print('Error fetching hospital data: $error');
    }
  }

  Future<void> _loadDoctorsForDepartment(String departmentId) async {
    setState(() {
      _isDoctorsLoading = true;
    });
    try {
      // Fetch doctors based on department and hospital ID
      List<Map<String, dynamic>> doctors = await _firebaseService.getDoctorsForDepartment(widget.hospitalId, departmentId);
      setState(() {
        _doctors = doctors;
        _isDoctorsLoading = false;
      });
    } catch (error) {
      print('Error fetching doctors: $error');
    }
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: Text('Specialty Details - ${_hospitalDetails['hospitalName']}'),
        backgroundColor: Colors.blueAccent,
      ),
      body: _isLoading
          ? Center(child: CircularProgressIndicator())
          : Column(
        children: [
          // Logo and Organization name
          Padding(
            padding: const EdgeInsets.all(10.0),
            child: Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                // Organization logo and name
                Row(
                  children: [
                    // Logo placeholder
                    CircleAvatar(
                      radius: 25,
                      backgroundImage: NetworkImage(_hospitalDetails['logo'] ?? ''),
                    ),
                    SizedBox(width: 10),
                    // Organization name
                    Text(
                      _hospitalDetails['hospitalName'] ?? 'Organization Name',
                      style: TextStyle(
                        fontSize: 16,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                  ],
                ),
                // Blinking Speech Bubble
                AnimatedBuilder(
                  animation: _controller,
                  builder: (context, child) {
                    return Container(
                      padding: const EdgeInsets.all(10.0),
                      decoration: BoxDecoration(
                        color: _animation.value,
                        borderRadius: BorderRadius.circular(20),
                      ),
                      child: Row(
                        children: [
                          Icon(Icons.chat_bubble_outline, color: Colors.white),
                          SizedBox(width: 5),
                          Text(
                            'Available Professionals',
                            style: TextStyle(
                              color: Colors.white,
                              fontWeight: FontWeight.bold,
                              fontSize: 12,
                            ),
                          ),
                        ],
                      ),
                    );
                  },
                ),
              ],
            ),
          ),
          Expanded(
            child: Row(
              children: [
                // Labels section (30%)
                Container(
                  width: MediaQuery.of(context).size.width * 0.30,
                  padding: const EdgeInsets.all(8.0),
                  child: ListView.builder(
                    itemCount: _departments.length,
                    itemBuilder: (context, index) {
                      return Column(
                        children: [
                          GestureDetector(
                            onTap: () => _loadDoctorsForDepartment(_departments[index]),
                            child: _specialtyLabel(_departments[index]),
                          ),
                          SizedBox(height: 15),
                        ],
                      );
                    },
                  ),
                ),
                // Doctor details section (70%)
                Expanded(
                  flex: 7,
                  child: _isDoctorsLoading
                      ? Center(child: CircularProgressIndicator())
                      : _doctors.isEmpty
                      ? Center(child: Text('No doctors available for this department'))
                      : ListView.builder(
                    itemCount: _doctors.length,
                    itemBuilder: (context, index) {
                      var doctor = _doctors[index];
                      return _doctorDetailCard(
                        doctor['name'],
                        doctor['experience'],
                        doctor['userPic'],
                      );
                    },
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  // Function to create a specialty label
  Widget _specialtyLabel(String title) {
    return Text(
      title,
      style: TextStyle(fontSize: 16, fontWeight: FontWeight.w600),
    );
  }

  // Function to create a doctor detail card
  Widget _doctorDetailCard(String name, String experience, String userPic) {
    return Card(
      elevation: 4,
      margin: EdgeInsets.symmetric(horizontal: 10),
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(12),
      ),
      child: Padding(
        padding: const EdgeInsets.all(12.0),
        child: Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // Avatar section
            Container(
              width: 70,
              height: 70,
              decoration: BoxDecoration(
                shape: BoxShape.rectangle,
                border: Border.all(color: Colors.grey, width: 1),
                borderRadius: BorderRadius.circular(10),
                color: Colors.grey[200],
              ),
              child: userPic.isNotEmpty
                  ? Image.network(userPic, fit: BoxFit.cover)
                  : Icon(Icons.person, size: 50, color: Colors.grey[700]),
            ),
            SizedBox(width: 15),
            // Doctor details
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    name,
                    style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
                  ),
                  SizedBox(height: 5),
                  Text(
                    experience,
                    style: TextStyle(fontSize: 14, color: Colors.black54),
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}
