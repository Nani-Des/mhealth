import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'dart:convert';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:hive/hive.dart';

import 'Widgets/article_detail_page.dart';

class KnowledgePacksPage extends StatefulWidget {
  @override
  _KnowledgePacksPageState createState() => _KnowledgePacksPageState();
}

class _KnowledgePacksPageState extends State<KnowledgePacksPage> {
  Map<String, List<Map<String, dynamic>>> categorizedArticles = {};
  bool isLoading = true;
  late Box<String> knowledgePackBox;
  late Map<String, List<Map<String, dynamic>>> localArticles; // Local articles from JSON

  @override
  void initState() {
    super.initState();
    initializeHive();
    loadAllArticles();
  }

  Future<void> initializeHive() async {
    knowledgePackBox = await Hive.openBox<String>('knowledge_packs');
  }

  Future<void> loadAllArticles() async {
    setState(() {
      isLoading = true;
    });

    // Load local data (from JSON)
    localArticles = await loadLocalData();

    // Fetch remote data (from Firebase)
    final remoteData = await fetchRemoteData();

    // Combine local (JSON) and remote (Firebase) data
    final combinedData = {...localArticles}; // Copy local data

    remoteData.forEach((category, articles) {
      combinedData.putIfAbsent(category, () => []);
      combinedData[category]!.addAll(articles);
    });

    setState(() {
      categorizedArticles = combinedData;
      isLoading = false;
    });
  }

  Future<Map<String, List<Map<String, dynamic>>>> loadLocalData() async {
    final String response = await rootBundle.loadString('assets/knowledge_packs.json');
    final List<dynamic> data = json.decode(response);

    final Map<String, List<Map<String, dynamic>>> categorized = {};
    for (final categoryData in data) {
      final category = categoryData['category'];
      final articles = List<Map<String, dynamic>>.from(categoryData['articles']);
      categorized[category] = articles;
    }
    return categorized;
  }

  Future<Map<String, List<Map<String, dynamic>>>> fetchRemoteData() async {
    final snapshot = await FirebaseFirestore.instance.collection('KnowledgePacks').get();

    final Map<String, List<Map<String, dynamic>>> categorized = {};
    for (final doc in snapshot.docs) {
      final data = doc.data();
      final category = data['Category'];
      final articles = List<Map<String, dynamic>>.from(data['articles']);

      categorized.putIfAbsent(category, () => []);
      // Ensure the article data is not null before adding it
      for (final article in articles) {
        if (article['title'] != null && article['content'] != null) {
          categorized[category]!.add(article);
        }
      }
    }
    return categorized;
  }

  Future<void> saveArticleOffline(String title, String content) async {
    await knowledgePackBox.put(title, content);
  }

  Future<String?> getOfflineArticle(String title) async {
    // Check Hive and local (JSON) data
    if (knowledgePackBox.containsKey(title)) {
      return knowledgePackBox.get(title);
    }

    // Check if article exists in local (JSON)
    for (var category in localArticles.values) {
      for (var article in category) {
        if (article['title'] == title) {
          return article['content']; // Return content from JSON
        }
      }
    }

    return null; // If the article is not found in either Hive or JSON
  }

  @override
  void dispose() {
    knowledgePackBox.close(); // Close the Hive box
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: Text('Knowledge Packs'),
      ),
      body: isLoading
          ? Center(child: CircularProgressIndicator())
          : ListView.builder(
        itemCount: categorizedArticles.keys.length,
        itemBuilder: (context, index) {
          final category = categorizedArticles.keys.elementAt(index);
          final articles = categorizedArticles[category]!;
          return ExpansionTile(
            title: Text(
              category,
              style: TextStyle(fontWeight: FontWeight.bold),
            ),
            children: [
              GridView.builder(
                shrinkWrap: true,
                physics: NeverScrollableScrollPhysics(),
                gridDelegate: SliverGridDelegateWithFixedCrossAxisCount(
                  crossAxisCount: 2,
                  crossAxisSpacing: 10,
                  mainAxisSpacing: 10,
                  childAspectRatio: 1,
                ),
                itemCount: articles.length,
                  itemBuilder: (context, articleIndex) {
                    final article = articles[articleIndex];
                    return GestureDetector(
                      onTap: () async {
                        final offlineContent = await getOfflineArticle(article['title']);
                        Navigator.push(
                          context,
                          MaterialPageRoute(
                            builder: (context) => ArticleDetailPage(
                              title: article['title'],
                              content: offlineContent ?? article['content'],
                            ),
                          ),
                        );
                      },
                      child: FutureBuilder<String?>(
                        future: getOfflineArticle(article['title']),
                        builder: (context, snapshot) {
                          final isOffline = snapshot.hasData && snapshot.data != null;

                          return Container(
                            margin: EdgeInsets.all(8.0),
                            decoration: BoxDecoration(
                              border: Border.all(color: Colors.blueAccent, width: 2),
                              borderRadius: BorderRadius.circular(15),
                              color: Colors.white,
                              boxShadow: [
                                BoxShadow(
                                  color: Colors.grey.withOpacity(0.5),
                                  spreadRadius: 3,
                                  blurRadius: 7,
                                  offset: Offset(0, 3),
                                ),
                              ],
                            ),
                            child: Stack(
                              children: [
                                Center(
                                  child: Column(
                                    mainAxisAlignment: MainAxisAlignment.center,
                                    children: [
                                      Icon(Icons.article, size: 40, color: Colors.blueAccent),
                                      SizedBox(height: 10),
                                      Text(
                                        article['title'],
                                        textAlign: TextAlign.center,
                                        style: TextStyle(
                                          fontWeight: FontWeight.bold,
                                          color: Colors.blueAccent,
                                        ),
                                      ),
                                    ],
                                  ),
                                ),
                                if (!isOffline)
                                  Positioned(
                                    bottom: 8,
                                    right: 8,
                                    child: GestureDetector(
                                      onTap: () async {
                                        // Save the article content offline (in Hive) when the download icon is tapped
                                        await saveArticleOffline(article['title'], article['content']);
                                        // Optionally, show a message or feedback to the user indicating the article has been downloaded
                                        ScaffoldMessenger.of(context).showSnackBar(SnackBar(
                                          content: Text("Article downloaded for offline use!"),
                                        ));
                                      },
                                      child: Icon(
                                        Icons.download,
                                        color: Colors.red,
                                        size: 20,
                                      ),
                                    ),
                                  ),
                              ],
                            ),
                          );
                        },
                      ),
                    );
                  },

              ),
            ],
          );
        },
      ),
    );
  }
}

