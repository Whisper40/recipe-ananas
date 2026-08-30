# google_mlkit_text_recognition compiles support for optional language scripts
# as compileOnly dependencies. This app uses the bundled Latin recognizer, so
# the optional language classes are intentionally not packaged.
-dontwarn com.google.mlkit.vision.text.chinese.**
-dontwarn com.google.mlkit.vision.text.devanagari.**
-dontwarn com.google.mlkit.vision.text.japanese.**
-dontwarn com.google.mlkit.vision.text.korean.**
