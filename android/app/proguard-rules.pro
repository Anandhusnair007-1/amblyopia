## Flutter wrapper
-keep class io.flutter.app.** { *; }
-keep class io.flutter.plugin.**  { *; }
-keep class io.flutter.util.**  { *; }
-keep class io.flutter.view.**  { *; }
-keep class io.flutter.**  { *; }
-keep class io.flutter.plugins.**  { *; }
-keep class io.flutter.embedding.**  { *; }
-dontwarn io.flutter.embedding.**
-keep class net.sqlcipher.** { *; }
-keep class net.sqlcipher.database.** { *; }
-dontwarn net.sqlcipher.**

## TFLite
-keep class org.tensorflow.** { *; }
-dontwarn org.tensorflow.**

## Vosk
-keep class org.vosk.** { *; }
-dontwarn org.vosk.**

## ML Kit
-keep class com.google.mlkit.** { *; }
-dontwarn com.google.mlkit.**

## SQLCipher (already above, explicit)
-keep class net.sqlcipher.** { *; }
-dontwarn net.sqlcipher.**

## Flutter secure storage
-keep class com.it_nomads.fluttersecurestorage.** { *; }

## Drift / SQLite
-keep class com.tekartik.sqflite.** { *; }

## PDF
-keep class com.tom_roush.pdfbox.** { *; }

## Keep model classes (Dart / serialization)
-keepclassmembers class * {
  @com.google.gson.annotations.SerializedName <fields>;
}

## Dart
-keep class **.Dart { *; }
