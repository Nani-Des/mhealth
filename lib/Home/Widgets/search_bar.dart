import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:flutter_dotenv/flutter_dotenv.dart';
import 'package:google_maps_flutter/google_maps_flutter.dart';
import 'package:http/http.dart' as http;

class SearchBar1 extends StatefulWidget {
  final double borderRadius;

  const SearchBar1({
    Key? key,
    this.borderRadius = 12.0,
  }) : super(key: key);

  @override
  _SearchBar1State createState() => _SearchBar1State();
}

class _SearchBar1State extends State<SearchBar1> {
  final TextEditingController _controller = TextEditingController();
  GoogleMapController? _googleMapController;
  Marker? _destination;
  String? _selectedPlaceName;
  bool _isMapVisible = false;

  @override
  void dispose() {
    _controller.dispose();
    _googleMapController?.dispose();
    super.dispose();
  }

  Future<void> _searchPlace(String query) async {
    if (query.isEmpty) return;

    try {
      final apiKey = dotenv.env['GOOGLE_API_KEY'];
      if (apiKey == null) throw Exception('Google API Key not found');

      // Use Places API Autocomplete to get predictions
      final autocompleteUrl = Uri.parse(
        'https://maps.googleapis.com/maps/api/place/autocomplete/json'
            '?input=$query'
            '&key=$apiKey'
            '&language=en',
      );
      final autocompleteResponse = await http.get(autocompleteUrl);
      if (autocompleteResponse.statusCode != 200) {
        throw Exception('Failed to fetch autocomplete results');
      }

      final autocompleteData = json.decode(autocompleteResponse.body);
      if (autocompleteData['status'] != 'OK' || autocompleteData['predictions'].isEmpty) {
        throw Exception('No results found');
      }

      final placeId = autocompleteData['predictions'][0]['place_id'];

      // Fetch place details
      final detailsUrl = Uri.parse(
        'https://maps.googleapis.com/maps/api/place/details/json'
            '?place_id=$placeId'
            '&key=$apiKey'
            '&fields=name,geometry',
      );
      final detailsResponse = await http.get(detailsUrl);
      if (detailsResponse.statusCode != 200) {
        throw Exception('Failed to fetch place details');
      }

      final detailsData = json.decode(detailsResponse.body);
      if (detailsData['status'] != 'OK') {
        throw Exception('Failed to get place details');
      }

      final result = detailsData['result'];
      final lat = result['geometry']['location']['lat'] as double;
      final lng = result['geometry']['location']['lng'] as double;

      setState(() {
        _selectedPlaceName = result['name'];
        _destination = Marker(
          markerId: const MarkerId('searched_place'),
          infoWindow: InfoWindow(title: result['name']),
          position: LatLng(lat, lng),
        );
        _isMapVisible = true; // Show the map after search
      });

      _googleMapController?.animateCamera(
        CameraUpdate.newLatLngZoom(LatLng(lat, lng), 14.0),
      );
    } catch (e) {
      setState(() {
        _selectedPlaceName = 'Error: $e';
        _isMapVisible = false; // Hide map on error
      });
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Error: $e')),
      );
    }
  }

  void _resetSearch() {
    setState(() {
      _isMapVisible = false;
      _controller.clear();
      _destination = null;
      _selectedPlaceName = null;
    });
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: SafeArea(
        child: Stack(
          children: [
            if (_isMapVisible && _destination != null)
              GoogleMap(
                onMapCreated: (controller) {
                  _googleMapController = controller;
                  if (_destination != null) {
                    controller.animateCamera(
                      CameraUpdate.newLatLngZoom(_destination!.position, 14.0),
                    );
                  }
                },
                initialCameraPosition: const CameraPosition(
                  target: LatLng(37.7749, -122.4194), // Default: San Francisco
                  zoom: 12,
                ),
                markers: _destination != null ? {_destination!} : {},
              ),
            Column(
              children: [
                Container(
                  margin: const EdgeInsets.symmetric(horizontal: 16.0, vertical: 8.0),
                  child: Row(
                    children: [
                      Expanded(
                        child: Container(
                          decoration: BoxDecoration(
                            color: Colors.white,
                            borderRadius: BorderRadius.circular(widget.borderRadius),
                            boxShadow: [
                              BoxShadow(
                                color: Colors.grey.withOpacity(0.2),
                                spreadRadius: 1,
                                blurRadius: 4,
                                offset: const Offset(0, 2),
                              ),
                            ],
                          ),
                          child: TextField(
                            controller: _controller,
                            decoration: InputDecoration(
                              hintText: 'Search by name...',
                              hintStyle: TextStyle(
                                color: Colors.grey[400],
                                fontWeight: FontWeight.w400,
                              ),
                              prefixIcon: Icon(
                                Icons.search,
                                color: Colors.blueAccent,
                                size: 24,
                              ),
                              suffixIcon: _controller.text.isNotEmpty
                                  ? Container(
                                margin: const EdgeInsets.all(4),
                                decoration: BoxDecoration(
                                  color: Colors.grey[100],
                                  shape: BoxShape.circle,
                                ),
                                child: IconButton(
                                  icon: const Icon(
                                    Icons.clear,
                                    color: Colors.grey,
                                    size: 18,
                                  ),
                                  onPressed: () {
                                    _controller.clear();
                                    _resetSearch();
                                  },
                                ),
                              )
                                  : null,
                              border: OutlineInputBorder(
                                borderRadius: BorderRadius.circular(widget.borderRadius),
                                borderSide: BorderSide.none,
                              ),
                              filled: true,
                              fillColor: Colors.white,
                              contentPadding: const EdgeInsets.symmetric(
                                vertical: 16.0,
                                horizontal: 20.0,
                              ),
                            ),
                            onSubmitted: _searchPlace, // Trigger search on Enter
                          ),
                        ),
                      ),
                      const SizedBox(width: 12),
                      Container(
                        padding: const EdgeInsets.all(14.0),
                        decoration: BoxDecoration(
                          color: Colors.blueAccent,
                          borderRadius: BorderRadius.circular(widget.borderRadius),
                          boxShadow: [
                            BoxShadow(
                              color: Colors.blueAccent.withOpacity(0.3),
                              spreadRadius: 1,
                              blurRadius: 4,
                              offset: const Offset(0, 2),
                            ),
                          ],
                        ),
                        child: const Icon(
                          Icons.local_hospital,
                          color: Colors.white,
                          size: 24,
                        ),
                      ),
                    ],
                  ),
                ),
                if (_isMapVisible && _selectedPlaceName != null)
                  Padding(
                    padding: const EdgeInsets.all(16.0),
                    child: Text(
                      'Selected: $_selectedPlaceName',
                      style: const TextStyle(fontSize: 16, fontWeight: FontWeight.bold),
                    ),
                  ),
              ],
            ),
            if (_isMapVisible)
              Positioned(
                top: 16,
                left: 16,
                child: IconButton(
                  icon: const Icon(Icons.arrow_back, color: Colors.black),
                  onPressed: _resetSearch,
                ),
              ),
          ],
        ),
      ),
    );
  }
}