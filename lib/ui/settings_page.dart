import 'package:flutter/material.dart';

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
          const ListTile(
            title: Text('About'),
            subtitle: Text('WebNovel Lite — demo scaffold'),
          )
        ],
      ),
    );
  }
}
