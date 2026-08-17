import 'dart:convert';
import 'dart:typed_data';

import 'package:file_picker/file_picker.dart';
import 'package:flutter/material.dart';
import 'package:package_info_plus/package_info_plus.dart';

import '../models/recipe.dart';
import '../services/recipe_repository.dart';
import 'recipe_editor_page.dart';

enum _RecipeMenuAction { export, import }

class HomePage extends StatefulWidget {
  const HomePage({required this.repository, super.key});

  final RecipeRepository repository;

  @override
  State<HomePage> createState() => _HomePageState();
}

class _HomePageState extends State<HomePage> {
  final _searchController = TextEditingController();
  String _searchQuery = '';
  String? _selectedCategory;
  late List<Recipe> _recipes;
  late List<String> _categories;
  bool _isBusy = false;
  String _appVersion = '...';

  @override
  void initState() {
    super.initState();
    _recipes = [...widget.repository.recipes];
    _categories = [...widget.repository.categories];
    _searchController.addListener(() {
      setState(() => _searchQuery = _searchController.text);
    });
    _loadAppVersion();
  }

  Future<void> _loadAppVersion() async {
    try {
      final info = await PackageInfo.fromPlatform();
      if (!mounted) return;
      setState(() {
        _appVersion = '${info.version}+${info.buildNumber}';
      });
    } catch (_) {
      if (!mounted) return;
      setState(() => _appVersion = 'version inconnue');
    }
  }

  @override
  void dispose() {
    _searchController.dispose();
    super.dispose();
  }

  List<Recipe> get _visibleRecipes {
    final query = _searchQuery.trim().toLowerCase();
    final result = _recipes
        .where(
          (recipe) =>
              query.isEmpty || recipe.title.toLowerCase().contains(query),
        )
        .where(
          (recipe) =>
              _selectedCategory == null ||
              recipe.categories.any(
                (category) =>
                    category.toLowerCase() == _selectedCategory!.toLowerCase(),
              ),
        )
        .toList();
    result.sort(
      (a, b) => a.title.toLowerCase().compareTo(b.title.toLowerCase()),
    );
    return result;
  }

  Future<void> _openEditor([Recipe? recipe]) async {
    final result = await Navigator.of(context).push<Recipe>(
      MaterialPageRoute(
        builder: (_) => RecipeEditorPage(
          recipe: recipe,
          categories: _categories,
          onCreateCategory: _createCategory,
        ),
      ),
    );
    if (result == null || !mounted) return;
    await widget.repository.upsert(result);
    if (!mounted) return;
    setState(() => _recipes = [...widget.repository.recipes]);
    _showMessage(recipe == null ? 'Recette créée.' : 'Recette mise à jour.');
  }

  Future<String?> _createCategory() async {
    final controller = TextEditingController();
    final category = await showDialog<String>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Nouvelle catégorie'),
        content: TextField(
          controller: controller,
          autofocus: true,
          textCapitalization: TextCapitalization.sentences,
          decoration: const InputDecoration(
            labelText: 'Nom de la catégorie',
            hintText: 'Ex. Apéro',
          ),
          onSubmitted: (_) => Navigator.pop(context, controller.text),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('Annuler'),
          ),
          FilledButton(
            onPressed: () => Navigator.pop(context, controller.text),
            child: const Text('Créer'),
          ),
        ],
      ),
    );
    controller.dispose();
    if (!mounted || category == null) return null;
    final trimmed = category.trim();
    if (trimmed.isEmpty) return null;
    final existing = _categories.where(
      (item) => item.toLowerCase() == trimmed.toLowerCase(),
    );
    if (existing.isNotEmpty) {
      _showMessage('Cette catégorie existe déjà.');
      return existing.first;
    }
    final updatedCategories = [..._categories, trimmed]..sort(_compareText);
    await widget.repository.saveCategories(updatedCategories);
    if (!mounted) return trimmed;
    setState(() => _categories = updatedCategories);
    return trimmed;
  }

  Future<void> _manageCategories() async {
    if (_categories.isEmpty) return;
    final category = await showModalBottomSheet<String>(
      context: context,
      showDragHandle: true,
      builder: (context) => SafeArea(
        child: ListView(
          shrinkWrap: true,
          padding: const EdgeInsets.only(bottom: 16),
          children: [
            const ListTile(
              title: Text('Gérer les catégories'),
              subtitle: Text('Sélectionnez une catégorie à supprimer.'),
            ),
            ..._categories.map(
              (category) => ListTile(
                leading: const Icon(Icons.label_outline_rounded),
                title: Text(category),
                subtitle: Text(
                  '${_recipes.where((recipe) => recipe.categories.any((item) => item.toLowerCase() == category.toLowerCase())).length} recette(s)',
                ),
                trailing: IconButton(
                  tooltip: 'Supprimer la catégorie',
                  icon: const Icon(Icons.delete_outline_rounded),
                  onPressed: () => Navigator.pop(context, category),
                ),
              ),
            ),
          ],
        ),
      ),
    );
    if (category == null || !mounted) return;

    final recipeCount = _recipes
        .where(
          (recipe) => recipe.categories.any(
            (item) => item.toLowerCase() == category.toLowerCase(),
          ),
        )
        .length;
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Supprimer la catégorie ?'),
        content: Text(
          recipeCount == 0
              ? 'La catégorie « $category » sera supprimée définitivement.'
              : 'La catégorie « $category » sera retirée de $recipeCount recette(s) et supprimée définitivement.',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            child: const Text('Annuler'),
          ),
          FilledButton(
            onPressed: () => Navigator.pop(context, true),
            child: const Text('Supprimer'),
          ),
        ],
      ),
    );
    if (confirmed != true) return;

    await widget.repository.deleteCategory(category);
    if (!mounted) return;
    setState(() {
      _categories = [...widget.repository.categories];
      _recipes = [...widget.repository.recipes];
      if (_selectedCategory?.toLowerCase() == category.toLowerCase()) {
        _selectedCategory = null;
      }
    });
    _showMessage('Catégorie supprimée.');
  }

  int _compareText(String first, String second) =>
      first.toLowerCase().compareTo(second.toLowerCase());

  Future<void> _deleteRecipe(Recipe recipe) async {
    final shouldDelete = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Supprimer la recette ?'),
        content: Text('« ${recipe.title} » sera supprimée définitivement.'),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            child: const Text('Annuler'),
          ),
          FilledButton(
            onPressed: () => Navigator.pop(context, true),
            child: const Text('Supprimer'),
          ),
        ],
      ),
    );
    if (shouldDelete != true) return;
    await widget.repository.delete(recipe.id);
    if (!mounted) return;
    setState(() => _recipes = [...widget.repository.recipes]);
    _showMessage('Recette supprimée.');
  }

  Future<void> _exportRecipes() async {
    if (_isBusy) return;
    setState(() => _isBusy = true);
    try {
      final timestamp = _fileTimestamp(DateTime.now());
      final savedPath = await FilePicker.saveFile(
        dialogTitle: 'Enregistrer la sauvegarde',
        fileName: 'recettes_$timestamp.json',
        type: FileType.custom,
        allowedExtensions: ['json'],
        bytes: Uint8List.fromList(utf8.encode(widget.repository.exportJson())),
      );
      if (mounted && savedPath != null) _showMessage('Sauvegarde exportée.');
    } catch (error) {
      if (mounted) _showMessage('Export impossible : $error');
    } finally {
      if (mounted) setState(() => _isBusy = false);
    }
  }

  Future<void> _importRecipes() async {
    if (_isBusy) return;
    try {
      final result = await FilePicker.pickFiles(
        type: FileType.custom,
        allowedExtensions: ['json', 'rtk'],
      );
      if (result.isEmpty) {
        return;
      }

      final picked = result.single;
      final bytes = await picked.readAsBytes();
      final importedBackup = picked.name.toLowerCase().endsWith('.rtk')
          ? widget.repository.parseRtkBackupData(bytes)
          : widget.repository.parseBackupData(utf8.decode(bytes));
      final importedRecipes = importedBackup.recipes;
      if (!mounted) return;

      final confirmed = await showDialog<bool>(
        context: context,
        builder: (context) => AlertDialog(
          icon: const Icon(Icons.warning_amber_rounded),
          title: const Text('Remplacer les recettes actuelles ?'),
          content: Text(
            'Cette restauration va supprimer les ${_recipes.length} recette(s) présentes sur le téléphone et les remplacer par ${importedRecipes.length} recette(s). Cette action est irréversible.',
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(context, false),
              child: const Text('Annuler'),
            ),
            FilledButton(
              onPressed: () => Navigator.pop(context, true),
              child: const Text('Restaurer'),
            ),
          ],
        ),
      );
      if (confirmed != true) return;

      setState(() => _isBusy = true);
      await widget.repository.saveAll(
        importedRecipes,
        categories: importedBackup.categories,
      );
      if (!mounted) return;
      setState(() {
        _recipes = [...widget.repository.recipes];
        _categories = [...widget.repository.categories];
        _selectedCategory = null;
      });
      _showMessage('${importedRecipes.length} recette(s) restaurée(s).');
    } on FormatException catch (error) {
      if (mounted) _showMessage('Fichier invalide : ${error.message}');
    } catch (error) {
      if (mounted) _showMessage('Import impossible : $error');
    } finally {
      if (mounted) setState(() => _isBusy = false);
    }
  }

  String _fileTimestamp(DateTime date) {
    String two(int value) => value.toString().padLeft(2, '0');
    return '${date.year}${two(date.month)}${two(date.day)}_${two(date.hour)}${two(date.minute)}${two(date.second)}';
  }

  void _showMessage(String message) {
    ScaffoldMessenger.of(context)
      ..hideCurrentSnackBar()
      ..showSnackBar(SnackBar(content: Text(message)));
  }

  @override
  Widget build(BuildContext context) {
    final visibleRecipes = _visibleRecipes;
    return Scaffold(
      appBar: AppBar(
        titleSpacing: 20,
        title: const Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              'Recettes Ananas',
              style: TextStyle(fontWeight: FontWeight.w800),
            ),
            Text("Manger, c'est important", style: TextStyle(fontSize: 12)),
          ],
        ),
        actions: [
          IconButton(
            onPressed: _isBusy ? null : () => _openEditor(),
            tooltip: 'Ajouter une recette',
            icon: const Icon(Icons.add_rounded),
          ),
          if (_isBusy)
            const Padding(
              padding: EdgeInsets.symmetric(horizontal: 18),
              child: Center(
                child: SizedBox.square(
                  dimension: 20,
                  child: CircularProgressIndicator(strokeWidth: 2),
                ),
              ),
            )
          else
            PopupMenuButton<_RecipeMenuAction>(
              tooltip: 'Sauvegarde',
              icon: const Icon(Icons.cloud_sync_outlined),
              onSelected: (action) => action == _RecipeMenuAction.export
                  ? _exportRecipes()
                  : _importRecipes(),
              itemBuilder: (context) => const [
                PopupMenuItem(
                  value: _RecipeMenuAction.export,
                  child: ListTile(
                    contentPadding: EdgeInsets.zero,
                    leading: Icon(Icons.upload_rounded),
                    title: Text('Exporter mes recettes'),
                  ),
                ),
                PopupMenuItem(
                  value: _RecipeMenuAction.import,
                  child: ListTile(
                    contentPadding: EdgeInsets.zero,
                    leading: Icon(Icons.download_rounded),
                    title: Text('Restaurer une sauvegarde'),
                  ),
                ),
              ],
            ),
          const SizedBox(width: 8),
        ],
      ),
      body: RefreshIndicator(
        onRefresh: () async =>
            setState(() => _recipes = [...widget.repository.recipes]),
        child: CustomScrollView(
          physics: const AlwaysScrollableScrollPhysics(),
          slivers: [
            SliverToBoxAdapter(
              child: _Header(
                searchController: _searchController,
                categories: _categories,
                selectedCategory: _selectedCategory,
                onCategorySelected: (category) =>
                    setState(() => _selectedCategory = category),
                onCreateCategory: _createCategory,
                onManageCategories: _manageCategories,
              ),
            ),
            if (_recipes.isEmpty)
              SliverFillRemaining(
                hasScrollBody: false,
                child: _EmptyState(onAdd: _openEditor),
              )
            else if (visibleRecipes.isEmpty)
              const SliverFillRemaining(
                hasScrollBody: false,
                child: _NoResultState(),
              )
            else
              SliverPadding(
                padding: const EdgeInsets.fromLTRB(20, 0, 20, 100),
                sliver: SliverList.builder(
                  itemCount: visibleRecipes.length,
                  itemBuilder: (context, index) => Padding(
                    padding: const EdgeInsets.only(bottom: 12),
                    child: _RecipeCard(
                      recipe: visibleRecipes[index],
                      onTap: () => _openEditor(visibleRecipes[index]),
                      onDelete: () => _deleteRecipe(visibleRecipes[index]),
                    ),
                  ),
                ),
              ),
            SliverToBoxAdapter(
              child: Padding(
                padding: const EdgeInsets.fromLTRB(20, 12, 20, 120),
                child: Center(
                  child: Text(
                    'Version déployée : $_appVersion',
                    textAlign: TextAlign.center,
                    style: Theme.of(context).textTheme.labelSmall?.copyWith(
                      color: Colors.grey.shade700,
                    ),
                  ),
                ),
              ),
            ),
          ],
        ),
      ),
      floatingActionButton: FloatingActionButton.extended(
        onPressed: () => _openEditor(),
        icon: const Icon(Icons.add_rounded),
        label: const Text('Nouvelle recette'),
      ),
    );
  }
}

class _Header extends StatelessWidget {
  const _Header({
    required this.searchController,
    required this.categories,
    required this.selectedCategory,
    required this.onCategorySelected,
    required this.onCreateCategory,
    required this.onManageCategories,
  });

  final TextEditingController searchController;
  final List<String> categories;
  final String? selectedCategory;
  final ValueChanged<String?> onCategorySelected;
  final Future<String?> Function() onCreateCategory;
  final VoidCallback onManageCategories;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.fromLTRB(20, 12, 20, 20),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          TextField(
            controller: searchController,
            textInputAction: TextInputAction.search,
            decoration: InputDecoration(
              hintText: 'Rechercher une recette…',
              prefixIcon: const Icon(Icons.search_rounded),
              suffixIcon: searchController.text.isEmpty
                  ? null
                  : IconButton(
                      onPressed: searchController.clear,
                      icon: const Icon(Icons.close_rounded),
                    ),
            ),
          ),
          if (categories.isNotEmpty) ...[
            const SizedBox(height: 14),
            Row(
              children: [
                Text(
                  'Catégories',
                  style: Theme.of(
                    context,
                  ).textTheme.titleSmall?.copyWith(fontWeight: FontWeight.w800),
                ),
                const Spacer(),
                IconButton(
                  onPressed: () async {
                    await onCreateCategory();
                  },
                  tooltip: 'Nouvelle catégorie',
                  icon: const Icon(Icons.add_circle_outline_rounded),
                ),
                IconButton(
                  onPressed: onManageCategories,
                  tooltip: 'Gérer les catégories',
                  icon: const Icon(Icons.settings_outlined),
                ),
              ],
            ),
            SingleChildScrollView(
              scrollDirection: Axis.horizontal,
              child: Row(
                children: [
                  FilterChip(
                    label: const Text('Toutes'),
                    selected: selectedCategory == null,
                    onSelected: (_) => onCategorySelected(null),
                  ),
                  const SizedBox(width: 8),
                  ...categories.map(
                    (category) => Padding(
                      padding: const EdgeInsets.only(right: 8),
                      child: FilterChip(
                        label: Text(category),
                        selected:
                            selectedCategory?.toLowerCase() ==
                            category.toLowerCase(),
                        onSelected: (_) => onCategorySelected(category),
                      ),
                    ),
                  ),
                ],
              ),
            ),
          ] else
            Align(
              alignment: Alignment.centerLeft,
              child: TextButton.icon(
                onPressed: onCreateCategory,
                icon: const Icon(Icons.add_rounded),
                label: const Text('Créer une catégorie'),
              ),
            ),
        ],
      ),
    );
  }
}

class _RecipeCard extends StatelessWidget {
  const _RecipeCard({
    required this.recipe,
    required this.onTap,
    required this.onDelete,
  });

  final Recipe recipe;
  final VoidCallback onTap;
  final VoidCallback onDelete;

  @override
  Widget build(BuildContext context) {
    final colors = Theme.of(context).colorScheme;
    final preview = recipe.description.isNotEmpty
        ? recipe.description
        : recipe.ingredients.isNotEmpty
        ? recipe.ingredients
        : 'Aucun détail ajouté pour le moment.';
    return Card(
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(20),
        child: Padding(
          padding: const EdgeInsets.all(18),
          child: Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              _RecipeThumbnail(
                imageBase64: recipe.imageBase64,
                width: 52,
                height: 52,
              ),
              const SizedBox(width: 14),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      recipe.title,
                      maxLines: 2,
                      overflow: TextOverflow.ellipsis,
                      style: Theme.of(context).textTheme.titleMedium?.copyWith(
                        fontWeight: FontWeight.w800,
                      ),
                    ),
                    const SizedBox(height: 5),
                    Text(
                      preview.replaceAll('\n', ' '),
                      maxLines: 2,
                      overflow: TextOverflow.ellipsis,
                      style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                        color: colors.onSurfaceVariant,
                      ),
                    ),
                    const SizedBox(height: 8),
                    if (recipe.rating > 0)
                      Row(
                        children: [
                          ...List.generate(
                            5,
                            (index) => Icon(
                              index < recipe.rating
                                  ? Icons.star_rounded
                                  : Icons.star_outline_rounded,
                              size: 17,
                              color: const Color(0xFFF59E0B),
                            ),
                          ),
                        ],
                      ),
                  ],
                ),
              ),
              PopupMenuButton<String>(
                tooltip: 'Options',
                onSelected: (_) => onDelete(),
                itemBuilder: (context) => const [
                  PopupMenuItem(value: 'delete', child: Text('Supprimer')),
                ],
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _RecipeThumbnail extends StatelessWidget {
  const _RecipeThumbnail({
    required this.imageBase64,
    required this.width,
    required this.height,
  });

  final String? imageBase64;
  final double width;
  final double height;

  @override
  Widget build(BuildContext context) {
    final colors = Theme.of(context).colorScheme;
    if (imageBase64 == null || imageBase64!.isEmpty) {
      return _placeholder(colors);
    }

    try {
      return ClipRRect(
        borderRadius: BorderRadius.circular(16),
        child: Image.memory(
          base64Decode(imageBase64!),
          width: width,
          height: height,
          fit: BoxFit.cover,
          errorBuilder: (_, _, _) => _placeholder(colors),
        ),
      );
    } on FormatException {
      return _placeholder(colors);
    }
  }

  Widget _placeholder(ColorScheme colors) {
    return Container(
      width: width,
      height: height,
      decoration: BoxDecoration(
        color: colors.primaryContainer,
        borderRadius: BorderRadius.circular(16),
      ),
      child: Icon(Icons.restaurant_rounded, color: colors.onPrimaryContainer),
    );
  }
}

class _EmptyState extends StatelessWidget {
  const _EmptyState({required this.onAdd});

  final VoidCallback onAdd;

  @override
  Widget build(BuildContext context) {
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(32),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            const Icon(
              Icons.menu_book_rounded,
              size: 76,
              color: Color(0xFFB9472E),
            ),
            const SizedBox(height: 20),
            Text(
              'Votre carnet est vide',
              style: Theme.of(
                context,
              ).textTheme.headlineSmall?.copyWith(fontWeight: FontWeight.w800),
            ),
            const SizedBox(height: 8),
            const Text(
              'Ajoutez votre première recette pour commencer votre collection.',
              textAlign: TextAlign.center,
            ),
            const SizedBox(height: 24),
            FilledButton.icon(
              onPressed: onAdd,
              icon: const Icon(Icons.add_rounded),
              label: const Text('Créer une recette'),
            ),
          ],
        ),
      ),
    );
  }
}

class _NoResultState extends StatelessWidget {
  const _NoResultState();

  @override
  Widget build(BuildContext context) {
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(32),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(
              Icons.search_off_rounded,
              size: 64,
              color: Theme.of(context).colorScheme.outline,
            ),
            const SizedBox(height: 16),
            Text(
              'Aucune recette trouvée',
              style: Theme.of(
                context,
              ).textTheme.titleLarge?.copyWith(fontWeight: FontWeight.w700),
            ),
            const SizedBox(height: 6),
            const Text(
              'Essayez avec un autre titre.',
              textAlign: TextAlign.center,
            ),
          ],
        ),
      ),
    );
  }
}
