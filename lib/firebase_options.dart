import 'package:firebase_core/firebase_core.dart' show FirebaseOptions;
import 'package:flutter/foundation.dart' show defaultTargetPlatform, TargetPlatform;

class DefaultFirebaseOptions {
  static FirebaseOptions get currentPlatform {
    switch (defaultTargetPlatform) {
      case TargetPlatform.android:
        return android;
      default:
        throw UnsupportedError('DefaultFirebaseOptions are not supported for this platform.');
    }
  }

  static const FirebaseOptions android = FirebaseOptions(
    apiKey: 'YOUR_NEW_API_KEY',
    appId: '1:346868082875:android:6e61d878b9540d82c7e19e',
    messagingSenderId: '346868082875',
    projectId: 'mhealth-6191e',
    storageBucket: 'mhealth-6191e.appspot.com',
  );
}