import 'package:flutter/material.dart';
import 'package:google_maps_flutter/google_maps_flutter.dart';
import 'package:dio/dio.dart';
import 'package:geolocator/geolocator.dart'; // Import geolocator
import 'package:flutter_dotenv/flutter_dotenv.dart';  // Import dotenv

import 'directions_model.dart';
import 'directions_repository.dart';
import 'place_search_service.dart';

class MapScreen1 extends StatefulWidget {
  @override
  _MapScreen1State createState() => _MapScreen1State();
}

class _MapScreen1State extends State<MapScreen1> {
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
      setState(() {
        _selectedPlaceName = 'Location services are disabled. Please enable them in your settings.';
      });
      return;
    }

    // Check and request location permission
    permission = await Geolocator.checkPermission();
    if (permission == LocationPermission.denied) {
      permission = await Geolocator.requestPermission();
      if (permission != LocationPermission.whileInUse &&
          permission != LocationPermission.always) {
        setState(() {
          _selectedPlaceName = 'Location permission denied. Please allow location access in your settings.';
        });
        return;
      }
    }

    // Get the user's current location
    Position position = await Geolocator.getCurrentPosition(
      desiredAccuracy: LocationAccuracy.high,
    );

    // Update state with current position
    setState(() {
      _currentPosition = position;
      _selectedPlaceName = 'Current Location: ${position.latitude}, ${position.longitude}';

      // **Set the origin marker by default**
      _origin = Marker(
        markerId: const MarkerId('origin'),
        position: LatLng(position.latitude, position.longitude),
        infoWindow: const InfoWindow(title: 'You are here'),
        icon: BitmapDescriptor.defaultMarkerWithHue(BitmapDescriptor.hueGreen),
      );
    });

    // Move the camera to the user's location
    _googleMapController.animateCamera(
      CameraUpdate.newLatLngZoom(LatLng(position.latitude, position.longitude), 14.0),
    );
  }

  // Function to search for the nearest hospital
  Future<void> _findNearestHospital() async {
    if (_currentPosition == null) {
      setState(() {
        _selectedPlaceName = 'Unable to get current location';
      });
      return;
    }

    final lat = _currentPosition!.latitude;
    final lng = _currentPosition!.longitude;

    final GOOGLE_API_KEY = dotenv.env['GOOGLE_API_KEY'] ?? ''; // Get Google API Key from dotenv

    if (GOOGLE_API_KEY.isEmpty) {
      setState(() {
        _selectedPlaceName = 'Google API Key is missing. Please check the environment variables.';
      });
      return;
    }

    final url =
        'https://maps.googleapis.com/maps/api/place/nearbysearch/json?location=$lat,$lng&radius=5000&type=hospital&key=$GOOGLE_API_KEY';

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
            icon: BitmapDescriptor.defaultMarkerWithHue(BitmapDescriptor.hueBlue), // Set marker color to blue
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
        ],
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
    try {
      final GOOGLE_API_KEY = dotenv.env['GOOGLE_API_KEY'] ?? ''; // Get Google API Key from dotenv

      if (GOOGLE_API_KEY.isEmpty) {
        setState(() {
          _selectedPlaceName = 'Google API Key is missing. Please check the environment variables.';
        });
        return;
      }

      final result = await _placeSearchService.searchPlace(query, GOOGLE_API_KEY);

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
