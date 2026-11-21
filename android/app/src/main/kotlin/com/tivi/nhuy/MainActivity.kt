package com.tivi.nhuy

import android.content.Intent
import android.net.Uri
import android.os.Build
import android.os.Bundle
import android.provider.Settings
import android.util.Log
import android.view.WindowManager
import androidx.core.content.FileProvider
import io.flutter.embedding.android.FlutterActivity
import io.flutter.embedding.engine.FlutterEngine
import io.flutter.plugin.common.MethodChannel
import java.io.File

class MainActivity : FlutterActivity() {

    private val CHANNEL = "com.tivi.nhuy/installer"
    private val TAG = "TIVI_APK_INSTALLER"

    private var pendingApkPath: String? = null
    private var waitingForInstallPermission = false

    override fun onCreate(savedInstanceState: Bundle?) {
        super.onCreate(savedInstanceState)

        window.addFlags(
            WindowManager.LayoutParams.FLAG_KEEP_SCREEN_ON
        )
    }

    override fun configureFlutterEngine(
        flutterEngine: FlutterEngine
    ) {
        super.configureFlutterEngine(flutterEngine)

        MethodChannel(
            flutterEngine.dartExecutor.binaryMessenger,
            CHANNEL
        ).setMethodCallHandler { call, result ->

            when (call.method) {
                "installApk" -> {
                    val filePath =
                        call.argument<String>("filePath")

                    if (filePath != null) {
                        pendingApkPath = filePath
                        installApk(filePath)
                        result.success(true)
                    } else {
                        result.error(
                            "INVALID_PATH",
                            "Đường dẫn file APK trống",
                            null
                        )
                    }
                }

                else -> result.notImplemented()
            }
        }
    }

    private fun canInstallUnknownApps(): Boolean {
        return if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.O) {
            packageManager.canRequestPackageInstalls()
        } else {
            true
        }
    }

    private fun installApk(filePath: String) {
        val file = File(filePath)

        if (!file.exists()) {
            Log.e(TAG, "Không tìm thấy APK: $filePath")
            pendingApkPath = null
            waitingForInstallPermission = false
            return
        }

        if (!canInstallUnknownApps()) {
            pendingApkPath = filePath
            waitingForInstallPermission = true
            openInstallPermissionSettings()
            return
        }

        waitingForInstallPermission = false
        pendingApkPath = null
        launchApkInstaller(file)
    }

    private fun openInstallPermissionSettings() {
        if (Build.VERSION.SDK_INT < Build.VERSION_CODES.O) return

        try {
            val intent = Intent(
                Settings.ACTION_MANAGE_UNKNOWN_APP_SOURCES
            ).apply {
                data = Uri.parse("package:$packageName")
                addFlags(Intent.FLAG_ACTIVITY_NEW_TASK)
            }

            startActivity(intent)
        } catch (e: Exception) {
            Log.e(TAG, "Không thể mở trang quyền cài APK", e)

            try {
                val intent = Intent(
                    Settings.ACTION_SECURITY_SETTINGS
                ).apply {
                    addFlags(Intent.FLAG_ACTIVITY_NEW_TASK)
                }
                startActivity(intent)
            } catch (e2: Exception) {
                Log.e(TAG, "Không thể mở Security Settings", e2)
            }
        }
    }

    override fun onResume() {
        super.onResume()

        if (!waitingForInstallPermission) {
            return
        }

        // Người dùng quay lại từ Settings nhưng chưa bật quyền.
        if (!canInstallUnknownApps()) {
            return
        }

        waitingForInstallPermission = false

        val apkPath = pendingApkPath

        if (apkPath.isNullOrEmpty()) {
            Log.e(TAG, "Không có APK đang chờ cài.")
            return
        }

        val file = File(apkPath)

        if (!file.exists()) {
            Log.e(TAG, "APK chờ cài không còn tồn tại: $apkPath")
            pendingApkPath = null
            return
        }

        // Dùng file đã tải, không tải lại.
        pendingApkPath = null
        launchApkInstaller(file)
    }

    private fun launchApkInstaller(file: File) {
        try {
            val intent = Intent(
                Intent.ACTION_VIEW
            ).apply {
                flags =
                    Intent.FLAG_ACTIVITY_NEW_TASK or
                    Intent.FLAG_GRANT_READ_URI_PERMISSION

                if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.N) {
                    val uri = FileProvider.getUriForFile(
                        this@MainActivity,
                        "${applicationContext.packageName}.fileprovider",
                        file
                    )

                    setDataAndType(
                        uri,
                        "application/vnd.android.package-archive"
                    )

                    addFlags(
                        Intent.FLAG_GRANT_READ_URI_PERMISSION
                    )
                } else {
                    setDataAndType(
                        Uri.fromFile(file),
                        "application/vnd.android.package-archive"
                    )
                }
            }

            startActivity(intent)
        } catch (e: Exception) {
            Log.e(TAG, "Không thể mở trình cài đặt APK", e)
        }
    }
}
