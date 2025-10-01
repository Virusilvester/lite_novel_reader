import 'dart:convert';
import 'package:flutter/foundation.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'models/models.dart';

class AppState extends ChangeNotifier {
  static const _kKeyLibrary = 'library_json';
  static const _kKeyTabs = 'library_tabs';
  static const _kKeyExtensions = 'extensions_json';
  static const _kKeyRecent = 'recent_json';

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
      if (tabsJson != null) libraryTabs = List<String>.from(jsonDecode(tabsJson));

      final libraryJson = prefs.getString(_kKeyLibrary);
      if (libraryJson != null) {
        final Map m = jsonDecode(libraryJson);
        library = m.map((k, v) => MapEntry(
            k,
            (v as List)
                .map((e) => Novel.fromJson(Map<String, dynamic>.from(e)))
                .toList()));
      }

      final extJson = prefs.getString(_kKeyExtensions);
      if (extJson != null) {
        extensions = (jsonDecode(extJson) as List)
            .map((e) => ScraperExtension.fromJson(Map.from(e)))
            .toList();
      } else {
        extensions = [
          ScraperExtension(
            id: 'sample-novelfire',
            name: 'Example: novelfire (placeholder)',
            host: 'novelfire.net',
            titleSelector: 'h1.title',
            coverSelector: '.book-cover img',
            chapterListSelector: '.chapter-list a',
            chapterTitleSelector: '',
            contentSelector: '.chapter-content',
          )
        ];
      }

      final recentJson = prefs.getString(_kKeyRecent);
      if (recentJson != null) recentNovelIds = List<String>.from(jsonDecode(recentJson));
    } catch (e) {
      debugPrint('Failed to load state: $e');
    }
    _loaded = true;
    notifyListeners();
  }

  Future<void> save() async {
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

  List<Novel> novelsForTab(String tab) {
    if (tab == 'All') {
      final all = <Novel>[];
      for (var t in libraryTabs) {
        if (t == 'All') continue;
        all.addAll(library[t] ?? []);
      }
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
      save();
      notifyListeners();
    }
  }

  void addNovelToTab(String tab, Novel novel) {
    library.putIfAbsent(tab, () => []);
    if (!library[tab]!.any((n) => n.id == novel.id)) {
      library[tab]!.insert(0, novel);
      save();
      notifyListeners();
    }
  }

  void addNovelToAllTabs(Novel novel) {
    addNovelToTab('All', novel);
    final defaultTab = libraryTabs.contains('Reading') ? 'Reading' : 'All';
    addNovelToTab(defaultTab, novel);
  }

  void addExtension(ScraperExtension ext) {
    extensions.removeWhere((e) => e.id == ext.id);
    extensions.add(ext);
    save();
    notifyListeners();
  }

  void markRead(Novel n) {
    n.lastRead = DateTime.now();
    recentNovelIds.remove(n.id);
    recentNovelIds.insert(0, n.id);
    if (recentNovelIds.length > 30) recentNovelIds = recentNovelIds.sublist(0, 30);
    save();
    notifyListeners();
  }
}
