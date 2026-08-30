import 'dart:convert';

import 'package:flutter/material.dart';
import 'package:flutter_quill/flutter_quill.dart';

/// Converts recipe rich text to and from the JSON Delta format used by Quill.
class RichTextStorage {
  const RichTextStorage._();

  static QuillController controllerFromText(String? value) {
    final document = documentFromText(value);
    return QuillController(
      document: document,
      selection: const TextSelection.collapsed(offset: 0),
    );
  }

  static Document documentFromText(String? value) {
    if (value == null || value.isEmpty) return Document();

    try {
      final decoded = jsonDecode(value);
      if (_looksLikeDelta(decoded)) {
        return Document.fromJson(decoded as List);
      }
    } catch (_) {
      // Existing recipes contain plain text, which is not JSON Delta data.
    }

    final document = Document();
    document.insert(0, value);
    return document;
  }

  static String encode(QuillController controller) {
    if (controller.document.toPlainText().trim().isEmpty) return '';
    return jsonEncode(controller.document.toDelta().toJson());
  }

  static String plainText(String? value) {
    return documentFromText(value).toPlainText().trim();
  }

  static bool _looksLikeDelta(dynamic value) {
    return value is List &&
        value.every(
          (operation) => operation is Map && operation.containsKey('insert'),
        );
  }
}

class RichTextEditingField extends StatelessWidget {
  const RichTextEditingField({
    required this.controller,
    required this.placeholder,
    this.minHeight = 150,
    super.key,
  });

  final QuillController controller;
  final String placeholder;
  final double minHeight;

  @override
  Widget build(BuildContext context) {
    controller.readOnly = false;
    final colors = Theme.of(context).colorScheme;
    return Container(
      constraints: BoxConstraints(minHeight: minHeight),
      decoration: BoxDecoration(
        color: Theme.of(context).inputDecorationTheme.fillColor ?? Colors.white,
        borderRadius: BorderRadius.circular(18),
        border: Border.all(color: colors.outlineVariant),
      ),
      child: QuillEditor.basic(
        controller: controller,
        config: QuillEditorConfig(
          padding: const EdgeInsets.all(14),
          placeholder: placeholder,
          scrollable: false,
          textInputAction: TextInputAction.newline,
        ),
      ),
    );
  }
}

class RichTextView extends StatefulWidget {
  const RichTextView({required this.text, required this.emptyText, super.key});

  final String text;
  final String emptyText;

  @override
  State<RichTextView> createState() => _RichTextViewState();
}

class _RichTextViewState extends State<RichTextView> {
  late final QuillController _controller;

  @override
  void initState() {
    super.initState();
    _controller = RichTextStorage.controllerFromText(widget.text);
    _controller.readOnly = true;
  }

  @override
  void didUpdateWidget(covariant RichTextView oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.text != widget.text) {
      _controller.document = RichTextStorage.documentFromText(widget.text);
      _controller.readOnly = true;
    }
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    if (RichTextStorage.plainText(widget.text).isEmpty) {
      return Text(
        widget.emptyText,
        style: Theme.of(context).textTheme.bodyLarge?.copyWith(
          color: Theme.of(context).colorScheme.onSurfaceVariant,
        ),
      );
    }

    return QuillEditor.basic(
      controller: _controller,
      config: const QuillEditorConfig(
        padding: EdgeInsets.zero,
        scrollable: false,
      ),
    );
  }
}

class RichTextBoldButton extends StatelessWidget {
  const RichTextBoldButton({required this.controller, super.key});

  final QuillController controller;

  @override
  Widget build(BuildContext context) {
    return AnimatedBuilder(
      animation: controller,
      builder: (context, _) {
        final isBold = controller.getSelectionStyle().attributes.containsKey(
          Attribute.bold.key,
        );
        return IconButton(
          tooltip: isBold ? 'Désactiver le gras' : 'Mettre en gras',
          onPressed: () {
            controller.formatSelection(
              isBold ? Attribute.clone(Attribute.bold, null) : Attribute.bold,
            );
          },
          icon: Icon(
            Icons.format_bold_rounded,
            color: isBold ? Theme.of(context).colorScheme.primary : null,
          ),
        );
      },
    );
  }
}

class RichTextUnderlineButton extends StatelessWidget {
  const RichTextUnderlineButton({required this.controller, super.key});

  final QuillController controller;

  @override
  Widget build(BuildContext context) {
    return AnimatedBuilder(
      animation: controller,
      builder: (context, _) {
        final isUnderlined = controller
            .getSelectionStyle()
            .attributes
            .containsKey(Attribute.underline.key);
        return IconButton(
          tooltip: isUnderlined
              ? 'Désactiver le soulignement'
              : 'Souligner le texte',
          onPressed: () {
            controller.formatSelection(
              isUnderlined
                  ? Attribute.clone(Attribute.underline, null)
                  : Attribute.underline,
            );
          },
          icon: Icon(
            Icons.format_underline_rounded,
            color: isUnderlined ? Theme.of(context).colorScheme.primary : null,
          ),
        );
      },
    );
  }
}
