import 'package:flutter/material.dart';
import '../Services/firebase_service.dart';
import 'doctor_profile.dart';

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
  List<Map<String, dynamic>> _departments = [];  // Department List with Name and ID
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
      Map<String, String> hospitalDetails = await _firebaseService.getHospitalDetails(widget.hospitalId);
      List<Map<String, dynamic>> departments = await _firebaseService.getDepartmentsForHospital(widget.hospitalId);
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
        title: Text(
          _hospitalDetails['hospitalName'] ?? 'Unknown Hospital',
          style: TextStyle(fontSize: 12), // Adjust the font size as needed
        ),
      ),
      body: _isLoading
          ? Center(child: CircularProgressIndicator())
          : Column(
        children: [
          Padding(
            padding: const EdgeInsets.all(10.0),
            child: Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Row(
                  children: [
                    CircleAvatar(
                      radius: 30,
                      backgroundImage: NetworkImage(_hospitalDetails['logo'] ?? ''),
                    ),
                    SizedBox(width: 10),
                  ],
                ),
                AnimatedBuilder(
                  animation: _controller,
                  builder: (context, child) {
                    return Container(
                      padding: const EdgeInsets.all(5.0),
                      decoration: BoxDecoration(
                        color: _animation.value,
                        borderRadius: BorderRadius.circular(10),
                      ),
                      child: Row(
                        children: [
                          Icon(Icons.chat_bubble_outline, color: Colors.white),
                          SizedBox(width: 5),
                          Text(
                            'Professionals',
                            style: TextStyle(
                              color: Colors.white,
                              fontWeight: FontWeight.bold,
                              fontSize: 8,
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
                Container(
                  width: MediaQuery.of(context).size.width * 0.30,
                  padding: const EdgeInsets.all(8.0),
                  child: ListView.builder(
                    itemCount: _departments.length,
                    itemBuilder: (context, index) {
                      return Column(
                        children: [
                          GestureDetector(
                            onTap: () => _loadDoctorsForDepartment(_departments[index]['Department ID']),
                            child: _specialtyLabel(_departments[index]['Department Name']),
                          ),
                          SizedBox(height: 30),
                        ],
                      );
                    },
                  ),
                ),
                Expanded(
                  flex: 7,
                  child: _isDoctorsLoading
                      ? Center(child: CircularProgressIndicator())
                      : _doctors.isEmpty
                      ? Center(child: Text('Select a department'))
                      : ListView.builder(
                    itemCount: _doctors.length,
                    itemBuilder: (context, index) {
                      var doctor = _doctors[index];
                      return _doctorDetailCard(
                        doctor['userId'], // Pass userId here
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

  Widget _specialtyLabel(String title) {
    return Text(
      title,
      style: TextStyle(fontSize: 12, fontWeight: FontWeight.w400),
    );
  }

  Widget _doctorDetailCard(String userId, String name, String experience, String userPic) {
    return GestureDetector(
      onTap: () {
        Navigator.push(
          context,
          MaterialPageRoute(
            builder: (context) => DoctorProfileScreen(userId: userId),
          ),
        );
      },
      child: Card(
        elevation: 4,
        margin: EdgeInsets.symmetric(horizontal: 10, vertical: 10),
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(15),
        ),
        child: Padding(
          padding: const EdgeInsets.all(12.0),
          child: Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Container(
                width: 50,
                height: 50,
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
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      name,
                      style: TextStyle(fontSize: 15, fontWeight: FontWeight.bold),
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
      ),
    );
  }
}
