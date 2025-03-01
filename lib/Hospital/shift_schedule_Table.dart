import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:intl/intl.dart';
import 'package:cached_network_image/cached_network_image.dart';

import 'doctor_profile.dart';

class ShiftScheduleScreen extends StatefulWidget {
  final String hospitalId;
  final String departmentId;
  final List<Map<String, dynamic>> doctors;

  const ShiftScheduleScreen({
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

  Future<void> _fetchHolidays() async {
    try {
      QuerySnapshot holidaySnapshot = await FirebaseFirestore.instance.collection('Holidays').get();
      setState(() {
        holidays = holidaySnapshot.docs.map((doc) => (doc['Date'] as Timestamp).toDate()).toSet();
      });
    } catch (e) {
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('Error fetching holidays: $e')));
    }
  }

  Future<void> _fetchDoctorSchedules() async {
    for (var doctor in widget.doctors) {
      String doctorId = doctor['userId'];
      try {
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
          int shiftType = scheduleSnapshot['Shift'] ?? 1;
          DateTime shiftStart = (scheduleSnapshot['Shift Start'] as Timestamp).toDate();

          Map<String, String> schedule = _generateShiftSchedule(
              activeDays, offDays, shiftSwitch, shiftType, shiftStart);

          setState(() {
            doctorShifts[doctorId] = schedule;
          });
        }
      } catch (e) {
        ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('Error fetching schedule: $e')));
      }
    }
  }

  Map<String, String> _generateShiftSchedule(
      int activeDays, int offDays, int shiftSwitch, int shiftType, DateTime shiftStart) {
    int daysInMonth = DateTime(selectedMonth.year, selectedMonth.month + 1, 0).day;
    Map<String, String> schedule = {};
    int cycleLength = activeDays + offDays;

    for (int i = 1; i <= daysInMonth; i++) {
      DateTime day = DateTime(selectedMonth.year, selectedMonth.month, i);
      if (holidays.contains(day)) {
        schedule[i.toString()] = "HO";
        continue;
      }

      int daysSinceStart = day.difference(shiftStart).inDays;
      if (daysSinceStart < 0) {
        schedule[i.toString()] = "WD";
        continue;
      }

      int cycleIndex = daysSinceStart % cycleLength;
      if (cycleIndex >= activeDays) {
        schedule[i.toString()] = "OF";
        continue;
      }

      if (shiftType == 1) {
        schedule[i.toString()] = "WD";
      } else {
        int fullCycles = daysSinceStart ~/ cycleLength;
        int activeDayIndex = fullCycles * activeDays + cycleIndex;

        if (shiftType == 2) {
          int block = activeDayIndex ~/ shiftSwitch;
          schedule[i.toString()] = (block % 2 == 0) ? "MS" : "AS";
        } else if (shiftType == 3) {
          int block = activeDayIndex ~/ shiftSwitch;
          int modBlock = block % 3;
          schedule[i.toString()] = modBlock == 0 ? "MS" : modBlock == 1 ? "AS" : "NS";
        } else {
          schedule[i.toString()] = "WD";
        }
      }
    }
    return schedule;
  }

  List<Map<String, String>> generateDays() {
    int daysInMonth = DateTime(selectedMonth.year, selectedMonth.month + 1, 0).day;
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
        elevation: 0,
        backgroundColor: Colors.blue,
        title: Row(
          children: [
            const Icon(Icons.calendar_today, size: 20),
            const SizedBox(width: 8),
            Text(
              DateFormat('MMMM yyyy').format(selectedMonth),
              style: const TextStyle(fontWeight: FontWeight.bold),
            ),
          ],
        ),
        actions: [
          IconButton(
            icon: const Icon(Icons.date_range),
            onPressed: _showMonthPicker,
          ),
        ],
        flexibleSpace: Container(
          decoration: BoxDecoration(
            gradient: LinearGradient(
              begin: Alignment.topLeft,
              end: Alignment.bottomRight,
              colors: [Colors.blue, Colors.blue.shade700],
            ),
          ),
        ),
      ),
      body: Container(
        decoration: BoxDecoration(
          gradient: LinearGradient(
            begin: Alignment.topCenter,
            end: Alignment.bottomCenter,
            colors: [Colors.blue.shade50, Colors.white],
          ),
        ),
        child: Column(
          children: [
            Container(
              padding: const EdgeInsets.all(8),
              child: Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Text(
                    'Legend',
                    style: Theme.of(context).textTheme.titleMedium?.copyWith(fontWeight: FontWeight.bold),
                  ),
                  Row(
                    children: [
                      _buildLegendItem('WD', 'Work Day', Colors.green),
                      _buildLegendItem('MS', 'Morning', Colors.blue),
                      _buildLegendItem('AS', 'Afternoon', Colors.orange),
                      _buildLegendItem('NS', 'Night', Colors.purple),
                      _buildLegendItem('OF', 'Off', Colors.grey),
                      _buildLegendItem('HO', 'Holiday', Colors.red),
                    ],
                  ),
                ],
              ),
            ),
            Expanded(
              child: widget.doctors.isEmpty
                  ? _buildEmptyState()
                  : SingleChildScrollView(
                scrollDirection: Axis.vertical,
                child: SingleChildScrollView(
                  scrollDirection: Axis.horizontal,
                  child: _buildScheduleTable(days),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildLegendItem(String code, String meaning, Color color) {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 4),
      child: Row(
        children: [
          Container(
            width: 12,
            height: 12,
            decoration: BoxDecoration(
              color: color,
              borderRadius: BorderRadius.circular(4),
            ),
          ),
          const SizedBox(width: 4),
          Text('$code', style: const TextStyle(fontSize: 12)),
        ],
      ),
    );
  }

  Widget _buildEmptyState() {
    return Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Icon(Icons.people_outline, size: 64, color: Colors.grey[400]),
          const SizedBox(height: 16),
          Text(
            'No doctors available',
            style: TextStyle(fontSize: 18, color: Colors.grey[600]),
          ),
        ],
      ),
    );
  }

  Widget _buildScheduleTable(List<Map<String, String>> days) {
    return DataTable(
      columnSpacing: 12,
      headingRowHeight: 70,
      dataRowHeight: 60,
      decoration: BoxDecoration(
        border: Border.all(color: Colors.grey[300]!),
        borderRadius: BorderRadius.circular(12),
      ),
      columns: [
        DataColumn(
          label: Container(
            padding: const EdgeInsets.symmetric(vertical: 8),
            child: const Text(
              'Doctor',
              style: TextStyle(fontWeight: FontWeight.bold, fontSize: 16),
            ),
          ),
        ),
        ...days.map((day) => DataColumn(
          label: Container(
            padding: const EdgeInsets.all(4),
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                Text(
                  day['day']!,
                  style: TextStyle(
                    fontWeight: FontWeight.bold,
                    color: day['day'] == 'Sun' ? Colors.red : Colors.black87,
                  ),
                ),
                const SizedBox(height: 4),
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                  decoration: BoxDecoration(
                    color: Colors.grey[200],
                    borderRadius: BorderRadius.circular(12),
                  ),
                  child: Text(day['date']!, style: const TextStyle(fontSize: 12)),
                ),
              ],
            ),
          ),
        )).toList(),
      ],
      rows: widget.doctors.map((doctor) {
        String doctorId = doctor['userId'];
        String doctorName = doctor['name'] ?? 'Unknown';
        String? userPic = doctor['userPic'];

        return DataRow(
          cells: [
            DataCell(
              GestureDetector(
                onTap: () => Navigator.push(
                  context,
                  MaterialPageRoute(
                    builder: (context) => DoctorProfileScreen(
                      userId: doctorId,
                      isReferral: false,
                    ),
                  ),
                ),
                child: Container(
                  padding: const EdgeInsets.symmetric(vertical: 8),
                  child: Row(
                    children: [
                      CircleAvatar(
                        radius: 20,
                        backgroundImage: userPic != null && userPic.isNotEmpty
                            ? CachedNetworkImageProvider(userPic)
                            : const AssetImage("assets/default_avatar.png") as ImageProvider,
                        backgroundColor: Colors.grey[200],
                      ),
                      const SizedBox(width: 12),
                      Expanded(
                        child: Text(
                          doctorName,
                          style: const TextStyle(fontSize: 14, fontWeight: FontWeight.w500),
                          overflow: TextOverflow.ellipsis,
                        ),
                      ),
                    ],
                  ),
                ),
              ),
            ),
            ...days.map((day) {
              String shift = doctorShifts[doctorId]?[day['date']] ?? '...';
              return DataCell(
                AnimatedContainer(
                  duration: const Duration(milliseconds: 300),
                  decoration: BoxDecoration(
                    color: _getShiftColor(shift),
                    borderRadius: BorderRadius.circular(8),
                  ),
                  alignment: Alignment.center,
                  child: Text(
                    shift,
                    style: const TextStyle(color: Colors.white, fontWeight: FontWeight.bold),
                  ),
                ),
              );
            }).toList(),
          ],
        );
      }).toList(),
    );
  }

  Color _getShiftColor(String shift) {
    switch (shift) {
      case 'WD': return Colors.green;
      case 'MS': return Colors.blue;
      case 'AS': return Colors.orange;
      case 'NS': return Colors.purple;
      case 'OF': return Colors.grey;
      case 'HO': return Colors.red;
      default: return Colors.grey[300]!;
    }
  }

  void _showMonthPicker() async {
    DateTime? newDate = await showDatePicker(
      context: context,
      initialDate: selectedMonth,
      firstDate: DateTime(2020),
      lastDate: DateTime(2030),
      builder: (context, child) {
        return Theme(
          data: Theme.of(context).copyWith(
            colorScheme: const ColorScheme.light(
              primary: Colors.blue,
              onPrimary: Colors.white,
              onSurface: Colors.black87,
            ),
            textButtonTheme: TextButtonThemeData(
              style: TextButton.styleFrom(foregroundColor: Colors.blue),
            ),
          ),
          child: child!,
        );
      },
    );
    if (newDate != null) {
      setState(() => selectedMonth = DateTime(newDate.year, newDate.month));
      _fetchDoctorSchedules();
    }
  }
}