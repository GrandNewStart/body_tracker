# Flutter default rules
-keep class io.flutter.app.** { *; }
-keep class io.flutter.plugin.** { *; }
-keep class io.flutter.util.** { *; }
-keep class io.flutter.view.** { *; }
-keep class io.flutter.** { *; }
-keep class io.flutter.plugins.** { *; }
-dontwarn io.flutter.embedding.engine.deferredcomponents.**
-dontwarn com.google.android.play.core.**

# Preserve JNI methods and callbacks
-keepclasseswithmembernames class * {
    native <methods>;
}

# Preserve Enum values for serialization and reflection
-keepclassmembers enum * {
    public static **[] values();
    public static ** valueOf(java.lang.String);
}

# Google Play Services annotations
-keepclassmembers class * {
    @com.google.android.gms.common.annotation.KeepName *;
}
-keepnames class * {
    @com.google.android.gms.common.annotation.KeepName *;
}

# Google ML Kit and MediaPipe JNI fields and classes (CRITICAL: prevents NoSuchFieldError on field 'value')
-keep class com.google.mlkit.** { *; }
-keep class com.google.android.gms.internal.mlkit_vision_mediapipe.** { *; }
-keepclassmembers class com.google.android.gms.internal.mlkit_vision_mediapipe.** {
    <fields>;
    <methods>;
}
-keep class com.google.android.gms.internal.mlkit_vision_** { *; }
-keepclassmembers class com.google.android.gms.internal.mlkit_vision_** {
    <fields>;
    <methods>;
}
-keep class com.google.mlkit.vision.mediapipe.** { *; }
-keepclassmembers class com.google.mlkit.vision.mediapipe.** {
    <fields>;
    <methods>;
}
-keep class com.google.mlkit.vision.pose.** { *; }
-keep class com.google.mlkit.vision.face.** { *; }
-keep class com.google.mlkit.vision.common.** { *; }

# AndroidX WorkManager & Room Database (CRITICAL: prevents WorkDatabase instantiation crash)
-keep class androidx.work.** { *; }
-keep class androidx.work.impl.** { *; }
-keep class androidx.room.** { *; }
-keep class * extends androidx.room.RoomDatabase
-dontwarn androidx.work.impl.WorkDatabase_Impl
-keepclassmembers class * extends androidx.room.RoomDatabase {
    <init>();
}

# Google Mobile Ads (AdMob)
-keep class com.google.android.gms.ads.** { *; }
-keep class com.google.ads.mediation.** { *; }
-dontwarn com.google.android.gms.ads.**

# Flutter Secure Storage
-keep class com.it_nomads.fluttersecurestorage.** { *; }

# Flutter Local Notifications
-keep class com.dexterous.flutterlocalnotifications.** { *; }
