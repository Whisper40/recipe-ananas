import 'package:flutter/material.dart';
import 'package:flutter_quill/flutter_quill.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:recette_box/screens/recipe_editor_page.dart';

void main() {
  testWidgets('monte les éditeurs vides pour une nouvelle recette', (
    tester,
  ) async {
    await tester.pumpWidget(const MaterialApp(home: RecipeEditorPage()));
    await tester.pump();

    final scrollable = find.byType(Scrollable).first;
    await tester.drag(scrollable, const Offset(0, -700));
    await tester.pump();
    expect(find.byType(QuillRawEditor), findsNWidgets(2));
    expect(tester.takeException(), isNull);
  });
}
