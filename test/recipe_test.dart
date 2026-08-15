import 'dart:convert';

import 'package:archive/archive.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:recette_box/models/recipe.dart';
import 'package:recette_box/services/recipe_repository.dart';

void main() {
  test('une recette se sérialise et se restaure', () {
    final recipe = Recipe.create(
      title: 'Tarte aux pommes',
      ingredients: 'Pommes\nPâte brisée',
      description: 'Cuire 35 minutes.',
      rating: 4,
      imageBase64: base64Encode([1, 2, 3]),
    );

    final restored = Recipe.fromJson(recipe.toJson());

    expect(restored.title, 'Tarte aux pommes');
    expect(restored.ingredients, contains('Pommes'));
    expect(restored.rating, 4);
    expect(restored.imageBase64, base64Encode([1, 2, 3]));
  });

  test('les catégories sont conservées dans le JSON', () {
    final recipe = Recipe.create(
      title: 'Tarte aux pommes',
      ingredients: 'Pommes',
      description: 'Cuire.',
      rating: 4,
      categories: ['Dessert', ' dessert '],
    );

    final restored = Recipe.fromJson(recipe.toJson());

    expect(restored.categories, ['Dessert']);
  });

  test(
    'une catégorie peut être supprimée des recettes et du catalogue',
    () async {
      SharedPreferences.setMockInitialValues({});
      final repository = RecipeRepository();
      await repository.init();
      await repository.saveAll(
        [
          Recipe.create(
            title: 'Tarte',
            ingredients: 'Pommes',
            description: 'Cuire.',
            rating: 4,
            categories: ['Dessert', 'Maison'],
          ),
        ],
        categories: ['Dessert', 'Maison'],
      );

      await repository.deleteCategory('dessert');

      expect(repository.categories, ['Maison']);
      expect(repository.recipes.single.categories, ['Maison']);
    },
  );

  test(
    'un backup Recettes Ananas et un tableau MyRecipeBox sont importables',
    () {
      final repository = RecipeRepository();
      final recipes = repository.parseBackup('''
      {
        "format": "recette_box_backup",
        "recipes": [
          {"id": "1", "title": "Bœuf bourguignon", "ingredients": "Bœuf", "rating": 5}
        ]
      }
    ''');
      final myRecipeBoxRecipes = repository.parseBackup('''
      [{"uuid": "2", "title": "Crêpes", "ingredients": "Farine", "instructions": "Mélanger"}]
    ''');

      expect(recipes.single.title, 'Bœuf bourguignon');
      expect(myRecipeBoxRecipes.single.description, 'Mélanger');
    },
  );

  test('une archive RTK importe la recette et sa photo', () {
    final archive = Archive()
      ..addFile(
        ArchiveFile(
          'recipes_0.json',
          0,
          utf8.encode('''
            [{
              "title": "Tarte",
              "ingredients": "Pommes",
              "quantity": "6 personnes",
              "instructions": "Cuire 35 minutes",
              "notes": "Servir tiède",
              "preparationTime": "15 min",
              "categories": [{"title": "Dessert"}],
              "pictures": ["/data/Pictures/tarte.png"]
            }]
          '''),
        ),
      )
      ..addFile(
        ArchiveFile(
          'categories.json',
          0,
          utf8.encode('''
            [
              {"title": "Entrée"},
              {"title": "Plat"},
              {"title": "Dessert"}
            ]
          '''),
        ),
      )
      ..addFile(ArchiveFile('tarte.png', 0, [137, 80, 78, 71]));

    final backup = RecipeRepository().parseRtkBackupData(
      ZipEncoder().encode(archive)!,
    );
    final recipes = backup.recipes;

    expect(recipes.single.title, 'Tarte');
    expect(recipes.single.ingredients, contains('Pommes'));
    expect(recipes.single.ingredients, contains('6 personnes'));
    expect(recipes.single.description, contains('Préparation :'));
    expect(recipes.single.description, contains('Cuire 35 minutes'));
    expect(recipes.single.description, contains('Notes :'));
    expect(recipes.single.description, contains('15 min'));
    expect(recipes.single.categories, ['Dessert']);
    expect(backup.categories, ['Entrée', 'Plat', 'Dessert']);
    expect(recipes.single.imageBase64, base64Encode([137, 80, 78, 71]));
  });
}
