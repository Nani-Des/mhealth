import 'dart:math';

import 'package:flutter/material.dart';
import 'dart:convert'; // For JSON parsing
import 'package:flutter/services.dart'; // For loading local JSON file
import 'dart:async';
import 'package:url_launcher/url_launcher.dart';
import '../../Maps/map_screen1.dart';
import '../knowledge_packs_page.dart';
import 'article_detail_page.dart'; // For periodic animation updates

class EmergencyHomePageContent extends StatefulWidget {
  @override
  _EmergencyHomePageContentState createState() =>  _EmergencyHomePageContentState();
}

class _EmergencyHomePageContentState extends State<EmergencyHomePageContent> with SingleTickerProviderStateMixin {
  late AnimationController _animationController;
  bool _showMap = false;
  List<Map<String, dynamic>> knowledgePacks = []; // Store knowledge packs
  Map<String, int> currentArticleIndex = {}; // Keep track of current article index for each category

  @override
  void initState() {
    super.initState();
    _animationController = AnimationController(vsync: this, duration: Duration(seconds: 1))..repeat(reverse: true);
    _loadKnowledgePacks(); // Load knowledge packs from JSON file
  }

  // Load knowledge packs from local JSON file
  Future<void> _loadKnowledgePacks() async {
    String jsonString = await rootBundle.loadString('assets/knowledge_packs.json');
    List<dynamic> jsonResponse = json.decode(jsonString);

    setState(() {
      knowledgePacks = List<Map<String, dynamic>>.from(jsonResponse);

      // Initialize currentArticleIndex for each category
      for (var category in knowledgePacks) {
        currentArticleIndex[category['category']] = 0;
      }

      // Start the periodic timer to swap articles every few seconds
      _startArticleSwitching();
    });
  }

  // Start the timer to swap titles
  void _startArticleSwitching() {
    Timer.periodic(Duration(seconds: 3), (timer) {
      setState(() {
        for (var category in knowledgePacks) {
          // Ensure we cast to int explicitly
          int currentIndex = currentArticleIndex[category['category']]!;
          int nextIndex = (currentIndex + 1) % (category['articles'].length as int);
          currentArticleIndex[category['category']] = nextIndex;
        }
      });
    });
  }

  @override
  void dispose() {
    _animationController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Column(
      children: [
        // First Section (10% height)
        Expanded(
          flex: 1,
          child: Row(
            mainAxisAlignment: MainAxisAlignment.spaceEvenly,
            children: [
              _buildIconWithLabel(Icons.local_police, 'Police', Colors.blue, '911'),
              _buildIconWithLabel(Icons.local_fire_department, 'Fire Service', Colors.red, '101'),
              _buildIconWithLabel(Icons.local_hospital, 'Ambulance', Colors.red, '112'),
            ],
          ),
        ),

        // Second Section (50% height) - Either SOS or MapScreen1
        Expanded(
          flex: 7,
          child: Center(
            child: GestureDetector(
              onTap: () {
                setState(() {
                  _showMap = !_showMap; // Toggle the map screen display
                });
              },
              child: AnimatedBuilder(
                animation: _animationController,
                builder: (context, child) {
                  return Stack(
                    alignment: Alignment.center,
                    children: [
                      if (!_showMap) ...[
                        // Show SOS circle if not on the map screen
                        ...List.generate(3, (index) {
                          double scale = 1.4 - index * 0.2;
                          double opacity = 0.3 - index * 0.1;
                          return Transform.scale(
                            scale: scale + 0.05 * sin(_animationController.value * 2 * pi),
                            child: Container(
                              width: 160,
                              height: 160,
                              decoration: BoxDecoration(
                                shape: BoxShape.circle,
                                color: Colors.red.withOpacity(opacity),
                              ),
                            ),
                          );
                        }),
                        Transform.scale(
                          scale: 1 + 0.1 * sin(_animationController.value * 2 * pi),
                          child: Container(
                            width: 120,
                            height: 120,
                            decoration: BoxDecoration(
                              gradient: RadialGradient(
                                colors: [
                                  Colors.red.withOpacity(0.6),
                                  Colors.red,
                                ],
                                stops: [0.7, 1.0],
                              ),
                              shape: BoxShape.circle,
                            ),
                            child: Center(
                              child: Text(
                                'SOS',
                                style: TextStyle(
                                  color: Colors.white,
                                  fontWeight: FontWeight.bold,
                                  fontSize: 24,
                                ),
                              ),
                            ),
                          ),
                        ),
                        Positioned(
                          bottom: 20,
                          child: Text(
                            'Find Hospital',
                            style: TextStyle(
                              color: Colors.white,
                              fontWeight: FontWeight.bold,
                              fontSize: 18,
                            ),
                          ),
                        ),
                      ] else ...[
                        // Show the map screen when _showMap is true
                        MapScreen1(),
                      ],
                    ],
                  );
                },
              ),
            ),
          ),
        ),

        // Third Section (40% height) - Display categories and articles
        Expanded(
          flex: 2,
          child: Column(
            children: [
              Padding(
                padding: const EdgeInsets.symmetric(horizontal: 8.0),
                child: Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    Text(
                      'Categories',
                      style: TextStyle(
                        fontSize: 12,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                    GestureDetector(
                      onTap: () {
                        // Navigate to another page
                        Navigator.push(
                          context,
                          MaterialPageRoute(
                            builder: (context) => KnowledgePacksPage(),
                          ),
                        );
                      },
                      child: Text(
                        'See More',
                        style: TextStyle(
                          fontSize: 12,
                          color: Colors.blue,
                          fontWeight: FontWeight.w600,
                        ),
                      ),
                    ),
                  ],
                ),
              ),
              SizedBox(height: 6),
              Expanded(
                child: ListView(
                  scrollDirection: Axis.horizontal,
                  children: knowledgePacks.map((category) {
                    return _buildCategorySquareItem(category);
                  }).toList(),
                ),
              ),
            ],
          ),

        ),
        SizedBox(height: 50),
      ],
    );
  }



  Widget _buildIconWithLabel(IconData icon, String label, Color color, String phoneNumber) {
    return GestureDetector(
      onTap: () async {
        final Uri launchUri = Uri(
          scheme: 'tel',
          path: phoneNumber,
        );
        if (await canLaunchUrl(launchUri)) {
          await launchUrl(launchUri);
        } else {
          // Handle error when unable to launch the dialer
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: Text('Could not launch dialer for $phoneNumber'),
            ),
          );
        }
      },
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Icon(icon, size: 30, color: color),
          SizedBox(height: 4),
          Text(
            label,
            style: TextStyle(fontSize: 12, fontWeight: FontWeight.w500),
          ),
        ],
      ),
    );
  }


  // Build each category square item with animated titles
  Widget _buildCategorySquareItem(Map<String, dynamic> category) {
    int currentIndex = currentArticleIndex[category['category']]!;
    String currentTitle = category['articles'][currentIndex]['title'];
    String currentContent = category['articles'][currentIndex]['content'];

    return GestureDetector(
      onTap: () {
        // Navigate to the ArticleDetailPage with current title and content
        Navigator.push(
          context,
          MaterialPageRoute(
            builder: (context) => ArticleDetailPage(title: currentTitle, content: currentContent),
          ),
        );
      },
      child: Container(
        margin: EdgeInsets.symmetric(horizontal: 4),
        width: 200,
        height: 200,
        decoration: BoxDecoration(
          color: Colors.lightBlue[50], // Light blue background color
          border: Border.all(
            color: Colors.blue, // Outer border color
            width: 4, // Outer border width
          ),
          boxShadow: [
            BoxShadow(
              color: Colors.blue.withOpacity(0.2),
              spreadRadius: 2,
              blurRadius: 8,
              offset: Offset(0, 4),
            ),
          ],
          borderRadius: BorderRadius.circular(12),
        ),
        child: Container(
          margin: EdgeInsets.all(8), // Inner space for double border effect
          decoration: BoxDecoration(
            color: Colors.blue, // Inner color
            borderRadius: BorderRadius.circular(8),
          ),
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              // Display category name
              Text(
                category['category'],
                style: TextStyle(
                  color: Colors.white,
                  fontSize: 14,
                  fontWeight: FontWeight.bold,
                ),
              ),
              SizedBox(height: 4),
              // Display current article title with animation
              AnimatedSwitcher(
                duration: Duration(seconds: 1),
                child: Text(
                  currentTitle,
                  key: ValueKey<int>(currentIndex), // Ensure the key is unique for each article index
                  style: TextStyle(
                    color: Colors.white,
                    fontSize: 12,
                    fontWeight: FontWeight.bold,
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

}


