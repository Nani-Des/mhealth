// import 'package:flutter/material.dart';
// import 'package:cloud_firestore/cloud_firestore.dart';
// import 'package:intl/intl.dart';
// import 'package:provider/provider.dart';
// import 'package:printing/printing.dart';
// import 'package:pdf/pdf.dart';
// import 'package:pdf/widgets.dart' as pw;
//
// // Enums and configurations from React code
// enum ShiftCode { WD, MS, AS, NS, OF, HO, LV, NA }
//
// enum ShiftType { WholeDay, MorningEvening, MorningAfternoonEvening }
//
// class ShiftTiming {
//   final Map<String, String> morning;
//   final Map<String, String> afternoon;
//   final Map<String, String> evening;
//
//   ShiftTiming({
//     required this.morning,
//     required this.afternoon,
//     required this.evening,
//   });
//
//   factory ShiftTiming.fromJson(Map<String, dynamic> json) => ShiftTiming(
//     morning: Map<String, String>.from(json['Morning'] ?? {'Start': '08:00', 'End': '14:00'}),
//     afternoon: Map<String, String>.from(json['Afternoon'] ?? {'Start': '14:00', 'End': '20:00'}),
//     evening: Map<String, String>.from(json['Evening'] ?? {'Start': '20:00', 'End': '08:00'}),
//   );
// }
//
// final shiftConfig = {
//   ShiftCode.WD: {
//     'color': Colors.teal,
//     'tooltip': (ShiftTiming? timings) => 'Whole Day',
//   },
//   ShiftCode.MS: {
//     'color': Colors.blue,
//     'tooltip': (ShiftTiming? timings) => timings != null
//         ? 'Morning Shift (${timings.morning['Start']} - ${timings.morning['End']})'
//         : 'Morning Shift',
//   },
//   ShiftCode.AS: {
//     'color': Colors.orange,
//     'tooltip': (ShiftTiming? timings) => timings != null
//         ? 'Afternoon Shift (${timings.afternoon['Start']} - ${timings.afternoon['End']})'
//         : 'Afternoon Shift',
//   },
//   ShiftCode.NS: {
//     'color': Colors.purple,
//     'tooltip': (ShiftTiming? timings) => timings != null
//         ? 'Night Shift (${timings.evening['Start']} - ${timings.evening['End']})'
//         : 'Night Shift',
//   },
//   ShiftCode.OF: {
//     'color': Colors.grey,
//     'tooltip': (ShiftTiming? timings) => 'Day Off',
//   },
//   ShiftCode.HO: {
//     'color': Colors.red,
//     'tooltip': (ShiftTiming? timings) => 'Holiday',
//   },
//   ShiftCode.LV: {
//     'color': Colors.yellow[700]!,
//     'tooltip': (ShiftTiming? timings) => 'Leave',
//   },
//   ShiftCode.NA: {
//     'color': Colors.grey[800]!,
//     'tooltip': (ShiftTiming? timings) => 'Not available (before shift start date)',
//   },
// };
//
// // Models
// class User {
//   final String id;
//   final String fname;
//   final String lname;
//   final String title;
//   final String? userPic;
//   final String departmentId;
//   final String hospitalId;
//
//   User({
//     required this.id,
//     required this.fname,
//     required this.lname,
//     required this.title,
//     this.userPic,
//     required this.departmentId,
//     required this.hospitalId,
//   });
//
//   factory User.fromJson(Map<String, dynamic> json) => User(
//     id: json['id'],
//     fname: json['Fname'] ?? '',
//     lname: json['Lname'] ?? '',
//     title: json['Title'] ?? '',
//     userPic: json['User Pic'],
//     departmentId: json['Department ID'] ?? '',
//     hospitalId: json['Hospital ID'] ?? '',
//   );
// }
//
// class Department {
//   final String id;
//   final String name;
//
//   Department({required this.id, required this.name});
//
//   factory Department.fromJson(Map<String, dynamic> json) => Department(
//     id: json['id'],
//     name: json['Department Name'] ?? '',
//   );
// }
//
// class Schedule {
//   final int shift;
//   final int activeDays;
//   final int offDays;
//   final int shiftSwitch;
//   final DateTime shiftStart;
//
//   Schedule({
//     required this.shift,
//     required this.activeDays,
//     required this.offDays,
//     required this.shiftSwitch,
//     required this.shiftStart,
//   });
//
//   factory Schedule.fromJson(Map<String, dynamic> json) => Schedule(
//     shift: json['Shift'] ?? ShiftType.WholeDay.index,
//     activeDays: json['Active Days'] ?? 5,
//     offDays: json['Off Days'] ?? 2,
//     shiftSwitch: json['Shift Switch'] ?? 5,
//     shiftStart: (json['Shift Start'] as Timestamp?)?.toDate() ?? DateTime.now(),
//   );
// }
//
// // State management with Provider
// class ScheduleProvider with ChangeNotifier {
//   List<User> _users = [];
//   List<Department> _departments = [];
//   String _hospitalId = 'default_hospital';
//   String _hospitalName = 'Default Hospital';
//   ShiftTiming? _shiftTimings;
//   DateTime _selectedMonth = DateTime.now();
//   List<DateTime> _holidays = [];
//   Map<String, Schedule?> _userSchedules = {};
//   Map<String, Map<String, String>> _doctorShifts = {};
//   List<String> _conflicts = [];
//   bool _isLoading = true;
//   Map<String, bool> _loadingUsers = {};
//
//   List<User> get users => _users;
//   List<Department> get departments => _departments;
//   String get hospitalName => _hospitalName;
//   ShiftTiming? get shiftTimings => _shiftTimings;
//   DateTime get selectedMonth => _selectedMonth;
//   List<DateTime> get holidays => _holidays;
//   Map<String, Schedule?> get userSchedules => _userSchedules;
//   Map<String, Map<String, String>> get doctorShifts => _doctorShifts;
//   List<String> get conflicts => _conflicts;
//   bool get isLoading => _isLoading;
//   Map<String, bool> get loadingUsers => _loadingUsers;
//
//   void setSelectedMonth(DateTime month) {
//     _selectedMonth = DateTime(month.year, month.month, 1);
//     notifyListeners();
//     fetchSchedules();
//   }
//
//   Future<void> initialize(String hospitalId, List<User> users, List<Department> departments) async {
//     _hospitalId = hospitalId;
//     _users = users;
//     _departments = departments;
//     await fetchHospitalData();
//     await fetchSchedules();
//   }
//
//   Future<void> fetchHospitalData() async {
//     try {
//       final hospitalDoc = await FirebaseFirestore.instance.collection('Hospitals').doc(_hospitalId).get();
//       if (hospitalDoc.exists) {
//         _hospitalName = hospitalDoc.data()?['Name'] ?? 'Default Hospital';
//         _shiftTimings = hospitalDoc.data()?['Shift Timings'] != null
//             ? ShiftTiming.fromJson(hospitalDoc.data()!['Shift Timings'])
//             : ShiftTiming(
//           morning: {'Start': '08:00', 'End': '14:00'},
//           afternoon: {'Start': '14:00', 'End': '20:00'},
//           evening: {'Start': '20:00', 'End': '08:00'},
//         );
//       } else {
//         _shiftTimings = ShiftTiming(
//           morning: {'Start': '08:00', 'End': '14:00'},
//           afternoon: {'Start': '14:00', 'End': '20:00'},
//           evening: {'Start': '20:00', 'End': '08:00'},
//         );
//       }
//     } catch (e) {
//       print('Error fetching hospital data: $e');
//     }
//     _isLoading = false;
//     notifyListeners();
//   }
//
//   Future<Map<String, String>> generateShiftSchedule({
//     required int activeDays,
//     required int offDays,
//     required int shiftSwitch,
//     required int shiftType,
//     required DateTime shiftStart,
//     required String userId,
//   }) async {
//     final daysInMonth = DateTime(_selectedMonth.year, _selectedMonth.month + 1, 0).day;
//     final schedule = <String, String>{};
//
//     // Fetch custom shifts
//     final customShiftsQuery = FirebaseFirestore.instance
//         .collection('Users')
//         .doc(userId)
//         .collection('CustomShifts')
//         .where('Date', isGreaterThanOrEqualTo: DateTime(_selectedMonth.year, _selectedMonth.month, 1))
//         .where('Date', isLessThan: DateTime(_selectedMonth.year, _selectedMonth.month + 1, 1));
//     final customShiftsSnapshot = await customShiftsQuery.get();
//     final customShiftMap = <String, String>{};
//     for (var doc in customShiftsSnapshot.docs) {
//       final date = (doc.data()['Date'] as Timestamp).toDate();
//       customShiftMap[date.day.toString()] = doc.data()['Shift'] ?? ShiftCode.WD.name;
//     }
//
//     // Fetch leaves
//     final leavesQuery = FirebaseFirestore.instance
//         .collection('Users')
//         .doc(userId)
//         .collection('Leaves')
//         .where('StartDate', isLessThanOrEqualTo: DateTime(_selectedMonth.year, _selectedMonth.month, daysInMonth))
//         .where('EndDate', isGreaterThanOrEqualTo: DateTime(_selectedMonth.year, _selectedMonth, 1));
//     final leavesSnapshot = await leavesQuery.get();
//     final leaveDays = <DateTime>[];
//     for (var doc in leavesSnapshot.docs) {
//       final start = (doc.data()['StartDate'] as Timestamp).toDate();
//       final end = (doc.data()['EndDate'] as Timestamp).toDate();
//       for (var day = start; day.isBefore(end.add(Duration(days: 1))); day = day.add(Duration(days: 1))) {
//         if (day.month == _selectedMonth.month && day.year == _selectedMonth.year) {
//           leaveDays.add(DateTime(day.year, day.month, day.day));
//         }
//       }
//     }
//
//     final cycleLength = activeDays + offDays;
//
//     for (var i = 1; i <= daysInMonth; i++) {
//       final day = DateTime(_selectedMonth.year, _selectedMonth.month, i);
//       final dayStr = i.toString();
//
//       if (day.isBefore(shiftStart)) {
//         schedule[dayStr] = ShiftCode.NA.name;
//         continue;
//       }
//
//       if (customShiftMap[dayStr] != null) {
//         schedule[dayStr] = customShiftMap[dayStr]!;
//         continue;
//       }
//
//       if (leaveDays.any((d) => d.day == i && d.month == _selectedMonth.month)) {
//         schedule[dayStr] = ShiftCode.LV.name;
//         continue;
//       }
//
//       final daysSinceStart = day.difference(shiftStart).inDays;
//       if (daysSinceStart < 0) {
//         schedule[dayStr] = ShiftCode.WD.name;
//         continue;
//       }
//
//       final cycleIndex = daysSinceStart % cycleLength;
//       if (cycleIndex >= activeDays) {
//         schedule[dayStr] = ShiftCode.OF.name;
//         continue;
//       }
//
//       final fullCycles = daysSinceStart ~/ cycleLength;
//       final activeDayIndex = fullCycles * activeDays + cycleIndex;
//
//       switch (shiftType) {
//         case 0: // WholeDay
//           schedule[dayStr] = ShiftCode.WD.name;
//           break;
//         case 1: // MorningEvening
//           final block2 = activeDayIndex ~/ shiftSwitch;
//           schedule[dayStr] = block2 % 2 == 0 ? ShiftCode.MS.name : ShiftCode.NS.name;
//           break;
//         case 2: // MorningAfternoonEvening
//           final block3 = activeDayIndex ~/ shiftSwitch;
//           final modBlock = block3 % 3;
//           schedule[dayStr] = modBlock == 0
//               ? ShiftCode.MS.name
//               : modBlock == 1
//               ? ShiftCode.AS.name
//               : ShiftCode.NS.name;
//           break;
//         default:
//           schedule[dayStr] = ShiftCode.WD.name;
//       }
//     }
//     return schedule;
//   }
//
//   Future<void> fetchSchedules() async {
//     final newDoctorShifts = <String, Map<String, String>>{};
//     final newLoadingUsers = <String, bool>{};
//     _userSchedules = {};
//
//     for (var user in _users) {
//       newLoadingUsers[user.id] = true;
//       notifyListeners();
//       try {
//         final scheduleSnapshot = await FirebaseFirestore.instance.collection('Users').doc(user.id).collection('Schedule').get();
//         Schedule? schedule;
//         if (scheduleSnapshot.docs.isNotEmpty) {
//           schedule = Schedule.fromJson(scheduleSnapshot.docs.first.data());
//           _userSchedules[user.id] = schedule;
//         } else {
//           schedule = Schedule(
//             shift: ShiftType.WholeDay.index,
//             activeDays: 5,
//             offDays: 2,
//             shiftSwitch: 5,
//             shiftStart: DateTime.now(),
//           );
//           await FirebaseFirestore.instance.collection('Users').doc(user.id).collection('Schedule').doc('default').set({
//             'Shift': schedule.shift,
//             'Active Days': schedule.activeDays,
//             'Off Days': schedule.offDays,
//             'Shift Switch': schedule.shiftSwitch,
//             'Shift Start': Timestamp.fromDate(schedule.shiftStart),
//           });
//           _userSchedules[user.id] = schedule;
//         }
//
//         final shifts = await generateShiftSchedule(
//           activeDays: schedule.activeDays,
//           offDays: schedule.offDays,
//           shiftSwitch: schedule.shiftSwitch,
//           shiftType: schedule.shift,
//           shiftStart: schedule.shiftStart,
//           userId: user.id,
//         );
//         newDoctorShifts[user.id] = shifts;
//       } catch (e) {
//         print('Error generating schedule for ${user.id}: $e');
//         newDoctorShifts[user.id] = {};
//       } finally {
//         newLoadingUsers[user.id] = false;
//       }
//     }
//
//     _doctorShifts = newDoctorShifts;
//     _loadingUsers = newLoadingUsers;
//     detectConflicts();
//     notifyListeners();
//   }
//
//   void detectConflicts() {
//     final daysInMonth = DateTime(_selectedMonth.year, _selectedMonth.month + 1, 0).day;
//     final conflictDays = <String>[];
//     for (var i = 1; i <= daysInMonth; i++) {
//       final dayStr = i.toString();
//       final activeDoctors = _users.fold(0, (count, user) {
//         final shift = _doctorShifts[user.id]?[dayStr] ?? '';
//         return (shift != ShiftCode.OF.name && shift != ShiftCode.HO.name && shift != ShiftCode.LV.name) ? count + 1 : count;
//       });
//       if (activeDoctors == 0) {
//         conflictDays.add(dayStr);
//       }
//     }
//     _conflicts = conflictDays;
//     notifyListeners();
//   }
// }
//
// class ShiftScheduleScreen extends StatefulWidget {
//   @override
//   _ShiftScheduleScreenState createState() => _ShiftScheduleScreenState();
// }
//
// class _ShiftScheduleScreenState extends State<ShiftScheduleScreen> {
//   final _searchController = TextEditingController();
//   String? _selectedDepartmentId;
//   int _currentPage = 1;
//   final int _itemsPerPage = 6;
//
//   @override
//   void dispose() {
//     _searchController.dispose();
//     super.dispose();
//   }
//
//   List<User> _filterUsers(ScheduleProvider provider) {
//     final searchTerm = _searchController.text.toLowerCase();
//     return provider.users.where((user) {
//       final fullName = '${user.fname} ${user.lname}'.toLowerCase();
//       final deptName = provider.departments
//           .firstWhere((d) => d.id == user.departmentId, orElse: () => Department(id: '', name: ''))
//           .name
//           .toLowerCase();
//       return fullName.contains(searchTerm) || deptName.contains(searchTerm);
//     }).where((user) => _selectedDepartmentId == null || user.departmentId == _selectedDepartmentId).toList();
//   }
//
//   List<Map<String, String>> _getDays(ScheduleProvider provider) {
//     final daysInMonth = DateTime(provider.selectedMonth.year, provider.selectedMonth.month + 1, 0).day;
//     final days = <Map<String, String>>[];
//     final formatter = DateFormat('E');
//     for (var i = 1; i <= daysInMonth; i++) {
//       final date = DateTime(provider.selectedMonth.year, provider.selectedMonth.month, i);
//       days.add({
//         'day': formatter.format(date).substring(0, 3),
//         'date': i.toString(),
//       });
//     }
//     return days;
//   }
//
//   Future<void> _printSchedule(ScheduleProvider provider, List<User> filteredUsers) async {
//     final pdf = pw.Document();
//     final days = _getDays(provider);
//     final font = await PdfGoogleFonts.openSansRegular();
//
//     pdf.addPage(
//       pw.MultiPage(
//         pageFormat: PdfPageFormat.a4,
//         margin: pw.EdgeInsets.all(20),
//         build: (pw.Context context) => [
//           pw.Header(
//             level: 0,
//             child: pw.Column(
//               crossAxisAlignment: pw.CrossAxisAlignment.center,
//               children: [
//                 pw.Text(provider.hospitalName, style: pw.TextStyle(font: font, fontSize: 16, fontWeight: pw.FontWeight.bold)),
//                 pw.Text(
//                   'Physician Shift Schedule - ${DateFormat('MMMM yyyy').format(provider.selectedMonth)}',
//                   style: pw.TextStyle(font: font, fontSize: 14),
//                 ),
//                 if (_selectedDepartmentId != null)
//                   pw.Text(
//                     'Department: ${provider.departments.firstWhere((d) => d.id == _selectedDepartmentId, orElse: () => Department(id: '', name: 'All Departments')).name}',
//                     style: pw.TextStyle(font: font, fontSize: 12),
//                   ),
//                 if (provider.conflicts.isNotEmpty)
//                   pw.Text(
//                     'Warning: No physicians available on days ${provider.conflicts.join(', ')}',
//                     style: pw.TextStyle(font: font, fontSize: 10, color: PdfColors.red),
//                   ),
//               ],
//             ),
//           ),
//           pw.SizedBox(height: 10),
//           pw.Text('Legend', style: pw.TextStyle(font: font, fontSize: 12, fontWeight: pw.FontWeight.bold)),
//           pw.Wrap(
//             spacing: 10,
//             runSpacing: 5,
//             children: shiftConfig.entries.map((entry) {
//               return pw.Row(
//                 children: [
//                   pw.Container(
//                     width: 12,
//                     height: 12,
//                     color: PdfColor.fromInt(entry.value['color']!.value),
//                     decoration: pw.BoxDecoration(border: pw.Border.all()),
//                   ),
//                   pw.SizedBox(width: 4),
//                   pw.Text(
//                     '${entry.key.name} - ${entry.value['tooltip']!.split('(')[0].trim()}',
//                     style: pw.TextStyle(font: font, fontSize: 8),
//                   ),
//                 ],
//               );
//             }).toList(),
//           ),
//           pw.SizedBox(height: 20),
//           pw.Table(
//             border: pw.TableBorder.all(),
//             columnWidths: {
//               0: pw.FixedColumnWidth(100),
//               for (var i = 1; i <= days.length; i++) i: pw.FixedColumnWidth(30),
//             },
//             children: [
//               pw.TableRow(
//                 children: [
//                   pw.Padding(
//                     padding: pw.EdgeInsets.all(4),
//                     child: pw.Text('Physician', style: pw.TextStyle(font: font, fontSize: 8, fontWeight: pw.FontWeight.bold)),
//                   ),
//                   ...days.map((day) => pw.Padding(
//                     padding: pw.EdgeInsets.all(4),
//                     child: pw.Column(
//                       children: [
//                         pw.Text(day['day']!, style: pw.TextStyle(font: font, fontSize: 8)),
//                         pw.Text(day['date']!, style: pw.TextStyle(font: font, fontSize: 8)),
//                       ],
//                     ),
//                   )),
//                 ],
//               ),
//               ...filteredUsers.map((user) => pw.TableRow(
//                 children: [
//                   pw.Padding(
//                     padding: pw.EdgeInsets.all(4),
//                     child: pw.Text(
//                       '${user.title} ${user.fname} ${user.lname}',
//                       style: pw.TextStyle(font: font, fontSize: 8),
//                     ),
//                   ),
//                   ...days.map((day) {
//                     final shift = provider.doctorShifts[user.id]?[day['date']!] ?? ShiftCode.NA.name;
//                     return pw.Container(
//                       color: PdfColor.fromInt(shiftConfig[ShiftCode.values.firstWhere((e) => e.name == shift)]?['color']!.value),
//                       padding: pw.EdgeInsets.all(4),
//                       child: pw.Text(
//                         shift,
//                         style: pw.TextStyle(font: font, fontSize: 8, color: PdfColors.white),
//                         textAlign: pw.TextAlign.center,
//                       ),
//                     );
//                   }),
//                 ],
//               )),
//             ],
//           ),
//         ],
//       ),
//     );
//
//     await Printing.layoutPdf(onLayout: (PdfPageFormat format) async => pdf.save());
//   }
//
//   @override
//   Widget build(BuildContext context) {
//     return ChangeNotifierProvider(
//       create: (context) => ScheduleProvider()
//         ..initialize(
//           'default_hospital', // Replace with actual hospital ID
//           [/* Pass your users list here */], // Replace with actual users
//           [/* Pass your departments list here */], // Replace with actual departments
//         ),
//       child: Consumer<ScheduleProvider>(
//         builder: (context, provider, child) {
//           final filteredUsers = _filterUsers(provider);
//           final paginatedUsers = filteredUsers.skip((_currentPage - 1) * _itemsPerPage).take(_itemsPerPage).toList();
//           final days = _getDays(provider);
//           final totalPages = (filteredUsers.length / _itemsPerPage).ceil();
//
//           return Scaffold(
//             appBar: AppBar(
//               title: Text('Shift Calendar'),
//               backgroundColor: Colors.teal,
//             ),
//             body: provider.isLoading
//                 ? Center(child: CircularProgressIndicator())
//                 : Padding(
//               padding: EdgeInsets.all(16),
//               child: Column(
//                 crossAxisAlignment: CrossAxisAlignment.start,
//                 children: [
//                   Row(
//                     mainAxisAlignment: MainAxisAlignment.spaceBetween,
//                     children: [
//                       Column(
//                         crossAxisAlignment: CrossAxisAlignment.start,
//                         children: [
//                           Text(
//                             provider.hospitalName,
//                             style: TextStyle(fontSize: 24, fontWeight: FontWeight.bold, color: Colors.teal[900]),
//                           ),
//                           Text(
//                             'View daily shift schedules for physicians',
//                             style: TextStyle(fontSize: 16, color: Colors.teal[900]),
//                           ),
//                         ],
//                       ),
//                       Row(
//                         children: [
//                           InkWell(
//                             onTap: () async {
//                               final picked = await showDatePicker(
//                                 context: context,
//                                 initialDate: provider.selectedMonth,
//                                 firstDate: DateTime(2020),
//                                 lastDate: DateTime(2030),
//                                 initialEntryMode: DatePickerEntryMode.calendarOnly,
//                                 builder: (context, child) => Theme(
//                                   data: ThemeData.light().copyWith(
//                                     primaryColor: Colors.teal,
//                                     colorScheme: ColorScheme.light(primary: Colors.teal),
//                                     buttonTheme: ButtonThemeData(textTheme: ButtonTextTheme.primary),
//                                   ),
//                                   child: child!,
//                                 ),
//                               );
//                               if (picked != null) {
//                                 provider.setSelectedMonth(picked);
//                               }
//                             },
//                             child: Container(
//                               padding: EdgeInsets.symmetric(horizontal: 12, vertical: 8),
//                               decoration: BoxDecoration(
//                                 color: Colors.teal[100],
//                                 border: Border.all(color: Colors.teal[200]!),
//                                 borderRadius: BorderRadius.circular(12),
//                               ),
//                               child: Row(
//                                 children: [
//                                   Icon(Icons.calendar_today, size: 20, color: Colors.teal[900]),
//                                   SizedBox(width: 8),
//                                   Text(
//                                     DateFormat('MMMM yyyy').format(provider.selectedMonth),
//                                     style: TextStyle(color: Colors.teal[900]),
//                                   ),
//                                 ],
//                               ),
//                             ),
//                           ),
//                           SizedBox(width: 16),
//                           ElevatedButton.icon(
//                             onPressed: () => _printSchedule(provider, filteredUsers),
//                             icon: Icon(Icons.print),
//                             label: Text('Print Schedule'),
//                             style: ElevatedButton.styleFrom(
//                               backgroundColor: Colors.teal[500],
//                               foregroundColor: Colors.grey[900],
//                               shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
//                             ),
//                           ),
//                         ],
//                       ),
//                     ],
//                   ),
//                   if (provider.conflicts.isNotEmpty)
//                     Container(
//                       margin: EdgeInsets.only(top: 16),
//                       padding: EdgeInsets.all(16),
//                       decoration: BoxDecoration(
//                         color: Colors.red[600],
//                         borderRadius: BorderRadius.circular(12),
//                       ),
//                       child: Text(
//                         'Warning: No physicians available on days ${provider.conflicts.join(', ')}',
//                         style: TextStyle(color: Colors.white),
//                       ),
//                     ),
//                   SizedBox(height: 16),
//                   Row(
//                     children: [
//                       Expanded(
//                         child: TextField(
//                           controller: _searchController,
//                           decoration: InputDecoration(
//                             hintText: 'Search by physician name or department...',
//                             border: OutlineInputBorder(borderRadius: BorderRadius.circular(12)),
//                             filled: true,
//                             fillColor: Colors.teal[100],
//                             hintStyle: TextStyle(color: Colors.teal[600]),
//                           ),
//                           onChanged: (value) {
//                             setState(() {
//                               _currentPage = 1;
//                             });
//                           },
//                         ),
//                       ),
//                       SizedBox(width: 16),
//                       DropdownButton<String?>(
//                         value: _selectedDepartmentId,
//                         hint: Text('All Departments'),
//                         items: [
//                           DropdownMenuItem<String?>(
//                             value: null,
//                             child: Text('All Departments'),
//                           ),
//                           ...provider.departments.map((dept) => DropdownMenuItem<String>(
//                             value: dept.id,
//                             child: Text(dept.name),
//                           )),
//                         ],
//                         onChanged: (value) {
//                           setState(() {
//                             _selectedDepartmentId = value;
//                             _currentPage = 1;
//                           });
//                         },
//                         style: TextStyle(color: Colors.teal[700]),
//                         dropdownColor: Colors.teal[100],
//                       ),
//                     ],
//                   ),
//                   SizedBox(height: 16),
//                   Text(
//                     'Legend',
//                     style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold, color: Colors.teal[800]),
//                   ),
//                   Wrap(
//                     spacing: 16,
//                     runSpacing: 8,
//                     children: shiftConfig.entries.map((entry) {
//                       return Tooltip(
//                         message: entry.value['tooltip']!(provider.shiftTimings),
//                         child: Row(
//                           mainAxisSize: MainAxisSize.min,
//                           children: [
//                             Container(
//                               width: 16,
//                               height: 16,
//                               decoration: BoxDecoration(
//                                 color: entry.value['color'] as Color,
//                                 border: Border.all(),
//                                 borderRadius: BorderRadius.circular(4),
//                               ),
//                             ),
//                             SizedBox(width: 8),
//                             Column(
//                               crossAxisAlignment: CrossAxisAlignment.start,
//                               children: [
//                                 Text(
//                                   entry.key.name,
//                                   style: TextStyle(fontSize: 12, fontWeight: FontWeight.bold, color: Colors.teal[900]),
//                                 ),
//                                 Text(
//                                   entry.value['tooltip']!(null).split('(')[0].trim(),
//                                   style: TextStyle(fontSize: 10, color: Colors.grey[600]),
//                                 ),
//                               ],
//                             ),
//                           ],
//                         ),
//                       );
//                     }).toList(),
//                   ),
//                   SizedBox(height: 16),
//                   if (filteredUsers.isEmpty)
//                     Center(
//                       child: Text(
//                         'No physicians found.',
//                         style: TextStyle(fontSize: 18, color: Colors.grey[600]),
//                       ),
//                     )
//                   else
//                     Expanded(
//                       child: SingleChildScrollView(
//                         scrollDirection: Axis.horizontal,
//                         child: DataTable(
//                           columnSpacing: 8,
//                           headingRowHeight: 60,
//                           dataRowHeight: 60,
//                           columns: [
//                             DataColumn(
//                               label: Text(
//                                 'Physician',
//                                 style: TextStyle(fontWeight: FontWeight.bold, color: Colors.white),
//                               ),
//                             ),
//                             ...days.map((day) => DataColumn(
//                               label: Column(
//                                 children: [
//                                   Text(
//                                     day['day']!,
//                                     style: TextStyle(
//                                       fontWeight: FontWeight.bold,
//                                       color: day['day'] == 'Sun' || provider.conflicts.contains(day['date'])
//                                           ? Colors.red[400]
//                                           : Colors.white,
//                                     ),
//                                   ),
//                                   Container(
//                                     padding: EdgeInsets.symmetric(horizontal: 8, vertical: 4),
//                                     decoration: BoxDecoration(
//                                       color: provider.conflicts.contains(day['date']) ? Colors.red[900] : Colors.teal[700],
//                                       borderRadius: BorderRadius.circular(16),
//                                     ),
//                                     child: Text(
//                                       day['date']!,
//                                       style: TextStyle(color: Colors.white, fontSize: 12),
//                                     ),
//                                   ),
//                                 ],
//                               ),
//                             )),
//                           ],
//                           rows: paginatedUsers.map((user) {
//                             return DataRow(
//                               cells: [
//                                 DataCell(
//                                   Row(
//                                     children: [
//                                       user.userPic != null
//                                           ? CircleAvatar(
//                                         backgroundImage: NetworkImage(user.userPic!),
//                                         radius: 20,
//                                       )
//                                           : CircleAvatar(
//                                         backgroundColor: Colors.teal[400],
//                                         child: Text(
//                                           user.fname.isNotEmpty ? user.fname[0] : 'P',
//                                           style: TextStyle(color: Colors.grey[800]),
//                                         ),
//                                         radius: 20,
//                                       ),
//                                       SizedBox(width: 8),
//                                       Column(
//                                         crossAxisAlignment: CrossAxisAlignment.start,
//                                         mainAxisAlignment: MainAxisAlignment.center,
//                                         children: [
//                                           Text(
//                                             '${user.title} ${user.fname} ${user.lname}',
//                                             style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold),
//                                           ),
//                                           Text(
//                                             '(Shift Type: ${provider.userSchedules[user.id]?.shift == ShiftType.WholeDay.index ? 'Whole Day' : provider.userSchedules[user.id]?.shift == ShiftType.MorningEvening.index ? 'Morning/Evening' : 'Morning/Afternoon/Evening'})',
//                                             style: TextStyle(fontSize: 10, color: Colors.grey[400]),
//                                           ),
//                                         ],
//                                       ),
//                                     ],
//                                   ),
//                                 ),
//                                 ...days.map((day) {
//                                   final shift = provider.doctorShifts[user.id]?[day['date']!] ?? ShiftCode.NA.name;
//                                   return DataCell(
//                                     Tooltip(
//                                       message: shiftConfig[ShiftCode.values.firstWhere((e) => e.name == shift)]?['tooltip']!(provider.shiftTimings) ?? shift,
//                                       child: Container(
//                                         color: shiftConfig[ShiftCode.values.firstWhere((e) => e.name == shift)]?['color'] as Color,
//                                         alignment: Alignment.center,
//                                         child: Text(
//                                           shift,
//                                           style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold, fontSize: 12),
//                                         ),
//                                       ),
//                                     ),
//                                   );
//                                 }),
//                               ],
//                             );
//                           }).toList(),
//                         ),
//                       ),
//                     ),
//                   if (filteredUsers.length > _itemsPerPage)
//                     Padding(
//                       padding: EdgeInsets.symmetric(vertical: 16),
//                       child: Row(
//                         mainAxisAlignment: MainAxisAlignment.spaceBetween,
//                         children: [
//                           Text(
//                             'Page $_currentPage of $totalPages',
//                             style: TextStyle(color: Colors.white),
//                           ),
//                           Row(
//                             children: [
//                               ElevatedButton(
//                                 onPressed: _currentPage > 1
//                                     ? () => setState(() => _currentPage--)
//                                     : null,
//                                 child: Text('Previous'),
//                                 style: ElevatedButton.styleFrom(
//                                   backgroundColor: Colors.teal[500],
//                                   foregroundColor: Colors.grey[900],
//                                   shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
//                                 ),
//                               ),
//                               SizedBox(width: 8),
//                               ...List.generate(totalPages, (index) => index + 1)
//                                   .asMap()
//                                   .entries
//                                   .where((entry) {
//                                 final page = entry.value;
//                                 final maxPagesToShow = 5;
//                                 final startPage = (_currentPage - (maxPagesToShow ~/ 2)).clamp(1, totalPages);
//                                 final endPage = (startPage + maxPagesToShow - 1).clamp(1, totalPages);
//                                 return page >= startPage && page <= endPage;
//                               })
//                                   .map((entry) => Padding(
//                                 padding: EdgeInsets.symmetric(horizontal: 4),
//                                 child: ElevatedButton(
//                                   onPressed: () => setState(() => _currentPage = entry.value),
//                                   child: Text('${entry.value}'),
//                                   style: ElevatedButton.styleFrom(
//                                     backgroundColor: _currentPage == entry.value ? Colors.teal[400] : Colors.grey[700],
//                                     foregroundColor: _currentPage == entry.value ? Colors.grey[900] : Colors.white,
//                                     shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
//                                   ),
//                                 ),
//                               )),
//                               SizedBox(width: 8),
//                               ElevatedButton(
//                                 onPressed: _currentPage < totalPages
//                                     ? () => setState(() => _currentPage++)
//                                     : null,
//                                 child: Text('Next'),
//                                 style: ElevatedButton.styleFrom(
//                                   backgroundColor: Colors.teal[500],
//                                   foregroundColor: Colors.grey[900],
//                                   shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
//                                 ),
//                               ),
//                             ],
//                           ),
//                         ],
//                       ),
//                     ),
//                 ],
//               ),
//             ),
//           );
//         },
//       ),
//     );
//   }
// }