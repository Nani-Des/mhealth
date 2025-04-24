// import 'package:firebase_auth/firebase_auth.dart';
// import 'package:cloud_firestore/cloud_firestore.dart';
// import 'package:flutter/material.dart';
// import 'package:google_sign_in/google_sign_in.dart';
// import 'package:nhap/Registration/Components/phone_number_dialog.dart';
//
// class RegistrationService {
//   static final FirebaseAuth _auth = FirebaseAuth.instance;
//   static final FirebaseFirestore _firestore = FirebaseFirestore.instance;
//   static final GoogleSignIn _googleSignIn = GoogleSignIn();
//
//   // Default profile picture URL
//   static const String defaultProfilePic =
//       'https://firebasestorage.googleapis.com/v0/b/mhealth-6191e.appspot.com/o/assets%2Fplaceholder.png?alt=media&token=3350f551-d18e-44ed-939a-095b8a66a2a7';
//
//   /// Registers a user with email and password and returns the user ID upon successful registration.
//   static Future<String?> registerUser(
//       BuildContext context,
//       String firstName,
//       String lastName,
//       String email,
//       String password,
//       ) async {
//     try {
//       // Register user with Firebase Authentication
//       UserCredential userCredential = await _auth.createUserWithEmailAndPassword(
//         email: email,
//         password: password,
//       );
//
//       User? user = userCredential.user;
//       if (user != null) {
//         // Prompt user for additional information including optional image
//         await PhoneNumberDialog.showPhoneNumberDialog(
//           context,
//               (phoneNumber, countryCode, region, imageUrl) async {
//             // Save user details to Firestore
//             await _firestore.collection('Users').doc(user.uid).set({
//               'Role': false,
//               'Fname': firstName,
//               'Lname': lastName,
//               'Email': user.email,
//               'User ID': user.uid,
//               'Mobile Number': '$countryCode $phoneNumber',
//               'Region': region,
//               'Status': true,
//               'User Pic': imageUrl ?? defaultProfilePic, // Use uploaded image or default
//               'CreatedAt': Timestamp.now(),
//             });
//
//             print('User registered successfully');
//           },
//         );
//
//         // Sign in the user automatically after registration
//         await _signInUser(context, email, password);
//
//         // Return the User ID after login
//         return user.uid;
//       }
//     } catch (e) {
//       print('Error during registration: $e');
//       throw e; // Propagate error to the caller
//     }
//
//     // Return null if registration fails
//     return null;
//   }
//
//   /// Signs in a user with Google and returns the user ID upon successful sign-in.
//   static Future<String?> signInWithGoogle(BuildContext context) async {
//     try {
//       // Initiate Google Sign-In
//       final GoogleSignInAccount? googleUser = await _googleSignIn.signIn();
//       if (googleUser == null) {
//         // User canceled the sign-in
//         ScaffoldMessenger.of(context).showSnackBar(const SnackBar(
//           content: Text('Google Sign-In was canceled.'),
//         ));
//         return null;
//       }
//
//       // Obtain the auth details from the request
//       final GoogleSignInAuthentication googleAuth = await googleUser.authentication;
//
//       // Create a new credential
//       final OAuthCredential credential = GoogleAuthProvider.credential(
//         accessToken: googleAuth.accessToken,
//         idToken: googleAuth.idToken,
//       );
//
//       // Sign in to Firebase with the Google credential
//       UserCredential userCredential = await _auth.signInWithCredential(credential);
//       User? user = userCredential.user;
//
//       if (user != null) {
//         // Check if user already exists in Firestore
//         DocumentSnapshot userDoc = await _firestore.collection('Users').doc(user.uid).get();
//
//         if (!userDoc.exists) {
//           // New user, prompt for additional information
//           await PhoneNumberDialog.showPhoneNumberDialog(
//             context,
//                 (phoneNumber, countryCode, region, imageUrl) async {
//               // Extract first and last name from Google display name
//               String displayName = user.displayName ?? '';
//               String firstName = displayName.isNotEmpty ? displayName.split(' ').first : 'User';
//               String lastName = displayName.contains(' ') ? displayName.split(' ').sublist(1).join(' ') : '';
//
//               // Save user details to Firestore
//               await _firestore.collection('Users').doc(user.uid).set({
//                 'Role': false,
//                 'Fname': firstName,
//                 'Lname': lastName,
//                 'Email': user.email ?? googleUser.email,
//                 'User ID': user.uid,
//                 'Mobile Number': '$countryCode $phoneNumber',
//                 'Region': region,
//                 'Status': true,
//                 'User Pic': imageUrl ?? user.photoURL ?? defaultProfilePic, // Use Google profile pic if available
//                 'CreatedAt': Timestamp.now(),
//               });
//
//               print('Google user registered successfully');
//             },
//           );
//         } else {
//           print('Existing Google user signed in');
//         }
//
//         // Return the User ID for further navigation
//         return user.uid;
//       }
//     } catch (e) {
//       print('Error during Google sign-in: $e');
//       String errorMessage;
//       if (e is FirebaseAuthException) {
//         switch (e.code) {
//           case 'account-exists-with-different-credential':
//             errorMessage = 'Account already exists with a different credential.';
//             break;
//           case 'invalid-credential':
//             errorMessage = 'Invalid Google credentials. Please try again.';
//             break;
//           case 'network-request-failed':
//             errorMessage = 'Network error. Please check your internet connection.';
//             break;
//           default:
//             errorMessage = 'Google sign-in error: ${e.message}';
//         }
//       } else if (e.toString().contains('ApiException: 10')) {
//         errorMessage = 'Google Sign-In failed due to a configuration error (ApiException: 10). Please check SHA-1 and OAuth settings in Firebase.';
//       } else {
//         errorMessage = 'Unexpected Google sign-in error. Please try again.';
//       }
//       ScaffoldMessenger.of(context).showSnackBar(SnackBar(
//         content: Text(errorMessage),
//       ));
//       return null;
//     }
//
//     // Return null if sign-in fails
//     return null;
//   }
//
//   /// Validates email format
//   static bool isValidEmail(String email) {
//     final emailRegex = RegExp(r'^[a-zA-Z0-9._%+-]+@[a-zA-Z0-9.-]+\.[a-zA-Z]{2,}$');
//     return emailRegex.hasMatch(email);
//   }
//
//   /// Signs in the user after registration and returns the user ID
//   static Future<void> _signInUser(BuildContext context, String email, String password) async {
//     try {
//       UserCredential userCredential = await _auth.signInWithEmailAndPassword(
//         email: email,
//         password: password,
//       );
//
//       User? user = userCredential.user;
//       if (user != null) {
//         print('User signed in successfully with ID: ${user.uid}');
//         // Pass the user ID back to the previous screen
//         Navigator.pop(context);
//         Navigator.pop(context, user.uid);
//       }
//     } catch (e) {
//       print('Error signing in: $e');
//       ScaffoldMessenger.of(context).showSnackBar(const SnackBar(
//         content: Text('Failed to sign in. Please check your email and password.'),
//       ));
//       throw e; // Propagate error to the caller
//     }
//   }
// }