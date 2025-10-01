import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../app_state.dart';
import 'library_page.dart';
import 'recent_page.dart';
import 'sources_page.dart';
import 'extensions_page.dart';
import 'downloads_page.dart';
import 'settings_page.dart';

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
                    destinations: _labels
                        .map((l) => NavigationRailDestination(icon: const Icon(Icons.folder), label: Text(l)))
                        .toList(),
                    leading: Padding(
                      padding: const EdgeInsets.symmetric(vertical: 8.0),
                      child: IconButton(onPressed: () {}, icon: const Icon(Icons.menu)),
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
