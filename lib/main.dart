import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_localizations/flutter_localizations.dart';

import 'screens/home_page.dart';
import 'services/recipe_repository.dart';
import 'services/update_checker.dart';

/// Configuration publique GitHub pour la vérification automatique des versions.
const _githubOwner = 'Whisper40';
const _githubRepo = 'recipe-ananas';

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();
  final repository = RecipeRepository();
  await repository.init();
  runApp(RecipeBoxApp(repository: repository));
}

class RecipeBoxApp extends StatefulWidget {
  const RecipeBoxApp({required this.repository, super.key});

  final RecipeRepository repository;

  @override
  State<RecipeBoxApp> createState() => _RecipeBoxAppState();
}

class _RecipeBoxAppState extends State<RecipeBoxApp> {
  bool _checkingUpdate = false;
  late final UpdateChecker _updateChecker = UpdateChecker(
    owner: _githubOwner,
    repo: _githubRepo,
  );

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      _checkForUpdates();
    });
  }

  Future<void> _checkForUpdates() async {
    if (_checkingUpdate) return;
    setState(() => _checkingUpdate = true);

    try {
      final release = await _updateChecker.checkForUpdate();

      if (release != null && mounted) {
        final isAvailable = await _updateChecker.isUpdateAvailable(release);
        if (isAvailable && mounted) {
          _showUpdateDialog(release);
        }
      }
    } catch (e) {
      debugPrint('Erreur vérification mise à jour: $e');
    } finally {
      if (mounted) {
        setState(() => _checkingUpdate = false);
      }
    }
  }

  void _showUpdateDialog(GitHubRelease release) {
    showDialog(
      context: context,
      barrierDismissible: false,
      builder: (context) => AlertDialog(
        title: const Text('Mise à jour disponible'),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              'Une nouvelle version est disponible (${release.tagName}).',
              style: const TextStyle(fontWeight: FontWeight.bold),
            ),
            const SizedBox(height: 12),
            const Text('Voulez-vous télécharger et installer la mise à jour?'),
          ],
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('Plus tard'),
          ),
          FilledButton(
            onPressed: () {
              Navigator.pop(context);
              _updateChecker.downloadAndInstall(
                context,
                release,
                onInstallComplete: () {
                  SystemNavigator.pop();
                },
              );
            },
            child: const Text('Mettre à jour'),
          ),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    const seedColor = Color(0xFFB9472E);
    final colorScheme = ColorScheme.fromSeed(
      seedColor: seedColor,
      brightness: Brightness.light,
    );

    return MaterialApp(
      title: 'Recettes Ananas',
      locale: const Locale('fr'),
      supportedLocales: const [Locale('fr')],
      localizationsDelegates: GlobalMaterialLocalizations.delegates,
      debugShowCheckedModeBanner: false,
      theme: ThemeData(
        useMaterial3: true,
        colorScheme: colorScheme,
        scaffoldBackgroundColor: const Color(0xFFFFFBF8),
        appBarTheme: const AppBarTheme(centerTitle: false),
        inputDecorationTheme: const InputDecorationTheme(
          filled: true,
          fillColor: Colors.white,
          border: OutlineInputBorder(
            borderRadius: BorderRadius.all(Radius.circular(18)),
            borderSide: BorderSide.none,
          ),
          enabledBorder: OutlineInputBorder(
            borderRadius: BorderRadius.all(Radius.circular(18)),
            borderSide: BorderSide.none,
          ),
          focusedBorder: OutlineInputBorder(
            borderRadius: BorderRadius.all(Radius.circular(18)),
            borderSide: BorderSide(color: seedColor, width: 1.5),
          ),
        ),
        cardTheme: const CardThemeData(
          elevation: 0,
          margin: EdgeInsets.zero,
          color: Colors.white,
        ),
      ),
      home: HomePage(repository: widget.repository),
    );
  }
}
