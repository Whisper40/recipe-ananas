class Recipe {
  const Recipe({
    required this.id,
    required this.title,
    required this.ingredients,
    required this.description,
    required this.rating,
    this.categories = const <String>[],
    this.imageBase64,
    required this.updatedAt,
  });

  factory Recipe.create({
    required String title,
    required String ingredients,
    required String description,
    required int rating,
    List<String> categories = const <String>[],
    String? imageBase64,
  }) {
    final now = DateTime.now();
    return Recipe(
      id: now.microsecondsSinceEpoch.toString(),
      title: title.trim(),
      ingredients: ingredients.trim(),
      description: description.trim(),
      rating: rating.clamp(0, 5),
      categories: normaliseCategories(categories),
      imageBase64: imageBase64,
      updatedAt: now,
    );
  }

  factory Recipe.fromJson(Map<String, dynamic> json) {
    final rawRating = json['rating'];
    final rating = rawRating is num ? rawRating.round() : 0;
    final rawDate = json['updatedAt'] ?? json['lastModifiedDate'];
    final updatedAt = rawDate is String
        ? DateTime.tryParse(rawDate.replaceFirst(' ', 'T')) ?? DateTime.now()
        : DateTime.now();
    final rawCategories = json['categories'] ?? json['category'];

    return Recipe(
      id: (json['id'] ?? json['uuid'] ?? updatedAt.microsecondsSinceEpoch)
          .toString(),
      title: (json['title'] ?? '').toString().trim(),
      ingredients: (json['ingredients'] ?? '').toString().trim(),
      description: (json['description'] ?? json['instructions'] ?? '')
          .toString()
          .trim(),
      rating: rating.clamp(0, 5),
      categories: _parseCategories(rawCategories),
      imageBase64: (json['imageBase64'] ?? json['image'])?.toString(),
      updatedAt: updatedAt,
    );
  }

  final String id;
  final String title;
  final String ingredients;
  final String description;
  final int rating;
  final List<String> categories;
  final String? imageBase64;
  final DateTime updatedAt;

  Recipe copyWith({
    String? title,
    String? ingredients,
    String? description,
    int? rating,
    List<String>? categories,
    bool clearCategories = false,
    String? imageBase64,
    bool clearImage = false,
  }) {
    return Recipe(
      id: id,
      title: title?.trim() ?? this.title,
      ingredients: ingredients?.trim() ?? this.ingredients,
      description: description?.trim() ?? this.description,
      rating: (rating ?? this.rating).clamp(0, 5),
      categories: clearCategories
          ? const <String>[]
          : normaliseCategories(categories ?? this.categories),
      imageBase64: clearImage ? null : imageBase64 ?? this.imageBase64,
      updatedAt: DateTime.now(),
    );
  }

  Map<String, dynamic> toJson() => {
    'id': id,
    'title': title,
    'ingredients': ingredients,
    'description': description,
    'rating': rating,
    if (categories.isNotEmpty) 'categories': categories,
    if (imageBase64 != null) 'imageBase64': imageBase64,
    'updatedAt': updatedAt.toIso8601String(),
  };

  static List<String> _parseCategories(dynamic rawCategories) {
    if (rawCategories is String) return normaliseCategories([rawCategories]);
    if (rawCategories is! List) return const <String>[];

    return normaliseCategories(
      rawCategories.map((category) {
        if (category is Map) {
          return (category['title'] ?? category['name'] ?? '').toString();
        }
        return category.toString();
      }),
    );
  }

  static List<String> normaliseCategories(Iterable<String> values) {
    final result = <String>[];
    final seen = <String>{};
    for (final value in values) {
      final category = value.trim();
      final key = category.toLowerCase();
      if (category.isNotEmpty && seen.add(key)) result.add(category);
    }
    return List.unmodifiable(result);
  }
}
