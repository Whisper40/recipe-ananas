import 'dart:convert';

import 'package:http/http.dart' as http;
import 'package:http/testing.dart';
import 'package:package_info_plus/package_info_plus.dart';
import 'package:recette_box/services/update_checker.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  test('utilise la release latest sur le canal stable', () async {
    late Uri requestedUri;
    final client = MockClient((request) async {
      requestedUri = request.url;
      return http.Response(
        jsonEncode({
          'tag_name': 'v1.0.4+2',
          'draft': false,
          'prerelease': false,
          'assets': [
            {'browser_download_url': 'https://example.com/app-1.0.4+2.apk'},
          ],
        }),
        200,
      );
    });

    final release = await UpdateChecker(
      owner: 'Whisper40',
      repo: 'recipe-ananas',
      client: client,
      packageInfoProvider: () async => PackageInfo(
        appName: 'Recettes Ananas',
        packageName: 'com.recettebox.recette_box',
        version: '1.0.3',
        buildNumber: '1',
        buildSignature: '',
      ),
    ).checkForUpdate();

    expect(requestedUri.path, '/repos/Whisper40/recipe-ananas/releases/latest');
    expect(
      int.tryParse(requestedUri.queryParameters['cache_bust'] ?? ''),
      isNotNull,
    );
    expect(release?.tagName, 'v1.0.4+2');
  });

  test('utilise la dernière release publiée sur le canal beta', () async {
    late Uri requestedUri;
    final release = await UpdateChecker(
      owner: 'Whisper40',
      repo: 'recipe-ananas',
      channel: UpdateChannel.beta,
      client: MockClient((request) async {
        requestedUri = request.url;
        return http.Response(
          jsonEncode([
            {
              'tag_name': 'v1.0.7+1',
              'draft': false,
              'prerelease': true,
              'assets': [
                {'browser_download_url': 'https://example.com/app-1.0.7+1.apk'},
              ],
            },
          ]),
          200,
        );
      }),
      packageInfoProvider: () async => PackageInfo(
        appName: 'Recettes Ananas',
        packageName: 'com.recettebox.recette_box',
        version: '1.0.6',
        buildNumber: '12',
        buildSignature: '',
      ),
    ).checkForUpdate();

    expect(requestedUri.path, '/repos/Whisper40/recipe-ananas/releases');
    expect(requestedUri.queryParameters['per_page'], '20');
    expect(release?.tagName, 'v1.0.7+1');
  });

  test('ignore les brouillons sur le canal beta', () async {
    final release = await UpdateChecker(
      owner: 'Whisper40',
      repo: 'recipe-ananas',
      channel: UpdateChannel.beta,
      client: MockClient(
        (_) async => http.Response(
          jsonEncode([
            {
              'tag_name': 'v1.0.7+1',
              'draft': true,
              'assets': [
                {'browser_download_url': 'https://example.com/app-1.0.7+1.apk'},
              ],
            },
          ]),
          200,
        ),
      ),
      packageInfoProvider: () async => PackageInfo(
        appName: 'Recettes Ananas',
        packageName: 'com.recettebox.recette_box',
        version: '1.0.6',
        buildNumber: '12',
        buildSignature: '',
      ),
    ).checkForUpdate();

    expect(release, isNull);
  });
}
