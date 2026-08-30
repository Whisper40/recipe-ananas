import 'package:flutter_test/flutter_test.dart';
import 'package:recette_box/services/recipe_ocr_service.dart';

void main() {
  test('combine les textes OCR dans l’ordre des captures', () {
    expect(
      RecipeOcrService.combineTexts([
        '  Ingrédients  ',
        '',
        '2 œufs\n100 g de farine #recette',
        '   ',
      ]),
      'Ingrédients\n\n2 œufs\n100 g de farine',
    );
  });

  test('supprime les hashtags et les lignes qui ne contiennent que cela', () {
    expect(
      RecipeOcrService.removeHashtags(
        'Tarte aux pommes #recette\n#dessert #faitmaison\nCuire 30 min',
      ),
      'Tarte aux pommes\nCuire 30 min',
    );
  });
}
