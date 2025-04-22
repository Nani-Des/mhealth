import 'dart:convert';
import 'dart:io';
import 'package:flutter/material.dart';
import 'package:http/http.dart' as http;
import 'package:flutter_tts/flutter_tts.dart';
import 'package:flutter_dotenv/flutter_dotenv.dart';
import 'package:just_audio/just_audio.dart';
import 'package:dio/dio.dart';

class FirstAidResponseWidget extends StatefulWidget {
  final String responseText;
  final VoidCallback onClose;

  const FirstAidResponseWidget({
    Key? key,
    required this.responseText,
    required this.onClose,
  }) : super(key: key);

  @override
  _FirstAidResponseWidget1State createState() => _FirstAidResponseWidget1State();
}

class _FirstAidResponseWidget1State extends State<FirstAidResponseWidget> with SingleTickerProviderStateMixin {
  String displayText = "";
  String selectedLanguage = "en"; // Default to English
  bool isLoading = false;
  bool isSpeaking = false;
  bool isInitializing = true;
  late FlutterTts flutterTts;
  late AudioPlayer audioPlayer;
  bool isTranslated = false;
  CancelToken? _cancelToken;

  late AnimationController _progressAnimationController;
  late Animation<double> _progressAnimation;

  final Map<String, String> languageMap = {
    "Twi (Akan)": "ak",
    "Ewe": "ee",
    "Ga": "gaa",
    "English": "en"
  };

  static const int maxTtsChars = 590; // Reduced to avoid tensor errors
  static const int maxRetries = 2; // Retry attempts for TTS API

  @override
  void initState() {
    super.initState();
    flutterTts = FlutterTts();
    audioPlayer = AudioPlayer();
    _cancelToken = CancelToken();
    displayText = widget.responseText;

    // Initialize TTS with strict cleanup
    _initializeTts();
    audioPlayer.stop();
    audioPlayer.pause();

    print("initState: TTS stopped, isSpeaking = $isSpeaking, isInitializing = $isInitializing"); // Debug log

    _progressAnimationController = AnimationController(
      vsync: this,
      duration: Duration(seconds: 2),
    )..repeat();
    _progressAnimation = Tween<double>(begin: 0, end: 1).animate(_progressAnimationController);

    // Mark initialization complete after delay
    WidgetsBinding.instance.addPostFrameCallback((_) async {
      await Future.delayed(Duration(milliseconds: 500));
      if (mounted) {
        setState(() => isInitializing = false);
        print("initState: Initialization complete, isInitializing = $isInitializing"); // Debug log
      }
    });
  }

  Future<void> _initializeTts() async {
    await flutterTts.stop();
    await flutterTts.setQueueMode(0); // Clear queued speech
    await flutterTts.setSilence(1); // Force silence
    await flutterTts.setLanguage("en-US");
    await flutterTts.setSpeechRate(0.5);
    await flutterTts.setPitch(1.0);
    flutterTts.setCompletionHandler(() {
      if (isSpeaking && mounted) {
        setState(() => isSpeaking = false);
        print("FlutterTts completed, isSpeaking = $isSpeaking"); // Debug log
      }
    });
    flutterTts.setErrorHandler((msg) {
      if (mounted) {
        setState(() => isSpeaking = false);
        print("FlutterTts error: $msg"); // Debug log
      }
    });
  }

  String _sanitizeTextForTranslation(String text) {
    // Preserve markdown-like structures
    return text
        .replaceAll("\n", "\n") // Keep newlines intact
        .replaceAllMapped(RegExp(r'^(#{1,3})\s*(.*)', multiLine: true), (match) => '${match.group(1)} ${match.group(2)}')
        .replaceAllMapped(RegExp(r'^\d+\.\s*(.*)', multiLine: true), (match) => '${match.group(0)}')
        .replaceAllMapped(RegExp(r'^- (.*)', multiLine: true), (match) => '- ${match.group(1)}')
        .replaceAllMapped(RegExp(r'^• (.*)', multiLine: true), (match) => '• ${match.group(1)}')
        .replaceAll("**", "");
  }

  String _sanitizeTextForSpeech(String text) {
    // Allow all Unicode letters and spaces for Twi, Ewe, Ga
    return text
        .replaceAll(RegExp(r'[^\p{L}\s]', unicode: true), '')
        .replaceAll(RegExp(r'\s+'), ' ')
        .trim();
  }

  String _truncateText(String text, int maxChars) {
    if (text.length <= maxChars) return text;
    return text.substring(0, maxChars).trim();
  }

  Future<void> translateText() async {
    if (widget.responseText.trim().isEmpty) {
      if (mounted) {
        setState(() {
          displayText = "Error: No text to translate.";
          isTranslated = false;
        });
      }
      return;
    }

    String? apiKey = dotenv.env['GOOGLE_TRANSLATE_API_KEY'];
    if (apiKey == null || apiKey.isEmpty) {
      if (mounted) {
        setState(() {
          displayText = "Error: Missing API key.";
          isTranslated = false;
        });
      }
      return;
    }

    if (mounted) {
      setState(() => isLoading = true);
    }

    // Stop any ongoing speech before translation
    if (isSpeaking) {
      if (selectedLanguage == "en") {
        await flutterTts.stop();
      } else {
        await audioPlayer.stop();
      }
      if (mounted) {
        setState(() => isSpeaking = false);
        print("translateText: Stopped ongoing speech"); // Debug log
      }
    }

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
        final translatedText = responseBody['data']['translations'][0]['translatedText'];
        print("Translated text: $translatedText");

        if (mounted) {
          setState(() {
            displayText = translatedText;
            isTranslated = true;
          });
        }
      } else {
        if (mounted) {
          setState(() {
            displayText = "Translation failed: ${response.statusCode}";
            isTranslated = false;
          });
        }
      }
    } catch (e) {
      if (mounted) {
        setState(() {
          displayText = "Error: ${e.toString()}";
          isTranslated = false;
        });
      }
    }

    if (mounted) {
      setState(() => isLoading = false);
    }
  }

  Future<void> _toggleSpeech() async {
    if (isInitializing) {
      print("toggleSpeech: Blocked during initialization"); // Debug log
      return;
    }

    // Log stack trace to trace caller
    print("toggleSpeech called, isSpeaking = $isSpeaking, language = $selectedLanguage"); // Debug log
    print("Stack trace: ${StackTrace.current}"); // Debug log

    // Update isSpeaking immediately on tap
    if (mounted) {
      setState(() => isSpeaking = !isSpeaking);
      print("toggleSpeech: Toggled isSpeaking to $isSpeaking"); // Debug log
    }

    if (!isSpeaking) {
      // Stop speech
      if (selectedLanguage == "en") {
        await flutterTts.stop();
      } else {
        await audioPlayer.stop();
      }
      print("toggleSpeech: Stopped speech"); // Debug log
    } else {
      // Start speech
      String textToSpeak = selectedLanguage == "en" ? widget.responseText : displayText;
      textToSpeak = _sanitizeTextForSpeech(textToSpeak);
      // Truncate for Ghana NLP TTS
      textToSpeak = _truncateText(textToSpeak, maxTtsChars);
      print("Sanitized text for speech: $textToSpeak"); // Log sanitized text
      print("Text length: ${textToSpeak.length} characters"); // Log character count
      if (textToSpeak.isEmpty) {
        print("toggleSpeech: Empty text to speak"); // Debug log
        if (mounted) {
          setState(() => isSpeaking = false); // Revert icon
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(content: Text("No text to speak")),
          );
        }
        return;
      }

      // Reset TTS state
      if (selectedLanguage == "en") {
        await flutterTts.stop();
      } else {
        await audioPlayer.stop();
      }

      // Show loading indicator for TTS
      if (mounted) {
        setState(() => isLoading = true);
      }

      if (selectedLanguage == "en") {
        await flutterTts.setLanguage("en-US");
        await flutterTts.setSpeechRate(0.5);
        await flutterTts.setPitch(1.0);

        try {
          int result = await flutterTts.speak(textToSpeak);
          if (result != 1) {
            print("toggleSpeech: Failed to start English TTS"); // Debug log
            if (mounted) {
              setState(() => isSpeaking = false); // Revert icon
              ScaffoldMessenger.of(context).showSnackBar(
                SnackBar(content: Text("Failed to start English speech")),
              );
            }
          } else {
            print("toggleSpeech: Started English TTS"); // Debug log
          }
        } catch (e) {
          print("toggleSpeech: English TTS error - $e"); // Debug log
          if (mounted) {
            setState(() => isSpeaking = false); // Revert icon
            ScaffoldMessenger.of(context).showSnackBar(
              SnackBar(content: Text("English speech error: $e")),
            );
          }
        } finally {
          if (mounted) {
            setState(() => isLoading = false);
          }
        }
      } else {
        String? ghanaNlpApiKey = dotenv.env['GHANA_NLP_API_KEY'];
        if (ghanaNlpApiKey == null || ghanaNlpApiKey.isEmpty) {
          print("toggleSpeech: Missing Ghana NLP API key"); // Debug log
          if (mounted) {
            setState(() => isSpeaking = false); // Revert icon
            setState(() => isLoading = false);
            ScaffoldMessenger.of(context).showSnackBar(
              SnackBar(content: Text("Missing Ghana NLP API key")),
            );
          }
          return;
        }

        final Map<String, String> languageToGhanaNlp = {
          "ak": "tw",
          "ee": "ee",
          "gaa": "ga"
        };

        final Map<String, String> speakerMap = {
          "ak": "twi_speaker_4",
          "ee": "ewe_speaker_4",
          "gaa": "ga_speaker_3"
        };

        final url = Uri.parse("https://translation-api.ghananlp.org/tts/v1/synthesize");
        int attempt = 0;
        bool success = false;
        dynamic error;

        while (attempt < maxRetries && !success && !_cancelToken!.isCancelled) {
          attempt++;
          print("toggleSpeech: Attempt $attempt of $maxRetries for Ghana NLP TTS"); // Debug log
          try {
            final response = await http.post(
              url,
              headers: {
                "Content-Type": "application/json",
                "Cache-Control": "no-cache",
                "Ocp-Apim-Subscription-Key": ghanaNlpApiKey,
              },
              body: jsonEncode({
                "text": textToSpeak,
                "language": languageToGhanaNlp[selectedLanguage],
                "speaker_id": speakerMap[selectedLanguage]
              }),
            );

            print("Ghana NLP TTS response headers: ${response.headers}"); // Log headers
            print("Ghana NLP TTS response body: ${response.body}"); // Log body

            if (response.statusCode == 200) {
              final contentType = response.headers['content-type'] ?? '';
              if (contentType.contains('application/json')) {
                final jsonResponse = jsonDecode(response.body);
                print("Ghana NLP TTS JSON response: $jsonResponse"); // Debug log
                error = jsonResponse['message'] ?? 'Unknown error';
                if (attempt == maxRetries && mounted) {
                  setState(() => isSpeaking = false); // Revert icon
                  ScaffoldMessenger.of(context).showSnackBar(
                    SnackBar(content: Text("TTS error: $error")),
                  );
                }
              } else if (contentType.contains('audio/wav')) {
                final audioBytes = response.bodyBytes;
                try {
                  await audioPlayer.setAudioSource(
                    AudioSource.uri(
                      Uri.dataFromBytes(audioBytes, mimeType: 'audio/wav'),
                    ),
                  );
                  await audioPlayer.play();
                  print("toggleSpeech: Started Ghana NLP TTS"); // Debug log
                  success = true;
                } catch (e) {
                  print("toggleSpeech: Audio playback error - $e"); // Debug log
                  error = e;
                  if (attempt == maxRetries && mounted) {
                    setState(() => isSpeaking = false); // Revert icon
                    ScaffoldMessenger.of(context).showSnackBar(
                      SnackBar(content: Text("Audio playback error: $e")),
                    );
                  }
                }
              } else {
                print("toggleSpeech: Unexpected content-type: $contentType"); // Debug log
                error = 'Unexpected response format';
                if (attempt == maxRetries && mounted) {
                  setState(() => isSpeaking = false); // Revert icon
                  ScaffoldMessenger.of(context).showSnackBar(
                    SnackBar(content: Text("Unexpected response format")),
                  );
                }
              }
            } else {
              print("toggleSpeech: Ghana NLP TTS failed - ${response.statusCode}, ${response.body}"); // Debug log
              error = 'TTS failed: ${response.statusCode}';
              if (attempt == maxRetries && mounted) {
                setState(() => isSpeaking = false); // Revert icon
                ScaffoldMessenger.of(context).showSnackBar(
                  SnackBar(content: Text("TTS failed: ${response.statusCode}")),
                );
              }
            }
          } catch (e) {
            print("toggleSpeech: Ghana NLP TTS error - $e"); // Debug log
            error = e;
            if (attempt == maxRetries && mounted) {
              setState(() => isSpeaking = false); // Revert icon
              ScaffoldMessenger.of(context).showSnackBar(
                SnackBar(content: Text("TTS error: $e")),
              );
            }
          }
        }

        if (mounted) {
          setState(() => isLoading = false);
        }
      }
    }
  }

  @override
  void dispose() {
    _progressAnimationController.dispose();
    flutterTts.stop();
    audioPlayer.stop();
    audioPlayer.dispose();
    _cancelToken?.cancel();
    super.dispose();
    print("dispose: TTS stopped, audioPlayer disposed, HTTP requests cancelled"); // Debug log
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
    child: Stack(
    children: [
    Column(
    mainAxisSize: MainAxisSize.min,
    crossAxisAlignment: CrossAxisAlignment.start,
    children: [
    _buildHeader(),
    const SizedBox(height: 16),
    _buildContent(),
    ],
    ),
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
              _buildActionButton(isSpeaking ? Icons.record_voice_over : Icons.volume_off, _toggleSpeech),
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
        onChanged: (value) async {
          if (value != null) {
            if (mounted) {
              setState(() {
                selectedLanguage = value;
                // Reset displayText to English if switching to en
                if (value == "en") {
                  displayText = widget.responseText;
                  isTranslated = false;
                }
              });
              print("Language changed to: $selectedLanguage"); // Debug log
              // Stop any ongoing speech on language change
              if (isSpeaking) {
                if (selectedLanguage == "en") {
                  await flutterTts.stop();
                } else {
                  await audioPlayer.stop();
                }
                setState(() => isSpeaking = false);
                print("Language change: Stopped ongoing speech"); // Debug log
              }
              // Trigger translation for non-English languages
              if (value != "en") {
                await translateText();
              }
            }
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
                isLoading && !isSpeaking ? "Translating..." : "Processing speech...",
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