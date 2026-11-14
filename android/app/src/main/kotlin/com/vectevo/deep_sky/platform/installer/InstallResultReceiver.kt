package com.vectevo.deep_sky.platform.installer

import android.content.BroadcastReceiver
import android.content.Context
import android.content.Intent
import android.content.pm.PackageInstaller
import android.os.Build
import android.util.Log

/**
 * Handles Android [PackageInstaller] session commit callbacks and launches the system
 * user-confirmation UI when [PackageInstaller.STATUS_PENDING_USER_ACTION] is returned (SP-03).
 */
class InstallResultReceiver : BroadcastReceiver() {

    companion object {
        const val ACTION_INSTALL_STATUS = "com.vectevo.deep_sky.INSTALL_STATUS"
        private const val TAG = "InstallResultReceiver"
    }

    @Suppress("DEPRECATION")
    override fun onReceive(context: Context, intent: Intent) {
        if (intent.action != ACTION_INSTALL_STATUS) {
            return
        }
        val status = intent.getIntExtra(PackageInstaller.EXTRA_STATUS, PackageInstaller.STATUS_FAILURE)
        when (status) {
            PackageInstaller.STATUS_PENDING_USER_ACTION -> {
                val confirmIntent = if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.TIRAMISU) {
                    intent.getParcelableExtra(Intent.EXTRA_INTENT, Intent::class.java)
                } else {
                    intent.getParcelableExtra(Intent.EXTRA_INTENT)
                }
                if (confirmIntent != null) {
                    confirmIntent.addFlags(Intent.FLAG_ACTIVITY_NEW_TASK)
                    context.startActivity(confirmIntent)
                }
            }
            PackageInstaller.STATUS_SUCCESS -> {
                Log.i(TAG, "APK update session completed successfully.")
            }
            else -> {
                val msg = intent.getStringExtra(PackageInstaller.EXTRA_STATUS_MESSAGE)
                Log.w(TAG, "APK install failed with status=$status message=$msg")
            }
        }
    }
}
