import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_localizations/flutter_localizations.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'screens/home_page.dart';
import 'services/recipe_repository.dart';
import 'services/update_checker.dart';

/// Configuration publique GitHub pour la vérification automatique des versions.
const _githubOwner = 'Whisper40';
const _githubRepo = 'recipe-ananas';
final _navigatorKey = GlobalKey<NavigatorState>();

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();
  final repository = RecipeRepository();
  await repository.init();
  final preferences = await SharedPreferences.getInstance();
  runApp(
    RecipeBoxApp(
      repository: repository,
      preferences: preferences,
      updateChannel: UpdateChannel.fromStorage(
        preferences.getString(updateChannelStorageKey),
      ),
    ),
  );
}

class RecipeBoxApp extends StatefulWidget {
  const RecipeBoxApp({
    required this.repository,
    this.updateChecker,
    this.preferences,
    this.updateChannel = UpdateChannel.stable,
    super.key,
  });

  final RecipeRepository repository;
  final UpdateChecker? updateChecker;
  final SharedPreferences? preferences;
  final UpdateChannel updateChannel;

  @override
  State<RecipeBoxApp> createState() => _RecipeBoxAppState();
}

class _RecipeBoxAppState extends State<RecipeBoxApp> {
  late final UpdateChecker _updateChecker;
  late UpdateChannel _updateChannel;

  @override
  void initState() {
    super.initState();
    _updateChannel = widget.updateChannel;
    _updateChecker =
        widget.updateChecker ??
        UpdateChecker(
          owner: _githubOwner,
          repo: _githubRepo,
          channel: _updateChannel,
        );
    WidgetsBinding.instance.addPostFrameCallback((_) {
      _checkForUpdates();
    });
  }

  Future<void> _setUpdateChannel(UpdateChannel channel) async {
    setState(() {
      _updateChannel = channel;
      _updateChecker.channel = channel;
    });
    await widget.preferences?.setString(updateChannelStorageKey, channel.name);
  }

  Future<void> _checkForUpdates() async {
    try {
      final release = await _updateChecker.checkForUpdate();

      if (!mounted) return;
      if (release != null) _showUpdateDialog(release);
    } catch (_) {
      // La vérification automatique ne doit pas perturber l’utilisation de l’application.
    }
  }

  void _showUpdateDialog(GitHubRelease release) {
    final dialogContext = _navigatorKey.currentContext;
    if (dialogContext == null) return;
    showDialog(
      context: dialogContext,
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
                dialogContext,
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
      navigatorKey: _navigatorKey,
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
      home: HomePage(
        repository: widget.repository,
        updateChannel: _updateChannel,
        onUpdateChannelChanged: _setUpdateChannel,
      ),
    );
  }
}
