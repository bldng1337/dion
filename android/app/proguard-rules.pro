# Flutter / Dart default rules are added automatically by the Flutter Gradle
# plugin (flutter_proguard_rules.pro) together with this file.

# The rdion_runtime native library (librdion_runtime.so) looks up and caches the
# `dion.mihon.AndroidMihonBridge` Kotlin object via JNI during System.loadLibrary.
# R8 cannot see JNI references, so it strips the class in release builds, causing:
#   ClassNotFoundException: dion.mihon.AndroidMihonBridge
# Keep the whole Mihon compat layer (bridge, SourceManager, dtos).
-keep class dion.mihon.** { *; }

# Mihon source-api stubs. These interfaces are implemented by extensions that
# are loaded dynamically at runtime via a PathClassLoader, which references them
# by their original fully-qualified names. They are a binary contract and must
# not be renamed or removed.
-keep class eu.kanade.tachiyomi.** { *; }

# Injekt dependency injection is used reflectively by Mihon extensions.
-keep class uy.kohesive.injekt.** { *; }

# kotlin-logging / slf4j are referenced by extension code by name.
-keep class io.github.oshai.kotlinlogging.** { *; }
-keep class org.slf4j.** { *; }

# Keep kotlinx.serialization serializers used by the dto classes, since the
# bridge serializes results to JSON that native code parses.
-keepattributes *Annotation*, InnerClasses
-dontnote kotlinx.serialization.**
-keepclassmembers class **$$serializer { *; }
-keepclasseswithmembers class * {
    kotlinx.serialization.KSerializer serializer(...);
}

# kotlin-logging (a transitive dependency of rdion_runtime) references the
# optional kotlinx-coroutines-slf4j module, which is not on the classpath.
# R8 full mode treats the missing class as a hard error; suppress it.
# (See build/app/outputs/mapping/release/missing_rules.txt.)
-dontwarn kotlinx.coroutines.slf4j.MDCContext
-dontwarn kotlinx.coroutines.slf4j.**
