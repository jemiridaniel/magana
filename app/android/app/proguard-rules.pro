# ML Kit text recognition (google_mlkit_text_recognition): the plugin can build
# Chinese, Devanagari, Japanese and Korean recognisers, but Magana bundles only the
# Latin one (offline basic reading, lib/offline/). Those optional classes are absent
# on purpose.
-dontwarn com.google.mlkit.vision.text.chinese.**
-dontwarn com.google.mlkit.vision.text.devanagari.**
-dontwarn com.google.mlkit.vision.text.japanese.**
-dontwarn com.google.mlkit.vision.text.korean.**

# The plugin and ML Kit look classes up at run time; shrinking them broke offline reading in
# a release build (NullPointerException in google_mlkit_text_recognizer, docs/FINDINGS.md).
-keep class com.google_mlkit_text_recognition.** { *; }
-keep class com.google_mlkit_commons.** { *; }
-keep class com.google.mlkit.** { *; }
-keep class com.google.android.gms.internal.mlkit_vision_text_common.** { *; }
-keep class com.google.android.gms.internal.mlkit_vision_common.** { *; }
