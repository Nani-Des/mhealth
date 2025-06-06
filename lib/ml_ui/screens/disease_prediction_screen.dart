import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:lottie/lottie.dart';
import 'dart:async';
import '../../core/services/disease_predictor_service.dart';

class DiseasePredictionScreen extends StatefulWidget {
  const DiseasePredictionScreen({Key? key}) : super(key: key);

  @override
  State<DiseasePredictionScreen> createState() => _DiseasePredictionScreenState();
}

class _DiseasePredictionScreenState extends State<DiseasePredictionScreen> {
  late var _symptomController = TextEditingController();
  final List<String> _selectedSymptoms = [];
  List<Map<String, dynamic>> _predictions = [];
  List<String> _suggestions = [];
  bool _isLoading = false;
  bool _showResults = false;
  bool _isCancelling = false;

  final DiseasePredictorService _predictorService = DiseasePredictorService();
  final FocusNode _symptomFocusNode = FocusNode();
  final ScrollController _marqueeController = ScrollController();

  // Add a Completer to handle cancellation
  Completer<List<Map<String, dynamic>>>? _predictionCompleter;
  StreamSubscription? _predictionSubscription;

  @override
  void initState() {
    super.initState();
    _loadSymptoms();
    WidgetsBinding.instance.addPostFrameCallback((_) => _startMarquee());
  }

  void _startMarquee() {
    if (_marqueeController.hasClients) {
      final double maxScroll = _marqueeController.position.maxScrollExtent;
      const duration = Duration(seconds: 15);

      _marqueeController.animateTo(
        maxScroll,
        duration: duration,
        curve: Curves.linear,
      ).then((_) {
        if (mounted) {
          _marqueeController.jumpTo(0);
          _startMarquee();
        }
      });
    }
  }

  Future<void> _loadSymptoms() async {
    try {
      await _predictorService.init();
      if (mounted) {
        setState(() {
          _suggestions = _predictorService.displaySymptoms;
        });
      }
    } catch (e) {
      print('Error loading symptoms: $e');
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Failed to load symptoms: ${e.toString()}'),
            backgroundColor: Colors.red,
          ),
        );
      }
    }
  }

  void _addSymptom(String symptom) {
    if (symptom.isNotEmpty && !_selectedSymptoms.contains(symptom)) {
      setState(() {
        _selectedSymptoms.add(symptom);
        _predictions = [];
        _symptomController.clear();
        _showResults = false;
      });
    }
  }

  Future<void> _predictDisease() async {
    print('_predictDisease called');

    if (_selectedSymptoms.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Please select at least one symptom'),
          backgroundColor: Colors.orange,
        ),
      );
      return;
    }

    // Dismiss keyboard
    FocusScope.of(context).unfocus();
    FocusManager.instance.primaryFocus?.unfocus();
    SystemChannels.textInput.invokeMethod('TextInput.hide');

    // Wait for keyboard to dismiss
    await _waitForKeyboardDismissal();

    // Set loading state
    setState(() {
      _isLoading = true;
      _isCancelling = false;
      _showResults = false;
      _predictions = [];
    });

    // Small delay to ensure loading UI renders
    await Future.delayed(const Duration(milliseconds: 100));

    try {
      // Create a completer for cancellation support
      _predictionCompleter = Completer<List<Map<String, dynamic>>>();

      // Run prediction
      _runPredictionAsync();

      // Wait for either completion or cancellation
      final predictions = await _predictionCompleter!.future;

      if (mounted && !_isCancelling) {
        setState(() {
          _predictions = predictions;
          _isLoading = false;
          _showResults = true;
        });
      }
    } on CancellationException {
      print('Prediction was cancelled');
      if (mounted) {
        setState(() {
          _isLoading = false;
          _isCancelling = false;
        });
      }
    } catch (e) {
      print('Prediction error: $e');
      if (mounted && !_isCancelling) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Prediction failed: ${e.toString()}'),
            backgroundColor: Colors.red,
          ),
        );
        setState(() {
          _isLoading = false;
          _isCancelling = false;
        });
      }
    } finally {
      _predictionCompleter = null;
    }
  }

  void _runPredictionAsync() {
    Timer(const Duration(milliseconds: 50), () async {
      try {
        if (_isCancelling || _predictionCompleter == null) {
          _predictionCompleter?.completeError(CancellationException());
          return;
        }

        // Validate that we have symptoms selected
        if (_selectedSymptoms.isEmpty) {
          _predictionCompleter?.completeError(
              Exception('No symptoms selected for prediction')
          );
          return;
        }

        // Run the actual prediction with timeout
        final predictions = await _predictorService.predict(_selectedSymptoms)
            .timeout(const Duration(seconds: 30), onTimeout: () {
          if (mounted && !_isCancelling) {
            ScaffoldMessenger.of(context).showSnackBar(
              const SnackBar(
                content: Text('Prediction took too long. Please try again.'),
                backgroundColor: Colors.orange,
              ),
            );
          }
          return <Map<String, dynamic>>[];
        });

        if (!_isCancelling && _predictionCompleter != null && !_predictionCompleter!.isCompleted) {
          _predictionCompleter!.complete(predictions);
        }
      } catch (e) {
        print('Prediction async error: $e');
        if (!_isCancelling && _predictionCompleter != null && !_predictionCompleter!.isCompleted) {
          _predictionCompleter!.completeError(e);
        }
      }
    });
  }

  Future<void> _waitForKeyboardDismissal() async {
    double initialInset = MediaQuery.of(context).viewInsets.bottom;
    int attempts = 0;

    while (attempts < 20) {
      await Future.delayed(const Duration(milliseconds: 50));
      double currentInset = MediaQuery.of(context).viewInsets.bottom;

      if (currentInset <= 0) {
        break;
      }
      attempts++;
    }

    await Future.delayed(const Duration(milliseconds: 200));
  }

  void _cancelPrediction() {
    print('Cancel prediction called');
    setState(() {
      _isCancelling = true;
    });

    // Complete the completer with cancellation
    if (_predictionCompleter != null && !_predictionCompleter!.isCompleted) {
      _predictionCompleter!.completeError(CancellationException());
    }

    // Use a short delay to ensure the cancellation is processed
    Timer(const Duration(milliseconds: 100), () {
      if (mounted) {
        setState(() {
          _isLoading = false;
          _isCancelling = false;
        });
      }
    });
  }

  double _parseConfidence(dynamic confidence) {
    if (confidence is double) return confidence;
    if (confidence is int) return confidence.toDouble();
    if (confidence is String) return double.tryParse(confidence) ?? 0.0;
    return 0.0;
  }

  Color _getRankColor(int rank) {
    switch (rank) {
      case 1:
        return Colors.amber[600]!; // Gold for 1st place
      case 2:
        return Colors.grey[600]!; // Silver for 2nd place
      case 3:
        return Colors.brown[400]!; // Bronze for 3rd place
      default:
        return Colors.teal[600]!;
    }
  }

  Color _getConfidenceColor(double confidence) {
    if (confidence > 75) return Colors.green[600]!;
    if (confidence > 50) return Colors.orange[600]!;
    return Colors.red[600]!;
  }

  @override
  Widget build(BuildContext context) {
    print('Build called - isLoading: $_isLoading, isCancelling: $_isCancelling');

    return Scaffold(
      resizeToAvoidBottomInset: false,
      appBar: AppBar(
        title: const Text('Disease Predictor'),
        backgroundColor: Colors.teal[700],
        foregroundColor: Colors.white,
      ),
      body: Column(
        children: [
          // Scrolling warning banner
          Container(
            height: 30,
            color: Colors.orange[100],
            child: SingleChildScrollView(
              controller: _marqueeController,
              scrollDirection: Axis.horizontal,
              physics: const NeverScrollableScrollPhysics(),
              child: Row(
                children: [
                  const SizedBox(width: 20),
                  const Icon(Icons.warning_amber, size: 18, color: Colors.orange),
                  const SizedBox(width: 8),
                  const Text(
                    'Note: This AI-powered tool should not replace professional medical diagnosis. For serious concerns, consult a health expert.',
                    style: TextStyle(
                      fontSize: 14,
                      color: Colors.orange,
                      fontWeight: FontWeight.w500,
                    ),
                  ),
                  const SizedBox(width: 20),
                  const Icon(Icons.warning_amber, size: 18, color: Colors.orange),
                  const SizedBox(width: 8),
                  const Text(
                    'Note: This AI-powered tool should not replace professional medical diagnosis. For serious concerns, consult a health expert.',
                    style: TextStyle(
                      fontSize: 14,
                      color: Colors.orange,
                      fontWeight: FontWeight.w500,
                    ),
                  ),
                  const SizedBox(width: 20),
                ],
              ),
            ),
          ),
          Expanded(
            child: Stack(
              children: [
                SingleChildScrollView(
                  padding: const EdgeInsets.all(16),
                  child: Column(
                    children: [
                      if (_selectedSymptoms.isEmpty && !_isLoading && _predictions.isEmpty)
                        _buildWelcomeCard(),

                      // Disable input controls while loading
                      IgnorePointer(
                        ignoring: _isLoading,
                        child: Opacity(
                          opacity: _isLoading ? 0.5 : 1.0,
                          child: Column(
                            children: [
                              Autocomplete<String>(
                                optionsBuilder: (TextEditingValue textEditingValue) {
                                  if (textEditingValue.text.isEmpty) {
                                    return const Iterable<String>.empty();
                                  }
                                  return _suggestions.where((s) =>
                                      s.toLowerCase().contains(textEditingValue.text.toLowerCase()));
                                },
                                onSelected: _addSymptom,
                                optionsViewBuilder: (context, onSelected, options) {
                                  return Align(
                                    alignment: Alignment.topLeft,
                                    child: Material(
                                      elevation: 4,
                                      child: ConstrainedBox(
                                        constraints: const BoxConstraints(maxHeight: 200),
                                        child: ListView.builder(
                                          padding: EdgeInsets.zero,
                                          itemCount: options.length,
                                          itemBuilder: (context, index) {
                                            final option = options.elementAt(index);
                                            return ListTile(
                                              title: Text(option),
                                              onTap: () => onSelected(option),
                                            );
                                          },
                                        ),
                                      ),
                                    ),
                                  );
                                },
                                fieldViewBuilder: (context, textEditingController, focusNode, onFieldSubmitted) {
                                  _symptomController = textEditingController;
                                  return TextField(
                                    controller: textEditingController,
                                    focusNode: focusNode,
                                    decoration: InputDecoration(
                                      labelText: 'Enter Symptom',
                                      border: const OutlineInputBorder(),
                                      suffixIcon: _isLoading && !_isCancelling
                                          ? const Padding(
                                        padding: EdgeInsets.all(10),
                                        child: CircularProgressIndicator(strokeWidth: 2),
                                      )
                                          : null,
                                    ),
                                    onSubmitted: (value) {
                                      if (_suggestions.contains(value)) {
                                        _addSymptom(value);
                                      }
                                    },
                                  );
                                },
                              ),
                              const SizedBox(height: 16),
                              if (_selectedSymptoms.isNotEmpty) ...[
                                const Align(
                                  alignment: Alignment.centerLeft,
                                  child: Padding(
                                    padding: EdgeInsets.only(bottom: 8),
                                    child: Text(
                                      'Selected Symptoms:',
                                      style: TextStyle(
                                        fontSize: 16,
                                        fontWeight: FontWeight.bold,
                                        color: Colors.teal,
                                      ),
                                    ),
                                  ),
                                ),
                              ],
                              if (_selectedSymptoms.isNotEmpty) ...[
                                Wrap(
                                  spacing: 8,
                                  runSpacing: 8,
                                  children: _selectedSymptoms.map((symptom) => Chip(
                                    label: Text(symptom),
                                    deleteIcon: const Icon(Icons.close, size: 16),
                                    onDeleted: () => setState(() {
                                      _selectedSymptoms.remove(symptom);
                                      _showResults = false;
                                    }),
                                  )).toList(),
                                ),
                                const SizedBox(height: 16),
                                SizedBox(
                                  width: double.infinity,
                                  child: ElevatedButton(
                                    onPressed: _isLoading ? null : _predictDisease,
                                    style: ElevatedButton.styleFrom(
                                      backgroundColor: Colors.teal[700],
                                      foregroundColor: Colors.white,
                                      padding: const EdgeInsets.symmetric(vertical: 16),
                                    ),
                                    child: _isLoading
                                        ? const SizedBox(
                                      height: 20,
                                      width: 20,
                                      child: CircularProgressIndicator(
                                        strokeWidth: 2,
                                        valueColor: AlwaysStoppedAnimation<Color>(Colors.white),
                                      ),
                                    )
                                        : const Text(
                                      'Predict Disease',
                                      style: TextStyle(
                                        fontSize: 16,
                                        fontWeight: FontWeight.bold,
                                      ),
                                    ),
                                  ),
                                ),
                              ],
                            ],
                          ),
                        ),
                      ),

                      // Enhanced results display
                      if (_showResults && _predictions.isNotEmpty) ...[
                        const SizedBox(height: 24),
                        Container(
                          width: double.infinity,
                          padding: const EdgeInsets.all(16),
                          decoration: BoxDecoration(
                            gradient: LinearGradient(
                              colors: [Colors.teal[50]!, Colors.teal[100]!],
                              begin: Alignment.topLeft,
                              end: Alignment.bottomRight,
                            ),
                            borderRadius: BorderRadius.circular(12),
                            border: Border.all(color: Colors.teal[200]!),
                          ),
                          child: Column(
                            children: [
                              Row(
                                children: [
                                  Icon(Icons.analytics, color: Colors.teal[700], size: 24),
                                  const SizedBox(width: 8),
                                  Text(
                                    'Top 3 Possible Conditions',
                                    style: TextStyle(
                                      fontSize: 18,
                                      fontWeight: FontWeight.bold,
                                      color: Colors.teal[700],
                                    ),
                                  ),
                                ],
                              ),
                              const SizedBox(height: 4),
                              Text(
                                'Based on ${_selectedSymptoms.length} symptom${_selectedSymptoms.length > 1 ? 's' : ''}',
                                style: TextStyle(
                                  fontSize: 14,
                                  color: Colors.teal[600],
                                ),
                              ),
                            ],
                          ),
                        ),
                        const SizedBox(height: 16),
                        ..._predictions.asMap().entries.map((entry) {
                          final index = entry.key;
                          final prediction = entry.value;
                          final confidence = _parseConfidence(prediction['confidence']);
                          final rank = index + 1;

                          return Container(
                            margin: const EdgeInsets.only(bottom: 12),
                            child: Card(
                              elevation: 4,
                              shape: RoundedRectangleBorder(
                                borderRadius: BorderRadius.circular(16),
                                side: BorderSide(
                                  color: _getRankColor(rank).withOpacity(0.3),
                                  width: 2,
                                ),
                              ),
                              child: Container(
                                decoration: BoxDecoration(
                                  borderRadius: BorderRadius.circular(16),
                                  gradient: LinearGradient(
                                    colors: [
                                      _getRankColor(rank).withOpacity(0.05),
                                      _getRankColor(rank).withOpacity(0.02),
                                    ],
                                    begin: Alignment.topLeft,
                                    end: Alignment.bottomRight,
                                  ),
                                ),
                                child: Padding(
                                  padding: const EdgeInsets.all(16),
                                  child: Row(
                                    children: [
                                      // Rank badge
                                      Container(
                                        width: 40,
                                        height: 40,
                                        decoration: BoxDecoration(
                                          color: _getRankColor(rank),
                                          shape: BoxShape.circle,
                                          boxShadow: [
                                            BoxShadow(
                                              color: _getRankColor(rank).withOpacity(0.3),
                                              blurRadius: 8,
                                              offset: const Offset(0, 2),
                                            ),
                                          ],
                                        ),
                                        child: Center(
                                          child: Text(
                                            '$rank',
                                            style: const TextStyle(
                                              color: Colors.white,
                                              fontWeight: FontWeight.bold,
                                              fontSize: 18,
                                            ),
                                          ),
                                        ),
                                      ),
                                      const SizedBox(width: 16),
                                      // Disease info
                                      Expanded(
                                        child: Column(
                                          crossAxisAlignment: CrossAxisAlignment.start,
                                          children: [
                                            Text(
                                              prediction['disease']?.toString() ?? 'Unknown',
                                              style: const TextStyle(
                                                fontSize: 16,
                                                fontWeight: FontWeight.bold,
                                                color: Colors.black87,
                                              ),
                                            ),
                                            const SizedBox(height: 4),
                                            Row(
                                              children: [
                                                Icon(
                                                  Icons.trending_up,
                                                  size: 14,
                                                  color: Colors.grey[600],
                                                ),
                                                const SizedBox(width: 4),
                                                Text(
                                                  'Confidence: ${confidence.toStringAsFixed(1)}%',
                                                  style: TextStyle(
                                                    fontSize: 12,
                                                    color: Colors.grey[600],
                                                  ),
                                                ),
                                              ],
                                            ),
                                          ],
                                        ),
                                      ),
                                      // Confidence indicator
                                      Container(
                                        width: 60,
                                        height: 60,
                                        child: Stack(
                                          alignment: Alignment.center,
                                          children: [
                                            SizedBox(
                                              width: 50,
                                              height: 50,
                                              child: CircularProgressIndicator(
                                                value: confidence / 100,
                                                strokeWidth: 4,
                                                backgroundColor: Colors.grey[300],
                                                valueColor: AlwaysStoppedAnimation<Color>(
                                                  _getConfidenceColor(confidence),
                                                ),
                                              ),
                                            ),
                                            Text(
                                              '${confidence.toStringAsFixed(0)}%',
                                              style: TextStyle(
                                                fontSize: 12,
                                                fontWeight: FontWeight.bold,
                                                color: _getConfidenceColor(confidence),
                                              ),
                                            ),
                                          ],
                                        ),
                                      ),
                                    ],
                                  ),
                                ),
                              ),
                            ),
                          );
                        }),
                        const SizedBox(height: 16),
                        // Disclaimer card
                        Card(
                          color: Colors.amber[50],
                          child: Padding(
                            padding: const EdgeInsets.all(12),
                            child: Row(
                              children: [
                                Icon(Icons.info_outline, color: Colors.amber[800], size: 20),
                                const SizedBox(width: 8),
                                Expanded(
                                  child: Text(
                                    'These are AI predictions based on symptoms. Please consult a healthcare professional for proper diagnosis.',
                                    style: TextStyle(
                                      fontSize: 12,
                                      color: Colors.amber[800],
                                    ),
                                  ),
                                ),
                              ],
                            ),
                          ),
                        ),
                      ],
                    ],
                  ),
                ),

                // Full screen loading overlay
                if (_isLoading)
                  Positioned.fill(
                    child: Material(
                      color: Colors.black.withOpacity(0.8),
                      child: Container(
                        width: double.infinity,
                        height: double.infinity,
                        child: Center(
                          child: _buildLoadingIndicator(),
                        ),
                      ),
                    ),
                  ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildLoadingIndicator() {
    return Card(
      elevation: 8,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(16),
      ),
      child: Container(
        padding: const EdgeInsets.all(32),
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(16),
        ),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            SizedBox(
              width: 120,
              height: 120,
              child: Lottie.asset(
                'assets/animations/medical_loading.json',
                width: 120,
                height: 120,
                fit: BoxFit.contain,
                errorBuilder: (context, error, stackTrace) {
                  return Container(
                    width: 120,
                    height: 120,
                    decoration: BoxDecoration(
                      color: Colors.teal[100],
                      shape: BoxShape.circle,
                    ),
                    child: const Center(
                      child: CircularProgressIndicator(
                        strokeWidth: 4,
                        valueColor: AlwaysStoppedAnimation<Color>(Colors.teal),
                      ),
                    ),
                  );
                },
              ),
            ),
            const SizedBox(height: 24),
            Text(
              _isCancelling
                  ? 'Cancelling prediction...'
                  : 'Analyzing ${_selectedSymptoms.length} symptom${_selectedSymptoms.length > 1 ? 's' : ''}...',
              style: TextStyle(
                fontSize: 18,
                color: Colors.teal[700],
                fontWeight: FontWeight.bold,
              ),
              textAlign: TextAlign.center,
            ),
            const SizedBox(height: 12),
            Text(
              _isCancelling
                  ? 'Please wait...'
                  : 'AI is processing your symptoms',
              style: const TextStyle(
                fontSize: 14,
                color: Colors.grey,
              ),
              textAlign: TextAlign.center,
            ),
            const SizedBox(height: 24),
            SizedBox(
              width: 200,
              child: LinearProgressIndicator(
                backgroundColor: Colors.grey[300],
                valueColor: AlwaysStoppedAnimation<Color>(
                    _isCancelling ? Colors.red : Colors.teal[700]!
                ),
                minHeight: 6,
              ),
            ),
            const SizedBox(height: 24),
            if (!_isCancelling)
              OutlinedButton(
                onPressed: _cancelPrediction,
                style: OutlinedButton.styleFrom(
                  foregroundColor: Colors.red,
                  side: const BorderSide(color: Colors.red),
                  padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 12),
                ),
                child: const Text(
                  'Cancel Prediction',
                  style: TextStyle(fontWeight: FontWeight.bold),
                ),
              ),
          ],
        ),
      ),
    );
  }

  Widget _buildWelcomeCard() {
    return Card(
      elevation: 4,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(12),
      ),
      margin: const EdgeInsets.only(bottom: 24),
      child: Padding(
        padding: const EdgeInsets.all(20),
        child: Column(
          children: [
            Icon(
              Icons.medical_services,
              size: 64,
              color: Colors.teal[700],
            ),
            const SizedBox(height: 16),
            const Text(
              'AI-Powered Disease Prediction',
              style: TextStyle(
                fontSize: 20,
                fontWeight: FontWeight.bold,
              ),
              textAlign: TextAlign.center,
            ),
            const SizedBox(height: 8),
            Text(
              'Start by searching for symptoms you are experiencing. Our AI will analyze patterns to suggest possible conditions.',
              style: TextStyle(
                fontSize: 16,
                color: Colors.grey[600],
              ),
              textAlign: TextAlign.center,
            ),
            const SizedBox(height: 16),
            Wrap(
              spacing: 8,
              runSpacing: 8,
              children: [
                _buildQuickSymptomChip('Fever'),
                _buildQuickSymptomChip('Headache'),
                _buildQuickSymptomChip('Cough'),
                _buildQuickSymptomChip('Fatigue'),
                _buildQuickSymptomChip('Nausea'),
              ],
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildQuickSymptomChip(String symptom) {
    return ActionChip(
      label: Text(symptom),
      backgroundColor: Colors.teal[50],
      labelStyle: TextStyle(color: Colors.teal[700]),
      onPressed: () => _addSymptom(symptom),
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(20),
      ),
    );
  }

  @override
  void dispose() {
    _predictionSubscription?.cancel();
    _marqueeController.dispose();
    _symptomFocusNode.dispose();
    _symptomController.dispose();
    _predictorService.dispose();
    super.dispose();
  }
}

// Custom exception for cancellation
class CancellationException implements Exception {
  final String message;
  CancellationException([this.message = 'Operation was cancelled']);

  @override
  String toString() => 'CancellationException: $message';
}