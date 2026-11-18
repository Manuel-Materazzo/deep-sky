package com.vectevo.deep_sky.platform.installer

import android.app.PendingIntent
import android.content.Context
import android.content.Intent
import android.content.pm.PackageInfo
import android.content.pm.PackageInstaller
import android.content.pm.PackageManager
import android.net.Uri
import android.os.Build
import android.os.StatFs
import android.provider.Settings
import java.io.File
import java.io.FileInputStream
import java.security.MessageDigest

/**
 * Coordinates PackageInstaller self-updates, permission checks, staging storage,
 * and pre-install signing certificate verification (SP-03, F-19, TC-10).
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

    fun openInstallUnknownAppsSettings() {
        val intent = Intent(Settings.ACTION_MANAGE_UNKNOWN_APP_SOURCES).apply {
            data = Uri.parse("package:${context.packageName}")
            addFlags(Intent.FLAG_ACTIVITY_NEW_TASK)
        }
        context.startActivity(intent)
    }

    fun getStagingDirectory(): File {
        val dir = File(context.filesDir, "apk_updates")
        if (!dir.exists()) {
            dir.mkdirs()
        }
        return dir
    }

    fun getAvailableStorageBytes(): Long {
        val dir = getStagingDirectory()
        return StatFs(dir.absolutePath).availableBytes
    }

    /**
     * Validates archive metadata and signing certificates against the currently installed app
     * before creating a [PackageInstaller] session, preventing downgrade or signature-mismatch failures.
     */
    @Suppress("DEPRECATION")
    fun installVerifiedApk(apkPath: String): Result<String> {
        val apkFile = File(apkPath)
        if (!apkFile.isFile || apkFile.length() <= 0L) {
            return Result.failure(IllegalArgumentException("apk_missing:APK file does not exist."))
        }
        if (!canRequestPackageInstalls()) {
            return Result.failure(
                SecurityException("permission_denied:Allow installing updates from this app in Android settings."),
            )
        }

        val flags = if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.P) {
            PackageManager.GET_SIGNING_CERTIFICATES
        } else {
            PackageManager.GET_SIGNATURES
        }

        val archiveInfo = context.packageManager.getPackageArchiveInfo(apkFile.absolutePath, flags)
            ?: return Result.failure(IllegalArgumentException("apk_invalid:Downloaded file is not a valid Android APK."))

        if (archiveInfo.packageName != context.packageName) {
            return Result.failure(
                SecurityException("package_mismatch:APK package ${archiveInfo.packageName} does not match ${context.packageName}."),
            )
        }

        val currentInfo = context.packageManager.getPackageInfo(context.packageName, flags)
        val archiveVersion = versionCodeOf(archiveInfo)
        val currentVersion = versionCodeOf(currentInfo)
        if (archiveVersion <= currentVersion) {
            return Result.failure(
                IllegalArgumentException("version_not_higher:APK version $archiveVersion is not newer than installed $currentVersion."),
            )
        }

        val currentSigners = signingDigests(currentInfo)
        val archiveSigners = signingDigests(archiveInfo)
        if (currentSigners.isEmpty() || archiveSigners.isEmpty() || currentSigners.none { it in archiveSigners }) {
            return Result.failure(
                SecurityException("apk_certificate_mismatch:APK signing certificate does not match the installed app."),
            )
        }

        val packageInstaller = context.packageManager.packageInstaller
        val params = PackageInstaller.SessionParams(PackageInstaller.SessionParams.MODE_FULL_INSTALL).apply {
            setAppPackageName(context.packageName)
            setSize(apkFile.length())
        }
        val sessionId = packageInstaller.createSession(params)
        packageInstaller.openSession(sessionId).use { session ->
            session.openWrite("base.apk", 0, apkFile.length()).use { out ->
                FileInputStream(apkFile).use { input ->
                    input.copyTo(out)
                }
                session.fsync(out)
            }
            val callbackIntent = Intent(context, InstallResultReceiver::class.java).apply {
                action = InstallResultReceiver.ACTION_INSTALL_STATUS
            }
            val pendingFlags = PendingIntent.FLAG_UPDATE_CURRENT or
                if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.S) PendingIntent.FLAG_MUTABLE else 0
            val statusReceiver = PendingIntent.getBroadcast(
                context,
                sessionId,
                callbackIntent,
                pendingFlags,
            )
            session.commit(statusReceiver.intentSender)
        }
        return Result.success("session_committed:$sessionId")
    }

    @Suppress("DEPRECATION")
    private fun versionCodeOf(info: PackageInfo): Long {
        return if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.P) {
            info.longVersionCode
        } else {
            info.versionCode.toLong()
        }
    }

    @Suppress("DEPRECATION")
    private fun signingDigests(info: PackageInfo): Set<String> {
        val signatures = if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.P) {
            val signingInfo = info.signingInfo ?: return emptySet()
            if (signingInfo.hasMultipleSigners()) {
                signingInfo.apkContentsSigners
            } else {
                signingInfo.signingCertificateHistory
            }
        } else {
            info.signatures ?: emptyArray()
        }
        val sha256 = MessageDigest.getInstance("SHA-256")
        return signatures.map { sig ->
            sha256.digest(sig.toByteArray()).joinToString("") { "%02x".format(it) }
        }.toSet()
    }
}
