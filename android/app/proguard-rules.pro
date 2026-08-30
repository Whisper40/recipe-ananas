# Keep ML Kit's public and internal classes available after R8. The Flutter
# plugin selects the recognizer implementation through native code and the
# optional script dependencies are included explicitly in build.gradle.kts.
-keep class com.google.mlkit.** { *; }
-keep class com.google.android.gms.internal.mlkit_vision_text.** { *; }
