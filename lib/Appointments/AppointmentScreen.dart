import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';

class AppointmentScreen extends StatefulWidget {
  final String userId;

  const AppointmentScreen({Key? key, required this.userId}) : super(key: key);

  @override
  _AppointmentScreenState createState() => _AppointmentScreenState();
}

class _AppointmentScreenState extends State<AppointmentScreen> {
  Map<String, List<Map<String, dynamic>>> categorizedAppointments = {
    'Pending': [],
    'Active': [],
    'Terminated': [],
    'Requests': [],
    'Appointments': [],
  };

  bool isLoading = true;
  String selectedStatus = 'Pending';

  @override
  void initState() {
    super.initState();
    fetchAppointments();
  }

  Future<void> fetchAppointments() async {
    try {
      // Fetch appointments from the Bookings collection
      var bookingsSnapshot = await FirebaseFirestore.instance.collection('Bookings').get();

      for (var doc in bookingsSnapshot.docs) {
        String patientId = doc.id; // The document ID is the patient ID
        List<dynamic> bookings = doc.data()['Bookings'] ?? [];

        for (var booking in bookings) {
          if (booking['doctorId'] == widget.userId) {
            // This is an incoming request for a doctor (someone who booked the doctor)
            var patientDoc = await FirebaseFirestore.instance.collection('Users').doc(patientId).get();
            if (patientDoc.exists) {
              booking['patientInfo'] = {
                'fname': patientDoc.data()?['Fname'],
                'lname': patientDoc.data()?['Lname'],
                'userPic': patientDoc.data()?['User Pic'],
              };
              // Categorize requests (Pending) and appointments (Active)
              categorizedAppointments[booking['status']]?.add(booking);
            }
          } else if (booking['patientId'] == widget.userId) {
            // This is a booking made by the logged-in user (patient's bookings)
            var doctorDoc = await FirebaseFirestore.instance.collection('Users').doc(booking['doctorId']).get();
            if (doctorDoc.exists) {
              booking['doctorInfo'] = {
                'title': doctorDoc.data()?['Title'],
                'fname': doctorDoc.data()?['Fname'],
                'lname': doctorDoc.data()?['Lname'],
                'userPic': doctorDoc.data()?['User Pic'],
              };
              // Categorize bookings (Pending, Active, Terminated)
              categorizedAppointments[booking['status']]?.add(booking);
            }
          }
        }
      }
    } catch (e) {
      print("❌ Error fetching appointments: $e");
    }

    setState(() {
      isLoading = false;
    });
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: Text('Appointments')),
      body: isLoading
          ? Center(child: CircularProgressIndicator())
          : Row(
        children: [
          Expanded(
            flex: 2,
            child: Column(
              mainAxisAlignment: MainAxisAlignment.start,
              children: [
                statusLabel('Requests', Colors.orange),
                statusLabel('Appointments', Colors.purple),
                statusLabel('Pending', Colors.teal),
                statusLabel('Active', Colors.green),
                statusLabel('Terminated', Colors.red),
              ],
            ),
          ),
          Expanded(
            flex: 5,
            child: ListView(
              children: [
                appointmentSection('Requests', 'Pending'),
                appointmentSection('Appointments', 'Active'),
                appointmentSection('Pending', 'Pending'),
                appointmentSection('Active', 'Active'),
                appointmentSection('Terminated', 'Terminated'),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget statusLabel(String label, Color color) {
    bool isSelected = selectedStatus == label;
    return GestureDetector(
      onTap: () {
        setState(() {
          selectedStatus = label;
        });
      },
      child: Padding(
        padding: const EdgeInsets.all(8.0),
        child: Text(
          label,
          style: TextStyle(
            fontSize: 12,
            fontWeight: FontWeight.bold,
            color: isSelected ? color : Colors.black,
          ),
        ),
      ),
    );
  }

  Widget appointmentSection(String sectionLabel, String status) {
    if (selectedStatus != sectionLabel) return SizedBox.shrink();
    List<Map<String, dynamic>> appointments = categorizedAppointments[status] ?? [];
    if (appointments.isEmpty) {
      return Padding(
        padding: const EdgeInsets.all(8.0),
        child: Text(
          'No $sectionLabel',
          style: TextStyle(fontSize: 12, fontStyle: FontStyle.italic),
        ),
      );
    }
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: appointments.map((appointment) {
        return sectionLabel == 'Requests' || sectionLabel == 'Appointments'
            ? appointmentCard(appointment) // Doctor's side: Requests and Appointments
            : patientAppointmentCard(appointment); // Patient's side: Pending, Active, Terminated
      }).toList(),
    );
  }

  Widget appointmentCard(Map<String, dynamic> appointment) {
    var userInfo = appointment['patientInfo'];
    return Card(
      margin: EdgeInsets.symmetric(vertical: 8.0, horizontal: 12.0),
      elevation: 3,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
      child: ListTile(
        leading: CircleAvatar(
          backgroundImage: userInfo['userPic'] != null ? NetworkImage(userInfo['userPic']) : null,
          child: userInfo['userPic'] == null ? Icon(Icons.person) : null,
        ),
        title: Text('${userInfo['fname']} ${userInfo['lname']}'),
        subtitle: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text('Reason: ${appointment['reason']}'),
            Text('Date: ${appointment['date'].toDate()}'),
          ],
        ),
      ),
    );
  }

  Widget patientAppointmentCard(Map<String, dynamic> appointment) {
    return FutureBuilder<DocumentSnapshot>(
      future: FirebaseFirestore.instance.collection('Users').doc(appointment['doctorId']).get(),
      builder: (context, snapshot) {
        if (!snapshot.hasData) {
          return SizedBox.shrink();
        }
        var doctorData = snapshot.data!;
        return Card(
          margin: EdgeInsets.symmetric(vertical: 8.0, horizontal: 12.0),
          elevation: 3,
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
          child: ListTile(
            leading: CircleAvatar(
              backgroundImage: doctorData['User Pic'] != null ? NetworkImage(doctorData['User Pic']) : null,
              child: doctorData['User Pic'] == null ? Icon(Icons.person) : null,
            ),
            title: Text('${doctorData['Fname']} ${doctorData['Lname']}'),
            subtitle: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text('Hospital ID: ${appointment['hospitalId']}'),
                Text('Reason: ${appointment['reason']}'),
                Text('Date: ${appointment['date'].toDate()}'),
                Text('Status: ${appointment['status']}'),
              ],
            ),
          ),
        );
      },
    );
  }
}
