package com.vectevo.deep_sky.platform.push

import android.app.Activity
import android.app.NotificationChannel
import android.app.NotificationManager
import android.content.Context
import android.content.Intent
import android.content.pm.PackageManager
import android.net.Uri
import android.os.Build
import android.os.Handler
import android.os.Looper
import android.provider.Settings
import android.util.Log
import androidx.core.app.NotificationManagerCompat
import androidx.core.content.ContextCompat
import com.google.android.gms.common.ConnectionResult
import com.google.android.gms.common.GoogleApiAvailabilityLight
import com.google.firebase.FirebaseApp
import com.google.firebase.FirebaseOptions
import com.google.firebase.messaging.FirebaseMessaging
import java.util.concurrent.atomic.AtomicBoolean

/**
 * Runtime Firebase configuration and token/wakeup coordinator (SP-01, TC-04, AD-04).
 *
 * Persists public Firebase project parameters in SharedPreferences so [FirebaseApp] can be
 * initialized cleanly in [com.vectevo.deep_sky.DeepSkyApplication.onCreate] even when FCM
 * wakes a terminated process or runs after device reboot without opening MainActivity.
 */
class RuntimeFirebaseCoordinator(private val context: Context) {

    data class RuntimeConfig(
        val projectId: String,
        val apiKey: String,
        val appId: String,
        val senderId: String,
    ) {
        fun isValid(): Boolean =
            projectId.isNotBlank() &&
                apiKey.isNotBlank() &&
                appId.isNotBlank() &&
                senderId.isNotBlank()
    }

    companion object {
        private const val TAG = "RuntimeFirebaseCoord"
        private const val PREFS_NAME = "deep_sky_runtime_firebase"
        private const val KEY_PROJECT_ID = "project_id"
        private const val KEY_API_KEY = "api_key"
        private const val KEY_APP_ID = "app_id"
        private const val KEY_SENDER_ID = "sender_id"
        private const val KEY_PENDING_TOKEN = "pending_fcm_token"
        private const val KEY_LAST_TOKEN = "last_fcm_token"
        private const val KEY_LAST_WAKEUP_KEY = "last_wakeup_key"
        private const val KEY_LAST_WAKEUP_TS = "last_wakeup_ts"
        private const val KEY_RECEIVED_COUNT = "received_count"
        private const val TOKEN_FETCH_TIMEOUT_MS = 15_000L

        const val UPDATES_CHANNEL_ID = "deep_sky_updates"
    }

    private val prefs by lazy {
        context.applicationContext.getSharedPreferences(PREFS_NAME, Context.MODE_PRIVATE)
    }

    fun isReady(): Boolean = true

    /** Ensures notification channels exist and initializes FirebaseApp if config is persisted. */
    fun ensureInitializedFromStorage(): Boolean {
        ensureNotificationChannel()
        val stored = loadStoredConfig() ?: return false
        return applyFirebaseOptions(stored)
    }

    fun ensureNotificationChannel() {
        if (Build.VERSION.SDK_INT < Build.VERSION_CODES.O) {
            return
        }
        val manager = context.getSystemService(NotificationManager::class.java) ?: return
        val name = context.getString(com.vectevo.deep_sky.R.string.notification_channel_updates_name)
        val desc = context.getString(com.vectevo.deep_sky.R.string.notification_channel_updates_desc)
        val channel = NotificationChannel(
            UPDATES_CHANNEL_ID,
            name,
            NotificationManager.IMPORTANCE_HIGH,
        ).apply {
            description = desc
        }
        manager.createNotificationChannel(channel)
    }

    /** Persists runtime config, initializes FirebaseApp, and retrieves the current FCM token. */
    fun configureAndFetchToken(
        config: RuntimeConfig,
        onSuccess: (String) -> Unit,
        onError: (String, String) -> Unit,
    ) {
        if (!config.isValid()) {
            onError("invalid_config", "All Firebase runtime parameters (projectId, apiKey, appId, senderId) are required.")
            return
        }

        val gmsStatus = checkGooglePlayServicesStatus()
        if (gmsStatus == ConnectionResult.SERVICE_MISSING ||
            gmsStatus == ConnectionResult.SERVICE_DISABLED ||
            gmsStatus == ConnectionResult.SERVICE_INVALID
        ) {
            onError(
                "gms_unavailable",
                "Google Play Services is unavailable on this device (status=$gmsStatus).",
            )
            return
        }

        ensureNotificationChannel()
        saveConfig(config)
        val initialized = applyFirebaseOptions(config)
        if (!initialized) {
            onError("firebase_init_failed", "Unable to initialize FirebaseApp with provided runtime options.")
            return
        }

        val mainHandler = Handler(Looper.getMainLooper())
        val settled = AtomicBoolean(false)
        val timeoutRunnable = Runnable {
            if (settled.compareAndSet(false, true)) {
                onError(
                    "fcm_token_timeout",
                    "Timed out waiting for Firebase registration token.",
                )
            }
        }
        mainHandler.postDelayed(timeoutRunnable, TOKEN_FETCH_TIMEOUT_MS)

        fun finishSuccess(token: String) {
            if (settled.compareAndSet(false, true)) {
                mainHandler.removeCallbacks(timeoutRunnable)
                mainHandler.post { onSuccess(token) }
            }
        }

        fun finishError(code: String, message: String) {
            if (settled.compareAndSet(false, true)) {
                mainHandler.removeCallbacks(timeoutRunnable)
                mainHandler.post { onError(code, message) }
            }
        }

        try {
            val messaging = FirebaseMessaging.getInstance()
            messaging.isAutoInitEnabled = true
            messaging.token
                .addOnSuccessListener { token ->
                    if (token.isNullOrBlank()) {
                        finishError("empty_token", "FirebaseMessaging returned an empty registration token.")
                    } else {
                        saveLastKnownToken(token)
                        finishSuccess(token)
                    }
                }
                .addOnFailureListener { error ->
                    finishError("fcm_token_error", error.message ?: "Failed to obtain FCM registration token.")
                }
                .addOnCanceledListener {
                    finishError("fcm_token_cancelled", "Firebase registration token request was cancelled.")
                }
        } catch (ex: Exception) {
            finishError("fcm_token_exception", ex.message ?: "Exception requesting FCM token.")
        }
    }

    private fun checkGooglePlayServicesStatus(): Int {
        return try {
            GoogleApiAvailabilityLight.getInstance().isGooglePlayServicesAvailable(context)
        } catch (ex: Throwable) {
            Log.w(TAG, "Unable to query GoogleApiAvailabilityLight", ex)
            ConnectionResult.SUCCESS
        }
    }

    fun openNotificationSettings(activity: Activity?): Boolean {
        val launchContext = activity ?: context
        val intent = if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.O) {
            Intent(Settings.ACTION_APP_NOTIFICATION_SETTINGS).apply {
                putExtra(Settings.EXTRA_APP_PACKAGE, context.packageName)
            }
        } else {
            Intent(Settings.ACTION_APPLICATION_DETAILS_SETTINGS).apply {
                data = Uri.fromParts("package", context.packageName, null)
            }
        }
        if (activity == null) {
            intent.addFlags(Intent.FLAG_ACTIVITY_NEW_TASK)
        }
        return try {
            launchContext.startActivity(intent)
            true
        } catch (_: Exception) {
            try {
                val fallback = Intent(Settings.ACTION_APPLICATION_DETAILS_SETTINGS).apply {
                    data = Uri.fromParts("package", context.packageName, null)
                    if (activity == null) {
                        addFlags(Intent.FLAG_ACTIVITY_NEW_TASK)
                    }
                }
                launchContext.startActivity(fallback)
                true
            } catch (_: Exception) {
                false
            }
        }
    }

    fun loadStoredConfig(): RuntimeConfig? {
        val projectId = prefs.getString(KEY_PROJECT_ID, "")?.trim().orEmpty()
        val apiKey = prefs.getString(KEY_API_KEY, "")?.trim().orEmpty()
        val appId = prefs.getString(KEY_APP_ID, "")?.trim().orEmpty()
        val senderId = prefs.getString(KEY_SENDER_ID, "")?.trim().orEmpty()
        val config = RuntimeConfig(projectId, apiKey, appId, senderId)
        return if (config.isValid()) config else null
    }

    fun clearStoredConfig() {
        prefs.edit()
            .remove(KEY_PROJECT_ID)
            .remove(KEY_API_KEY)
            .remove(KEY_APP_ID)
            .remove(KEY_SENDER_ID)
            .remove(KEY_PENDING_TOKEN)
            .remove(KEY_LAST_TOKEN)
            .apply()
    }

    fun savePendingToken(token: String) {
        prefs.edit()
            .putString(KEY_PENDING_TOKEN, token)
            .putString(KEY_LAST_TOKEN, token)
            .apply()
    }

    fun consumePendingToken(): String? {
        val pending = prefs.getString(KEY_PENDING_TOKEN, null)
        if (!pending.isNullOrBlank()) {
            prefs.edit().remove(KEY_PENDING_TOKEN).apply()
            return pending
        }
        return null
    }

    fun saveLastKnownToken(token: String) {
        prefs.edit().putString(KEY_LAST_TOKEN, token).apply()
    }

    fun recordWakeup(l10nKey: String, timestampMs: Long) {
        val count = prefs.getInt(KEY_RECEIVED_COUNT, 0) + 1
        prefs.edit()
            .putString(KEY_LAST_WAKEUP_KEY, l10nKey)
            .putLong(KEY_LAST_WAKEUP_TS, timestampMs)
            .putInt(KEY_RECEIVED_COUNT, count)
            .apply()
    }

    fun hasNotificationPermission(): Boolean {
        val osNotificationsEnabled = NotificationManagerCompat.from(context).areNotificationsEnabled()
        if (Build.VERSION.SDK_INT < Build.VERSION_CODES.TIRAMISU) {
            return osNotificationsEnabled
        }
        val runtimeGranted = ContextCompat.checkSelfPermission(
            context,
            android.Manifest.permission.POST_NOTIFICATIONS,
        ) == PackageManager.PERMISSION_GRANTED
        return runtimeGranted && osNotificationsEnabled
    }

    fun statusMap(): Map<String, Any?> {
        val stored = loadStoredConfig()
        val firebaseInitialized = FirebaseApp.getApps(context.applicationContext).isNotEmpty()
        return mapOf(
            "configured" to (stored != null),
            "firebaseInitialized" to firebaseInitialized,
            "projectId" to (stored?.projectId ?: ""),
            "appId" to (stored?.appId ?: ""),
            "lastKnownToken" to (prefs.getString(KEY_LAST_TOKEN, "") ?: ""),
            "pendingToken" to (prefs.getString(KEY_PENDING_TOKEN, "") ?: ""),
            "lastWakeupKey" to (prefs.getString(KEY_LAST_WAKEUP_KEY, "") ?: ""),
            "lastWakeupEpochMs" to prefs.getLong(KEY_LAST_WAKEUP_TS, 0L),
            "receivedCount" to prefs.getInt(KEY_RECEIVED_COUNT, 0),
            "hasNotificationPermission" to hasNotificationPermission(),
        )
    }

    private fun saveConfig(config: RuntimeConfig) {
        prefs.edit()
            .putString(KEY_PROJECT_ID, config.projectId)
            .putString(KEY_API_KEY, config.apiKey)
            .putString(KEY_APP_ID, config.appId)
            .putString(KEY_SENDER_ID, config.senderId)
            .apply()
    }

    private fun applyFirebaseOptions(config: RuntimeConfig): Boolean {
        val appContext = context.applicationContext
        val options = FirebaseOptions.Builder()
            .setProjectId(config.projectId)
            .setApiKey(config.apiKey)
            .setApplicationId(config.appId)
            .setGcmSenderId(config.senderId)
            .build()

        return try {
            val existing = FirebaseApp.getApps(appContext)
                .firstOrNull { it.name == FirebaseApp.DEFAULT_APP_NAME }
            if (existing != null) {
                if (existing.options.applicationId == options.applicationId &&
                    existing.options.apiKey == options.apiKey &&
                    existing.options.projectId == options.projectId &&
                    existing.options.gcmSenderId == options.gcmSenderId
                ) {
                    return true
                }
                existing.delete()
            }
            FirebaseApp.initializeApp(appContext, options)
            true
        } catch (ex: Exception) {
            Log.e(TAG, "Failed runtime Firebase initialization", ex)
            false
        }
    }
}
