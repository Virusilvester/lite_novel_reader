import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import 'app_state.dart';
import 'ui/root_page.dart';

void main() {
  WidgetsFlutterBinding.ensureInitialized();
  runApp(const WebNovelLiteApp());
}

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
