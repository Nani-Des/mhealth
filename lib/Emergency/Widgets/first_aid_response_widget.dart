import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:http/http.dart' as http;
import 'package:flutter_tts/flutter_tts.dart';

class FirstAidResponseWidget extends StatefulWidget {
  final String responseText;
  final VoidCallback onClose;

  const FirstAidResponseWidget({
    Key? key,
    required this.responseText,
    required this.onClose,
  }) : super(key: key);

  @override
  _FirstAidResponseWidgetState createState() => _FirstAidResponseWidgetState();
}

class _FirstAidResponseWidgetState extends State<FirstAidResponseWidget> {
  String translatedText = "";
  String selectedLanguage = "en-tw"; // Default language
  bool isLoading = false;
  bool isSpeaking = false;
  late FlutterTts flutterTts;

  final Map<String, String> languageMap = {
    "Twi": "en-tw",
    "Ewe": "en-ew",
    "Ga": "en-ga",
  };

  @override
  void initState() {
    super.initState();
    flutterTts = FlutterTts();
  }

  String _sanitizeTextForTranslation(String text) {
    return text
        .replaceAll("\n", "\\n") // Escape new lines
        .replaceAllMapped(RegExp(r'^(#{1,})\s*(.*)', multiLine: true), (match) => match.group(2)!)
        .replaceAll("**", ""); // Remove ** markers
  }

  Future<void> translateText() async {
    setState(() => isLoading = true);
    final url = Uri.parse("https://translation-api.ghananlp.org/v1/translate");

    try {
      final response = await http.post(
        url,
        headers: {
          "Content-Type": "application/json",
          "Cache-Control": "no-cache",
          "Ocp-Apim-Subscription-Key": "8c310df9eaf6470391aaf83da367b1cd", // Replace with actual key
        },
        body: jsonEncode({"in": _sanitizeTextForTranslation(widget.responseText), "lang": selectedLanguage}),
      );

      final responseBody = response.body;
      if (response.statusCode == 200) {
        if (responseBody.startsWith("\"") && responseBody.endsWith("\"")) {
          setState(() => translatedText = responseBody.substring(1, responseBody.length - 1));
        } else {
          setState(() => translatedText = "Unexpected response format from server: ${responseBody}");
        }
      } else {
        setState(() => translatedText = "Translation request failed with status code: ${response.statusCode}\nResponse: ${responseBody}");
      }
    } catch (e) {
      setState(() => translatedText = "Error: ${e.toString()}");
    }

    setState(() => isLoading = false);
  }

  Future<void> _toggleSpeech() async {
    if (isSpeaking) {
      await flutterTts.stop();
    } else {
      await flutterTts.speak(translatedText.isNotEmpty ? translatedText : widget.responseText);
    }

    setState(() {
      isSpeaking = !isSpeaking;
    });
  }

  List<TextSpan> _formatResponseText(String text) {
    final RegExp headerPattern = RegExp(r'^(#{1,})\s*(.*)', multiLine: true);
    final List<TextSpan> spans = [];

    text.split("\n").forEach((line) {
      final headerMatch = headerPattern.firstMatch(line);
      if (headerMatch != null) {
        spans.add(TextSpan(
          text: "${headerMatch.group(2)}\n",
          style: TextStyle(fontWeight: FontWeight.bold, fontSize: 20),
        ));
        return;
      }

      line = line.replaceAll("**", ""); // Remove bold markers
      spans.add(TextSpan(text: "$line\n", style: TextStyle(fontSize: 16)));
    });

    return spans;
  }

  @override
  Widget build(BuildContext context) {
    return Container(
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.vertical(top: Radius.circular(16)),
        boxShadow: [BoxShadow(blurRadius: 5, color: Colors.black26)],
      ),
      padding: EdgeInsets.all(16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Text("First Aid", style: TextStyle(fontWeight: FontWeight.bold, fontSize: 18)),
              Row(
                children: [
                  DropdownButton<String>(
                    value: selectedLanguage,
                    items: languageMap.entries.map((entry) {
                      return DropdownMenuItem<String>(
                        value: entry.value,
                        child: Text(entry.key),
                      );
                    }).toList(),
                    onChanged: (value) {
                      if (value != null) {
                        setState(() => selectedLanguage = value);
                      }
                    },
                  ),
                  IconButton(
                    icon: Icon(Icons.translate),
                    onPressed: translateText,
                  ),
                  IconButton(
                    icon: Icon(isSpeaking ? Icons.volume_off : Icons.volume_up),
                    onPressed: _toggleSpeech,
                  ),
                  IconButton(
                    icon: Icon(Icons.close),
                    onPressed: widget.onClose,
                  ),
                ],
              ),
            ],
          ),
          Divider(),
          Expanded(
            child: SingleChildScrollView(
              child: RichText(
                text: TextSpan(
                  style: TextStyle(color: Colors.black),
                  children: translatedText.isNotEmpty
                      ? _formatResponseText(translatedText)
                      : _formatResponseText(widget.responseText),
                ),
              ),
            ),
          ),
          if (isLoading) Center(child: CircularProgressIndicator()),
        ],
      ),
    );
  }
}
