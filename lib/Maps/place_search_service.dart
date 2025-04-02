// place_search_service.dart

import 'package:dio/dio.dart';
import 'package:google_maps_flutter/google_maps_flutter.dart';

class PlaceSearchService {
  final Dio _dio = Dio();

  // Function to search for a place by name and return its location and name
  Future<Map<String, dynamic>> searchPlace(String query, String apiKey) async {
    if (query.isEmpty) {
      throw ArgumentError('Query cannot be empty');
    }

    final url =
        'https://maps.googleapis.com/maps/api/place/textsearch/json?query=$query&key=$apiKey';

    try {
      final response = await _dio.get(url);
      if (response.data['results'].isNotEmpty) {
        final place = response.data['results'][0];
        final lat = place['geometry']['location']['lat'];
        final lng = place['geometry']['location']['lng'];
        final name = place['name'];

        return {
          'name': name,
          'lat': lat,
          'lng': lng,
        };
      } else {
        throw Exception('No results found for the query');
      }
    } catch (e) {
      throw Exception('Error searching place: $e');
    }
  }
}
