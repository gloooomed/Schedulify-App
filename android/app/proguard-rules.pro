# Flutter Wrapper
-keep class io.flutter.app.** { *; }
-keep class io.flutter.plugin.**  { *; }
-keep class io.flutter.util.**  { *; }
-keep class io.flutter.view.**  { *; }
-keep class io.flutter.**  { *; }
-keep class io.flutter.plugins.**  { *; }

# Mobile Scanner
-keep class dev.steenbakker.mobile_scanner.** { *; }
-keep class com.google.mlkit.** { *; }
-keep class androidx.camera.** { *; }
-keep class com.google.android.gms.vision.** { *; }

# Prevent stripping of camera/mlkit methods
-keepclassmembers class dev.steenbakker.mobile_scanner.** { *; }
-keepclassmembers class com.google.mlkit.** { *; }
-keepclassmembers class androidx.camera.** { *; }

# Suppress R8 missing class warnings for Flutter deferred components
-dontwarn com.google.android.play.core.**
-dontwarn io.flutter.embedding.engine.deferredcomponents.**
