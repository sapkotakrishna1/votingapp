import 'dart:convert';
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:http/http.dart' as http;
import 'package:url_launcher/url_launcher.dart';
import 'package:xml/xml.dart' as xml;

class NewsPage extends StatefulWidget {
  const NewsPage({super.key});

  @override
  State<NewsPage> createState() => _NewsPageState();
}

class _NewsPageState extends State<NewsPage> {
  List<NewsItem> allNews = [];
  bool isLoadingNews = true;

  @override
  void initState() {
    super.initState();
    fetchAllNews();
  }

  // =======================
  // Normalize BBC RSS image URLs
  // =======================
  String? normalizeImageUrl(String? url) {
    if (url == null || url.isEmpty) return null;
    url = url.trim();
    if (url.startsWith('//')) {
      return 'https:$url';
    } else if (url.startsWith('/')) {
      return 'https://www.bbc.com$url';
    } else if (!url.startsWith('http')) {
      return 'https://www.bbc.com/$url';
    }
    return url;
  }

  // =======================
  // Fetch Nepali News (BBC RSS)
  // =======================
  Future<List<NewsItem>> fetchNepaliNews() async {
    try {
      final rssUrl = "https://www.bbc.com/nepali/index.xml";
      final url = kIsWeb
          ? Uri.parse(
              'https://api.allorigins.win/raw?url=${Uri.encodeComponent(rssUrl)}')
          : Uri.parse(rssUrl);

      final response =
          await http.get(url, headers: {"Accept": "application/xml"});

      if (response.statusCode == 200) {
        final document = xml.XmlDocument.parse(response.body);
        final items = document.findAllElements('item');

        return items.map((node) {
          final description = node.getElement('description')?.text ?? '';

          // 1️⃣ Try <enclosure>
          String? imgUrl = node.getElement('enclosure')?.getAttribute('url');

          // 2️⃣ Try <media:content>
          if (imgUrl == null || imgUrl.isEmpty) {
            final mediaContent = node.getElement('media:content',
                namespace: 'http://search.yahoo.com/mrss/');
            imgUrl = mediaContent?.getAttribute('url');
          }

          // 3️⃣ Fallback: extract <img> from description HTML
          if (imgUrl == null || imgUrl.isEmpty) {
            final regex =
                RegExp(r'<img[^>]+src="([^">]+)"', caseSensitive: false);
            imgUrl = regex.firstMatch(description)?.group(1);
          }

          // Normalize URL
          imgUrl = normalizeImageUrl(imgUrl);

          // Clean HTML tags from description
          final cleanDescription =
              description.replaceAll(RegExp(r'<[^>]*>'), '');

          return NewsItem(
            title: node.getElement('title')?.text ?? '',
            description: cleanDescription,
            url: node.getElement('link')?.text ?? '',
            imageUrl: imgUrl ?? '',
            source: 'Nepali',
          );
        }).toList();
      }
    } catch (e) {
      print("Error fetching Nepali news: $e");
    }
    return [];
  }

  Future<List<NewsItem>> fetchRatopatiNews() async {
    try {
      final rssUrl = "https://www.ratopati.com/rss";
      final url = kIsWeb
          ? Uri.parse(
              'https://api.allorigins.win/raw?url=${Uri.encodeComponent(rssUrl)}')
          : Uri.parse(rssUrl);

      final response =
          await http.get(url, headers: {"Accept": "application/xml"});

      if (response.statusCode == 200) {
        final document = xml.XmlDocument.parse(response.body);
        final items = document.findAllElements('item');

        return items.map((node) {
          final description = node.getElement('description')?.text ?? '';

          // Try to extract image from <img> tag in description
          String? imgUrl;
          final regex =
              RegExp(r'<img[^>]+src="([^">]+)"', caseSensitive: false);
          imgUrl = regex.firstMatch(description)?.group(1);
          imgUrl = imgUrl != null ? normalizeImageUrl(imgUrl) : null;

          final cleanDescription =
              description.replaceAll(RegExp(r'<[^>]*>'), '');

          return NewsItem(
            title: node.getElement('title')?.text ?? '',
            description: cleanDescription,
            url: node.getElement('link')?.text ?? '',
            imageUrl: imgUrl,
            source: 'RatoPati',
          );
        }).toList();
      }
    } catch (e) {
      print("Error fetching RatoPati news: $e");
    }

    return [];
  }

  // =======================
  // Fetch English News (NewsAPI)
  // =======================
  Future<List<NewsItem>> fetchEnglishNews() async {
    try {
      final newsApiUrl =
          "https://newsapi.org/v2/top-headlines?country=us&apiKey=YOUR_NEWSAPI_KEY";

      final url = kIsWeb
          ? Uri.parse(
              'https://api.allorigins.win/raw?url=${Uri.encodeComponent(newsApiUrl)}')
          : Uri.parse(newsApiUrl);

      final response =
          await http.get(url, headers: {"Accept": "application/json"});

      if (response.statusCode == 200) {
        final data = jsonDecode(response.body);
        final List articles = data['articles'] ?? [];

        return articles.map((a) {
          return NewsItem(
            title: a['title'] ?? '',
            description: a['description'] ?? '',
            url: a['url'] ?? '',
            imageUrl: a['urlToImage'] ?? '',
            source: 'English',
          );
        }).toList();
      }
    } catch (e) {
      print("Error fetching English news: $e");
    }
    return [];
  }

  // =======================
  // Fetch All News
  // =======================
  Future<void> fetchAllNews() async {
    setState(() => isLoadingNews = true);

    final nepali = await fetchNepaliNews();
    final ratopati = await fetchRatopatiNews();

    List<NewsItem> combined = [];
    int maxLength =
        nepali.length > ratopati.length ? nepali.length : ratopati.length;

    for (int i = 0; i < maxLength; i++) {
      if (i < nepali.length) combined.add(nepali[i]);
      if (i < ratopati.length) combined.add(ratopati[i]);
    }

    setState(() {
      allNews = combined;
      isLoadingNews = false;
    });
  }

  // =======================
  // Open news link
  // =======================
  Future<void> openNews(String url) async {
    final uri = Uri.parse(url);
    if (await canLaunchUrl(uri)) {
      await launchUrl(uri, mode: LaunchMode.externalApplication);
    } else {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text("Could not launch news link")),
      );
    }
  }

  // =======================
  // News Card Widget (Side Image Layout)
  // =======================
  Widget newsCard(NewsItem news) {
    return InkWell(
      onTap: () => openNews(news.url),
      child: Card(
        color: Colors.white12,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
        margin: const EdgeInsets.only(bottom: 16),
        child: SizedBox(
          height: 150,
          child: Row(
            children: [
              // Text Section - 60%
              Expanded(
                flex: 10,
                child: Padding(
                  padding: const EdgeInsets.all(12),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        news.title,
                        style: const TextStyle(
                            color: Colors.white,
                            fontSize: 16,
                            fontWeight: FontWeight.bold),
                        maxLines: 2,
                        overflow: TextOverflow.ellipsis,
                      ),
                      const SizedBox(height: 6),
                      Expanded(
                        child: Text(
                          news.description,
                          maxLines: 4,
                          overflow: TextOverflow.ellipsis,
                          style: const TextStyle(color: Colors.white70),
                        ),
                      ),
                      const SizedBox(height: 6),
                      Text(
                        "Source: ${news.source}",
                        style: const TextStyle(
                            color: Colors.white38, fontSize: 12),
                      ),
                    ],
                  ),
                ),
              ),

              // Image Section - 40%
              Expanded(
                flex: 4,
                child: news.imageUrl != null && news.imageUrl!.isNotEmpty
                    ? ClipRRect(
                        borderRadius: const BorderRadius.horizontal(
                            right: Radius.circular(16)),
                        child: Image.network(
                          news.imageUrl!,
                          height: 150,
                          width: double.infinity,
                          fit: BoxFit.cover,
                          errorBuilder: (context, error, stackTrace) {
                            return Container(
                              height: 150,
                              color: Colors.grey[300],
                              child: const Icon(Icons.image, size: 50),
                            );
                          },
                        ),
                      )
                    : Container(
                        height: 150,
                        decoration: const BoxDecoration(
                          color: Colors.grey,
                          borderRadius: BorderRadius.horizontal(
                              right: Radius.circular(16)),
                        ),
                        child: const Icon(Icons.image, size: 50),
                      ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  // =======================
  // Build UI
  // =======================
  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFF5A1FD6),
      appBar: AppBar(
        backgroundColor: Colors.transparent,
        elevation: 0,
        title: const Text("Latest News"),
      ),
      body: Padding(
        padding: const EdgeInsets.all(16),
        child: isLoadingNews
            ? const Center(
                child: CircularProgressIndicator(color: Colors.white))
            : allNews.isEmpty
                ? const Center(
                    child: Text(
                      "No news available",
                      style: TextStyle(color: Colors.white70),
                    ),
                  )
                : ListView.builder(
                    itemCount: allNews.length,
                    itemBuilder: (context, index) => newsCard(allNews[index]),
                  ),
      ),
    );
  }
}

class NewsItem {
  final String title;
  final String description;
  final String url;
  final String source;
  final String? imageUrl;

  NewsItem({
    required this.title,
    required this.description,
    required this.url,
    required this.source,
    this.imageUrl,
  });
}
