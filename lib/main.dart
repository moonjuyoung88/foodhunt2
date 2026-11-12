import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import 'services/app_state.dart';
import 'ui/home_page.dart';
import 'ui/style.dart';

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();
  await SystemChrome.setPreferredOrientations([DeviceOrientation.portraitUp]);
  SystemChrome.setSystemUIOverlayStyle(
    const SystemUiOverlayStyle(
      statusBarColor: Colors.transparent,
      statusBarIconBrightness: Brightness.light,
      systemNavigationBarColor: Ui.bgBottom,
    ),
  );
  final app = await AppState.load();
  runApp(PixelNibblersApp(app: app));
}

class PixelNibblersApp extends StatelessWidget {
  const PixelNibblersApp({super.key, required this.app});
  final AppState app;

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'Pixel Nibblers',
      debugShowCheckedModeBanner: false,
      theme: ThemeData(
        brightness: Brightness.dark,
        scaffoldBackgroundColor: Ui.bgBottom,
        colorScheme: ColorScheme.fromSeed(
          seedColor: Ui.yellow,
          brightness: Brightness.dark,
        ),
      ),
      home: HomePage(app: app),
    );
  }
}
