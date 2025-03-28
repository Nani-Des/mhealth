import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import '../../Hospital/hospital_page.dart';
import '../../Hospital/hospital_profile_screen.dart';
import '../../Hospital/specialty_details.dart';
import '../../Login/login_screen1.dart';

class OrganizationListView extends StatefulWidget {
  final bool showSearchBar;
  final bool isReferral;

  const OrganizationListView({
    super.key,
    required this.showSearchBar,
    required this.isReferral,
  });

  @override
  State<OrganizationListView> createState() => _OrganizationListViewState();
}

class _OrganizationListViewState extends State<OrganizationListView> {
  String searchQuery = "";
  late final Stream<QuerySnapshot> _hospitalsStream;
  final _auth = FirebaseAuth.instance;
  late ScrollController _scrollController;

  @override
  void initState() {
    super.initState();
    _hospitalsStream = FirebaseFirestore.instance.collection('Hospital').snapshots();
    _scrollController = ScrollController();
  }

  @override
  void dispose() {
    _scrollController.dispose();
    super.dispose();
  }

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
                prefixIcon: const Icon(Icons.search),
                border: OutlineInputBorder(borderRadius: BorderRadius.circular(10)),
              ),
              onChanged: (value) => setState(() => searchQuery = value.toLowerCase()),
            ),
          ),
        Expanded(
          child: StreamBuilder<QuerySnapshot>(
            stream: _hospitalsStream,
            builder: (context, snapshot) {
              if (!snapshot.hasData) {
                return const Center(child: CircularProgressIndicator());
              }

              final hospitals = _filterHospitals(snapshot.data!.docs);

              return Container(
                decoration: BoxDecoration(
                  color: Colors.white,
                  borderRadius: BorderRadius.circular(16),
                  boxShadow: [
                    BoxShadow(
                      color: Colors.teal,
                      spreadRadius: 2,
                      blurRadius: 8,
                      offset: const Offset(0, 4),
                    ),
                  ],
                ),
                child: Scrollbar(
                  controller: _scrollController,
                  thumbVisibility: true,// Always show scrollbar
                  thickness: 8, // Slightly thicker for better visibility
                  radius: const Radius.circular(12), // Smooth rounded edges
                  trackVisibility: true, // Show track for modern look
                  child: ListView.builder(
                    controller: _scrollController,
                    shrinkWrap: true,
                    physics: const BouncingScrollPhysics(),
                    padding: const EdgeInsets.all(8),
                    itemCount: hospitals.length,
                    itemBuilder: (context, index) {
                      final hospital = hospitals[index];
                      final hospitalData = hospital.data() as Map<String, dynamic>;
                      final backgroundImage = hospitalData['Background Image']?.isNotEmpty == true
                          ? hospitalData['Background Image']
                          : 'assets/Images/background_default.jpg';

                      return HospitalCard(
                        backgroundImage: backgroundImage,
                        city: hospitalData['City'] ?? 'Unknown City',
                        contact: hospitalData['Contact'] ?? 'No Contact Info',
                        hospitalId: hospital.id,
                        onTap: () => _navigateToHospitalPage(context, hospital.id),
                      );
                    },
                  ),
                ),
              );
            },
          ),
        ),
      ],
    );
  }

  List<QueryDocumentSnapshot> _filterHospitals(List<QueryDocumentSnapshot> docs) {
    if (searchQuery.isEmpty) return docs;
    return docs.where((doc) {
      final data = doc.data() as Map<String, dynamic>;
      final name = (data['Hospital Name'] as String?)?.toLowerCase() ?? '';
      final city = (data['City'] as String?)?.toLowerCase() ?? '';
      return name.contains(searchQuery) || city.contains(searchQuery);
    }).toList();
  }

  void _navigateToHospitalPage(BuildContext context, String hospitalId) {
    Navigator.push(
      context,
      MaterialPageRoute(
        builder: (context) => HospitalPage(
          hospitalId: hospitalId,
          isReferral: widget.isReferral,
        ),
      ),
    );
  }
}

class HospitalCard extends StatelessWidget {
  final String backgroundImage;
  final String city;
  final String contact;
  final String hospitalId;
  final VoidCallback onTap;

  const HospitalCard({
    super.key,
    required this.backgroundImage,
    required this.city,
    required this.contact,
    required this.hospitalId,
    required this.onTap,
  });

  Future<double> _getAverageRating() async {
    try {
      final ratingsSnapshot = await FirebaseFirestore.instance
          .collection('Hospital')
          .doc(hospitalId)
          .collection('Ratings')
          .orderBy('timestamp', descending: true)
          .limit(20)
          .get();

      if (ratingsSnapshot.docs.isEmpty) return 4.5;

      final total = ratingsSnapshot.docs.fold<double>(
        0.0,
            (sum, doc) => sum + (doc['rating'] as double? ?? 0.0),
      );
      return total / ratingsSnapshot.docs.length;
    } catch (e) {
      return 4.5; // Fallback in case of error
    }
  }

  void _navigateToReviews(BuildContext context) {
    final user = FirebaseAuth.instance.currentUser;
    Navigator.push(
      context,
      MaterialPageRoute(
        builder: (context) => user == null
            ? LoginScreen1()
            : HospitalProfileScreen(hospitalId: hospitalId),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Card(
      margin: const EdgeInsets.symmetric(vertical: 5.0),
      elevation: 8.0,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(15.0)),
      child: GestureDetector(
        onTap: onTap,
        child: Column(
          children: [
            ClipRRect(
              borderRadius: const BorderRadius.vertical(top: Radius.circular(15.0)),
              child: Image.network(
                backgroundImage,
                height: 100,
                width: double.infinity,
                fit: BoxFit.cover,
                errorBuilder: (_, __, ___) => Image.asset(
                  'assets/Images/background_default.jpg',
                  height: 100,
                  width: double.infinity,
                  fit: BoxFit.cover,
                ),
              ),
            ),
            Padding(
              padding: const EdgeInsets.all(8.0),
              child: Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  FutureBuilder<double>(
                    future: _getAverageRating(),
                    builder: (context, snapshot) {
                      if (snapshot.connectionState == ConnectionState.waiting) {
                        return const _RatingWidget(loading: true);
                      }
                      final rating = snapshot.data ?? 4.5;
                      return _RatingWidget(rating: rating);
                    },
                  ),
                  Column(
                    crossAxisAlignment: CrossAxisAlignment.center,
                    children: [
                      Text(
                        city,
                        style: const TextStyle(
                          fontSize: 14.0,
                          color: Colors.black87,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                      Text(
                        contact,
                        style: const TextStyle(
                          fontSize: 12.0,
                          fontStyle: FontStyle.italic,
                          color: Colors.grey,
                        ),
                      ),
                    ],
                  ),
                  TextButton(
                    onPressed: () => _navigateToReviews(context),
                    child: const Text("Reviews", style: TextStyle(color: Colors.teal)),
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _RatingWidget extends StatelessWidget {
  final double? rating;
  final bool loading;

  const _RatingWidget({this.rating, this.loading = false});

  @override
  Widget build(BuildContext context) {
    return Row(
      children: [
        const Icon(Icons.star, color: Colors.orange, size: 16),
        const SizedBox(width: 5),
        Text(
          loading ? "..." : rating!.toStringAsFixed(1),
          style: const TextStyle(
            fontSize: 14.0,
            fontWeight: FontWeight.bold,
            color: Colors.black87,
          ),
        ),
      ],
    );
  }
}