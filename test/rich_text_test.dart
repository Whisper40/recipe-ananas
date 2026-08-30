import 'package:flutter/material.dart';
import 'package:flutter_quill/flutter_quill.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:recette_box/services/rich_text_storage.dart';

void main() {
  test('conserve le texte existant sans formatage', () {
    final controller = RichTextStorage.controllerFromText(
      '500 g de pommes\n2 œufs',
    );

    expect(
      RichTextStorage.plainText(RichTextStorage.encode(controller)),
      '500 g de pommes\n2 œufs',
    );
    controller.dispose();
  });

  test('conserve le gras dans le Delta sauvegardé', () {
    final controller = RichTextStorage.controllerFromText(
      '500 g de pommes\n2 œufs',
    );
    controller.updateSelection(
      const TextSelection(baseOffset: 9, extentOffset: 15),
      ChangeSource.local,
    );
    controller.formatSelection(Attribute.bold);

    final restored = RichTextStorage.controllerFromText(
      RichTextStorage.encode(controller),
    );
    restored.updateSelection(
      const TextSelection(baseOffset: 9, extentOffset: 15),
      ChangeSource.local,
    );

    expect(
      restored.getSelectionStyle().attributes[Attribute.bold.key],
      isNotNull,
    );
    expect(
      RichTextStorage.plainText(RichTextStorage.encode(restored)),
      '500 g de pommes\n2 œufs',
    );
    controller.dispose();
    restored.dispose();
  });
}
