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
  late Map<String, List<Map<String, dynamic>>> localArticles;

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
    setState(() => isLoading = true);
    localArticles = await loadLocalData();
    final remoteData = await fetchRemoteData();

    final combinedData = {...localArticles};
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
    setState(() {}); // Refresh UI to reflect download status
    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(content: Text("Article downloaded for offline use!")),
    );
  }

  Future<String?> getOfflineArticle(String title) async {
    if (knowledgePackBox.containsKey(title)) {
      return knowledgePackBox.get(title);
    }
    for (var category in localArticles.values) {
      for (var article in category) {
        if (article['title'] == title) {
          return article['content'];
        }
      }
    }
    return null;
  }

  @override
  void dispose() {
    knowledgePackBox.close();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        elevation: 0,
        backgroundColor: Colors.tealAccent,
        title: const Row(
          children: [
            Icon(Icons.book, color: Colors.white),
            SizedBox(width: 8),
            Text(
              "Knowledge Packs",
              style: TextStyle(
                fontWeight: FontWeight.bold,
                color: Colors.white,
              ),
            ),
          ],
        ),
        flexibleSpace: Container(
          decoration: BoxDecoration(
            gradient: LinearGradient(
              begin: Alignment.topLeft,
              end: Alignment.bottomRight,
              colors: [Colors.tealAccent, Colors.tealAccent.shade700],
            ),
          ),
        ),
      ),
      body: Container(
        decoration: BoxDecoration(
          gradient: LinearGradient(
            begin: Alignment.topCenter,
            end: Alignment.bottomCenter,
            colors: [Colors.tealAccent.withOpacity(0.1), Colors.white],
          ),
        ),
        child: isLoading
            ? _buildLoadingState()
            : categorizedArticles.isEmpty
            ? _buildEmptyState()
            : ListView.builder(
          padding: const EdgeInsets.all(16),
          itemCount: categorizedArticles.keys.length,
          itemBuilder: (context, index) {
            final category = categorizedArticles.keys.elementAt(index);
            final articles = categorizedArticles[category]!;
            return _buildCategorySection(category, articles);
          },
        ),
      ),
    );
  }

  Widget _buildLoadingState() {
    return Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          CircularProgressIndicator(
            valueColor: AlwaysStoppedAnimation<Color>(Colors.tealAccent),
          ),
          const SizedBox(height: 16),
          Text(
            "Loading Knowledge Packs...",
            style: TextStyle(color: Colors.grey[600], fontSize: 16),
          ),
        ],
      ),
    );
  }

  Widget _buildEmptyState() {
    return Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Icon(Icons.book_outlined, size: 64, color: Colors.grey[400]),
          const SizedBox(height: 16),
          Text(
            "No Knowledge Packs Available",
            style: TextStyle(fontSize: 18, color: Colors.grey[600]),
          ),
        ],
      ),
    );
  }

  Widget _buildCategorySection(String category, List<Map<String, dynamic>> articles) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 16),
      child: Card(
        elevation: 4,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
        child: ExpansionTile(
          leading: Icon(Icons.folder, color: Colors.teal),
          title: Text(
            category,
            style: const TextStyle(
              fontSize: 18,
              fontWeight: FontWeight.bold,
              color: Colors.black87,
            ),
          ),
          tilePadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
          children: [
            Container(
              padding: const EdgeInsets.all(16),
              child: GridView.builder(
                shrinkWrap: true,
                physics: const NeverScrollableScrollPhysics(),
                gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
                  crossAxisCount: 2,
                  crossAxisSpacing: 16,
                  mainAxisSpacing: 16,
                  childAspectRatio: 0.85,
                ),
                itemCount: articles.length,
                itemBuilder: (context, articleIndex) {
                  final article = articles[articleIndex];
                  return _buildArticleCard(article);
                },
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildArticleCard(Map<String, dynamic> article) {
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
          return AnimatedContainer(
            duration: const Duration(milliseconds: 300),
            decoration: BoxDecoration(
              color: Colors.white,
              borderRadius: BorderRadius.circular(16),
              boxShadow: [
                BoxShadow(
                  color: Colors.grey.withOpacity(0.2),
                  spreadRadius: 2,
                  blurRadius: 8,
                  offset: const Offset(0, 4),
                ),
              ],
            ),
            child: Stack(
              children: [
                Column(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    Container(
                      padding: const EdgeInsets.all(12),
                      decoration: BoxDecoration(
                        color: Colors.teal.withOpacity(0.1),
                        borderRadius: const BorderRadius.vertical(top: Radius.circular(16)),
                      ),
                      child: Icon(
                        Icons.article,
                        size: 40,
                        color: Colors.teal,
                      ),
                    ),
                    Expanded(
                      child: Padding(
                        padding: const EdgeInsets.all(12),
                        child: Text(
                          article['title'],
                          textAlign: TextAlign.center,
                          style: const TextStyle(
                            fontSize: 14,
                            fontWeight: FontWeight.w600,
                            color: Colors.black87,
                          ),
                          maxLines: 3,
                          overflow: TextOverflow.ellipsis,
                        ),
                      ),
                    ),
                  ],
                ),
                if (!isOffline)
                  Positioned(
                    bottom: 8,
                    right: 8,
                    child: GestureDetector(
                      onTap: () async {
                        await saveArticleOffline(article['title'], article['content']);
                      },
                      child: Container(
                        padding: const EdgeInsets.all(6),
                        decoration: BoxDecoration(
                          color: Colors.redAccent,
                          shape: BoxShape.circle,
                          boxShadow: [
                            BoxShadow(
                              color: Colors.redAccent.withOpacity(0.3),
                              spreadRadius: 2,
                              blurRadius: 4,
                            ),
                          ],
                        ),
                        child: const Icon(
                          Icons.download,
                          color: Colors.white,
                          size: 20,
                        ),
                      ),
                    ),
                  ),
                if (isOffline)
                  Positioned(
                    top: 8,
                    right: 8,
                    child: Container(
                      padding: const EdgeInsets.all(4),
                      decoration: const BoxDecoration(
                        color: Colors.lightGreenAccent,
                        shape: BoxShape.circle,
                      ),
                      child: const Icon(
                        Icons.offline_pin,
                        color: Colors.white,
                        size: 16,
                      ),
                    ),
                  ),
              ],
            ),
          );
        },
      ),
    );
  }
}