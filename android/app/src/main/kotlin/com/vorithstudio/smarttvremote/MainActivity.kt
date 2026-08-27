package com.vorithstudio.smarttvremote

import android.os.Bundle
import androidx.activity.enableEdgeToEdge
import androidx.core.splashscreen.SplashScreen.Companion.installSplashScreen
import io.flutter.embedding.android.FlutterFragmentActivity

class MainActivity : FlutterFragmentActivity() {
    override fun onCreate(savedInstanceState: Bundle?) {
        // Android 12+ splash must be installed before window flags change.
        // enableEdgeToEdge() without this dismisses the splash on API 31–33
        // and leaves a black window until Flutter's first frame.
        installSplashScreen()
        enableEdgeToEdge()
        super.onCreate(savedInstanceState)
    }
}
