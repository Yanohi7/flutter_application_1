package com.example.flutter_application_1

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
                } else if (call.method == "wrapDeviceRecoveryKey" ||
                    call.method == "unwrapDeviceRecoveryKey"
                ) {
                    deviceRecovery.handle(call, result)
                } else {
                    biometrics.handle(call, result)
                }
            }
    }
}
