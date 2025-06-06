import 'dart:convert';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:connectivity_plus/connectivity_plus.dart';
import 'package:cached_network_image/cached_network_image.dart';
import '../../Auth/auth_screen.dart';
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
  bool _isOffline = false;
  List<Map<String, dynamic>> _cachedHospitals = [];
  Map<String, double> _cachedRatings = {};

  @override
  void initState() {
    super.initState();
    _hospitalsStream = FirebaseFirestore.instance.collection('Hospital').snapshots();
    _scrollController = ScrollController();
    _checkConnectivity();
    _loadCachedData();
    _loadSearchQuery();
  }

  // Check network connectivity
  void _checkConnectivity() async {
    var connectivityResult = await Connectivity().checkConnectivity();
    setState(() {
      _isOffline = connectivityResult.contains(ConnectivityResult.none);
    });

    Connectivity().onConnectivityChanged.listen((List<ConnectivityResult> results) {
      setState(() {
        _isOffline = results.contains(ConnectivityResult.none);
      });
      if (!_isOffline) {
        _showModernSnackBar(context, "Back online, syncing data...");
      }
    });
  }

  // Load cached hospital data and ratings
  Future<void> _loadCachedData() async {
    final prefs = await SharedPreferences.getInstance();
    final cachedHospitals = prefs.getString('cached_hospitals');
    final cachedRatings = prefs.getString('cached_ratings');

    setState(() {
      if (cachedHospitals != null) {
        _cachedHospitals = List<Map<String, dynamic>>.from(jsonDecode(cachedHospitals));
      }
      if (cachedRatings != null) {
        _cachedRatings = Map<String, double>.from(jsonDecode(cachedRatings));
      }
    });
  }

  // Load cached search query
  Future<void> _loadSearchQuery() async {
    final prefs = await SharedPreferences.getInstance();
    final cachedQuery = prefs.getString('search_query_organization');
    if (cachedQuery != null) {
      setState(() {
        searchQuery = cachedQuery;
      });
    }
  }

  // Cache hospital data and ratings
  Future<void> _cacheData(List<Map<String, dynamic>> hospitals, Map<String, double> ratings) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString('cached_hospitals', jsonEncode(hospitals));
    await prefs.setString('cached_ratings', jsonEncode(ratings));
  }

  // Cache search query
  Future<void> _cacheSearchQuery(String query) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString('search_query_organization', query);
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
              onChanged: (value) {
                setState(() => searchQuery = value.toLowerCase());
                _cacheSearchQuery(value.toLowerCase());
              },
            ),
          ),
        Expanded(
          child: _isOffline && _cachedHospitals.isNotEmpty
              ? _buildOfflineHospitalList()
              : StreamBuilder<QuerySnapshot>(
            stream: _hospitalsStream,
            builder: (context, snapshot) {
              if (snapshot.connectionState == ConnectionState.waiting) {
                return Center(
                  child: Column(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      const CircularProgressIndicator(),
                      const SizedBox(height: 16),
                      Text(
                        "Loading Hospitals${_isOffline ? ' (Offline)' : ''}...",
                        style: const TextStyle(fontSize: 16, color: Colors.teal),
                      ),
                    ],
                  ),
                );
              }

              if (!snapshot.hasData || snapshot.data!.docs.isEmpty) {
                return const Center(child: Text("No hospitals found"));
              }

              final hospitals = _filterHospitals(snapshot.data!.docs);
              final hospitalDataList = hospitals.map((doc) {
                final data = doc.data() as Map<String, dynamic>;
                return {
                  'id': doc.id,
                  'Hospital Name': data['Hospital Name'] ?? '',
                  'City': data['City'] ?? 'Unknown City',
                  'Contact': data['Contact'] ?? 'No Contact Info',
                  'Background Image': data['Background Image']?.isNotEmpty == true
                      ? data['Background Image']
                      : 'assets/Images/background_default.jpg',
                };
              }).toList();

              // Cache hospital data
              _cacheData(hospitalDataList, _cachedRatings);

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
                  thumbVisibility: true,
                  thickness: 8,
                  radius: const Radius.circular(12),
                  trackVisibility: true,
                  child: ListView.builder(
                    key: const PageStorageKey<String>('hospital_list'),
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
                        cachedRating: _cachedRatings[hospital.id],
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

  Widget _buildOfflineHospitalList() {
    final filteredHospitals = _filterCachedHospitals(_cachedHospitals);
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
        thumbVisibility: true,
        thickness: 8,
        radius: const Radius.circular(12),
        trackVisibility: true,
        child: ListView.builder(
          key: const PageStorageKey<String>('hospital_list'),
          controller: _scrollController,
          shrinkWrap: true,
          physics: const BouncingScrollPhysics(),
          padding: const EdgeInsets.all(8),
          itemCount: filteredHospitals.length,
          itemBuilder: (context, index) {
            final hospital = filteredHospitals[index];
            return HospitalCard(
              backgroundImage: hospital['Background Image'],
              city: hospital['City'],
              contact: hospital['Contact'],
              hospitalId: hospital['id'],
              onTap: () => _navigateToHospitalPage(context, hospital['id']),
              cachedRating: _cachedRatings[hospital['id']],
            );
          },
        ),
      ),
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

  List<Map<String, dynamic>> _filterCachedHospitals(List<Map<String, dynamic>> hospitals) {
    if (searchQuery.isEmpty) return hospitals;
    return hospitals.where((hospital) {
      final name = (hospital['Hospital Name'] as String?)?.toLowerCase() ?? '';
      final city = (hospital['City'] as String?)?.toLowerCase() ?? '';
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
            Expanded(child: Text(message, style: const TextStyle(color: Colors.white))),
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
}

class HospitalCard extends StatelessWidget {
  final String backgroundImage;
  final String city;
  final String contact;
  final String hospitalId;
  final VoidCallback onTap;
  final double? cachedRating;

  const HospitalCard({
    super.key,
    required this.backgroundImage,
    required this.city,
    required this.contact,
    required this.hospitalId,
    required this.onTap,
    this.cachedRating,
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
            ? AuthScreen()
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
              child: CachedNetworkImage(
                imageUrl: backgroundImage,
                height: 100,
                width: double.infinity,
                fit: BoxFit.cover,
                placeholder: (context, url) => const Center(child: CircularProgressIndicator()),
                errorWidget: (context, url, error) => Image.asset(
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
                  cachedRating != null
                      ? _RatingWidget(rating: cachedRating)
                      : FutureBuilder<double>(
                    future: _getAverageRating(),
                    builder: (context, snapshot) {
                      if (snapshot.connectionState == ConnectionState.waiting) {
                        return const _RatingWidget(loading: true);
                      }
                      final rating = snapshot.data ?? 4.5;
                      // Cache the rating
                      _OrganizationListViewState? state = context.findAncestorStateOfType<_OrganizationListViewState>();
                      state?._cachedRatings[hospitalId] = rating;
                      state?._cacheData(state._cachedHospitals, state._cachedRatings);
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