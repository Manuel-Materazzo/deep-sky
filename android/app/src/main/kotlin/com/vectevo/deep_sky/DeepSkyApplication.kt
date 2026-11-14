package com.vectevo.deep_sky

import android.app.Application
import com.vectevo.deep_sky.platform.push.RuntimeFirebaseCoordinator

/**
 * Custom Android Application ensuring runtime FirebaseOptions and notification channels are
 * initialized in [onCreate] before FCM background services execute (SP-01, TC-04).
 */
class DeepSkyApplication : Application() {

    override fun onCreate() {
        super.onCreate()
        RuntimeFirebaseCoordinator(this).ensureInitializedFromStorage()
    }
}
