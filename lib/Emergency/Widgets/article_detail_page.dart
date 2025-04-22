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
            fontSize: 14,
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
            fontSize: 13,
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

    final RegExp emphasizePattern = RegExp(r'\b(To prevent|To treat)\b');

    TextSpan formatLine(String line) {
      final matches = emphasizePattern.allMatches(line);
      if (matches.isEmpty) {
        return TextSpan(text: "$line\n");
      }

      List<InlineSpan> children = [];
      int lastMatchEnd = 0;

      for (final match in matches) {
        if (match.start > lastMatchEnd) {
          children.add(TextSpan(text: line.substring(lastMatchEnd, match.start)));
        }

        children.add(TextSpan(
          text: match.group(0),
          style: const TextStyle(
            fontWeight: FontWeight.bold,
            color: Colors.teal,
          ),
        ));

        lastMatchEnd = match.end;
      }

      if (lastMatchEnd < line.length) {
        children.add(TextSpan(text: line.substring(lastMatchEnd)));
      }

      return TextSpan(children: children..add(const TextSpan(text: "\n")));
    }

    if (lines.length == 1) {
      String content = lines[0];
      List<String> sentences = content.split('.').map((s) => s.trim()).where((s) => s.isNotEmpty).toList();

      for (String sentence in sentences) {
        spans.add(formatLine(sentence));
      }
    } else {
      for (String line in lines) {
        if (line.trim().isEmpty) continue;

        TextSpan formatted = formatLine(line);

        if (line.startsWith("- ") || line.startsWith("• ")) {
          formatted = TextSpan(
            children: [
              TextSpan(
                text: "• ",
                style: const TextStyle(fontWeight: FontWeight.bold),
              ),
              ...formatted.children ?? [formatted]
            ],
          );
        } else if (line.startsWith("#")) {
          formatted = TextSpan(
            text: "${line.replaceAll("#", "")}\n",
            style: const TextStyle(fontSize: 20, fontWeight: FontWeight.bold),
          );
        }

        spans.add(formatted);
      }
    }

    return spans;
  }

}