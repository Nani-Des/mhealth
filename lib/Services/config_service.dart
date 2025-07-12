import 'package:firebase_core/firebase_core.dart';
import 'package:firebase_remote_config/firebase_remote_config.dart';
import 'package:flutter/foundation.dart';

class ConfigService {
  static final ConfigService _instance = ConfigService._internal();
  factory ConfigService() => _instance;
  ConfigService._internal();

  final _remoteConfig = FirebaseRemoteConfig.instance;
  bool _isInitialized = false;

  Future<void> init() async {
    try {
      if (Firebase.apps.isEmpty) {
        print('ConfigService: Firebase not initialized');
        return;
      }
      await _remoteConfig.setConfigSettings(
        RemoteConfigSettings(
          fetchTimeout: const Duration(seconds: 30),
          minimumFetchInterval: kDebugMode ? Duration.zero : const Duration(seconds: 3600),
        ),
      );
      print('ConfigService: RemoteConfig settings applied');
      await _remoteConfig.setDefaults({
        'google_api_key': '',
        'openai_api_key': '',
        'ghana_nlp_api_key': '',
        'nlp_api_key': '',
        'nlp_api_url': 'https://translation-api.ghananlp.org/v1/translate',
        'google_translate_api_key': '',
        'google_maps_api_key': '',
      });
      print('ConfigService: Default values set');

      // Retry fetch up to 3 times
      for (int i = 0; i < 3; i++) {
        try {
          bool updated = await _remoteConfig.fetchAndActivate();
          print('ConfigService: Fetch attempt ${i + 1} ${updated ? 'successful' : 'no new values'}');
          _isInitialized = true;
          break;
        } catch (e) {
          print('ConfigService: Fetch attempt ${i + 1} failed: $e');
          if (i == 2) {
            print('ConfigService: All fetch attempts failed');
            break;
          }
          await Future.delayed(Duration(seconds: 2));
        }
      }

    } catch (e) {
      print('ConfigService: Initialization failed: $e');
    }
  }

  bool get isInitialized => _isInitialized;
  String get googleMapsApiKey => _remoteConfig.getString('google_maps_api_key');
  String get googleApiKey => _remoteConfig.getString('google_api_key');
  String get openAiApiKey => _remoteConfig.getString('openai_api_key');
  String get ghanaNlpApiKey => _remoteConfig.getString('ghana_nlp_api_key');
  String get nlpApiKey => _remoteConfig.getString('nlp_api_key');
  String get nlpApiUrl => _remoteConfig.getString('nlp_api_url');
  String get googleTranslateApiKey => _remoteConfig.getString('google_translate_api_key');
}