package com.example.flutter_application_1

import android.os.Build
import android.security.keystore.KeyGenParameterSpec
import android.security.keystore.KeyPermanentlyInvalidatedException
import android.security.keystore.KeyProperties
import androidx.biometric.BiometricManager
import androidx.biometric.BiometricPrompt
import androidx.core.content.ContextCompat
import androidx.fragment.app.FragmentActivity
import io.flutter.plugin.common.MethodCall
import io.flutter.plugin.common.MethodChannel
import java.security.KeyStore
import javax.crypto.Cipher
import javax.crypto.KeyGenerator
import javax.crypto.SecretKey
import javax.crypto.spec.GCMParameterSpec

internal class PrivateBiometrics(private val activity: FragmentActivity) {
    private var authenticating = false

    fun handle(call: MethodCall, result: MethodChannel.Result) {
        if (call.method !in setOf("wrapBiometricKey", "unwrapBiometricKey", "deleteBiometricKey")) {
            result.notImplemented()
            return
        }
        val alias = call.argument<String>("alias")
        if (alias == null || !alias.matches(aliasPattern)) {
            result.error("invalid_key", "The biometric key is invalid.", null)
            return
        }

        if (call.method == "deleteBiometricKey") {
            try {
                keyStore().deleteEntry(alias)
                result.success(null)
            } catch (_: Exception) {
                result.error("storage_error", "Could not remove biometric access.", null)
            }
            return
        }

        val data = call.argument<ByteArray>("data")
        val wrapping = call.method == "wrapBiometricKey"
        val expectedSize = if (wrapping) keySize else sealedSize
        if (data == null || data.size != expectedSize) {
            data?.fill(0)
            result.error("invalid_key", "The biometric key is invalid.", null)
            return
        }
        if (authenticating) {
            data.fill(0)
            result.error("busy", "Biometric authentication is already running.", null)
            return
        }

        try {
            val status = BiometricManager.from(activity).canAuthenticate(authenticators)
            if (status != BiometricManager.BIOMETRIC_SUCCESS &&
                status != BiometricManager.BIOMETRIC_STATUS_UNKNOWN
            ) {
                data.fill(0)
                val message = when (status) {
                    BiometricManager.BIOMETRIC_ERROR_NONE_ENROLLED ->
                        "Add a fingerprint or supported face unlock in Android settings, then try again."
                    BiometricManager.BIOMETRIC_ERROR_HW_UNAVAILABLE ->
                        "Biometrics are temporarily unavailable. Try again or use your private password."
                    BiometricManager.BIOMETRIC_ERROR_SECURITY_UPDATE_REQUIRED ->
                        "Install the required Android security update to use biometrics."
                    else -> "Android does not report a biometric sensor that can protect private information."
                }
                result.error("unavailable", message, null)
                return
            }

            val cipher = Cipher.getInstance("AES/GCM/NoPadding")
            if (wrapping) {
                cipher.init(Cipher.ENCRYPT_MODE, generateKey(alias))
            } else {
                val key = keyStore().getKey(alias, null) as? SecretKey
                    ?: throw KeyPermanentlyInvalidatedException()
                cipher.init(Cipher.DECRYPT_MODE, key, GCMParameterSpec(128, data, 0, ivSize))
            }

            val prompt = BiometricPrompt(
                activity,
                ContextCompat.getMainExecutor(activity),
                object : BiometricPrompt.AuthenticationCallback() {
                    override fun onAuthenticationSucceeded(auth: BiometricPrompt.AuthenticationResult) {
                        try {
                            val authorized = auth.cryptoObject?.cipher
                                ?: throw IllegalStateException("Missing authenticated cipher")
                            val output = if (wrapping) {
                                authorized.iv + authorized.doFinal(data)
                            } else {
                                authorized.doFinal(data, ivSize, data.size - ivSize)
                            }
                            try {
                                result.success(output)
                            } finally {
                                output.fill(0)
                            }
                        } catch (_: Exception) {
                            result.error("storage_error", "Could not unlock the biometric key.", null)
                        } finally {
                            data.fill(0)
                            authenticating = false
                        }
                    }

                    override fun onAuthenticationError(code: Int, message: CharSequence) {
                        data.fill(0)
                        authenticating = false
                        when (code) {
                            BiometricPrompt.ERROR_NEGATIVE_BUTTON,
                            BiometricPrompt.ERROR_USER_CANCELED,
                            BiometricPrompt.ERROR_CANCELED -> result.success(null)
                            BiometricPrompt.ERROR_LOCKOUT,
                            BiometricPrompt.ERROR_LOCKOUT_PERMANENT -> result.error(
                                "locked_out",
                                "Android has locked biometric attempts. Unlock your phone and try again, or use your private password.",
                                null,
                            )
                            else -> result.error(
                                "unavailable",
                                "Android could not complete biometric authentication. Try again or use your private password.",
                                null,
                            )
                        }
                    }
                },
            )
            val info = BiometricPrompt.PromptInfo.Builder()
                .setTitle("Private information")
                .setAllowedAuthenticators(authenticators)
                .setNegativeButtonText("Cancel")
                .build()
            authenticating = true
            prompt.authenticate(info, BiometricPrompt.CryptoObject(cipher))
        } catch (_: KeyPermanentlyInvalidatedException) {
            data.fill(0)
            authenticating = false
            result.error(
                "invalidated",
                "Biometric access has changed. Unlock with your private password or recovery file, then set up biometrics again.",
                null,
            )
        } catch (_: Exception) {
            data.fill(0)
            authenticating = false
            result.error(
                "storage_error",
                "Could not use Android biometric protection. Check your device settings or use your private password.",
                null,
            )
        }
    }

    private fun keyStore(): KeyStore = KeyStore.getInstance("AndroidKeyStore").apply { load(null) }

    @Suppress("DEPRECATION")
    private fun generateKey(alias: String): SecretKey {
        val spec = KeyGenParameterSpec.Builder(
            alias,
            KeyProperties.PURPOSE_ENCRYPT or KeyProperties.PURPOSE_DECRYPT,
        )
            .setKeySize(256)
            .setBlockModes(KeyProperties.BLOCK_MODE_GCM)
            .setEncryptionPaddings(KeyProperties.ENCRYPTION_PADDING_NONE)
            .setUserAuthenticationRequired(true)
        if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.R) {
            spec.setUserAuthenticationParameters(0, KeyProperties.AUTH_BIOMETRIC_STRONG)
        } else {
            spec.setUserAuthenticationValidityDurationSeconds(-1)
        }
        return KeyGenerator.getInstance(KeyProperties.KEY_ALGORITHM_AES, "AndroidKeyStore").run {
            init(spec.build())
            generateKey()
        }
    }

    private companion object {
        const val authenticators = BiometricManager.Authenticators.BIOMETRIC_STRONG
        const val keySize = 32
        const val ivSize = 12
        const val sealedSize = ivSize + keySize + 16
        val aliasPattern = Regex("entries_android_biometric_[a-f0-9]{24}")
    }
}
