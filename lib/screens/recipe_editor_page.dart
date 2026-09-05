import 'dart:convert';

import 'package:file_picker/file_picker.dart';
import 'package:flutter/material.dart';
import 'package:flutter_quill/flutter_quill.dart';

import '../models/recipe.dart';
import '../services/recipe_ocr_service.dart';
import '../services/rich_text_storage.dart';

enum _OcrDestination { ingredients, preparation }

class _OcrImportData {
  const _OcrImportData({required this.text, required this.destination});

  final String text;
  final _OcrDestination destination;
}

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
  late final QuillController _ingredientsController;
  late final QuillController _descriptionController;
  late int _rating;
  late List<String> _selectedCategories;
  late List<String> _availableCategories;
  String? _imageBase64;
  bool _isPickingImage = false;
  bool _isExtractingText = false;
  bool _editMode = false;

  bool get _isExistingRecipe => widget.recipe != null;
  bool get _isEditable => !_isExistingRecipe || _editMode;

  @override
  void initState() {
    super.initState();
    final recipe = widget.recipe;
    _titleController = TextEditingController(text: recipe?.title);
    _ingredientsController = RichTextStorage.controllerFromText(
      recipe?.ingredients,
    );
    _descriptionController = RichTextStorage.controllerFromText(
      recipe?.description,
    );
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
      final result = await FilePicker.pickFiles(type: FileType.image);
      if (result.isEmpty || !mounted) return;
      final picked = result.single;
      final bytes = await picked.readAsBytes();
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

  Future<void> _importScreenshots() async {
    if (!_isEditable || _isExtractingText) return;
    try {
      final result = await FilePicker.pickFiles(type: FileType.image);
      if (result.isEmpty || !mounted) return;

      setState(() => _isExtractingText = true);
      final extractedText = await RecipeOcrService().extractText(result);
      if (!mounted) return;
      if (extractedText.isEmpty) {
        _showMessage('Aucun texte n’a été détecté dans ces captures.');
        return;
      }

      final importData = await showDialog<_OcrImportData>(
        context: context,
        builder: (context) => _OcrPreviewDialog(text: extractedText),
      );
      if (!mounted || importData == null) return;

      final controller = importData.destination == _OcrDestination.ingredients
          ? _ingredientsController
          : _descriptionController;
      _insertText(controller, importData.text);
      _showMessage('Texte importé dans la recette.');
    } on RecipeOcrException catch (error) {
      if (mounted) _showMessage(error.message);
    } catch (error) {
      if (mounted) _showMessage('Import des captures impossible : $error');
    } finally {
      if (mounted) setState(() => _isExtractingText = false);
    }
  }

  void _insertText(QuillController controller, String value) {
    final text = value.trim();
    if (text.isEmpty) return;
    final existingText = controller.document.toPlainText().trim();
    final insertion = existingText.isEmpty ? text : '\n\n$text';
    final offset = controller.document.length - 1;
    controller.replaceText(
      offset,
      0,
      insertion,
      TextSelection.collapsed(offset: offset),
    );
  }

  void _showMessage(String message) {
    ScaffoldMessenger.of(context)
      ..hideCurrentSnackBar()
      ..showSnackBar(SnackBar(content: Text(message)));
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
            ingredients: RichTextStorage.encode(_ingredientsController),
            description: RichTextStorage.encode(_descriptionController),
            rating: _rating,
            categories: _selectedCategories,
            imageBase64: _imageBase64,
          )
        : existing.copyWith(
            title: _titleController.text,
            ingredients: RichTextStorage.encode(_ingredientsController),
            description: RichTextStorage.encode(_descriptionController),
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
            if (_isEditable)
              OutlinedButton.icon(
                onPressed: _isExtractingText ? null : _importScreenshots,
                icon: _isExtractingText
                    ? const SizedBox.square(
                        dimension: 18,
                        child: CircularProgressIndicator(strokeWidth: 2),
                      )
                    : const Icon(Icons.document_scanner_outlined),
                label: Text(
                  _isExtractingText
                      ? 'Lecture des captures…'
                      : 'Importer depuis des captures Instagram',
                ),
              ),
            if (_isEditable) const SizedBox(height: 18),
            Row(
              children: [
                Expanded(
                  child: _SectionLabel(
                    icon: Icons.shopping_basket_outlined,
                    title: 'Ingrédients',
                    color: colors.primary,
                  ),
                ),
                if (_isEditable)
                  Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      RichTextBoldButton(controller: _ingredientsController),
                      RichTextUnderlineButton(
                        controller: _ingredientsController,
                      ),
                    ],
                  ),
              ],
            ),
            const SizedBox(height: 8),
            if (_isEditable)
              RichTextEditingField(
                controller: _ingredientsController,
                minHeight: 190,
                placeholder: 'Ex. 500 g de pommes de terre',
              )
            else
              RichTextView(
                text: widget.recipe?.ingredients ?? '',
                emptyText: 'Aucun ingrédient renseigné.',
              ),
            const SizedBox(height: 22),
            Row(
              children: [
                Expanded(
                  child: _SectionLabel(
                    icon: Icons.menu_book_rounded,
                    title: 'Description et préparation',
                    color: colors.primary,
                  ),
                ),
                if (_isEditable)
                  Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      RichTextBoldButton(controller: _descriptionController),
                      RichTextUnderlineButton(
                        controller: _descriptionController,
                      ),
                    ],
                  ),
              ],
            ),
            const SizedBox(height: 8),
            if (_isEditable)
              RichTextEditingField(
                controller: _descriptionController,
                minHeight: 250,
                placeholder: 'Décrivez la préparation, vos astuces…',
              )
            else
              RichTextView(
                text: widget.recipe?.description ?? '',
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

class _OcrPreviewDialog extends StatefulWidget {
  const _OcrPreviewDialog({required this.text});

  final String text;

  @override
  State<_OcrPreviewDialog> createState() => _OcrPreviewDialogState();
}

class _OcrPreviewDialogState extends State<_OcrPreviewDialog> {
  late final TextEditingController _textController;
  _OcrDestination _destination = _OcrDestination.ingredients;

  @override
  void initState() {
    super.initState();
    _textController = TextEditingController(text: widget.text);
    _textController.addListener(_textChanged);
  }

  void _textChanged() => setState(() {});

  @override
  void dispose() {
    _textController.removeListener(_textChanged);
    _textController.dispose();
    super.dispose();
  }

  void _insert() {
    final text = _textController.text.trim();
    if (text.isEmpty) return;
    Navigator.of(
      context,
    ).pop(_OcrImportData(text: text, destination: _destination));
  }

  @override
  Widget build(BuildContext context) {
    return AlertDialog(
      icon: const Icon(Icons.document_scanner_outlined),
      title: const Text('Vérifier le texte importé'),
      content: ConstrainedBox(
        constraints: const BoxConstraints(maxWidth: 560),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Text(
              'Relisez et corrigez le résultat de la lecture avant de l’insérer dans la recette.',
            ),
            const SizedBox(height: 16),
            SegmentedButton<_OcrDestination>(
              expandedInsets: EdgeInsets.zero,
              showSelectedIcon: false,
              segments: const [
                ButtonSegment(
                  value: _OcrDestination.ingredients,
                  label: Text('Ingrédients', softWrap: false),
                ),
                ButtonSegment(
                  value: _OcrDestination.preparation,
                  label: Text('Préparation', softWrap: false),
                ),
              ],
              selected: {_destination},
              onSelectionChanged: (selection) =>
                  setState(() => _destination = selection.first),
            ),
            const SizedBox(height: 16),
            TextField(
              controller: _textController,
              minLines: 8,
              maxLines: 14,
              textCapitalization: TextCapitalization.sentences,
              keyboardType: TextInputType.multiline,
              decoration: const InputDecoration(
                labelText: 'Texte extrait',
                alignLabelWithHint: true,
              ),
            ),
          ],
        ),
      ),
      actionsPadding: const EdgeInsets.fromLTRB(24, 0, 24, 20),
      actions: [
        Row(
          mainAxisAlignment: MainAxisAlignment.end,
          children: [
            TextButton(
              onPressed: () => Navigator.pop(context),
              child: const Text('Annuler'),
            ),
            const SizedBox(width: 8),
            FilledButton.icon(
              onPressed: _textController.text.trim().isEmpty ? null : _insert,
              icon: const Icon(Icons.playlist_add_rounded),
              label: const Text('Insérer'),
            ),
          ],
        ),
      ],
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
