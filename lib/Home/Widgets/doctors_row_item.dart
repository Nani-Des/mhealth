import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:cached_network_image/cached_network_image.dart';
import '../../Hospital/doctor_profile.dart';

class DoctorsRowItem extends StatefulWidget {
  @override
  _DoctorsRowItemState createState() => _DoctorsRowItemState();
}

class _DoctorsRowItemState extends State<DoctorsRowItem> {
  final FirebaseFirestore _firestore = FirebaseFirestore.instance;
  List<Map<String, String>> _users = [];

  @override
  void initState() {
    super.initState();
    _fetchUserPicsAndNames();
  }

  Future<void> _fetchUserPicsAndNames() async {
    try {
      QuerySnapshot snapshot = await _firestore
          .collection('Users')
          .where('Role', isEqualTo: true) // Ensure 'Role' is stored as a boolean
          .limit(10)
          .get();

      List<Map<String, String>> users = snapshot.docs
          .where((doc) {
        var data = doc.data() as Map<String, dynamic>?; // Cast safely
        return data != null &&
            data.containsKey('User Pic') &&
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
      })
          .toList();

      setState(() {
        _users = users;
      });
    } catch (e) {
      print('Error fetching user pics and names: $e');
    }
  }


  void _onItemPressed(int index) {
    final userId = _users[index]['userId'];
    if (userId != null) {
      Navigator.push(
        context,
        MaterialPageRoute(
          builder: (context) => DoctorProfileScreen(userId: userId, isReferral: false,),
        ),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    return Container(
      height: 120.0,
      child: ListView.builder(
        scrollDirection: Axis.horizontal,
        itemCount: _users.length,
        itemBuilder: (context, index) {
          return Padding(
            padding: const EdgeInsets.symmetric(horizontal: 5.0),
            child: GestureDetector(
              onTap: () => _onItemPressed(index),
              child: Column(
                children: [
                  ClipRRect(
                    borderRadius: BorderRadius.circular(10.0),
                    child: CachedNetworkImage(
                      imageUrl: _users[index]['User Pic']!,
                      placeholder: (context, url) => CircularProgressIndicator(),
                      errorWidget: (context, url, error) => Icon(Icons.error),
                      width: 80.0,
                      height: 80.0,
                      fit: BoxFit.cover,
                    ),
                  ),
                  SizedBox(height: 5),
                  Text(
                    _users[index]['Fname']!,
                    style: TextStyle(
                      fontSize: 14.0,
                    ),
                  ),
                ],
              ),
            ),
          );
        },
      ),
    );
  }
}
