import 'dart:convert';

import 'package:http/http.dart' as http;
import 'package:http/testing.dart';
import 'package:recette_box/services/update_checker.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  test(
    'sélectionne la release installable avec la version la plus élevée',
    () async {
      late Uri requestedUri;
      final client = MockClient((request) async {
        requestedUri = request.url;
        return http.Response(
          jsonEncode([
            {
              'tag_name': 'v1.0.3+11',
              'draft': false,
              'prerelease': false,
              'assets': [
                {
                  'browser_download_url':
                      'https://example.com/app-1.0.3+11.apk',
                },
              ],
            },
            {
              'tag_name': 'v1.0.4+0',
              'draft': false,
              'prerelease': false,
              'assets': [
                {'browser_download_url': 'https://example.com/app-1.0.4+0.apk'},
              ],
            },
            {
              'tag_name': 'v1.0.5+0',
              'draft': true,
              'prerelease': false,
              'assets': [
                {'browser_download_url': 'https://example.com/app-1.0.5+0.apk'},
              ],
            },
          ]),
          200,
        );
      });

      final release = await UpdateChecker(
        owner: 'Whisper40',
        repo: 'recipe-ananas',
        client: client,
      ).checkForUpdate();

      expect(requestedUri.path, '/repos/Whisper40/recipe-ananas/releases');
      expect(requestedUri.queryParameters['per_page'], '100');
      expect(release?.tagName, 'v1.0.4+0');
    },
  );
}
