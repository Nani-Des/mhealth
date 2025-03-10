import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:flutter_dotenv/flutter_dotenv.dart';
import 'package:google_maps_flutter/google_maps_flutter.dart';
import 'package:http/http.dart' as http;

class SearchScreen extends StatefulWidget {
  const SearchScreen({Key? key}) : super(key: key);

  @override
  _SearchScreenState createState() => _SearchScreenState();
}

class _SearchScreenState extends State<SearchScreen> {
  bool _isSearching = false;

  void _startSearch() {
    setState(() {
      _isSearching = true;
    });
  }

  void _resetSearch() {
    setState(() {
      _isSearching = false;
    });
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: SafeArea(
        child: Stack(
          children: [
            if (_isSearching) MapWithSearch(onBack: _resetSearch),
            if (!_isSearching)
              Center(
                child: SearchBar1(
                  borderRadius: 30.0, // iOS-like rounded corners
                  onSearchTapped: _startSearch,
                ),
              ),
          ],
        ),
      ),
    );
  }
}

class SearchBar1 extends StatelessWidget {
  final double borderRadius;
  final VoidCallback onSearchTapped;

  const SearchBar1({
    Key? key,
    required this.borderRadius,
    required this.onSearchTapped,
  }) : super(key: key);

  @override
  Widget build(BuildContext context) {
    return Container(
      width: MediaQuery.of(context).size.width * 0.9,
      padding: const EdgeInsets.symmetric(horizontal: 16.0, vertical: 12.0),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(borderRadius),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.1),
            spreadRadius: 1,
            blurRadius: 5,
            offset: const Offset(0, 2),
          ),
        ],
      ),
      child: GestureDetector(
        onTap: onSearchTapped,
        child: Row(
          children: [
            Icon(Icons.search, color: Colors.grey[600], size: 24),
            const SizedBox(width: 12),
            Text(
              'Search by name...',
              style: TextStyle(
                color: Colors.grey[600],
                fontSize: 16,
                fontWeight: FontWeight.w400,
              ),
            ),
            const Spacer(),
            Container(
              padding: const EdgeInsets.all(8.0),
              decoration: BoxDecoration(
                color: Colors.blueAccent,
                borderRadius: BorderRadius.circular(borderRadius),
              ),
              child: const Icon(
                Icons.local_hospital,
                color: Colors.white,
                size: 20,
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class MapWithSearch extends StatefulWidget {
  final VoidCallback onBack;

  const MapWithSearch({Key? key, required this.onBack}) : super(key: key);

  @override
  _MapWithSearchState createState() => _MapWithSearchState();
}

class _MapWithSearchState extends State<MapWithSearch> {
  final TextEditingController _controller = TextEditingController();
  final String? apiKey = dotenv.env['GOOGLE_API_KEY'];
  List<Prediction> _predictions = [];
  late GoogleMapController _mapController;
  PlaceDetails? _selectedPlace;

  @override
  void dispose() {
    _controller.dispose();
    _mapController.dispose();
    super.dispose();
  }

  Future<void> _fetchPredictions(String input) async {
    if (input.isEmpty || apiKey == null) {
      setState(() => _predictions = []);
      return;
    }

    final url = Uri.parse(
      'https://maps.googleapis.com/maps/api/place/autocomplete/json'
          '?input=$input'
          '&key=$apiKey'
          '&language=en'
          '&components=country:us', // Adjust country as needed
    );

    final response = await http.get(url);
    if (response.statusCode == 200) {
      final data = json.decode(response.body);
      if (data['status'] == 'OK') {
        setState(() {
          _predictions = (data['predictions'] as List)
              .map((p) => Prediction.fromJson(p))
              .toList();
        });
      }
    }
  }

  Future<PlaceDetails?> _fetchPlaceDetails(String placeId) async {
    final url = Uri.parse(
      'https://maps.googleapis.com/maps/api/place/details/json'
          '?place_id=$placeId'
          '&key=$apiKey'
          '&fields=name,geometry',
    );

    final response = await http.get(url);
    if (response.statusCode == 200) {
      final data = json.decode(response.body);
      if (data['status'] == 'OK') {
        return PlaceDetails.fromJson(data['result']);
      }
    }
    return null;
  }

  void _onPredictionSelected(Prediction prediction) async {
    final place = await _fetchPlaceDetails(prediction.placeId);
    if (place != null && place.lat != null && place.lng != null) {
      setState(() {
        _selectedPlace = place;
        _controller.text = place.name;
        _predictions = [];
      });
      _mapController.animateCamera(
        CameraUpdate.newLatLng(LatLng(place.lat!, place.lng!)),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    return Stack(
      children: [
        GoogleMap(
          onMapCreated: (controller) {
            _mapController = controller;
          },
          initialCameraPosition: const CameraPosition(
            target: LatLng(37.7749, -122.4194), // Default: San Francisco
            zoom: 12,
          ),
          markers: _selectedPlace != null
              ? {
            Marker(
              markerId: MarkerId(_selectedPlace!.name),
              position: LatLng(_selectedPlace!.lat!, _selectedPlace!.lng!),
              infoWindow: InfoWindow(title: _selectedPlace!.name),
            ),
          }
              : {},
        ),
        Positioned(
          top: 16,
          left: 16,
          right: 16,
          child: Column(
            children: [
              Container(
                decoration: BoxDecoration(
                  color: Colors.white,
                  borderRadius: BorderRadius.circular(30.0),
                  boxShadow: [
                    BoxShadow(
                      color: Colors.black.withOpacity(0.1),
                      spreadRadius: 1,
                      blurRadius: 5,
                      offset: const Offset(0, 2),
                    ),
                  ],
                ),
                child: TextField(
                  controller: _controller,
                  autofocus: true,
                  decoration: InputDecoration(
                    hintText: 'Search by name...',
                    hintStyle: TextStyle(color: Colors.grey[600]),
                    prefixIcon: Icon(Icons.search, color: Colors.grey[600]),
                    suffixIcon: _controller.text.isNotEmpty
                        ? IconButton(
                      icon: Icon(Icons.clear, color: Colors.grey[600]),
                      onPressed: () {
                        _controller.clear();
                        setState(() {
                          _predictions = [];
                          _selectedPlace = null;
                        });
                      },
                    )
                        : null,
                    border: InputBorder.none,
                    contentPadding: const EdgeInsets.symmetric(vertical: 15),
                  ),
                  onChanged: _fetchPredictions,
                ),
              ),
              if (_predictions.isNotEmpty)
                Container(
                  margin: const EdgeInsets.only(top: 8),
                  constraints: BoxConstraints(
                    maxHeight: MediaQuery.of(context).size.height * 0.4,
                  ),
                  decoration: BoxDecoration(
                    color: Colors.white,
                    borderRadius: BorderRadius.circular(12),
                    boxShadow: [
                      BoxShadow(
                        color: Colors.black.withOpacity(0.1),
                        spreadRadius: 1,
                        blurRadius: 5,
                      ),
                    ],
                  ),
                  child: ListView.builder(
                    shrinkWrap: true,
                    itemCount: _predictions.length,
                    itemBuilder: (context, index) {
                      final prediction = _predictions[index];
                      return ListTile(
                        title: Text(prediction.description),
                        onTap: () => _onPredictionSelected(prediction),
                      );
                    },
                  ),
                ),
            ],
          ),
        ),
        Positioned(
          top: 16,
          left: 16,
          child: IconButton(
            icon: const Icon(Icons.arrow_back, color: Colors.black),
            onPressed: widget.onBack,
          ),
        ),
      ],
    );
  }
}

// Data models
class Prediction {
  final String description;
  final String placeId;

  Prediction({required this.description, required this.placeId});

  factory Prediction.fromJson(Map<String, dynamic> json) {
    return Prediction(
      description: json['description'] as String,
      placeId: json['place_id'] as String,
    );
  }
}

class PlaceDetails {
  final String name;
  final double? lat;
  final double? lng;

  PlaceDetails({required this.name, this.lat, this.lng});

  factory PlaceDetails.fromJson(Map<String, dynamic> json) {
    final geometry = json['geometry']?['location'];
    return PlaceDetails(
      name: json['name'] as String,
      lat: geometry?['lat'] as double?,
      lng: geometry?['lng'] as double?,
    );
  }
}