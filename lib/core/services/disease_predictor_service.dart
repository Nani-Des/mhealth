import 'dart:convert';
import 'dart:io';
import 'dart:typed_data';
import 'package:flutter/services.dart' show rootBundle;
import 'package:tflite_flutter/tflite_flutter.dart';

class DiseasePredictorService {
  late Interpreter _interpreter;
  late List<String> _symptomClasses;
  late List<String> _diseaseClasses;
  bool _isInitialized = false;

  Future<void> init() async {
    try {
      // Load the TensorFlow Lite model
      _interpreter = await Interpreter.fromAsset('assets/models/disease_model.tflite');

      // Load symptom classes (from MLBinarizer)
      final symptomJson = await rootBundle.loadString('assets/models/symptom_classes.json');
      _symptomClasses = List<String>.from(json.decode(symptomJson));

      // Load disease classes (from LabelEncoder)
      final diseaseJson = await rootBundle.loadString('assets/models/disease_classes.json');
      _diseaseClasses = List<String>.from(json.decode(diseaseJson));

      _isInitialized = true;
      print('Disease predictor initialized successfully');
      print('Symptoms loaded: ${_symptomClasses.length}');
      print('Diseases loaded: ${_diseaseClasses.length}');
    } catch (e) {
      print('Error initializing disease predictor: $e');
      throw Exception('Failed to initialize disease predictor: $e');
    }
  }

  /// Clean symptom function - matches the training process
  String _cleanSymptom(String symptom) {
    return symptom.trim().replaceAll('_', ' ');
  }

  /// Get display symptoms (cleaned for UI)
  List<String> get displaySymptoms {
    if (!_isInitialized) return [];
    return _symptomClasses.map((s) => _cleanSymptom(s)).toList();
  }

  /// Check if service is ready
  bool get isInitialized => _isInitialized;

  Future<List<Map<String, dynamic>>> predict(List<String> selectedSymptoms) async {
    if (!_isInitialized) {
      throw Exception('Service not initialized. Call init() first.');
    }

    if (selectedSymptoms.isEmpty) {
      throw Exception('No symptoms provided for prediction');
    }

    try {
      // Clean the input symptoms to match training format
      final cleanedSymptoms = selectedSymptoms.map((s) => _cleanSymptom(s)).toList();

      // Create input vector
      final inputVector = List<double>.filled(_symptomClasses.length, 0.0);

      for (String symptom in cleanedSymptoms) {
        final index = _symptomClasses.indexWhere(
              (s) => _cleanSymptom(s).toLowerCase() == symptom.toLowerCase(),
        );
        if (index != -1) {
          inputVector[index] = 1.0;
        } else {
          print('Warning: Symptom "$symptom" not found in model vocabulary');
        }
      }

      // Prepare input and output tensors with correct shapes
      final inputTensor = [inputVector]; // shape: [1, num_features]
      final outputTensor = [List<double>.filled(_diseaseClasses.length, 0.0)];

      // Run inference
      _interpreter.run(inputTensor, outputTensor);

      final predictions = <Map<String, dynamic>>[];

      // Extract the prediction scores
      final outputList = outputTensor[0];

      final indexedScores = <MapEntry<int, double>>[];
      for (int i = 0; i < outputList.length; i++) {
        indexedScores.add(MapEntry(i, outputList[i]));
      }

      // Sort by confidence (descending)
      indexedScores.sort((a, b) => b.value.compareTo(a.value));

      for (int i = 0; i < 3 && i < indexedScores.length; i++) {
        final entry = indexedScores[i];
        final confidence = entry.value * 100;

        predictions.add({
          'disease': _diseaseClasses[entry.key],
          'confidence': confidence,
          'rank': i + 1,
        });
      }

      print('Prediction completed successfully');
      print('Input symptoms: $cleanedSymptoms');
      print('Top prediction: ${predictions.isNotEmpty ? predictions[0]['disease'] : 'None'}');

      return predictions;
    } catch (e) {
      print('Error during prediction: $e');
      throw Exception('Prediction failed: $e');
    }
  }


  /// Get symptom suggestions based on partial input
  List<String> getSuggestions(String query) {
    if (!_isInitialized || query.isEmpty) return [];

    final lowercaseQuery = query.toLowerCase();
    return displaySymptoms
        .where((symptom) => symptom.toLowerCase().contains(lowercaseQuery))
        .take(10)
        .toList();
  }

  /// Dispose resources
  void dispose() {
    if (_isInitialized) {
      _interpreter.close();
      _isInitialized = false;
    }
  }
}