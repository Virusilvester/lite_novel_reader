import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../app_state.dart';
import '../models/models.dart';

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
    final newExt = await _showExtensionDialog(ctx);
    if (newExt != null) {
      final state = Provider.of<AppState>(context, listen: false);
      state.addExtension(newExt);
    }
  }

  Future<void> _editExtension(BuildContext ctx, ScraperExtension e) async {
    final ext = await _showExtensionDialog(ctx, e: e);
    if (ext != null) {
      final state = Provider.of<AppState>(context, listen: false);
      state.addExtension(ext);
    }
  }

  Future<ScraperExtension?> _showExtensionDialog(BuildContext ctx, {ScraperExtension? e}) {
    final idCtrl = TextEditingController(text: e?.id ?? 'ext-${DateTime.now().millisecondsSinceEpoch}');
    final nameCtrl = TextEditingController(text: e?.name ?? '');
    final hostCtrl = TextEditingController(text: e?.host ?? '');
    final titleCtrl = TextEditingController(text: e?.titleSelector ?? '');
    final coverCtrl = TextEditingController(text: e?.coverSelector ?? '');
    final listCtrl = TextEditingController(text: e?.chapterListSelector ?? '');
    final itemTitleCtrl = TextEditingController(text: e?.chapterTitleSelector ?? '');
    final contentCtrl = TextEditingController(text: e?.contentSelector ?? '');

    return showDialog<ScraperExtension>(
      context: ctx,
      builder: (c) {
        return AlertDialog(
          scrollable: true,
          title: Text(e == null ? 'New Extension' : 'Edit Extension'),
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
              child: Text(e == null ? 'Create' : 'Save'),
            )
          ],
        );
      },
    );
  }
}
