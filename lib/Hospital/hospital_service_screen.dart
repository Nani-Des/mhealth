import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:nhap/Appointments/Referral%20screens/referral_details_page.dart';
import '../Appointments/referral_form.dart';
import '../Auth/auth_screen.dart';
import '../Login/login_screen1.dart';
import '../Services/firebase_service.dart';
import 'Widgets/custom_nav_bar.dart';
import 'hospital_profile_screen.dart';

class HospitalServiceScreen extends StatefulWidget {
  final String hospitalId;
  final bool isReferral;
  final Function? selectHealthFacility;

  const HospitalServiceScreen({
    required this.hospitalId,
    required this.isReferral,
    this.selectHealthFacility,
    Key? key,
  }) : super(key: key);

  @override
  _HospitalServiceScreenState createState() => _HospitalServiceScreenState();
}

class _HospitalServiceScreenState extends State<HospitalServiceScreen> with TickerProviderStateMixin {
  Map<String, List<Map<String, dynamic>>> timetable = {};
  late AnimationController _textAnimationController;
  late Animation<double> _textFadeAnimation;
  late AnimationController _progressAnimationController;
  late Animation<double> _progressAnimation;

  Map<String, String> _hospitalDetails = {};
  List<Map<String, dynamic>> _departments = [];
  List<Map<String, dynamic>> _doctors = [];
  String? _selectedDepartmentId;
  bool _isLoading = true;
  bool _isDoctorsLoading = false;
  FirebaseService _firebaseService = FirebaseService();

  final List<String> orderedDays = [
    'Sunday',
    'Monday',
    'Tuesday',
    'Wednesday',
    'Thursday',
    'Friday',
    'Saturday',
  ];

  @override
  void initState() {
    super.initState();
    _loadServices();
    _loadHospitalData();
    _textAnimationController = AnimationController(
      vsync: this,
      duration: Duration(milliseconds: 1200),
    )..repeat(reverse: true);

    _textFadeAnimation = Tween<double>(begin: 0.2, end: 1.0).animate(
      CurvedAnimation(
        parent: _textAnimationController,
        curve: Curves.easeInOut,
      ),
    );

    _progressAnimationController = AnimationController(
      vsync: this,
      duration: Duration(seconds: 2),
    )..repeat();
    _progressAnimation = Tween<double>(begin: 0, end: 1).animate(_progressAnimationController);
  }

  Future<void> _loadHospitalData() async {
    try {
      Map<String, String> hospitalDetails = await _firebaseService.getHospitalDetails(widget.hospitalId);
      List<Map<String, dynamic>> departments =
      await _firebaseService.getDepartmentsForHospital(widget.hospitalId);

      if (departments.isNotEmpty) {
        _selectedDepartmentId = departments.first['Department ID'];
      }

      setState(() {
        _hospitalDetails = hospitalDetails;
        _departments = departments;
        _isLoading = false;
      });
    } catch (error) {
      print('Error fetching hospital data: $error');
      setState(() {
        _isLoading = false;
      });
    }
  }

  Future<void> _loadServices() async {
    try {
      QuerySnapshot serviceSnapshot = await FirebaseFirestore.instance
          .collection('Hospital')
          .doc(widget.hospitalId)
          .collection('Services')
          .get();

      Map<String, List<Map<String, dynamic>>> fetchedTimetable = {};
      for (var doc in serviceSnapshot.docs) {
        var data = doc.data() as Map<String, dynamic>;
        for (String day in data['Days']) {
          fetchedTimetable.putIfAbsent(day, () => []).add({
            "service": data['Service Name'],
            "time": data['Time'],
            "description": data['Description'] ?? 'No description available',
            "icon": _getServiceIcon(data['Service Name']),
            "page": _getServicePage(data['Service Name']),
          });
        }
      }
      setState(() => timetable = fetchedTimetable);
    } catch (e) {
      print("Error loading services: $e");
    }
  }

  String _getServiceIcon(String serviceName) {
    String normalizedService = serviceName.toLowerCase();

    if (normalizedService.contains('refer') || normalizedService.contains('referral')) {
      return '🏥';
    } else if (normalizedService.contains('consult')) {
      return '🩺';
    } else if (normalizedService.contains('emergency') || normalizedService.contains('trauma')) {
      return '🚑';
    } else if (normalizedService.contains('lab') || normalizedService.contains('pathology')) {
      return '🧪';
    } else if (normalizedService.contains('pharmacy') || normalizedService.contains('medication')) {
      return '💊';
    } else if (normalizedService.contains('radiology') ||
        normalizedService.contains('x-ray') ||
        normalizedService.contains('mri') ||
        normalizedService.contains('ct scan') ||
        normalizedService.contains('ultrasound')) {
      return '🩻';
    } else if (normalizedService.contains('cardiology') || normalizedService.contains('heart')) {
      return '❤️';
    } else if (normalizedService.contains('neurology') || normalizedService.contains('brain')) {
      return '🧠';
    } else if (normalizedService.contains('oncology') || normalizedService.contains('cancer')) {
      return '🎗️';
    } else if (normalizedService.contains('surgery')) {
      return '🔪';
    } else if (normalizedService.contains('orthopedic') || normalizedService.contains('bone')) {
      return '🦴';
    } else if (normalizedService.contains('ophthalmology') || normalizedService.contains('eye')) {
      return '👁️';
    } else if (normalizedService.contains('dentistry') || normalizedService.contains('dental')) {
      return '🦷';
    } else if (normalizedService.contains('pediatrics') || normalizedService.contains('child')) {
      return '👶';
    } else if (normalizedService.contains('maternity') ||
        normalizedService.contains('obstetrics') ||
        normalizedService.contains('pregnancy')) {
      return '🤰';
    } else if (normalizedService.contains('dermatology') || normalizedService.contains('skin')) {
      return '🧴';
    } else if (normalizedService.contains('psychiatry') ||
        normalizedService.contains('mental health') ||
        normalizedService.contains('psychology')) {
      return '🧠💭';
    } else if (normalizedService.contains('rehabilitation') ||
        normalizedService.contains('physical therapy') ||
        normalizedService.contains('physiotherapy')) {
      return '🏃‍♂️';
    } else if (normalizedService.contains('nutrition') || normalizedService.contains('diet')) {
      return '🥗';
    } else if (normalizedService.contains('vaccination') || normalizedService.contains('immunization')) {
      return '💉';
    } else if (normalizedService.contains('pain management')) {
      return '⚕️';
    } else if (normalizedService.contains('nephrology') || normalizedService.contains('kidney')) {
      return '🫁';
    } else {
      return '🏥';
    }
  }

  Widget Function() _getServicePage(String serviceName) {
    switch (serviceName.toLowerCase()) {
      case 'refer':
      // return () => ReferralForm();
      case 'consultation':
      // return () => ReferralDetailsPage(hospitalId: widget.hospitalId);
      case 'emergency':
      case 'lab tests':
      case 'pharmacy':
      case 'radiology':
      // return () => ReferralForm();
      default:
        return () => HospitalProfileScreen(hospitalId: widget.hospitalId);
    }
  }

  void _checkAndNavigate(BuildContext context, Map<String, dynamic> serviceData) async {
    User? user = FirebaseAuth.instance.currentUser;
    if (user == null) {
      Navigator.push(context, MaterialPageRoute(builder: (context) => AuthScreen()));
      return;
    }

    DocumentSnapshot userDoc =
    await FirebaseFirestore.instance.collection('Users').doc(user.uid).get();
    bool isDoctor = userDoc.exists && userDoc['Role'] == true;

    if (serviceData['service'].toLowerCase() == 'refer' && !isDoctor) {
      showDialog(
        context: context,
        builder: (context) => AlertDialog(
          title: const Text("Access Denied"),
          content: const Text("Only doctors can access Referrals."),
          actions: [
            TextButton(onPressed: () => Navigator.pop(context), child: const Text("OK")),
          ],
        ),
      );
      return;
    }

    Navigator.push(context, MaterialPageRoute(builder: (context) => serviceData['page']()));
  }

  void _showServiceTime(String service, String time, String description) {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: Text(service, style: TextStyle(fontStyle: FontStyle.italic, color: Colors.teal)),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              "Available Time / Quantity: $time",
              style: TextStyle(
                fontSize: 14,
                color: Colors.black87,
              ),
            ),
            SizedBox(height: 8),
            Text(
              "$description",
              style: TextStyle(
                fontWeight: FontWeight.bold,
                fontSize: 14,
                color: Colors.grey[700],
              ),
            ),
          ],
        ),
        actions: [TextButton(onPressed: () => Navigator.pop(context), child: const Text("OK"))],
      ),
    );
  }

  @override
  void dispose() {
    _textAnimationController.dispose();
    _progressAnimationController.dispose();
    super.dispose();
  }

  Widget _buildSophisticatedProgressIndicator() {
    return AnimatedBuilder(
      animation: _progressAnimationController,
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
    List<String> daysToDisplay = orderedDays.where((day) => timetable.containsKey(day)).toList();

    return Scaffold(
      appBar: AppBar(
        title: const Text("Services"),
        flexibleSpace: Container(
          decoration: const BoxDecoration(
            gradient: LinearGradient(
              colors: [Colors.teal, Colors.tealAccent],
              begin: Alignment.topLeft,
              end: Alignment.bottomRight,
            ),
          ),
        ),
        elevation: 4,
      ),
      body: Container(
        color: Colors.grey[100],
        padding: const EdgeInsets.all(16.0),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Text(
              "Available Services",
              style: TextStyle(fontSize: 20, fontWeight: FontWeight.bold, color: Colors.black87),
            ),
            const SizedBox(height: 16),
            Expanded(
              child: timetable.isEmpty
                  ? Center(
                child: Column(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    _buildSophisticatedProgressIndicator(),
                    SizedBox(height: 16),
                    Text(
                      "Loading Services...",
                      style: TextStyle(fontSize: 16, color: Colors.teal),
                    ),
                  ],
                ),
              )
                  : ListView.builder(
                itemCount: daysToDisplay.length,
                itemBuilder: (context, index) {
                  String day = daysToDisplay[index];
                  List<Map<String, dynamic>> dayServices = timetable[day]!;
                  return Padding(
                    padding: const EdgeInsets.symmetric(vertical: 8.0),
                    child: Card(
                      elevation: 3,
                      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                      child: Padding(
                        padding: const EdgeInsets.all(16.0),
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              day,
                              style: const TextStyle(
                                fontSize: 20,
                                fontWeight: FontWeight.bold,
                                color: Colors.teal,
                              ),
                            ),
                            const SizedBox(height: 12),
                            GridView.builder(
                              shrinkWrap: true,
                              physics: const NeverScrollableScrollPhysics(),
                              itemCount: dayServices.length,
                              gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
                                crossAxisCount: 3,
                                crossAxisSpacing: 12,
                                mainAxisSpacing: 12,
                                childAspectRatio: 0.70,
                              ),
                              itemBuilder: (context, serviceIndex) {
                                var serviceData = dayServices[serviceIndex];
                                return GestureDetector(
                                  onTap: () => _checkAndNavigate(context, serviceData),
                                  child: Card(
                                    elevation: 2,
                                    shape:
                                    RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                                    child: Container(
                                      decoration: BoxDecoration(
                                        gradient: LinearGradient(
                                          colors: [Colors.white, Colors.grey[50]!],
                                          begin: Alignment.topLeft,
                                          end: Alignment.bottomRight,
                                        ),
                                        borderRadius: BorderRadius.circular(12),
                                      ),
                                      child: Column(
                                        mainAxisAlignment: MainAxisAlignment.center,
                                        children: [
                                          Text(
                                            serviceData['icon'],
                                            style: const TextStyle(fontSize: 30),
                                          ),
                                          Flexible(
                                            child: Text(
                                              serviceData['service'],
                                              style: const TextStyle(
                                                fontSize: 10,
                                                fontWeight: FontWeight.w600,
                                                color: Colors.black87,
                                              ),
                                              textAlign: TextAlign.center,
                                            ),
                                          ),
                                          IconButton(
                                            icon: const Icon(Icons.schedule, color: Colors.teal, size: 20),
                                            onPressed: () => _showServiceTime(
                                              serviceData['service'],
                                              serviceData['time'],
                                              serviceData['description'],
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
                    ),
                  );
                },
              ),
            ),
          ],
        ),
      ),
      floatingActionButton: widget.isReferral
          ? Row(
        mainAxisAlignment: MainAxisAlignment.end,
        children: [
          FadeTransition(
            opacity: _textFadeAnimation,
            child: Padding(
              padding: const EdgeInsets.only(right: 8.0),
              child: Text(
                "Tap Here To Add Hospital",
                style: TextStyle(
                  color: Colors.teal,
                  fontSize: 16,
                  fontWeight: FontWeight.w500,
                ),
              ),
            ),
          ),
          FloatingActionButton(
            onPressed: () {
              String selectedHospitalName = _hospitalDetails['hospitalName'] ?? 'Loading Hospital..';

              Navigator.pop(context, selectedHospitalName);
              Navigator.pop(context, selectedHospitalName);
              Navigator.pop(context, selectedHospitalName);

              Future.delayed(Duration(milliseconds: 300), () {
                if (widget.selectHealthFacility != null) {
                  widget.selectHealthFacility!(selectedHospitalName);
                }
              });
            },
            child: Icon(Icons.add),
            backgroundColor: Colors.teal,
          ),
        ],
      )
          : null,
      bottomNavigationBar:
      widget.isReferral ? null : CustomBottomNavBarHospital(hospitalId: widget.hospitalId),
    );
  }
}