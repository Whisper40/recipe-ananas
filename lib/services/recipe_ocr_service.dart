import 'package:file_picker/file_picker.dart';
import 'package:google_mlkit_text_recognition/google_mlkit_text_recognition.dart';

class RecipeOcrService {
  static String combineTexts(Iterable<String> texts) => texts
      .map((text) => text.trim())
      .where((text) => text.isNotEmpty)
      .join('\n\n');

  Future<String> extractText(List<PlatformFile> images) async {
    final recognizer = TextRecognizer(script: TextRecognitionScript.latin);
    try {
      final texts = <String>[];
      for (final image in images) {
        final path = image.path;
        if (path == null || path.isEmpty) {
          throw const RecipeOcrException(
            'Le chemin d’une capture est inaccessible sur cet appareil.',
          );
        }
        final recognizedText = await recognizer.processImage(
          InputImage.fromFilePath(path),
        );
        final text = recognizedText.text.trim();
        if (text.isNotEmpty) texts.add(text);
      }
      return combineTexts(texts);
    } finally {
      await recognizer.close();
    }
  }
}

class RecipeOcrException implements Exception {
  const RecipeOcrException(this.message);

  final String message;

  @override
  String toString() => message;
}
