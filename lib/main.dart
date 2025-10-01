// lib/main.dart
import 'dart:convert';
import 'dart:io';

import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:http/http.dart' as http;
import 'package:html/parser.dart' as html_parser;
import 'package:shared_preferences/shared_preferences.dart';
import 'package:path_provider/path_provider.dart';
import 'package:url_launcher/url_launcher.dart';

void main() {
  WidgetsFlutterBinding.ensureInitialized();
  runApp(const WebNovelLiteApp());
}

/// ------------------------- Models -------------------------
class Chapter {
  String id;
  String title;
  String url;
  bool downloaded;

  Chapter({
    required this.id,
    required this.title,
    required this.url,
    this.downloaded = false,
  });

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
        lastRead:
            j['lastRead'] != null ? DateTime.parse(j['lastRead']) : null,
      );
}

class ScraperExtension {
  String id;
  String name;
  String host; // e.g. "novelfire.net"
  // CSS selectors:
  String titleSelector;
  String coverSelector;
  String chapterListSelector; // selects chapter link elements
  String chapterTitleSelector; // optionally, relative selector for title inside the chapter list item
  String contentSelector; // selector used when fetching a chapter page to extract text/html

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

/// ------------------------- App State -------------------------
class AppState extends ChangeNotifier {
  static const _kKeyLibrary = 'library_json';
  static const _kKeyTabs = 'library_tabs';
  static const _kKeyExtensions = 'extensions_json';
  static const _kKeyRecent = 'recent_json';

  // libraryTabs maps tabName -> list of Novel JSONs
  List<String> libraryTabs = ['All'];
  Map<String, List<Novel>> library = {'All': []};

  List<ScraperExtension> extensions = [];
  List<String> recentNovelIds = [];

  bool _loaded = false;

  bool get loaded => _loaded;

  AppState() {
    _load();
  }

  Future<void> _load() async {
    final prefs = await SharedPreferences.getInstance();
    try {
      final tabsJson = prefs.getString(_kKeyTabs);
      if (tabsJson != null) {
        libraryTabs = List<String>.from(jsonDecode(tabsJson));
      }
      final libraryJson = prefs.getString(_kKeyLibrary);
      if (libraryJson != null) {
        final Map m = jsonDecode(libraryJson);
        library = m.map((k, v) => MapEntry(
            k,
            (v as List)
                .map((e) => Novel.fromJson(Map<String, dynamic>.from(e)))
                .toList()));
      } else {
        library = {'All': []};
      }
      final extJson = prefs.getString(_kKeyExtensions);
      if (extJson != null) {
        extensions = (jsonDecode(extJson) as List)
            .map((e) => ScraperExtension.fromJson(Map.from(e)))
            .toList();
      } else {
        // Add a sample placeholder extension the user can edit
        extensions = [
          ScraperExtension(
            id: 'sample-novelfire',
            name: 'Example: novelfire (placeholder)',
            host: 'novelfire.net',
            titleSelector: 'h1.title',
            coverSelector: '.book-cover img',
            chapterListSelector: '.chapter-list a',
            chapterTitleSelector: null ?? '', // optional
            contentSelector: '.chapter-content',
          )
        ];
      }
      final recentJson = prefs.getString(_kKeyRecent);
      if (recentJson != null) {
        recentNovelIds = List<String>.from(jsonDecode(recentJson));
      }
    } catch (e) {
      debugPrint('Failed to load state: $e');
    }
    _loaded = true;
    notifyListeners();
  }

  Future<void> _save() async {
    final prefs = await SharedPreferences.getInstance();
    try {
      prefs.setString(_kKeyTabs, jsonEncode(libraryTabs));
      final libraryMap = library.map((k, v) => MapEntry(k, v.map((n) => n.toJson()).toList()));
      prefs.setString(_kKeyLibrary, jsonEncode(libraryMap));
      prefs.setString(_kKeyExtensions, jsonEncode(extensions.map((e) => e.toJson()).toList()));
      prefs.setString(_kKeyRecent, jsonEncode(recentNovelIds));
    } catch (e) {
      debugPrint('Failed to save state: $e');
    }
  }

  // Library operations
  List<Novel> novelsForTab(String tab) {
    if (tab == 'All') {
      final all = <Novel>[];
      for (var t in libraryTabs) {
        if (t == 'All') continue;
        all.addAll(library[t] ?? []);
      }
      // dedupe by id
      final map = {for (var n in all) n.id: n};
      return map.values.toList();
    } else {
      return library[tab] ?? [];
    }
  }

  void createTab(String name) {
    if (!libraryTabs.contains(name)) {
      libraryTabs.add(name);
      library[name] = [];
      _save();
      notifyListeners();
    }
  }

  void addNovelToTab(String tab, Novel novel) {
    library.putIfAbsent(tab, () => []);
    // avoid duplicates
    if (!library[tab]!.any((n) => n.id == novel.id)) {
      library[tab]!.insert(0, novel);
      _save();
      notifyListeners();
    }
  }

  void addNovelToAllTabs(Novel novel) {
    addNovelToTab('All', novel); // though All is special, we still keep it minimal
    // For simplicity put into a default 'Reading' if exists else into 'All'
    final defaultTab = libraryTabs.contains('Reading') ? 'Reading' : 'All';
    addNovelToTab(defaultTab, novel);
  }

  void addExtension(ScraperExtension ext) {
    extensions.removeWhere((e) => e.id == ext.id);
    extensions.add(ext);
    _save();
    notifyListeners();
  }

  void markRead(Novel n) {
    n.lastRead = DateTime.now();
    // add to recent list front
    recentNovelIds.remove(n.id);
    recentNovelIds.insert(0, n.id);
    if (recentNovelIds.length > 30) recentNovelIds = recentNovelIds.sublist(0, 30);
    _save();
    notifyListeners();
  }
}

/// ------------------------- Scraper Service (skeleton) -------------------------
class ScraperService {
  // Scrape novel metadata & chapter list using ScraperExtension selectors.
  // This is intentionally simple: you provide CSS selectors per extension.
  Future<Novel?> scrapeNovel(String url, ScraperExtension ext) async {
    try {
      final uri = Uri.parse(url);
      final resp = await http.get(uri);
      if (resp.statusCode != 200) return null;
      final doc = html_parser.parse(resp.body);

      final titleEl = doc.querySelector(ext.titleSelector);
      final title = titleEl?.text.trim() ?? 'Unknown title';

      final coverEl = doc.querySelector(ext.coverSelector);
      String coverUrl = '';
      if (coverEl != null) {
        final src = coverEl.attributes['src'] ?? coverEl.attributes['data-src'] ?? '';
        if (src.isNotEmpty) {
          coverUrl = _normalizeUri(uri, src);
        }
      }

      // find chapter links
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
          chapters.add(Chapter(id: 'c${i + 1}', title: chapTitle.isNotEmpty ? chapTitle : 'Chapter ${i + 1}', url: chapUrl));
        }
      }

      final novel = Novel(
        id: uri.toString(),
        title: title,
        author: '',
        coverUrl: coverUrl,
        sourceUrl: url,
        chapters: chapters,
      );
      return novel;
    } catch (e) {
      debugPrint('Scrape failed: $e');
      return null;
    }
  }

  Future<String?> fetchChapterContent(String chapterUrl, ScraperExtension ext) async {
    try {
      final resp = await http.get(Uri.parse(chapterUrl));
      if (resp.statusCode != 200) return null;
      final doc = html_parser.parse(resp.body);
      final contentEl = doc.querySelector(ext.contentSelector);
      if (contentEl == null) {
        return resp.body; // fallback to raw HTML
      } else {
        return contentEl.innerHtml;
      }
    } catch (e) {
      debugPrint('fetchChapterContent error: $e');
      return null;
    }
  }

  String _normalizeUri(Uri base, String href) {
    try {
      final u = Uri.parse(href);
      if (u.hasScheme) return href;
      // relative
      return base.resolveUri(u).toString();
    } catch (e) {
      return href;
    }
  }
}

/// ------------------------- Download Service (simple) -------------------------
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

/// ------------------------- UI -------------------------
class WebNovelLiteApp extends StatelessWidget {
  const WebNovelLiteApp({super.key});

  @override
  Widget build(BuildContext context) {
    return ChangeNotifierProvider(
      create: (_) => AppState(),
      child: MaterialApp(
        debugShowCheckedModeBanner: false,
        title: 'WebNovel Lite',
        theme: ThemeData(
          primarySwatch: Colors.indigo,
          useMaterial3: true,
        ),
        home: const RootPage(),
      ),
    );
  }
}

class RootPage extends StatefulWidget {
  const RootPage({super.key});

  @override
  State<RootPage> createState() => _RootPageState();
}

class _RootPageState extends State<RootPage> {
  int _selectedIndex = 0;
  final List<String> _labels = ['Library', 'Recent', 'Sources', 'Extensions', 'Downloads', 'Settings'];

  @override
  Widget build(BuildContext context) {
    final bodyPages = [
      const LibraryPage(),
      const RecentPage(),
      const SourcesPage(),
      const ExtensionsPage(),
      const DownloadsPage(),
      const SettingsPage(),
    ];

    return Consumer<AppState>(
      builder: (context, state, _) {
        if (!state.loaded) {
          return const Scaffold(body: Center(child: CircularProgressIndicator()));
        }

        return LayoutBuilder(builder: (context, constraints) {
          final wide = constraints.maxWidth > 800;
          if (wide) {
            return Scaffold(
              body: Row(
                children: [
                  NavigationRail(
                    selectedIndex: _selectedIndex,
                    onDestinationSelected: (i) => setState(() => _selectedIndex = i),
                    labelType: NavigationRailLabelType.all,
                    destinations: _labels.map((l) => NavigationRailDestination(icon: const Icon(Icons.folder), label: Text(l))).toList(),
                    leading: Padding(
                      padding: const EdgeInsets.symmetric(vertical: 8.0),
                      child: IconButton(
                          onPressed: () {},
                          icon: const Icon(Icons.menu)),
                    ),
                  ),
                  const VerticalDivider(width: 1),
                  Expanded(child: bodyPages[_selectedIndex]),
                ],
              ),
            );
          } else {
            return Scaffold(
              body: bodyPages[_selectedIndex],
              bottomNavigationBar: BottomNavigationBar(
                currentIndex: _selectedIndex,
                onTap: (i) => setState(() => _selectedIndex = i),
                type: BottomNavigationBarType.fixed,
                items: const [
                  BottomNavigationBarItem(icon: Icon(Icons.library_books), label: 'Library'),
                  BottomNavigationBarItem(icon: Icon(Icons.history), label: 'Recent'),
                  BottomNavigationBarItem(icon: Icon(Icons.public), label: 'Sources'),
                  BottomNavigationBarItem(icon: Icon(Icons.extension), label: 'Extensions'),
                  BottomNavigationBarItem(icon: Icon(Icons.download), label: 'Downloads'),
                  BottomNavigationBarItem(icon: Icon(Icons.settings), label: 'Settings'),
                ],
              ),
            );
          }
        });
      },
    );
  }
}

/// ------------------------- Pages -------------------------
class LibraryPage extends StatefulWidget {
  const LibraryPage({super.key});

  @override
  State<LibraryPage> createState() => _LibraryPageState();
}

class _LibraryPageState extends State<LibraryPage> {
  String selectedTab = 'All';

  @override
  Widget build(BuildContext context) {
    final state = Provider.of<AppState>(context);
    selectedTab = state.libraryTabs.contains(selectedTab) ? selectedTab : state.libraryTabs.first;
    final novels = state.novelsForTab(selectedTab);

    return SafeArea(
      child: Column(
        children: [
          // Tabs row
          SizedBox(
            height: 64,
            child: ListView(
              padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
              scrollDirection: Axis.horizontal,
              children: [
                for (var tab in state.libraryTabs)
                  Padding(
                    padding: const EdgeInsets.symmetric(horizontal: 6),
                    child: ChoiceChip(
                      label: Text(tab),
                      selected: selectedTab == tab,
                      onSelected: (_) => setState(() => selectedTab = tab),
                    ),
                  ),
                ActionChip(
                  label: const Text('+ Add tab'),
                  onPressed: () async {
                    final name = await showDialog<String>(
                        context: context,
                        builder: (c) {
                          var txt = '';
                          return AlertDialog(
                            title: const Text('Create tab'),
                            content: TextField(
                              onChanged: (v) => txt = v,
                              decoration: const InputDecoration(hintText: 'Tab name (e.g. Reading, Favorites)'),
                            ),
                            actions: [
                              TextButton(onPressed: () => Navigator.of(c).pop(null), child: const Text('Cancel')),
                              ElevatedButton(onPressed: () => Navigator.of(c).pop(txt.trim()), child: const Text('Create')),
                            ],
                          );
                        });
                    if (name != null && name.isNotEmpty) {
                      state.createTab(name);
                      setState(() => selectedTab = name);
                    }
                  },
                )
              ],
            ),
          ),
          const Divider(height: 1),
          Expanded(
            child: novels.isEmpty
                ? Center(
                    child: Text('No novels in "$selectedTab". Add from Sources or Extensions tab.'),
                  )
                : ListView.separated(
                    itemCount: novels.length,
                    separatorBuilder: (_, __) => const Divider(height: 1),
                    itemBuilder: (context, idx) {
                      final n = novels[idx];
                      return ListTile(
                        leading: n.coverUrl.isNotEmpty ? Image.network(n.coverUrl, width: 56, fit: BoxFit.cover, errorBuilder: (_, __, ___) => const Icon(Icons.book)) : const Icon(Icons.book, size: 40),
                        title: Text(n.title),
                        subtitle: Text(n.author.isNotEmpty ? n.author : n.sourceUrl),
                        trailing: PopupMenuButton<String>(
                          onSelected: (v) async {
                            if (v == 'open') {
                              // mark last read & open a placeholder
                              state.markRead(n);
                              // For now open source URL in external browser
                              final uri = Uri.tryParse(n.sourceUrl);
                              if (uri != null && await canLaunchUrl(uri)) {
                                await launchUrl(uri);
                              }
                            } else if (v == 'download') {
                              // add first chapter to download queue (very simple demo)
                              ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Added to download queue (demo).')));
                            } else if (v == 'remove') {
                              setState(() {
                                state.library[selectedTab]?.removeWhere((x) => x.id == n.id);
                                state._save();
                              });
                            }
                          },
                          itemBuilder: (context) => const [
                            PopupMenuItem(value: 'open', child: Text('Open / Open in browser')),
                            PopupMenuItem(value: 'download', child: Text('Download (demo)')),
                            PopupMenuItem(value: 'remove', child: Text('Remove')),
                          ],
                        ),
                      );
                    },
                  ),
          ),
        ],
      ),
    );
  }
}

class RecentPage extends StatelessWidget {
  const RecentPage({super.key});

  @override
  Widget build(BuildContext context) {
    final state = Provider.of<AppState>(context);
    // convert recent ids to Novel objects if present
    final recentNovels = <Novel>[];
    for (var id in state.recentNovelIds) {
      for (var tab in state.libraryTabs) {
        final list = state.library[tab] ?? [];
        final found = list.firstWhere((n) => n.id == id, orElse: () => NullNovel());
        if (found is Novel && found.id.isNotEmpty && !recentNovels.any((rn) => rn.id == found.id)) {
          recentNovels.add(found);
        }
      }
    }

    return SafeArea(
      child: recentNovels.isEmpty
          ? const Center(child: Text('No recently read novels.'))
          : ListView.separated(
              itemCount: recentNovels.length,
              separatorBuilder: (_, __) => const Divider(height: 1),
              itemBuilder: (context, idx) {
                final n = recentNovels[idx];
                return ListTile(
                  title: Text(n.title),
                  subtitle: Text(n.sourceUrl),
                  onTap: () async {
                    // open in browser
                    final uri = Uri.tryParse(n.sourceUrl);
                    if (uri != null && await canLaunchUrl(uri)) {
                      await launchUrl(uri);
                    }
                  },
                );
              },
            ),
    );
  }
}

// NullNovel sentinel so firstWhere returns something predictable
Novel NullNovel() => Novel(id: '', title: '', sourceUrl: '');

/*
Sources page: user pastes a novel URL and chooses an extension (matched by host).
This is purposely simple: resolve extension by host or let user pick one.
*/
class SourcesPage extends StatefulWidget {
  const SourcesPage({super.key});
  @override
  State<SourcesPage> createState() => _SourcesPageState();
}

class _SourcesPageState extends State<SourcesPage> {
  final _urlController = TextEditingController();
  ScraperExtension? _selectedExt;
  bool _loading = false;
  String? _status;
  final _scraper = ScraperService();

  @override
  Widget build(BuildContext context) {
    final state = Provider.of<AppState>(context);
    return SafeArea(
      child: Padding(
        padding: const EdgeInsets.all(12),
        child: Column(
          children: [
            TextField(
              controller: _urlController,
              decoration: const InputDecoration(labelText: 'Novel page URL', hintText: 'https://novelfire.net/book/123', border: OutlineInputBorder()),
            ),
            const SizedBox(height: 8),
            Row(
              children: [
                Expanded(
                  child: DropdownButtonFormField<ScraperExtension>(
                    value: _selectedExt,
                    hint: const Text('Choose extension (or leave to auto-match)'),
                    items: state.extensions.map((e) => DropdownMenuItem(value: e, child: Text('${e.name} (${e.host})'))).toList(),
                    onChanged: (v) => setState(() => _selectedExt = v),
                  ),
                ),
                const SizedBox(width: 8),
                ElevatedButton(
                  onPressed: _loading ? null : () async {
                    final url = _urlController.text.trim();
                    if (url.isEmpty) {
                      setState(() => _status = 'Please enter a URL.');
                      return;
                    }
                    setState(() { _loading = true; _status = null; });
                    try {
                      final uri = Uri.tryParse(url);
                      if (uri == null) {
                        setState(() => _status = 'Invalid URL');
                        return;
                      }
                      ScraperExtension? ext = _selectedExt;
                      if (ext == null) {
                        ext = state.extensions.firstWhere((e) => uri.host.contains(e.host), orElse: () => state.extensions.first);
                      }
                      final novel = await _scraper.scrapeNovel(url, ext);
                      if (novel == null) {
                        setState(() { _status = 'Failed to fetch or parse page (check selectors or network).'; _loading = false; });
                        return;
                      }
                      // Add to library under default tab
                      state.addNovelToAllTabs(novel);
                      setState(() { _status = 'Added "${novel.title}" to library.'; _loading = false; });
                    } catch (e) {
                      setState(() { _status = 'Error: $e'; _loading = false; });
                    }
                  },
                  child: _loading ? const SizedBox(width: 18, height: 18, child: CircularProgressIndicator(strokeWidth: 2)) : const Text('Fetch & Add'),
                )
              ],
            ),
            const SizedBox(height: 12),
            if (_status != null) Text(_status!, style: const TextStyle(color: Colors.green)),
            const SizedBox(height: 12),
            Expanded(
              child: ListView(
                children: [
                  const Text('Quick tips:', style: TextStyle(fontWeight: FontWeight.bold)),
                  const SizedBox(height: 6),
                  const Text('- If fetch fails, edit or add an extension with correct CSS selectors in Extensions tab.'),
                  const SizedBox(height: 6),
                  const Text('- For web (browser) builds you may hit CORS; prefer mobile/desktop or use a proxy.'),
                ],
              ),
            )
          ],
        ),
      ),
    );
  }
}

class ExtensionsPage extends StatefulWidget {
  const ExtensionsPage({super.key});
  @override
  State<ExtensionsPage> createState() => _ExtensionsPageState();
}

class _ExtensionsPageState extends State<ExtensionsPage> {
  @override
  Widget build(BuildContext context) {
    final state = Provider.of<AppState>(context);
    return SafeArea(
      child: Column(
        children: [
          Expanded(
            child: ListView.separated(
              itemCount: state.extensions.length,
              separatorBuilder: (_, __) => const Divider(height: 1),
              itemBuilder: (context, idx) {
                final e = state.extensions[idx];
                return ListTile(
                  title: Text(e.name),
                  subtitle: Text(e.host),
                  onTap: () => _editExtension(context, e),
                );
              },
            ),
          ),
          Padding(
            padding: const EdgeInsets.all(12),
            child: ElevatedButton.icon(
              onPressed: () => _createExtension(context),
              icon: const Icon(Icons.add),
              label: const Text('Add extension (manual)'),
            ),
          )
        ],
      ),
    );
  }

  Future<void> _createExtension(BuildContext ctx) async {
    final newExt = await showDialog<ScraperExtension>(
        context: ctx,
        builder: (c) {
          final idCtrl = TextEditingController(text: 'ext-${DateTime.now().millisecondsSinceEpoch}');
          final nameCtrl = TextEditingController();
          final hostCtrl = TextEditingController();
          final titleCtrl = TextEditingController();
          final coverCtrl = TextEditingController();
          final listCtrl = TextEditingController();
          final itemTitleCtrl = TextEditingController();
          final contentCtrl = TextEditingController();
          return AlertDialog(
            scrollable: true,
            title: const Text('New Extension'),
            content: Column(
              children: [
                TextField(controller: idCtrl, decoration: const InputDecoration(labelText: 'id')),
                TextField(controller: nameCtrl, decoration: const InputDecoration(labelText: 'Name')),
                TextField(controller: hostCtrl, decoration: const InputDecoration(labelText: 'Host (e.g. novelfire.net)')),
                TextField(controller: titleCtrl, decoration: const InputDecoration(labelText: 'Title selector (CSS)')),
                TextField(controller: coverCtrl, decoration: const InputDecoration(labelText: 'Cover selector (CSS)')),
                TextField(controller: listCtrl, decoration: const InputDecoration(labelText: 'Chapter list selector (CSS)')),
                TextField(controller: itemTitleCtrl, decoration: const InputDecoration(labelText: 'Chapter title selector (optional)')),
                TextField(controller: contentCtrl, decoration: const InputDecoration(labelText: 'Chapter content selector (CSS)')),
              ],
            ),
            actions: [
              TextButton(onPressed: () => Navigator.pop(c), child: const Text('Cancel')),
              ElevatedButton(
                onPressed: () {
                  final ext = ScraperExtension(
                    id: idCtrl.text.trim(),
                    name: nameCtrl.text.trim(),
                    host: hostCtrl.text.trim(),
                    titleSelector: titleCtrl.text.trim(),
                    coverSelector: coverCtrl.text.trim(),
                    chapterListSelector: listCtrl.text.trim(),
                    chapterTitleSelector: itemTitleCtrl.text.trim(),
                    contentSelector: contentCtrl.text.trim(),
                  );
                  Navigator.pop(c, ext);
                },
                child: const Text('Create'),
              )
            ],
          );
        });
    if (newExt != null) {
      final state = Provider.of<AppState>(context, listen: false);
      state.addExtension(newExt);
    }
  }

  Future<void> _editExtension(BuildContext ctx, ScraperExtension e) async {
    // for brevity reuse create dialog with prefilled values
    final ext = await showDialog<ScraperExtension>(
        context: ctx,
        builder: (c) {
          final idCtrl = TextEditingController(text: e.id);
          final nameCtrl = TextEditingController(text: e.name);
          final hostCtrl = TextEditingController(text: e.host);
          final titleCtrl = TextEditingController(text: e.titleSelector);
          final coverCtrl = TextEditingController(text: e.coverSelector);
          final listCtrl = TextEditingController(text: e.chapterListSelector);
          final itemTitleCtrl = TextEditingController(text: e.chapterTitleSelector);
          final contentCtrl = TextEditingController(text: e.contentSelector);
          return AlertDialog(
            scrollable: true,
            title: const Text('Edit Extension'),
            content: Column(
              children: [
                TextField(controller: idCtrl, decoration: const InputDecoration(labelText: 'id')),
                TextField(controller: nameCtrl, decoration: const InputDecoration(labelText: 'Name')),
                TextField(controller: hostCtrl, decoration: const InputDecoration(labelText: 'Host (e.g. novelfire.net)')),
                TextField(controller: titleCtrl, decoration: const InputDecoration(labelText: 'Title selector (CSS)')),
                TextField(controller: coverCtrl, decoration: const InputDecoration(labelText: 'Cover selector (CSS)')),
                TextField(controller: listCtrl, decoration: const InputDecoration(labelText: 'Chapter list selector (CSS)')),
                TextField(controller: itemTitleCtrl, decoration: const InputDecoration(labelText: 'Chapter title selector (optional)')),
                TextField(controller: contentCtrl, decoration: const InputDecoration(labelText: 'Chapter content selector (CSS)')),
              ],
            ),
            actions: [
              TextButton(onPressed: () => Navigator.pop(c), child: const Text('Cancel')),
              ElevatedButton(
                onPressed: () {
                  final ext = ScraperExtension(
                    id: idCtrl.text.trim(),
                    name: nameCtrl.text.trim(),
                    host: hostCtrl.text.trim(),
                    titleSelector: titleCtrl.text.trim(),
                    coverSelector: coverCtrl.text.trim(),
                    chapterListSelector: listCtrl.text.trim(),
                    chapterTitleSelector: itemTitleCtrl.text.trim(),
                    contentSelector: contentCtrl.text.trim(),
                  );
                  Navigator.pop(c, ext);
                },
                child: const Text('Save'),
              )
            ],
          );
        });
    if (ext != null) {
      final state = Provider.of<AppState>(context, listen: false);
      state.addExtension(ext);
    }
  }
}

class DownloadsPage extends StatelessWidget {
  const DownloadsPage({super.key});

  @override
  Widget build(BuildContext context) {
    // minimal placeholder for queue
    return SafeArea(
      child: Column(
        children: [
          const ListTile(title: Text('Download queue (demo)')),
          const Padding(
            padding: EdgeInsets.all(12.0),
            child: Text('This step is a skeleton. Next step we will implement queued downloads, progress, pause/resume, and saving chapters to files.'),
          )
        ],
      ),
    );
  }
}

class SettingsPage extends StatelessWidget {
  const SettingsPage({super.key});

  @override
  Widget build(BuildContext context) {
    return SafeArea(
      child: ListView(
        children: [
          SwitchListTile(
            title: const Text('Enable notifications (demo)'),
            value: false,
            onChanged: (_) {},
          ),
          ListTile(
            title: const Text('About'),
            subtitle: const Text('WebNovel Lite — demo scaffold'),
          )
        ],
      ),
    );
  }
}
