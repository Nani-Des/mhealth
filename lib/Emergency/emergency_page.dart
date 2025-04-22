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
import 'package:url_launcher/url_launcher.dart';
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

  bool _isListening = false;
  bool _showResponsePopup = false;
  bool _isOffline = false;
  bool _isLoading = false;
  String _responseText = "";

  final GlobalKey _micKey = GlobalKey();
  final GlobalKey _textFieldKey = GlobalKey();
  final GlobalKey _sendKey = GlobalKey();

  Map<String, dynamic>? _emergencyData;
  late Box _translationBox;

  late AnimationController _progressAnimationController;
  late Animation<double> _progressAnimation;

  @override
  void initState() {
    super.initState();
    _speechToText = stt.SpeechToText();
    _translationBox = Hive.box('translations');
    _loadEmergencyData();
    _checkConnectivity();

    _progressAnimationController = AnimationController(
      vsync: this,
      duration: Duration(seconds: 2),
    )..repeat();
    _progressAnimation = Tween<double>(begin: 0, end: 1).animate(_progressAnimationController);

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
    _progressAnimationController.dispose();
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
      _isLoading = true;
    });

    String response;
    if (_isOffline) {
      response = _findClosestMatch(query);
    } else {
      String? cachedResponse = _translationBox.get(query);
      if (cachedResponse != null) {
        response = cachedResponse;
      } else {
        response = await _fetchFirstAidResponse(query);
        if (!response.startsWith("Sorry,")) {
          await _translationBox.put(query, response);
        }
      }
    }

    if (response.startsWith("Sorry,")) {
      response = _findClosestMatch(query);
    }

    setState(() {
      _responseText = response;
      _isLoading = false;
    });

    _showResponseBottomSheet();
    await _flutterTts.speak(response);
  }

  Future<String> _fetchFirstAidResponse(String query) async {
    try {
      final String apiKey = dotenv.env['OPENAI_API_KEY'] ?? '';
      if (apiKey.isEmpty) {
        return "API key is missing. Please check the environment variables.";
      }

      const String prefix =
          "Provide clear, step-by-step first-aid instructions for the following situation in a gradual and simple manner. Use easy-to-understand language, avoid complex medical jargon: ";
      final String modifiedQuery = prefix + query;

      final response = await Dio().post(
        'https://api.openai.com/v1/chat/completions',
        options: Options(headers: {'Authorization': 'Bearer $apiKey'}),
        data: {
          'model': 'gpt-4o-mini',
          'messages': [{'role': 'user', 'content': modifiedQuery}],
        },
      );
      return response.data['choices'][0]['message']['content'];
    } catch (e) {
      return "Sorry, I couldn't fetch the response.";
    }
  }

  String _findClosestMatch(String query) {
    if (_emergencyData == null || _emergencyData!['articles'] == null) {
      print("Debug: No emergency data or articles found.");
      return "No emergency procedures available offline.";
    }

    final articles = _emergencyData!['articles'] as List<dynamic>;
    if (articles.isEmpty) {
      print("Debug: Articles list is empty.");
      return "No emergency procedures available offline.";
    }

    String bestMatchTitle = "";
    String bestMatchContent = "";
    double highestScore = 0.0;

    final cleanQuery = query.toLowerCase().trim();
    final allWords = cleanQuery.split(RegExp(r'\s+'));
    const stopWords = {
      'i', 'me', 'my', 'myself', 'we', 'our', 'ours', 'ourselves', 'you', 'your',
      'yours', 'he', 'him', 'his', 'she', 'her', 'hers', 'it', 'its', 'they',
      'them', 'their', 'theirs', 'what', 'which', 'who', 'whom', 'this', 'that',
      'these', 'those', 'am', 'is', 'are', 'was', 'were', 'be', 'been', 'being',
      'have', 'has', 'had', 'having', 'do', 'does', 'did', 'doing', 'a', 'an',
      'the', 'and', 'but', 'if', 'or', 'because', 'as', 'until', 'while', 'of',
      'at', 'by', 'for', 'with', 'about', 'to', 'in', 'on', 'from'
    };

    final keywords = allWords.where((word) => !stopWords.contains(word)).toList();
    final keywordQuery = keywords.isNotEmpty ? keywords.join(' ') : cleanQuery;
    print("Debug: Query entered: '$cleanQuery' -> Keywords: $keywords");

    for (var article in articles) {
      final String title = article['title'].toString().toLowerCase();
      final String keywordsFromData = article['keywords'].toString().toLowerCase();

      final keywordList = keywordsFromData.split(',').map((k) => k.trim()).toList();
      final combinedText = "$title, ${keywordList.join(', ')}";
      final textWords = combinedText.split(RegExp(r',\s*')).map((w) => w.trim()).toList();

      final double similarity = keywordQuery.similarityTo(combinedText);
      final int matchingWords = keywords.where((word) => textWords.any((tw) => tw.contains(word))).length;
      final double overlapScore = keywords.isNotEmpty ? matchingWords / keywords.length : 0.0;

      final double combinedScore = (0.7 * similarity) + (0.3 * overlapScore);
      print("Debug: Comparing '$keywordQuery' to '$combinedText' -> Similarity: $similarity, Overlap: $overlapScore, Combined: $combinedScore");

      if (combinedScore > highestScore) {
        highestScore = combinedScore;
        bestMatchTitle = article['title'];
        bestMatchContent = article['content'];
      }
    }

    print("Debug: Highest score: $highestScore for '$bestMatchTitle'");
    final double threshold = keywords.length <= 2 ? 0.2 : 0.3;
    if (highestScore < threshold) {
      print("Debug: Score $highestScore below threshold $threshold");
      if (keywords.any((word) => ["pain", "hurt", "ache", "tight"].contains(word))) {
        bestMatchTitle = "Chest Pain";
        bestMatchContent = articles.firstWhere((a) => a['title'] == "Chest Pain")['content'];
        print("Debug: Fallback to 'Chest Pain' for pain-related keywords");
      } else if (keywords.any((word) => ["bleed", "bleeding", "blood", "cut"].contains(word))) {
        bestMatchTitle = "Severe Bleeding";
        bestMatchContent = articles.firstWhere((a) => a['title'] == "Severe Bleeding")['content'];
        print("Debug: Fallback to 'Severe Bleeding' for bleeding-related keywords");
      } else if (keywords.any((word) => ["breathe", "breathing", "air"].contains(word))) {
        bestMatchTitle = "Choking";
        bestMatchContent = articles.firstWhere((a) => a['title'] == "Choking")['content'];
        print("Debug: Fallback to 'Choking' for breathing-related keywords");
      } else {
        return "I couldn't find a specific match for '$query'. Please try describing the emergency into words";
      }
    }

    print("Debug: Navigating to '$bestMatchTitle'");
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

  void _showResponseBottomSheet() {
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
      ),
      builder: (BuildContext context) {
        return Container(
          constraints: BoxConstraints(
            maxHeight: MediaQuery.of(context).size.height * 0.6,
          ),
          child: SingleChildScrollView(
            child: Padding(
              padding: const EdgeInsets.all(16.0),
              child: FirstAidResponseWidget(
                responseText: _responseText,
                onClose: () => Navigator.pop(context),
              ),
            ),
          ),
        );
      },
    );
  }

  Future<void> _makePhoneCall(String phoneNumber) async {
    final Uri phoneUri = Uri(scheme: 'tel', path: phoneNumber);
    if (await canLaunchUrl(phoneUri)) {
      await launchUrl(phoneUri);
    } else {
      print('Could not launch $phoneNumber');
    }
  }

  void _showEmergencyOptions(BuildContext context) {
    showDialog(
      context: context,
      builder: (BuildContext context) {
        return Dialog(
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
          elevation: 10,
          backgroundColor: Colors.white,
          child: Padding(
            padding: const EdgeInsets.all(60.0),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    Icon(Icons.emergency, color: Colors.redAccent, size: 28),
                    SizedBox(width: 12),
                    Text(
                      "Emergency Services",
                      style: TextStyle(
                        fontSize: 8,
                        fontWeight: FontWeight.w700,
                        color: Colors.redAccent,
                        letterSpacing: 0.5,
                      ),
                    ),
                  ],
                ),
                SizedBox(height: 20),
                _buildOptionButton(
                  context,
                  icon: Icons.local_police,
                  label: "Police",
                  number: "911",
                  color: Colors.blue.shade700,
                ),
                SizedBox(height: 12),
                _buildOptionButton(
                  context,
                  icon: Icons.fire_truck,
                  label: "Fire Service",
                  number: "101",
                  color: Colors.orange.shade700,
                ),
                SizedBox(height: 12),
                _buildOptionButton(
                  context,
                  icon: Icons.local_hospital,
                  label: "Ambulance",
                  number: "112",
                  color: Colors.red.shade700,
                ),
              ],
            ),
          ),
        );
      },
    );
  }

  Widget _buildOptionButton(
      BuildContext context, {
        required IconData icon,
        required String label,
        required String number,
        required Color color,
      }) {
    return GestureDetector(
      onTap: () {
        _makePhoneCall(number);
        Navigator.pop(context);
      },
      child: Container(
        padding: EdgeInsets.symmetric(vertical: 12, horizontal: 12),
        decoration: BoxDecoration(
          color: color,
          borderRadius: BorderRadius.circular(12),
          boxShadow: [
            BoxShadow(
              color: color.withOpacity(0.3),
              blurRadius: 6,
              offset: Offset(0, 3),
            ),
          ],
        ),
        child: Row(
          children: [
            Icon(icon, color: Colors.white, size: 24),
            SizedBox(width: 12),
            Text(
              label,
              style: TextStyle(
                color: Colors.white,
                fontSize: 14,
                fontWeight: FontWeight.w600,
              ),
            ),
          ],
        ),
      ),
    );
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
    return Scaffold(
      appBar: AppBar(
        elevation: 0,
        backgroundColor: Colors.redAccent,
        leading: Icon(
          _isOffline ? Icons.cloud_off : Icons.cloud_done,
          color: Colors.white,
          size: 24,
        ),
        title: SizedBox.shrink(), // Optional: removes extra space if no title is needed
        flexibleSpace: Container(
          decoration: BoxDecoration(
            gradient: LinearGradient(
              begin: Alignment.topLeft,
              end: Alignment.bottomRight,
              colors: [Colors.redAccent, Colors.redAccent.shade700],
            ),
          ),
        ),
        actions: [
          // Your existing Police, Fire, and Ambulance buttons here
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 6.0),
            child: Tooltip(
              message: "Call Police (911)",
              child: GestureDetector(
                onTap: () => _makePhoneCall("911"),
                child: Container(
                  padding: EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                  decoration: BoxDecoration(
                    color: Colors.blue.shade700,
                    borderRadius: BorderRadius.circular(8),
                  ),
                  child: Row(
                    children: [
                      Icon(Icons.local_police, color: Colors.white, size: 20),
                      SizedBox(width: 4),
                      Text(
                        "Police",
                        style: TextStyle(
                          color: Colors.white,
                          fontSize: 12,
                          fontWeight: FontWeight.w600,
                        ),
                      ),
                    ],
                  ),
                ),
              ),
            ),
          ),
          // Fire Service Button (Orange)
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 6.0),
            child: Tooltip(
              message: "Call Fire Service (101)",
              child: GestureDetector(
                onTap: () => _makePhoneCall("101"),
                child: Container(
                  padding: EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                  decoration: BoxDecoration(
                    color: Colors.orange.shade700,
                    borderRadius: BorderRadius.circular(8),
                  ),
                  child: Row(
                    children: [
                      Icon(Icons.fire_truck, color: Colors.white, size: 20),
                      SizedBox(width: 4),
                      Text(
                        "Fire",
                        style: TextStyle(
                          color: Colors.white,
                          fontSize: 12,
                          fontWeight: FontWeight.w600,
                        ),
                      ),
                    ],
                  ),
                ),
              ),
            ),
          ),
          // Ambulance Button (Red)
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 6.0),
            child: Tooltip(
              message: "Call Ambulance (112)",
              child: GestureDetector(
                onTap: () => _makePhoneCall("112"),
                child: Container(
                  padding: EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                  decoration: BoxDecoration(
                    color: Colors.red.shade700,
                    borderRadius: BorderRadius.circular(8),
                  ),
                  child: Row(
                    children: [
                      Icon(Icons.local_hospital, color: Colors.white, size: 20),
                      SizedBox(width: 4),
                      Text(
                        "Ambulance",
                        style: TextStyle(
                          color: Colors.white,
                          fontSize: 12,
                          fontWeight: FontWeight.w600,
                        ),
                      ),
                    ],
                  ),
                ),
              ),
            ),
          ),
          SizedBox(width: 8),
        ],
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
              left: 15,
              right: 15,
              bottom: 20,
              child: _buildInputArea(),
            ),
            if (_isLoading)
              Center(
                child: Container(
                  padding: EdgeInsets.all(20),
                  decoration: BoxDecoration(
                    color: Colors.black54,
                    borderRadius: BorderRadius.circular(15),
                  ),
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      _buildSophisticatedProgressIndicator(),
                      SizedBox(height: 16),
                      Text(
                        "Processing Emergency...",
                        style: TextStyle(color: Colors.white, fontSize: 16),
                      ),
                    ],
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
                  hintStyle: const TextStyle(
                    fontSize: 12,
                    color: Colors.grey,
                  ),
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
                _messageController.clear();
                _fetchAndShowResponse(query);
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