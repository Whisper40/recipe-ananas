import 'dart:convert';

import 'package:archive/archive.dart';
import 'package:shared_preferences/shared_preferences.dart';

import '../models/recipe.dart';

class RecipeBackup {
  const RecipeBackup({required this.recipes, required this.categories});

  final List<Recipe> recipes;
  final List<String> categories;
}

class RecipeRepository {
  static const _storageKey = 'recette_box_recipes_v1';
  static const _categoriesStorageKey = 'recette_box_categories_v1';
  late SharedPreferences _preferences;
  List<Recipe> _recipes = <Recipe>[];
  List<String> _categories = <String>[];

  List<Recipe> get recipes => List.unmodifiable(_recipes);
  List<String> get categories => List.unmodifiable(_categories);

  Future<void> init() async {
    _preferences = await SharedPreferences.getInstance();
    final encoded = _preferences.getString(_storageKey);
    if (encoded != null && encoded.isNotEmpty) {
      try {
        final decoded = jsonDecode(encoded);
        if (decoded is List) {
          _recipes = decoded
              .whereType<Map>()
              .map((item) => Recipe.fromJson(Map<String, dynamic>.from(item)))
              .where((recipe) => recipe.title.isNotEmpty)
              .toList();
        }
      } on FormatException {
        _recipes = <Recipe>[];
      }
    }

    _categories = Recipe.normaliseCategories(
      _preferences.getStringList(_categoriesStorageKey) ??
          _recipes.expand((recipe) => recipe.categories),
    );
  }

  Future<void> saveAll(
    List<Recipe> recipes, {
    Iterable<String>? categories,
  }) async {
    _recipes = List<Recipe>.from(recipes);
    _categories = Recipe.normaliseCategories(
      categories ?? _recipes.expand((recipe) => recipe.categories),
    );
    await _persist();
  }

  Future<void> upsert(Recipe recipe) async {
    final index = _recipes.indexWhere((item) => item.id == recipe.id);
    if (index == -1) {
      _recipes.add(recipe);
    } else {
      _recipes[index] = recipe;
    }
    _categories = Recipe.normaliseCategories([
      ..._categories,
      ...recipe.categories,
    ]);
    await _persist();
  }

  Future<void> saveCategories(Iterable<String> categories) async {
    _categories = Recipe.normaliseCategories(categories);
    await _persist();
  }

  Future<void> deleteCategory(String category) async {
    final target = category.trim().toLowerCase();
    if (target.isEmpty) return;

    _categories = _categories
        .where((item) => item.toLowerCase() != target)
        .toList();
    _recipes = _recipes.map((recipe) {
      final remainingCategories = recipe.categories
          .where((item) => item.toLowerCase() != target)
          .toList();
      return remainingCategories.length == recipe.categories.length
          ? recipe
          : recipe.copyWith(categories: remainingCategories);
    }).toList();
    await _persist();
  }

  Future<void> delete(String id) async {
    _recipes.removeWhere((recipe) => recipe.id == id);
    await _persist();
  }

  String exportJson() {
    final payload = <String, dynamic>{
      'format': 'recette_box_backup',
      'version': 1,
      'exportedAt': DateTime.now().toIso8601String(),
      'categories': _categories,
      'recipes': _recipes.map((recipe) => recipe.toJson()).toList(),
    };
    return const JsonEncoder.withIndent('  ').convert(payload);
  }

  List<Recipe> parseBackup(String content) {
    return parseBackupData(content).recipes;
  }

  RecipeBackup parseBackupData(String content) {
    final decoded = jsonDecode(content);
    dynamic rawRecipes = decoded;
    dynamic rawCategories;
    if (decoded is Map<String, dynamic>) {
      rawRecipes = decoded['recipes'];
      rawCategories = decoded['categories'];
    }
    if (rawRecipes is! List) {
      throw const FormatException(
        'Le fichier ne contient pas de liste de recettes.',
      );
    }

    final recipes = _recipesFromRaw(rawRecipes);
    if (recipes.isEmpty && rawRecipes.isNotEmpty) {
      throw const FormatException(
        'Aucune recette exploitable dans ce fichier.',
      );
    }
    return RecipeBackup(
      recipes: recipes,
      categories: _categoriesFromRaw(rawCategories, recipes),
    );
  }

  List<Recipe> parseRtkBackup(List<int> content) {
    return parseRtkBackupData(content).recipes;
  }

  RecipeBackup parseRtkBackupData(List<int> content) {
    final archive = ZipDecoder().decodeBytes(content);
    final recipesFile = archive.findFile('recipes_0.json');
    if (recipesFile == null) {
      throw const FormatException(
        'L’archive RTK ne contient pas recipes_0.json.',
      );
    }

    final imageFiles = <String, List<int>>{};
    for (final file in archive.files) {
      if (!file.isFile || !_isImageFile(file.name)) {
        continue;
      }
      imageFiles[_fileName(file.name)] = List<int>.from(
        file.content as List<int>,
      );
    }

    final decoded = jsonDecode(utf8.decode(recipesFile.content as List<int>));
    if (decoded is! List) {
      throw const FormatException(
        'recipes_0.json ne contient pas de liste de recettes.',
      );
    }

    final recipes = _recipesFromRaw(
      decoded,
      imageFiles: imageFiles,
      mergeLegacyFields: true,
    );
    if (recipes.isEmpty && decoded.isNotEmpty) {
      throw const FormatException(
        'Aucune recette exploitable dans cette archive RTK.',
      );
    }
    final categoriesFile = archive.findFile('categories.json');
    final rawCategories = categoriesFile == null
        ? null
        : jsonDecode(utf8.decode(categoriesFile.content as List<int>));
    return RecipeBackup(
      recipes: recipes,
      categories: _categoriesFromRaw(rawCategories, recipes),
    );
  }

  List<String> _categoriesFromRaw(
    dynamic rawCategories,
    Iterable<Recipe> recipes,
  ) {
    final values = <String>[];
    if (rawCategories is String) values.add(rawCategories);
    if (rawCategories is List) {
      values.addAll(
        rawCategories.map((category) {
          if (category is Map) {
            return (category['title'] ?? category['name'] ?? '').toString();
          }
          return category.toString();
        }),
      );
    }
    values.addAll(recipes.expand((recipe) => recipe.categories));
    return Recipe.normaliseCategories(values);
  }

  List<Recipe> _recipesFromRaw(
    dynamic rawRecipes, {
    Map<String, List<int>> imageFiles = const <String, List<int>>{},
    bool mergeLegacyFields = false,
  }) {
    final items = (rawRecipes as List).whereType<Map>();
    return items
        .map<Recipe>((item) {
          final json = Map<String, dynamic>.from(item);
          if (mergeLegacyFields) {
            _mergeMyRecipeBoxFields(json);
          }
          final imageBytes = _findRecipeImage(json['pictures'], imageFiles);
          if (imageBytes != null) {
            json['imageBase64'] = base64Encode(imageBytes);
          }
          return Recipe.fromJson(json);
        })
        .where((Recipe recipe) => recipe.title.isNotEmpty)
        .toList();
  }

  void _mergeMyRecipeBoxFields(Map<String, dynamic> json) {
    json['ingredients'] = _joinSections([
      _textValue(json['ingredients']),
      _section('Quantité / portions', json['quantity']),
    ]);

    final descriptionSections = <String>[
      _section('Description', json['description']),
      _section('Préparation', json['instructions']),
      _section('Préparation', json['preparation']),
      _section('Étapes', json['steps']),
      _section('Notes', json['notes']),
      _section('Temps de préparation', json['preparationTime']),
      _section('Temps de cuisson', json['cookingTime']),
      _section('Temps de repos', json['inactiveTime']),
      _section('Temps total', json['totalTime']),
      _section('Ustensiles', json['cookware']),
      _section('Nutrition', json['nutrition']),
      _section('Lien', json['url']),
      _section('Vidéo', json['video']),
    ];

    const handledFields = <String>{
      'title',
      'uuid',
      'id',
      'rating',
      'lastModifiedDate',
      'updatedAt',
      'pictures',
      'ingredients',
      'quantity',
      'description',
      'instructions',
      'preparation',
      'steps',
      'notes',
      'preparationTime',
      'cookingTime',
      'inactiveTime',
      'totalTime',
      'cookware',
      'nutrition',
      'categories',
      'url',
      'video',
    };
    for (final entry in json.entries) {
      if (!handledFields.contains(entry.key)) {
        descriptionSections.add(_section(entry.key, entry.value));
      }
    }

    json['description'] = _joinSections(descriptionSections);
  }

  String _section(String label, dynamic value) {
    final text = _textValue(value);
    return text.isEmpty ? '' : '$label :\n$text';
  }

  String _joinSections(Iterable<String> sections) {
    return sections.where((section) => section.trim().isNotEmpty).join('\n\n');
  }

  String _textValue(dynamic value) {
    if (value == null) return '';
    if (value is String) return value.trim();
    if (value is List) {
      return value.map(_textValue).where((item) => item.isNotEmpty).join(', ');
    }
    if (value is Map) {
      return value.entries
          .map((entry) => '${entry.key}: ${_textValue(entry.value)}')
          .where((item) => item.trim().isNotEmpty)
          .join(', ');
    }
    return value.toString().trim();
  }

  List<int>? _findRecipeImage(
    dynamic pictures,
    Map<String, List<int>> imageFiles,
  ) {
    if (pictures is! List) return null;
    for (final picture in pictures.whereType<String>()) {
      final image = imageFiles[_fileName(picture)];
      if (image != null) return image;
    }
    return null;
  }

  String _fileName(String path) => path.split('/').last;

  bool _isImageFile(String path) {
    final name = _fileName(path).toLowerCase();
    return name.endsWith('.png') ||
        name.endsWith('.jpg') ||
        name.endsWith('.jpeg') ||
        name.endsWith('.webp');
  }

  Future<void> _persist() async {
    await _preferences.setString(
      _storageKey,
      jsonEncode(_recipes.map((recipe) => recipe.toJson()).toList()),
    );
    await _preferences.setStringList(_categoriesStorageKey, _categories);
  }
}
