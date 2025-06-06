import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:intl/intl.dart';
import 'package:printing/printing.dart';
import 'package:pdf/pdf.dart';
import 'package:pdf/widgets.dart' as pw;
import 'package:shared_preferences/shared_preferences.dart';

class BookingDetailsPage extends StatefulWidget {
  final String userId;
  final String doctorId;
  final Timestamp bookingDate;
  final String currentUserId;

  const BookingDetailsPage({
    required this.userId,
    required this.doctorId,
    required this.bookingDate,
    required this.currentUserId,
    Key? key,
  }) : super(key: key);

  @override
  _BookingDetailsPageState createState() => _BookingDetailsPageState();
}

class _BookingDetailsPageState extends State<BookingDetailsPage> {
  Map<String, dynamic>? booking;
  Map<String, dynamic>? patientInfo;
  Map<String, dynamic>? doctorInfo;
  bool isLoading = true;
  bool isDoctor = false;
  String? error;

  @override
  void initState() {
    super.initState();
    _fetchBookingDetails();
    _checkUserRole();
  }

  Future<void> _checkUserRole() async {
    try {
      DocumentSnapshot userDoc = await FirebaseFirestore.instance
          .collection('Users')
          .doc(widget.currentUserId)
          .get();
      if (userDoc.exists) {
        setState(() {
          isDoctor = userDoc['Role'] == true;
        });
      }
    } catch (e) {
      _showSnackBar('Error checking user role: $e', isError: true);
    }
  }

  Future<void> _fetchBookingDetails() async {
    try {
      DocumentSnapshot bookingDoc = await FirebaseFirestore.instance
          .collection('Bookings')
          .doc(widget.userId)
          .get();
      if (!bookingDoc.exists) {
        setState(() {
          error = 'Booking not found';
          isLoading = false;
        });
        return;
      }

      List<dynamic> bookings = bookingDoc['Bookings'] ?? [];
      var selectedBooking = bookings.firstWhere(
            (b) =>
        b['date'] is Timestamp &&
            b['date'].toDate().millisecondsSinceEpoch ==
                widget.bookingDate.toDate().millisecondsSinceEpoch &&
            b['doctorId'] == widget.doctorId,
        orElse: () => null,
      );

      if (selectedBooking == null) {
        setState(() {
          error = 'Booking not found';
          isLoading = false;
        });
        return;
      }

      DocumentSnapshot patientDoc = await FirebaseFirestore.instance
          .collection('Users')
          .doc(widget.userId)
          .get();
      DocumentSnapshot doctorDoc = await FirebaseFirestore.instance
          .collection('Users')
          .doc(widget.doctorId)
          .get();

      setState(() {
        booking = selectedBooking;
        patientInfo = patientDoc.exists ? patientDoc.data() as Map<String, dynamic> : null;
        doctorInfo = doctorDoc.exists ? doctorDoc.data() as Map<String, dynamic> : null;
        isLoading = false;
      });
    } catch (e) {
      setState(() {
        error = 'Error loading booking details: $e';
        isLoading = false;
      });
    }
  }

  Future<void> _acceptBooking() async {
    try {
      DocumentSnapshot doc = await FirebaseFirestore.instance
          .collection('Bookings')
          .doc(widget.userId)
          .get();
      if (!doc.exists) {
        _showSnackBar('Booking document not found', isError: true);
        return;
      }

      List<dynamic> bookings = List.from(doc['Bookings'] ?? []);
      int index = bookings.indexWhere((b) =>
      b['date'] is Timestamp &&
          b['date'].toDate().millisecondsSinceEpoch ==
              widget.bookingDate.toDate().millisecondsSinceEpoch &&
          b['doctorId'] == widget.doctorId);
      if (index == -1) {
        _showSnackBar('Booking not found', isError: true);
        return;
      }

      DateTime selectedDateTime = bookings[index]['date'].toDate();
      final reasonController = TextEditingController(text: bookings[index]['reason']);

      final updatedBooking = await showDialog<Map<String, dynamic>>(
        context: context,
        barrierDismissible: true,
        builder: (context) {
          return StatefulBuilder(
            builder: (context, setState) {
              return Dialog(
                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
                child: Padding(
                  padding: const EdgeInsets.all(16.0),
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      const Text(
                        'Accept Booking',
                        style: TextStyle(fontSize: 20, fontWeight: FontWeight.bold, color: Colors.teal),
                      ),
                      const SizedBox(height: 16),
                      Row(
                        mainAxisAlignment: MainAxisAlignment.spaceBetween,
                        children: [
                          Text(
                            'Date: ${DateFormat('MMM d, yyyy h:mm a').format(selectedDateTime)}',
                            style: const TextStyle(fontSize: 14, color: Colors.grey),
                          ),
                          TextButton(
                            onPressed: () async {
                              final newDate = await _selectDateTime(context, selectedDateTime);
                              if (newDate != null) {
                                setState(() => selectedDateTime = newDate);
                              }
                            },
                            child: const Text('Change', style: TextStyle(color: Colors.teal)),
                          ),
                        ],
                      ),
                      const SizedBox(height: 16),
                      TextField(
                        controller: reasonController,
                        maxLines: 3,
                        decoration: InputDecoration(
                          hintText: 'Reason for Booking',
                          hintStyle: TextStyle(color: Colors.grey[400]),
                          border: OutlineInputBorder(
                            borderRadius: BorderRadius.circular(12),
                          ),
                          contentPadding: const EdgeInsets.symmetric(vertical: 12, horizontal: 16),
                        ),
                      ),
                      const SizedBox(height: 20),
                      Row(
                        mainAxisAlignment: MainAxisAlignment.end,
                        children: [
                          TextButton(
                            onPressed: () => Navigator.pop(context, null),
                            child: const Text('Cancel', style: TextStyle(color: Colors.grey)),
                          ),
                          const SizedBox(width: 10),
                          ElevatedButton(
                            onPressed: () {
                              Navigator.pop(context, {
                                'doctorId': bookings[index]['doctorId'],
                                'hospitalId': bookings[index]['hospitalId'],
                                'date': Timestamp.fromDate(selectedDateTime),
                                'status': 'Active',
                                'reason': reasonController.text.trim().isEmpty
                                    ? bookings[index]['reason']
                                    : reasonController.text.trim(),
                              });
                            },
                            style: ElevatedButton.styleFrom(
                              backgroundColor: Colors.teal,
                              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                            ),
                            child: const Text('Confirm', style: TextStyle(color: Colors.white)),
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

      if (updatedBooking == null) return;

      bookings[index] = updatedBooking;
      await FirebaseFirestore.instance.collection('Bookings').doc(widget.userId).update({
        'Bookings': bookings,
      });

      final prefs = await SharedPreferences.getInstance();
      await prefs.remove('processed_appointments_${widget.currentUserId}');

      setState(() {
        booking = updatedBooking;
      });
      _showSnackBar('Booking accepted successfully');
    } catch (e) {
      _showSnackBar('Failed to accept booking: $e', isError: true);
    }
  }

  Future<void> _rejectOrCancelBooking() async {
    bool isReject = isDoctor;
    try {
      DocumentSnapshot doc = await FirebaseFirestore.instance
          .collection('Bookings')
          .doc(widget.userId)
          .get();
      if (!doc.exists) {
        _showSnackBar('Booking document not found', isError: true);
        return;
      }

      List<dynamic> bookings = List.from(doc['Bookings'] ?? []);
      int index = bookings.indexWhere((b) =>
      b['date'] is Timestamp &&
          b['date'].toDate().millisecondsSinceEpoch ==
              widget.bookingDate.toDate().millisecondsSinceEpoch &&
          b['doctorId'] == widget.doctorId);
      if (index == -1) {
        _showSnackBar('Booking not found', isError: true);
        return;
      }

      bool? confirm = await showDialog<bool>(
        context: context,
        builder: (context) => AlertDialog(
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
          title: Row(
            children: [
              const Icon(Icons.warning, color: Colors.red),
              const SizedBox(width: 8),
              Text(isReject ? 'Reject Booking' : 'Cancel Booking'),
            ],
          ),
          content: Text('Are you sure you want to ${isReject ? 'reject' : 'cancel'} this booking?'),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(context, false),
              child: const Text('No', style: TextStyle(color: Colors.teal)),
            ),
            TextButton(
              onPressed: () => Navigator.pop(context, true),
              child: const Text('Yes', style: TextStyle(color: Colors.red)),
            ),
          ],
        ),
      );

      if (confirm != true) return;

      bookings.removeAt(index);
      await FirebaseFirestore.instance.collection('Bookings').doc(widget.userId).update({
        'Bookings': bookings,
      });

      final prefs = await SharedPreferences.getInstance();
      await prefs.remove('processed_appointments_${widget.currentUserId}');

      setState(() {
        booking = null;
      });
      _showSnackBar('Booking ${isReject ? 'rejected' : 'canceled'} successfully');
      Navigator.pop(context);
    } catch (e) {
      _showSnackBar('Failed to ${isReject ? 'reject' : 'cancel'} booking: $e', isError: true);
    }
  }

  Future<void> _printBookingDetails() async {
    final doc = pw.Document();
    doc.addPage(
      pw.Page(
        build: (pw.Context context) => pw.Column(
          crossAxisAlignment: pw.CrossAxisAlignment.start,
          children: [
            pw.Text('Booking Details', style: pw.TextStyle(fontSize: 24, fontWeight: pw.FontWeight.bold)),
            pw.SizedBox(height: 20),
            pw.Text('Patient: ${patientInfo?['Fname'] ?? 'Unknown'} ${patientInfo?['Lname'] ?? 'Unknown'}'),
            pw.Text('Doctor: ${doctorInfo?['Fname'] ?? 'Unknown'} ${doctorInfo?['Lname'] ?? 'Unknown'}'),
            pw.Text('Date: ${DateFormat('MMM d, yyyy h:mm a').format(widget.bookingDate.toDate())}'),
            pw.Text('Reason: ${booking?['reason'] ?? 'N/A'}'),
            pw.Text('Status: ${booking?['status'] ?? 'Unknown'}'),
            pw.Text('Hospital ID: ${booking?['hospitalId'] ?? 'N/A'}'),
          ],
        ),
      ),
    );

    await Printing.layoutPdf(
      onLayout: (PdfPageFormat format) async => doc.save(),
    );
  }

  Future<DateTime?> _selectDateTime(BuildContext context, DateTime initialDate) async {
    final pickedDate = await showDatePicker(
      context: context,
      initialDate: initialDate,
      firstDate: DateTime.now(),
      lastDate: DateTime(2101),
      builder: (context, child) => Theme(
        data: ThemeData.light().copyWith(
          colorScheme: const ColorScheme.light(primary: Colors.teal),
        ),
        child: child!,
      ),
    );

    if (pickedDate == null) return null;

    final pickedTime = await showTimePicker(
      context: context,
      initialTime: TimeOfDay.fromDateTime(initialDate),
      builder: (context, child) => Theme(
        data: ThemeData.light().copyWith(
          colorScheme: const ColorScheme.light(primary: Colors.teal),
        ),
        child: child!,
      ),
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

  void _showSnackBar(String message, {bool isError = false}) {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Row(
          children: [
            Icon(
              isError ? Icons.error_outline : Icons.check_circle_outline,
              color: Colors.white,
            ),
            const SizedBox(width: 10),
            Expanded(child: Text(message, style: const TextStyle(color: Colors.white))),
          ],
        ),
        backgroundColor: isError ? Colors.redAccent : Colors.teal,
        behavior: SnackBarBehavior.floating,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
        margin: const EdgeInsets.all(10),
        duration: const Duration(seconds: 3),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Booking Details', style: TextStyle(color: Colors.white)),
        backgroundColor: Colors.teal,
        elevation: 0,
        leading: IconButton(
          icon: const Icon(Icons.arrow_back_ios_new, color: Colors.white),
          onPressed: () => Navigator.pop(context),
        ),
      ),
      body: isLoading
          ? const Center(child: CircularProgressIndicator(color: Colors.teal))
          : error != null
          ? Center(child: Text(error!, style: const TextStyle(fontSize: 18, color: Colors.red)))
          : booking == null
          ? const Center(child: Text('No booking found', style: TextStyle(fontSize: 18, color: Colors.grey)))
          : SingleChildScrollView(
        padding: const EdgeInsets.all(16.0),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Card(
              elevation: 4,
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
              child: Padding(
                padding: const EdgeInsets.all(16.0),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      'Booking Information',
                      style: TextStyle(
                        fontSize: 20,
                        fontWeight: FontWeight.bold,
                        color: Colors.teal[700],
                      ),
                    ),
                    const SizedBox(height: 16),
                    _buildDetailRow(
                      'Patient',
                      '${patientInfo?['Fname'] ?? 'Unknown'} ${patientInfo?['Lname'] ?? 'Unknown'}',
                    ),
                    _buildDetailRow(
                      'Doctor',
                      '${doctorInfo?['Fname'] ?? 'Unknown'} ${doctorInfo?['Lname'] ?? 'Unknown'}',
                    ),
                    _buildDetailRow(
                      'Date',
                      DateFormat('MMM d, yyyy h:mm a').format(widget.bookingDate.toDate()),
                    ),
                    _buildDetailRow('Reason', booking!['reason'] ?? 'N/A'),
                    _buildDetailRow('Status', booking!['status'] ?? 'Unknown'),
                    _buildDetailRow('Hospital ID', booking!['hospitalId'] ?? 'N/A'),
                  ],
                ),
              ),
            ),
            const SizedBox(height: 24),
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceEvenly,
              children: [
                if (isDoctor && booking!['status'] == 'Pending')
                  ElevatedButton.icon(
                    icon: const Icon(Icons.check, color: Colors.white),
                    label: const Text('Accept', style: TextStyle(color: Colors.white)),
                    style: ElevatedButton.styleFrom(
                      backgroundColor: Colors.green,
                      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                      padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 12),
                    ),
                    onPressed: _acceptBooking,
                  ),
                if ((isDoctor || !isDoctor) && booking!['status'] == 'Pending')
                  ElevatedButton.icon(
                    icon: const Icon(Icons.close, color: Colors.white),
                    label: Text(isDoctor ? 'Reject' : 'Cancel', style: const TextStyle(color: Colors.white)),
                    style: ElevatedButton.styleFrom(
                      backgroundColor: Colors.red,
                      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                      padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 12),
                    ),
                    onPressed: _rejectOrCancelBooking,
                  ),
                ElevatedButton.icon(
                  icon: const Icon(Icons.print, color: Colors.white),
                  label: const Text('Print', style: TextStyle(color: Colors.white)),
                  style: ElevatedButton.styleFrom(
                    backgroundColor: Colors.teal,
                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                    padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 12),
                  ),
                  onPressed: _printBookingDetails,
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildDetailRow(String label, String value) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 8.0),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          SizedBox(
            width: 120,
            child: Text(
              label,
              style: const TextStyle(fontSize: 16, fontWeight: FontWeight.bold, color: Colors.grey),
            ),
          ),
          Expanded(
            child: Text(
              value,
              style: const TextStyle(fontSize: 16, color: Colors.black87),
            ),
          ),
        ],
      ),
    );
  }
}