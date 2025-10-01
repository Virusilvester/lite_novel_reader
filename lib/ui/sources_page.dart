import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../app_state.dart';
import '../models/models.dart';
import '../services/scraper_service.dart';

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
              decoration: const InputDecoration(
                  labelText: 'Novel page URL',
                  hintText: 'https://novelfire.net/book/123',
                  border: OutlineInputBorder()),
            ),
            const SizedBox(height: 8),
            Row(
              children: [
                Expanded(
                  child: DropdownButtonFormField<ScraperExtension>(
                    value: _selectedExt,
                    hint: const Text('Choose extension (or leave to auto-match)'),
                    items: state.extensions
                        .map((e) => DropdownMenuItem(value: e, child: Text('${e.name} (${e.host})')))
                        .toList(),
                    onChanged: (v) => setState(() => _selectedExt = v),
                  ),
                ),
                const SizedBox(width: 8),
                ElevatedButton(
                  onPressed: _loading
                      ? null
                      : () async {
                          final url = _urlController.text.trim();
                          if (url.isEmpty) {
                            setState(() => _status = 'Please enter a URL.');
                            return;
                          }
                          setState(() {
                            _loading = true;
                            _status = null;
                          });
                          try {
                            final uri = Uri.tryParse(url);
                            if (uri == null) {
                              setState(() => _status = 'Invalid URL');
                              return;
                            }
                            ScraperExtension? ext = _selectedExt;
                            if (ext == null) {
                              ext = state.extensions.firstWhere(
                                  (e) => uri.host.contains(e.host),
                                  orElse: () => state.extensions.first);
                            }
                            final novel = await _scraper.scrapeNovel(url, ext);
                            if (novel == null) {
                              setState(() {
                                _status = 'Failed to fetch or parse page.';
                                _loading = false;
                              });
                              return;
                            }
                            state.addNovelToAllTabs(novel);
                            setState(() {
                              _status = 'Added "${novel.title}" to library.';
                              _loading = false;
                            });
                          } catch (e) {
                            setState(() {
                              _status = 'Error: $e';
                              _loading = false;
                            });
                          }
                        },
                  child: _loading
                      ? const SizedBox(width: 18, height: 18, child: CircularProgressIndicator(strokeWidth: 2))
                      : const Text('Fetch & Add'),
                )
              ],
            ),
            const SizedBox(height: 12),
            if (_status != null) Text(_status!, style: const TextStyle(color: Colors.green)),
          ],
        ),
      ),
    );
  }
}
