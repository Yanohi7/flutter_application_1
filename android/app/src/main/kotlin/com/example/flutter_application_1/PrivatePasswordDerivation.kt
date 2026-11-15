package com.example.flutter_application_1

import android.os.Build
import android.os.SystemClock
import android.util.Log
import io.flutter.plugin.common.BinaryMessenger
import io.flutter.plugin.common.MethodChannel
import javax.crypto.SecretKeyFactory
import javax.crypto.spec.PBEKeySpec

internal object PrivatePasswordDerivation {
    // Existing password envelopes use UTF-8, including non-ASCII passwords.
    private val supportsCompatiblePbkdf2 by lazy {
        Build.VERSION.SDK_INT >= Build.VERSION_CODES.O && runCatching {
            val sample = derive("Пароль🔐", "entrynote-kdf-check".toByteArray(), 2)
            try {
                sample.joinToString("") { "%02x".format(it) } ==
                    "16a59d3d561fa0a6127465b6eb43adcfef38902056cccf3859bfe54aaab59188"
            } finally {
                sample.fill(0)
            }
        }.getOrDefault(false)
    }

    fun register(messenger: BinaryMessenger) {
        MethodChannel(
            messenger,
            "entries/private_crypto",
            io.flutter.plugin.common.StandardMethodCodec.INSTANCE,
            messenger.makeBackgroundTaskQueue(),
        ).setMethodCallHandler { call, result ->
            if (call.method != "derivePasswordKey") {
                result.notImplemented()
                return@setMethodCallHandler
            }
            val password = call.argument<String>("password")
            val salt = call.argument<ByteArray>("salt")
            if (password == null || salt == null || salt.size != 12) {
                result.error("invalid_kdf_input", null, null)
                return@setMethodCallHandler
            }
            val started = SystemClock.elapsedRealtime()
            val derived = if (supportsCompatiblePbkdf2) {
                runCatching { derive(password, salt, 600_000) }.getOrNull()
            } else null
            try {
                if (BuildConfig.DEBUG) {
                    if (derived == null) Log.d("EntryNoteKdf", "Using the portable PBKDF2 implementation.")
                    else Log.d("EntryNoteKdf", "Platform PBKDF2: ${SystemClock.elapsedRealtime() - started} ms.")
                }
                result.success(derived)
            } finally {
                derived?.fill(0)
            }
        }
    }

    private fun derive(password: String, salt: ByteArray, iterations: Int): ByteArray {
        val chars = password.toCharArray()
        val spec = PBEKeySpec(chars, salt, iterations, 256)
        chars.fill('\u0000')
        return try {
            SecretKeyFactory.getInstance("PBKDF2WithHmacSHA256").generateSecret(spec).encoded
        } finally {
            spec.clearPassword()
        }
    }
}
