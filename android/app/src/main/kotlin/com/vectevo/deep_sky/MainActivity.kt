package com.vectevo.deep_sky

import android.content.Intent
import com.vectevo.deep_sky.platform.PlatformBridgePlugin
import io.flutter.embedding.android.FlutterActivity
import io.flutter.embedding.engine.FlutterEngine

class MainActivity : FlutterActivity() {
    private lateinit var platformBridge: PlatformBridgePlugin

    override fun configureFlutterEngine(flutterEngine: FlutterEngine) {
        super.configureFlutterEngine(flutterEngine)
        platformBridge = PlatformBridgePlugin(applicationContext, activity = this)
        platformBridge.register(flutterEngine)
        platformBridge.handleIntent(intent)
    }

    override fun onNewIntent(intent: Intent) {
        super.onNewIntent(intent)
        setIntent(intent)
        if (::platformBridge.isInitialized) {
            platformBridge.handleIntent(intent)
        }
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

    @Suppress("DEPRECATION")
    override fun onActivityResult(requestCode: Int, resultCode: Int, data: Intent?) {
        if (::platformBridge.isInitialized && platformBridge.onActivityResult(requestCode, resultCode, data)) {
            return
        }
        super.onActivityResult(requestCode, resultCode, data)
    }
}
