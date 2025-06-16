import 'package:dio/dio.dart';
import 'package:flutter/foundation.dart';
import 'package:google_maps_flutter/google_maps_flutter.dart';
import '../Services/config_service.dart';
import 'directions_model.dart';

class DirectionsRepository {
  static const String _baseUrl =
      'https://maps.googleapis.com/maps/api/directions/json?';

  final Dio _dio;

  DirectionsRepository({Dio? dio}) : _dio = dio ?? Dio();

  Future<Directions?> getDirections({
    required LatLng origin,
    required LatLng destination,
  }) async {
    // Fetch the Google API key from ConfigService
    final String googleApiKey = ConfigService().googleApiKey;

    if (googleApiKey.isEmpty) {
      throw Exception('Google API Key is not set. Please check Firebase Remote Config settings.');
    }

    try {
      final response = await _dio.get(
        _baseUrl,
        queryParameters: {
          'origin': '${origin.latitude},${origin.longitude}',
          'destination': '${destination.latitude},${destination.longitude}',
          'key': googleApiKey,
        },
      );

      // Check if response is successful
      if (response.statusCode == 200) {
        return Directions.fromMap(response.data);
      }
      return null;
    } catch (e) {
      if (kDebugMode) {
        print('Error fetching directions: $e');
      }
      return null;
    }
  }
}