import 'package:firebase_core/firebase_core.dart';
import 'package:firebase_remote_config/firebase_remote_config.dart';
import 'package:flutter/foundation.dart';

class ConfigService {
  static final ConfigService _instance = ConfigService._internal();
  factory ConfigService() => _instance;
  ConfigService._internal();

  final _remoteConfig = FirebaseRemoteConfig.instance;

  Future<void> init() async {
    try {
      if (Firebase.apps.isEmpty) {
        print('ConfigService: Firebase not initialized');
        return;
      }
      await _remoteConfig.setConfigSettings(
        RemoteConfigSettings(
          fetchTimeout: const Duration(seconds: 30),
          minimumFetchInterval: kDebugMode ? Duration.zero : const Duration(hours: 12),
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
      });
      print('ConfigService: Default values set');
      _remoteConfig.fetchAndActivate().then((fetched) {
        print('ConfigService: Background fetch ${fetched ? 'successful' : 'failed'}');
        print('ConfigService: Google API Key: ${googleApiKey}');
      }).catchError((e) {
        print('ConfigService: Background fetch failed: $e');
      });
    } catch (e) {
      print('ConfigService: Initialization failed: $e');
    }
  }

  String get googleApiKey => _remoteConfig.getString('google_api_key');
  String get openAiApiKey => _remoteConfig.getString('openai_api_key');
  String get ghanaNlpApiKey => _remoteConfig.getString('ghana_nlp_api_key');
  String get nlpApiKey => _remoteConfig.getString('nlp_api_key');
  String get nlpApiUrl => _remoteConfig.getString('nlp_api_url');
  String get googleTranslateApiKey => _remoteConfig.getString('google_translate_api_key');
}