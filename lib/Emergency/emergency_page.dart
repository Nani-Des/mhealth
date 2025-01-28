import 'package:flutter/material.dart';
import 'package:flutter_tts/flutter_tts.dart';
import 'package:speech_to_text/speech_to_text.dart' as stt;
import 'package:dio/dio.dart';

import 'Widgets/emergency_hompage_content.dart';

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
  String _responseText = ""; // To store AI-generated first aid response

  @override
  void initState() {
    super.initState();
    _speechToText = stt.SpeechToText();
    _controller = AnimationController(
      duration: const Duration(milliseconds: 300),
      vsync: this,
    );
    _offsetAnimation = Tween<Offset>(
      begin: Offset(0.0, 0.95),
      end: Offset(0.0, 0.0),
    ).animate(CurvedAnimation(
      parent: _controller,
      curve: Curves.easeInOut,
    ));
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
    }
  }

  Future<void> _stopListening() async {
    setState(() => _isListening = false);
    _speechToText.stop();
  }

  Future<void> _fetchAndShowResponse(String query) async {
    final String response = await _fetchFirstAidResponse(query);
    setState(() {
      _responseText = response; // Update UI with the response
      _toggleResponsePopup();
    });
    await _flutterTts.speak(response);
  }

  Future<String> _fetchFirstAidResponse(String query) async {
    try {
      const apiKey = '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';
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
      // Extract the content from the response structure
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
        title: Text("Emergency Assistance"),
      ),
      body: Stack(
        children: [
          EmergencyHomePageContent(),
          Padding(
            padding: const EdgeInsets.all(16.0),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                if (_showResponsePopup)
                  SizedBox.shrink(), // Placeholder for hidden content when popup is visible
              ],
            ),
          ),
          SlideTransition(
            position: _offsetAnimation,
            child: Container(
              color: Colors.white,
              child: Column(
                children: [
                  Padding(
                    padding: const EdgeInsets.all(8.0),
                    child: Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        Text(
                          "First Aid Instructions",
                          style: TextStyle(fontWeight: FontWeight.bold, fontSize: 16),
                        ),
                        IconButton(
                          icon: Icon(Icons.unfold_more),
                          onPressed: _toggleResponsePopup,
                        ),
                      ],
                    ),
                  ),
                  Expanded(
                    child: SingleChildScrollView(
                      padding: const EdgeInsets.all(8.0),
                      child: Text(
                        _responseText,
                        style: TextStyle(fontSize: 14),
                      ),
                    ),
                  ),
                ],
              ),
            ),
          ),
        ],
      ),
      bottomNavigationBar: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 8.0, vertical: 8.0),
        child: Row(
          children: [
            Expanded(
              child: TextField(
                controller: _messageController,
                decoration: InputDecoration(
                  labelText: "Describe the emergency",
                  border: OutlineInputBorder(),
                ),
              ),
            ),
            SizedBox(width: 8),
            IconButton(
              icon: Icon(_isListening ? Icons.mic : Icons.mic_none),
              onPressed: _isListening ? _stopListening : _startListening,
            ),
            IconButton(
              icon: Icon(Icons.send),
              onPressed: () => _fetchAndShowResponse(_messageController.text),
            ),
          ],
        ),
      ),
    );
  }
}