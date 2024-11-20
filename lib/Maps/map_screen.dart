import 'package:flutter/material.dart';
import 'package:google_maps_flutter/google_maps_flutter.dart';
import 'package:dio/dio.dart';
import 'package:geolocator/geolocator.dart'; // Import geolocator

import 'directions_model.dart';
import 'directions_repository.dart';
import 'place_search_service.dart';

class MapScreen extends StatefulWidget {
  @override
  _MapScreenState createState() => _MapScreenState();
}

class _MapScreenState extends State<MapScreen> {
  static const _initialCameraPosition = CameraPosition(
    target: LatLng(6.6666, -1.6163), // Default position
    zoom: 12.5,
  );

  late GoogleMapController _googleMapController;
  Marker? _origin;
  Marker? _destination;
  Directions? _info;
  final TextEditingController _searchController = TextEditingController();
  String? _selectedPlaceName;

  final PlaceSearchService _placeSearchService = PlaceSearchService();

  Position? _currentPosition;

  @override
  void dispose() {
    _googleMapController.dispose();
    _searchController.dispose();
    super.dispose();
  }

  @override
  void initState() {
    super.initState();
    _getCurrentLocation(); // Get the user's current location when the screen loads
  }

  // Function to get current location
  Future<void> _getCurrentLocation() async {
    bool serviceEnabled;
    LocationPermission permission;

    // Check if location services are enabled
    serviceEnabled = await Geolocator.isLocationServiceEnabled();
    if (!serviceEnabled) {
      // Location services are not enabled, show a message to the user and return
      setState(() {
        _selectedPlaceName = 'Location services are disabled. Please enable them in your device settings.';
      });
      return;
    }

    // Check location permission
    permission = await Geolocator.checkPermission();
    if (permission == LocationPermission.denied) {
      // If permission is denied, request it
      permission = await Geolocator.requestPermission();
      if (permission != LocationPermission.whileInUse &&
          permission != LocationPermission.always) {
        // Permission still denied, inform the user
        setState(() {
          _selectedPlaceName = 'Location permission denied. Please allow location access in your settings.';
        });
        return;
      }
    }

    // Get current position
    Position position = await Geolocator.getCurrentPosition(
        desiredAccuracy: LocationAccuracy.high);

    setState(() {
      _currentPosition = position;
      _selectedPlaceName = 'Current Location: ${position.latitude}, ${position.longitude}';
    });
  }


  // Function to search for the nearest hospital
  Future<void> _findNearestHospital() async {
    if (_currentPosition == null) {
      setState(() {
        _selectedPlaceName = 'Unable to get current location';
      });
      return;
    }

    const apiKey = 'AIzaSyCxmBGLBAQ86Aapno5ZcHgtSgJXJA6204s'; // Replace with your actual API key
    final lat = _currentPosition!.latitude;
    final lng = _currentPosition!.longitude;

    final url =
        'https://maps.googleapis.com/maps/api/place/nearbysearch/json?location=$lat,$lng&radius=5000&type=hospital&key=$apiKey';

    try {
      final response = await Dio().get(url);
      if (response.data['results'].isNotEmpty) {
        final hospital = response.data['results'][0];
        final hospitalLat = hospital['geometry']['location']['lat'];
        final hospitalLng = hospital['geometry']['location']['lng'];
        final hospitalName = hospital['name'];

        setState(() {
          _selectedPlaceName = 'Nearest Hospital: $hospitalName';
        });

        // Add a marker for the nearest hospital
        setState(() {
          _destination = Marker(
            markerId: const MarkerId('nearest_hospital'),
            infoWindow: InfoWindow(title: hospitalName),
            position: LatLng(hospitalLat, hospitalLng),
            icon: BitmapDescriptor.defaultMarkerWithHue(BitmapDescriptor.hueBlue), // Set marker color to red
          );
        });

        // Animate camera to the hospital's location
        _googleMapController.animateCamera(
          CameraUpdate.newLatLngZoom(LatLng(hospitalLat, hospitalLng), 14.0),
        );
      } else {
        setState(() {
          _selectedPlaceName = 'No hospitals found nearby.';
        });
      }
    } catch (e) {
      setState(() {
        _selectedPlaceName = 'Error finding nearest hospital: $e';
      });
    }
  }


  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Google Maps with Search'),
        actions: [
          if (_origin != null)
            TextButton(
              onPressed: () => _googleMapController.animateCamera(
                CameraUpdate.newCameraPosition(
                  CameraPosition(
                    target: _origin!.position,
                    zoom: 14.5,
                    tilt: 50.0,
                  ),
                ),
              ),
              style: TextButton.styleFrom(
                foregroundColor: Colors.green,
                textStyle: const TextStyle(fontWeight: FontWeight.w600),
              ),
              child: const Text('ORIGIN'),
            ),
          if (_destination != null)
            TextButton(
              onPressed: () => _googleMapController.animateCamera(
                CameraUpdate.newCameraPosition(
                  CameraPosition(
                    target: _destination!.position,
                    zoom: 14.5,
                    tilt: 50.0,
                  ),
                ),
              ),
              style: TextButton.styleFrom(
                foregroundColor: Colors.blue,
                textStyle: const TextStyle(fontWeight: FontWeight.w600),
              ),
              child: const Text('DEST'),
            )
        ],
      ),
      body: Stack(
        children: [
          GoogleMap(
            myLocationButtonEnabled: false,
            zoomControlsEnabled: false,
            initialCameraPosition: _initialCameraPosition,
            onMapCreated: (controller) => _googleMapController = controller,
            markers: {
              if (_origin != null) _origin!,
              if (_destination != null) _destination!,
            },
            polylines: {
              if (_info != null)
                Polyline(
                  polylineId: const PolylineId('overview_polyline'),
                  color: Colors.red,
                  width: 5,
                  points: _info!.polylinePoints
                      .map((e) => LatLng(e.latitude, e.longitude))
                      .toList(),
                ),
            },
            onLongPress: _addMarker,
          ),
          Positioned(
            top: 10.0,
            left: 10.0,
            right: 10.0,
            child: Container(
              padding: const EdgeInsets.symmetric(horizontal: 8.0),
              decoration: BoxDecoration(
                color: Colors.white,
                borderRadius: BorderRadius.circular(8.0),
                boxShadow: [
                  BoxShadow(
                    color: Colors.black26,
                    offset: Offset(0, 2),
                    blurRadius: 6.0,
                  ),
                ],
              ),
              child: Row(
                children: [
                  Expanded(
                    child: TextField(
                      controller: _searchController,
                      textInputAction: TextInputAction.search,
                      onSubmitted: _searchPlace,
                      decoration: const InputDecoration(
                        hintText: 'Search for a place',
                        border: InputBorder.none,
                        contentPadding: EdgeInsets.only(left: 8.0),
                      ),
                    ),
                  ),
                  IconButton(
                    icon: const Icon(Icons.search),
                    onPressed: () => _searchPlace(_searchController.text),
                  ),
                  IconButton(
                    icon: const Icon(Icons.local_hospital_sharp),
                    onPressed: _findNearestHospital, // Find nearest hospital
                    color: Colors.redAccent,
                  ),
                ],
              ),
            ),
          ),
          if (_selectedPlaceName != null)
            Positioned(
              bottom: 50.0,
              left: 50.0,
              right: 50.0,
              child: Container(
                padding: const EdgeInsets.all(8.0),
                decoration: BoxDecoration(
                  color: Colors.white,
                  borderRadius: BorderRadius.circular(10.0),
                  boxShadow: [
                    BoxShadow(
                      color: Colors.black26,
                      offset: Offset(0, 2),
                      blurRadius: 6.0,
                    ),
                  ],
                ),
                child: Text(
                  _selectedPlaceName!,
                  textAlign: TextAlign.center,
                  style: const TextStyle(
                    fontSize: 10.0,
                    fontWeight: FontWeight.w600,
                  ),
                ),
              ),
            ),
        ],
      ),
      floatingActionButton: FloatingActionButton(
        backgroundColor: Theme.of(context).primaryColor,
        foregroundColor: Colors.black,
        onPressed: () => _googleMapController.animateCamera(
          _info != null
              ? CameraUpdate.newLatLngBounds(_info!.bounds, 100.0)
              : CameraUpdate.newCameraPosition(_initialCameraPosition),
        ),
        child: const Icon(Icons.center_focus_strong),
      ),
    );
  }

  void _addMarker(LatLng pos) async {
    if (_origin == null || (_origin != null && _destination != null)) {
      setState(() {
        _origin = Marker(
          markerId: const MarkerId('origin'),
          infoWindow: const InfoWindow(title: 'Origin'),
          icon: BitmapDescriptor.defaultMarkerWithHue(BitmapDescriptor.hueGreen),
          position: pos,
        );
        _destination = null;
        _info = null;
      });
    } else {
      setState(() {
        _destination = Marker(
          markerId: const MarkerId('destination'),
          infoWindow: const InfoWindow(title: 'Destination'),
          icon: BitmapDescriptor.defaultMarkerWithHue(BitmapDescriptor.hueBlue),
          position: pos,
        );
      });

      final directions = await DirectionsRepository(dio: Dio())
          .getDirections(origin: _origin!.position, destination: pos);
      setState(() => _info = directions);
    }
  }

  Future<void> _searchPlace(String query) async {
    const apiKey = 'AIzaSyCxmBGLBAQ86Aapno5ZcHgtSgJXJA6204s'; // Replace with your actual API key

    try {
      final result = await _placeSearchService.searchPlace(query, apiKey);

      // Set the name of the selected place
      setState(() {
        _selectedPlaceName = result['name'];
      });

      final double lat = result['lat'];
      final double lng = result['lng'];

      // Add a marker at the searched location
      setState(() {
        _destination = Marker(
          markerId: MarkerId('searched_place'),
          infoWindow: InfoWindow(title: result['name']),
          position: LatLng(lat, lng),
          icon: BitmapDescriptor.defaultMarkerWithHue(BitmapDescriptor.hueBlue), // Change color to blue
        );
      });

      // Move the camera to the searched location
      _googleMapController.animateCamera(
        CameraUpdate.newLatLngZoom(LatLng(lat, lng), 14.0),
      );
    } catch (e) {
      setState(() {
        _selectedPlaceName = 'Error: $e';
      });
    }
  }

}
