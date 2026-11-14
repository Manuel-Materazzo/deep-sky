package com.vectevo.deep_sky

import com.vectevo.deep_sky.platform.PlatformBridgePlugin
import io.flutter.embedding.android.FlutterActivity
import io.flutter.embedding.engine.FlutterEngine

class MainActivity : FlutterActivity() {
    override fun configureFlutterEngine(flutterEngine: FlutterEngine) {
        super.configureFlutterEngine(flutterEngine)
        PlatformBridgePlugin(applicationContext).register(flutterEngine)
    }
}
