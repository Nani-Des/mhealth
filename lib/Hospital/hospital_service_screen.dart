import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:mhealth/Appointments/Referral%20screens/referral_details_page.dart';

import '../Appointments/referral_form.dart';
import '../Login/login_screen1.dart';

class HospitalServiceScreen extends StatefulWidget {
  final String hospitalId;

  HospitalServiceScreen({required this.hospitalId});

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
      {"title": "Referrals", "icon": "🏥", "page": () => ReferralForm()},
      {"title": "Consultation", "icon": "🩺", "page": () => ReferralDetailsPage(hospitalId: widget.hospitalId)}, // ✅ Now widget.hospitalId is accessible
      {"title": "Emergency", "icon": "🚑", "page": () => ReferralForm()},
      {"title": "Lab Tests", "icon": "🧪", "page": () => ReferralForm()},
      {"title": "Pharmacy", "icon": "💊", "page": () => ReferralForm()},
      {"title": "Radiology", "icon": "🩻", "page": () => ReferralForm()},
    ];
    _loadServices();
  }
  void _checkAndNavigate(BuildContext context, int index) async {
    User? user = FirebaseAuth.instance.currentUser;

    if (user == null) {
      // Redirect to login if user is not signed in
      Navigator.push(
        context,
        MaterialPageRoute(builder: (context) => LoginScreen1()),
      );
      return;
    }

    // Check user role from Firestore
    DocumentSnapshot userDoc = await FirebaseFirestore.instance
        .collection('Users')
        .doc(user.uid)
        .get();

    bool isDoctor = userDoc.exists && userDoc['Role'] == true;

    if (index == 0 && !isDoctor) {
      // Show a message if a non-doctor tries to access "Referrals"
      showDialog(
        context: context,
        builder: (context) => AlertDialog(
          title: Text("Access Denied"),
          content: Text("Only doctors can access Referrals."),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(context),
              child: Text("OK"),
            ),
          ],
        ),
      );
      return;
    }

    // Navigate to the service page
    Navigator.push(
      context,
      MaterialPageRoute(builder: (context) => services[index]["page"]()),
    );
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
          if (!fetchedTimetable.containsKey(day)) {
            fetchedTimetable[day] = [];
          }
          fetchedTimetable[day]!.add({
            "service": data['Service Name'],
            "time": data['Time']
          });
        }
      }

      setState(() {
        timetable = fetchedTimetable;
      });
    } catch (e) {
      print("Error loading services: $e");
    }
  }


  void _showServiceTime(String service, String time) {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: Text(service),
        content: Text("Available Time: $time"),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: Text("OK"),
          ),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: Text("Hospital Services")),
      body: Padding(
        padding: const EdgeInsets.all(10.0),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text("Service Timetable", style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold)),
            SizedBox(height: 10),
            Expanded(
              flex: 2,
              child: ListView.builder(
                itemCount: timetable.keys.length,
                itemBuilder: (context, index) {
                  String day = timetable.keys.elementAt(index);
                  return Card(
                    elevation: 3,
                    margin: EdgeInsets.symmetric(vertical: 5),
                    child: ExpansionTile(
                      initiallyExpanded: true,
                      title: Text(day, style: TextStyle(fontWeight: FontWeight.bold)),
                      children: timetable[day]!.map((serviceData) {
                        return ListTile(
                          title: Text(serviceData["service"]!),
                          trailing: IconButton(
                            icon: Icon(Icons.schedule),
                            onPressed: () => _showServiceTime(serviceData["service"]!, serviceData["time"]!),
                          ),
                        );
                      }).toList(),
                    ),
                  );
                },
              ),
            ),
            SizedBox(height: 15),
            Text("Hospital Services", style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold)),
            SizedBox(height: 10),
            Expanded(
              flex: 3,
              child: GridView.builder(
                itemCount: services.length,
                gridDelegate: SliverGridDelegateWithFixedCrossAxisCount(
                  crossAxisCount: 3,
                  crossAxisSpacing: 10,
                  mainAxisSpacing: 10,
                  childAspectRatio: 1.0,
                ),
                itemBuilder: (context, index) {
                  return GestureDetector(
                    onTap: () {
                      _checkAndNavigate(context, index);
                    },
                    child: Card(
                      elevation: 4,
                      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
                      child: Column(
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: [
                          Text(
                            services[index]["icon"]!,
                            style: TextStyle(fontSize: 30),
                          ),
                          SizedBox(height: 5),
                          Text(
                            services[index]["title"]!,
                            style: TextStyle(fontSize: 14, fontWeight: FontWeight.bold),
                            textAlign: TextAlign.center,
                          ),
                        ],
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