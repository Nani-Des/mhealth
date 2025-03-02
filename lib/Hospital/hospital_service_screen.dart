import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:mhealth/Appointments/Referral%20screens/referral_details_page.dart';
import '../Appointments/referral_form.dart';
import '../Login/login_screen1.dart';

class HospitalServiceScreen extends StatefulWidget {
  final String hospitalId;

  const HospitalServiceScreen({required this.hospitalId, Key? key}) : super(key: key);

  @override
  _HospitalServiceScreenState createState() => _HospitalServiceScreenState();
}

class _HospitalServiceScreenState extends State<HospitalServiceScreen> {
  Map<String, List<Map<String, String>>> timetable = {};
  List<Map<String, dynamic>> services = [];

  @override
  void initState() {
    super.initState();
    services = [
      {"title": "Refer", "icon": "🏥", "page": () => ReferralForm()},
      {"title": "Consultation", "icon": "🩺", "page": () => ReferralDetailsPage(hospitalId: widget.hospitalId)}, // ✅ Now widget.hospitalId is accessible
      {"title": "Emergency", "icon": "🚑", "page": () => ReferralForm()},
      {"title": "Lab Tests", "icon": "🧪", "page": () => ReferralForm()},
      {"title": "Pharmacy", "icon": "💊", "page": () => ReferralForm()},
      {"title": "Radiology", "icon": "🩻", "page": () => ReferralForm()},
    ];
    _loadServices();
  }

  Future<void> _loadServices() async {
    try {
      QuerySnapshot serviceSnapshot = await FirebaseFirestore.instance
          .collection('Hospital')
          .doc(widget.hospitalId)
          .collection('Services')
          .get();

      Map<String, List<Map<String, String>>> fetchedTimetable = {};
      for (var doc in serviceSnapshot.docs) {
        var data = doc.data() as Map<String, dynamic>;
        for (String day in data['Days']) {
          fetchedTimetable.putIfAbsent(day, () => []).add({
            "service": data['Service Name'],
            "time": data['Time'],
          });
        }
      }
      setState(() => timetable = fetchedTimetable);
    } catch (e) {
      print("Error loading services: $e");
    }
  }

  void _checkAndNavigate(BuildContext context, int index) async {
    User? user = FirebaseAuth.instance.currentUser;
    if (user == null) {
      Navigator.push(context, MaterialPageRoute(builder: (context) =>  LoginScreen1()));
      return;
    }

    DocumentSnapshot userDoc = await FirebaseFirestore.instance.collection('Users').doc(user.uid).get();
    bool isDoctor = userDoc.exists && userDoc['Role'] == true;

    if (index == 0 && !isDoctor) {
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

    Navigator.push(context, MaterialPageRoute(builder: (context) => services[index]["page"]()));
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
    return Scaffold(
      appBar: AppBar(
        title: const Text("Hospital Services"),
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
            // Timetable Section
            const Text(
              "Service Timetable",
              style: TextStyle(fontSize: 20, fontWeight: FontWeight.bold, color: Colors.black87),
            ),
            const SizedBox(height: 12),
            Expanded(
              flex: 2,
              child: timetable.isEmpty
                  ? const Center(child: CircularProgressIndicator())
                  : ListView.builder(
                itemCount: timetable.keys.length,
                itemBuilder: (context, index) {
                  String day = timetable.keys.elementAt(index);
                  return Card(
                    elevation: 2,
                    margin: const EdgeInsets.symmetric(vertical: 6),
                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                    child: ExpansionTile(
                      tilePadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 4),
                      title: Text(
                        day,
                        style: const TextStyle(fontSize: 16, fontWeight: FontWeight.bold, color: Colors.teal),
                      ),
                      children: timetable[day]!.map((serviceData) {
                        return ListTile(
                          title: Text(serviceData["service"]!, style: const TextStyle(fontSize: 14)),
                          trailing: IconButton(
                            icon: const Icon(Icons.schedule, color: Colors.teal),
                            onPressed: () => _showServiceTime(serviceData["service"]!, serviceData["time"]!),
                          ),
                        );
                      }).toList(),
                    ),
                  );
                },
              ),
            ),
            const Divider(height: 24, thickness: 1, color: Colors.grey),

            // Services Section
            const Text(
              "Hospital Services",
              style: TextStyle(fontSize: 20, fontWeight: FontWeight.bold, color: Colors.black87),
            ),
            const SizedBox(height: 12),
            Expanded(
              flex: 3,
              child: GridView.builder(
                itemCount: services.length,
                gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
                  crossAxisCount: 3,
                  crossAxisSpacing: 12,
                  mainAxisSpacing: 12,
                  childAspectRatio: 0.85,
                ),
                itemBuilder: (context, index) {
                  return GestureDetector(
                    onTap: () => _checkAndNavigate(context, index),
                    child: Card(
                      elevation: 3,
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
                              services[index]["icon"]!,
                              style: TextStyle(fontSize: 30),
                            ),
                            const SizedBox(height: 8),
                            Text(
                              services[index]["title"]!,
                              style: const TextStyle(
                                fontSize: 14,
                                fontWeight: FontWeight.w600,
                                color: Colors.black87,
                              ),
                              textAlign: TextAlign.center,
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
    );
  }
}