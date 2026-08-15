import 'dart:convert';
import 'dart:io';

import 'package:file_picker/file_picker.dart';
import 'package:flutter/material.dart';

import '../models/recipe.dart';

class RecipeEditorPage extends StatefulWidget {
  const RecipeEditorPage({
    this.recipe,
    this.categories = const <String>[],
    this.onCreateCategory,
    super.key,
  });

  final Recipe? recipe;
  final List<String> categories;
  final Future<String?> Function()? onCreateCategory;

  @override
  State<RecipeEditorPage> createState() => _RecipeEditorPageState();
}

class _RecipeEditorPageState extends State<RecipeEditorPage> {
  final _formKey = GlobalKey<FormState>();
  late final TextEditingController _titleController;
  late final TextEditingController _ingredientsController;
  late final TextEditingController _descriptionController;
  late int _rating;
  late List<String> _selectedCategories;
  late List<String> _availableCategories;
  String? _imageBase64;
  bool _isPickingImage = false;
  bool _editMode = false;

  bool get _isExistingRecipe => widget.recipe != null;
  bool get _isEditable => !_isExistingRecipe || _editMode;

  @override
  void initState() {
    super.initState();
    final recipe = widget.recipe;
    _titleController = TextEditingController(text: recipe?.title);
    _ingredientsController = TextEditingController(text: recipe?.ingredients);
    _descriptionController = TextEditingController(text: recipe?.description);
    _rating = recipe?.rating ?? 0;
    _selectedCategories = recipe?.categories.toList() ?? <String>[];
    _availableCategories = [
      ...{...widget.categories, ..._selectedCategories},
    ];
    _imageBase64 = recipe?.imageBase64;
  }

  @override
  void dispose() {
    _titleController.dispose();
    _ingredientsController.dispose();
    _descriptionController.dispose();
    super.dispose();
  }

  Future<void> _pickImage() async {
    if (_isPickingImage) return;
    setState(() => _isPickingImage = true);
    try {
      final result = await FilePicker.pickFiles(
        type: FileType.image,
        withData: true,
      );
      if (result == null || !mounted) return;
      final picked = result.files.single;
      final bytes = picked.bytes ?? await File(picked.path!).readAsBytes();
      setState(() => _imageBase64 = base64Encode(bytes));
    } catch (error) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Image impossible à sélectionner : $error')),
        );
      }
    } finally {
      if (mounted) setState(() => _isPickingImage = false);
    }
  }

  void _removeImage() {
    if (!_isEditable) return;
    setState(() => _imageBase64 = null);
  }

  Future<void> _addCategory() async {
    if (!_isEditable || widget.onCreateCategory == null) return;
    final category = await widget.onCreateCategory!();
    if (!mounted || category == null) return;
    if (_selectedCategories.any(
      (item) => item.toLowerCase() == category.toLowerCase(),
    )) {
      return;
    }
    setState(() {
      _availableCategories = [..._availableCategories, category];
      _selectedCategories = [..._selectedCategories, category];
    });
  }

  void _save() {
    FocusManager.instance.primaryFocus?.unfocus();
    if (!_formKey.currentState!.validate()) return;
    final existing = widget.recipe;
    final recipe = existing == null
        ? Recipe.create(
            title: _titleController.text,
            ingredients: _ingredientsController.text,
            description: _descriptionController.text,
            rating: _rating,
            categories: _selectedCategories,
            imageBase64: _imageBase64,
          )
        : existing.copyWith(
            title: _titleController.text,
            ingredients: _ingredientsController.text,
            description: _descriptionController.text,
            rating: _rating,
            categories: _selectedCategories,
            imageBase64: _imageBase64,
            clearImage: _imageBase64 == null && existing.imageBase64 != null,
          );
    Navigator.of(context).pop(recipe);
  }

  @override
  Widget build(BuildContext context) {
    final colors = Theme.of(context).colorScheme;
    return Scaffold(
      appBar: AppBar(
        title: Text(_isExistingRecipe ? 'Recette' : 'Nouvelle recette'),
        actions: [
          if (_isExistingRecipe && !_editMode)
            IconButton(
              onPressed: () => setState(() => _editMode = true),
              tooltip: 'Modifier la recette',
              icon: const Icon(Icons.edit_rounded),
            )
          else
            TextButton.icon(
              onPressed: _save,
              icon: const Icon(Icons.check_rounded),
              label: const Text('Enregistrer'),
            ),
          const SizedBox(width: 8),
        ],
      ),
      body: Form(
        key: _formKey,
        child: ListView(
          padding: const EdgeInsets.fromLTRB(20, 12, 20, 36),
          children: [
            Text(
              'Les bons plats commencent ici',
              style: Theme.of(context).textTheme.headlineSmall?.copyWith(
                fontWeight: FontWeight.w800,
                color: colors.primary,
              ),
            ),
            const SizedBox(height: 6),
            Text(
              'Notez vos idées et retrouvez-les en quelques secondes.',
              style: Theme.of(context).textTheme.bodyMedium,
            ),
            const SizedBox(height: 28),
            _ImagePickerField(
              imageBase64: _imageBase64,
              isBusy: _isPickingImage,
              isEditable: _isEditable,
              onPick: _pickImage,
              onRemove: _removeImage,
            ),
            const SizedBox(height: 24),
            if (_isEditable)
              TextFormField(
                controller: _titleController,
                textCapitalization: TextCapitalization.sentences,
                autofocus: !_isExistingRecipe,
                decoration: const InputDecoration(
                  labelText: 'Titre de la recette *',
                  hintText: 'Ex. Gratin dauphinois',
                  prefixIcon: Icon(Icons.restaurant_menu_rounded),
                ),
                validator: (value) => value == null || value.trim().isEmpty
                    ? 'Le titre est obligatoire.'
                    : null,
              )
            else
              Text(
                _titleController.text,
                style: Theme.of(context).textTheme.headlineSmall?.copyWith(
                  fontWeight: FontWeight.w800,
                ),
              ),
            const SizedBox(height: 22),
            _SectionLabel(
              icon: Icons.star_rounded,
              title: 'Votre évaluation',
              color: colors.primary,
            ),
            const SizedBox(height: 8),
            Row(
              children: [
                for (var index = 1; index <= 5; index++)
                  IconButton(
                    onPressed: _isEditable
                        ? () => setState(() => _rating = index)
                        : null,
                    tooltip: '$index étoile${index > 1 ? 's' : ''}',
                    icon: Icon(
                      index <= _rating
                          ? Icons.star_rounded
                          : Icons.star_outline_rounded,
                      size: 36,
                      color: index <= _rating
                          ? const Color(0xFFF59E0B)
                          : colors.outline,
                    ),
                  ),
                if (_rating > 0)
                  Text(
                    '$_rating/5',
                    style: Theme.of(context).textTheme.titleMedium?.copyWith(
                      fontWeight: FontWeight.w700,
                    ),
                  ),
              ],
            ),
            const SizedBox(height: 18),
            _CategoryField(
              categories: _availableCategories,
              selectedCategories: _selectedCategories,
              isEditable: _isEditable,
              onToggle: (category, selected) {
                setState(() {
                  if (selected) {
                    _selectedCategories = [..._selectedCategories, category];
                  } else {
                    _selectedCategories = _selectedCategories
                        .where((item) => item != category)
                        .toList();
                  }
                });
              },
              onAdd: _addCategory,
            ),
            const SizedBox(height: 18),
            _SectionLabel(
              icon: Icons.shopping_basket_outlined,
              title: 'Ingrédients',
              color: colors.primary,
            ),
            const SizedBox(height: 8),
            if (_isEditable)
              TextFormField(
                controller: _ingredientsController,
                textCapitalization: TextCapitalization.sentences,
                minLines: 7,
                maxLines: null,
                decoration: const InputDecoration(
                  hintText:
                      'Un ingrédient par ligne\nEx. 500 g de pommes de terre',
                  alignLabelWithHint: true,
                ),
              )
            else
              _ReadableText(
                text: _ingredientsController.text,
                emptyText: 'Aucun ingrédient renseigné.',
              ),
            const SizedBox(height: 22),
            _SectionLabel(
              icon: Icons.menu_book_rounded,
              title: 'Description et préparation',
              color: colors.primary,
            ),
            const SizedBox(height: 8),
            if (_isEditable)
              TextFormField(
                controller: _descriptionController,
                textCapitalization: TextCapitalization.sentences,
                minLines: 10,
                maxLines: null,
                decoration: const InputDecoration(
                  hintText: 'Décrivez la préparation, vos astuces…',
                  alignLabelWithHint: true,
                ),
              )
            else
              _ReadableText(
                text: _descriptionController.text,
                emptyText: 'Aucune description renseignée.',
              ),
            const SizedBox(height: 30),
            if (_isEditable)
              FilledButton.icon(
                onPressed: _save,
                icon: const Icon(Icons.check_rounded),
                label: Text(
                  _isExistingRecipe
                      ? 'Enregistrer les modifications'
                      : 'Créer la recette',
                ),
                style: FilledButton.styleFrom(
                  minimumSize: const Size.fromHeight(54),
                  shape: const RoundedRectangleBorder(
                    borderRadius: BorderRadius.all(Radius.circular(18)),
                  ),
                ),
              ),
          ],
        ),
      ),
    );
  }
}

class _ImagePickerField extends StatelessWidget {
  const _ImagePickerField({
    required this.imageBase64,
    required this.isBusy,
    required this.isEditable,
    required this.onPick,
    required this.onRemove,
  });

  final String? imageBase64;
  final bool isBusy;
  final bool isEditable;
  final VoidCallback onPick;
  final VoidCallback onRemove;

  @override
  Widget build(BuildContext context) {
    final hasImage = imageBase64 != null && imageBase64!.isNotEmpty;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        _SectionLabel(
          icon: Icons.photo_outlined,
          title: 'Photo de la recette',
          color: Theme.of(context).colorScheme.primary,
        ),
        const SizedBox(height: 10),
        if (hasImage)
          ClipRRect(
            borderRadius: BorderRadius.circular(18),
            child: Image.memory(
              base64Decode(imageBase64!),
              width: double.infinity,
              height: 190,
              fit: BoxFit.cover,
              errorBuilder: (_, _, _) => const SizedBox.shrink(),
            ),
          ),
        if (hasImage) const SizedBox(height: 8),
        if (isEditable)
          Wrap(
            spacing: 8,
            children: [
              OutlinedButton.icon(
                onPressed: isBusy ? null : onPick,
                icon: isBusy
                    ? const SizedBox.square(
                        dimension: 18,
                        child: CircularProgressIndicator(strokeWidth: 2),
                      )
                    : const Icon(Icons.add_photo_alternate_outlined),
                label: Text(
                  hasImage ? 'Changer la photo' : 'Ajouter une photo',
                ),
              ),
              if (hasImage)
                TextButton.icon(
                  onPressed: onRemove,
                  icon: const Icon(Icons.delete_outline_rounded),
                  label: const Text('Retirer'),
                ),
            ],
          ),
      ],
    );
  }
}

class _CategoryField extends StatelessWidget {
  const _CategoryField({
    required this.categories,
    required this.selectedCategories,
    required this.isEditable,
    required this.onToggle,
    required this.onAdd,
  });

  final List<String> categories;
  final List<String> selectedCategories;
  final bool isEditable;
  final void Function(String category, bool selected) onToggle;
  final VoidCallback onAdd;

  @override
  Widget build(BuildContext context) {
    final colors = Theme.of(context).colorScheme;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        _SectionLabel(
          icon: Icons.label_outline_rounded,
          title: 'Catégories',
          color: colors.primary,
        ),
        const SizedBox(height: 8),
        if (isEditable)
          Wrap(
            spacing: 8,
            runSpacing: 4,
            children: [
              ...categories.map(
                (category) => FilterChip(
                  label: Text(category),
                  selected: selectedCategories.any(
                    (item) => item.toLowerCase() == category.toLowerCase(),
                  ),
                  onSelected: (selected) => onToggle(category, selected),
                ),
              ),
              ActionChip(
                avatar: const Icon(Icons.add_rounded, size: 18),
                label: const Text('Nouvelle catégorie'),
                onPressed: onAdd,
              ),
            ],
          )
        else if (selectedCategories.isEmpty)
          Text(
            'Aucune catégorie.',
            style: Theme.of(
              context,
            ).textTheme.bodyLarge?.copyWith(color: colors.onSurfaceVariant),
          )
        else
          Wrap(
            spacing: 8,
            runSpacing: 4,
            children: selectedCategories
                .map((category) => Chip(label: Text(category)))
                .toList(),
          ),
      ],
    );
  }
}

class _ReadableText extends StatelessWidget {
  const _ReadableText({required this.text, required this.emptyText});

  final String text;
  final String emptyText;

  @override
  Widget build(BuildContext context) {
    final colors = Theme.of(context).colorScheme;
    return SelectableText(
      text.isEmpty ? emptyText : text,
      style: Theme.of(context).textTheme.bodyLarge?.copyWith(
        height: 1.45,
        color: text.isEmpty ? colors.onSurfaceVariant : null,
      ),
    );
  }
}

class _SectionLabel extends StatelessWidget {
  const _SectionLabel({
    required this.icon,
    required this.title,
    required this.color,
  });

  final IconData icon;
  final String title;
  final Color color;

  @override
  Widget build(BuildContext context) {
    return Row(
      children: [
        Icon(icon, size: 20, color: color),
        const SizedBox(width: 8),
        Text(
          title,
          style: Theme.of(
            context,
          ).textTheme.titleMedium?.copyWith(fontWeight: FontWeight.w800),
        ),
      ],
    );
  }
}
