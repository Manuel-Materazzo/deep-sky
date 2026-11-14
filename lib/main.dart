import 'package:material_ui/material_ui.dart';

void main() {
  runApp(const DeepSkyApp());
}

/// Root widget for the Deep Sky application.
class DeepSkyApp extends StatelessWidget {
  const DeepSkyApp({super.key});

  @override
  Widget build(BuildContext context) {
    const seedColor = Color(0xFF2B4570);

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

/// Placeholder home screen representing the couple's shared space before
/// the illustrated scene and core features are implemented.
class HomePlaceholderPage extends StatelessWidget {
  const HomePlaceholderPage({super.key});

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final colorScheme = theme.colorScheme;

    return Scaffold(
      appBar: AppBar(
        title: const Text('Deep Sky'),
        centerTitle: true,
      ),
      body: SafeArea(
        child: Center(
          child: Padding(
            padding: const EdgeInsets.symmetric(horizontal: 24),
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                Icon(
                  Icons.nights_stay_outlined,
                  size: 64,
                  color: colorScheme.primary,
                ),
                const SizedBox(height: 20),
                Text(
                  'La nostra casa',
                  style: theme.textTheme.headlineSmall,
                  textAlign: TextAlign.center,
                ),
                const SizedBox(height: 8),
                Text(
                  'Uno spazio privato per due persone.\nPiccoli gesti, senza fretta.',
                  style: theme.textTheme.bodyMedium?.copyWith(
                    color: colorScheme.onSurfaceVariant,
                  ),
                  textAlign: TextAlign.center,
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}
