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

# === Dynamically-loaded extension dependencies ===
# Mihon/Aniyomi extensions are Kotlin code loaded at runtime via a
# PathClassLoader. R8 can only see statically-reachable code, so every library
# an extension links against by name must be kept wholesale, or the extension
# dies during class verification with NoClassDefFoundError, e.g.:
#   Failed resolution of: Lkotlin/collections/CollectionsKt;
#   Failed resolution of: Lkotlin/jvm/functions/Function0;
# (kotlin-stdlib, the HTTP/HTML/Rx stacks, and kotlinx.* are all needed.)

# Kotlin standard library — every extension references kotlin.collections.*,
# kotlin.jvm.functions.Function0/1/2, etc. Without this, R8 inlines the app's
# own collection/lambda calls, drops the now-unreachable facade classes, and
# extensions crash on first class load.
-keep class kotlin.** { *; }

# kotlinx: coroutines (extension suspend code), serialization runtime (JSON/
# protobuf parsers used by many sources), and the okio serialization bridge.
-keep class kotlinx.** { *; }

# OkHttp + Okio: extensions issue HTTP requests through HttpSource/NetworkHelper
# and reference okhttp3/okio types directly (interceptors, Request/Response,
# Buffer, etc.).
-keep class okhttp3.** { *; }
-keep class okio.** { *; }

# JSoup — the vast majority of manga extensions parse HTML with it.
-keep class org.jsoup.** { *; }

# RxJava — a number of older extensions build their fetch pipelines with it.
-keep class rx.** { *; }

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

# OkHttp (pulled in transitively by the rhttp package) ships GraalVM
# native-image integration under okhttp3.internal.graal.*, which references
# GraalVM/SubstrateVM classes that are not present on Android. R8 full mode
# treats the missing classes as a hard error; suppress them.
# (See build/app/outputs/mapping/release/missing_rules.txt.)
-dontwarn com.oracle.svm.core.annotate.**
-dontwarn org.graalvm.nativeimage.**
-dontwarn java.lang.Module
