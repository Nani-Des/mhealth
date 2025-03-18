import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:table_calendar/table_calendar.dart';
import 'package:intl/intl.dart';

import '../Components/booking_helper.dart';

class DoctorAvailabilityCalendar extends StatefulWidget {
  final String doctorId;
  final String hospitalId;

  const DoctorAvailabilityCalendar({
    Key? key,
    required this.doctorId,
    required this.hospitalId,
  }) : super(key: key);

  @override
  _DoctorAvailabilityCalendarState createState() =>
      _DoctorAvailabilityCalendarState();
}

class _DoctorAvailabilityCalendarState
    extends State<DoctorAvailabilityCalendar> {
  int activeDays = 5;
  int offDays = 2;
  int shiftSwitch = 5;
  DateTime shiftStart = DateTime.now();
  Set<DateTime> holidays = {};
  Map<String, dynamic> shiftTimings = {};
  String doctorImage = ''; // To store the doctor's image URL.

  @override
  void initState() {
    super.initState();
    _fetchDoctorSchedule();
    _fetchHospitalShiftTimings();
    _fetchGlobalHolidays();
    _fetchDoctorImage(); // Fetch the doctor's image on initialization.
  }

  Future<void> _fetchDoctorSchedule() async {
    DocumentSnapshot scheduleSnapshot = await FirebaseFirestore.instance
        .collection('Users')
        .doc(widget.doctorId)
        .collection('Schedule')
        .doc(widget.doctorId)
        .get();

    if (scheduleSnapshot.exists) {
      setState(() {
        activeDays = scheduleSnapshot['Active Days'] ?? 5;
        offDays = scheduleSnapshot['Off Days'] ?? 2;
        shiftSwitch = scheduleSnapshot['Shift Switch'] ?? 5;
        shiftStart = (scheduleSnapshot['Shift Start'] as Timestamp).toDate();
      });
    }
  }

  Future<void> _fetchHospitalShiftTimings() async {
    DocumentSnapshot hospitalSnapshot = await FirebaseFirestore.instance
        .collection('Hospital')
        .doc(widget.hospitalId)
        .get();

    if (hospitalSnapshot.exists) {
      setState(() {
        shiftTimings =
        Map<String, dynamic>.from(hospitalSnapshot['Shift Timings'] ?? {});
      });
    }
  }

  Future<void> _fetchGlobalHolidays() async {
    QuerySnapshot holidaySnapshot =
    await FirebaseFirestore.instance.collection('Holidays').get();

    setState(() {
      holidays = holidaySnapshot.docs.map((doc) {
        Timestamp timestamp = doc['Date'];
        return timestamp.toDate();
      }).toSet();
    });
  }

  Future<void> _fetchDoctorImage() async {
    DocumentSnapshot doctorSnapshot = await FirebaseFirestore.instance
        .collection('Users')
        .doc(widget.doctorId)
        .get();

    if (doctorSnapshot.exists) {
      setState(() {
        doctorImage = doctorSnapshot['User Pic'] ?? '';
      });
    }
  }

  bool _isDoctorActive(DateTime day) {
    if (day.isBefore(shiftStart) ||
        holidays.contains(DateTime(day.year, day.month, day.day))) {
      return false;
    }

    int daysSinceStart = day.difference(shiftStart).inDays;
    int cycleLength = activeDays + offDays;

    return (daysSinceStart % cycleLength) < activeDays;
  }

  String _getDoctorShift(DateTime day) {
    int daysSinceStart = day.difference(shiftStart).inDays;
    int activePeriod = daysSinceStart % (activeDays + offDays);

    if (activePeriod < shiftSwitch) {
      return "Morning";
    } else if (activePeriod < 2 * shiftSwitch) {
      return "Afternoon";
    } else {
      return "Night";
    }
  }

  void _showShiftDetails(BuildContext context, DateTime day) {
    String shift = _getDoctorShift(day);
    Map<String, dynamic>? timingMap = shiftTimings[shift];

    String timingText;
    DateTime? bookingDateTime;
    if (timingMap != null && timingMap is Map<String, dynamic>) {
      String start = timingMap['Start'] ?? "Unavailable";
      String end = timingMap['End'] ?? "Unavailable";

      // Combine selected date and shift time into a DateTime object
      if (start != "Unavailable") {
        // Parse the time using a DateFormat
        DateFormat dateFormat = DateFormat("hh:mm a");  // Format for "00:00 AM"
        try {
          // Convert the start time to DateTime object
          DateTime parsedStartTime = dateFormat.parse(start);
          bookingDateTime = DateTime(
            day.year,
            day.month,
            day.day,
            parsedStartTime.hour,
            parsedStartTime.minute,
          );
        } catch (e) {
          print("Error parsing time: $e");
        }
      }

      timingText = "Start: $start\nEnd: $end";
    } else {
      timingText = "Timings Unavailable";
    }

    showDialog(
      context: context,
      builder: (BuildContext context) {
        return AlertDialog(
          title: Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Text('Shift Details'),
              if (doctorImage.isNotEmpty)
                CircleAvatar(
                  backgroundImage: NetworkImage(doctorImage),
                  radius: 20,
                ),
            ],
          ),
          content: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                'Selected Date: ${DateFormat('yyyy-MM-dd').format(day)}',
                style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold, color: Colors.teal),
              ),
              SizedBox(height: 8),
              Text(
                'Working Period:',
                style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold, color: Colors.teal),
              ),
              Text(
                timingText,
                style: TextStyle(fontSize: 14, color: Colors.teal),
              ),
              SizedBox(height: 16),
              Text(
                'Guide:',
                style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold, color: Colors.teal),
              ),
              Text(
                'Book an appointment now for convenience!',
                style: TextStyle(fontSize: 14, color: Colors.black54),
              ),
            ],
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.of(context).pop(),
              child: Text('Close'),
            ),
            ElevatedButton(
              onPressed: () {
                if (bookingDateTime != null) {
                  // Pass the combined DateTime as a Timestamp
                  handleBookAppointment(
                    context,
                    doctorId: widget.doctorId,
                    hospitalId: widget.hospitalId,
                    selectedDate: bookingDateTime, // Use the combined timestamp
                  );
                }
              },
              child: Text('Book Appointment'),
              style: ElevatedButton.styleFrom(
                backgroundColor: Colors.green,
              ),
            ),
          ],
        );
      },
    );
  }

  @override
  Widget build(BuildContext context) {
    return Dialog(
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12.0)),
      child: Container(
        padding: EdgeInsets.all(16.0),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Text(
              'Choose a Date',
              style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
            ),
            SizedBox(height: 16),
            TableCalendar(
              firstDay: DateTime.now(),
              lastDay: DateTime.now().add(Duration(days: 30)),
              focusedDay: DateTime.now(),
              calendarStyle: CalendarStyle(
                todayDecoration: BoxDecoration(
                  color: Colors.orangeAccent,
                  shape: BoxShape.circle,
                ),
              ),
              calendarBuilders: CalendarBuilders(
                defaultBuilder: (context, day, focusedDay) {
                  if (holidays.contains(day)) {
                    return Center(
                      child: Container(
                        decoration: BoxDecoration(
                          color: Colors.red,
                          shape: BoxShape.circle,
                        ),
                        child: Padding(
                          padding: const EdgeInsets.all(6.0),
                          child: Text(
                            '${day.day}',
                            style: TextStyle(color: Colors.white),
                          ),
                        ),
                      ),
                    );
                  } else if (_isDoctorActive(day)) {
                    return GestureDetector(
                      onTap: () => _showShiftDetails(context, day),
                      child: Center(
                        child: Container(
                          decoration: BoxDecoration(
                            color: Colors.green,
                            shape: BoxShape.circle,
                          ),
                          child: Padding(
                            padding: const EdgeInsets.all(6.0),
                            child: Text(
                              '${day.day}',
                              style: TextStyle(color: Colors.white),
                            ),
                          ),
                        ),
                      ),
                    );
                  }
                  return Center(
                    child: Text('${day.day}', style: TextStyle(color: Colors.black87)),
                  );
                },
              ),
              headerStyle: HeaderStyle(formatButtonVisible: false),
            ),
          ],
        ),
      ),
    );
  }
}
