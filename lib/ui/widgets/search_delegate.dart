import 'package:flutter/material.dart';
import 'package:quick_pdf/router/app_navigation.dart';
import 'package:quick_pdf/services/document_database.dart';

class DocumentSearchDelegate extends SearchDelegate<String?> {
  final DocumentDatabase _documentDatabase = DocumentDatabase();

  DocumentSearchDelegate() : super();

  @override
  List<Widget> buildActions(BuildContext context) {
    return [
      IconButton(
        icon: const Icon(Icons.clear),
        onPressed: () {
          query = '';
        },
      ),
    ];
  }

  @override
  Widget buildLeading(BuildContext context) {
    return IconButton(
      icon: const Icon(Icons.arrow_back),
      onPressed: () {
        close(context, null);
      },
    );
  }

  @override
  Widget buildResults(BuildContext context) {
    return _buildSearchResults(context);
  }

  @override
  Widget buildSuggestions(BuildContext context) {
    return _buildSearchResults(context);
  }

  Widget _buildSearchResults(BuildContext context) {
    return FutureBuilder<List<Map<String, dynamic>>>(
      future: _documentDatabase.searchDocuments(query),
      builder: (context, snapshot) {
        if (snapshot.connectionState == ConnectionState.waiting) {
          return const Center(child: CircularProgressIndicator());
        }

        if (snapshot.hasError) {
          return Center(child: Text('Error: ${snapshot.error}'));
        }

        final matchingDocuments = snapshot.data ?? [];

        if (matchingDocuments.isEmpty) {
          return Center(
            child: Text(
              query.isEmpty ? 'No recent documents' : 'No results found for "$query"',
              textAlign: TextAlign.center,
            ),
          );
        }

        return ListView.builder(
          itemCount: matchingDocuments.length,
          itemBuilder: (context, index) {
            final doc = matchingDocuments[index];
            return _buildSearchResultItem(context, doc);
          },
        );
      },
    );
  }

  Widget _buildSearchResultItem(BuildContext context, Map<String, dynamic> doc) {
    final String path = doc['path'] ?? '';
    final String name = doc['name'] ?? 'Unknown';
    final int size = doc['size'] ?? 0;
    final String dateAdded = doc['dateAdded']?.toString() ?? '';
    final String textContent = doc['text_content'] ?? '';

    // Determine match type for highlighting
    final bool nameMatches = query.isNotEmpty && name.toLowerCase().contains(query.toLowerCase());
    final bool contentMatches = query.isNotEmpty && textContent.toLowerCase().contains(query.toLowerCase());

    return ListTile(
      leading: const Icon(Icons.picture_as_pdf, color: Colors.red),
      title: _buildHighlightedText(name, query, nameMatches ? Colors.orange : null),
      subtitle: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            '${(size / 1024).toStringAsFixed(1)} KB • ${_formatDate(dateAdded)}',
            style: TextStyle(
              color: Colors.grey[600],
              fontSize: 12,
            ),
          ),
          if (contentMatches && textContent.isNotEmpty)
            Padding(
              padding: const EdgeInsets.only(top: 4.0),
              child: _buildHighlightedText(
                _snippetText(textContent, query, 100),
                query,
                Colors.blueAccent,
              ),
            ),
        ],
      ),
      onTap: () {
        close(context, path);
        context.openPdfViewer(path);
      },
    );
  }

  Widget _buildHighlightedText(String text, String query, Color? highlightColor) {
    if (query.isEmpty || text.isEmpty) {
      return Text(text);
    }

    final queryLower = query.toLowerCase();
    final textLower = text.toLowerCase();
    final List<TextSpan> spans = [];
    int start = 0;

    while (start < text.length) {
      final index = textLower.indexOf(queryLower, start);
      if (index == -1) {
        // No more matches, add remaining text
        spans.add(TextSpan(
          text: text.substring(start),
        ));
        break;
      }

      // Add text before match
      if (index > start) {
        spans.add(TextSpan(
          text: text.substring(start, index),
        ));
      }

      // Add matched text with highlight
      spans.add(TextSpan(
        text: text.substring(index, index + query.length),
        style: TextStyle(
          fontWeight: FontWeight.bold,
          backgroundColor: highlightColor?.withValues(alpha: 0.2),
        ),
      ));

      start = index + query.length;
    }

    return Text.rich(TextSpan(children: spans));
  }

  String _snippetText(String text, String query, int maxLength) {
    if (text.isEmpty || query.isEmpty) {
      return text.length > maxLength ? '${text.substring(0, maxLength)}...' : text;
    }

    final queryLower = query.toLowerCase();
    final textLower = text.toLowerCase();
    final index = textLower.indexOf(queryLower);

    if (index == -1) {
      return text.length > maxLength ? '${text.substring(0, maxLength)}...' : text;
    }

    // Calculate start position to show context around the match
    int start = index - (maxLength ~/ 2);
    if (start < 0) start = 0;
    
    int end = start + maxLength;
    if (end > text.length) {
      end = text.length;
      start = text.length - maxLength;
      if (start < 0) start = 0;
    }

    String result = text.substring(start, end);
    if (start > 0) result = '...$result';
    if (end < text.length) result = '$result...';
    
    return result;
  }

  String _formatDate(String dateString) {
    try {
      final date = DateTime.parse(dateString);
      return '${date.year}-${date.month.toString().padLeft(2, '0')}-${date.day.toString().padLeft(2, '0')}';
    } catch (e) {
      return dateString;
    }
  }

  @override
  String get searchFieldLabel => 'Search documents by name or content';
}