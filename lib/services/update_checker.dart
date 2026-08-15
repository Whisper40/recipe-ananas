import 'dart:convert';
import 'dart:io';

import 'package:flutter_app_installer/flutter_app_installer.dart';
import 'package:flutter/material.dart';
import 'package:http/http.dart' as http;
import 'package:package_info_plus/package_info_plus.dart';
import 'package:path_provider/path_provider.dart';
import 'package:permission_handler/permission_handler.dart';
import 'package:shared_preferences/shared_preferences.dart';

/// Modèle pour une release GitHub
class GitHubRelease {
  final String tagName;
  final String downloadUrl;
  final String body;
  final DateTime createdAt;

  GitHubRelease({
    required this.tagName,
    required this.downloadUrl,
    required this.body,
    required this.createdAt,
  });

  factory GitHubRelease.fromJson(Map<String, dynamic> json) {
    return GitHubRelease(
      tagName: json['tag_name'] as String,
      downloadUrl: json['assets']?.isNotEmpty == true
          ? (json['assets'][0]['browser_download_url'] as String?) ?? ''
          : '',
      body: json['body'] as String? ?? '',
      createdAt: DateTime.parse(json['created_at'] as String),
    );
  }
}

/// Service de vérification des mises à jour
class UpdateChecker {
  static const _storageKey = 'last_checked_version';

  final String owner;
  final String repo;
  final String? token;

  UpdateChecker({
    required this.owner,
    required this.repo,
    this.token,
  });

  String get _apiUrl =>
      'https://api.github.com/repos/$owner/$repo/releases/latest';

  /// Vérifie s'il existe une nouvelle version disponible
  Future<GitHubRelease?> checkForUpdate() async {
    try {
      final headers = <String, String>{
        'Accept': 'application/vnd.github.v3+json',
      };

      // Pour les repos privés, ajoute le token GitHub
      if (token != null && token!.isNotEmpty) {
        headers['Authorization'] = 'Bearer $token';
      }

      final response = await http.get(Uri.parse(_apiUrl), headers: headers);

      if (response.statusCode == 200) {
        final data = jsonDecode(response.body) as Map<String, dynamic>;
        return GitHubRelease.fromJson(data);
      } else if (response.statusCode == 404) {
        // Pas de release trouvée
        return null;
      } else {
        debugPrint(
            'Erreur GitHub API: ${response.statusCode} - ${response.body}');
        return null;
      }
    } catch (e) {
      debugPrint('Erreur vérification mise à jour: $e');
      return null;
    }
  }

  /// Compare la version actuelle avec la version GitHub
  /// Retourne true si une mise à jour est disponible
  Future<bool> isUpdateAvailable(GitHubRelease release) async {
    try {
      final info = await PackageInfo.fromPlatform();
      final currentVersion = info.version.split('+').first;
      final currentBuild = int.tryParse(info.buildNumber) ?? 0;

      final normalizedTag = release.tagName.trim().replaceFirst(RegExp(r'^v'), '');
      final tagParts = normalizedTag.split('+');
      final githubVersion = tagParts.first;
      final githubBuild = tagParts.length > 1 ? int.tryParse(tagParts[1]) ?? 0 : 0;

      if (githubVersion != currentVersion) {
        return true;
      }

      if (githubBuild > currentBuild) {
        return true;
      }

      return false;
    } catch (e) {
      debugPrint('Erreur comparaison version: $e');
      return false;
    }
  }

  /// Télécharge et installe la nouvelle version
  Future<void> downloadAndInstall(
    BuildContext context,
    GitHubRelease release, {
    required VoidCallback onInstallComplete,
  }) async {
    final messenger = ScaffoldMessenger.maybeOf(context);
    final storageStatus = await Permission.storage.request();
    final manageStatus = await Permission.manageExternalStorage.request();

    if (!context.mounted) return;
    if (!storageStatus.isGranted && !manageStatus.isGranted) {
      messenger?.showSnackBar(
        const SnackBar(
          content: Text('Permission de stockage requise pour installer l\'APK.'),
          backgroundColor: Colors.red,
        ),
      );
      return;
    }

    try {
      if (!context.mounted) return;
      final confirmed = await showDialog<bool>(
        context: context,
        barrierDismissible: false,
        builder: (_) => _DownloadDialog(url: release.downloadUrl),
      );

      if (!context.mounted) return;
      if (confirmed != true) {
        return;
      }

      final apkPath = await _downloadApk(release.downloadUrl);
      if (!context.mounted) return;
      if (apkPath == null) {
        messenger?.showSnackBar(
          const SnackBar(
            content: Text('Erreur lors du téléchargement de l\'APK.'),
            backgroundColor: Colors.red,
          ),
        );
        return;
      }

      final installer = FlutterAppInstaller();
      await installer.installApk(filePath: apkPath);
      if (!context.mounted) return;
      await _saveLastCheckedVersion(release.tagName);
      messenger?.showSnackBar(
        const SnackBar(
          content: Text('Installation lancée.'),
          backgroundColor: Colors.green,
        ),
      );
      await Future.delayed(const Duration(seconds: 2));
      if (!context.mounted) return;
      onInstallComplete();
    } catch (e) {
      if (context.mounted) {
        messenger?.showSnackBar(
          SnackBar(
            content: Text('Erreur lors du téléchargement: $e'),
            backgroundColor: Colors.red,
          ),
        );
      }
    }
  }

  /// Télécharge l'APK et retourne le chemin local
  Future<String?> _downloadApk(String url) async {
    try {
      final client = http.Client();
      final request = http.Request('GET', Uri.parse(url));
      final streamedResponse = await client.send(request);

      if (streamedResponse.statusCode != 200) {
        client.close();
        return null;
      }

      final directory = await getApplicationDocumentsDirectory();
      final apkPath = '${directory.path}/recette-box-update.apk';
      final file = File(apkPath);

      final bytes = <int>[];
      await for (final chunk in streamedResponse.stream) {
        bytes.addAll(chunk);
      }

      await file.writeAsBytes(bytes);
      client.close();
      return apkPath;
    } catch (e) {
      debugPrint('Erreur téléchargement APK: $e');
      return null;
    }
  }

  /// Sauvegarde la dernière version vérifiée
  Future<void> _saveLastCheckedVersion(String version) async {
    try {
      final prefs = await SharedPreferences.getInstance();
      await prefs.setString(_storageKey, version);
    } catch (e) {
      debugPrint('Erreur sauvegarde version: $e');
    }
  }

}

/// Dialog de progression du téléchargement
class _DownloadDialog extends StatefulWidget {
  final String url;

  const _DownloadDialog({required this.url});

  @override
  State<_DownloadDialog> createState() => _DownloadDialogState();
}

class _DownloadDialogState extends State<_DownloadDialog> {
  double _progress = 0;
  bool _isComplete = false;

  @override
  void initState() {
    super.initState();
    _download();
  }

  Future<void> _download() async {
    try {
      final response = await http.get(Uri.parse(widget.url));
      
      if (response.statusCode == 200) {
        int downloaded = 0;

        // Utiliser http.StreamedResponse pour le suivi de progression
        final client = http.Client();
        final request = http.Request('GET', Uri.parse(widget.url));
        final streamedResponse = await client.send(request);

        if (streamedResponse.statusCode == 200) {
          final contentLength = streamedResponse.contentLength ?? 1;
          final bytes = <int>[];
          
          await for (final chunk in streamedResponse.stream) {
            bytes.addAll(chunk);
            downloaded += chunk.length;
            
            if (mounted) {
              setState(() {
                _progress = downloaded / contentLength;
              });
            }
          }

          if (mounted) {
            setState(() {
              _progress = 1.0;
              _isComplete = true;
            });
            
            // Fermer le dialog après un court délai
            await Future.delayed(const Duration(seconds: 1));
            if (mounted) {
              Navigator.of(context).pop(1.0);
            }
          }
        }
      }
    } catch (e) {
      if (mounted) {
        setState(() {
          _isComplete = true;
        });
        Navigator.of(context).pop(0.0);
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return AlertDialog(
      title: const Text('Mise à jour disponible'),
      content: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          const Text('Téléchargement de la nouvelle version...'),
          const SizedBox(height: 16),
          LinearProgressIndicator(value: _progress),
          if (_isComplete) ...[
            const SizedBox(height: 8),
            const Text('Téléchargement terminé!', style: TextStyle(color: Colors.green)),
          ],
        ],
      ),
      actions: [
        TextButton(
          onPressed: _isComplete ? null : () => Navigator.pop(context),
          child: const Text('Annuler'),
        ),
      ],
    );
  }
}