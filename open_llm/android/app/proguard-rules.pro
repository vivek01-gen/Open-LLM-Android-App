# Flutter-specific ProGuard rules
-keep class io.flutter.app.** { *; }
-keep class io.flutter.plugin.** { *; }
-keep class io.flutter.util.** { *; }
-keep class io.flutter.view.** { *; }
-keep class io.flutter.** { *; }
-keep class io.flutter.plugins.** { *; }

# Keep annotations
-keepattributes *Annotation*

# Keep the app's Kotlin bridge (MethodChannel handlers + MainActivity members).
# R8 cannot see usage registered via setMethodCallHandler, so keep the class
# and its members to avoid stripping platform-channel code in release builds.
-keep class com.openllm.app.MainActivity { *; }

# Keep sqflite / androidx sqlite classes used across the platform channel.
-keep class com.tekartik.sqflite.** { *; }
-keep class androidx.sqlite.db.** { *; }

# Keep MethodChannel plumbing referenced by name.
-keep class io.flutter.plugin.common.MethodChannel { *; }
