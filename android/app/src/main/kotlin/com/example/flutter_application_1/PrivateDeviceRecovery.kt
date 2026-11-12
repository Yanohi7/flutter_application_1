package com.example.flutter_application_1

import android.app.Activity
import android.app.KeyguardManager
import android.os.Build
import android.security.keystore.KeyGenParameterSpec
import android.security.keystore.KeyProperties
import androidx.activity.result.contract.ActivityResultContracts
import androidx.biometric.BiometricManager
import androidx.biometric.BiometricPrompt
import androidx.core.content.ContextCompat
import androidx.fragment.app.FragmentActivity
import io.flutter.plugin.common.MethodCall
import io.flutter.plugin.common.MethodChannel
import java.security.KeyFactory
import java.security.KeyPairGenerator
import java.security.KeyStore
import java.security.spec.MGF1ParameterSpec
import java.security.spec.X509EncodedKeySpec
import javax.crypto.Cipher
import javax.crypto.spec.OAEPParameterSpec
import javax.crypto.spec.PSource

internal class PrivateDeviceRecovery(private val activity: FragmentActivity) {
    private var pending: MethodChannel.Result? = null
    private var legacyDecrypt: (() -> ByteArray)? = null
    private val credentialLauncher = activity.registerForActivityResult(
        ActivityResultContracts.StartActivityForResult(),
    ) { result ->
        val decrypt = legacyDecrypt
        legacyDecrypt = null
        finish(if (result.resultCode == Activity.RESULT_OK) decrypt else null)
    }

    @Suppress("DEPRECATION")
    fun handle(call: MethodCall, result: MethodChannel.Result) {
        val alias = call.argument<String>("alias")
        val data = call.argument<ByteArray>("data")
        val wrapping = call.method == "wrapDeviceRecoveryKey"
        if (alias == null || !alias.matches(aliasPattern) ||
            data?.size != (if (wrapping) 32 else 256)
        ) {
            data?.fill(0)
            result.error("invalid_key", "The device recovery key is invalid.", null)
            return
        }
        if (pending != null) {
            data.fill(0)
            result.error("busy", "Device verification is already running.", null)
            return
        }
        val keyguard = activity.getSystemService(KeyguardManager::class.java)
        if (keyguard?.isDeviceSecure != true) {
            data.fill(0)
            if (wrapping) result.success(null) else result.error(
                "no_screen_lock", "Set up a screen lock in your phone settings.", null,
            )
            return
        }

        try {
            if (wrapping) {
                try {
                    result.success(wrap(alias, data))
                } finally {
                    data.fill(0)
                }
                return
            }
            pending = result
            if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.R) {
                val cipher = decryptionCipher(alias)
                val prompt = BiometricPrompt(
                    activity,
                    ContextCompat.getMainExecutor(activity),
                    object : BiometricPrompt.AuthenticationCallback() {
                        override fun onAuthenticationSucceeded(auth: BiometricPrompt.AuthenticationResult) {
                            finish { checkNotNull(auth.cryptoObject?.cipher).doFinal(data) }
                        }

                        override fun onAuthenticationError(code: Int, message: CharSequence) {
                            if (code == BiometricPrompt.ERROR_USER_CANCELED ||
                                code == BiometricPrompt.ERROR_CANCELED
                            ) {
                                finish(null)
                            } else {
                                fail("Could not verify your screen lock. Try again.")
                            }
                        }
                    },
                )
                val info = BiometricPrompt.PromptInfo.Builder()
                    .setTitle("Reset private password")
                    .setSubtitle("Confirm your phone's screen lock")
                    .setAllowedAuthenticators(
                        BiometricManager.Authenticators.BIOMETRIC_STRONG or
                            BiometricManager.Authenticators.DEVICE_CREDENTIAL,
                    )
                    .build()
                prompt.authenticate(info, BiometricPrompt.CryptoObject(cipher))
            } else {
                val intent = checkNotNull(keyguard.createConfirmDeviceCredentialIntent(
                    "Reset private password", "Confirm your phone's screen lock",
                ))
                legacyDecrypt = { decryptionCipher(alias).doFinal(data) }
                credentialLauncher.launch(intent)
            }
        } catch (_: Exception) {
            legacyDecrypt = null
            pending = null
            result.error("unavailable", unavailable, null)
        }
    }

    private fun finish(decrypt: (() -> ByteArray)?) {
        val result = pending ?: return
        pending = null
        try {
            val bytes = decrypt?.invoke()
            try {
                result.success(bytes)
            } finally {
                bytes?.fill(0)
            }
        } catch (_: Exception) {
            result.error("unavailable", unavailable, null)
        }
    }

    private fun fail(message: String) {
        val result = pending ?: return
        pending = null
        result.error("unavailable", message, null)
    }

    private fun keyStore(): KeyStore = KeyStore.getInstance("AndroidKeyStore").apply { load(null) }

    @Suppress("DEPRECATION")
    private fun wrap(alias: String, data: ByteArray): ByteArray {
        val spec = KeyGenParameterSpec.Builder(alias, KeyProperties.PURPOSE_DECRYPT)
            .setKeySize(2048)
            .setDigests(KeyProperties.DIGEST_SHA256)
            .setEncryptionPaddings(KeyProperties.ENCRYPTION_PADDING_RSA_OAEP)
            .setUserAuthenticationRequired(true)
        if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.R) {
            spec.setUserAuthenticationParameters(
                0, KeyProperties.AUTH_BIOMETRIC_STRONG or KeyProperties.AUTH_DEVICE_CREDENTIAL,
            )
        } else {
            spec.setUserAuthenticationValidityDurationSeconds(15)
        }
        val pair = KeyPairGenerator.getInstance(KeyProperties.KEY_ALGORITHM_RSA, "AndroidKeyStore")
            .run { initialize(spec.build()); generateKeyPair() }
        // Import only the public half so wrapping never requires a credential prompt.
        val publicKey = KeyFactory.getInstance("RSA")
            .generatePublic(X509EncodedKeySpec(pair.public.encoded))
        return Cipher.getInstance(transformation).run {
            init(Cipher.ENCRYPT_MODE, publicKey, oaep)
            doFinal(data)
        }
    }

    private fun decryptionCipher(alias: String): Cipher = Cipher.getInstance(transformation).apply {
        init(Cipher.DECRYPT_MODE, keyStore().getKey(alias, null), oaep)
    }

    private companion object {
        const val unavailable = "Device recovery is unavailable. Try your recovery file."
        const val transformation = "RSA/ECB/OAEPWithSHA-256AndMGF1Padding"
        val oaep = OAEPParameterSpec("SHA-256", "MGF1", MGF1ParameterSpec.SHA1, PSource.PSpecified.DEFAULT)
        val aliasPattern = Regex("entries_recovery_v1(?:_test_workspace_[a-z0-9_]+)?")
    }
}
