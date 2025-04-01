import 'dart:async';
import 'dart:convert';

import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:firebase_core/firebase_core.dart';
import 'package:flutter/material.dart';
import 'package:flutter_dotenv/flutter_dotenv.dart';
import 'package:http/http.dart' as http;

import 'chat_module.dart';


  class TranslationService {
    static String API_KEY = dotenv.env['NLP_API_KEY'] ?? '';
    static String API_URL = dotenv.env['NLP_API_URL'] ?? '';

    static final Map<String, String> ghanaianLanguages = {
      'en': 'English',
      'tw': 'Twi',
      'ee': 'Ewe',
      'gaa': 'Ga',
      'fat': 'Fante',
      'yo': 'Yoruba',
      'dag': 'Dagbani',
      'ki': 'Kikuyu',
      'gur': 'Gurune',
      'luo': 'Luo',
      'mer': 'Kimeru',
      'kus': 'Kusaal',
    };

    static Future<String> translateText({
      required String text,
      required String targetLanguage,
      String sourceLanguage = 'en',
    }) async {
      try {
        print('Starting translation for text: $text to language: $targetLanguage');

        final url = Uri.parse('$API_URL?subscription-key=$API_KEY');

        // Ensure proper UTF-8 encoding in the request
        final response = await http.post(
          url,
          headers: {
            'Content-Type': 'application/json; charset=utf-8',
            'Accept': 'application/json; charset=utf-8',
          },
          body: utf8.encode(jsonEncode({
            'text': text,
            'target_language': targetLanguage,
            'source_language': sourceLanguage,
          })),
        );

        print('Translation Response Status: ${response.statusCode}');
        // Decode the response body with UTF-8
        final decodedBody = utf8.decode(response.bodyBytes);
        print('Translation Response Body: $decodedBody');

        if (response.statusCode == 200) {
          final data = jsonDecode(decodedBody);

          if (data is Map<String, dynamic>) {
            String? translatedText;

            if (data['type'] == 'Success' && data['message'] != null) {
              translatedText = data['message'].toString();
            } else if (data['translatedText'] != null) {
              translatedText = data['translatedText'].toString();
            }

            if (translatedText != null) {
              // Ensure the translated text is properly decoded
              final decodedText = _decodeSpecialCharacters(translatedText);
              print('Successfully translated to: $decodedText');
              return decodedText;
            }

            throw Exception('Unexpected response format: $decodedBody');
          } else {
            throw Exception('Invalid response format: $decodedBody');
          }
        } else {
          final error = jsonDecode(decodedBody);
          throw Exception('Translation failed: ${error['message'] ?? 'Unknown error'}');
        }
      } catch (e) {
        print('Translation Error: $e');
        rethrow;
      }
    }

    // Helper method to decode special characters
    static String _decodeSpecialCharacters(String text) {
      // Replace HTML entities if they appear in the text
      return text
          .replaceAll('&amp;', '&')
          .replaceAll('&lt;', '<')
          .replaceAll('&gt;', '>')
          .replaceAll('&quot;', '"')
          .replaceAll('&#039;', "'")
      // Add more replacements if needed for specific characters
          .replaceAll('\\u', '\\\\u'); // Handle Unicode escape sequences
    }
  }

    void main() async {
    await dotenv.load();
    WidgetsFlutterBinding.ensureInitialized();
    await Firebase.initializeApp();
    await ensureTestUserExists();
    await CallService().clearOldNotifications();
    runApp(const MyApp());
  }

  Future<void> ensureTestUserExists() async {
    const String testEmail = "akotomichael992@yahoo.com";
    const String testPassword = "Test1234!";

    try {
      UserCredential userCredential;

      // Check if a user with this email exists by attempting to log in
      try {
        userCredential = await FirebaseAuth.instance.signInWithEmailAndPassword(
          email: testEmail,
          password: testPassword,
        );
      } catch (e) {
        // If sign-in fails, create the test user
        userCredential = await FirebaseAuth.instance.createUserWithEmailAndPassword(
          email: testEmail,
          password: testPassword,
        );

        // Store user details in Firestore
        final user = userCredential.user;
        if (user != null) {
          await FirebaseFirestore.instance.collection('Users').doc(user.uid).set({
            'CreatedAt': FieldValue.serverTimestamp(),
            'Email': 'akotomichael255@gmail.com',
            'Fname': 'Michael',
            'Lname': 'Akoto',
            'Mobile Number': '0243472977',
            'Region': 'Ashanti',
            'Role': true,  // Set to true if you want the user to be an expert
            'Status': true,
            'User ID': user.uid,
            'User Pic': '', // Add a profile picture URL if available
          });
        }
      }

      print("Test user is logged in as: ${userCredential.user?.email}");
    } catch (error) {
      print("Error ensuring test user exists: $error");
    }
  }

  class MyApp extends StatelessWidget {
    const MyApp({super.key});

    @override
    Widget build(BuildContext context) {
      return const MaterialApp(
        debugShowCheckedModeBanner: false,
        title: 'My Chat App',
        home: ChatHomePage(),
      );
    }
  }

