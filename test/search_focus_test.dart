import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:recette_box/models/recipe.dart';
import 'package:recette_box/screens/home_page.dart';
import 'package:recette_box/services/recipe_repository.dart';
import 'package:shared_preferences/shared_preferences.dart';

void main() {
  testWidgets(
    'le retour d’une recette ne redonne pas le focus à la recherche',
    (tester) async {
      SharedPreferences.setMockInitialValues({});
      final repository = RecipeRepository();
      await repository.init();
      await repository.saveAll([
        Recipe.create(
          title: 'Tarte aux pommes',
          ingredients: 'Pommes',
          description: 'Cuire.',
          rating: 0,
        ),
      ]);

      await tester.pumpWidget(
        MaterialApp(home: HomePage(repository: repository)),
      );

      final searchField = find.byType(TextField).first;
      await tester.tap(searchField);
      await tester.enterText(searchField, 'Tarte');
      await tester.pump();
      expect(
        tester
            .widget<EditableText>(find.byType(EditableText))
            .focusNode
            .hasFocus,
        isTrue,
      );

      await tester.tap(find.text('Tarte aux pommes'));
      await tester.pumpAndSettle();
      expect(find.text('Recette'), findsOneWidget);

      await tester.pageBack();
      await tester.pumpAndSettle();

      expect(
        tester
            .widget<EditableText>(find.byType(EditableText))
            .focusNode
            .hasFocus,
        isFalse,
      );
      expect(tester.testTextInput.isVisible, isFalse);
    },
  );
}
