import 'dart:io';

import 'package:file_picker/file_picker.dart';
import 'package:google_mlkit_text_recognition/google_mlkit_text_recognition.dart';
import 'package:path_provider/path_provider.dart';

class RecipeOcrService {
  static String combineTexts(Iterable<String> texts) =>
      texts.map(removeHashtags).where((text) => text.isNotEmpty).join('\n\n');

  static String removeHashtags(String text) {
    final hashtagPattern = RegExp(r'#[\p{L}\p{N}_]+', unicode: true);
    return text
        .split('\n')
        .map(
          (line) => line
              .replaceAll(hashtagPattern, '')
              .replaceAll(RegExp(r'[ \t]{2,}'), ' ')
              .trim(),
        )
        .where((line) => line.isNotEmpty)
        .join('\n')
        .trim();
  }

  Future<String> extractText(List<PlatformFile> images) async {
    final recognizer = TextRecognizer(script: TextRecognitionScript.latin);
    Directory? workingDirectory;
    try {
      final texts = <String>[];
      final temporaryDirectory = await getTemporaryDirectory();
      workingDirectory = Directory(
        '${temporaryDirectory.path}/recipe_ocr_${DateTime.now().microsecondsSinceEpoch}',
      );
      await workingDirectory.create(recursive: true);

      for (var index = 0; index < images.length; index++) {
        final image = images[index];
        final bytes = await image.readAsBytes();
        if (bytes.isEmpty) {
          throw RecipeOcrException(
            'La capture « ${image.name} » est vide ou inaccessible.',
          );
        }

        // Android’s Storage Access Framework can return a content URI or no
        // filesystem path. Copying the selected bytes to the app cache gives
        // ML Kit a regular local path in every case.
        final localFile = File('${workingDirectory.path}/capture_$index');
        await localFile.writeAsBytes(bytes, flush: true);
        final recognizedText = await recognizer.processImage(
          InputImage.fromFilePath(localFile.path),
        );
        final text = recognizedText.text.trim();
        if (text.isNotEmpty) texts.add(text);
      }
      return combineTexts(texts);
    } finally {
      await recognizer.close();
      if (workingDirectory != null && await workingDirectory.exists()) {
        await workingDirectory.delete(recursive: true);
      }
    }
  }
}

class RecipeOcrException implements Exception {
  const RecipeOcrException(this.message);

  final String message;

  @override
  String toString() => message;
}
