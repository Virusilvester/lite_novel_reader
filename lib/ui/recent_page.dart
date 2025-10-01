import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:url_launcher/url_launcher.dart';
import '../app_state.dart';
import '../models/models.dart';

class RecentPage extends StatelessWidget {
  const RecentPage({super.key});

  @override
  Widget build(BuildContext context) {
    final state = Provider.of<AppState>(context);
    final recentNovels = <Novel>[];
    for (var id in state.recentNovelIds) {
      for (var tab in state.libraryTabs) {
        final list = state.library[tab] ?? [];
        final found = list.firstWhere((n) => n.id == id, orElse: () => NullNovel());
        if (found.id.isNotEmpty && !recentNovels.any((rn) => rn.id == found.id)) recentNovels.add(found);
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
                    final uri = Uri.tryParse(n.sourceUrl);
                    if (uri != null && await canLaunchUrl(uri)) await launchUrl(uri);
                  },
                );
              },
            ),
    );
  }
}

Novel NullNovel() => Novel(id: '', title: '', sourceUrl: '');
