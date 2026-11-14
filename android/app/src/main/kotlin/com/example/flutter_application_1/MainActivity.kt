package com.example.flutter_application_1

import android.app.KeyguardManager
import android.content.ClipData
import android.content.ClipboardManager
import android.content.Intent
import android.os.Build
import android.os.PersistableBundle
import android.provider.Settings
import android.view.WindowManager
import io.flutter.embedding.android.FlutterFragmentActivity
import io.flutter.embedding.engine.FlutterEngine
import io.flutter.plugin.common.MethodChannel

class MainActivity : FlutterFragmentActivity() {
    private val deviceRecovery = PrivateDeviceRecovery(this)

    override fun configureFlutterEngine(flutterEngine: FlutterEngine) {
        super.configureFlutterEngine(flutterEngine)
        val biometrics = PrivateBiometrics(this)
        MethodChannel(flutterEngine.dartExecutor.binaryMessenger, "entries/privacy")
            .setMethodCallHandler { call, result ->
                if (call.method == "protectScreen") {
                    if (call.arguments == true) {
                        window.addFlags(WindowManager.LayoutParams.FLAG_SECURE)
                    } else {
                        window.clearFlags(WindowManager.LayoutParams.FLAG_SECURE)
                    }
                    result.success(null)
                } else if (call.method == "copyPrivateValue") {
                    val value = call.arguments as? String
                    val clipboard = getSystemService(ClipboardManager::class.java)
                    if (value.isNullOrEmpty() || clipboard == null) {
                        result.error("clipboard_unavailable", "Could not copy.", null)
                    } else {
                        val clip = ClipData.newPlainText("", value)
                        if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.N) {
                            clip.description.extras = PersistableBundle().apply {
                                putBoolean("android.content.extra.IS_SENSITIVE", true)
                            }
                        }
                        clipboard.setPrimaryClip(clip)
                        result.success(null)
                    }
                } else if (call.method == "hasScreenLock") {
                    result.success(getSystemService(KeyguardManager::class.java)?.isDeviceSecure == true)
                } else if (call.method == "openScreenLockSettings") {
                    try {
                        startActivity(Intent(Settings.ACTION_SECURITY_SETTINGS))
                        result.success(null)
                    } catch (_: Exception) {
                        result.error("unavailable", "Open your phone's security settings.", null)
                    }
                } else if (call.method == "wrapDeviceRecoveryKey" ||
                    call.method == "unwrapDeviceRecoveryKey" ||
                    call.method == "wrapDeferredScreenLockKey" ||
                    call.method == "unwrapDeferredScreenLockKey" ||
                    call.method == "deleteDeferredScreenLockKey" ||
                    call.method == "isScreenLockKeyMissing"
                ) {
                    deviceRecovery.handle(call, result)
                } else {
                    biometrics.handle(call, result)
                }
            }
    }
}
