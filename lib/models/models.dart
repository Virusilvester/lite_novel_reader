class Chapter {
  String id;
  String title;
  String url;
  bool downloaded;

  Chapter({required this.id, required this.title, required this.url, this.downloaded = false});

  Map<String, dynamic> toJson() => {
        'id': id,
        'title': title,
        'url': url,
        'downloaded': downloaded,
      };

  static Chapter fromJson(Map<String, dynamic> j) => Chapter(
        id: j['id'],
        title: j['title'],
        url: j['url'],
        downloaded: j['downloaded'] ?? false,
      );
}

class Novel {
  String id;
  String title;
  String author;
  String coverUrl;
  String sourceUrl;
  List<Chapter> chapters;
  DateTime? lastRead;

  Novel({
    required this.id,
    required this.title,
    this.author = '',
    this.coverUrl = '',
    required this.sourceUrl,
    List<Chapter>? chapters,
    this.lastRead,
  }) : chapters = chapters ?? [];

  Map<String, dynamic> toJson() => {
        'id': id,
        'title': title,
        'author': author,
        'coverUrl': coverUrl,
        'sourceUrl': sourceUrl,
        'chapters': chapters.map((c) => c.toJson()).toList(),
        'lastRead': lastRead?.toIso8601String(),
      };

  static Novel fromJson(Map<String, dynamic> j) => Novel(
        id: j['id'],
        title: j['title'] ?? 'No title',
        author: j['author'] ?? '',
        coverUrl: j['coverUrl'] ?? '',
        sourceUrl: j['sourceUrl'] ?? '',
        chapters: (j['chapters'] as List? ?? [])
            .map((e) => Chapter.fromJson(Map<String, dynamic>.from(e)))
            .toList(),
        lastRead: j['lastRead'] != null ? DateTime.parse(j['lastRead']) : null,
      );
}

class ScraperExtension {
  String id;
  String name;
  String host;
  String titleSelector;
  String coverSelector;
  String chapterListSelector;
  String chapterTitleSelector;
  String contentSelector;

  ScraperExtension({
    required this.id,
    required this.name,
    required this.host,
    required this.titleSelector,
    required this.coverSelector,
    required this.chapterListSelector,
    required this.chapterTitleSelector,
    required this.contentSelector,
  });

  Map<String, dynamic> toJson() => {
        'id': id,
        'name': name,
        'host': host,
        'titleSelector': titleSelector,
        'coverSelector': coverSelector,
        'chapterListSelector': chapterListSelector,
        'chapterTitleSelector': chapterTitleSelector,
        'contentSelector': contentSelector,
      };

  static ScraperExtension fromJson(Map<String, dynamic> j) => ScraperExtension(
        id: j['id'],
        name: j['name'],
        host: j['host'],
        titleSelector: j['titleSelector'],
        coverSelector: j['coverSelector'],
        chapterListSelector: j['chapterListSelector'],
        chapterTitleSelector: j['chapterTitleSelector'],
        contentSelector: j['contentSelector'],
      );
}
