package com.vorithstudio.smarttvremote

import android.os.Bundle
import androidx.activity.enableEdgeToEdge
import io.flutter.embedding.android.FlutterFragmentActivity

class MainActivity : FlutterFragmentActivity() {
    override fun onCreate(savedInstanceState: Bundle?) {
        // Backward-compatible edge-to-edge on API < 35; required for Play Console when
        // targeting SDK 35. Flutter handles insets via SafeArea / MediaQuery padding.
        enableEdgeToEdge()
        super.onCreate(savedInstanceState)
    }
}
