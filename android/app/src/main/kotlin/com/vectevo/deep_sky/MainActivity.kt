package com.vectevo.deep_sky

import com.vectevo.deep_sky.platform.PlatformBridgePlugin
import io.flutter.embedding.android.FlutterActivity
import io.flutter.embedding.engine.FlutterEngine

class MainActivity : FlutterActivity() {
    private lateinit var platformBridge: PlatformBridgePlugin

    override fun configureFlutterEngine(flutterEngine: FlutterEngine) {
        super.configureFlutterEngine(flutterEngine)
        platformBridge = PlatformBridgePlugin(applicationContext, activity = this)
        platformBridge.register(flutterEngine)
    }

    override fun onRequestPermissionsResult(
        requestCode: Int,
        permissions: Array<out String>,
        grantResults: IntArray,
    ) {
        super.onRequestPermissionsResult(requestCode, permissions, grantResults)
        if (::platformBridge.isInitialized) {
            platformBridge.onRequestPermissionsResult(requestCode, grantResults)
        }
    }
}
