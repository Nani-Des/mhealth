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

class _KnowledgePacksPageState extends State<KnowledgePacksPage> with SingleTickerProviderStateMixin {
  Map<String, List<Map<String, dynamic>>> categorizedArticles = {};
  bool isLoading = true;
  late Box<String> knowledgePackBox;
  late Box<String> archivedArticlesBox;
  late Map<String, List<Map<String, dynamic>>> localArticles;
  bool showArchived = false;

  late AnimationController _progressAnimationController;
  late Animation<double> _progressAnimation;

  @override
  void initState() {
    super.initState();
    _initializeData();

    _progressAnimationController = AnimationController(
      vsync: this,
      duration: Duration(seconds: 2),
    )..repeat();
    _progressAnimation = Tween<double>(begin: 0, end: 1).animate(_progressAnimationController);
  }

  Future<void> _initializeData() async {
    await initializeHive();
    await loadAllArticles();
  }

  Future<void> initializeHive() async {
    knowledgePackBox = await Hive.openBox<String>('knowledge_packs');
    archivedArticlesBox = await Hive.openBox<String>('archived_articles');
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
    setState(() {});
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text("Downloaded: $title", style: TextStyle(color: Colors.white)),
        backgroundColor: Colors.teal,
      ),
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

  Future<void> toggleArchiveArticle(String title, String content) async {
    if (archivedArticlesBox.containsKey(title)) {
      await archivedArticlesBox.delete(title);
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text("Unarchived: $title", style: TextStyle(color: Colors.white)),
          backgroundColor: Colors.orange,
        ),
      );
    } else {
      await archivedArticlesBox.put(title, content);
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text("Archived: $title", style: TextStyle(color: Colors.white)),
          backgroundColor: Colors.teal,
        ),
      );
    }
    setState(() {});
  }

  Map<String, List<Map<String, dynamic>>> getFilteredArticles() {
    if (!showArchived) {
      return categorizedArticles;
    }
    final Map<String, List<Map<String, dynamic>>> archived = {};
    for (var category in categorizedArticles.keys) {
      final articles = categorizedArticles[category]!
          .where((article) => archivedArticlesBox.containsKey(article['title']))
          .toList();
      if (articles.isNotEmpty) {
        archived[category] = articles;
      }
    }
    return archived;
  }

  @override
  void dispose() {
    knowledgePackBox.close();
    archivedArticlesBox.close();
    _progressAnimationController.dispose();
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
    if (isLoading) {
      return Scaffold(
        body: _buildLoadingState(),
      );
    }

    final filteredArticles = getFilteredArticles();
    final archivedCount = archivedArticlesBox.length;

    return Scaffold(
      appBar: AppBar(
        elevation: 2,
        backgroundColor: Colors.teal,
        title: Row(
          children: [
            Icon(Icons.book, color: Colors.white),
            SizedBox(width: 8),
            Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  showArchived ? "Archived Packs" : "Knowledge Packs",
                  style: TextStyle(fontWeight: FontWeight.bold, color: Colors.white, fontSize: 14),
                ),
                if (archivedCount > 0)
                  Text(
                    "$archivedCount archived",
                    style: TextStyle(color: Colors.white70, fontSize: 12),
                  ),
              ],
            ),
          ],
        ),
        flexibleSpace: Container(
          decoration: BoxDecoration(
            gradient: LinearGradient(
              begin: Alignment.topLeft,
              end: Alignment.bottomRight,
              colors: [Colors.teal.shade700, Colors.teal.shade400],
            ),
          ),
        ),
        actions: [
          IconButton(
            icon: Icon(showArchived ? Icons.view_list : Icons.archive, color: Colors.white),
            onPressed: () => setState(() => showArchived = !showArchived),
            tooltip: showArchived ? "Show All" : "Show Archived",
          ),
        ],
      ),
      body: Container(
        decoration: BoxDecoration(
          gradient: LinearGradient(
            begin: Alignment.topCenter,
            end: Alignment.bottomCenter,
            colors: [Colors.teal.shade50, Colors.white],
          ),
        ),
        child: filteredArticles.isEmpty
            ? _buildEmptyState()
            : ListView.builder(
          padding: const EdgeInsets.all(16),
          itemCount: filteredArticles.keys.length,
          itemBuilder: (context, index) {
            final category = filteredArticles.keys.elementAt(index);
            final articles = filteredArticles[category]!;
            return _buildCategorySection(category, articles);
          },
        ),
      ),
      floatingActionButton: FloatingActionButton(
        onPressed: () => setState(() => showArchived = !showArchived),
        backgroundColor: Colors.teal,
        child: Icon(showArchived ? Icons.view_list : Icons.archive),
        tooltip: showArchived ? "Show All" : "Show Archived",
      ),
    );
  }

  Widget _buildLoadingState() {
    return Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          _buildSophisticatedProgressIndicator(),
          const SizedBox(height: 16),
          Text(
            "Loading Knowledge Packs...",
            style: TextStyle(color: Colors.teal.shade700, fontSize: 14, fontWeight: FontWeight.w500),
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
          Icon(Icons.book_outlined, size: 80, color: Colors.teal.shade200),
          const SizedBox(height: 16),
          Text(
            showArchived ? "No Archived Packs" : "No Knowledge Packs Available",
            style: TextStyle(fontSize: 14, color: Colors.teal.shade700, fontWeight: FontWeight.bold),
          ),
          const SizedBox(height: 8),
          Text(
            showArchived ? "Archive some packs to see them here!" : "Check back later for new content.",
            style: TextStyle(fontSize: 14, color: Colors.grey.shade600),
          ),
        ],
      ),
    );
  }

  Widget _buildCategorySection(String category, List<Map<String, dynamic>> articles) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 12),
      child: Card(
        elevation: 6,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
        child: ExpansionTile(
          leading: Icon(Icons.folder_open, color: Colors.teal.shade600),
          title: Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Text(
                category,
                style: TextStyle(
                  fontSize: 14,
                  fontWeight: FontWeight.bold,
                  color: Colors.teal.shade800,
                ),
              ),
              Container(
                padding: EdgeInsets.symmetric(horizontal: 8, vertical: 2),
                decoration: BoxDecoration(
                  color: Colors.teal.shade100,
                  borderRadius: BorderRadius.circular(12),
                ),
                child: Text(
                  "${articles.length}",
                  style: TextStyle(color: Colors.teal.shade800, fontSize: 12),
                ),
              ),
            ],
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
          final isArchived = archivedArticlesBox.containsKey(article['title']);
          return AnimatedScale(
            scale: 1.0,
            duration: Duration(milliseconds: 200),
            child: Container(
              decoration: BoxDecoration(
                color: Colors.white,
                borderRadius: BorderRadius.circular(16),
                boxShadow: [
                  BoxShadow(
                    color: Colors.teal.shade100.withOpacity(0.3),
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
                          color: Colors.teal.shade50,
                          borderRadius: const BorderRadius.vertical(top: Radius.circular(16)),
                        ),
                        child: Icon(
                          Icons.article,
                          size: 40,
                          color: Colors.teal.shade600,
                        ),
                      ),
                      Expanded(
                        child: Padding(
                          padding: const EdgeInsets.all(12),
                          child: Text(
                            article['title'],
                            textAlign: TextAlign.center,
                            style: TextStyle(
                              fontSize: 14,
                              fontWeight: FontWeight.w600,
                              color: Colors.teal.shade900,
                            ),
                            maxLines: 3,
                            overflow: TextOverflow.ellipsis,
                          ),
                        ),
                      ),
                    ],
                  ),
                  Positioned(
                    top: 8,
                    right: 8,
                    child: Row(
                      children: [
                        if (isOffline)
                          Container(
                            padding: const EdgeInsets.all(4),
                            decoration: BoxDecoration(
                              color: Colors.green.shade400,
                              shape: BoxShape.circle,
                            ),
                            child: Icon(Icons.offline_pin, color: Colors.white, size: 16),
                          ),
                        if (!isOffline)
                          Tooltip(
                            message: "Download for offline use",
                            child: GestureDetector(
                              onTap: () async {
                                await saveArticleOffline(article['title'], article['content']);
                              },
                              child: Container(
                                padding: const EdgeInsets.all(6),
                                decoration: BoxDecoration(
                                  color: Colors.redAccent.shade400,
                                  shape: BoxShape.circle,
                                  boxShadow: [
                                    BoxShadow(
                                      color: Colors.redAccent.withOpacity(0.3),
                                      spreadRadius: 1,
                                      blurRadius: 4,
                                    ),
                                  ],
                                ),
                                child: Icon(Icons.download, color: Colors.white, size: 20),
                              ),
                            ),
                          ),
                      ],
                    ),
                  ),
                  Positioned(
                    bottom: 8,
                    left: 8,
                    child: Tooltip(
                      message: isArchived ? "Unarchive" : "Archive",
                      child: GestureDetector(
                        onTap: () async {
                          await toggleArchiveArticle(article['title'], article['content']);
                        },
                        child: Container(
                          padding: const EdgeInsets.all(6),
                          decoration: BoxDecoration(
                            color: isArchived ? Colors.orange.shade600 : Colors.grey.shade600,
                            shape: BoxShape.circle,
                            boxShadow: [
                              BoxShadow(
                                color: (isArchived ? Colors.orange : Colors.grey).withOpacity(0.3),
                                spreadRadius: 1,
                                blurRadius: 4,
                              ),
                            ],
                          ),
                          child: Icon(
                            isArchived ? Icons.unarchive : Icons.archive,
                            color: Colors.white,
                            size: 20,
                          ),
                        ),
                      ),
                    ),
                  ),
                ],
              ),
            ),
          );
        },
      ),
    );
  }
}