import 'dart:convert';
import 'dart:io';
import 'package:flutter/services.dart' show rootBundle;
import 'package:nhap/data/models/disease_predictor_model.dart';
 // Adjust if path differs

class DiseasePredictorService {
  late List<String> _symptomList;
  late List<String> _labelClasses;

  Future<void> init() async {
    _symptomList = List<String>.from(
      json.decode(await rootBundle.loadString('assets/symptoms.json')),
    );

    _labelClasses = List<String>.from(
      json.decode(await rootBundle.loadString('assets/label_classes.json')),
    );
  }

  List<String> get displaySymptoms =>
      _symptomList.map((s) => s.replaceAll('_', ' ')).toList();

  Future<List<Map<String, dynamic>>> predict(List<String> selectedSymptoms) async {
    // Convert user input to underscore version
    final inputVector = List<double>.filled(_symptomList.length, 0.0);
    for (var symptom in selectedSymptoms) {
      final index = _symptomList.indexOf(symptom.replaceAll(' ', '_'));
      if (index != -1) inputVector[index] = 1.0;
    }

    final scores = score(inputVector).cast<double>();
    final indexed = List.generate(scores.length, (i) => MapEntry(i, scores[i]));
    indexed.sort((a, b) => b.value.compareTo(a.value));

    return indexed.take(3).map((entry) {
      return {
        'disease': _labelClasses[entry.key],
        'confidence': (entry.value * 100).toStringAsFixed(2),
      };
    }).toList();
  }
}
