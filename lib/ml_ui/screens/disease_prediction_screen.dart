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
    await _predictorService.init();
    if (mounted) {
      setState(() {
        _suggestions = _predictorService.displaySymptoms;
      });
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

      // Run prediction in a separate isolate/compute function
      // This prevents UI blocking
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
        setState(() => _isLoading = false);
      }
    } finally {
      _predictionCompleter = null;
    }
  }

  void _runPredictionAsync() {
    // Use Timer.periodic to break up the computation and allow UI updates
    Timer(const Duration(milliseconds: 50), () async {
      try {
        if (_isCancelling || _predictionCompleter == null) {
          _predictionCompleter?.completeError(CancellationException());
          return;
        }

        // Run the actual prediction
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

  @override
  Widget build(BuildContext context) {
    print('Build called - isLoading: $_isLoading, isCancelling: $_isCancelling');

    return Scaffold(
      resizeToAvoidBottomInset: false,
      appBar: AppBar(
        title: const Text('Disease Predictor'),
        backgroundColor: Colors.teal[700],
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
                    'Note: This detection tool is AI-based and should not replace professional medical diagnosis. For serious concerns, consult a health expert.',
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
                    'Note: This detection tool is AI-based and should not replace professional medical diagnosis. For serious concerns, consult a health expert.',
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
                                      foregroundColor: Colors.black,
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

                      if (_showResults && _predictions.isNotEmpty) ...[
                        const SizedBox(height: 24),
                        const Text(
                          'Prediction Results',
                          style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
                        ),
                        const SizedBox(height: 16),
                        ..._predictions.map((p) {
                          final confidence = _parseConfidence(p['confidence']);
                          return Card(
                            margin: const EdgeInsets.only(bottom: 12),
                            child: ListTile(
                              title: Text(p['disease']?.toString() ?? 'Unknown'),
                              trailing: Container(
                                width: 50,
                                height: 50,
                                decoration: BoxDecoration(
                                  color: _getConfidenceColor(confidence),
                                  shape: BoxShape.circle,
                                ),
                                child: Center(
                                  child: Text(
                                    '${confidence.toStringAsFixed(0)}%',
                                    style: const TextStyle(
                                      color: Colors.white,
                                      fontWeight: FontWeight.bold,
                                    ),
                                  ),
                                ),
                              ),
                            ),
                          );
                        }),
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
                  : 'This may take a few moments',
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

  Color _getConfidenceColor(double confidence) {
    if (confidence > 75) return Colors.green;
    if (confidence > 50) return Colors.orange;
    return Colors.red;
  }

  @override
  void dispose() {
    _predictionSubscription?.cancel();
    _marqueeController.dispose();
    _symptomFocusNode.dispose();
    _symptomController.dispose();
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