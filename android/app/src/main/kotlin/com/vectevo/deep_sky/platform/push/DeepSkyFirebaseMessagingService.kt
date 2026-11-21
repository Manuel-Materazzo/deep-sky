package com.vectevo.deep_sky.platform.push

import android.app.PendingIntent
import android.content.Intent
import android.util.Log
import androidx.core.app.NotificationCompat
import androidx.core.app.NotificationManagerCompat
import androidx.core.content.ContextCompat
import com.google.firebase.messaging.FirebaseMessagingService
import com.google.firebase.messaging.RemoteMessage
import com.vectevo.deep_sky.MainActivity
import com.vectevo.deep_sky.R
import com.vectevo.deep_sky.platform.PlatformBridgePlugin

/**
 * Handles background data-only FCM wakeup messages and token rotation (SP-01, S-02).
 *
 * Notice that [DeepSkyApplication.onCreate] always runs first to initialize FirebaseApp from
 * runtime preferences when Android cold-starts this service after task dismissal or boot.
 */
class DeepSkyFirebaseMessagingService : FirebaseMessagingService() {

    companion object {
        private const val TAG = "DeepSkyFcmService"
        private const val WAKEUP_NOTIFICATION_ID = 4101
    }

    override fun onNewToken(token: String) {
        super.onNewToken(token)
        Log.i(TAG, "Received rotated FCM token (len=${token.length})")
        RuntimeFirebaseCoordinator(applicationContext).savePendingToken(token)
    }

    override fun onMessageReceived(message: RemoteMessage) {
        super.onMessageReceived(message)
        val coordinator = RuntimeFirebaseCoordinator(applicationContext)
        coordinator.ensureNotificationChannel()

        // Privacy rule S-02: ignore any unexpected display fields and resolve purely from l10nKey.
        val key = message.data["l10nKey"] ?: "wakeup.generic"
        coordinator.recordWakeup(key, System.currentTimeMillis())
        // AU-18: If the Flutter engine is currently attached, wake Dart to trigger silent sync.
        PlatformBridgePlugin.dispatchForegroundWakeup(key)

        val bodyResId = when (key) {
            "wakeup.thinking_of_you" -> R.string.push_body_thinking_of_you
            "wakeup.new_moment" -> R.string.push_body_new_moment
            "wakeup.capsule_ready" -> R.string.push_body_capsule_ready
            "wakeup.daily_prompt" -> R.string.push_body_daily_prompt
            "wakeup.pairing_request" -> R.string.push_body_pairing_request
            else -> R.string.push_body_generic
        }

        if (!coordinator.hasNotificationPermission()) {
            Log.w(TAG, "POST_NOTIFICATIONS not granted; wakeup recorded but notification skipped.")
            return
        }

        val launchIntent = Intent(this, MainActivity::class.java).apply {
            flags = Intent.FLAG_ACTIVITY_NEW_TASK or Intent.FLAG_ACTIVITY_CLEAR_TOP
        }
        val pendingIntent = PendingIntent.getActivity(
            this,
            0,
            launchIntent,
            PendingIntent.FLAG_UPDATE_CURRENT or PendingIntent.FLAG_IMMUTABLE,
        )

        val notification = NotificationCompat.Builder(this, RuntimeFirebaseCoordinator.UPDATES_CHANNEL_ID)
            .setSmallIcon(R.drawable.ic_notification)
            .setColor(ContextCompat.getColor(this, R.color.notification_accent))
            .setContentTitle(getString(R.string.push_title_generic))
            .setContentText(getString(bodyResId))
            .setPriority(NotificationCompat.PRIORITY_HIGH)
            .setAutoCancel(true)
            .setContentIntent(pendingIntent)
            .build()

        try {
            NotificationManagerCompat.from(this).notify(WAKEUP_NOTIFICATION_ID, notification)
        } catch (sec: SecurityException) {
            Log.w(TAG, "Missing notification permission when posting wakeup", sec)
        }
    }
}
