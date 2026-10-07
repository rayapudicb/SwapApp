package com.swappy.swappy_mobile

import android.os.Bundle
import android.view.WindowManager
import io.flutter.embedding.android.FlutterActivity

class MainActivity : FlutterActivity() {
    override fun onCreate(savedInstanceState: Bundle?) {
        super.onCreate(savedInstanceState)
        // Participant identity and exchange evidence must never enter Android
        // screenshots, screen recordings, or recent-app thumbnails.
        window.addFlags(WindowManager.LayoutParams.FLAG_SECURE)
    }
}
