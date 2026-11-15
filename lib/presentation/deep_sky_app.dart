import 'package:deep_sky/presentation/deep_sky_controller.dart';
import 'package:deep_sky/presentation/screens/code_verification_page.dart';
import 'package:deep_sky/presentation/screens/home_shell_page.dart';
import 'package:deep_sky/presentation/screens/onboarding_page.dart';
import 'package:deep_sky/presentation/screens/space_setup_page.dart';
import 'package:deep_sky/presentation/screens/upgrade_required_page.dart';
import 'package:deep_sky/presentation/theme/deep_sky_theme.dart';
import 'package:material_ui/material_ui.dart';

/// Root widget for the Deep Sky client application (`APP-01`, `V-06`).
class DeepSkyApp extends StatefulWidget {
  const DeepSkyApp({super.key, this.controller, this.autoInitialize = true});

  final DeepSkyController? controller;
  final bool autoInitialize;

  @override
  State<DeepSkyApp> createState() => _DeepSkyAppState();
}

class _DeepSkyAppState extends State<DeepSkyApp> {
  DeepSkyController? _ownedController;

  DeepSkyController get _controller =>
      widget.controller ?? (_ownedController ??= DeepSkyController());

  @override
  void initState() {
    super.initState();
    if (widget.autoInitialize) {
      _controller.initialize();
    }
  }

  @override
  void didUpdateWidget(covariant DeepSkyApp oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.controller != widget.controller && widget.autoInitialize) {
      _controller.initialize();
    }
  }

  @override
  void dispose() {
    _ownedController?.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return ListenableBuilder(
      listenable: _controller,
      builder: (BuildContext context, Widget? child) {
        return MaterialApp(
          title: 'Deep Sky',
          debugShowCheckedModeBanner: false,
          locale: Locale(_controller.languageCode),
          supportedLocales: const <Locale>[Locale('it'), Locale('en')],
          localizationsDelegates: GlobalMaterialLocalizations.delegates,
          theme: DeepSkyTheme.light(),
          darkTheme: DeepSkyTheme.dark(),
          themeMode: _controller.isNight ? ThemeMode.dark : ThemeMode.light,
          home: _buildPhaseScreen(),
        );
      },
    );
  }

  Widget _buildPhaseScreen() {
    switch (_controller.phase) {
      case AppBootPhase.loading:
        return const Scaffold(
          key: Key('loading-page'),
          body: Center(child: Icon(Icons.nights_stay_outlined, size: 40)),
        );
      case AppBootPhase.upgradeRequired:
        return UpgradeRequiredPage(controller: _controller);
      case AppBootPhase.unpaired:
      case AppBootPhase.waiting:
        if (_controller.needsCodeVerification) {
          return CodeVerificationPage(controller: _controller);
        }
        return OnboardingPage(controller: _controller);
      case AppBootPhase.paired:
        if (_controller.needsSpaceSetup) {
          return SpaceSetupPage(controller: _controller);
        }
        return HomeShellPage(controller: _controller);
    }
  }
}
