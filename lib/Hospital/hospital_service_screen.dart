import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:mhealth/Appointments/Referral%20screens/referral_details_page.dart';
import '../Appointments/referral_form.dart';
import '../Login/login_screen1.dart';
import 'Widgets/custom_nav_bar.dart';
import 'hospital_profile_screen.dart';

class HospitalServiceScreen extends StatefulWidget {
  final String hospitalId;
  final bool isReferral;

  const HospitalServiceScreen({required this.hospitalId, required this.isReferral, Key? key}) : super(key: key);

  @override
  _HospitalServiceScreenState createState() => _HospitalServiceScreenState();
}

class _HospitalServiceScreenState extends State<HospitalServiceScreen> {
  Map<String, List<Map<String, dynamic>>> timetable = {};

  // Define the desired order of days
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
    // Normalize the input service name to lowercase for comparison
    String normalizedService = serviceName.toLowerCase();

    // Map service names to emojis
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
      return '🏥'; // Default hospital icon
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
      Navigator.push(context, MaterialPageRoute(builder: (context) => LoginScreen1()));
      return;
    }

    DocumentSnapshot userDoc = await FirebaseFirestore.instance.collection('Users').doc(user.uid).get();
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

  void _showServiceTime(String service, String time) {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: Text(service),
        content: Text("Available Time: $time"),
        actions: [TextButton(onPressed: () => Navigator.pop(context), child: const Text("OK"))],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    // Filter and sort days based on the orderedDays list and availability in timetable
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
                  ? const Center(child: CircularProgressIndicator())
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
                                childAspectRatio: 0.85,
                              ),
                              itemBuilder: (context, serviceIndex) {
                                var serviceData = dayServices[serviceIndex];
                                return GestureDetector(
                                  onTap: () => _checkAndNavigate(context, serviceData),
                                  child: Card(
                                    elevation: 2,
                                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
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
                                          const SizedBox(height: 5),
                                          Flexible(
                                            child: Text(
                                              serviceData['service'],
                                              style: const TextStyle(
                                                fontSize: 12,
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
      bottomNavigationBar: widget.isReferral ? null : CustomBottomNavBarHospital(hospitalId: widget.hospitalId),
    );
  }
}