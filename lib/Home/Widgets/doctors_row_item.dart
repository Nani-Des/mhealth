import 'dart:async';
import 'dart:math';
import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:cached_network_image/cached_network_image.dart';
import 'package:geolocator/geolocator.dart';
import '../../Hospital/doctor_profile.dart';

class DoctorsRowItem extends StatefulWidget {
  @override
  _DoctorsRowItemState createState() => _DoctorsRowItemState();
}

class _DoctorsRowItemState extends State<DoctorsRowItem> {
  final FirebaseFirestore _firestore = FirebaseFirestore.instance;
  List<Map<String, String>> _users = [];
  int _currentIndex = 0;
  late Timer _timer;

  @override
  void initState() {
    super.initState();
    _fetchDoctorsFromClosestHospitals();
    _startAutoSwitching();
  }

  @override
  void dispose() {
    _timer.cancel();
    super.dispose();
  }

  /// Start auto-switching doctors every 5 seconds
  void _startAutoSwitching() {
    _timer = Timer.periodic(Duration(seconds: 5), (timer) {
      if (_users.isNotEmpty) {
        setState(() {
          _currentIndex = (_currentIndex + 3) % _users.length;
        });
      }
    });
  }

  /// Fetch the 2 closest hospitals
  Future<List<String>> _fetchClosestHospitals(Position userPosition) async {
    try {
      QuerySnapshot snapshot = await _firestore.collection('Hospital').get();
      List<Map<String, dynamic>> hospitals = [];

      for (var doc in snapshot.docs) {
        var data = doc.data() as Map<String, dynamic>;
        if (data.containsKey('Lat') && data.containsKey('Lng')) {
          double hospitalLat = (data['Lat'] as num).toDouble();
          double hospitalLng = (data['Lng'] as num).toDouble();
          double distance = _calculateDistance(
              userPosition.latitude, userPosition.longitude, hospitalLat, hospitalLng);
          hospitals.add({'id': doc.id, 'distance': distance});
        }
      }

      hospitals.sort((a, b) => a['distance'].compareTo(b['distance']));
      return hospitals.take(2).map((h) => h['id'] as String).toList();
    } catch (e) {
      print('Error fetching closest hospitals: $e');
      return [];
    }
  }

  /// Fetch doctors from the closest 2 hospitals
  Future<void> _fetchDoctorsFromClosestHospitals() async {
    try {
      Position position = await Geolocator.getCurrentPosition(
        desiredAccuracy: LocationAccuracy.high,
      );

      List<String> closestHospitals = await _fetchClosestHospitals(position);

      if (closestHospitals.isEmpty) {
        print('No hospitals found.');
        return;
      }

      QuerySnapshot snapshot = await _firestore
          .collection('Users')
          .where('Hospital ID', whereIn: closestHospitals)
          .where('Role', isEqualTo: true)
          .limit(10) // Fetch up to 10 doctors to rotate through
          .get();

      List<Map<String, String>> users = snapshot.docs
          .where((doc) {
        var data = doc.data() as Map<String, dynamic>;
        return data.containsKey('User Pic') &&
            data['User Pic'] != null &&
            Uri.tryParse(data['User Pic'])?.hasAbsolutePath == true;
      })
          .map((doc) {
        var data = doc.data() as Map<String, dynamic>;
        return {
          'userId': doc.id,
          'User Pic': data['User Pic'] as String,
          'Fname': '${data['Title'] ?? ''} ${data['Fname'] ?? ''}'.trim(),
        };
      }).toList();

      setState(() {
        _users = users;
      });
    } catch (e) {
      print('Error fetching doctors: $e');
    }
  }

  double _calculateDistance(double lat1, double lng1, double lat2, double lng2) {
    const double R = 6371; // Earth radius in km
    double dLat = _degreesToRadians(lat2 - lat1);
    double dLng = _degreesToRadians(lng2 - lng1);
    double a = sin(dLat / 2) * sin(dLat / 2) +
        cos(_degreesToRadians(lat1)) * cos(_degreesToRadians(lat2)) *
            sin(dLng / 2) * sin(dLng / 2);
    double c = 2 * atan2(sqrt(a), sqrt(1 - a));
    return R * c; // Distance in km
  }

  double _degreesToRadians(double degrees) {
    return degrees * pi / 180;
  }

  void _onItemPressed(int index) {
    final userId = _users[index]['userId'];
    if (userId != null) {
      Navigator.push(
        context,
        MaterialPageRoute(
          builder: (context) => DoctorProfileScreen(userId: userId, isReferral: false),
        ),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    return Container(
      height: 120.0,
      child: AnimatedSwitcher(
        duration: Duration(milliseconds: 500),
        child: Row(
          key: ValueKey<int>(_currentIndex),
          mainAxisAlignment: MainAxisAlignment.center,
          children: _users
              .skip(_currentIndex)
              .take(3)
              .map((user) => Padding(
            padding: const EdgeInsets.symmetric(horizontal: 5.0),
            child: GestureDetector(
              onTap: () => _onItemPressed(_users.indexOf(user)),
              child: Column(
                children: [
                  ClipRRect(
                    borderRadius: BorderRadius.circular(10.0),
                    child: CachedNetworkImage(
                      imageUrl: user['User Pic']!,
                      placeholder: (context, url) => SizedBox.shrink(), // Removed CircularProgressIndicator
                      errorWidget: (context, url, error) => Icon(Icons.error),
                      width: 80.0,
                      height: 80.0,
                      fit: BoxFit.cover,
                    ),
                  ),
                  SizedBox(height: 5),
                  Text(
                    user['Fname']!,
                    style: TextStyle(fontSize: 14.0),
                  ),
                ],
              ),
            ),
          ))
              .toList(),
        ),
      ),
    );
  }
}
