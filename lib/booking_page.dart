import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import 'package:cloud_firestore/cloud_firestore.dart';

class BookingPage extends StatefulWidget {
  final String currentUserId;
  const BookingPage({required this.currentUserId, Key? key}) : super(key: key);

  @override
  _BookingPageState createState() => _BookingPageState();
}

class _BookingPageState extends State<BookingPage> with SingleTickerProviderStateMixin {
  late Stream<QuerySnapshot> _allBookingsStream;
  late AnimationController _animationController;
  late Animation<double> _progressAnimation;

  @override
  void initState() {
    super.initState();
    _allBookingsStream = FirebaseFirestore.instance.collection('Bookings').snapshots();
    _animationController = AnimationController(
      vsync: this,
      duration: Duration(seconds: 2),
    )..repeat();
    _progressAnimation = Tween<double>(begin: 0, end: 1).animate(_animationController);
  }

  @override
  void dispose() {
    _animationController.dispose();
    super.dispose();
  }

  Widget _buildSophisticatedProgressIndicator() {
    return AnimatedBuilder(
      animation: _animationController,
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
    return DefaultTabController(
      length: 2,
      child: Scaffold(
        appBar: AppBar(
          title: Text(
            "Bookings",
            style: TextStyle(fontWeight: FontWeight.bold, color: Colors.white),
          ),
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
          return Center(
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                _buildSophisticatedProgressIndicator(),
                SizedBox(height: 16),
                Text(
                  "Loading Requests...",
                  style: TextStyle(fontSize: 16, color: Colors.teal),
                ),
              ],
            ),
          );
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

        if (requests.isEmpty) {
          return _buildEmptyState("No booking requests found");
        }

        requests.sort((a, b) => _sortBookings(a, b));
        return ListView.builder(
          padding: EdgeInsets.all(16),
          itemCount: requests.length,
          itemBuilder: (context, index) =>
              _buildAppointmentCard(requests[index], requests[index]['patientId'], true),
        );
      },
    );
  }

  Widget _buildAppointments() {
    return StreamBuilder(
      stream: FirebaseFirestore.instance.collection('Bookings').doc(widget.currentUserId).snapshots(),
      builder: (context, AsyncSnapshot<DocumentSnapshot> snapshot) {
        if (snapshot.connectionState == ConnectionState.waiting) {
          return Center(
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                _buildSophisticatedProgressIndicator(),
                SizedBox(height: 16),
                Text(
                  "Loading Appointments...",
                  style: TextStyle(fontSize: 16, color: Colors.teal),
                ),
              ],
            ),
          );
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
      itemBuilder: (context, index) =>
          _buildAppointmentCard(filtered[index], widget.currentUserId, false),
    );
  }

  Widget _buildAppointmentCard(Map<String, dynamic> appointment, String userId, bool isRequest) {
    return FutureBuilder(
      future: FirebaseFirestore.instance.collection('Users').doc(userId).get(),
      builder: (context, AsyncSnapshot<DocumentSnapshot> userSnapshot) {
        if (userSnapshot.connectionState == ConnectionState.waiting) {
          return Card(
            elevation: 2,
            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
            margin: EdgeInsets.symmetric(vertical: 8),
            child: Padding(
              padding: EdgeInsets.all(16),
              child: Center(child: _buildSophisticatedProgressIndicator()),
            ),
          );
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
                  backgroundImage:
                  userInfo['User Pic'] != null ? NetworkImage(userInfo['User Pic']) : null,
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
      if (!doc.exists) return;

      List<dynamic> bookings = List.from(doc['Bookings']);
      int index = bookings.indexWhere((b) => b['date'] == date);
      if (index == -1) return;

      final updatedBooking = await _showUpdateBookingDialog(context, bookings[index], newStatus);
      if (updatedBooking == null) return;

      bookings[index] = updatedBooking;

      await FirebaseFirestore.instance.collection('Bookings').doc(userId).update({
        'Bookings': bookings,
      });

      _showModernSnackBar(context, "Status updated to $newStatus");
    } catch (e) {
      _showModernSnackBar(context, "Failed to update status: $e", isError: true);
    }
  }

  Future<Map<String, dynamic>?> _showUpdateBookingDialog(
      BuildContext context, Map<String, dynamic> booking, String newStatus) async {
    DateTime selectedDateTime = booking['date'].toDate();
    final TextEditingController reasonController = TextEditingController(text: booking['reason']);

    return await showDialog<Map<String, dynamic>>(
      context: context,
      barrierDismissible: false,
      builder: (context) {
        return StatefulBuilder(
          builder: (context, setState) {
            return Dialog(
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
              elevation: 10,
              child: Padding(
                padding: const EdgeInsets.all(20.0),
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      'Accept Booking',
                      style: TextStyle(
                        fontSize: 20,
                        fontWeight: FontWeight.bold,
                        color: Colors.teal,
                      ),
                    ),
                    SizedBox(height: 16),
                    Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        Text(
                          "Date: ${DateFormat('MMM dd, yyyy HH:mm').format(selectedDateTime)}",
                          style: TextStyle(fontSize: 14, color: Colors.grey[700]),
                        ),
                        TextButton(
                          onPressed: () async {
                            final newDate = await _selectDateTime(context, selectedDateTime);
                            if (newDate != null) {
                              setState(() {
                                selectedDateTime = newDate;
                              });
                            }
                          },
                          child: Text('Change', style: TextStyle(color: Colors.teal)),
                        ),
                      ],
                    ),
                    SizedBox(height: 16),
                    TextField(
                      controller: reasonController,
                      maxLines: 3,
                      decoration: InputDecoration(
                        hintText: 'Update reason (optional)',
                        hintStyle: TextStyle(color: Colors.grey[400]),
                        filled: true,
                        fillColor: Colors.grey[100],
                        border: OutlineInputBorder(
                          borderRadius: BorderRadius.circular(12),
                          borderSide: BorderSide.none,
                        ),
                        contentPadding: EdgeInsets.symmetric(vertical: 12, horizontal: 16),
                      ),
                    ),
                    SizedBox(height: 20),
                    Row(
                      mainAxisAlignment: MainAxisAlignment.end,
                      children: [
                        TextButton(
                          onPressed: () => Navigator.pop(context, null),
                          child: Text('Cancel', style: TextStyle(color: Colors.grey[600])),
                        ),
                        SizedBox(width: 10),
                        ElevatedButton(
                          onPressed: () {
                            Navigator.pop(context, {
                              'doctorId': booking['doctorId'],
                              'hospitalId': booking['hospitalId'],
                              'date': Timestamp.fromDate(selectedDateTime),
                              'status': newStatus,
                              'reason': reasonController.text.trim().isEmpty
                                  ? booking['reason']
                                  : reasonController.text.trim(),
                            });
                          },
                          style: ElevatedButton.styleFrom(
                            backgroundColor: Colors.teal,
                            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                            padding: EdgeInsets.symmetric(horizontal: 20, vertical: 12),
                          ),
                          child: Text('Confirm', style: TextStyle(color: Colors.white)),
                        ),
                      ],
                    ),
                  ],
                ),
              ),
            );
          },
        );
      },
    );
  }

  Future<DateTime?> _selectDateTime(BuildContext context, DateTime initialDate) async {
    final DateTime? pickedDate = await showDatePicker(
      context: context,
      initialDate: initialDate,
      firstDate: DateTime.now(),
      lastDate: DateTime(2101),
      builder: (context, child) {
        return Theme(
          data: ThemeData.light().copyWith(
            colorScheme: ColorScheme.light(primary: Colors.teal),
            buttonTheme: ButtonThemeData(textTheme: ButtonTextTheme.primary),
          ),
          child: child!,
        );
      },
    );

    if (pickedDate == null) return null;

    final TimeOfDay? pickedTime = await showTimePicker(
      context: context,
      initialTime: TimeOfDay.fromDateTime(initialDate),
      builder: (context, child) {
        return Theme(
          data: ThemeData.light().copyWith(
            colorScheme: ColorScheme.light(primary: Colors.teal),
          ),
          child: child!,
        );
      },
    );

    if (pickedTime == null) return null;

    return DateTime(
      pickedDate.year,
      pickedDate.month,
      pickedDate.day,
      pickedTime.hour,
      pickedTime.minute,
    );
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
        _showModernSnackBar(context, "Booking deleted successfully");
      }
    } catch (e) {
      _showModernSnackBar(context, "Failed to delete booking: $e", isError: true);
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

  void _showModernSnackBar(BuildContext context, String message, {bool isError = false}) {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Row(
          children: [
            Icon(
              isError ? Icons.error_outline : Icons.check_circle_outline,
              color: Colors.white,
            ),
            SizedBox(width: 10),
            Expanded(child: Text(message, style: TextStyle(color: Colors.white))),
          ],
        ),
        backgroundColor: isError ? Colors.redAccent : Colors.teal,
        behavior: SnackBarBehavior.floating,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
        margin: EdgeInsets.all(10),
        duration: Duration(seconds: 3),
      ),
    );
  }
}