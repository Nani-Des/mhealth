import 'package:flutter/material.dart';
import 'package:flutter_dotenv/flutter_dotenv.dart';
import 'package:http/http.dart' as http;
import 'dart:convert';
import 'package:google_maps_flutter/google_maps_flutter.dart';
import 'package:mhealth/Home/Widgets/speech_bubble.dart';
import 'doctors_row_item.dart';
import 'organization_list_view.dart';

class HomePageContent extends StatefulWidget {
  const HomePageContent({Key? key}) : super(key: key);

  @override
  _HomePageContentState createState() => _HomePageContentState();
}

class _HomePageContentState extends State<HomePageContent> with SingleTickerProviderStateMixin {
  bool _showInitialView = true;
  String? _selectedPlaceId;
  String? _selectedPlaceName;
  late AnimationController _animationController;
  late Animation<double> _fadeAnimation;

  @override
  void initState() {
    super.initState();
    _animationController = AnimationController(
      duration: const Duration(milliseconds: 300),
      vsync: this,
    );
    _fadeAnimation = Tween<double>(begin: 0.0, end: 1.0).animate(
      CurvedAnimation(parent: _animationController, curve: Curves.easeInOut),
    );
    _animationController.forward();
  }

  @override
  void dispose() {
    _animationController.dispose();
    super.dispose();
  }

  void _onPlaceSelected(PlaceDetails place) {
    setState(() {
      _showInitialView = false;
      _selectedPlaceId = place.placeId;
      _selectedPlaceName = place.name;
    });
    _animationController.forward(from: 0);
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      resizeToAvoidBottomInset: true,
      body: Stack(
        children: [
          AnimatedSwitcher(
            duration: const Duration(milliseconds: 300),
            child: _showInitialView
                ? FadeTransition(
              opacity: _fadeAnimation,
              child: Container(
                decoration: BoxDecoration(
                  gradient: LinearGradient(
                    begin: Alignment.topCenter,
                    end: Alignment.bottomCenter,
                    colors: [Colors.blueGrey[50]!, Colors.white],
                  ),
                ),
                child: SingleChildScrollView(
                  padding: const EdgeInsets.fromLTRB(16.0, 16.0, 16.0, 80.0),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      SearchBar1(onPlaceSelected: _onPlaceSelected),
                      const SizedBox(height: 12),
                      SpeechBubble(
                        onPressed: () {
                          print("See Doctor now! tapped");
                        },
                        textStyle: const TextStyle(
                          fontSize: 15.0,
                          fontWeight: FontWeight.bold,
                          color: Colors.teal,
                        ),
                      ),
                      const SizedBox(height: 12),
                      DoctorsRowItem(),
                      const SizedBox(height: 12),
                      SizedBox(
                        height: MediaQuery.of(context).size.height * 0.5,
                        child: OrganizationListView(showSearchBar: false, isReferral: false),
                      ),
                    ],
                  ),
                ),
              ),
            )
                : MapResultsView(
              key: ValueKey(_selectedPlaceId),
              placeId: _selectedPlaceId!,
              placeName: _selectedPlaceName!,
              onBack: () {
                setState(() => _showInitialView = true);
                _animationController.forward(from: 0);
              },
            ),
          ),
        ],
      ),
    );
  }
}

class SearchBar1 extends StatefulWidget {
  final Function(PlaceDetails)? onPlaceSelected;

  const SearchBar1({Key? key, this.onPlaceSelected}) : super(key: key);

  @override
  _SearchBar1State createState() => _SearchBar1State();
}

class _SearchBar1State extends State<SearchBar1> {
  final TextEditingController _controller = TextEditingController();
  final String? apiKey = dotenv.env['GOOGLE_API_KEY'];
  List<Prediction> _predictions = [];
  bool _isLoading = false;

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  Future<void> _fetchPredictions(String input) async {
    if (input.isEmpty || apiKey == null) {
      setState(() {
        _predictions = [];
        _isLoading = false;
      });
      return;
    }

    setState(() => _isLoading = true);

    // Center of Ghana: approximately 7.9465° N, -1.0232° W
    const String location = '7.9465,-1.0232';
    const String radius = '500000'; // 500 km radius to cover Ghana
    const String types = '(hospital|clinic|doctor|health)'; // Healthcare-specific types

    final url = Uri.parse(
      'https://maps.googleapis.com/maps/api/place/autocomplete/json'
          '?input=$input'
          '&key=$apiKey'
          '&language=en'
          '&components=country:gh' // Restrict to Ghana
          '&location=$location'
          '&radius=$radius'
          '&types=$types',
    );

    try {
      final response = await http.get(url);
      if (response.statusCode == 200) {
        final data = json.decode(response.body);
        if (data['status'] == 'OK') {
          setState(() {
            _predictions = (data['predictions'] as List)
                .map((p) => Prediction.fromJson(p))
                .toList();
            _isLoading = false;
          });
        } else {
          setState(() => _isLoading = false);
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(content: Text('Error: ${data['status']}')),
          );
        }
      } else {
        throw Exception('Failed to fetch predictions');
      }
    } catch (e) {
      setState(() => _isLoading = false);
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Failed to load suggestions')),
      );
    }
  }

  Future<PlaceDetails?> _fetchPlaceDetails(String placeId) async {
    if (apiKey == null) return null;

    final url = Uri.parse(
      'https://maps.googleapis.com/maps/api/place/details/json'
          '?place_id=$placeId'
          '&key=$apiKey'
          '&fields=name,geometry,formatted_address,types',
    );

    try {
      final response = await http.get(url);
      if (response.statusCode == 200) {
        final data = json.decode(response.body);
        if (data['status'] == 'OK') {
          return PlaceDetails.fromJson(data['result'], placeId);
        }
      }
      return null;
    } catch (e) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Failed to load place details')),
      );
      return null;
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
              hintText: 'Search healthcare in Ghana...',
              hintStyle: TextStyle(color: Colors.grey[400]),
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
                  _controller.clear();
                  setState(() => _predictions = []);
                },
              )
                  : null,
              border: OutlineInputBorder(
                borderRadius: BorderRadius.circular(12),
                borderSide: BorderSide.none,
              ),
              contentPadding: const EdgeInsets.symmetric(vertical: 16),
            ),
            onChanged: _fetchPredictions,
          ),
        ),
        if (_predictions.isNotEmpty)
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
            child: ListView.builder(
              shrinkWrap: true,
              physics: const ClampingScrollPhysics(),
              itemCount: _predictions.length,
              itemBuilder: (context, index) {
                final prediction = _predictions[index];
                return ListTile(
                  title: Text(prediction.description),
                  tileColor: Colors.white,
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(12),
                  ),
                  onTap: () async {
                    final place = await _fetchPlaceDetails(prediction.placeId);
                    if (place != null) {
                      widget.onPlaceSelected?.call(place);
                      setState(() {
                        _controller.clear();
                        _predictions = [];
                      });
                    }
                  },
                );
              },
            ),
          ),
      ],
    );
  }
}

class MapResultsView extends StatefulWidget {
  final String placeId;
  final String placeName;
  final VoidCallback onBack;

  const MapResultsView({
    Key? key,
    required this.placeId,
    required this.placeName,
    required this.onBack,
  }) : super(key: key);

  @override
  _MapResultsViewState createState() => _MapResultsViewState();
}

class _MapResultsViewState extends State<MapResultsView> with SingleTickerProviderStateMixin {
  final String? apiKey = dotenv.env['GOOGLE_API_KEY'];
  late GoogleMapController _mapController;
  Set<Marker> _markers = {};
  PlaceDetails? _place;
  late AnimationController _animationController;
  late Animation<double> _fadeAnimation;

  @override
  void initState() {
    super.initState();
    _fetchPlaceDetails();
    _animationController = AnimationController(
      duration: const Duration(milliseconds: 300),
      vsync: this,
    );
    _fadeAnimation = Tween<double>(begin: 0.0, end: 1.0).animate(
      CurvedAnimation(parent: _animationController, curve: Curves.easeInOut),
    );
    _animationController.forward();
  }

  @override
  void dispose() {
    _animationController.dispose();
    _mapController.dispose();
    super.dispose();
  }

  void _onMapCreated(GoogleMapController controller) {
    _mapController = controller;
    if (_place?.lat != null && _place?.lng != null) {
      _mapController.animateCamera(
        CameraUpdate.newLatLngZoom(LatLng(_place!.lat!, _place!.lng!), 15),
      );
    }
  }

  Future<void> _fetchPlaceDetails() async {
    if (apiKey == null) return;

    final url = Uri.parse(
      'https://maps.googleapis.com/maps/api/place/details/json'
          '?place_id=${widget.placeId}'
          '&key=$apiKey'
          '&fields=name,geometry,formatted_address,types',
    );

    try {
      final response = await http.get(url);
      if (response.statusCode == 200) {
        final data = json.decode(response.body);
        if (data['status'] == 'OK') {
          setState(() {
            _place = PlaceDetails.fromJson(data['result'], widget.placeId);
            if (_place?.lat != null && _place?.lng != null) {
              _markers = {
                Marker(
                  markerId: MarkerId(widget.placeId),
                  position: LatLng(_place!.lat!, _place!.lng!),
                  infoWindow: InfoWindow(
                    title: _place!.name,
                    snippet: _place!.formattedAddress,
                  ),
                  icon: BitmapDescriptor.defaultMarkerWithHue(BitmapDescriptor.hueBlue),
                ),
              };
            }
          });
        }
      }
    } catch (e) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Failed to load place details')),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    return FadeTransition(
      opacity: _fadeAnimation,
      child: Stack(
        children: [
          GoogleMap(
            onMapCreated: _onMapCreated,
            initialCameraPosition: const CameraPosition(
              target: LatLng(7.9465, -1.0232), // Center of Ghana
              zoom: 7, // Zoom level to show most of Ghana initially
            ),
            markers: _markers,
            myLocationEnabled: true,
            myLocationButtonEnabled: true,
            mapToolbarEnabled: false,
          ),
          Positioned(
            top: MediaQuery.of(context).padding.top + 10,
            left: 15,
            right: 15,
            child: Row(
              children: [
                Material(
                  elevation: 4,
                  borderRadius: BorderRadius.circular(12),
                  child: IconButton(
                    icon: const Icon(Icons.arrow_back_ios, color: Colors.teal),
                    onPressed: widget.onBack,
                    padding: const EdgeInsets.all(12),
                  ),
                ),
                const SizedBox(width: 8),
                Expanded(
                  child: Container(
                    decoration: BoxDecoration(
                      color: Colors.white,
                      borderRadius: BorderRadius.circular(12),
                      boxShadow: [
                        BoxShadow(
                          color: Colors.grey.withOpacity(0.3),
                          spreadRadius: 2,
                          blurRadius: 8,
                          offset: const Offset(0, 2),
                        ),
                      ],
                    ),
                    padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
                    child: Text(
                      widget.placeName,
                      style: const TextStyle(
                        fontSize: 16,
                        fontWeight: FontWeight.w500,
                        color: Colors.black87,
                      ),
                      overflow: TextOverflow.ellipsis,
                    ),
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

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
  final String placeId;
  final String? formattedAddress;
  final List<String>? types;

  PlaceDetails({
    required this.name,
    this.lat,
    this.lng,
    required this.placeId,
    this.formattedAddress,
    this.types,
  });

  factory PlaceDetails.fromJson(Map<String, dynamic> json, String placeId) {
    final geometry = json['geometry']?['location'];
    return PlaceDetails(
      name: json['name'] as String,
      lat: geometry?['lat'] as double?,
      lng: geometry?['lng'] as double?,
      placeId: placeId,
      formattedAddress: json['formatted_address'] as String?,
      types: (json['types'] as List?)?.map((t) => t as String).toList(),
    );
  }
}