# mhealth

Cross-platform Flutter app for remote healthcare: bookings, referrals, chat, location-based provider search, notifications, and on-device symptom inference.

Overview
- mhealth is a Flutter client that integrates Firebase (Auth, Firestore, Realtime DB, Storage, Cloud Functions, FCM) with local persistence (Hive), location, voice/video, and an optional on-device TFLite disease model for symptom-to-diagnosis inference.
- The app includes platform integrations for push (FCM/APNs), maps (Google Maps API via Remote Config), WebRTC/Agora for real-time calls, and background notification handling.
- The runtime entry point is `lib/main.dart`; important features live in `lib/` submodules (Auth, ChatModule, Appointments, Maps, Home).
- Configuration uses `firebase_options.dart`, a `.env` file pattern, and Remote Config; several debug flags in `lib/main.dart` let you run without Firebase for local UI/debug work.

Tech Stack
- Dart & Flutter (multi-platform: Android, iOS, Web, macOS, Windows, Linux)
- Firebase: Auth, Firestore, Realtime Database, Storage, Functions, Messaging, Remote Config
- Local storage: Hive
- ML: TFLite (tflite_flutter, firebase_ml_model_downloader)
- Real-time: flutter_webrtc / agora_rtc_engine
- Networking: dio, http
- Maps/geolocation: google_maps_flutter, geolocator
- Notifications: firebase_messaging, platform method channels

Getting Started
Prerequisites
- Flutter SDK (Dart >= 3.5)
- Android SDK or Xcode for platform builds
- Firebase project with Android / iOS apps configured
- Google Maps API key (if using maps)
- Optional: Apple Sign-In key (.p8) and APNs for iOS push; Agora credentials for RTC

Steps
1. Clone the repo
```
git clone https://github.com/Nani-Des/mhealth.git
cd mhealth
```
2. Fetch packages
```
flutter pub get
```
3. Configure Firebase (one of)
- If you have Firebase CLI + FlutterFire:
```
flutterfire configure
```
- Or place platform config files:
```
android/app/google-services.json
ios/Runner/GoogleService-Info.plist
```
Ensure `firebase_options.dart` is generated or present.
4. Provide secrets and keys
- Add environment variables or edit the config service to supply:
  - Google Maps API key (Remote Config or `flutter_dotenv`/`.env`)
  - APNs / .p8 key for Apple Sign-In and APNs (remove from repo; keep private)
  - Agora credentials (if using RTC)
5. Run on a device or emulator
```
flutter run
```
Or target a specific platform:
```
flutter run -d chrome     # web
flutter run -d emulator-5554  # android emulator
```
6. Build release artifacts
```
flutter build apk
flutter build ios
flutter build web
```
7. Run Firebase Functions (if using server helpers)
```
cd functions
npm install
firebase emulators:start --only functions
```

Usage
- Start app and sign in with a Firebase user configured in your project.
- Sample: run on Android emulator and open the bookings screen
```
flutter run -d emulator-5554
# navigate: Home -> Bookings
```
- To bypass Firebase for UI-only development, toggle the debug flag in `lib/main.dart`:
```
const bool debugDisableFirebase = true;
```

Project Structure
```
pubspec.yaml
firebase.json
lib/
  main.dart                      # app entry and initialization
  Auth/                          # auth screens & services
  ChatModule/                    # chat UI and logic
  Appointments/                  # booking/referral forms
  Home/                          # home/dashboard pages
  Maps/                          # map and geolocation screens
  Services/                      # ConfigService, CallService, WordFilterService
assets/
  Icons/ Icon.png
  models/
    disease_model.tflite         # on-device TFLite model (optional)
functions/                        # Firebase Cloud Functions
android/ ios/ macos/ windows/ linux/  # native platforms
test/                             # unit/widget tests
```

Notes & Implementation Details
- Background FCM is handled in `lib/main.dart` via `_firebaseMessagingBackgroundHandler` and saved to SharedPreferences when processed offline.
- Remote Config is used to source runtime keys (e.g., Google Maps API); ConfigService reads and exposes those values at startup.
- The app registers a MethodChannel (`com.mhealth.nhap/...`) to pass platform-specific values (Google Maps API key, FCM token updates) between native code and Dart.
- On-device inference: `assets/models/disease_model.tflite` + `tflite_flutter` are wired for local symptom prediction; Firebase ML Model Downloader is also included for remote model delivery.
- Local cache: Hive box `translations` is opened at app start; other boxes are used across modules.
- Important runtime flags at top of `lib/main.dart`:
```
const bool debugDisableFirebase = false;
const bool debugDisableServices = true;
```
Set these to simplify local development.

Status
working

Author
- Nani-Des — https://github.com/Nani-Des
