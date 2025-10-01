import 'package:flutter/foundation.dart';
import 'package:html/parser.dart' as html_parser;
import 'package:http/http.dart' as http;
import '../models/models.dart';

class ScraperService {
  /// Optional: fetches via a proxy to avoid CORS issues (Flutter Web)
  Future<String?> _fetchUrl(String url, {String? proxy}) async {
    try {
      Uri uri = Uri.parse(url);
      if (proxy != null && proxy.isNotEmpty) {
        // Pass the target URL as a query param to your proxy
        uri = Uri.parse('$proxy?url=${Uri.encodeComponent(url)}');
      }
      final resp = await http.get(uri);
      if (resp.statusCode != 200) return null;
      return resp.body;
    } catch (e) {
      debugPrint('Fetch error: $e');
      return null;
    }
  }


  Future<Novel?> scrapeNovel(String url, ScraperExtension ext) async {
    try {
      final htmlString = await _fetchUrl(url, proxy: ext.proxyUrl);
      if (htmlString == null) return null;

      final uri = Uri.parse(url);
      final doc = html_parser.parse(htmlString);

      final titleEl = doc.querySelector(ext.titleSelector);
      final title = titleEl?.text.trim() ?? 'Unknown title';

      final coverEl = doc.querySelector(ext.coverSelector);
      String coverUrl = '';
      if (coverEl != null) {
        final src = coverEl.attributes['src'] ?? coverEl.attributes['data-src'] ?? '';
        if (src.isNotEmpty) coverUrl = _normalizeUri(uri, src);
      }

      final chapEls = doc.querySelectorAll(ext.chapterListSelector);
      final chapters = <Chapter>[];
      for (var i = 0; i < chapEls.length; i++) {
        final el = chapEls[i];
        final href = el.attributes['href'] ?? '';
        final chapUrl = href.isNotEmpty ? _normalizeUri(uri, href) : '';
        final chapTitle = (ext.chapterTitleSelector.isNotEmpty
                ? (el.querySelector(ext.chapterTitleSelector)?.text ?? el.text)
                : el.text)
            .trim();
        if (chapUrl.isNotEmpty) {
          chapters.add(Chapter(
              id: 'c${i + 1}',
              title: chapTitle.isNotEmpty ? chapTitle : 'Chapter ${i + 1}',
              url: chapUrl));
        }
      }

      return Novel(
        id: uri.toString(),
        title: title,
        author: '',
        coverUrl: coverUrl,
        sourceUrl: url,
        chapters: chapters,
      );
    } catch (e) {
      debugPrint('Scrape failed: $e');
      return null;
    }
  }

  Future<String?> fetchChapterContent(String chapterUrl, ScraperExtension ext) async {
    try {
      final htmlString = await _fetchUrl(chapterUrl, proxy: ext.proxyUrl);
      if (htmlString == null) return null;
      final doc = html_parser.parse(htmlString);
      final contentEl = doc.querySelector(ext.contentSelector);
      return contentEl?.innerHtml ?? htmlString;
    } catch (e) {
      debugPrint('fetchChapterContent error: $e');
      return null;
    }
  }

  String _normalizeUri(Uri base, String href) {
    try {
      final u = Uri.parse(href);
      if (u.hasScheme) return href;
      return base.resolveUri(u).toString();
    } catch (e) {
      return href;
    }
  }
}
