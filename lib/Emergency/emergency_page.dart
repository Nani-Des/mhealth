import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart' show rootBundle;
import 'package:flutter_tts/flutter_tts.dart';
import 'package:speech_to_text/speech_to_text.dart' as stt;
import 'package:dio/dio.dart';
import 'package:flutter_dotenv/flutter_dotenv.dart';
import 'package:showcaseview/showcaseview.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:string_similarity/string_similarity.dart';
import 'package:hive/hive.dart';
import 'package:connectivity_plus/connectivity_plus.dart';

import 'Widgets/article_detail_page.dart';
import 'Widgets/emergency_hompage_content.dart';
import 'Widgets/first_aid_response_widget1.dart';

class EmergencyPage extends StatefulWidget {
  @override
  _EmergencyPageState createState() => _EmergencyPageState();
}

class _EmergencyPageState extends State<EmergencyPage> with SingleTickerProviderStateMixin {
  final TextEditingController _messageController = TextEditingController();
  final FlutterTts _flutterTts = FlutterTts();
  late stt.SpeechToText _speechToText;
  late AnimationController _controller;
  late Animation<Offset> _offsetAnimation;

  bool _isListening = false;
  bool _showResponsePopup = false;
  bool _isOffline = false;
  bool _isLoading = false; // Loading state for progress indicator
  String _responseText = "";

  final GlobalKey _micKey = GlobalKey();
  final GlobalKey _textFieldKey = GlobalKey();
  final GlobalKey _sendKey = GlobalKey();

  Map<String, dynamic>? _emergencyData;
  late Box _translationBox;

  @override
  void initState() {
    super.initState();
    _speechToText = stt.SpeechToText();
    _controller = AnimationController(
      duration: const Duration(milliseconds: 400),
      vsync: this,
    );
    _offsetAnimation = Tween<Offset>(
      begin: const Offset(0.0, 1.0),
      end: const Offset(0.0, 0.0),
    ).animate(CurvedAnimation(parent: _controller, curve: Curves.easeInOutBack));

    _translationBox = Hive.box('translations');
    _loadEmergencyData();
    _checkConnectivity();

    WidgetsBinding.instance.addPostFrameCallback((_) async {
      final prefs = await SharedPreferences.getInstance();
      final bool hasSeenWalkthrough = prefs.getBool('hasSeenEmergencyWalkthrough') ?? false;
      if (!hasSeenWalkthrough && mounted) {
        ShowCaseWidget.of(context)?.startShowCase([_micKey, _textFieldKey, _sendKey]);
        await prefs.setBool('hasSeenEmergencyWalkthrough', true);
      }
    });
  }

  Future<void> _loadEmergencyData() async {
    try {
      final String response = await rootBundle.loadString('assets/emergency_procedures.json');
      setState(() {
        _emergencyData = json.decode(response);
      });
    } catch (e) {
      print('Error loading emergency data: $e');
    }
  }

  Future<void> _checkConnectivity() async {
    var connectivityResult = await (Connectivity().checkConnectivity());
    setState(() {
      _isOffline = connectivityResult == ConnectivityResult.none;
    });
    if (_isOffline) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Offline Mode: Limited functionality available'),
          backgroundColor: Colors.orange,
        ),
      );
    }
  }

  @override
  void dispose() {
    _messageController.dispose();
    _flutterTts.stop();
    _controller.dispose();
    super.dispose();
  }

  Future<void> _startListening() async {
    bool available = await _speechToText.initialize();
    if (available) {
      setState(() => _isListening = true);
      _speechToText.listen(onResult: (result) {
        setState(() {
          _messageController.text = result.recognizedWords;
        });
      });
    } else {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Speech recognition not available')),
      );
    }
  }

  Future<void> _stopListening() async {
    setState(() => _isListening = false);
    _speechToText.stop();
  }

  Future<void> _fetchAndShowResponse(String query) async {
    if (query.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Please describe the emergency')),
      );
      return;
    }

    setState(() {
      _isLoading = true; // Show progress indicator
    });

    String response;
    if (_isOffline) {
      response = _findClosestMatch(query);
    } else {
      // Check cached translation first
      String? cachedResponse = _translationBox.get(query);
      if (cachedResponse != null) {
        response = cachedResponse;
      } else {
        response = await _fetchFirstAidResponse(query);
        if (!response.startsWith("Sorry,")) {
          await _translationBox.put(query, response); // Cache successful response
        }
      }
    }

    if (response.startsWith("Sorry,")) {
      response = _findClosestMatch(query);
    }

    setState(() {
      _responseText = response;
      _isLoading = false; // Hide progress indicator
      _toggleResponsePopup();
    });
    await _flutterTts.speak(response);
  }

  Future<String> _fetchFirstAidResponse(String query) async {
    try {
      final String apiKey = dotenv.env['OPENAI_API_KEY'] ?? '';
      if (apiKey.isEmpty) {
        return "API key is missing. Please check the environment variables.";
      }

      final response = await Dio().post(
        'https://api.openai.com/v1/chat/completions',
        options: Options(headers: {'Authorization': 'Bearer $apiKey'}),
        data: {
          'model': 'gpt-4o-mini',
          'messages': [{'role': 'user', 'content': query}],
        },
      );
      return response.data['choices'][0]['message']['content'];
    } catch (e) {
      return "Sorry, I couldn't fetch the response.";
    }
  }

  String _findClosestMatch(String query) {
    if (_emergencyData == null || _emergencyData!['articles'] == null) {
      return "No emergency procedures available offline.";
    }

    final articles = _emergencyData!['articles'] as List<dynamic>;
    if (articles.isEmpty) {
      return "No emergency procedures available offline.";
    }

    String bestMatchTitle = "";
    String bestMatchContent = "";
    double highestSimilarity = 0.0;

    for (var article in articles) {
      final String title = article['title'].toString().toLowerCase();
      final double similarity = query.toLowerCase().similarityTo(title);

      if (similarity > highestSimilarity) {
        highestSimilarity = similarity;
        bestMatchTitle = article['title'];
        bestMatchContent = article['content'];
      }
    }

    if (highestSimilarity < 0.3) {
      return "I couldn't find a specific match for '$query'. Please try describing the emergency differently.";
    }

    Navigator.push(
      context,
      MaterialPageRoute(
        builder: (context) => ArticleDetailPage(
          title: bestMatchTitle,
          content: bestMatchContent,
        ),
      ),
    );

    return bestMatchContent;
  }

  void _toggleResponsePopup() {
    setState(() {
      _showResponsePopup = !_showResponsePopup;
      _showResponsePopup ? _controller.forward() : _controller.reverse();
    });
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        elevation: 0,
        backgroundColor: Colors.redAccent,
        title: Row(
          children: [
            Icon(Icons.emergency, color: Colors.white),
            SizedBox(width: 8),
            Text(
              "Emergency Assistance${_isOffline ? ' (Offline)' : ''}",
              style: TextStyle(
                fontWeight: FontWeight.bold,
                color: Colors.white,
              ),
            ),
          ],
        ),
        flexibleSpace: Container(
          decoration: BoxDecoration(
            gradient: LinearGradient(
              begin: Alignment.topLeft,
              end: Alignment.bottomRight,
              colors: [Colors.redAccent, Colors.redAccent.shade700],
            ),
          ),
        ),
      ),
      body: Container(
        decoration: BoxDecoration(
          gradient: LinearGradient(
            begin: Alignment.topCenter,
            end: Alignment.bottomCenter,
            colors: [Colors.redAccent.withOpacity(0.1), Colors.white],
          ),
        ),
        child: Stack(
          children: [
            EmergencyHomePageContent(),
            Positioned(
              left: 0,
              right: 0,
              bottom: 0,
              child: _buildInputArea(),
            ),
            if (_showResponsePopup)
              SlideTransition(
                position: _offsetAnimation,
                child: Padding(
                  padding: const EdgeInsets.all(16.0),
                  child: FirstAidResponseWidget1(
                    responseText: _responseText,
                    onClose: _toggleResponsePopup,
                  ),
                ),
              ),
            if (_isLoading) // Progress indicator
              Center(
                child: CircularProgressIndicator(
                  valueColor: AlwaysStoppedAnimation<Color>(Colors.teal),
                ),
              ),
          ],
        ),
      ),
    );
  }

  Widget _buildInputArea() {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: const BorderRadius.vertical(top: Radius.circular(30)),
        boxShadow: [
          BoxShadow(
            color: Colors.grey.withOpacity(0.2),
            spreadRadius: 2,
            blurRadius: 10,
            offset: const Offset(0, -2),
          ),
        ],
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.end,
        children: [
          Expanded(
            child: Showcase(
              key: _textFieldKey,
              description: 'Type your emergency query here.',
              child: TextField(
                controller: _messageController,
                maxLines: null,
                decoration: InputDecoration(
                  hintText: "Describe the emergency...",
                  filled: true,
                  fillColor: Colors.grey[100],
                  border: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(20),
                    borderSide: BorderSide.none,
                  ),
                  contentPadding: const EdgeInsets.symmetric(horizontal: 20, vertical: 16),
                  suffixIcon: Showcase(
                    key: _micKey,
                    description: 'Tap to use voice input for your emergency.',
                    child: IconButton(
                      icon: AnimatedSwitcher(
                        duration: const Duration(milliseconds: 200),
                        child: Icon(
                          _isListening ? Icons.mic : Icons.mic_none,
                          key: ValueKey(_isListening),
                          color: Colors.redAccent,
                        ),
                      ),
                      onPressed: _isListening ? _stopListening : _startListening,
                    ),
                  ),
                ),
              ),
            ),
          ),
          const SizedBox(width: 12),
          Showcase(
            key: _sendKey,
            description: 'Tap to submit your emergency query.',
            child: FloatingActionButton(
              onPressed: () {
                String query = _messageController.text;
                _messageController.clear(); // Clear input immediately
                _fetchAndShowResponse(query); // Fetch response
              },
              backgroundColor: Colors.redAccent,
              elevation: 2,
              child: const Icon(Icons.send, color: Colors.white),
            ),
          ),
        ],
      ),
    );
  }
}