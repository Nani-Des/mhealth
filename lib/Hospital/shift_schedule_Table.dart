import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:intl/intl.dart';

class ShiftScheduleScreen extends StatefulWidget {
  final String hospitalId;
  final String departmentId;
  final List<Map<String, dynamic>> doctors;

  ShiftScheduleScreen({
    required this.hospitalId,
    required this.departmentId,
    required this.doctors,
  });

  @override
  _ShiftScheduleScreenState createState() => _ShiftScheduleScreenState();
}

class _ShiftScheduleScreenState extends State<ShiftScheduleScreen> {
  DateTime selectedMonth = DateTime.now();
  Map<String, Map<String, String>> doctorShifts = {};
  Set<DateTime> holidays = {};

  @override
  void initState() {
    super.initState();
    _fetchHolidays();
    _fetchDoctorSchedules();
  }

  // Fetch global holidays
  Future<void> _fetchHolidays() async {
    QuerySnapshot holidaySnapshot =
    await FirebaseFirestore.instance.collection('Holidays').get();
    setState(() {
      holidays = holidaySnapshot.docs.map((doc) {
        Timestamp timestamp = doc['Date'];
        return timestamp.toDate();
      }).toSet();
    });
  }

  // Fetch schedules for all doctors
  Future<void> _fetchDoctorSchedules() async {
    for (var doctor in widget.doctors) {
      String doctorId = doctor['userId'];
      DocumentSnapshot scheduleSnapshot = await FirebaseFirestore.instance
          .collection('Users')
          .doc(doctorId)
          .collection('Schedule')
          .doc(doctorId)
          .get();

      if (scheduleSnapshot.exists) {
        int activeDays = scheduleSnapshot['Active Days'] ?? 5;
        int offDays = scheduleSnapshot['Off Days'] ?? 2;
        int shiftSwitch = scheduleSnapshot['Shift Switch'] ?? 5;
        // New field: "Shift" determines the type of shift rotation.
        int shiftType = scheduleSnapshot['Shift'] ?? 1;
        DateTime shiftStart =
        (scheduleSnapshot['Shift Start'] as Timestamp).toDate();

        // Generate shifts for the current month with the new logic
        Map<String, String> schedule = _generateShiftSchedule(
            activeDays, offDays, shiftSwitch, shiftType, shiftStart);

        setState(() {
          doctorShifts[doctorId] = schedule;
        });
      }
    }
  }

  /// Generates the shift schedule for a doctor.
  ///
  /// [activeDays] and [offDays] determine the work/off cycle.
  /// [shiftSwitch] sets how many active days pass before switching the shift.
  /// [shiftType] (1, 2, or 3) decides which shift rotation to use.
  /// [shiftStart] is the date the schedule starts.
  Map<String, String> _generateShiftSchedule(
      int activeDays, int offDays, int shiftSwitch, int shiftType, DateTime shiftStart) {
    int daysInMonth =
        DateTime(selectedMonth.year, selectedMonth.month + 1, 0).day;
    Map<String, String> schedule = {};
    int cycleLength = activeDays + offDays;

    for (int i = 1; i <= daysInMonth; i++) {
      DateTime day = DateTime(selectedMonth.year, selectedMonth.month, i);

      // Holiday Check
      if (holidays.contains(day)) {
        schedule[i.toString()] = "HO";
        continue;
      }

      int daysSinceStart = day.difference(shiftStart).inDays;
      // If the day is before the shift start date, assign a default shift (WD)
      if (daysSinceStart < 0) {
        schedule[i.toString()] = "WD";
        continue;
      }

      int cycleIndex = daysSinceStart % cycleLength;

      // If the day falls on an off-day in the cycle
      if (cycleIndex >= activeDays) {
        schedule[i.toString()] = "OF"; // Off day
        continue;
      }

      // Active day: now decide the shift based on the shift type.
      if (shiftType == 1) {
        // Type 1: All active days remain "WD".
        schedule[i.toString()] = "WD";
      } else {
        // Calculate the active day index (ignoring off days)
        int fullCycles = daysSinceStart ~/ cycleLength;
        int activeDayIndex = fullCycles * activeDays + cycleIndex;

        if (shiftType == 2) {
          // Type 2: Alternate between Morning Shift (MS) and Afternoon Shift (AS)
          int block = activeDayIndex ~/ shiftSwitch;
          schedule[i.toString()] = (block % 2 == 0) ? "MS" : "AS";
        } else if (shiftType == 3) {
          // Type 3: Cycle between MS, AS, and Night Shift (NS)
          int block = activeDayIndex ~/ shiftSwitch;
          int modBlock = block % 3;
          if (modBlock == 0) {
            schedule[i.toString()] = "MS";
          } else if (modBlock == 1) {
            schedule[i.toString()] = "AS";
          } else {
            schedule[i.toString()] = "NS";
          }
        } else {
          // Fallback if an unknown shift type is provided.
          schedule[i.toString()] = "WD";
        }
      }
    }

    return schedule;
  }

  // Generate days for the selected month
  List<Map<String, String>> generateDays() {
    int daysInMonth =
        DateTime(selectedMonth.year, selectedMonth.month + 1, 0).day;
    List<Map<String, String>> days = [];
    for (int i = 1; i <= daysInMonth; i++) {
      String weekday = ['Sun', 'Mon', 'Tue', 'Wed', 'Thu', 'Fri', 'Sat']
      [DateTime(selectedMonth.year, selectedMonth.month, i).weekday % 7];
      days.add({'day': weekday, 'date': i.toString()});
    }
    return days;
  }

  @override
  Widget build(BuildContext context) {
    List<Map<String, String>> days = generateDays();

    return Scaffold(
      appBar: AppBar(
        title: Text(
            "Shift Schedule - ${DateFormat('MMMM yyyy').format(selectedMonth)}"),
        actions: [
          IconButton(
            icon: Icon(Icons.calendar_today),
            onPressed: () async {
              DateTime? newDate = await showDatePicker(
                context: context,
                initialDate: selectedMonth,
                firstDate: DateTime(2020),
                lastDate: DateTime(2030),
              );
              if (newDate != null) {
                setState(() => selectedMonth =
                    DateTime(newDate.year, newDate.month));
                _fetchDoctorSchedules();
              }
            },
          ),
        ],
      ),
      body: Column(
        children: [
          Expanded(
            child: widget.doctors.isEmpty
                ? Center(child: Text("No doctors available."))
                : SingleChildScrollView(
              scrollDirection: Axis.horizontal,
              child: DataTable(
                columnSpacing: 20,
                columns: [
                  DataColumn(label: Text('Doctor')),
                  ...days
                      .map((day) => DataColumn(
                    label: Column(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        Text(day['day']!),
                        Text(day['date']!),
                      ],
                    ),
                  ))
                      .toList(),
                ],
                rows: widget.doctors.map((doctor) {
                  String doctorId = doctor['userId'];
                  String doctorName = doctor['name'] ?? 'Unknown';
                  String? userPic = doctor['userPic'];

                  return DataRow(cells: [
                    DataCell(Row(
                      children: [
                        CircleAvatar(
                          backgroundImage: userPic != null &&
                              userPic.isNotEmpty
                              ? NetworkImage(userPic)
                              : AssetImage("assets/default_avatar.png")
                          as ImageProvider,
                          radius: 16,
                        ),
                        SizedBox(width: 8),
                        Text(doctorName),
                      ],
                    )),
                    ...days.map((day) {
                      String shift = doctorShifts[doctorId]?[day['date']] ??
                          '...'; // Default loading state
                      return DataCell(Text(shift));
                    }).toList(),
                  ]);
                }).toList(),
              ),
            ),
          ),
        ],
      ),
    );
  }
}
