# ---------------------------------------------------------------------------
# R8 / ProGuard keep rules for VIPGo (com.vipgo.app)
#
# Only rules the app actually needs are listed. Each block names the plugin that
# requires it so this file can be pruned when a dependency is dropped.
# ---------------------------------------------------------------------------

# --- Flutter engine ---------------------------------------------------------
# The engine and generated plugin registrant are reached reflectively from JNI.
-keep class io.flutter.** { *; }
-keep class io.flutter.plugins.** { *; }
-keep class io.flutter.plugin.editing.** { *; }
-dontwarn io.flutter.embedding.**

# --- firebase_core / firebase_messaging -------------------------------------
# FirebaseMessagingService subclasses and model classes are instantiated by name.
-keep class com.google.firebase.** { *; }
-keep class com.google.android.gms.** { *; }
-dontwarn com.google.firebase.**
-dontwarn com.google.android.gms.**
-keepattributes Signature,InnerClasses,EnclosingMethod
-keepattributes *Annotation*

# --- mobile_scanner (ML Kit barcode scanning) -------------------------------
# ML Kit loads its detector implementations reflectively; it also references
# the optional bundled-model classes that this app does not ship.
-keep class com.google.mlkit.** { *; }
-keep class com.google.android.gms.internal.mlkit_vision_barcode.** { *; }
-dontwarn com.google.mlkit.**
# Present only when the unbundled model dependency is used - safe to ignore.
-dontwarn com.google.android.gms.internal.mlkit_common.**

# --- flutter_local_notifications --------------------------------------------
# Scheduled notifications are restored via Gson-deserialised models, so the
# generic signatures and TypeToken subclasses must survive shrinking.
-keep class com.dexterous.** { *; }
-keep class * extends com.google.gson.reflect.TypeToken
-keep,allowobfuscation,allowshrinking class com.google.gson.reflect.TypeToken
-keep,allowobfuscation,allowshrinking class * extends com.google.gson.reflect.TypeToken
-dontwarn com.dexterous.**

# --- webview_flutter --------------------------------------------------------
# @JavascriptInterface members are called from JS by name.
-keepclassmembers class * {
    @android.webkit.JavascriptInterface <methods>;
}

# --- geolocator / connectivity_plus -----------------------------------------
-keep class com.baseflow.geolocator.** { *; }
-dontwarn com.baseflow.**

# --- flutter_secure_storage -------------------------------------------------
-keep class androidx.security.crypto.** { *; }
-dontwarn androidx.security.crypto.**

# --- core library desugaring ------------------------------------------------
-dontwarn java.lang.invoke.**
-dontwarn javax.annotation.**

# --- Play Core (referenced by Flutter's deferred-components support) ---------
# The app does not use deferred components, so these classes are absent.
-dontwarn com.google.android.play.core.**

# --- Kotlin -----------------------------------------------------------------
-keep class kotlin.Metadata { *; }
-dontwarn kotlin.**

# Keep line numbers so Play Console stack traces stay readable after
# deobfuscation with the uploaded mapping.txt.
-keepattributes SourceFile,LineNumberTable
-renamesourcefileattribute SourceFile
