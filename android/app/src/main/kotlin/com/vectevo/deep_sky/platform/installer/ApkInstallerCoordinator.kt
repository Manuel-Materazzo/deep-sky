package com.vectevo.deep_sky.platform.installer

import android.content.Context
import android.os.Build

/**
 * Placeholder coordinator for PackageInstaller-based self-updates (SP-03, F-19, TC-10).
 */
class ApkInstallerCoordinator(private val context: Context) {
    fun supportsInAppInstall(): Boolean = Build.VERSION.SDK_INT >= Build.VERSION_CODES.O

    fun canRequestPackageInstalls(): Boolean {
        return if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.O) {
            context.packageManager.canRequestPackageInstalls()
        } else {
            true
        }
    }
}
