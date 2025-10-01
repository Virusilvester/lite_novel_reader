import 'package:flutter/material.dart';

class DownloadsPage extends StatelessWidget {
  const DownloadsPage({super.key});

  @override
  Widget build(BuildContext context) {
    return SafeArea(
      child: Column(
        children: const [
          ListTile(title: Text('Download queue (demo)')),
          Padding(
            padding: EdgeInsets.all(12.0),
            child: Text(
              'This step is a skeleton. Next step we will implement queued downloads, progress, pause/resume, and saving chapters to files.',
            ),
          ),
        ],
      ),
    );
  }
}
