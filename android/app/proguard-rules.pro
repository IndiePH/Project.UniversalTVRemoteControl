# Unity LevelPlay / ironSource (required when R8 minifies the release AAB).
# From Unity Grow Flutter + Android SDK integration docs.

-keepclassmembers class com.ironsource.sdk.controller.IronSourceWebView$JSInterface {
    public *;
}
-keepclassmembers class * implements android.os.Parcelable {
    public static final android.os.Parcelable$Creator *;
}
-keep public class com.google.android.gms.ads.** { public *; }
-keep class com.google.android.gms.appset.** { *; }
-keep class com.google.android.gms.tasks.** { *; }
-keep class com.ironsource.adapters.** { *; }
-keep class com.ironsource.unity.androidbridge.** { *; }
-keepclassmembers class com.ironsource.** { public *; }
-keep public class com.ironsource.**
-keep class com.unity3d.mediation.** { *; }
-keep class com.unity3d.ironsource.** { *; }
-dontwarn com.ironsource.**
-dontwarn com.ironsource.mediationsdk.**
-dontwarn com.ironsource.adapters.**
-dontwarn com.iab.omid.**
-keep class com.iab.omid.** { *; }
-keepattributes JavascriptInterface
-keepclassmembers class * {
    @android.webkit.JavascriptInterface <methods>;
}
