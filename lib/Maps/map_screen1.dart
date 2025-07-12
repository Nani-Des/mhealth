import 'package:flutter/material.dart';
import 'package:google_maps_flutter/google_maps_flutter.dart';
import 'package:dio/dio.dart';
import 'package:geolocator/geolocator.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:showcaseview/showcaseview.dart';
import 'package:connectivity_plus/connectivity_plus.dart'; // Added for connectivity check
import '../Services/config_service.dart';
import 'directions_model.dart';
import 'directions_repository.dart';
import 'place_search_service.dart';

class MapScreen1 extends StatefulWidget {
  final String? initialPlace;

  const MapScreen1({
    Key? key,
    this.initialPlace,
  }) : super(key: key);

  @override
  _MapScreen1State createState() => _MapScreen1State();
}

class _MapScreen1State extends State<MapScreen1> {
  CameraPosition _initialCameraPosition = const CameraPosition(
    target: LatLng(6.6666, -1.6163), // Kumasi as fallback
    zoom: 12.5,
  );

  late GoogleMapController _googleMapController;
  Marker? _origin;
  Marker? _destination;
  Directions? _info;
  final TextEditingController _searchController = TextEditingController();
  String? _selectedPlaceName;
  Polyline? _routePolyline;
  bool _isMapReady = false; // Flag for API key availability
  bool _isControllerReady = false; // Flag for GoogleMapController initialization
  bool _isLocationInitialized = false; // Flag for location initialization
  bool _hasInternet = true; // Flag for internet connectivity

  final PlaceSearchService _placeSearchService = PlaceSearchService();
  Position? _currentPosition;

  final GlobalKey _chipKey = GlobalKey();
  final GlobalKey _hospitalKey = GlobalKey();

  @override
  void initState() {
    super.initState();
    if (widget.initialPlace != null) {
      print('Initial Place: ${widget.initialPlace}');
    }
    // Check connectivity
    _checkConnectivity();
    // Initialize ConfigService and check API key
    ConfigService().init().then((_) {
      if (mounted) {
        if (ConfigService().googleApiKey.isEmpty) {
          print('Error: google_api_key not found in Firebase Remote Config');
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(content: Text('Configuration error: Missing Google API key')),
          );
          setState(() {
            _isMapReady = false;
          });
        } else {
          print('MapScreen1: Google API key loaded successfully');
          setState(() {
            _isMapReady = true;
          });
        }
      }
    }).catchError((e) {
      if (mounted) {
        print('Error initializing ConfigService: $e');
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Failed to load configuration: $e')),
        );
        setState(() {
          _isMapReady = false;
        });
      }
    });
  }

  Future<void> _checkConnectivity() async {
    try {
      var connectivityResult = await Connectivity().checkConnectivity();
      setState(() {
        _hasInternet = connectivityResult != ConnectivityResult.none;
      });
      if (!_hasInternet) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('No internet connection. Map tiles may not load.')),
        );
      }
    } catch (e) {
      print('Error checking connectivity: $e');
    }
  }

  Future<void> _initializeMap() async {
    if (!_isMapReady || !_isControllerReady) {
      print('MapScreen1: Waiting for map and controller to be ready');
      return;
    }
    if (!_isLocationInitialized) {
      await _getCurrentLocation();
    }
    if (_currentPosition != null) {
      setState(() {
        _initialCameraPosition = CameraPosition(
          target: LatLng(_currentPosition!.latitude, _currentPosition!.longitude),
          zoom: 14.0,
        );
      });
      _googleMapController.animateCamera(
        CameraUpdate.newLatLngZoom(
          LatLng(_currentPosition!.latitude, _currentPosition!.longitude),
          14.0,
        ),
      );
    }
    if (widget.initialPlace != null && widget.initialPlace!.isNotEmpty) {
      await _searchAndShowRoute(widget.initialPlace!);
    }

    WidgetsBinding.instance.addPostFrameCallback((_) async {
      final prefs = await SharedPreferences.getInstance();
      final bool hasSeenWalkthrough = prefs.getBool('hasSeenEmergencyWalkthrough') ?? false;
      if (!hasSeenWalkthrough && mounted) {
        ShowCaseWidget.of(context)?.startShowCase([_chipKey, _hospitalKey]);
        await prefs.setBool('hasSeenEmergencyWalkthrough', true);
      }
    });
  }

  Future<void> _getCurrentLocation() async {
    bool serviceEnabled = await Geolocator.isLocationServiceEnabled();
    if (!serviceEnabled) {
      setState(() {
        _selectedPlaceName = 'Location services are disabled. Please enable them in your settings.';
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
      _isLocationInitialized = true;
    });
  }

  Future<void> _searchAndShowRoute(String query) async {
    if (!_isMapReady || !_isControllerReady || !_hasInternet) {
      setState(() {
        _selectedPlaceName = 'Error: Map not fully loaded or no internet.';
      });
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Please wait, map is loading or check internet connection.')),
      );
      return;
    }

    if (_currentPosition == null) {
      setState(() {
        _selectedPlaceName = 'Unable to get current location';
      });
      return;
    }

    String apiKey = ConfigService().googleApiKey;
    if (apiKey.isEmpty) {
      setState(() {
        _selectedPlaceName = 'Error: Missing Google API key.';
      });
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Configuration error: Missing Google API key')),
      );
      return;
    }

    try {
      final result = await _placeSearchService.searchPlace(query, apiKey);
      final destinationLatLng = LatLng(result['lat'], result['lng']);

      setState(() {
        _selectedPlaceName = result['name'];
        _destination = Marker(
          markerId: const MarkerId('searched_place'),
          infoWindow: InfoWindow(title: result['name']),
          position: destinationLatLng,
          icon: BitmapDescriptor.defaultMarkerWithHue(BitmapDescriptor.hueBlue),
        );
      });

      final directions = await DirectionsRepository(dio: Dio())
          .getDirections(origin: _origin!.position, destination: destinationLatLng);

      setState(() {
        _info = directions;
        _routePolyline = Polyline(
          polylineId: const PolylineId('route'),
          points: _info!.polylinePoints
              .map((point) => LatLng(point.latitude, point.longitude))
              .toList(),
          color: Colors.teal,
          width: 5,
        );
      });

      _googleMapController.animateCamera(
        CameraUpdate.newLatLngZoom(destinationLatLng, 14.0),
      );
    } catch (e) {
      setState(() {
        _selectedPlaceName = 'Error finding place: $e';
      });
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Search error: $e')),
      );
    }
  }

  Future<void> _findHealthCenter() async {
    if (!_isMapReady || !_isControllerReady || !_hasInternet) {
      setState(() {
        _selectedPlaceName = 'Error: Map not fully loaded or no internet.';
      });
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Please wait, map is loading or check internet connection.')),
      );
      return;
    }

    if (_currentPosition == null) {
      setState(() {
        _selectedPlaceName = 'Unable to get current location';
      });
      return;
    }

    String apiKey = ConfigService().googleApiKey;
    if (apiKey.isEmpty) {
      setState(() {
        _selectedPlaceName = 'Error: Missing Google API key.';
      });
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Configuration error: Missing Google API key')),
      );
      return;
    }

    final lat = _currentPosition!.latitude;
    final lng = _currentPosition!.longitude;

    final url =
        'https://maps.googleapis.com/maps/api/place/nearbysearch/json?location=$lat,$lng&radius=5000&type=health&keyword=health%20center&key=$apiKey';

    try {
      final response = await Dio().get(url);
      if (response.data['results'].isNotEmpty) {
        final healthCenter = response.data['results'][0];
        final healthCenterLat = healthCenter['geometry']['location']['lat'];
        final healthCenterLng = healthCenter['geometry']['location']['lng'];
        final healthCenterName = healthCenter['name'];

        setState(() {
          _selectedPlaceName = 'Nearest Health Center: $healthCenterName';
          _destination = Marker(
            markerId: const MarkerId('nearest_health_center'),
            infoWindow: InfoWindow(title: healthCenterName),
            position: LatLng(healthCenterLat, healthCenterLng),
            icon: BitmapDescriptor.defaultMarkerWithHue(BitmapDescriptor.hueBlue),
          );
        });

        final directions = await DirectionsRepository(dio: Dio())
            .getDirections(origin: _origin!.position, destination: LatLng(healthCenterLat, healthCenterLng));

        setState(() {
          _info = directions;
          _routePolyline = Polyline(
            polylineId: const PolylineId('route'),
            points: _info!.polylinePoints
                .map((point) => LatLng(point.latitude, point.longitude))
                .toList(),
            color: Colors.teal,
            width: 5,
          );
        });

        _googleMapController.animateCamera(
          CameraUpdate.newLatLngZoom(LatLng(healthCenterLat, healthCenterLng), 14.0),
        );
      } else {
        setState(() {
          _selectedPlaceName = 'No health centers found nearby.';
        });
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('No health centers found nearby')),
        );
      }
    } catch (e) {
      setState(() {
        _selectedPlaceName = 'Error finding nearest health center: $e';
      });
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Health center search error: $e')),
      );
    }
  }

  Future<void> _findNearestHospital() async {
    if (!_isMapReady || !_isControllerReady || !_hasInternet) {
      setState(() {
        _selectedPlaceName = 'Error: Map not fully loaded or no internet.';
      });
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Please wait, map is loading or check internet connection.')),
      );
      return;
    }

    if (_currentPosition == null) {
      setState(() {
        _selectedPlaceName = 'Unable to get current location';
      });
      return;
    }

    String apiKey = ConfigService().googleApiKey;
    if (apiKey.isEmpty) {
      setState(() {
        _selectedPlaceName = 'Error: Missing Google API key.';
      });
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Configuration error: Missing Google API key')),
      );
      return;
    }

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
          _destination = Marker(
            markerId: const MarkerId('nearest_hospital'),
            infoWindow: InfoWindow(title: hospitalName),
            position: LatLng(hospitalLat, hospitalLng),
            icon: BitmapDescriptor.defaultMarkerWithHue(BitmapDescriptor.hueBlue),
          );
        });

        final directions = await DirectionsRepository(dio: Dio())
            .getDirections(origin: _origin!.position, destination: LatLng(hospitalLat, hospitalLng));

        setState(() {
          _info = directions;
          _routePolyline = Polyline(
            polylineId: const PolylineId('route'),
            points: _info!.polylinePoints
                .map((point) => LatLng(point.latitude, point.longitude))
                .toList(),
            color: Colors.teal,
            width: 5,
          );
        });

        _googleMapController.animateCamera(
          CameraUpdate.newLatLngZoom(LatLng(hospitalLat, hospitalLng), 14.0),
        );
      } else {
        setState(() {
          _selectedPlaceName = 'No hospitals found nearby.';
        });
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('No hospitals found nearby')),
        );
      }
    } catch (e) {
      setState(() {
        _selectedPlaceName = 'Error finding nearest hospital: $e';
      });
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Hospital search error: $e')),
      );
    }
  }

  @override
  void dispose() {
    _googleMapController.dispose();
    _searchController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return SafeArea(
      child: Scaffold(
        body: Stack(
          children: [
            if (_isMapReady && _hasInternet)
              GoogleMap(
                myLocationButtonEnabled: true, // Enabled to help diagnose map issues
                zoomControlsEnabled: true, // Enabled for user control
                initialCameraPosition: _initialCameraPosition,
                mapType: MapType.normal, // Explicitly set to ensure tiles load
                onMapCreated: (controller) {
                  _googleMapController = controller;
                  setState(() {
                    _isControllerReady = true;
                  });
                  print('MapScreen1: GoogleMap created');
                  _initializeMap();
                },
                markers: {
                  if (_origin != null) _origin!,
                  if (_destination != null) _destination!,
                },
                polylines: _routePolyline != null ? {_routePolyline!} : {},
                onLongPress: _addMarker,
              )
            else
              Center(
                child: _isMapReady
                    ? const Text('No internet connection. Please connect to load map.')
                    : const CircularProgressIndicator(),
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
                    Showcase(
                      key: _hospitalKey,
                      description: 'Tap To Locate Nearest Hospital',
                      child: IconButton(
                        icon: const Icon(Icons.local_hospital_sharp),
                        onPressed: _findNearestHospital,
                        color: Colors.redAccent,
                      ),
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
        floatingActionButton: Showcase(
          key: _chipKey,
          description: 'Tap To Find Nearest CHIP Facility',
          child: FloatingActionButton(
            backgroundColor: Colors.green,
            foregroundColor: Colors.white,
            onPressed: _findHealthCenter,
            child: const Icon(Icons.local_hospital),
          ),
        ),
      ),
    );
  }

  void _addMarker(LatLng pos) async {
    if (!_isMapReady || !_isControllerReady || !_hasInternet) {
      setState(() {
        _selectedPlaceName = 'Error: Map not fully loaded or no internet.';
      });
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Please wait, map is loading or check internet connection.')),
      );
      return;
    }

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
        _routePolyline = null;
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
      setState(() {
        _info = directions;
        _routePolyline = Polyline(
          polylineId: const PolylineId('route'),
          points: _info!.polylinePoints
              .map((point) => LatLng(point.latitude, point.longitude))
              .toList(),
          color: Colors.teal,
          width: 5,
        );
      });
    }
  }

  Future<void> _searchPlace(String query) async {
    if (!_isMapReady || !_isControllerReady || !_hasInternet) {
      setState(() {
        _selectedPlaceName = 'Error: Map not fully loaded or no internet.';
      });
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Please wait, map is loading or check internet connection.')),
      );
      return;
    }

    String apiKey = ConfigService().googleApiKey;
    if (apiKey.isEmpty) {
      setState(() {
        _selectedPlaceName = 'Error: Missing Google API key.';
      });
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Configuration error: Missing Google API key')),
      );
      return;
    }

    try {
      final result = await _placeSearchService.searchPlace(query, apiKey);
      setState(() {
        _selectedPlaceName = result['name'];
        _destination = Marker(
          markerId: const MarkerId('searched_place'),
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
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Search error: $e')),
      );
    }
  }
}