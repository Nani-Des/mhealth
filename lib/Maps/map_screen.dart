import 'package:flutter/material.dart';
import 'package:google_maps_flutter/google_maps_flutter.dart';
import 'package:dio/dio.dart';
import 'package:geolocator/geolocator.dart';
import 'package:flutter_dotenv/flutter_dotenv.dart';  // Import dotenv
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
  Polyline? _routePolyline;

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
    _getCurrentLocation();
  }

  Future<void> _getCurrentLocation() async {
    bool serviceEnabled = await Geolocator.isLocationServiceEnabled();
    if (!serviceEnabled) {
      setState(() {
        _selectedPlaceName = 'Location services are delete. Please enable them in your settings.';
      });
      return;
    }

    LocationPermission permission = await Geolocator.checkPermission();
    if (permission == LocationPermission.denied) {
      permission = await Geolocator.requestPermission();
      if (permission == LocationPermission.deniedForever) {
        setState(() {
          _selectedPlaceName = 'Location permission denied. Please allow location access in settings.';
        });
        return;
      }
    }

    Position position = await Geolocator.getCurrentPosition(
      desiredAccuracy: LocationAccuracy.high,
    );

    setState(() {
      _currentPosition = position;
      _selectedPlaceName = 'Current Location: ${position.latitude}, ${position.longitude}';

      _origin = Marker(
        markerId: const MarkerId('origin'),
        position: LatLng(position.latitude, position.longitude),
        infoWindow: const InfoWindow(title: 'You are here'),
        icon: BitmapDescriptor.defaultMarkerWithHue(BitmapDescriptor.hueGreen),
      );
    });

    _googleMapController.animateCamera(
      CameraUpdate.newLatLngZoom(LatLng(position.latitude, position.longitude), 14.0),
    );
  }

  Future<void> _findNearestHospital() async {
    if (_currentPosition == null) {
      setState(() {
        _selectedPlaceName = 'Unable to get current location';
      });
      return;
    }

    final lat = _currentPosition!.latitude;
    final lng = _currentPosition!.longitude;

    final url =
        'https://maps.googleapis.com/maps/api/place/nearbysearch/json?location=$lat,$lng&radius=5000&type=hospital&key=${dotenv.env['GOOGLE_API_KEY']}'; // Use dotenv to get the key

    try {
      final response = await Dio().get(url);
      if (response.data['results'].isNotEmpty) {
        final hospital = response.data['results'][0];
        final hospitalLat = hospital['geometry']['location']['lat'];
        final hospitalLng = hospital['geometry']['location']['lng'];
        final hospitalName = hospital['name'];

        setState(() {
          _selectedPlaceName = 'Nearest Hospital: $hospitalName';
          _destination = Marker(
            markerId: const MarkerId('nearest_hospital'),
            infoWindow: InfoWindow(title: hospitalName),
            position: LatLng(hospitalLat, hospitalLng),
            icon: BitmapDescriptor.defaultMarkerWithHue(BitmapDescriptor.hueBlue),
          );
        });

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
        title: const Text('Find Nearby Hospitals'),
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
              style: TextButton.styleFrom(foregroundColor: Colors.green),
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
              style: TextButton.styleFrom(foregroundColor: Colors.teal),
              child: const Text('DEST'),
            ),
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
            polylines: _routePolyline != null ? {_routePolyline!} : {},
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
                        hintText: 'Search for nearest Hospital',
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
                  boxShadow: [BoxShadow(color: Colors.black26, blurRadius: 6.0)],
                ),
                child: Text(
                  _selectedPlaceName!,
                  textAlign: TextAlign.center,
                  style: const TextStyle(fontSize: 10.0, fontWeight: FontWeight.w600),
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
        _routePolyline = null; // Clear polyline when origin is set again
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

      // Get directions to create a polyline
      final directions = await DirectionsRepository(dio: Dio())
          .getDirections(origin: _origin!.position, destination: pos);
      setState(() {
        _info = directions;

        // Add polyline between origin and destination
        _routePolyline = Polyline(
          polylineId: PolylineId('route'),
          points: _info!.polylinePoints
              .map((point) => LatLng(point.latitude, point.longitude)) // Convert PointLatLng to LatLng
              .toList(),
          color: Colors.blue,
          width: 5,
        );
      });
    }
  }

  Future<void> _searchPlace(String query) async {
    try {
      final result = await _placeSearchService.searchPlace(query, dotenv.env['GOOGLE_API_KEY']!); // Access API key from dotenv
      setState(() {
        _selectedPlaceName = result['name'];
        _destination = Marker(
          markerId: MarkerId('searched_place'),
          infoWindow: InfoWindow(title: result['name']),
          position: LatLng(result['lat'], result['lng']),
        );
      });

      _googleMapController.animateCamera(
        CameraUpdate.newLatLngZoom(LatLng(result['lat'], result['lng']), 14.0),
      );
    } catch (e) {
      setState(() {
        _selectedPlaceName = 'Error: $e';
      });
    }
  }
}
