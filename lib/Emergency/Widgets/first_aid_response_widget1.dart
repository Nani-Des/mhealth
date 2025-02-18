import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:http/http.dart' as http;
import 'package:flutter_tts/flutter_tts.dart';
import 'package:flutter_dotenv/flutter_dotenv.dart';

class FirstAidResponseWidget1 extends StatefulWidget {
  final String responseText;
  final VoidCallback onClose;

  const FirstAidResponseWidget1({
    Key? key,
    required this.responseText,
    required this.onClose,
  }) : super(key: key);

  @override
  _FirstAidResponseWidget1State createState() => _FirstAidResponseWidget1State();
}

class _FirstAidResponseWidget1State extends State<FirstAidResponseWidget1> {
  String translatedText = "";
  String selectedLanguage = "ak"; // Default language is Akan (Twi alternative)
  bool isLoading = false;
  bool isSpeaking = false;
  late FlutterTts flutterTts;

  final Map<String, String> languageMap = {
    "Twi (Akan)": "ak",
    "Ewe": "ee",
    "Ga": "gaa",
    "English": "en"
  };

  @override
  void initState() {
    super.initState();
    flutterTts = FlutterTts();
  }

  String _sanitizeTextForTranslation(String text) {
    return text.replaceAll("\n", " <br> ") // Preserve new lines for formatting
        .replaceAllMapped(RegExp(r'^(#{1,})\s*(.*)', multiLine: true), (match) => match.group(2)!)
        .replaceAll("**", ""); // Remove markdown markers
  }

  String _restoreFormatting(String text) {
    return text.replaceAll("<br>", "\n"); // Convert HTML-like breaks back to new lines
  }

  Future<void> translateText() async {
    if (widget.responseText.trim().isEmpty) {
      setState(() => translatedText = "Error: No text to translate.");
      return;
    }

    String? apiKey = dotenv.env['GOOGLE_TRANSLATE_API_KEY'];
    if (apiKey == null || apiKey.isEmpty) {
      setState(() => translatedText = "Error: Missing API key.");
      return;
    }

    setState(() => isLoading = true);

    final url = Uri.parse("https://translation.googleapis.com/language/translate/v2?key=$apiKey");

    try {
      final response = await http.post(
        url,
        headers: {"Content-Type": "application/json"},
        body: jsonEncode({
          "q": _sanitizeTextForTranslation(widget.responseText),
          "target": selectedLanguage,
          "format": "text"
        }),
      );

      print("Response Status Code: ${response.statusCode}");
      print("Response Body: ${response.body}");

      if (response.statusCode == 200) {
        final responseBody = jsonDecode(response.body);
        setState(() {
          translatedText = _restoreFormatting(responseBody['data']['translations'][0]['translatedText']);
        });
      } else {
        setState(() => translatedText = "Translation failed: ${response.statusCode}");
        print("Translation failed: ${response.statusCode}\n${response.body}");
      }
    } catch (e) {
      setState(() => translatedText = "Error: ${e.toString()}");
      print("Error occurred: ${e.toString()}");
    }

    setState(() => isLoading = false);
  }

  Future<void> _toggleSpeech() async {
    if (isSpeaking) {
      await flutterTts.stop();
      setState(() => isSpeaking = false);
      return;
    }

    String textToSpeak = translatedText.isNotEmpty ? translatedText : widget.responseText;
    String languageCode = selectedLanguage;

    // Map language codes to TTS-supported languages
    final Map<String, String> ttsLanguageMap = {
      "ak": "ak_GH", // Akan (Twi)
      "ee": "ee_GH", // Ewe
      "gaa": "gaa_GH", // Ga
      "en": "en-US" // English
    };

    // Set TTS language
    if (ttsLanguageMap.containsKey(languageCode)) {
      await flutterTts.setLanguage(ttsLanguageMap[languageCode]!);
    } else {
      await flutterTts.setLanguage("en-US"); // Default to English if unavailable
    }

    // Set speech rate and pitch for better clarity
    await flutterTts.setSpeechRate(0.5);
    await flutterTts.setPitch(1.0);

    // Start speaking
    int result = await flutterTts.speak(textToSpeak);
    if (result == 1) {
      setState(() => isSpeaking = true);
    }
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
                  style: TextStyle(fontSize: 16, color: Colors.black),
                  children: translatedText.isNotEmpty
                      ? _formatText(translatedText)
                      : _formatText(widget.responseText),
                ),
              ),
            ),
          ),
          if (isLoading) Center(child: CircularProgressIndicator()),
        ],
      ),
    );
  }

  List<TextSpan> _formatText(String text) {
    List<TextSpan> spans = [];
    List<String> lines = text.split("\n");

    for (String line in lines) {
      if (line.startsWith("- ")) {
        spans.add(TextSpan(text: "• ${line.substring(2)}\n", style: TextStyle(fontWeight: FontWeight.bold)));
      } else if (line.startsWith("#")) {
        spans.add(TextSpan(text: "${line.replaceAll("#", "")}\n", style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold)));
      } else {
        spans.add(TextSpan(text: "$line\n"));
      }
    }

    return spans;
  }
}
