import 'package:firebase_auth/firebase_auth.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/material.dart';
import 'package:google_sign_in/google_sign_in.dart';
import 'package:provider/provider.dart';
import 'package:sign_in_with_apple/sign_in_with_apple.dart';

class AuthService with ChangeNotifier {
  final FirebaseAuth _auth = FirebaseAuth.instance;
  final FirebaseFirestore _firestore = FirebaseFirestore.instance;
  final GoogleSignIn _googleSignIn = GoogleSignIn();
  User? _currentUser;
  bool _isLoading = false;
  String? _errorMessage;

  User? get currentUser => _currentUser;
  bool get isLoading => _isLoading;
  String? get errorMessage => _errorMessage;

  static const String defaultProfilePic =
      'https://firebasestorage.googleapis.com/v0/b/mhealth-6191e.appspot.com/o/assets%2Fplaceholder.png?alt=media&token=3350f551-d18e-44ed-939a-095b8a66a2a7';

  AuthService() {
    _auth.authStateChanges().listen((User? user) {
      _currentUser = user;
      notifyListeners();
    });
  }

  // Validate email format
  static bool isValidEmail(String email) {
    final emailRegex = RegExp(r'^[a-zA-Z0-9._%+-]+@[a-zA-Z0-9.-]+\.[a-zA-Z]{2,}$');
    return emailRegex.hasMatch(email);
  }

  // Map FirebaseAuthException codes to user-friendly messages
  String _mapFirebaseError(FirebaseAuthException e) {
    switch (e.code) {
      case 'email-already-in-use':
        return 'This email is already registered. Please sign in or use a different email.';
      case 'invalid-email':
        return 'The email address is not valid.';
      case 'weak-password':
        return 'The password is too weak. Please use a stronger password.';
      case 'operation-not-allowed':
        return 'This registration method is not allowed. Please contact support.';
      case 'invalid-credential':
        return 'Invalid email or password. Please check your credentials.';
      case 'user-disabled':
        return 'This account has been disabled. Please contact support.';
      case 'user-not-found':
        return 'No account found with this email. Please register first.';
      case 'wrong-password':
        return 'Incorrect password. Please try again.';
      case 'too-many-requests':
        return 'Too many attempts. Please try again later.';
      case 'network-request-failed':
        return 'Network error. Please check your internet connection and try again.';
      default:
        return e.message ?? 'An unexpected error occurred. Please try again.';
    }
  }

  // Show error message to the user
  void _showError(BuildContext context, String message) {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(message),
        backgroundColor: Colors.red,
        duration: const Duration(seconds: 5),
      ),
    );
  }

  // Register user with email and password
  Future<bool> registerUser({
    required BuildContext context,
    required String firstName,
    required String lastName,
    required String email,
    required String password,
    required String phoneNumber,
    String region = '',
  }) async {
    if (!isValidEmail(email)) {
      _errorMessage = 'Please enter a valid email address.';
      _showError(context, _errorMessage!);
      notifyListeners();
      return false;
    }

    if (firstName.isEmpty || lastName.isEmpty || phoneNumber.isEmpty) {
      _errorMessage = 'Please fill in all required fields.';
      _showError(context, _errorMessage!);
      notifyListeners();
      return false;
    }

    _isLoading = true;
    _errorMessage = null;
    notifyListeners();

    try {
      UserCredential userCredential = await _auth.createUserWithEmailAndPassword(
        email: email,
        password: password,
      );

      User? user = userCredential.user;
      if (user != null) {
        await _firestore.collection('Users').doc(user.uid).set({
          'Role': false,
          'Fname': firstName,
          'Lname': lastName,
          'Email': email,
          'User ID': user.uid,
          'Mobile Number': phoneNumber,
          'Region': region,
          'Status': true,
          'User Pic': defaultProfilePic,
          'CreatedAt': Timestamp.now(),
        });

        _currentUser = user;
        notifyListeners();
        return true;
      }
    } on FirebaseAuthException catch (e) {
      _errorMessage = _mapFirebaseError(e);
      _showError(context, _errorMessage!);
    } catch (e) {
      _errorMessage = 'An unexpected error occurred: ${e.toString()}';
      _showError(context, _errorMessage!);
    } finally {
      _isLoading = false;
      notifyListeners();
    }
    return false;
  }

  // Sign in with email and password
  Future<bool> signInUser({
    required BuildContext context,
    required String email,
    required String password,
  }) async {
    if (!isValidEmail(email)) {
      _errorMessage = 'Please enter a valid email address.';
      _showError(context, _errorMessage!);
      notifyListeners();
      return false;
    }

    if (password.isEmpty) {
      _errorMessage = 'Please enter a password.';
      _showError(context, _errorMessage!);
      notifyListeners();
      return false;
    }

    _isLoading = true;
    _errorMessage = null;
    notifyListeners();

    try {
      UserCredential userCredential = await _auth.signInWithEmailAndPassword(
        email: email,
        password: password,
      );

      User? user = userCredential.user;
      if (user != null) {
        DocumentSnapshot userDoc = await _firestore.collection('Users').doc(user.uid).get();
        if (userDoc.exists && userDoc['Status'] == true) {
          _currentUser = user;
          notifyListeners();
          return true;
        } else {
          await _auth.signOut();
          _errorMessage = 'This account is deactivated or deleted.';
          _showError(context, _errorMessage!);
        }
      }
    } on FirebaseAuthException catch (e) {
      _errorMessage = _mapFirebaseError(e);
      _showError(context, _errorMessage!);
    } catch (e) {
      _errorMessage = 'An unexpected error occurred: ${e.toString()}';
      _showError(context, _errorMessage!);
    } finally {
      _isLoading = false;
      notifyListeners();
    }
    return false;
  }

  // Reset password
  Future<bool> resetPassword({
    required BuildContext context,
    required String email,
  }) async {
    if (!isValidEmail(email)) {
      _errorMessage = 'Please enter a valid email address.';
      _showError(context, _errorMessage!);
      notifyListeners();
      return false;
    }

    _isLoading = true;
    _errorMessage = null;
    notifyListeners();

    try {
      await _auth.sendPasswordResetEmail(email: email);
      _showError(context, 'Password reset email sent. Check your inbox.');
      return true;
    } on FirebaseAuthException catch (e) {
      _errorMessage = _mapFirebaseError(e);
      _showError(context, _errorMessage!);
    } catch (e) {
      _errorMessage = 'An unexpected error occurred: ${e.toString()}';
      _showError(context, _errorMessage!);
    } finally {
      _isLoading = false;
      notifyListeners();
    }
    return false;
  }

  // Sign in with Google
  Future<bool> signInWithGoogle(BuildContext context) async {
    _isLoading = true;
    _errorMessage = null;
    notifyListeners();

    try {
      final GoogleSignInAccount? googleUser = await _googleSignIn.signIn();
      if (googleUser == null) {
        _errorMessage = 'Google Sign-In was cancelled.';
        _showError(context, _errorMessage!);
        return false;
      }

      final GoogleSignInAuthentication googleAuth = await googleUser.authentication;
      final OAuthCredential credential = GoogleAuthProvider.credential(
        accessToken: googleAuth.accessToken,
        idToken: googleAuth.idToken,
      );

      UserCredential userCredential = await _auth.signInWithCredential(credential);
      User? user = userCredential.user;

      if (user != null) {
        DocumentSnapshot userDoc = await _firestore.collection('Users').doc(user.uid).get();
        if (!userDoc.exists) {
          String displayName = user.displayName ?? '';
          String firstName = displayName.isNotEmpty ? displayName.split(' ').first : 'User';
          String lastName = displayName.contains(' ') ? displayName.split(' ').sublist(1).join(' ') : '';

          await _firestore.collection('Users').doc(user.uid).set({
            'Role': false,
            'Fname': firstName,
            'Lname': lastName,
            'Email': user.email ?? googleUser.email,
            'User ID': user.uid,
            'Mobile Number': '',
            'Region': '',
            'Status': true,
            'User Pic': user.photoURL ?? defaultProfilePic,
            'CreatedAt': Timestamp.now(),
          });
        } else if (userDoc['Status'] != true) {
          String displayName = user.displayName ?? '';
          String firstName = displayName.isNotEmpty ? displayName.split(' ').first : 'User';
          String lastName = displayName.contains(' ') ? displayName.split(' ').sublist(1).join(' ') : '';

          await _firestore.collection('Users').doc(user.uid).update({
            'Role': false,
            'Fname': firstName,
            'Lname': lastName,
            'Email': user.email ?? googleUser.email,
            'Mobile Number': userDoc['Mobile Number'] ?? '',
            'Region': userDoc['Region'] ?? '',
            'Status': true,
            'User Pic': user.photoURL ?? userDoc['User Pic'] ?? defaultProfilePic,
            'UpdatedAt': Timestamp.now(),
          });
        }

        _currentUser = user;
        notifyListeners();
        return true;
      }
    } on FirebaseAuthException catch (e) {
      _errorMessage = _mapFirebaseError(e);
      _showError(context, _errorMessage!);
    } catch (e) {
      _errorMessage = 'An unexpected error occurred during Google Sign-In: ${e.toString()}';
      _showError(context, _errorMessage!);
    } finally {
      _isLoading = false;
      notifyListeners();
    }
    return false;
  }

  // Sign in with Apple
  Future<bool> signInWithApple(BuildContext context) async {
    _isLoading = true;
    _errorMessage = null;
    notifyListeners();

    try {
      final appleCredential = await SignInWithApple.getAppleIDCredential(
        scopes: [
          AppleIDAuthorizationScopes.email,
          AppleIDAuthorizationScopes.fullName,
        ],
      );

      final oauthCredential = OAuthProvider("apple.com").credential(
        idToken: appleCredential.identityToken,
        accessToken: appleCredential.authorizationCode,
      );

      final UserCredential userCredential = await _auth.signInWithCredential(oauthCredential);
      final User? user = userCredential.user;

      if (user != null) {
        DocumentSnapshot userDoc = await _firestore.collection('Users').doc(user.uid).get();
        if (!userDoc.exists) {
          String firstName = appleCredential.givenName ?? 'User';
          String lastName = appleCredential.familyName ?? '';
          String email = appleCredential.email ?? user.email ?? 'no-email-${user.uid}@example.com';

          await _firestore.collection('Users').doc(user.uid).set({
            'Role': false,
            'Fname': firstName,
            'Lname': lastName,
            'Email': email,
            'User ID': user.uid,
            'Mobile Number': '',
            'Region': '',
            'Status': true,
            'User Pic': defaultProfilePic,
            'CreatedAt': Timestamp.now(),
          });
        } else if (userDoc['Status'] != true) {
          String firstName = appleCredential.givenName ?? userDoc['Fname'] ?? 'User';
          String lastName = appleCredential.familyName ?? userDoc['Lname'] ?? '';
          String email = appleCredential.email ?? user.email ?? userDoc['Email'] ?? 'no-email-${user.uid}@example.com';

          await _firestore.collection('Users').doc(user.uid).update({
            'Role': false,
            'Fname': firstName,
            'Lname': lastName,
            'Email': email,
            'Mobile Number': userDoc['Mobile Number'] ?? '',
            'Region': userDoc['Region'] ?? '',
            'Status': true,
            'User Pic': userDoc['User Pic'] ?? defaultProfilePic,
            'UpdatedAt': Timestamp.now(),
          });
        }

        _currentUser = user;
        notifyListeners();
        return true;
      }
    } on FirebaseAuthException catch (e) {
      _errorMessage = _mapFirebaseError(e);
      _showError(context, _errorMessage!);
    } catch (e) {
      _errorMessage = 'An unexpected error occurred during Apple Sign-In: ${e.toString()}';
      _showError(context, _errorMessage!);
    } finally {
      _isLoading = false;
      notifyListeners();
    }
    return false;
  }

  // Sign out
  Future<void> signOut() async {
    await _googleSignIn.signOut();
    await _auth.signOut();
    _currentUser = null;
    notifyListeners();
  }
}