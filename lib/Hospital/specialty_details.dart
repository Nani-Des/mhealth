import 'package:flutter/material.dart';
import 'package:mhealth/Hospital/shift_schedule_Table.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:showcaseview/showcaseview.dart';
import '../Services/firebase_service.dart';
import 'Widgets/custom_nav_bar.dart';
import 'doctor_profile.dart';

class SpecialtyDetails extends StatefulWidget {
  final String hospitalId;
  final bool isReferral;
  final Function? selectHealthFacility;

  SpecialtyDetails({required this.hospitalId, required this.isReferral, this.selectHealthFacility,});

  @override
  _SpecialtyDetailsState createState() => _SpecialtyDetailsState();
}

class _SpecialtyDetailsState extends State<SpecialtyDetails>
    with SingleTickerProviderStateMixin {
  late AnimationController _controller;
  late Animation<Color?> _animation;
  FirebaseService _firebaseService = FirebaseService();

  Map<String, String> _hospitalDetails = {'hospitalName': '', 'logo': ''};
  List<Map<String, dynamic>> _departments = [];
  List<Map<String, dynamic>> _doctors = [];

  bool _isLoading = true;
  bool _isDoctorsLoading = false;
  String? _selectedDepartmentId;

  final GlobalKey _servicekey = GlobalKey();
  final GlobalKey _specialtycalendarKey = GlobalKey();

  @override
  void initState() {
    super.initState();

    _controller = AnimationController(
      duration: const Duration(seconds: 1),
      vsync: this,
    )..repeat(reverse: true);

    _animation = ColorTween(
      begin: Colors.teal,
      end: Colors.tealAccent,
    ).animate(_controller);

    _loadHospitalData();

    WidgetsBinding.instance.addPostFrameCallback((_) async {
      final prefs = await SharedPreferences.getInstance();
      await prefs.remove('hasSeenEmergencyWalkthrough');
      final bool hasSeenWalkthrough = prefs.getBool('hasSeenEmergencyWalkthrough') ?? false;
      if (!hasSeenWalkthrough && mounted) {
        ShowCaseWidget.of(context)?.startShowCase([_servicekey, _specialtycalendarKey]);
        await prefs.setBool('hasSeenEmergencyWalkthrough', true);
      }
    });
  }

  Future<void> _loadHospitalData() async {
    try {
      Map<String, String> hospitalDetails =
      await _firebaseService.getHospitalDetails(widget.hospitalId);
      List<Map<String, dynamic>> departments =
      await _firebaseService.getDepartmentsForHospital(widget.hospitalId);

      if (departments.isNotEmpty) {
        _selectedDepartmentId = departments.first['Department ID'];
        _loadDoctorsForDepartment(_selectedDepartmentId!);
      }

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
      _selectedDepartmentId = departmentId;
    });
    try {
      List<Map<String, dynamic>> doctors = await _firebaseService
          .getDoctorsForDepartment(widget.hospitalId, departmentId);
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
      backgroundColor: Color(0xFFE0F2F1),
      appBar: AppBar(
        backgroundColor: Colors.teal,
        elevation: 0,
        title: Text(
          _hospitalDetails['hospitalName'] ?? 'Loading Hospital..',
          style: const TextStyle(
            fontSize: 20,
            fontWeight: FontWeight.bold,
            color: Colors.white,
          ),
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
                      backgroundImage:
                      NetworkImage(_hospitalDetails['logo'] ?? ''),
                    ),

                  ],
                ),
                AnimatedBuilder(
                  animation: _controller,
                  builder: (context, child) {
                    return GestureDetector(
                      onTap: () {
                        showDialog(
                          context: context,
                          builder: (context) => Dialog(
                            shape: RoundedRectangleBorder(
                              borderRadius: BorderRadius.circular(16),
                            ),
                            child: SizedBox(
                              width: 700,
                              height: 650,
                              child: ShiftScheduleScreen(
                                hospitalId: widget.hospitalId,
                                doctors: _doctors,
                              ),
                            ),
                          ),
                        );
                      },
                    child: Showcase(
                    key: _servicekey,
                    description: 'Tap to view the Department Timetable',
                      child: Container(
                        padding: const EdgeInsets.all(5.0),
                        decoration: BoxDecoration(
                          color: _animation.value,
                          borderRadius: BorderRadius.circular(10),
                        ),
                        child: Row(
                          children: [
                            Icon(Icons.chat_bubble_outline,
                                color: Colors.white),
                            SizedBox(width: 10),
                            Text(
                              'Department Schedule',
                              style: TextStyle(
                                color: Colors.white,
                                fontWeight: FontWeight.bold,
                                fontSize: 14,
                              ),
                            ),
                          ],
                        ),
                      ),
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
                      String departmentId =
                      _departments[index]['Department ID'];
                      return Column(
                        children: [
                          GestureDetector(
                            onTap: () =>
                                _loadDoctorsForDepartment(departmentId),
                            child: _specialtyLabel(
                              _departments[index]['Department Name'],
                              departmentId == _selectedDepartmentId,
                            ),
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
                        doctor['userId'],
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
      floatingActionButton: widget.isReferral
          ? FloatingActionButton(
        onPressed: () {
          String selectedHospitalName = _hospitalDetails['hospitalName'] ?? 'Loading Hospital..';

          // Pass the selected hospital name back to the previous screen
          Navigator.pop(context, selectedHospitalName);
          // Pop the navigation stack twice
          Navigator.pop(context, selectedHospitalName);
          Navigator.pop(context, selectedHospitalName); // First pop to go back to previous page

          // Trigger the method to reset and re-execute the _selectHealthFacility logic
          Future.delayed(Duration(milliseconds: 300), () {
            // Check if the selectHealthFacility function is passed and execute it
            if (widget.selectHealthFacility != null) {
              widget.selectHealthFacility!(selectedHospitalName); // Pass selectedHospitalName here
            }
          });
        },
        child: Icon(Icons.add),
        backgroundColor: Colors.teal,
      )
          : null,
      bottomNavigationBar: widget.isReferral ? null : CustomBottomNavBarHospital(hospitalId: widget.hospitalId),
    );
  }

  Widget _specialtyLabel(String title, bool isSelected) {
    return Container(
      padding: EdgeInsets.symmetric(vertical: 8, horizontal: 12),
      decoration: BoxDecoration(
        color: isSelected ? Colors.teal : Colors.transparent,
        borderRadius: BorderRadius.circular(8),
      ),
      child: Text(
        title,
        style: TextStyle(
          fontSize: 10,
          fontWeight: FontWeight.w600,
          color: isSelected ? Colors.white : Colors.black,
        ),
      ),
    );
  }

  Widget _doctorDetailCard(
      String userId, String name, String experience, String userPic) {
    return GestureDetector(
      onTap: () {
        Navigator.push(
          context,
          MaterialPageRoute(
            builder: (context) => DoctorProfileScreen(userId: userId,isReferral:widget.isReferral),
          ),
        );
      },
      child: Card(
        elevation: 4,
        margin: EdgeInsets.symmetric(horizontal: 10, vertical: 10),
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(15),
        ),
        child: ListTile(
          leading: CircleAvatar(
            backgroundImage: userPic.isNotEmpty ? NetworkImage(userPic) : null,
            child: userPic.isEmpty ? Icon(Icons.person) : null,
          ),
          title: Text(name, style: TextStyle(fontWeight: FontWeight.bold, color: Colors.teal,fontSize: 14)),
          subtitle: Text(experience, style: TextStyle(fontSize: 10),),
        ),
      ),
    );
  }
}
