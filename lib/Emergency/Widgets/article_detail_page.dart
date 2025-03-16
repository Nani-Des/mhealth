import 'package:flutter/material.dart';

class ArticleDetailPage extends StatelessWidget {
  final String title;
  final String content;

  const ArticleDetailPage({required this.title, required this.content});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        elevation: 0,
        backgroundColor: Colors.teal,
        title: Text(
          title,
          style: const TextStyle(
            fontWeight: FontWeight.bold,
            color: Colors.white,
            fontSize: 20,
          ),
          maxLines: 2,
          overflow: TextOverflow.ellipsis,
        ),
        flexibleSpace: Container(
          decoration: BoxDecoration(
            gradient: LinearGradient(
              begin: Alignment.topLeft,
              end: Alignment.bottomRight,
              colors: [Colors.teal, Colors.teal.shade700],
            ),
          ),
        ),
        leading: IconButton(
          icon: const Icon(Icons.arrow_back_ios, color: Colors.white),
          onPressed: () => Navigator.pop(context),
        ),
      ),
      body: Container(
        decoration: BoxDecoration(
          gradient: LinearGradient(
            begin: Alignment.topCenter,
            end: Alignment.bottomCenter,
            colors: [Colors.teal.withOpacity(0.1), Colors.white],
          ),
        ),
        child: Padding(
          padding: const EdgeInsets.all(20.0),
          child: SingleChildScrollView(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                _buildTitle(),
                const SizedBox(height: 24),
                _buildContent(),
              ],
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildTitle() {
    return Container(
      padding: const EdgeInsets.all(16),
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
      child: Text(
        title,
        style: const TextStyle(
          fontSize: 28,
          fontWeight: FontWeight.bold,
          color: Colors.black87,
        ),
      ),
    );
  }

  Widget _buildContent() {
    return Container(
      padding: const EdgeInsets.all(16),
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
      child: RichText(
        text: TextSpan(
          style: const TextStyle(
            fontSize: 16,
            height: 1.6,
            color: Colors.black87,
          ),
          children: _formatContent(content),
        ),
      ),
    );
  }

  List<TextSpan> _formatContent(String text) {
    List<TextSpan> spans = [];
    List<String> lines = text.split("\n");

    // If it appears to be a single paragraph with steps (like from JSON)
    if (lines.length == 1) {
      String content = lines[0];
      RegExp stepPattern = RegExp(r'(\d+\.\s+[^.]+)');
      List<String> sentences = content.split('.').map((s) => s.trim()).where((s) => s.isNotEmpty).toList();

      for (String sentence in sentences) {
        if (stepPattern.hasMatch(sentence)) {
          spans.add(TextSpan(
            text: "$sentence.\n",
            style: const TextStyle(fontWeight: FontWeight.w600),
          ));
        } else {
          spans.add(TextSpan(
            text: "$sentence.\n",
            style: const TextStyle(fontWeight: FontWeight.normal),
          ));
        }
      }
    } else {
      // Handle multi-line content with existing formatting
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
            style: const TextStyle(fontSize: 20, fontWeight: FontWeight.bold),
          ));
        } else {
          spans.add(TextSpan(text: "$line\n"));
        }
      }
    }

    return spans;
  }
}