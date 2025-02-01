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
  };

  bool isDoctor = false;
  String selectedStatus = 'Pending'; // Default to Pending
  bool isLoading = true;

  @override
  void initState() {
    super.initState();
    checkUserRole();
  }

  Future<void> checkUserRole() async {
    try {
      var userDoc =
      await FirebaseFirestore.instance.collection('Users').doc(widget.userId).get();
      if (userDoc.exists && userDoc.data()?['Role'] == true) {
        setState(() {
          isDoctor = true;
        });
      }
      fetchAppointments();
    } catch (e) {
      print("Error fetching user role: $e");
    }
  }

  Future<void> fetchAppointments() async {
    try {
      if (isDoctor) {
        var bookingsSnapshot =
        await FirebaseFirestore.instance.collection('Bookings').get();
        for (var doc in bookingsSnapshot.docs) {
          List<dynamic> bookings = doc.data()['Bookings'] ?? [];
          for (var booking in bookings) {
            if (booking['doctorId'] == widget.userId) {
              // Use the document ID of the matched booking as the patient ID
              var patientDoc = await FirebaseFirestore.instance.collection('Users').doc(doc.id).get();
              if (patientDoc.exists) {
                booking['patientInfo'] = {
                  'fname': patientDoc.data()?['Fname'],
                  'lname': patientDoc.data()?['Lname'],
                  'userPic': patientDoc.data()?['User Pic'],
                };
                categorizedAppointments[booking['status']]?.add(booking);
              }
            }
          }
        }
      } else {
        var bookingDoc =
        await FirebaseFirestore.instance.collection('Bookings').doc(widget.userId).get();
        if (bookingDoc.exists) {
          List<dynamic> bookings = bookingDoc.data()?['Bookings'] ?? [];
          for (var booking in bookings) {
            String doctorId = booking['doctorId'];
            String status = booking['status'];
            var doctorDoc = await FirebaseFirestore.instance.collection('Users').doc(doctorId).get();
            if (doctorDoc.exists && doctorDoc.data()?['Status'] == true) {
              booking['doctorInfo'] = {
                'title': doctorDoc.data()?['Title'],
                'fname': doctorDoc.data()?['Fname'],
                'lname': doctorDoc.data()?['Lname'],
                'userPic': doctorDoc.data()?['User Pic'],
              };
              categorizedAppointments[status]?.add(booking);
            }
          }
        }
      }
    } catch (e) {
      print("Error fetching appointments: $e");
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
                if (isDoctor) ...[
                  statusLabel('Requests', Colors.orange),
                  statusLabel('Appointments', Colors.purple),
                ],
                statusLabel('Pending', Colors.blue),
                statusLabel('Active', Colors.green),
                statusLabel('Terminated', Colors.red),
              ],
            ),
          ),
          Expanded(
            flex: 5,
            child: ListView(
              children: [
                if (isDoctor) ...[
                  appointmentSection('Requests', 'Pending'),
                  appointmentSection('Appointments', 'Active'),
                ],
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
            fontSize: 18,
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
          style: TextStyle(fontSize: 16, fontStyle: FontStyle.italic),
        ),
      );
    }
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: appointments.map((appointment) => appointmentCard(appointment)).toList(),
    );
  }

  Widget appointmentCard(Map<String, dynamic> appointment) {
    var userInfo = isDoctor ? appointment['patientInfo'] : appointment['doctorInfo'];
    Timestamp bookingDate = appointment['date'];
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
}
