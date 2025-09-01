import 'dart:convert';

import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:connectivity_plus/connectivity_plus.dart';
import 'package:firebase_messaging/firebase_messaging.dart';
import 'package:cached_network_image/cached_network_image.dart';
import 'dart:async';
import 'Home/home_page.dart';
import 'booking_details.dart';

class BookingPage extends StatefulWidget {
  final String currentUserId;
  const BookingPage({required this.currentUserId, Key? key}) : super(key: key);

  @override
  _BookingPageState createState() => _BookingPageState();
}

class _BookingPageState extends State<BookingPage> with SingleTickerProviderStateMixin {
  late Stream<QuerySnapshot> _allBookingsStream;
  late Stream<DocumentSnapshot> _appointmentsStream;
  late AnimationController _animationController;
  late Animation<double> _progressAnimation;
  bool _isDoctor = false;
  bool _isOffline = false;
  List<Map<String, dynamic>> _cachedRequests = [];
  List<Map<String, dynamic>> _cachedAppointments = [];
  List<Map<String, dynamic>> _filteredRequests = [];
  List<Map<String, dynamic>> _filteredAppointments = [];
  int _selectedTabIndex = 0;

  // Enhanced filter state
  Set<String> _statusFilter = {'Pending', 'Active', 'Cancelled'};
  DateTime? _startDateFilter;
  DateTime? _endDateFilter;
  String _sortBy = 'date'; // 'date', 'status', 'reason'
  bool _sortAscending = true;
  String _searchQuery = '';

  final FirebaseMessaging _messaging = FirebaseMessaging.instance;
  final TextEditingController _searchController = TextEditingController();

  @override
  void initState() {
    super.initState();
    _allBookingsStream = FirebaseFirestore.instance.collection('Bookings').snapshots();
    _appointmentsStream = FirebaseFirestore.instance.collection('Bookings').doc(widget.currentUserId).snapshots();
    _animationController = AnimationController(
      vsync: this,
      duration: const Duration(seconds: 2),
    )..repeat();
    _progressAnimation = Tween<double>(begin: 0, end: 1).animate(_animationController);

    _searchController.addListener(() {
      setState(() {
        _searchQuery = _searchController.text;
        _updateFilteredData();
      });
    });

    Future.microtask(() async {
      await _checkUserRole();
      await _updateFcmToken();
      await _checkConnectivity();
      await _loadCachedData();
      await _checkPendingNotifications();
      await _checkNewAppointmentsOnLogin();
      await _checkUpcomingAppointments();
    });
  }

  Future<void> _updateFcmToken() async {
    try {
      String? token = await _messaging.getToken();
      if (token != null) {
        await FirebaseFirestore.instance
            .collection('Users')
            .doc(widget.currentUserId)
            .set({'fcmToken': token}, SetOptions(merge: true));
        if (kDebugMode) {
          print('FCM token updated for user ${widget.currentUserId}: $token');
        }
      } else {
        if (kDebugMode) {
          print('Failed to retrieve FCM token');
        }
      }
    } catch (e) {
      if (kDebugMode) {
        print('Error updating FCM token: $e');
      }
    }
  }

  Future<void> _checkUpcomingAppointments() async {
    if (_isOffline) return;
    try {
      final prefs = await SharedPreferences.getInstance();
      await prefs.remove('sent_reminders_${widget.currentUserId}');
      if (kDebugMode) {
        print('Cleared outdated reminders for user ${widget.currentUserId}');
      }
    } catch (e) {
      if (kDebugMode) {
        print('Error clearing reminders: $e');
      }
    }
  }

  Future<void> _checkPendingNotifications() async {
    final prefs = await SharedPreferences.getInstance();
    final notifications = prefs.getStringList('pending_notifications') ?? [];
    if (notifications.isNotEmpty) {
      if (kDebugMode) {
        print('Processing ${notifications.length} pending notifications');
      }
      for (var notification in notifications) {
        final data = jsonDecode(notification) as Map<String, dynamic>;
        _handleNotificationTap(data['data'] ?? {});
      }
      await prefs.setStringList('pending_notifications', []);
    }
  }

  Future<void> _checkNewAppointmentsOnLogin() async {
    if (_isOffline) return;
    for (int retry = 0; retry < 3; retry++) {
      try {
        final prefs = await SharedPreferences.getInstance();
        final processedAppointments = prefs.getStringList('processed_appointments_${widget.currentUserId}') ?? [];

        QuerySnapshot bookingsSnapshot;
        if (_isDoctor) {
          bookingsSnapshot = await FirebaseFirestore.instance.collection('Bookings').get();
        } else {
          bookingsSnapshot = await FirebaseFirestore.instance
              .collection('Bookings')
              .where(FieldPath.documentId, isEqualTo: widget.currentUserId)
              .get();
        }

        List<Map<String, dynamic>> newAppointments = [];
        for (var doc in bookingsSnapshot.docs) {
          var bookings = doc['Bookings'] as List<dynamic>? ?? [];
          for (var booking in bookings) {
            if (_isDoctor && booking['doctorId'] == widget.currentUserId && booking['status'] == 'Pending') {
              newAppointments.add({...booking, 'userId': doc.id});
            }
          }
        }

        for (var appointment in newAppointments) {
          final appointmentId = '${appointment['userId']}_${appointment['date'].seconds}';
          if (!processedAppointments.contains(appointmentId)) {
            processedAppointments.add(appointmentId);
          }
        }

        await prefs.setStringList('processed_appointments_${widget.currentUserId}', processedAppointments);
        break;
      } catch (e) {
        if (kDebugMode) {
          print('Error checking new appointments (retry $retry): $e');
        }
        if (retry < 2) await Future.delayed(const Duration(seconds: 2));
      }
    }
  }

  Future<void> _checkConnectivity() async {
    var connectivityResult = await Connectivity().checkConnectivity();
    setState(() {
      _isOffline = connectivityResult.contains(ConnectivityResult.none);
    });

    Connectivity().onConnectivityChanged.listen((List<ConnectivityResult> results) async {
      setState(() {
        _isOffline = results.contains(ConnectivityResult.none);
      });
      if (!_isOffline) {
        _showModernSnackBar(context, 'Back online, syncing data...');
        await _updateFcmToken();
        await _checkPendingNotifications();
        await _loadCachedData();
        await _checkNewAppointmentsOnLogin();
        await _checkUpcomingAppointments();
      }
    });
  }

  Future<void> _loadCachedData() async {
    final prefs = await SharedPreferences.getInstance();
    final cachedRequests = prefs.getString('cached_requests_${widget.currentUserId}');
    final cachedAppointments = prefs.getString('cached_appointments_${widget.currentUserId}');

    setState(() {
      if (cachedRequests != null) {
        final List<dynamic> decoded = jsonDecode(cachedRequests);
        _cachedRequests = decoded.map((item) {
          final map = item as Map<String, dynamic>;
          return {
            ...map,
            'date': map['date'] is String ? Timestamp.fromDate(DateTime.parse(map['date'])) : map['date'],
          };
        }).toList();
      }
      if (cachedAppointments != null) {
        final List<dynamic> decoded = jsonDecode(cachedAppointments);
        _cachedAppointments = decoded.map((item) {
          final map = item as Map<String, dynamic>;
          return {
            ...map,
            'date': map['date'] is String ? Timestamp.fromDate(DateTime.parse(map['date'])) : map['date'],
          };
        }).toList();
      }
      _updateFilteredData();
    });

    if (kDebugMode) {
      print('Loaded cached requests: ${_cachedRequests.length}');
      print('Loaded cached appointments: ${_cachedAppointments.length}');
      print('Filtered requests: ${_filteredRequests.length}');
      print('Filtered appointments: ${_filteredAppointments.length}');
    }
  }

  void _updateFilteredData() {
    _filteredRequests = _applyFilters(_cachedRequests, true);
    _filteredRequests.sort(_sortBookings);
    _filteredAppointments = _applyFilters(_cachedAppointments, false);
    _filteredAppointments.sort(_sortBookings);
    if (kDebugMode) {
      print('Updated filtered data: requests=${_filteredRequests.length}, appointments=${_filteredAppointments.length}');
    }
  }

  Future<void> _cacheData(String key, List<Map<String, dynamic>> data) async {
    final prefs = await SharedPreferences.getInstance();
    final serializableData = data.map((item) {
      return {
        ...item,
        'date': item['date'] is Timestamp ? item['date'].toDate().toIso8601String() : item['date'],
      };
    }).toList();
    await prefs.setString(key, jsonEncode(serializableData));
  }

  Future<void> _checkUserRole() async {
    try {
      DocumentSnapshot userDoc = await FirebaseFirestore.instance.collection('Users').doc(widget.currentUserId).get();
      if (userDoc.exists) {
        setState(() {
          _isDoctor = userDoc['Role'] == true;
        });
        if (kDebugMode) {
          print('User ${widget.currentUserId} role: ${_isDoctor ? 'Doctor' : 'Patient'}');
        }
      } else {
        _showModernSnackBar(context, 'User not found', isError: true);
      }
    } catch (e) {
      if (kDebugMode) {
        print('Error checking user role: $e');
      }
      _showModernSnackBar(context, 'Failed to load user role', isError: true);
    }
  }

  @override
  void dispose() {
    _animationController.dispose();
    _searchController.dispose();
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
                valueColor: const AlwaysStoppedAnimation<Color>(Colors.teal),
              ),
            ),
            Container(
              width: 60,
              height: 60,
              decoration: BoxDecoration(
                shape: BoxShape.circle,
                gradient: LinearGradient(
                  colors: [Colors.teal[100]!, Colors.teal[300]!],
                  begin: Alignment.topLeft,
                  end: Alignment.bottomRight,
                ),
                boxShadow: [
                  BoxShadow(
                    color: Colors.teal.withOpacity(0.3),
                    blurRadius: 10,
                    offset: const Offset(0, 4),
                  ),
                ],
              ),
              child: Center(
                child: Text(
                  '${(_progressAnimation.value * 100).toInt()}%',
                  style: const TextStyle(
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
      length: _isDoctor ? 2 : 1,
      initialIndex: _selectedTabIndex,
      child: Scaffold(
        appBar: AppBar(
          title: const Text(
            'Bookings',
            style: TextStyle(fontWeight: FontWeight.bold, color: Colors.white),
          ),
          backgroundColor: Colors.teal,
          elevation: 0,
          leading: IconButton(
            icon: const Icon(Icons.arrow_back_ios_new, color: Colors.white),
            onPressed: () {
              Navigator.pushAndRemoveUntil(
                context,
                MaterialPageRoute(builder: (context) => HomePage()),
                    (route) => false,
              );
            },
          ),
          actions: [
            IconButton(
              icon: const Icon(Icons.filter_list, color: Colors.white),
              onPressed: _showFilterDialog,
            ),
          ],
          bottom: TabBar(
            onTap: (index) => setState(() => _selectedTabIndex = index),
            indicatorColor: Colors.white,
            labelColor: Colors.white,
            unselectedLabelColor: Colors.white70,
            tabs: [
              if (_isDoctor) const Tab(text: 'Requests'),
              const Tab(text: 'Appointments'),
            ],
          ),
        ),
        body: Column(
          children: [
            // Search Bar
            Padding(
              padding: const EdgeInsets.all(16),
              child: TextField(
                controller: _searchController,
                decoration: InputDecoration(
                  hintText: 'Search bookings...',
                  prefixIcon: const Icon(Icons.search, color: Colors.teal),
                  suffixIcon: _searchQuery.isNotEmpty
                      ? IconButton(
                    icon: const Icon(Icons.clear, color: Colors.grey),
                    onPressed: () {
                      _searchController.clear();
                    },
                  )
                      : null,
                  border: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(12),
                    borderSide: const BorderSide(color: Colors.teal),
                  ),
                  focusedBorder: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(12),
                    borderSide: const BorderSide(color: Colors.teal, width: 2),
                  ),
                  contentPadding: const EdgeInsets.symmetric(vertical: 12),
                ),
              ),
            ),
            // Active Filters Indicator
            if (_statusFilter.length < 3 || _startDateFilter != null || _endDateFilter != null || _sortBy != 'date')
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
                color: Colors.teal.withOpacity(0.1),
                child: Row(
                  children: [
                    const Icon(Icons.filter_alt, size: 16, color: Colors.teal),
                    const SizedBox(width: 8),
                    Expanded(
                      child: SingleChildScrollView(
                        scrollDirection: Axis.horizontal,
                        child: Row(
                          children: [
                            if (_statusFilter.length < 3)
                              _buildFilterChip(
                                'Status: ${_statusFilter.join(', ')}',
                                onClear: () {
                                  setState(() {
                                    _statusFilter = {'Pending', 'Active', 'Cancelled'};
                                  });
                                  _updateFilteredData();
                                },
                              ),
                            if (_startDateFilter != null)
                              _buildFilterChip(
                                'From: ${DateFormat('MMM d').format(_startDateFilter!)}',
                                onClear: () {
                                  setState(() {
                                    _startDateFilter = null;
                                  });
                                  _updateFilteredData();
                                },
                              ),
                            if (_endDateFilter != null)
                              _buildFilterChip(
                                'To: ${DateFormat('MMM d').format(_endDateFilter!)}',
                                onClear: () {
                                  setState(() {
                                    _endDateFilter = null;
                                  });
                                  _updateFilteredData();
                                },
                              ),
                            _buildFilterChip(
                              'Sort: ${_sortBy.capitalize()} ${_sortAscending ? '↑' : '↓'}',
                              onClear: () {
                                setState(() {
                                  _sortBy = 'date';
                                  _sortAscending = true;
                                });
                                _updateFilteredData();
                              },
                            ),
                          ],
                        ),
                      ),
                    ),
                  ],
                ),
              ),
            Expanded(
              child: Container(
                color: Colors.grey[100],
                child: TabBarView(
                  children: [
                    if (_isDoctor) _buildRequests(),
                    _buildAppointments(),
                  ],
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildFilterChip(String label, {required VoidCallback onClear}) {
    return Container(
      margin: const EdgeInsets.only(right: 8),
      child: Chip(
        label: Text(label, style: const TextStyle(fontSize: 12)),
        backgroundColor: Colors.teal.withOpacity(0.2),
        deleteIcon: const Icon(Icons.close, size: 14),
        onDeleted: onClear,
      ),
    );
  }

  void _showFilterDialog() {
    final tempStatusFilter = _statusFilter.toSet();
    DateTime? tempStartDate = _startDateFilter;
    DateTime? tempEndDate = _endDateFilter;
    String tempSortBy = _sortBy;
    bool tempSortAscending = _sortAscending;

    showDialog(
      context: context,
      builder: (context) {
        return StatefulBuilder(
          builder: (context, setState) {
            return Dialog(
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
              child: SingleChildScrollView(
                padding: const EdgeInsets.all(16),
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      'Filter & Sort Bookings',
                      style: Theme.of(context).textTheme.titleLarge?.copyWith(
                        color: Colors.teal[800],
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                    const SizedBox(height: 16),

                    // Status Filter Section
                    Text(
                      'Filter by Status',
                      style: Theme.of(context).textTheme.titleMedium?.copyWith(color: Colors.grey[700]),
                    ),
                    Wrap(
                      spacing: 8,
                      children: ['Pending', 'Active', 'Cancelled'].map((status) {
                        return FilterChip(
                          label: Text(status),
                          selected: tempStatusFilter.contains(status),
                          onSelected: (selected) {
                            setState(() {
                              if (selected) {
                                tempStatusFilter.add(status);
                              } else {
                                tempStatusFilter.remove(status);
                              }
                            });
                          },
                          selectedColor: Colors.teal.withOpacity(0.2),
                          checkmarkColor: Colors.teal,
                          labelStyle: TextStyle(
                            color: tempStatusFilter.contains(status) ? Colors.teal : Colors.grey[700],
                          ),
                        );
                      }).toList(),
                    ),
                    const SizedBox(height: 16),

                    // Date Range Filter Section
                    Text(
                      'Filter by Date Range',
                      style: Theme.of(context).textTheme.titleMedium?.copyWith(color: Colors.grey[700]),
                    ),
                    const SizedBox(height: 8),
                    Row(
                      children: [
                        Expanded(
                          child: OutlinedButton(
                            onPressed: () async {
                              final picked = await showDatePicker(
                                context: context,
                                initialDate: tempStartDate ?? DateTime.now(),
                                firstDate: DateTime(2020),
                                lastDate: DateTime(2101),
                                builder: (context, child) => Theme(
                                  data: ThemeData.light().copyWith(
                                    colorScheme: const ColorScheme.light(primary: Colors.teal),
                                  ),
                                  child: child!,
                                ),
                              );
                              if (picked != null) {
                                setState(() => tempStartDate = picked);
                              }
                            },
                            style: OutlinedButton.styleFrom(
                              side: BorderSide(color: Colors.teal),
                              shape: RoundedRectangleBorder(
                                borderRadius: BorderRadius.circular(8),
                              ),
                            ),
                            child: Text(
                              tempStartDate != null
                                  ? DateFormat('MMM d, yyyy').format(tempStartDate!)
                                  : 'Start Date',
                              style: TextStyle(color: Colors.teal),
                            ),
                          ),
                        ),
                        const SizedBox(width: 8),
                        Expanded(
                          child: OutlinedButton(
                            onPressed: () async {
                              final picked = await showDatePicker(
                                context: context,
                                initialDate: tempEndDate ?? DateTime.now(),
                                firstDate: tempStartDate ?? DateTime(2020),
                                lastDate: DateTime(2101),
                                builder: (context, child) => Theme(
                                  data: ThemeData.light().copyWith(
                                    colorScheme: const ColorScheme.light(primary: Colors.teal),
                                  ),
                                  child: child!,
                                ),
                              );
                              if (picked != null) {
                                setState(() => tempEndDate = picked);
                              }
                            },
                            style: OutlinedButton.styleFrom(
                              side: BorderSide(color: Colors.teal),
                              shape: RoundedRectangleBorder(
                                borderRadius: BorderRadius.circular(8),
                              ),
                            ),
                            child: Text(
                              tempEndDate != null
                                  ? DateFormat('MMM d, yyyy').format(tempEndDate!)
                                  : 'End Date',
                              style: TextStyle(color: Colors.teal),
                            ),
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 8),
                    if (tempStartDate != null || tempEndDate != null)
                      TextButton(
                        onPressed: () {
                          setState(() {
                            tempStartDate = null;
                            tempEndDate = null;
                          });
                        },
                        child: const Text('Clear date range', style: TextStyle(color: Colors.red)),
                      ),
                    const SizedBox(height: 16),

                    // Sort Section
                    Text(
                      'Sort By',
                      style: Theme.of(context).textTheme.titleMedium?.copyWith(color: Colors.grey[700]),
                    ),
                    const SizedBox(height: 8),
                    Wrap(
                      spacing: 8,
                      children: [
                        ChoiceChip(
                          label: const Text('Date'),
                          selected: tempSortBy == 'date',
                          onSelected: (selected) {
                            setState(() {
                              tempSortBy = 'date';
                            });
                          },
                          selectedColor: Colors.teal,
                          labelStyle: TextStyle(
                            color: tempSortBy == 'date' ? Colors.white : Colors.grey[700],
                          ),
                        ),
                        ChoiceChip(
                          label: const Text('Status'),
                          selected: tempSortBy == 'status',
                          onSelected: (selected) {
                            setState(() {
                              tempSortBy = 'status';
                            });
                          },
                          selectedColor: Colors.teal,
                          labelStyle: TextStyle(
                            color: tempSortBy == 'status' ? Colors.white : Colors.grey[700],
                          ),
                        ),
                        ChoiceChip(
                          label: const Text('Reason'),
                          selected: tempSortBy == 'reason',
                          onSelected: (selected) {
                            setState(() {
                              tempSortBy = 'reason';
                            });
                          },
                          selectedColor: Colors.teal,
                          labelStyle: TextStyle(
                            color: tempSortBy == 'reason' ? Colors.white : Colors.grey[700],
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 8),
                    Row(
                      children: [
                        Radio<bool>(
                          value: true,
                          groupValue: tempSortAscending,
                          onChanged: (value) {
                            setState(() {
                              tempSortAscending = value ?? true;
                            });
                          },
                          activeColor: Colors.teal,
                        ),
                        const Text('Ascending'),
                        const SizedBox(width: 16),
                        Radio<bool>(
                          value: false,
                          groupValue: tempSortAscending,
                          onChanged: (value) {
                            setState(() {
                              tempSortAscending = value ?? false;
                            });
                          },
                          activeColor: Colors.teal,
                        ),
                        const Text('Descending'),
                      ],
                    ),
                    const SizedBox(height: 20),

                    // Action Buttons
                    Row(
                      mainAxisAlignment: MainAxisAlignment.end,
                      children: [
                        TextButton(
                          onPressed: () {
                            setState(() {
                              _statusFilter = {'Pending', 'Active', 'Cancelled'};
                              _startDateFilter = null;
                              _endDateFilter = null;
                              _sortBy = 'date';
                              _sortAscending = true;
                              _searchQuery = '';
                              _searchController.clear();
                            });
                            _updateFilteredData();
                            Navigator.pop(context);
                            _showModernSnackBar(context, 'Filters reset');
                          },
                          child: const Text('Reset All', style: TextStyle(color: Colors.red)),
                        ),
                        const SizedBox(width: 8),
                        ElevatedButton(
                          onPressed: () {
                            setState(() {
                              _statusFilter = tempStatusFilter;
                              _startDateFilter = tempStartDate;
                              _endDateFilter = tempEndDate;
                              _sortBy = tempSortBy;
                              _sortAscending = tempSortAscending;
                            });
                            _updateFilteredData();
                            Navigator.pop(context);
                            _showModernSnackBar(context, 'Filters applied');
                          },
                          style: ElevatedButton.styleFrom(
                            backgroundColor: Colors.teal,
                            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                          ),
                          child: const Text('Apply', style: TextStyle(color: Colors.white)),
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

  List<Map<String, dynamic>> _applyFilters(List<Map<String, dynamic>> bookings, bool isRequests) {
    return bookings.where((booking) {
      // Status filter
      if (!_statusFilter.contains(booking['status'])) {
        return false;
      }

      // Date range filter
      if (_startDateFilter != null || _endDateFilter != null) {
        final bookingDate = booking['date'] is Timestamp
            ? booking['date'].toDate()
            : DateTime.parse(booking['date']);

        if (_startDateFilter != null && bookingDate.isBefore(_startDateFilter!)) {
          return false;
        }
        if (_endDateFilter != null && bookingDate.isAfter(_endDateFilter!.add(const Duration(days: 1)))) {
          return false;
        }
      }

      // Search query filter
      if (_searchQuery.isNotEmpty) {
        final reason = (booking['reason'] ?? '').toString().toLowerCase();
        final status = (booking['status'] ?? '').toString().toLowerCase();
        final date = booking['date'] is Timestamp
            ? DateFormat('MMM dd, yyyy HH:mm').format(booking['date'].toDate()).toLowerCase()
            : DateFormat('MMM dd, yyyy HH:mm').format(DateTime.parse(booking['date'])).toLowerCase();

        if (!reason.contains(_searchQuery.toLowerCase()) &&
            !status.contains(_searchQuery.toLowerCase()) &&
            !date.contains(_searchQuery.toLowerCase())) {
          return false;
        }
      }

      return true;
    }).toList();
  }

  int _sortBookings(Map<String, dynamic> a, Map<String, dynamic> b) {
    // First sort by status priority if that's the selected sort
    if (_sortBy == 'status') {
      const statusPriority = {'Pending': 1, 'Active': 2, 'Cancelled': 3};
      int statusA = statusPriority[a['status']] ?? 4;
      int statusB = statusPriority[b['status']] ?? 4;

      if (statusA != statusB) {
        return _sortAscending ? statusA.compareTo(statusB) : statusB.compareTo(statusA);
      }
    }

    // Then sort by the selected field
    dynamic valueA, valueB;
    switch (_sortBy) {
      case 'date':
        valueA = a['date'] is Timestamp ? a['date'].toDate() : DateTime.parse(a['date']);
        valueB = b['date'] is Timestamp ? b['date'].toDate() : DateTime.parse(b['date']);
        break;
      case 'reason':
        valueA = (a['reason'] ?? '').toString().toLowerCase();
        valueB = (b['reason'] ?? '').toString().toLowerCase();
        break;
      case 'status':
        valueA = (a['status'] ?? '').toString().toLowerCase();
        valueB = (b['status'] ?? '').toString().toLowerCase();
        break;
      default:
        valueA = a['date'] is Timestamp ? a['date'].toDate() : DateTime.parse(a['date']);
        valueB = b['date'] is Timestamp ? b['date'].toDate() : DateTime.parse(b['date']);
    }

    // Handle date-specific sorting (future dates first)
    if (_sortBy == 'date') {
      bool isFutureA = valueA.isAfter(DateTime.now());
      bool isFutureB = valueB.isAfter(DateTime.now());

      if (isFutureA != isFutureB) {
        return isFutureA ? -1 : 1;
      }
    }

    // Default comparison
    int comparison;
    if (valueA is DateTime && valueB is DateTime) {
      comparison = valueA.compareTo(valueB);
    } else {
      comparison = valueA.toString().compareTo(valueB.toString());
    }

    return _sortAscending ? comparison : -comparison;
  }

  Widget _buildRequests() {
    if (_isOffline) {
      if (kDebugMode) {
        print('Offline: Using filtered requests: ${_filteredRequests.length}');
      }
      return _buildBookingList(_filteredRequests, true);
    }

    return StreamBuilder<QuerySnapshot>(
      stream: _allBookingsStream,
      builder: (context, AsyncSnapshot<QuerySnapshot> snapshot) {
        if (snapshot.connectionState == ConnectionState.waiting) {
          return _buildLoadingState('Requests');
        }
        if (snapshot.hasError) {
          if (kDebugMode) {
            print('Error loading requests: ${snapshot.error}');
          }
          return _buildEmptyState('Error loading requests: ${snapshot.error}');
        }
        if (!snapshot.hasData || snapshot.data!.docs.isEmpty) {
          if (kDebugMode) {
            print('No booking requests found for doctorId: ${widget.currentUserId}');
          }
          return _buildEmptyState('No booking requests found');
        }

        List<Map<String, dynamic>> requests = [];
        for (var doc in snapshot.data!.docs) {
          var bookings = doc['Bookings'] as List<dynamic>? ?? [];
          for (var booking in bookings) {
            if (booking['doctorId'] == widget.currentUserId) {
              if (_isDateInPast(booking['date'])) {
                booking['status'] = 'Cancelled';
              }
              requests.add({...booking, 'userId': doc.id});
            }
          }
        }

        if (kDebugMode) {
          print('Fetched ${requests.length} requests for doctorId: ${widget.currentUserId}');
          print('Requests: $requests');
        }

        if (requests.isEmpty) {
          return _buildEmptyState('No booking requests found');
        }

        _cachedRequests = requests;
        _cacheData('cached_requests_${widget.currentUserId}', requests);
        _filteredRequests = _applyFilters(requests, true);
        _filteredRequests.sort(_sortBookings);

        if (kDebugMode) {
          print('Filtered and sorted requests: ${_filteredRequests.length}');
        }

        return _buildBookingList(_filteredRequests, true);
      },
    );
  }

  Widget _buildAppointments() {
    if (_isOffline) {
      if (kDebugMode) {
        print('Offline: Using filtered appointments: ${_filteredAppointments.length}');
      }
      return _buildAppointmentTabs(_filteredAppointments);
    }

    return StreamBuilder<DocumentSnapshot>(
      stream: _appointmentsStream,
      builder: (context, AsyncSnapshot<DocumentSnapshot> snapshot) {
        if (snapshot.connectionState == ConnectionState.waiting) {
          return _buildLoadingState('Appointments');
        }
        if (snapshot.hasError) {
          if (kDebugMode) {
            print('Error loading appointments: ${snapshot.error}');
          }
          return _buildEmptyState('Error loading appointments: ${snapshot.error}');
        }
        if (!snapshot.hasData || !snapshot.data!.exists) {
          if (kDebugMode) {
            print('No appointments found for userId: ${widget.currentUserId}');
          }
          return _buildEmptyState('No appointments found');
        }

        var bookings = List<Map<String, dynamic>>.from(snapshot.data!['Bookings'] ?? []);
        for (var booking in bookings) {
          if (_isDateInPast(booking['date'])) {
            booking['status'] = 'Cancelled';
          }
          booking['userId'] = widget.currentUserId;
        }

        if (kDebugMode) {
          print('Fetched ${bookings.length} bookings for userId: ${widget.currentUserId}');
          print('Bookings: $bookings');
        }

        if (bookings.isEmpty) {
          return _buildEmptyState('No appointments found');
        }

        _cachedAppointments = bookings;
        _cacheData('cached_appointments_${widget.currentUserId}', bookings);
        _filteredAppointments = _applyFilters(bookings, false);
        _filteredAppointments.sort(_sortBookings);

        if (kDebugMode) {
          print('Filtered and sorted appointments: ${_filteredAppointments.length}');
        }

        _updateBookingStatusInDB(bookings);
        return _buildAppointmentTabs(_filteredAppointments);
      },
    );
  }

  Widget _buildAppointmentTabs(List<Map<String, dynamic>> bookings) {
    final pending = bookings.where((b) => b['status'] == 'Pending').toList();
    final active = bookings.where((b) => b['status'] == 'Active').toList();
    final terminated = bookings.where((b) => b['status'] == 'Cancelled').toList();

    if (kDebugMode) {
      print('Appointment tabs: Pending=${pending.length}, Active=${active.length}, Cancelled=${terminated.length}');
    }

    return DefaultTabController(
      length: 3,
      child: Column(
        children: [
          Container(
            color: Colors.white,
            child: TabBar(
              indicatorColor: Colors.teal,
              labelColor: Colors.teal,
              unselectedLabelColor: Colors.grey[600],
              labelStyle: Theme.of(context).textTheme.bodyMedium?.copyWith(fontWeight: FontWeight.bold),
              tabs: [
                Tab(text: 'Pending (${pending.length})'),
                Tab(text: 'Active (${active.length})'),
                Tab(text: 'Cancelled (${terminated.length})'),
              ],
            ),
          ),
          Expanded(
            child: TabBarView(
              children: [
                _buildBookingList(pending, false),
                _buildBookingList(active, false),
                _buildBookingList(terminated, false),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildBookingList(List<Map<String, dynamic>> bookings, bool isRequest) {
    if (bookings.isEmpty) {
      return _buildEmptyState(isRequest ? 'No requests match your filters' : 'No appointments match your filters');
    }

    return ListView.builder(
      key: PageStorageKey<String>('bookings_${isRequest ? "requests" : "appointments"}_list'),
      padding: const EdgeInsets.all(16),
      itemCount: bookings.length,
      itemBuilder: (context, index) => _buildAppointmentCard(bookings[index], isRequest),
    );
  }

  Widget _buildAppointmentCard(Map<String, dynamic> appointment, bool isRequest) {
    return FutureBuilder<DocumentSnapshot>(
      future: FirebaseFirestore.instance
          .collection('Users')
          .doc(isRequest ? appointment['userId'] : appointment['doctorId'])
          .get(),
      builder: (context, AsyncSnapshot<DocumentSnapshot> userSnapshot) {
        if (userSnapshot.connectionState == ConnectionState.waiting) {
          return const Card(
            elevation: 2,
            margin: EdgeInsets.symmetric(vertical: 8, horizontal: 16),
            child: SizedBox(
              height: 100,
              child: Center(child: CircularProgressIndicator()),
            ),
          );
        }
        if (userSnapshot.hasError || !userSnapshot.hasData || !userSnapshot.data!.exists) {
          if (kDebugMode) {
            print('Error fetching user ${isRequest ? appointment['userId'] : appointment['doctorId']}: ${userSnapshot.error}');
          }
          return const SizedBox.shrink();
        }

        var userInfo = userSnapshot.data!.data() as Map<String, dynamic>;
        String formattedDate = appointment['date'] is Timestamp
            ? DateFormat('MMM dd, yyyy HH:mm').format(appointment['date'].toDate())
            : DateFormat('MMM dd, yyyy HH:mm').format(DateTime.parse(appointment['date']));

        Color borderColor = appointment['status'] == 'Active'
            ? Colors.teal
            : appointment['status'] == 'Pending'
            ? Colors.orange
            : Colors.red;

        return Card(
          elevation: 4,
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(12),
            side: BorderSide(color: borderColor, width: 1),
          ),
          margin: const EdgeInsets.symmetric(vertical: 8, horizontal: 16),
          child: Padding(
            padding: const EdgeInsets.all(16),
            child: Row(
              crossAxisAlignment: CrossAxisAlignment.center,
              children: [
                CircleAvatar(
                  radius: 24,
                  backgroundColor: Colors.teal.withOpacity(0.1),
                  child: userInfo['User Pic']?.isNotEmpty == true
                      ? ClipOval(
                    child: CachedNetworkImage(
                      imageUrl: userInfo['User Pic'],
                      fit: BoxFit.cover,
                      width: 48,
                      height: 48,
                      placeholder: (context, url) => const CircularProgressIndicator(),
                      errorWidget: (context, url, error) => Image.asset(
                        'assets/Images/placeholder.png',
                        fit: BoxFit.cover,
                      ),
                      cacheKey: 'user-pic-${isRequest ? appointment['userId'] : appointment['doctorId']}',
                      maxHeightDiskCache: 200,
                      maxWidthDiskCache: 200,
                    ),
                  )
                      : Image.asset(
                    'assets/Images/placeholder.png',
                    fit: BoxFit.cover,
                    width: 48,
                    height: 48,
                  ),
                ),
                const SizedBox(width: 16),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        '${userInfo['Fname'] ?? 'Unknown'} ${userInfo['Lname'] ?? 'Unknown'}',
                        style: Theme.of(context).textTheme.titleMedium?.copyWith(
                          fontWeight: FontWeight.bold,
                          color: Colors.grey[800],
                        ),
                        overflow: TextOverflow.ellipsis,
                      ),
                      const SizedBox(height: 4),
                      Text(
                        'Reason: ${appointment['reason'] ?? 'N/A'}',
                        style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                          color: Colors.grey[600],
                          fontStyle: FontStyle.italic,
                        ),
                        overflow: TextOverflow.ellipsis,
                      ),
                      const SizedBox(height: 4),
                      Text(
                        'Date: $formattedDate',
                        style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                          color: Colors.grey[700],
                        ),
                        overflow: TextOverflow.ellipsis,
                      ),
                      const SizedBox(height: 8),
                      _buildStatusChip(appointment['status']),
                    ],
                  ),
                ),
                if (isRequest && appointment['status'] != 'Active' && !_isOffline)
                  Column(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      IconButton(
                        icon: const Icon(Icons.check, color: Colors.green, size: 24),
                        padding: const EdgeInsets.all(4),
                        constraints: const BoxConstraints(),
                        onPressed: () => _updateStatus(
                          appointment['userId'],
                          appointment['date'] is Timestamp
                              ? appointment['date']
                              : Timestamp.fromDate(DateTime.parse(appointment['date'])),
                          'Active',
                        ),
                      ),
                      IconButton(
                        icon: const Icon(Icons.delete, color: Colors.red, size: 24),
                        padding: const EdgeInsets.all(4),
                        constraints: const BoxConstraints(),
                        onPressed: () => _confirmDelete(
                          appointment['userId'],
                          appointment['date'] is Timestamp
                              ? appointment['date']
                              : Timestamp.fromDate(DateTime.parse(appointment['date'])),
                        ),
                      ),
                    ],
                  )
                else if (!isRequest && appointment['status'] == 'Pending' && !_isOffline)
                  IconButton(
                    icon: const Icon(Icons.delete, color: Colors.red, size: 24),
                    padding: const EdgeInsets.all(4),
                    constraints: const BoxConstraints(),
                    onPressed: () => _confirmDelete(
                      widget.currentUserId,
                      appointment['date'] is Timestamp
                          ? appointment['date']
                          : Timestamp.fromDate(DateTime.parse(appointment['date'])),
                    ),
                  ),
              ],
            ),
          ),
        );
      },
    );
  }

  Widget _buildStatusChip(String? status) {
    Color color = switch (status) {
      'Active' => Colors.teal,
      'Pending' => Colors.orange,
      'Cancelled' => Colors.red,
      _ => Colors.grey,
    };
    return Chip(
      label: Text(
        status ?? 'Unknown',
        style: Theme.of(context).textTheme.labelSmall?.copyWith(
          color: Colors.white,
          fontWeight: FontWeight.bold,
        ),
      ),
      backgroundColor: color.withOpacity(0.8),
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
      materialTapTargetSize: MaterialTapTargetSize.shrinkWrap,
    );
  }

  Widget _buildEmptyState(String message) {
    return Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Icon(
            Icons.event_busy,
            size: 64,
            color: Colors.grey[400],
          ),
          const SizedBox(height: 16),
          Text(
            message,
            style: Theme.of(context).textTheme.titleMedium?.copyWith(
              color: Colors.grey[600],
            ),
            textAlign: TextAlign.center,
          ),
        ],
      ),
    );
  }

  Widget _buildLoadingState(String type) {
    return Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          _buildSophisticatedProgressIndicator(),
          const SizedBox(height: 16),
          Text(
            'Loading $type${_isOffline ? ' (Offline)' : ''}...',
            style: Theme.of(context).textTheme.titleMedium?.copyWith(
              color: Colors.teal,
            ),
          ),
        ],
      ),
    );
  }

  bool _isDateInPast(Timestamp timestamp) {
    return timestamp.toDate().isBefore(DateTime.now());
  }

  Future<void> _createBooking({
    required String doctorId,
    required DateTime date,
    required String reason,
    required String hospitalId,
  }) async {
    if (_isOffline) {
      _showModernSnackBar(context, 'Cannot create booking offline', isError: true);
      return;
    }
    try {
      DocumentReference docRef = FirebaseFirestore.instance.collection('Bookings').doc(widget.currentUserId);
      DocumentSnapshot doc = await docRef.get();
      List<dynamic> bookings = doc.exists ? List.from(doc['Bookings'] ?? []) : [];
      final newBooking = {
        'doctorId': doctorId,
        'hospitalId': hospitalId,
        'date': Timestamp.fromDate(date),
        'status': 'Pending',
        'reason': reason,
      };
      bookings.add(newBooking);
      await docRef.set({'Bookings': bookings});
      _showModernSnackBar(context, 'Booking created successfully');
      setState(() {
        _cachedAppointments = bookings.cast<Map<String, dynamic>>();
        _updateFilteredData();
      });
    } catch (e) {
      _showModernSnackBar(context, 'Failed to create booking: $e', isError: true);
    }
  }

  void _updateStatus(String userId, Timestamp date, String newStatus) async {
    if (_isOffline) {
      _showModernSnackBar(context, 'Cannot update status offline', isError: true);
      return;
    }
    try {
      DocumentSnapshot doc = await FirebaseFirestore.instance.collection('Bookings').doc(userId).get();
      if (!doc.exists) {
        _showModernSnackBar(context, 'Booking document not found', isError: true);
        return;
      }

      List<dynamic> bookings = List.from(doc['Bookings'] ?? []);
      int index = bookings.indexWhere((b) =>
      b['date'] is Timestamp &&
          b['date'].toDate().millisecondsSinceEpoch == date.toDate().millisecondsSinceEpoch);
      if (index == -1) {
        _showModernSnackBar(context, 'Booking not found', isError: true);
        return;
      }

      final updatedBooking = await _showUpdateBookingDialog(context, bookings[index], newStatus);
      if (updatedBooking == null) return;

      bookings[index] = updatedBooking;

      await FirebaseFirestore.instance.collection('Bookings').doc(userId).update({
        'Bookings': bookings,
      });
      _showModernSnackBar(context, 'Status updated to $newStatus');

      final prefs = await SharedPreferences.getInstance();
      await prefs.remove('processed_appointments_${widget.currentUserId}');
      await prefs.remove('sent_accepted_notifications_${widget.currentUserId}');
      setState(() {
        if (userId == widget.currentUserId) {
          _cachedAppointments = bookings.cast<Map<String, dynamic>>();
        } else {
          _cachedRequests = _cachedRequests.map((req) {
            if (req['userId'] == userId &&
                req['date'] is Timestamp &&
                req['date'].toDate().millisecondsSinceEpoch == date.toDate().millisecondsSinceEpoch) {
              return updatedBooking;
            }
            return req;
          }).toList();
        }
        _updateFilteredData();
      });
      await _cacheData(
        userId == widget.currentUserId
            ? 'cached_appointments_${widget.currentUserId}'
            : 'cached_requests_${widget.currentUserId}',
        userId == widget.currentUserId ? _cachedAppointments : _cachedRequests,
      );
    } catch (e) {
      _showModernSnackBar(context, 'Failed to update status: $e', isError: true);
    }
  }

  Future<Map<String, dynamic>?> _showUpdateBookingDialog(
      BuildContext context,
      Map<String, dynamic> booking,
      String newStatus,
      ) async {
    DateTime selectedDateTime = booking['date'].toDate();
    final reasonController = TextEditingController(text: booking['reason']);

    return await showDialog<Map<String, dynamic>>(
      context: context,
      barrierDismissible: true,
      builder: (context) {
        return StatefulBuilder(
          builder: (context, setState) {
            return Dialog(
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
              child: Padding(
                padding: const EdgeInsets.all(16),
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      'Adjust Booking',
                      style: Theme.of(context).textTheme.titleLarge?.copyWith(
                        color: Colors.teal,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                    const SizedBox(height: 16),
                    Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        Expanded(
                          child: Text(
                            DateFormat('MMM d, yyyy h:mm a').format(selectedDateTime),
                            style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                              color: Colors.grey[700],
                            ),
                            overflow: TextOverflow.ellipsis,
                          ),
                        ),
                        TextButton(
                          onPressed: () async {
                            final newDate = await _selectDateTime(context);
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
                        const SizedBox(width: 8),
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
                            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
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
  }

  Future<DateTime?> _selectDateTime(BuildContext context) async {
    final pickedDate = await showDatePicker(
      context: context,
      initialDate: DateTime.now(),
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
      initialTime: TimeOfDay.now(),
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

  void _confirmDelete(String userId, Timestamp date) {
    if (_isOffline) {
      _showModernSnackBar(context, 'Cannot cancel booking offline', isError: true);
      return;
    }
    showDialog(
      context: context,
      barrierDismissible: false,
      builder: (context) {
        return Dialog(
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
          child: Padding(
            padding: const EdgeInsets.all(16),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    Icon(Icons.warning, color: Colors.red[600], size: 24),
                    const SizedBox(width: 8),
                    Text(
                      'Confirm Cancellation',
                      style: Theme.of(context).textTheme.titleLarge?.copyWith(
                        color: Colors.teal[800],
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 16),
                Text(
                  'Are you sure you want to cancel this appointment?',
                  style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                    color: Colors.grey[700],
                  ),
                ),
                const SizedBox(height: 20),
                Row(
                  mainAxisAlignment: MainAxisAlignment.end,
                  children: [
                    TextButton(
                      onPressed: () => Navigator.pop(context),
                      child: Text(
                        'No',
                        style: TextStyle(color: Colors.grey[600]),
                      ),
                    ),
                    const SizedBox(width: 8),
                    ElevatedButton(
                      onPressed: () {
                        _deleteBooking(userId, date);
                        Navigator.pop(context);
                      },
                      style: ElevatedButton.styleFrom(
                        backgroundColor: Colors.teal[600],
                        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
                      ),
                      child: Text(
                        'Yes, Cancel',
                        style: TextStyle(color: Colors.white),
                      ),
                    ),
                  ],
                ),
              ],
            ),
          ),
        );
      },
    );
  }

  void _deleteBooking(String userId, Timestamp date) async {
    try {
      DocumentReference docRef = FirebaseFirestore.instance.collection('Bookings').doc(userId);
      DocumentSnapshot doc = await docRef.get();
      if (!doc.exists) {
        _showModernSnackBar(context, 'Booking document not found', isError: true);
        return;
      }

      List<dynamic> bookings = List.from(doc['Bookings'] ?? []);
      int index = bookings.indexWhere((b) =>
      b['date'] is Timestamp &&
          b['date'].toDate().millisecondsSinceEpoch == date.toDate().millisecondsSinceEpoch);
      if (index == -1) {
        _showModernSnackBar(context, 'Booking not found', isError: true);
        return;
      }

      if (bookings[index] is! Map<String, dynamic>) {
        _showModernSnackBar(context, 'Invalid booking data format', isError: true);
        return;
      }

      bookings[index]['status'] = 'Cancelled';

      await docRef.update({'Bookings': bookings});
      _showModernSnackBar(context, 'Appointment cancelled successfully');

      final prefs = await SharedPreferences.getInstance();
      await prefs.remove('processed_appointments_${widget.currentUserId}');
      setState(() {
        if (userId == widget.currentUserId) {
          _cachedAppointments = bookings.cast<Map<String, dynamic>>();
        } else {
          _cachedRequests = _cachedRequests.map((req) {
            if (req['userId'] == userId &&
                req['date'] is Timestamp &&
                req['date'].toDate().millisecondsSinceEpoch == date.toDate().millisecondsSinceEpoch) {
              return {...req, 'status': 'Cancelled'};
            }
            return req;
          }).toList();
        }
        _updateFilteredData();
        _cacheData(
          userId == widget.currentUserId
              ? 'cached_appointments_${widget.currentUserId}'
              : 'cached_requests_${widget.currentUserId}',
          userId == widget.currentUserId ? _cachedAppointments : _cachedRequests,
        );
      });
    } catch (e) {
      _showModernSnackBar(context, 'Failed to cancel appointment: $e', isError: true);
    }
  }

  void _updateBookingStatusInDB(List<Map<String, dynamic>> bookings) async {
    if (_isOffline) return;
    try {
      await FirebaseFirestore.instance.collection('Bookings').doc(widget.currentUserId).update({
        'Bookings': bookings,
      });
    } catch (e) {
      if (kDebugMode) {
        print('Error updating booking status: $e');
      }
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
            const SizedBox(width: 10),
            Expanded(
              child: Text(
                message,
                style: const TextStyle(color: Colors.white),
              ),
            ),
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

  void _handleNotificationTap(Map<String, dynamic> data) {
    final type = data['type'];
    final bookingDateSeconds = data['bookingDate'];
    final userId = data['userId'];
    final doctorId = data['doctorId'];

    if (kDebugMode) {
      print('Handling notification tap: type=$type, userId=$userId, doctorId=$doctorId, bookingDate=$bookingDateSeconds');
    }

    setState(() {
      _selectedTabIndex = _isDoctor ? 0 : 1;
    });

    if (bookingDateSeconds != null && userId != null && doctorId != null) {
      Navigator.push(
        context,
        MaterialPageRoute(
          builder: (context) => BookingDetailsPage(
            userId: userId,
            doctorId: doctorId,
            bookingDate: Timestamp.fromMillisecondsSinceEpoch(int.parse(bookingDateSeconds) * 1000),
            currentUserId: widget.currentUserId,
          ),
        ),
      );
    } else {
      if (kDebugMode) {
        print('Invalid notification data: $data');
      }
    }
  }
}

extension StringExtension on String {
  String capitalize() {
    return "${this[0].toUpperCase()}${substring(1).toLowerCase()}";
  }
}