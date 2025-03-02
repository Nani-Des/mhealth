import 'package:flutter/material.dart';
import 'package:flutter_tts/flutter_tts.dart';
import 'package:speech_to_text/speech_to_text.dart' as stt;
import 'package:dio/dio.dart';
import 'package:flutter_dotenv/flutter_dotenv.dart';
import 'package:showcaseview/showcaseview.dart';
import 'package:shared_preferences/shared_preferences.dart'; // Added for persistence

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
  String _responseText = "";

  final GlobalKey _micKey = GlobalKey();
  final GlobalKey _textFieldKey = GlobalKey();
  final GlobalKey _sendKey = GlobalKey();

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

    // Trigger showcase only once using SharedPreferences
    WidgetsBinding.instance.addPostFrameCallback((_) async {
      final prefs = await SharedPreferences.getInstance();
      await prefs.remove('hasSeenEmergencyWalkthrough');
      final bool hasSeenWalkthrough = prefs.getBool('hasSeenEmergencyWalkthrough') ?? false;
      if (!hasSeenWalkthrough && mounted) {
        ShowCaseWidget.of(context)?.startShowCase([_micKey, _textFieldKey, _sendKey]);
        await prefs.setBool('hasSeenEmergencyWalkthrough', true);
      }
    });
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
    final String response = await _fetchFirstAidResponse(query);
    setState(() {
      _responseText = response;
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
          'messages': [
            {'role': 'user', 'content': query},
          ],
        },
      );
      return response.data['choices'][0]['message']['content'];
    } catch (e) {
      return "Sorry, I couldn't fetch the response. Please try again.";
    }
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
        title: const Row(
          children: [
            Icon(Icons.emergency, color: Colors.white),
            SizedBox(width: 8),
            Text(
              "Emergency Assistance",
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
              onPressed: () => _fetchAndShowResponse(_messageController.text),
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