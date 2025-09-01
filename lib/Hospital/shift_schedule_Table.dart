import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:intl/intl.dart';
import 'package:cached_network_image/cached_network_image.dart';

import '../Services/firebase_service.dart';
import 'Widgets/custom_nav_bar.dart';
import 'doctor_profile.dart';

// Enums and configurations
enum ShiftCode { WD, MS, AS, NS, OF, HO, LV, NA }

enum ShiftType { WholeDay, MorningEvening, MorningAfternoonEvening }

final shiftConfig = {
  ShiftCode.WD: {
    'color': Colors.teal,
    'meaning': 'Whole Day',
  },
  ShiftCode.MS: {
    'color': Colors.blue,
    'meaning': 'Morning Shift',
  },
  ShiftCode.AS: {
    'color': Colors.orange,
    'meaning': 'Afternoon Shift',
  },
  ShiftCode.NS: {
    'color': Colors.purple,
    'meaning': 'Night Shift',
  },
  ShiftCode.OF: {
    'color': Colors.grey,
    'meaning': 'Day Off',
  },
  ShiftCode.HO: {
    'color': Colors.red,
    'meaning': 'Holiday',
  },
  ShiftCode.LV: {
    'color': Colors.yellow[700]!,
    'meaning': 'Leave',
  },
  ShiftCode.NA: {
    'color': Colors.grey[800]!,
    'meaning': 'Not Available',
  },
};

class ShiftScheduleScreen extends StatefulWidget {
  final String hospitalId;
  final bool isReferral;
  final Function? selectHealthFacility;
  final List<Map<String, dynamic>> doctors;

  const ShiftScheduleScreen({
    required this.hospitalId,
    required this.doctors,
    required this.isReferral,
    this.selectHealthFacility,
  });

  @override
  _ShiftScheduleScreenState createState() => _ShiftScheduleScreenState();
}

class _ShiftScheduleScreenState extends State<ShiftScheduleScreen> {
  DateTime selectedMonth = DateTime.now();
  Map<String, Map<String, String>> doctorShifts = {};
  Set<DateTime> holidays = {};
  Map<String, String> _hospitalDetails = {};
  bool _isLoading = true;
  List<String> _conflicts = [];
  FirebaseService _firebaseService = FirebaseService();

  @override
  void initState() {
    super.initState();
    _loadHospitalData();
    _fetchHolidays();
    _fetchDoctorSchedules();
  }

  Future<void> _loadHospitalData() async {
    try {
      Map<String, dynamic> hospitalDetails =
      await _firebaseService.getHospitalDetails(widget.hospitalId);

      setState(() {
        _hospitalDetails = Map<String, String>.from(hospitalDetails);
        _isLoading = false;
      });
    } catch (error) {
      print('Error fetching hospital data: $error');
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Failed to load hospital data')),
      );
      setState(() {
        _isLoading = false;
        _hospitalDetails['hospitalName'] = 'Unknown Hospital';
      });
    }
  }

  Future<void> _fetchHolidays() async {
    try {
      QuerySnapshot holidaySnapshot =
      await FirebaseFirestore.instance.collection('Holidays').get();
      setState(() {
        holidays = holidaySnapshot.docs
            .map((doc) => (doc['Date'] as Timestamp).toDate())
            .toSet();
      });
    } catch (e) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Check your Network Connectivity!')),
      );
    }
  }

  Future<void> _fetchDoctorSchedules() async {
    setState(() {
      doctorShifts.clear();
      _conflicts.clear();
    });

    // Fetch schedules for all doctors
    for (var doctor in widget.doctors) {
      String doctorId = doctor['userId'];
      String doctorName = doctor['name'] ?? 'Unknown';
      try {
        // Fetch schedule
        QuerySnapshot scheduleSnapshot = await FirebaseFirestore.instance
            .collection('Users')
            .doc(doctorId)
            .collection('Schedule')
            .get();

        Map<String, dynamic>? scheduleData;
        if (scheduleSnapshot.docs.isEmpty) {
          // Set default schedule
          scheduleData = {
            'Shift': 1, // WholeDay (Firestore uses 1)
            'Active Days': 5,
            'Off Days': 2,
            'Shift Switch': 5,
            'Shift Start': Timestamp.fromDate(DateTime.now()),
          };
          await FirebaseFirestore.instance
              .collection('Users')
              .doc(doctorId)
              .collection('Schedule')
              .doc('default')
              .set(scheduleData);
        } else {
          scheduleData = scheduleSnapshot.docs.first.data() as Map<String, dynamic>;
        }

        // Handle Firestore Shift values (1=WholeDay, 2=MorningEvening, 3=MorningAfternoonEvening)
        int shiftType;
        dynamic shiftValue = scheduleData['Shift'];
        if (shiftValue is int) {
          shiftType = shiftValue;
        } else if (shiftValue is String) {
          shiftType = int.tryParse(shiftValue) ?? 1; // Default to WholeDay
        } else {
          shiftType = 1; // Default to WholeDay
        }
        // Validate shiftType (Firestore uses 1-3)
        if (shiftType < 1 || shiftType > 3) {
          shiftType = 1; // Default to WholeDay
        }

        // Log for debugging
        print('Doctor: $doctorName ($doctorId), Shift: $shiftType, '
            'Active Days: ${scheduleData['Active Days']}, '
            'Off Days: ${scheduleData['Off Days']}, '
            'Shift Switch: ${scheduleData['Shift Switch']}, '
            'Shift Start: ${(scheduleData['Shift Start'] as Timestamp?)?.toDate()}');

        int activeDays = (scheduleData['Active Days'] as num?)?.toInt() ?? 5;
        int offDays = (scheduleData['Off Days'] as num?)?.toInt() ?? 2;
        int shiftSwitch = (scheduleData['Shift Switch'] as num?)?.toInt() ?? 5;
        DateTime shiftStart = (scheduleData['Shift Start'] as Timestamp?)?.toDate() ?? DateTime.now();

        // Generate schedule
        Map<String, String> schedule = await _generateShiftSchedule(
          activeDays: activeDays,
          offDays: offDays,
          shiftSwitch: shiftSwitch,
          shiftType: shiftType,
          shiftStart: shiftStart,
          userId: doctorId,
        );

        setState(() {
          doctorShifts[doctorId] = schedule;
        });
      } catch (e) {
        print('Error fetching schedule for $doctorId ($doctorName): $e');
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Failed to load schedule for $doctorName')),
        );
        setState(() {
          doctorShifts[doctorId] = {};
        });
      }
    }

    // Detect conflicts
    _detectConflicts(widget.doctors);
  }

  Future<Map<String, String>> _generateShiftSchedule({
    required int activeDays,
    required int offDays,
    required int shiftSwitch,
    required int shiftType,
    required DateTime shiftStart,
    required String userId,
  }) async {
    int daysInMonth = DateTime(selectedMonth.year, selectedMonth.month + 1, 0).day;
    Map<String, String> schedule = {};

    // Fetch custom shifts
    QuerySnapshot customShiftsQuery = await FirebaseFirestore.instance
        .collection('Users')
        .doc(userId)
        .collection('CustomShifts')
        .where('Date',
        isGreaterThanOrEqualTo: DateTime(selectedMonth.year, selectedMonth.month, 1))
        .where('Date', isLessThan: DateTime(selectedMonth.year, selectedMonth.month + 1, 1))
        .get();
    Map<String, String> customShiftMap = {};
    customShiftsQuery.docs.forEach((doc) {
      DateTime date = (doc['Date'] as Timestamp).toDate();
      customShiftMap[date.day.toString()] = doc['Shift']?.toString() ?? ShiftCode.WD.name;
    });

    // Fetch leaves
    QuerySnapshot leavesQuery = await FirebaseFirestore.instance
        .collection('Users')
        .doc(userId)
        .collection('Leaves')
        .where('StartDate',
        isLessThanOrEqualTo: DateTime(selectedMonth.year, selectedMonth.month, daysInMonth))
        .where('EndDate',
        isGreaterThanOrEqualTo: DateTime(selectedMonth.year, selectedMonth.month, 1))
        .get();
    List<DateTime> leaveDays = [];
    leavesQuery.docs.forEach((doc) {
      DateTime start = (doc['StartDate'] as Timestamp).toDate();
      DateTime end = (doc['EndDate'] as Timestamp).toDate();
      for (DateTime day = start;
      day.isBefore(end.add(Duration(days: 1)));
      day = day.add(Duration(days: 1))) {
        if (day.month == selectedMonth.month && day.year == selectedMonth.year) {
          leaveDays.add(DateTime(day.year, day.month, day.day));
        }
      }
    });

    int cycleLength = activeDays + offDays;
    // Normalize shiftStart to midnight to avoid time component issues
    DateTime normalizedShiftStart = DateTime(shiftStart.year, shiftStart.month, shiftStart.day);
    for (int i = 1; i <= daysInMonth; i++) {
      DateTime day = DateTime(selectedMonth.year, selectedMonth.month, i);
      String dayStr = i.toString();

      // Priority 1: Holidays
      if (holidays.contains(DateTime(day.year, day.month, day.day))) {
        schedule[dayStr] = ShiftCode.HO.name;
        continue;
      }

      // Priority 2: Before shift start
      if (day.isBefore(normalizedShiftStart)) {
        schedule[dayStr] = ShiftCode.NA.name;
        continue;
      }

      // Priority 3: Custom shifts
      if (customShiftMap.containsKey(dayStr)) {
        schedule[dayStr] = customShiftMap[dayStr]!;
        continue;
      }

      // Priority 4: Leaves
      if (leaveDays.any((d) => d.day == i && d.month == selectedMonth.month)) {
        schedule[dayStr] = ShiftCode.LV.name;
        continue;
      }

      // Priority 5: Regular schedule
      // Normalize day to midnight for accurate day difference
      DateTime normalizedDay = DateTime(day.year, day.month, day.day);
      int daysSinceStart = normalizedDay.difference(normalizedShiftStart).inDays;
      if (daysSinceStart < 0) {
        schedule[dayStr] = ShiftCode.WD.name;
        continue;
      }

      int cycleIndex = daysSinceStart % cycleLength;
      if (cycleIndex >= activeDays) {
        schedule[dayStr] = ShiftCode.OF.name;
        continue;
      }

      int fullCycles = daysSinceStart ~/ cycleLength;
      int activeDayIndex = fullCycles * activeDays + cycleIndex;

      // Match Firestore Shift values (1=WholeDay, 2=MorningEvening, 3=MorningAfternoonEvening)
      if (shiftType == 1) { // WholeDay
        schedule[dayStr] = ShiftCode.WD.name;
      } else if (shiftType == 2) { // MorningEvening
        int block = activeDayIndex ~/ shiftSwitch;
        schedule[dayStr] = block % 2 == 0 ? ShiftCode.MS.name : ShiftCode.NS.name;
      } else if (shiftType == 3) { // MorningAfternoonEvening
        int block = activeDayIndex ~/ shiftSwitch;
        int modBlock = block % 3;
        schedule[dayStr] = modBlock == 0
            ? ShiftCode.MS.name
            : modBlock == 1
            ? ShiftCode.AS.name
            : ShiftCode.NS.name;
      } else {
        schedule[dayStr] = ShiftCode.WD.name; // Fallback
      }
    }

    return schedule;
  }

  void _detectConflicts(List<Map<String, dynamic>> doctors) {
    int daysInMonth = DateTime(selectedMonth.year, selectedMonth.month + 1, 0).day;
    List<String> conflictDays = [];
    for (int i = 1; i <= daysInMonth; i++) {
      String dayStr = i.toString();
      int activeDoctors = doctors.fold(0, (count, doctor) {
        String shift = doctorShifts[doctor['userId']]?[dayStr] ?? '';
        return (shift != ShiftCode.OF.name &&
            shift != ShiftCode.HO.name &&
            shift != ShiftCode.LV.name)
            ? count + 1
            : count;
      });
      if (activeDoctors == 0) {
        conflictDays.add(dayStr);
      }
    }
    setState(() {
      _conflicts = conflictDays;
    });
  }

  List<Map<String, String>> generateDays() {
    int daysInMonth = DateTime(selectedMonth.year, selectedMonth.month + 1, 0).day;
    List<Map<String, String>> days = [];
    for (int i = 1; i <= daysInMonth; i++) {
      String weekday = [
        'Sun',
        'Mon',
        'Tue',
        'Wed',
        'Thu',
        'Fri',
        'Sat'
      ][DateTime(selectedMonth.year, selectedMonth.month, i).weekday % 7];
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
        backgroundColor: Colors.teal,
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
              colors: [Colors.teal, Colors.teal.shade700],
            ),
          ),
        ),
      ),
      body: Container(
        decoration: BoxDecoration(
          gradient: LinearGradient(
            begin: Alignment.topCenter,
            end: Alignment.bottomCenter,
            colors: [Colors.teal.shade50, Colors.white],
          ),
        ),
        child: _isLoading
            ? Center(child: CircularProgressIndicator())
            : Column(
          children: [
            Container(
              padding: const EdgeInsets.all(8),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    _hospitalDetails['hospitalName'] ?? 'Unknown Hospital',
                    style: Theme.of(context)
                        .textTheme
                        .headlineSmall
                        ?.copyWith(
                      fontWeight: FontWeight.bold,
                      color: Colors.teal[900],
                    ),
                  ),
                  Text(
                    'View daily shift schedules for physicians',
                    style: TextStyle(fontSize: 16, color: Colors.teal[900]),
                  ),
                  const SizedBox(height: 8),
                  if (_conflicts.isNotEmpty)
                    Container(
                      margin: EdgeInsets.only(top: 8),
                      padding: EdgeInsets.all(8),
                      decoration: BoxDecoration(
                        color: Colors.red[600],
                        borderRadius: BorderRadius.circular(12),
                      ),
                      child: Text(
                        'Warning: No physicians available on days ${_conflicts.join(', ')}',
                        style: TextStyle(color: Colors.white),
                      ),
                    ),
                  const SizedBox(height: 8),
                  Text(
                    'Legend',
                    style: Theme.of(context)
                        .textTheme
                        .titleMedium
                        ?.copyWith(fontWeight: FontWeight.bold),
                  ),
                  const SizedBox(height: 8),
                  Wrap(
                    spacing: 8,
                    runSpacing: 4,
                    children: shiftConfig.entries
                        .map((entry) => _buildLegendItem(
                      entry.key,
                      entry.value['meaning'] as String,
                      entry.value['color'] as Color,
                    ))
                        .toList(),
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
                  child: _buildScheduleTable(days, widget.doctors),
                ),
              ),
            ),
          ],
        ),
      ),
      floatingActionButton: widget.isReferral
          ? FloatingActionButton(
        onPressed: _isLoading
            ? null
            : () {
          String selectedHospitalName =
              _hospitalDetails['hospitalName'] ?? 'Unknown Hospital';
          Navigator.pop(context, selectedHospitalName);
          Navigator.pop(context, selectedHospitalName);
          Navigator.pop(context, selectedHospitalName);
          Navigator.pop(context, selectedHospitalName);
          if (widget.selectHealthFacility != null) {
            Future.delayed(Duration(milliseconds: 300), () {
              widget.selectHealthFacility!(selectedHospitalName);
            });
          }
        },
        child: Icon(Icons.add),
        backgroundColor: _isLoading ? Colors.grey : Colors.teal,
      )
          : null,
      bottomNavigationBar:
      widget.isReferral ? null : CustomBottomNavBarHospital(hospitalId: widget.hospitalId),
    );
  }

  Widget _buildLegendItem(ShiftCode code, String meaning, Color color) {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Container(
            width: 16,
            height: 16,
            decoration: BoxDecoration(
              color: color,
              borderRadius: BorderRadius.circular(4),
              border: Border.all(color: Colors.grey.shade300),
            ),
          ),
          const SizedBox(width: 6),
          Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                code.name,
                style: const TextStyle(
                  fontSize: 10,
                  fontWeight: FontWeight.bold,
                ),
              ),
              Text(
                meaning,
                style: TextStyle(
                  fontSize: 10,
                  color: Colors.teal,
                ),
              ),
            ],
          ),
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

  Widget _buildScheduleTable(List<Map<String, String>> days, List<Map<String, dynamic>> doctors) {
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
                    color: day['day'] == 'Sun' || _conflicts.contains(day['date'])
                        ? Colors.red
                        : Colors.black87,
                  ),
                ),
                const SizedBox(height: 4),
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                  decoration: BoxDecoration(
                    color: _conflicts.contains(day['date']) ? Colors.red[900] : Colors.grey[200],
                    borderRadius: BorderRadius.circular(12),
                  ),
                  child: Text(
                    day['date']!,
                    style: TextStyle(
                      fontSize: 12,
                      color: _conflicts.contains(day['date']) ? Colors.white : Colors.black87,
                    ),
                  ),
                ),
              ],
            ),
          ),
        )),
      ],
      rows: doctors.map((doctor) {
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
              String shift = doctorShifts[doctorId]?[day['date']] ?? ShiftCode.NA.name;
              return DataCell(
                AnimatedContainer(
                  duration: const Duration(milliseconds: 300),
                  decoration: BoxDecoration(
                    color: shiftConfig[ShiftCode.values.firstWhere((e) => e.name == shift)]!['color'] as Color,
                    borderRadius: BorderRadius.circular(8),
                  ),
                  alignment: Alignment.center,
                  child: Text(
                    shift,
                    style: const TextStyle(color: Colors.white, fontWeight: FontWeight.bold),
                  ),
                ),
              );
            }),
          ],
        );
      }).toList(),
    );
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
              primary: Colors.teal,
              onPrimary: Colors.white,
              onSurface: Colors.black87,
            ),
            textButtonTheme: TextButtonThemeData(
              style: TextButton.styleFrom(foregroundColor: Colors.teal),
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

  @override
  void dispose() {
    super.dispose();
  }
}