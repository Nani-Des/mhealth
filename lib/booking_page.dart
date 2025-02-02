import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import 'package:cloud_firestore/cloud_firestore.dart';

class BookingPage extends StatefulWidget {
  final String currentUserId;
  const BookingPage({required this.currentUserId, Key? key}) : super(key: key);

  @override
  _BookingPageState createState() => _BookingPageState();
}

class _BookingPageState extends State<BookingPage> {
  late Stream<QuerySnapshot> _allBookingsStream;

  @override
  void initState() {
    super.initState();
    _allBookingsStream = FirebaseFirestore.instance.collection('Bookings').snapshots();
  }

  @override
  Widget build(BuildContext context) {
    return DefaultTabController(
      length: 2,
      child: Scaffold(
        appBar: AppBar(
          title: const Text("Bookings"),
          bottom: const TabBar(
            tabs: [
              Tab(text: "Requests"),
              Tab(text: "Appointments"),
            ],
          ),
        ),
        body: TabBarView(
          children: [
            _buildRequests(),
            _buildAppointments(),
          ],
        ),
      ),
    );
  }

  Widget _buildRequests() {
    return StreamBuilder(
      stream: _allBookingsStream,
      builder: (context, AsyncSnapshot<QuerySnapshot> snapshot) {
        if (snapshot.connectionState == ConnectionState.waiting) {
          return const Center(child: CircularProgressIndicator());
        }
        if (!snapshot.hasData) {
          return const Center(child: Text("No booking requests."));
        }

        List<Map<String, dynamic>> requests = [];
        for (var doc in snapshot.data!.docs) {
          var bookings = doc['Bookings'] as List<dynamic>? ?? [];
          for (var booking in bookings) {
            if (booking['doctorId'] == widget.currentUserId) {
              // Check if the date is in the past and update status if needed
              if (_isDateInPast(booking['date'])) {
                booking['status'] = "Terminated";
              }
              requests.add({...booking, 'patientId': doc.id});
            }
          }
        }

        // Sort requests: Active first, then Pending, then Terminated
        requests.sort((a, b) {
          if (a['status'] == "Active" && b['status'] != "Active") return -1;
          if (a['status'] != "Active" && b['status'] == "Active") return 1;
          if (a['status'] == "Terminated" && b['status'] != "Terminated") return 1;
          if (a['status'] != "Terminated" && b['status'] == "Terminated") return -1;
          return 0;
        });

        return ListView(
          children: requests.map((doc) => _buildAppointmentCard(doc, doc['patientId'], true)).toList(),
        );
      },
    );
  }

  Widget _buildAppointments() {
    return StreamBuilder(
      stream: FirebaseFirestore.instance.collection('Bookings').doc(widget.currentUserId).snapshots(),
      builder: (context, AsyncSnapshot<DocumentSnapshot> snapshot) {
        if (snapshot.connectionState == ConnectionState.waiting) {
          return const Center(child: CircularProgressIndicator());
        }
        if (!snapshot.hasData || !snapshot.data!.exists) {
          return const Center(child: Text("No bookings."));
        }

        var bookings = snapshot.data!['Bookings'] as List<dynamic>? ?? [];

        // Check and update status for each booking (mark past ones as Terminated)
        bookings.forEach((booking) {
          if (_isDateInPast(booking['date'])) {
            booking['status'] = "Terminated";
          }
        });

        // Count Pending, Active, and Terminated appointments after status update
        int pendingCount = bookings.where((doc) => doc['status'] == "Pending").length;
        int activeCount = bookings.where((doc) => doc['status'] == "Active").length;
        int terminatedCount = bookings.where((doc) => doc['status'] == "Terminated").length;

        // Update the Firebase DB with the new status values
        _updateBookingStatusInDB(bookings);

        return DefaultTabController(
          length: 3,
          child: Column(
            children: [
              TabBar(
                tabs: [
                  Tab(
                    text: "Pending ($pendingCount)",  // Show count for Pending
                  ),
                  Tab(
                    text: "Active ($activeCount)",  // Show count for Active
                  ),
                  Tab(
                    text: "Terminated ($terminatedCount)",  // Show count for Terminated
                  ),
                ],
              ),
              Expanded(
                child: TabBarView(
                  children: [
                    _buildStatusList(bookings, "Pending"),
                    _buildStatusList(bookings, "Active"),
                    _buildStatusList(bookings, "Terminated"),
                  ],
                ),
              ),
            ],
          ),
        );
      },
    );
  }

  Widget _buildStatusList(List<dynamic> bookings, String status) {
    var filtered = bookings.where((doc) => doc['status'] == status).toList();
    return ListView(
      children: filtered.map((doc) => _buildAppointmentCard(doc, doc['doctorId'], false)).toList(),
    );
  }

  Widget _buildAppointmentCard(Map<String, dynamic> appointment, String userId, bool isRequest) {
    return FutureBuilder(
      future: FirebaseFirestore.instance.collection('Users').doc(userId).get(),
      builder: (context, AsyncSnapshot<DocumentSnapshot> userSnapshot) {
        if (userSnapshot.connectionState == ConnectionState.waiting) {
          return const Center(child: CircularProgressIndicator());
        }
        if (!userSnapshot.hasData || !userSnapshot.data!.exists) {
          return const SizedBox.shrink();
        }
        var userInfo = userSnapshot.data!.data() as Map<String, dynamic>;
        String formattedDate = appointment['date'] is Timestamp
            ? DateFormat('yyyy-MM-dd HH:mm').format(appointment['date'].toDate())
            : appointment['date'].toString();

        // Apply a light blue border for active items
        BoxDecoration decoration = appointment['status'] == "Active"
            ? BoxDecoration(
          border: Border.all(color: Colors.lightBlue, width: 2),
          borderRadius: BorderRadius.circular(10),
        )
            : BoxDecoration(
          borderRadius: BorderRadius.circular(10),
        );

        return Container(
          decoration: decoration,
          margin: const EdgeInsets.symmetric(vertical: 8.0, horizontal: 12.0),
          child: Card(
            elevation: 6,
            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(15)),
            color: Colors.white,
            shadowColor: Colors.grey.withOpacity(0.5),
            child: ListTile(
              leading: CircleAvatar(
                backgroundImage: userInfo['User Pic'] != null ? NetworkImage(userInfo['User Pic']) : null,
                child: userInfo['User Pic'] == null ? const Icon(Icons.person) : null,
              ),
              title: Text(
                "${userInfo['Fname']} ${userInfo['Lname']}",
                style: TextStyle(fontWeight: FontWeight.bold, fontSize: 18),
              ),
              subtitle: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    "Reason: ${appointment['reason']}",
                    style: TextStyle(fontStyle: FontStyle.italic, color: Colors.grey),
                  ),
                  Text("Date: $formattedDate"),
                ],
              ),
              trailing: isRequest
                  ? appointment['status'] == "Active"  // Check if the request is Active
                  ? null  // If Active, don't show the icons
                  : Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  IconButton(
                    icon: const Icon(Icons.check, color: Colors.green),
                    onPressed: () => _updateStatus(userId, appointment['date'], "Active"),
                  ),
                  IconButton(
                    icon: const Icon(Icons.delete, color: Colors.red),
                    onPressed: () => _deleteBooking(userId, appointment['date']),
                  ),
                ],
              )
                  : appointment['status'] == "Pending"
                  ? IconButton(
                icon: const Icon(Icons.delete, color: Colors.red),
                onPressed: () => _deleteBooking(userId, appointment['date']),
              )
                  : null,
            ),
          ),
        );
      },
    );
  }

  void _updateStatus(String userId, Timestamp date, String newStatus) {
    FirebaseFirestore.instance.collection('Bookings').doc(userId).get().then((doc) {
      if (doc.exists) {
        List<dynamic> bookings = List.from(doc['Bookings']);
        for (var booking in bookings) {
          if (booking['date'] == date) {
            booking['status'] = newStatus;
          }
        }
        FirebaseFirestore.instance.collection('Bookings').doc(userId).update({'Bookings': bookings});
      }
    });
  }

  void _deleteBooking(String userId, Timestamp date) {
    FirebaseFirestore.instance.collection('Bookings').doc(userId).get().then((doc) {
      if (doc.exists) {
        List<dynamic> bookings = List.from(doc['Bookings']);
        bookings.removeWhere((booking) => booking['date'] == date);
        FirebaseFirestore.instance.collection('Bookings').doc(userId).update({'Bookings': bookings});
      }
    });
  }

  bool _isDateInPast(Timestamp timestamp) {
    return timestamp.toDate().isBefore(DateTime.now());
  }

  void _updateBookingStatusInDB(List<dynamic> bookings) {
    FirebaseFirestore.instance.collection('Bookings').doc(widget.currentUserId).update({
      'Bookings': bookings,
    });
  }
}
