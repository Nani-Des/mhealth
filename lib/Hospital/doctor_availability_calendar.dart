// doctor_availability_calendar.dart
import 'package:flutter/material.dart';
import 'package:table_calendar/table_calendar.dart';
import 'package:intl/intl.dart';

import '../Components/booking_helper.dart';

class DoctorAvailabilityCalendar extends StatelessWidget {
  const DoctorAvailabilityCalendar({Key? key}) : super(key: key);

  // Method to determine if the doctor is active on a given day (Monday to Friday)
  bool _isDoctorActive(DateTime day) {
    return day.weekday >= 1 && day.weekday <= 5; // Monday (1) to Friday (5)
  }

  // Method to show booking dialog when a working day is tapped
  void _showBookingDialog(BuildContext context, DateTime day) {
    String formattedDate = DateFormat('EEEE, MMMM d').format(day); // Format date as "Day, Month d"

    showDialog(
      context: context,
      builder: (BuildContext context) {
        return AlertDialog(
          title: Text('Book Appointment'),
          content: Text('Would you like to book on $formattedDate?'),
          actions: [
            TextButton(
              onPressed: () => Navigator.of(context).pop(),
              child: Text('Cancel'),
            ),
            ElevatedButton(
              onPressed: () {
                Navigator.of(context).pop();

                handleBookAppointment(context);
              },
              child: Text('Book Appointment'),
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

            // Calendar displaying all days with working days highlighted
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
                  // Highlight working days (Monday to Friday) with green if today, otherwise blue
                  if (_isDoctorActive(day)) {
                    bool isToday = DateTime(day.year, day.month, day.day) ==
                        DateTime(DateTime.now().year, DateTime.now().month, DateTime.now().day);

                    return GestureDetector(
                      onTap: () => _showBookingDialog(context, day),
                      child: Center(
                        child: Container(
                          decoration: BoxDecoration(
                            color: isToday ? Colors.green : Colors.blueAccent,
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
                  // For non-working days, display them without highlighting
                  return GestureDetector(
                    onTap: () {
                      ScaffoldMessenger.of(context).showSnackBar(
                        SnackBar(content: Text('No appointments available on weekends.')),
                      );
                    },
                    child: Center(
                      child: Text('${day.day}', style: TextStyle(color: Colors.black87)),
                    ),
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
