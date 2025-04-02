import 'dart:math';
import 'package:flutter/material.dart';
import 'dart:convert'; // For JSON parsing
import 'package:flutter/services.dart';
import 'dart:async';
import '../../Maps/map_screen1.dart';
import '../knowledge_packs_page.dart';
import 'article_detail_page.dart'; // For periodic animation updates

class EmergencyHomePageContent extends StatefulWidget {
  @override
  _EmergencyHomePageContentState createState() => _EmergencyHomePageContentState();
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
      if (!mounted) return; // Avoid setState if widget is disposed
      setState(() {
        for (var category in knowledgePacks) {
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
  @override
  Widget build(BuildContext context) {
    return SingleChildScrollView(
      child: SizedBox(
        height: MediaQuery.of(context).size.height - kToolbarHeight, // Full height minus AppBar
        child: Column(
          children: [
            Expanded(
              flex: 6,
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

            // Third Section (20% height) - Dipslay categories and articles
            Expanded(
              flex: 2,
              child: Column(
                children: [
                  Padding(
                    padding: const EdgeInsets.all(10.0),
                    child: Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        Text(
                          'Knowledge Packs',
                          style: TextStyle(
                            fontSize: 12,
                            fontWeight: FontWeight.bold,
                          ),
                        ),
                        GestureDetector(
                          onTap: () {
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
                              color: Colors.teal,
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
            Expanded(
              flex: 2,
              child: Column(),
            )
            // Space for input area in parent widget
          ],
        ),
      ),
    );
  }

  Widget _buildCategorySquareItem(Map<String, dynamic> category) {
    int currentIndex = currentArticleIndex[category['category']]!;
    String currentTitle = category['articles'][currentIndex]['title'];
    String currentContent = category['articles'][currentIndex]['content'];

    return GestureDetector(
      onTap: () {
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
          color: Colors.lightGreen[50],
          border: Border.all(
            color: Colors.teal,
            width: 4,
          ),
          boxShadow: [
            BoxShadow(
              color: Colors.teal.withOpacity(0.2),
              spreadRadius: 2,
              blurRadius: 8,
              offset: Offset(0, 4),
            ),
          ],
          borderRadius: BorderRadius.circular(12),
        ),
        child: Container(
          margin: EdgeInsets.all(8),
          decoration: BoxDecoration(
            color: Colors.teal,
            borderRadius: BorderRadius.circular(8),
          ),
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Text(
                category['category'],
                style: TextStyle(
                  color: Colors.white,
                  fontSize: 14,
                  fontWeight: FontWeight.bold,
                ),
              ),
              SizedBox(height: 4),
              AnimatedSwitcher(
                duration: Duration(seconds: 1),
                child: Text(
                  currentTitle,
                  key: ValueKey<int>(currentIndex),
                  style: TextStyle(
                    color: Colors.white,
                    fontSize: 14,
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