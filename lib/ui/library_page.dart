import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:url_launcher/url_launcher.dart';

import '../app_state.dart';

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
                              decoration: const InputDecoration(
                                  hintText: 'Tab name (e.g. Reading, Favorites)'),
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
                        leading: n.coverUrl.isNotEmpty
                            ? Image.network(n.coverUrl,
                                width: 56, fit: BoxFit.cover, errorBuilder: (_, __, ___) => const Icon(Icons.book))
                            : const Icon(Icons.book, size: 40),
                        title: Text(n.title),
                        subtitle: Text(n.author.isNotEmpty ? n.author : n.sourceUrl),
                        trailing: PopupMenuButton<String>(
                          onSelected: (v) async {
                            if (v == 'open') {
                              state.markRead(n);
                              final uri = Uri.tryParse(n.sourceUrl);
                              if (uri != null && await canLaunchUrl(uri)) await launchUrl(uri);
                            } else if (v == 'download') {
                              ScaffoldMessenger.of(context).showSnackBar(
                                  const SnackBar(content: Text('Added to download queue (demo).')));
                            } else if (v == 'remove') {
                              setState(() {
                                state.library[selectedTab]?.removeWhere((x) => x.id == n.id);
                                state.save();
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
