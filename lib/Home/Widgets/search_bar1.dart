import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:http/http.dart' as http;
import 'dart:convert';
import 'package:cached_network_image/cached_network_image.dart';
import '../../Services/config_service.dart';
import '../../Hospital/doctor_profile.dart';
import '../../Maps/map_screen1.dart';

class SearchBar1 extends StatefulWidget {
  const SearchBar1({Key? key}) : super(key: key);

  @override
  _SearchBar1State createState() => _SearchBar1State();
}

class _SearchBar1State extends State<SearchBar1> {
  final TextEditingController _controller = TextEditingController();
  bool _isLoading = false;
  List<Map<String, dynamic>> _doctorSuggestions = [];
  List<Map<String, dynamic>> _placeSuggestions = [];
  String? googleApiKey;

  @override
  void initState() {
    super.initState();
    // Initialize ConfigService and fetch google_api_key
    ConfigService().init().then((_) {
      if (mounted) {
        setState(() {
          googleApiKey = ConfigService().googleApiKey;
          if (googleApiKey == null || googleApiKey!.isEmpty) {
            print('Error: google_api_key not found in Firebase Remote Config');
          }
        });
      }
    }).catchError((e) {
      if (mounted) {
        print('Error initializing ConfigService: $e');
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Failed to load configuration: $e')),
        );
      }
    });
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  Future<void> _fetchDoctorSuggestions(String query) async {
    if (query.isEmpty) {
      setState(() {
        _doctorSuggestions = [];
      });
      return;
    }

    setState(() {
      _isLoading = true;
    });

    try {
      final snapshot = await FirebaseFirestore.instance
          .collection('Users')
          .where('Role', isEqualTo: true)
          .where('Status', isEqualTo: true)
          .get();

      final doctors = snapshot.docs
          .map((doc) => {
        ...doc.data(),
        'userId': doc.id, // Include document ID as userId
      })
          .where((doctor) {
        final queryLower = query.toLowerCase();
        return (doctor['Fname']?.toLowerCase()?.contains(queryLower) ?? false) ||
            (doctor['Lname']?.toLowerCase()?.contains(queryLower) ?? false) ||
            (doctor['Region']?.toLowerCase()?.contains(queryLower) ?? false);
      })
          .toList();

      setState(() {
        _doctorSuggestions = doctors;
        _isLoading = false;
      });
    } catch (e) {
      print('Error fetching doctors: $e');
      setState(() {
        _isLoading = false;
      });
    }
  }

  Future<void> _fetchPlaceSuggestions(String query) async {
    if (query.isEmpty || googleApiKey == null || googleApiKey!.isEmpty) {
      setState(() {
        _placeSuggestions = [];
      });
      return;
    }

    final url =
        'https://maps.googleapis.com/maps/api/place/autocomplete/json?input=$query&key=$googleApiKey&components=country:gh';

    try {
      final response = await http.get(Uri.parse(url));
      if (response.statusCode == 200) {
        final data = json.decode(response.body);
        setState(() {
          _placeSuggestions = List<Map<String, dynamic>>.from(data['predictions']);
        });
      } else {
        print('Error fetching places: Status code ${response.statusCode}');
      }
    } catch (e) {
      print('Error fetching places: $e');
    }
  }

  @override
  Widget build(BuildContext context) {
    return Column(
      children: [
        Container(
          decoration: BoxDecoration(
            color: Colors.white,
            borderRadius: BorderRadius.circular(12),
            boxShadow: [
              BoxShadow(
                color: Colors.grey.withOpacity(0.2),
                spreadRadius: 2,
                blurRadius: 8,
                offset: const Offset(0, 2),
              ),
            ],
          ),
          child: TextField(
            controller: _controller,
            decoration: InputDecoration(
              hintText: 'Search Health Facilities, Doctors in Ghana...',
              hintStyle: TextStyle(color: Colors.grey[600], fontSize: 12),
              prefixIcon: const Icon(Icons.search, color: Colors.teal),
              suffixIcon: _isLoading
                  ? const Padding(
                padding: EdgeInsets.all(12.0),
                child: SizedBox(
                  width: 20,
                  height: 20,
                  child: CircularProgressIndicator(strokeWidth: 2),
                ),
              )
                  : _controller.text.isNotEmpty
                  ? IconButton(
                icon: Icon(Icons.clear, color: Colors.grey[400]),
                onPressed: () {
                  setState(() {
                    _controller.clear();
                    _doctorSuggestions = [];
                    _placeSuggestions = [];
                  });
                },
              )
                  : null,
              border: OutlineInputBorder(
                borderRadius: BorderRadius.circular(12),
                borderSide: BorderSide.none,
              ),
              contentPadding: const EdgeInsets.symmetric(vertical: 16),
            ),
            onChanged: (value) {
              _fetchDoctorSuggestions(value);
              _fetchPlaceSuggestions(value);
            },
          ),
        ),
        if (_doctorSuggestions.isNotEmpty || _placeSuggestions.isNotEmpty)
          Container(
            margin: const EdgeInsets.only(top: 8),
            constraints: const BoxConstraints(maxHeight: 300),
            decoration: BoxDecoration(
              color: Colors.white,
              borderRadius: BorderRadius.circular(12),
              boxShadow: [
                BoxShadow(
                  color: Colors.grey.withOpacity(0.2),
                  spreadRadius: 2,
                  blurRadius: 8,
                  offset: const Offset(0, 2),
                ),
              ],
            ),
            child: ListView(
              shrinkWrap: true,
              physics: const ClampingScrollPhysics(),
              children: [
                if (_doctorSuggestions.isNotEmpty) ...[
                  Padding(
                    padding: const EdgeInsets.all(8.0),
                    child: Text(
                      'Doctors',
                      style: TextStyle(
                        fontWeight: FontWeight.bold,
                        color: Colors.grey[700],
                      ),
                    ),
                  ),
                  SizedBox(
                    height: 100,
                    child: ListView.builder(
                      scrollDirection: Axis.horizontal,
                      itemCount: _doctorSuggestions.length,
                      itemBuilder: (context, index) {
                        final doctor = _doctorSuggestions[index];
                        return GestureDetector(
                          onTap: () {
                            Navigator.push(
                              context,
                              MaterialPageRoute(
                                builder: (context) => DoctorProfileScreen(
                                  userId: doctor['userId'],
                                  isReferral: false,
                                ),
                              ),
                            );
                          },
                          child: Padding(
                            padding: const EdgeInsets.symmetric(horizontal: 8.0),
                            child: Column(
                              children: [
                                CircleAvatar(
                                  radius: 30,
                                  backgroundImage: doctor['User Pic'] != null
                                      ? CachedNetworkImageProvider(doctor['User Pic'])
                                      : null,
                                  child: doctor['User Pic'] == null
                                      ? const Icon(Icons.person, size: 30)
                                      : null,
                                ),
                                const SizedBox(height: 4),
                                Text(
                                  '${doctor['Title']} ${doctor['Lname']}',
                                  style: const TextStyle(fontSize: 12),
                                ),
                              ],
                            ),
                          ),
                        );
                      },
                    ),
                  ),
                ],
                if (_placeSuggestions.isNotEmpty) ...[
                  Padding(
                    padding: const EdgeInsets.all(8.0),
                    child: Text(
                      'Places',
                      style: TextStyle(
                        fontWeight: FontWeight.bold,
                        color: Colors.grey[700],
                      ),
                    ),
                  ),
                  ..._placeSuggestions.map((place) {
                    return ListTile(
                      title: Text(place['description']),
                      onTap: () {
                        Navigator.push(
                          context,
                          MaterialPageRoute(
                            builder: (context) => MapScreen1(
                              initialPlace: place['description'],
                            ),
                          ),
                        );
                      },
                    );
                  }).toList(),
                ],
              ],
            ),
          ),
      ],
    );
  }
}