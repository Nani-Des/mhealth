import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import '../../Hospital/hospital_page.dart';
import '../../Hospital/hospital_profile_screen.dart';
import '../../Hospital/specialty_details.dart';
import '../../Login/login_screen1.dart'; // Import the login screen

class OrganizationListView extends StatefulWidget {
  final bool showSearchBar;
  final bool isReferral;

  const OrganizationListView({
    Key? key,
    required this.showSearchBar,
    required this.isReferral,
  }) : super(key: key);

  @override
  _OrganizationListViewState createState() => _OrganizationListViewState();
}

class _OrganizationListViewState extends State<OrganizationListView> {
  String searchQuery = "";
  final User? user = FirebaseAuth.instance.currentUser;

  @override
  Widget build(BuildContext context) {
    return Column(
      children: [
        if (widget.showSearchBar)
          Padding(
            padding: const EdgeInsets.all(8.0),
            child: TextField(
              decoration: InputDecoration(
                hintText: 'Search by name or city...',
                prefixIcon: Icon(Icons.search),
                border: OutlineInputBorder(borderRadius: BorderRadius.circular(10)),
              ),
              onChanged: (value) {
                setState(() {
                  searchQuery = value.toLowerCase();
                });
              },
            ),
          ),
        Expanded(
          child: StreamBuilder<QuerySnapshot>(
            stream: FirebaseFirestore.instance.collection('Hospital').snapshots(),
            builder: (context, snapshot) {
              if (!snapshot.hasData) {
                return Center(child: CircularProgressIndicator());
              }

              final hospitals = snapshot.data!.docs.where((doc) {
                final hospitalData = doc.data() as Map<String, dynamic>;
                final hospitalName = hospitalData['Hospital Name']?.toLowerCase() ?? '';
                final city = hospitalData['City']?.toLowerCase() ?? '';
                return hospitalName.contains(searchQuery) || city.contains(searchQuery);
              }).toList();

              return SingleChildScrollView(
                child: ListView.builder(
                  shrinkWrap: true,
                  physics: BouncingScrollPhysics(),
                  itemCount: hospitals.length,
                  itemBuilder: (context, index) {
                    final hospital = hospitals[index];
                    final hospitalData = hospital.data() as Map<String, dynamic>;
                    final backgroundImage = hospitalData['Background Image'] ?? '';
                    final city = hospitalData['City'] ?? 'Unknown City';
                    final contact = hospitalData['Contact'] ?? 'No Contact Info';
                    final hospitalId = hospital.id;

                    return GestureDetector(
                      onTap: () {
                        Navigator.push(
                          context,
                          MaterialPageRoute(
                            builder: (context) => HospitalPage(
                              hospitalId: hospitalId,
                              isReferral: widget.isReferral,
                            ),
                          ),
                        );
                      },
                      child: HospitalCard(
                        backgroundImage: backgroundImage,
                        city: city,
                        contact: contact,
                        hospitalId: hospitalId,
                      ),
                    );
                  },
                ),
              );
            },
          ),
        ),
      ],
    );
  }
}

class HospitalCard extends StatelessWidget {
  final String backgroundImage;
  final String city;
  final String contact;
  final String hospitalId;

  const HospitalCard({
    Key? key,
    required this.backgroundImage,
    required this.city,
    required this.contact,
    required this.hospitalId,
  }) : super(key: key);

  Future<double> _getAverageRating() async {
    final ratingsSnapshot = await FirebaseFirestore.instance
        .collection('Hospital')
        .doc(hospitalId)
        .collection('Ratings')
        .orderBy('timestamp', descending: true)
        .limit(20)
        .get();

    if (ratingsSnapshot.docs.isEmpty) {
      return 4.5; // Default rating if no reviews
    } else {
      double total = 0.0;
      for (var doc in ratingsSnapshot.docs) {
        total += doc['rating'] as double;
      }
      return total / ratingsSnapshot.docs.length;
    }
  }

  void _navigateToReviews(BuildContext context) {
    final User? user = FirebaseAuth.instance.currentUser;
    if (user == null) {
      // If not logged in, redirect to login page
      Navigator.push(
        context,
        MaterialPageRoute(builder: (context) => LoginScreen1()),
      );
    } else {
      // If logged in, go to the reviews page
      Navigator.push(
        context,
        MaterialPageRoute(
          builder: (context) => HospitalProfileScreen(hospitalId: hospitalId),
        ),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    return Card(
      margin: EdgeInsets.symmetric(vertical: 5.0),
      elevation: 8.0,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(15.0)),
      child: Column(
        children: [
          ClipRRect(
            borderRadius: BorderRadius.vertical(top: Radius.circular(15.0)),
            child: Image.network(
              backgroundImage,
              height: 100,
              width: double.infinity,
              fit: BoxFit.cover,
              errorBuilder: (context, error, stackTrace) => Icon(Icons.broken_image, size: 100),
            ),
          ),
          Padding(
            padding: const EdgeInsets.all(8.0),
            child: Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                // Always show ratings
                FutureBuilder<double>(
                  future: _getAverageRating(),
                  builder: (context, snapshot) {
                    if (snapshot.connectionState == ConnectionState.waiting) {
                      return Row(
                        children: [
                          Icon(Icons.star, color: Colors.orange, size: 16),
                          SizedBox(width: 5),
                          Text("...", style: TextStyle(fontSize: 14.0, fontWeight: FontWeight.bold, color: Colors.black87)),
                        ],
                      );
                    }
                    if (snapshot.hasError) {
                      return Text("Error", style: TextStyle(fontSize: 14.0, color: Colors.red));
                    }
                    final rating = snapshot.data ?? 4.5;
                    return Row(
                      children: [
                        Icon(Icons.star, color: Colors.orange, size: 16),
                        SizedBox(width: 5),
                        Text(
                          rating.toStringAsFixed(1),
                          style: TextStyle(fontSize: 14.0, fontWeight: FontWeight.bold, color: Colors.black87),
                        ),
                      ],
                    );
                  },
                ),
                Column(
                  crossAxisAlignment: CrossAxisAlignment.center,
                  children: [
                    Text(
                      city,
                      style: TextStyle(fontSize: 14.0, color: Colors.black87, fontWeight: FontWeight.bold),
                    ),
                    Text(
                      contact,
                      style: TextStyle(fontSize: 12.0, fontStyle: FontStyle.italic, color: Colors.grey),
                    ),
                  ],
                ),
                // Always show "Reviews" button, but check login on tap
                TextButton(
                  onPressed: () => _navigateToReviews(context),
                  child: Text("Reviews", style: TextStyle(color: Colors.teal)),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}