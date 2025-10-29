-keep class io.flutter.** { *; }
-keep class io.flutter.plugins.** { *; }

# Gson (si lo usas)
-keep class com.google.gson.** { *; }
-keepattributes Signature

# OkHttp/Okio (habitual)
-dontwarn okhttp3.**
-dontwarn okio.**

# Crashlytics
-keepattributes SourceFile,LineNumberTable


# Mantener clases de Play Core que Flutter referencia
-keep class com.google.android.play.core.** { *; }
-dontwarn com.google.android.play.core.**

# (Opcional) Evitar problemas con el gestor de componentes diferidos de Flutter
-keep class io.flutter.embedding.engine.deferredcomponents.** { *; }
-keep class io.flutter.embedding.android.FlutterPlayStoreSplitApplication { *; }
