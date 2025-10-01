import 'dart:io';
import 'package:path_provider/path_provider.dart';
import 'scraper_service.dart';
import '../models/models.dart';

class DownloadService {
  final ScraperService scraper;
  DownloadService(this.scraper);

  Future<String?> downloadChapterToFile(String novelId, String chapterId, String chapterUrl, ScraperExtension ext) async {
    final content = await scraper.fetchChapterContent(chapterUrl, ext);
    if (content == null) return null;

    final dir = await getApplicationDocumentsDirectory();
    final novelDir = Directory('${dir.path}/novels/${_safeFileName(novelId)}');
    if (!await novelDir.exists()) await novelDir.create(recursive: true);

    final file = File('${novelDir.path}/${_safeFileName(chapterId)}.html');
    await file.writeAsString(content);
    return file.path;
  }

  String _safeFileName(String s) => s.replaceAll(RegExp(r'[^\w\-_. ]'), '_');
}
