import 'dart:convert';

import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';
import 'package:package_info_plus/package_info_plus.dart';
import 'package:recette_box/main.dart';
import 'package:recette_box/services/recipe_repository.dart';
import 'package:recette_box/services/update_checker.dart';
import 'package:shared_preferences/shared_preferences.dart';

void main() {
  testWidgets('affiche le dialogue pour une release plus récente', (
    tester,
  ) async {
    SharedPreferences.setMockInitialValues({});
    final repository = RecipeRepository();
    await repository.init();
    final checker = UpdateChecker(
      owner: 'Whisper40',
      repo: 'recipe-ananas',
      client: MockClient(
        (_) async => http.Response(
          jsonEncode([
            {
              'tag_name': 'v1.0.5+0',
              'draft': false,
              'prerelease': false,
              'assets': [
                {'browser_download_url': 'https://example.com/app-release.apk'},
              ],
            },
          ]),
          200,
        ),
      ),
      packageInfoProvider: () async => PackageInfo(
        appName: 'Recettes Ananas',
        packageName: 'com.recettebox.recette_box',
        version: '1.0.4',
        buildNumber: '9',
        buildSignature: '',
      ),
    );

    await tester.pumpWidget(
      RecipeBoxApp(repository: repository, updateChecker: checker),
    );
    await tester.pumpAndSettle();

    expect(find.text('Mise à jour disponible'), findsOneWidget);
    expect(find.textContaining('v1.0.5+0'), findsOneWidget);
  });
}
