import 'package:deep_sky/presentation/home_placeholder_page.dart';
import 'package:material_ui/material_ui.dart';

/// Root widget for the Deep Sky application (APP-01, V-06).
class DeepSkyApp extends StatelessWidget {
  const DeepSkyApp({super.key});

  @override
  Widget build(BuildContext context) {
    const Color seedColor = Color(0xFF2B4570);

    return MaterialApp(
      title: 'Deep Sky',
      themeMode: ThemeMode.system,
      theme: ThemeData(
        useMaterial3: true,
        colorScheme: ColorScheme.fromSeed(
          seedColor: seedColor,
          brightness: Brightness.light,
        ),
      ),
      darkTheme: ThemeData(
        useMaterial3: true,
        colorScheme: ColorScheme.fromSeed(
          seedColor: seedColor,
          brightness: Brightness.dark,
        ),
      ),
      home: const HomePlaceholderPage(),
    );
  }
}
