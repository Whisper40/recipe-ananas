import 'dart:convert';
import 'dart:io';

import 'package:flutter/material.dart';
import 'package:flutter_app_installer/flutter_app_installer.dart';
import 'package:http/http.dart' as http;
import 'package:package_info_plus/package_info_plus.dart';
import 'package:path_provider/path_provider.dart';

/// Modèle pour une release GitHub.
class GitHubRelease {
  GitHubRelease({
    required this.tagName,
    required this.downloadUrl,
    required this.body,
    required this.createdAt,
  });

  final String tagName;
  final String downloadUrl;
  final String body;
  final DateTime createdAt;

  factory GitHubRelease.fromJson(Map<String, dynamic> json) {
    final assets = json['assets'] is List<dynamic>
        ? json['assets'] as List<dynamic>
        : const <dynamic>[];
    var downloadUrl = '';
    for (final asset in assets) {
      if (asset is! Map<String, dynamic>) continue;
      final candidate = asset['browser_download_url'];
      if (candidate is String && candidate.toLowerCase().endsWith('.apk')) {
        downloadUrl = candidate;
        break;
      }
    }

    return GitHubRelease(
      tagName: json['tag_name'] as String? ?? '',
      downloadUrl: downloadUrl,
      body: json['body'] as String? ?? '',
      createdAt: DateTime.tryParse(json['created_at'] as String? ?? '') ??
          DateTime.fromMillisecondsSinceEpoch(0),
    );
  }
}

/// Service de vérification et d’installation des mises à jour.
class UpdateChecker {
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

  Future<GitHubRelease?> checkForUpdate() async {
    try {
      final headers = <String, String>{
        'Accept': 'application/vnd.github+json',
      };
      if (token != null && token!.isNotEmpty) {
        headers['Authorization'] = 'Bearer $token';
      }

      final response = await http.get(Uri.parse(_apiUrl), headers: headers);
      if (response.statusCode == 404) return null;
      if (response.statusCode != 200) {
        debugPrint(
          'Erreur GitHub API: ${response.statusCode} - ${response.body}',
        );
        return null;
      }

      return GitHubRelease.fromJson(
        jsonDecode(response.body) as Map<String, dynamic>,
      );
    } catch (error) {
      debugPrint('Erreur vérification mise à jour: $error');
      return null;
    }
  }

  /// Retourne true uniquement si la release GitHub est réellement plus récente.
  Future<bool> isUpdateAvailable(GitHubRelease release) async {
    try {
      final info = await PackageInfo.fromPlatform();
      final current = _AppVersion.parse(info.version, info.buildNumber);
      final available = _AppVersion.parseTag(release.tagName);
      return current != null &&
          available != null &&
          available.compareTo(current) > 0;
    } catch (error) {
      debugPrint('Erreur comparaison version: $error');
      return false;
    }
  }

  Future<void> downloadAndInstall(
    BuildContext context,
    GitHubRelease release, {
    required VoidCallback onInstallComplete,
  }) async {
    final messenger = ScaffoldMessenger.maybeOf(context);
    if (release.downloadUrl.isEmpty) {
      messenger?.showSnackBar(
        const SnackBar(
          content: Text('Aucun APK n’est disponible dans cette release.'),
          backgroundColor: Colors.red,
        ),
      );
      return;
    }

    try {
      final apkPath = await showDialog<String>(
        context: context,
        barrierDismissible: false,
        builder: (_) => _DownloadDialog(
          download: (onProgress) => _downloadApk(
            release.downloadUrl,
            onProgress: onProgress,
          ),
        ),
      );
      if (!context.mounted || apkPath == null) return;

      final installed = await FlutterAppInstaller().installApk(
        filePath: apkPath,
      );
      if (!context.mounted) return;
      if (!installed) {
        messenger?.showSnackBar(
          const SnackBar(
            content: Text(
              'Android n’a pas lancé l’installation. Vérifiez l’autorisation « installer des applications inconnues ».',
            ),
            backgroundColor: Colors.red,
          ),
        );
        return;
      }

      messenger?.showSnackBar(
        const SnackBar(
          content: Text('Installation lancée. Confirmez-la dans Android.'),
          backgroundColor: Colors.green,
        ),
      );
      await Future<void>.delayed(const Duration(seconds: 2));
      if (context.mounted) onInstallComplete();
    } catch (error) {
      if (context.mounted) {
        messenger?.showSnackBar(
          SnackBar(
            content: Text('Erreur lors de l’installation : $error'),
            backgroundColor: Colors.red,
          ),
        );
      }
    }
  }

  Future<String?> _downloadApk(
    String url, {
    required void Function(int received, int total) onProgress,
  }) async {
    final client = http.Client();
    IOSink? sink;
    try {
      final response = await client.send(http.Request('GET', Uri.parse(url)));
      if (response.statusCode != 200) return null;

      final directory = await getApplicationSupportDirectory();
      final file = File('${directory.path}/recette-box-update.apk');
      sink = file.openWrite();
      final total = response.contentLength ?? -1;
      var received = 0;
      await for (final chunk in response.stream) {
        sink.add(chunk);
        received += chunk.length;
        onProgress(received, total);
      }
      await sink.flush();
      await sink.close();
      sink = null;
      return file.path;
    } catch (error) {
      debugPrint('Erreur téléchargement APK: $error');
      return null;
    } finally {
      await sink?.close();
      client.close();
    }
  }
}

class _AppVersion implements Comparable<_AppVersion> {
  const _AppVersion(this.major, this.minor, this.patch, this.build);

  final int major;
  final int minor;
  final int patch;
  final int build;

  static _AppVersion? parse(String version, String build) {
    final match = RegExp(r'^(\d+)\.(\d+)\.(\d+)$').firstMatch(version.trim());
    if (match == null) return null;
    return _AppVersion(
      int.parse(match.group(1)!),
      int.parse(match.group(2)!),
      int.parse(match.group(3)!),
      int.tryParse(build.trim()) ?? 0,
    );
  }

  static _AppVersion? parseTag(String tag) {
    final normalized = tag.trim().replaceFirst(RegExp(r'^v'), '');
    final parts = normalized.split('+');
    if (parts.length > 2) return null;
    return parse(parts.first, parts.length == 2 ? parts[1] : '0');
  }

  @override
  int compareTo(_AppVersion other) {
    final versionComparison = _compareInts(major, other.major);
    if (versionComparison != 0) return versionComparison;
    final minorComparison = _compareInts(minor, other.minor);
    if (minorComparison != 0) return minorComparison;
    final patchComparison = _compareInts(patch, other.patch);
    if (patchComparison != 0) return patchComparison;
    return _compareInts(build, other.build);
  }

  static int _compareInts(int first, int second) =>
      first == second ? 0 : (first < second ? -1 : 1);
}

class _DownloadDialog extends StatefulWidget {
  const _DownloadDialog({required this.download});

  final Future<String?> Function(void Function(int received, int total))
      download;

  @override
  State<_DownloadDialog> createState() => _DownloadDialogState();
}

class _DownloadDialogState extends State<_DownloadDialog> {
  double? _progress;
  bool _finished = false;

  @override
  void initState() {
    super.initState();
    _download();
  }

  Future<void> _download() async {
    final path = await widget.download((received, total) {
      if (!mounted) return;
      setState(() {
        _progress = total > 0 ? received / total : null;
      });
    });
    if (!mounted) return;
    setState(() => _finished = true);
    if (path == null) {
      Navigator.of(context).pop();
      return;
    }
    await Future<void>.delayed(const Duration(milliseconds: 300));
    if (mounted) Navigator.of(context).pop(path);
  }

  @override
  Widget build(BuildContext context) {
    return AlertDialog(
      title: const Text('Mise à jour disponible'),
      content: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          const Text('Téléchargement de la nouvelle version…'),
          const SizedBox(height: 16),
          LinearProgressIndicator(value: _progress),
          if (_finished) ...[
            const SizedBox(height: 8),
            const Text(
              'Téléchargement terminé.',
              style: TextStyle(color: Colors.green),
            ),
          ],
        ],
      ),
      actions: [
        TextButton(
          onPressed: _finished ? null : () => Navigator.pop(context),
          child: const Text('Annuler'),
        ),
      ],
    );
  }
}