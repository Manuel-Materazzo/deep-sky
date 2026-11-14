package com.vectevo.deep_sky.platform

import android.content.Context
import android.content.pm.PackageManager
import android.os.Build
import com.vectevo.deep_sky.platform.installer.ApkInstallerCoordinator
import com.vectevo.deep_sky.platform.push.RuntimeFirebaseCoordinator
import com.vectevo.deep_sky.platform.widget.HomeWidgetCoordinator
import io.flutter.embedding.engine.FlutterEngine
import io.flutter.plugin.common.MethodCall
import io.flutter.plugin.common.MethodChannel

/**
 * Unified native Android bridge exposed to Flutter over [CHANNEL_NAME] (APP-02).
 * Hosts coordinators for APK installation (SP-03/F-19), runtime FCM (SP-01/TC-13),
 * and home screen widgets (F-13).
 */
class PlatformBridgePlugin(
    private val context: Context,
    private val installerCoordinator: ApkInstallerCoordinator = ApkInstallerCoordinator(context),
    private val widgetCoordinator: HomeWidgetCoordinator = HomeWidgetCoordinator(context),
    private val pushCoordinator: RuntimeFirebaseCoordinator = RuntimeFirebaseCoordinator(context),
) : MethodChannel.MethodCallHandler {

    companion object {
        const val CHANNEL_NAME = "com.vectevo.deep_sky/platform"
    }

    fun register(flutterEngine: FlutterEngine) {
        MethodChannel(flutterEngine.dartExecutor.binaryMessenger, CHANNEL_NAME)
            .setMethodCallHandler(this)
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
            else -> result.notImplemented()
        }
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
