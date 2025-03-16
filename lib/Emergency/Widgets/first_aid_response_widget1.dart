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
  String selectedLanguage = "ak";
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
    return text
        .replaceAll("\n", " <br> ")
        .replaceAllMapped(RegExp(r'^(#{1,})\s*(.*)', multiLine: true), (match) => match.group(2)!)
        .replaceAll("**", "");
  }

  String _restoreFormatting(String text) {
    return text.replaceAll("<br>", "\n");
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

      if (response.statusCode == 200) {
        final responseBody = jsonDecode(response.body);
        setState(() {
          translatedText = _restoreFormatting(responseBody['data']['translations'][0]['translatedText']);
        });
      } else {
        setState(() => translatedText = "Translation failed: ${response.statusCode}");
      }
    } catch (e) {
      setState(() => translatedText = "Error: ${e.toString()}");
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

    final Map<String, String> ttsLanguageMap = {
      "ak": "ak_GH",
      "ee": "ee_GH",
      "gaa": "gaa_GH",
      "en": "en-US"
    };

    if (ttsLanguageMap.containsKey(languageCode)) {
      await flutterTts.setLanguage(ttsLanguageMap[languageCode]!);
    } else {
      await flutterTts.setLanguage("en-US");
    }

    await flutterTts.setSpeechRate(0.5);
    await flutterTts.setPitch(1.0);

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
        borderRadius: BorderRadius.circular(20),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.1),
            spreadRadius: 2,
            blurRadius: 10,
            offset: const Offset(0, 2),
          ),
        ],
      ),
      padding: const EdgeInsets.all(20),
      child: Column(
        mainAxisSize: MainAxisSize.min, // Use min to take only necessary space
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          _buildHeader(),
          const SizedBox(height: 16),
          _buildContent(), // Removed Expanded here
          if (isLoading) _buildLoadingOverlay(),
        ],
      ),
    );
  }

  Widget _buildHeader() {
    return Container(
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        gradient: LinearGradient(
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
          colors: [Colors.redAccent, Colors.redAccent.shade700],
        ),
        borderRadius: BorderRadius.circular(16),
      ),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          const Row(
            children: [
              Icon(Icons.medical_services, color: Colors.white, size: 24),
              SizedBox(width: 4),
              Text(
                "First Aid",
                style: TextStyle(
                  fontWeight: FontWeight.bold,
                  fontSize: 10,
                  color: Colors.white,
                ),
              ),
            ],
          ),
          Row(
            children: [
              _buildLanguageDropdown(),
              const SizedBox(width: 8),
              _buildActionButton(Icons.translate, translateText),
              const SizedBox(width: 8),
              _buildActionButton(isSpeaking ? Icons.volume_off : Icons.volume_up, _toggleSpeech),
              const SizedBox(width: 8),
              _buildActionButton(Icons.close, widget.onClose),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildLanguageDropdown() {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
      decoration: BoxDecoration(
        color: Colors.white.withOpacity(0.2),
        borderRadius: BorderRadius.circular(12),
      ),
      child: DropdownButton<String>(
        value: selectedLanguage,
        underline: const SizedBox(),
        dropdownColor: Colors.redAccent,
        icon: const Icon(Icons.arrow_drop_down, color: Colors.white),
        style: const TextStyle(color: Colors.white, fontSize: 14, fontWeight: FontWeight.w500),
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
    );
  }

  Widget _buildActionButton(IconData icon, VoidCallback onPressed) {
    return Container(
      decoration: BoxDecoration(
        color: Colors.white.withOpacity(0.2),
        shape: BoxShape.circle,
      ),
      child: IconButton(
        icon: Icon(icon, color: Colors.white),
        onPressed: onPressed,
        splashRadius: 20,
      ),
    );
  }

  Widget _buildContent() {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Colors.grey[50],
        borderRadius: BorderRadius.circular(12),
      ),
      child: SingleChildScrollView(
        child: RichText(
          text: TextSpan(
            style: const TextStyle(
              fontSize: 16,
              color: Colors.black87,
              height: 1.5,
            ),
            children: translatedText.isNotEmpty
                ? _formatText(translatedText)
                : _formatText(widget.responseText),
          ),
        ),
      ),
    );
  }

  Widget _buildLoadingOverlay() {
    return Container(
      decoration: BoxDecoration(
        color: Colors.black.withOpacity(0.3),
        borderRadius: BorderRadius.circular(12),
      ),
      child: Center(
        child: CircularProgressIndicator(
          valueColor: AlwaysStoppedAnimation<Color>(Colors.redAccent),
          backgroundColor: Colors.white.withOpacity(0.3),
        ),
      ),
    );
  }

  List<TextSpan> _formatText(String text) {
    List<TextSpan> spans = [];
    List<String> lines = text.split("\n");

    for (String line in lines) {
      if (line.trim().isEmpty) continue;
      if (line.startsWith("- ") || line.startsWith("• ")) {
        spans.add(TextSpan(
          text: "• ${line.substring(2)}\n",
          style: const TextStyle(fontWeight: FontWeight.w600),
        ));
      } else if (line.startsWith("#")) {
        spans.add(TextSpan(
          text: "${line.replaceAll("#", "")}\n",
          style: const TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
        ));
      } else {
        spans.add(TextSpan(text: "$line\n"));
      }
    }

    return spans;
  }
}