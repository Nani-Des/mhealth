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

class _FirstAidResponseWidget1State extends State<FirstAidResponseWidget1> with SingleTickerProviderStateMixin {
  String displayText = "";
  String selectedLanguage = "ak";
  bool isLoading = false;
  bool isSpeaking = true;
  late FlutterTts flutterTts;
  bool isTranslated = false;

  late AnimationController _progressAnimationController;
  late Animation<double> _progressAnimation;

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
    displayText = widget.responseText;

    _progressAnimationController = AnimationController(
      vsync: this,
      duration: Duration(seconds: 2),
    )..repeat();
    _progressAnimation = Tween<double>(begin: 0, end: 1).animate(_progressAnimationController);
  }

  String _sanitizeTextForTranslation(String text) {
    return text
        .replaceAll("\n", " <br> ")
        .replaceAllMapped(RegExp(r'^(#{1,})\s*(.*)', multiLine: true), (match) => match.group(2)!)
        .replaceAll("**", "");
  }

  String _sanitizeTextForSpeech(String text) {
    return text
        .replaceAll(RegExp(r'#{1,}', multiLine: true), '')
        .replaceAll("**", "")
        .replaceAll("<br>", " ");
  }

  String _restoreFormatting(String text) {
    return text.replaceAll("<br>", "\n");
  }

  Future<void> translateText() async {
    if (widget.responseText.trim().isEmpty) {
      setState(() {
        displayText = "Error: No text to translate.";
        isTranslated = false;
      });
      return;
    }

    String? apiKey = dotenv.env['GOOGLE_TRANSLATE_API_KEY'];
    if (apiKey == null || apiKey.isEmpty) {
      setState(() {
        displayText = "Error: Missing API key.";
        isTranslated = false;
      });
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
        final translatedText = _restoreFormatting(responseBody['data']['translations'][0]['translatedText']);
        print("Translated text: $translatedText");

        setState(() {
          displayText = translatedText;
          isTranslated = true;
        });
      } else {
        setState(() {
          displayText = "Translation failed: ${response.statusCode}";
          isTranslated = false;
        });
      }
    } catch (e) {
      setState(() {
        displayText = "Error: ${e.toString()}";
        isTranslated = false;
      });
    }

    setState(() => isLoading = false);
  }

  Future<void> _toggleSpeech() async {
    if (isSpeaking) {
      await flutterTts.stop();
      setState(() => isSpeaking = false);
      return;
    }

    String textToSpeak = displayText;
    String languageCode = selectedLanguage;

    final Map<String, String> ttsLanguageMap = {
      "ak": "ak_GH",
      "ee": "ee_GH",
      "gaa": "gaa_GH",
      "en": "en-US"
    };

    await flutterTts.setLanguage(ttsLanguageMap[languageCode] ?? "en-US");
    await flutterTts.setSpeechRate(0.5);
    await flutterTts.setPitch(1.0);

    int result = await flutterTts.speak(_sanitizeTextForSpeech(textToSpeak));
    if (result == 1) {
      setState(() => isSpeaking = true);
    }
  }

  @override
  void dispose() {
    _progressAnimationController.dispose();
    flutterTts.stop();
    super.dispose();
  }

  Widget _buildSophisticatedProgressIndicator() {
    return AnimatedBuilder(
      animation: _progressAnimationController,
      builder: (context, child) {
        return Stack(
          alignment: Alignment.center,
          children: [
            SizedBox(
              width: 80,
              height: 80,
              child: CircularProgressIndicator(
                value: _progressAnimation.value,
                strokeWidth: 8,
                backgroundColor: Colors.teal.withOpacity(0.2),
                valueColor: AlwaysStoppedAnimation<Color>(Colors.teal),
              ),
            ),
            Container(
              width: 60,
              height: 60,
              decoration: BoxDecoration(
                shape: BoxShape.circle,
                gradient: LinearGradient(
                  colors: [Colors.teal.shade100, Colors.teal.shade300],
                  begin: Alignment.topLeft,
                  end: Alignment.bottomRight,
                ),
                boxShadow: [
                  BoxShadow(
                    color: Colors.teal.withOpacity(0.3),
                    blurRadius: 10,
                    offset: Offset(0, 4),
                  ),
                ],
              ),
              child: Center(
                child: Text(
                  '${(_progressAnimation.value * 100).toInt()}%',
                  style: TextStyle(
                    color: Colors.white,
                    fontWeight: FontWeight.bold,
                    fontSize: 18,
                  ),
                ),
              ),
            ),
          ],
        );
      },
    );
  }

  @override
  Widget build(BuildContext context) {
    print("Building widget with displayText: $displayText");
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
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          _buildHeader(),
          const SizedBox(height: 16),
          _buildContent(),
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
          Row(
            children: [
              _buildLanguageDropdown(),
              const SizedBox(width: 2),
              _buildActionButton(Icons.translate, translateText),
              const SizedBox(width: 2),
              _buildActionButton(isSpeaking ? Icons.volume_up : Icons.volume_off, _toggleSpeech),
              const SizedBox(width: 2),
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
        style: const TextStyle(color: Colors.white, fontSize: 12, fontWeight: FontWeight.w500),
        items: languageMap.entries.map((entry) {
          return DropdownMenuItem<String>(
            value: entry.value,
            child: Text(entry.key, style: TextStyle(fontSize: 10)),
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
        icon: Icon(icon, color: Colors.white, size: 20),
        onPressed: onPressed,
        splashRadius: 15,
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
              fontSize: 12,
              color: Colors.black87,
              height: 1.5,
            ),
            children: _formatText(displayText),
          ),
        ),
      ),
    );
  }

  Widget _buildLoadingOverlay() {
    return Positioned.fill(
      child: Container(
        decoration: BoxDecoration(
          color: Colors.black.withOpacity(0.3),
          borderRadius: BorderRadius.circular(12),
        ),
        child: Center(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              _buildSophisticatedProgressIndicator(),
              SizedBox(height: 16),
              Text(
                "Translating...",
                style: TextStyle(color: Colors.white, fontSize: 16),
              ),
            ],
          ),
        ),
      ),
    );
  }

  List<TextSpan> _formatText(String text) {
    List<TextSpan> spans = [];
    List<String> lines = text.split("\n");

    for (String line in lines) {
      if (line.trim().isEmpty) {
        spans.add(TextSpan(text: "\n"));
        continue;
      }

      if (line.startsWith(RegExp(r'^\d+\.\s'))) {
        spans.add(TextSpan(
          text: "$line\n",
          style: const TextStyle(
            fontSize: 16,
            fontWeight: FontWeight.w600,
            color: Colors.black87,
          ),
        ));
      } else if (line.startsWith("- ") || line.startsWith("• ")) {
        String content = line.substring(2).trim();
        spans.add(TextSpan(
          text: "• $content\n",
          style: const TextStyle(
            fontSize: 14,
            fontWeight: FontWeight.w500,
            color: Colors.black54,
          ),
        ));
      } else if (line.contains(RegExp(r'^#{1,3}\s'))) {
        String content = line.replaceAll(RegExp(r'^#{1,3}\s+'), "").trim();
        spans.add(TextSpan(
          text: "$content\n",
          style: const TextStyle(
            fontSize: 18,
            fontWeight: FontWeight.bold,
            color: Colors.redAccent,
          ),
        ));
      } else {
        spans.add(TextSpan(
          text: "$line\n",
          style: const TextStyle(
            fontSize: 14,
            color: Colors.black87,
          ),
        ));
      }
    }

    return spans;
  }
}