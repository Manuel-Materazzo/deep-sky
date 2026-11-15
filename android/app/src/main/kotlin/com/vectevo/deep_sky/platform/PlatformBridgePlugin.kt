package com.vectevo.deep_sky.platform

import android.app.Activity
import android.content.Context
import android.content.Intent
import android.content.pm.PackageManager
import android.os.Build
import androidx.core.app.ActivityCompat
import com.vectevo.deep_sky.platform.installer.ApkInstallerCoordinator
import com.vectevo.deep_sky.platform.push.RuntimeFirebaseCoordinator
import com.vectevo.deep_sky.platform.scanner.QrScannerActivity
import com.vectevo.deep_sky.platform.widget.HomeWidgetCoordinator
import io.flutter.embedding.engine.FlutterEngine
import io.flutter.plugin.common.MethodCall
import io.flutter.plugin.common.MethodChannel

/**
 * Unified native Android bridge exposed to Flutter over [CHANNEL_NAME] (APP-02).
 * Hosts coordinators for APK installation (SP-03/F-19), runtime FCM (SP-01/TC-04),
 * and home screen widgets (F-13).
 */
class PlatformBridgePlugin(
    private val context: Context,
    private val activity: Activity? = null,
    private val installerCoordinator: ApkInstallerCoordinator = ApkInstallerCoordinator(context),
    private val widgetCoordinator: HomeWidgetCoordinator = HomeWidgetCoordinator(context),
    private val pushCoordinator: RuntimeFirebaseCoordinator = RuntimeFirebaseCoordinator(context),
) : MethodChannel.MethodCallHandler {

    companion object {
        const val CHANNEL_NAME = "com.vectevo.deep_sky/platform"
        private const val REQ_POST_NOTIFICATIONS = 4102
        private const val REQ_SCAN_QR = 4104
    }

    private var pendingPermissionResult: MethodChannel.Result? = null
    private var pendingScanResult: MethodChannel.Result? = null

    fun register(flutterEngine: FlutterEngine) {
        MethodChannel(flutterEngine.dartExecutor.binaryMessenger, CHANNEL_NAME)
            .setMethodCallHandler(this)
    }

    fun onRequestPermissionsResult(requestCode: Int, grantResults: IntArray): Boolean {
        if (requestCode != REQ_POST_NOTIFICATIONS) {
            return false
        }
        val granted = grantResults.isNotEmpty() && grantResults[0] == PackageManager.PERMISSION_GRANTED
        pendingPermissionResult?.success(granted)
        pendingPermissionResult = null
        return true
    }

    override fun onMethodCall(call: MethodCall, result: MethodChannel.Result) {
        when (call.method) {
            "ping" -> result.success("pong")
            "getPlatformCapabilities" -> result.success(buildCapabilitiesMap())
            "canRequestPackageInstalls" -> result.success(installerCoordinator.canRequestPackageInstalls())
            "openInstallPermissionSettings" -> {
                installerCoordinator.openInstallUnknownAppsSettings()
                result.success(null)
            }
            "getUpdateStorageInfo" -> result.success(
                mapOf(
                    "stagingDir" to installerCoordinator.getStagingDirectory().absolutePath,
                    "availableBytes" to installerCoordinator.getAvailableStorageBytes(),
                ),
            )
            "installVerifiedApk" -> {
                val path = call.argument<String>("apkPath").orEmpty()
                installerCoordinator.installVerifiedApk(path)
                    .onSuccess { status -> result.success(status) }
                    .onFailure { err ->
                        val msg = err.message ?: "unknown_error:Failed to install APK."
                        val splitIdx = msg.indexOf(':')
                        val code = if (splitIdx > 0) msg.substring(0, splitIdx) else "install_failed"
                        val detail = if (splitIdx > 0) msg.substring(splitIdx + 1) else msg
                        result.error(code, detail, null)
                    }
            }
            "configureRuntimePush" -> handleConfigurePush(call, result)
            "getPushStatus" -> result.success(pushCoordinator.statusMap())
            "consumePendingPushToken" -> result.success(pushCoordinator.consumePendingToken() ?: "")
            "clearRuntimePushConfig" -> {
                pushCoordinator.clearStoredConfig()
                result.success(null)
            }
            "requestNotificationPermission" -> handleRequestNotificationPermission(result)
            "shareText" -> handleShareText(call, result)
            "scanQrCode" -> handleScanQrCode(call, result)
            else -> result.notImplemented()
        }
    }

    private fun handleConfigurePush(call: MethodCall, result: MethodChannel.Result) {
        val projectId = call.argument<String>("projectId")?.trim().orEmpty()
        val apiKey = call.argument<String>("apiKey")?.trim().orEmpty()
        val appId = call.argument<String>("appId")?.trim().orEmpty()
        val senderId = call.argument<String>("senderId")?.trim().orEmpty()

        val config = RuntimeFirebaseCoordinator.RuntimeConfig(
            projectId = projectId,
            apiKey = apiKey,
            appId = appId,
            senderId = senderId,
        )

        pushCoordinator.configureAndFetchToken(
            config = config,
            onSuccess = { token -> result.success(token) },
            onError = { code, message -> result.error(code, message, null) },
        )
    }

    private fun handleRequestNotificationPermission(result: MethodChannel.Result) {
        if (Build.VERSION.SDK_INT < Build.VERSION_CODES.TIRAMISU || pushCoordinator.hasNotificationPermission()) {
            result.success(true)
            return
        }
        val hostActivity = activity
        if (hostActivity == null) {
            result.success(false)
            return
        }
        pendingPermissionResult?.error("cancelled", "Superseded by a new permission request.", null)
        pendingPermissionResult = result
        ActivityCompat.requestPermissions(
            hostActivity,
            arrayOf(android.Manifest.permission.POST_NOTIFICATIONS),
            REQ_POST_NOTIFICATIONS,
        )
    }

    private fun handleShareText(call: MethodCall, result: MethodChannel.Result) {
        val text = call.argument<String>("text")?.trim().orEmpty()
        val subject = call.argument<String>("subject")?.trim()
        if (text.isEmpty()) {
            result.success(false)
            return
        }
        val sendIntent = Intent(Intent.ACTION_SEND).apply {
            type = "text/plain"
            putExtra(Intent.EXTRA_TEXT, text)
            if (!subject.isNullOrEmpty()) {
                putExtra(Intent.EXTRA_SUBJECT, subject)
            }
        }
        val chooser = Intent.createChooser(sendIntent, subject ?: "Deep Sky")
        val launchContext = activity ?: context
        if (activity == null) {
            chooser.addFlags(Intent.FLAG_ACTIVITY_NEW_TASK)
        }
        return try {
            launchContext.startActivity(chooser)
            result.success(true)
        } catch (_: Exception) {
            result.success(false)
        }
    }

    @Suppress("DEPRECATION")
    private fun handleScanQrCode(call: MethodCall, result: MethodChannel.Result) {
        val hostActivity = activity
        if (hostActivity == null) {
            result.error("camera_unavailable", "No host activity available to launch camera scanner.", null)
            return
        }
        pendingScanResult?.success(null)
        pendingScanResult = result

        val scannerIntent = Intent(hostActivity, QrScannerActivity::class.java).apply {
            call.argument<String>("title")?.let { putExtra(QrScannerActivity.EXTRA_TITLE, it) }
            call.argument<String>("hint")?.let { putExtra(QrScannerActivity.EXTRA_HINT, it) }
            call.argument<String>("cancelLabel")?.let { putExtra(QrScannerActivity.EXTRA_CANCEL_LABEL, it) }
        }
        try {
            hostActivity.startActivityForResult(scannerIntent, REQ_SCAN_QR)
        } catch (_: Exception) {
            pendingScanResult = null
            result.error("camera_unavailable", "Unable to start QR scanner activity.", null)
        }
    }

    fun onActivityResult(requestCode: Int, resultCode: Int, data: Intent?): Boolean {
        if (requestCode != REQ_SCAN_QR) {
            return false
        }
        val callback = pendingScanResult ?: return true
        pendingScanResult = null
        if (resultCode == Activity.RESULT_OK) {
            val payload = data?.getStringExtra(QrScannerActivity.EXTRA_RESULT_PAYLOAD)?.trim()
            callback.success(payload?.takeIf { it.isNotEmpty() })
        } else {
            val errCode = data?.getStringExtra(QrScannerActivity.EXTRA_ERROR_CODE)
            if (errCode != null) {
                callback.error(errCode, "QR scanner aborted ($errCode).", null)
            } else {
                callback.success(null)
            }
        }
        return true
    }

    @Suppress("DEPRECATION")
    private fun buildCapabilitiesMap(): Map<String, Any> {
        val packageInfo = if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.TIRAMISU) {
            context.packageManager.getPackageInfo(
                context.packageName,
                PackageManager.PackageInfoFlags.of(0),
            )
        } else {
            context.packageManager.getPackageInfo(context.packageName, 0)
        }

        val versionCode = if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.P) {
            packageInfo.longVersionCode
        } else {
            packageInfo.versionCode.toLong()
        }

        return mapOf(
            "packageName" to context.packageName,
            "androidApiLevel" to Build.VERSION.SDK_INT,
            "versionName" to (packageInfo.versionName ?: ""),
            "versionCode" to versionCode,
            "supportsRequestInstallPackages" to installerCoordinator.supportsInAppInstall(),
            "widgetSubsystemReady" to widgetCoordinator.isReady(),
            "pushSubsystemReady" to pushCoordinator.isReady(),
        )
    }
}
