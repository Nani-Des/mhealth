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
          title: Text("Bookings", style: TextStyle(fontWeight: FontWeight.bold, color: Colors.white)),
          backgroundColor: Colors.teal,
          elevation: 0,
          bottom: TabBar(
            indicatorColor: Colors.white,
            labelColor: Colors.white,
            unselectedLabelColor: Colors.white70,
            tabs: [
              Tab(text: "Requests"),
              Tab(text: "Appointments"),
            ],
          ),
        ),
        body: Container(
          color: Colors.grey[100],
          child: TabBarView(
            children: [
              _buildRequests(),
              _buildAppointments(),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildRequests() {
    return StreamBuilder(
      stream: _allBookingsStream,
      builder: (context, AsyncSnapshot<QuerySnapshot> snapshot) {
        if (snapshot.connectionState == ConnectionState.waiting) {
          return Center(child: CircularProgressIndicator(color: Colors.teal));
        }
        if (!snapshot.hasData || snapshot.data!.docs.isEmpty) {
          return _buildEmptyState("No booking requests found");
        }

        List<Map<String, dynamic>> requests = [];
        for (var doc in snapshot.data!.docs) {
          var bookings = doc['Bookings'] as List<dynamic>? ?? [];
          for (var booking in bookings) {
            if (booking['doctorId'] == widget.currentUserId) {
              if (_isDateInPast(booking['date'])) {
                booking['status'] = "Terminated";
              }
              requests.add({...booking, 'patientId': doc.id});
            }
          }
        }

        requests.sort((a, b) => _sortBookings(a, b));
        return ListView.builder(
          padding: EdgeInsets.all(16),
          itemCount: requests.length,
          itemBuilder: (context, index) => _buildAppointmentCard(requests[index], requests[index]['patientId'], true),
        );
      },
    );
  }

  Widget _buildAppointments() {
    return StreamBuilder(
      stream: FirebaseFirestore.instance.collection('Bookings').doc(widget.currentUserId).snapshots(),
      builder: (context, AsyncSnapshot<DocumentSnapshot> snapshot) {
        if (snapshot.connectionState == ConnectionState.waiting) {
          return Center(child: CircularProgressIndicator(color: Colors.teal));
        }
        if (!snapshot.hasData || !snapshot.data!.exists) {
          return _buildEmptyState("No appointments found");
        }

        var bookings = List<Map<String, dynamic>>.from(snapshot.data!['Bookings'] ?? []);
        bookings.forEach((booking) {
          if (_isDateInPast(booking['date'])) {
            booking['status'] = "Terminated";
          }
        });

        int pendingCount = bookings.where((doc) => doc['status'] == "Pending").length;
        int activeCount = bookings.where((doc) => doc['status'] == "Active").length;
        int terminatedCount = bookings.where((doc) => doc['status'] == "Terminated").length;

        _updateBookingStatusInDB(bookings);

        return DefaultTabController(
          length: 3,
          child: Column(
            children: [
              TabBar(
                indicatorColor: Colors.teal,
                labelColor: Colors.teal,
                unselectedLabelColor: Colors.grey[600],
                tabs: [
                  Tab(text: "Pending ($pendingCount)"),
                  Tab(text: "Active ($activeCount)"),
                  Tab(text: "Terminated ($terminatedCount)"),
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

  Widget _buildStatusList(List<Map<String, dynamic>> bookings, String status) {
    var filtered = bookings.where((doc) => doc['status'] == status).toList();
    return filtered.isEmpty
        ? _buildEmptyState("No $status appointments")
        : ListView.builder(
      padding: EdgeInsets.all(16),
      itemCount: filtered.length,
      itemBuilder: (context, index) => _buildAppointmentCard(filtered[index], widget.currentUserId, false),
    );
  }

  Widget _buildAppointmentCard(Map<String, dynamic> appointment, String userId, bool isRequest) {
    return FutureBuilder(
      future: FirebaseFirestore.instance.collection('Users').doc(userId).get(),
      builder: (context, AsyncSnapshot<DocumentSnapshot> userSnapshot) {
        if (userSnapshot.connectionState == ConnectionState.waiting) {
          return Center(child: CircularProgressIndicator(color: Colors.teal));
        }
        if (!userSnapshot.hasData || !userSnapshot.data!.exists) {
          return SizedBox.shrink();
        }
        var userInfo = userSnapshot.data!.data() as Map<String, dynamic>;
        String formattedDate = appointment['date'] is Timestamp
            ? DateFormat('MMM dd, yyyy HH:mm').format(appointment['date'].toDate())
            : appointment['date'].toString();

        Color borderColor = appointment['status'] == "Active"
            ? Colors.teal
            : appointment['status'] == "Pending"
            ? Colors.orange
            : Colors.red;

        return Card(
          elevation: 4,
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(12),
            side: BorderSide(color: borderColor, width: 2),
          ),
          margin: EdgeInsets.symmetric(vertical: 8),
          child: Padding(
            padding: EdgeInsets.all(16),
            child: Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                CircleAvatar(
                  radius: 25,
                  backgroundColor: Colors.teal.withOpacity(0.1),
                  backgroundImage: userInfo['User Pic'] != null ? NetworkImage(userInfo['User Pic']) : null,
                  child: userInfo['User Pic'] == null ? Icon(Icons.person, color: Colors.teal) : null,
                ),
                SizedBox(width: 16),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        "${userInfo['Fname']} ${userInfo['Lname']}",
                        style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold, color: Colors.grey[800]),
                      ),
                      SizedBox(height: 4),
                      Text(
                        "Reason: ${appointment['reason']}",
                        style: TextStyle(fontSize: 14, color: Colors.grey[600], fontStyle: FontStyle.italic),
                      ),
                      SizedBox(height: 4),
                      Text(
                        "Date: $formattedDate",
                        style: TextStyle(fontSize: 14, color: Colors.grey[700]),
                      ),
                      SizedBox(height: 4),
                      _buildStatusChip(appointment['status']),
                    ],
                  ),
                ),
                if (isRequest && appointment['status'] != "Active")
                  Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      IconButton(
                        icon: Icon(Icons.check, color: Colors.green),
                        onPressed: () => _updateStatus(userId, appointment['date'], "Active"),
                      ),
                      IconButton(
                        icon: Icon(Icons.delete, color: Colors.red),
                        onPressed: () => _confirmDelete(userId, appointment['date']),
                      ),
                    ],
                  )
                else if (!isRequest && appointment['status'] == "Pending")
                  IconButton(
                    icon: Icon(Icons.delete, color: Colors.red),
                    onPressed: () => _confirmDelete(userId, appointment['date']),
                  ),
              ],
            ),
          ),
        );
      },
    );
  }

  Widget _buildStatusChip(String status) {
    Color color;
    switch (status) {
      case "Active":
        color = Colors.teal;
        break;
      case "Pending":
        color = Colors.orange;
        break;
      case "Terminated":
        color = Colors.red;
        break;
      default:
        color = Colors.grey;
    }
    return Chip(
      label: Text(status, style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold)),
      backgroundColor: color.withOpacity(0.8),
      padding: EdgeInsets.symmetric(horizontal: 8),
    );
  }

  Widget _buildEmptyState(String message) {
    return Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Icon(Icons.event_busy, size: 48, color: Colors.grey),
          SizedBox(height: 16),
          Text(message, style: TextStyle(fontSize: 18, color: Colors.grey)),
        ],
      ),
    );
  }

  int _sortBookings(Map<String, dynamic> a, Map<String, dynamic> b) {
    if (a['status'] == "Active" && b['status'] != "Active") return -1;
    if (a['status'] != "Active" && b['status'] == "Active") return 1;
    if (a['status'] == "Terminated" && b['status'] != "Terminated") return 1;
    if (a['status'] != "Terminated" && b['status'] == "Terminated") return -1;
    return 0;
  }

  bool _isDateInPast(Timestamp timestamp) {
    return timestamp.toDate().isBefore(DateTime.now());
  }

  void _updateStatus(String userId, Timestamp date, String newStatus) async {
    try {
      DocumentSnapshot doc = await FirebaseFirestore.instance.collection('Bookings').doc(userId).get();
      if (doc.exists) {
        List<dynamic> bookings = List.from(doc['Bookings']);
        int index = bookings.indexWhere((b) => b['date'] == date);
        if (index != -1) {
          bookings[index]['status'] = newStatus;
          await FirebaseFirestore.instance.collection('Bookings').doc(userId).update({'Bookings': bookings});
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(content: Text("Status updated to $newStatus")),
          );
        }
      }
    } catch (e) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text("Failed to update status: $e")),
      );
    }
  }

  void _confirmDelete(String userId, Timestamp date) {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
        title: Row(
          children: [
            Icon(Icons.warning, color: Colors.red),
            SizedBox(width: 8),
            Text("Confirm Delete"),
          ],
        ),
        content: Text("Are you sure you want to delete this booking?"),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: Text("Cancel", style: TextStyle(color: Colors.teal)),
          ),
          TextButton(
            onPressed: () {
              _deleteBooking(userId, date);
              Navigator.pop(context);
            },
            child: Text("Delete", style: TextStyle(color: Colors.red)),
          ),
        ],
      ),
    );
  }

  void _deleteBooking(String userId, Timestamp date) async {
    try {
      DocumentReference docRef = FirebaseFirestore.instance.collection('Bookings').doc(userId);
      DocumentSnapshot doc = await docRef.get();
      if (doc.exists) {
        List<dynamic> bookings = List.from(doc['Bookings']);
        bookings.removeWhere((booking) => booking['date'] == date);
        await docRef.update({'Bookings': bookings});
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text("Booking deleted successfully")),
        );
      }
    } catch (e) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text("Failed to delete booking: $e")),
      );
    }
  }

  void _updateBookingStatusInDB(List<Map<String, dynamic>> bookings) async {
    try {
      await FirebaseFirestore.instance.collection('Bookings').doc(widget.currentUserId).update({
        'Bookings': bookings,
      });
    } catch (e) {
      print("Error updating booking status: $e");
    }
  }
}