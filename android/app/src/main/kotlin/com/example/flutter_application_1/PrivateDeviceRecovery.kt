package com.example.flutter_application_1

import android.app.Activity
import android.app.KeyguardManager
import android.os.Build
import android.security.keystore.KeyGenParameterSpec
import android.security.keystore.KeyPermanentlyInvalidatedException
import android.security.keystore.KeyProperties
import android.security.keystore.UserNotAuthenticatedException
import android.util.Log
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
import java.security.UnrecoverableKeyException
import java.security.spec.MGF1ParameterSpec
import java.security.spec.X509EncodedKeySpec
import java.util.concurrent.Executors
import javax.crypto.BadPaddingException
import javax.crypto.Cipher
import javax.crypto.spec.OAEPParameterSpec
import javax.crypto.spec.PSource

internal class PrivateDeviceRecovery(private val activity: FragmentActivity) {
    private class Unlock(
        val alias: String,
        val encrypted: ByteArray,
        val title: String,
        val perOperation: Boolean,
        val result: MethodChannel.Result,
    ) {
        var usedCredentialFallback = false
    }

    private var pending: Unlock? = null
    private val main by lazy { ContextCompat.getMainExecutor(activity) }
    private val keyguard get() = activity.getSystemService(KeyguardManager::class.java)
    private val credentialLauncher = activity.registerForActivityResult(
        ActivityResultContracts.StartActivityForResult(),
    ) { result ->
        val unlock = pending ?: return@registerForActivityResult
        if (result.resultCode == Activity.RESULT_OK) decrypt(unlock) else cancel(unlock)
    }

    fun handle(call: MethodCall, result: MethodChannel.Result) {
        if (call.method == "isScreenLockKeyMissing" ||
            call.method == "deleteDeferredScreenLockKey"
        ) {
            val alias = call.arguments as? String
            if (alias == null || !alias.matches(aliasPattern)) {
                result.error("recovery_key_invalid", null, null)
                return
            }
            worker.execute {
                try {
                    if (call.method == "deleteDeferredScreenLockKey") {
                        keyStore().deleteEntry("${alias}_deferred")
                        result.success(null)
                    } else {
                        val missing = try {
                            if (!keyStore().containsAlias(alias)) true
                            else {
                                decryptionCipher(alias)
                                false
                            }
                        } catch (_: KeyPermanentlyInvalidatedException) {
                            true
                        } catch (_: UnrecoverableKeyException) {
                            true
                        } catch (_: UserNotAuthenticatedException) {
                            false
                        }
                        result.success(missing)
                    }
                } catch (error: Exception) {
                    report(result, "recovery_setup_failed", "key status", error)
                }
            }
            return
        }

        val baseAlias = call.argument<String>("alias")
        val data = call.argument<ByteArray>("data")
        val wrapping = call.method == "wrapDeviceRecoveryKey" ||
            call.method == "wrapDeferredScreenLockKey"
        val deferred = call.method == "wrapDeferredScreenLockKey" ||
            call.method == "unwrapDeferredScreenLockKey"
        if (baseAlias == null || !baseAlias.matches(aliasPattern) ||
            data?.size != (if (wrapping) 32 else 256)
        ) {
            data?.fill(0)
            result.error("recovery_key_invalid", null, null)
            return
        }
        if (pending != null) {
            data.fill(0)
            result.error("recovery_busy", null, null)
            return
        }
        if (!(deferred && wrapping) && keyguard?.isDeviceSecure != true) {
            data.fill(0)
            result.error("no_screen_lock", null, null)
            return
        }

        val alias = if (deferred) "${baseAlias}_deferred" else baseAlias
        val passcodeOnly = call.argument<Boolean>("passcodeOnly") == true
        val timed = passcodeOnly || baseAlias.startsWith("entries_recovery_v3_")
        if (wrapping) {
            worker.execute {
                try {
                    result.success(wrap(alias, data, !deferred, timed, passcodeOnly))
                } catch (error: Exception) {
                    report(result, "recovery_setup_failed", "wrap", error)
                } finally {
                    data.fill(0)
                }
            }
            return
        }

        val unlock = Unlock(
            alias,
            data,
            call.argument<String>("prompt") ?: "Private information",
            Build.VERSION.SDK_INT >= Build.VERSION_CODES.R && !timed && !deferred,
            result,
        )
        pending = unlock
        worker.execute {
            try {
                if (!keyStore().containsAlias(alias)) {
                    main.execute { fail(unlock, "recovery_key_missing", "lookup") }
                } else {
                    val cipher = if (unlock.perOperation) decryptionCipher(alias) else null
                    main.execute {
                        if (pending === unlock) {
                            startAuthentication(unlock, cipher, passcodeOnly || deferred)
                        }
                    }
                }
            } catch (error: Exception) {
                main.execute { fail(unlock, keyError(error), "prepare", error) }
            }
        }
    }

    private fun startAuthentication(unlock: Unlock, cipher: Cipher?, credentialOnly: Boolean) {
        try {
            val canUseBiometrics = Build.VERSION.SDK_INT >= Build.VERSION_CODES.R &&
                BiometricManager.from(activity).canAuthenticate(
                    BiometricManager.Authenticators.BIOMETRIC_STRONG,
                ) == BiometricManager.BIOMETRIC_SUCCESS
            if (cipher == null && (credentialOnly || !canUseBiometrics)) {
                launchCredential(unlock)
                return
            }

            val prompt = BiometricPrompt(
                activity,
                main,
                object : BiometricPrompt.AuthenticationCallback() {
                    override fun onAuthenticationSucceeded(auth: BiometricPrompt.AuthenticationResult) {
                        if (pending !== unlock || unlock.usedCredentialFallback) return
                        val verifiedCipher = auth.cryptoObject?.cipher
                        if (unlock.perOperation && verifiedCipher == null) {
                            fail(unlock, "recovery_key_access_failed", "missing crypto object")
                            return
                        }
                        decrypt(unlock, verifiedCipher)
                    }

                    override fun onAuthenticationError(code: Int, message: CharSequence) {
                        if (pending !== unlock || unlock.usedCredentialFallback) return
                        when {
                            code == BiometricPrompt.ERROR_USER_CANCELED ||
                                code == BiometricPrompt.ERROR_CANCELED ||
                                code == BiometricPrompt.ERROR_NEGATIVE_BUTTON -> cancel(unlock)
                            !unlock.perOperation && code in credentialFallbackErrors -> {
                                Log.w(tag, "Biometric prompt returned code $code; using device credential.")
                                launchCredential(unlock)
                            }
                            else -> fail(unlock, "recovery_prompt_failed", "prompt", promptCode = code)
                        }
                    }
                },
            )
            val authenticators = BiometricManager.Authenticators.DEVICE_CREDENTIAL or
                if (canUseBiometrics) BiometricManager.Authenticators.BIOMETRIC_STRONG else 0
            val info = BiometricPrompt.PromptInfo.Builder()
                .setTitle(unlock.title)
                .setAllowedAuthenticators(authenticators)
                .build()
            if (cipher == null) prompt.authenticate(info)
            else prompt.authenticate(info, BiometricPrompt.CryptoObject(cipher))
        } catch (error: Exception) {
            if (unlock.perOperation) fail(unlock, "recovery_prompt_failed", "start prompt", error)
            else {
                Log.w(tag, "Biometric prompt failed to start: ${error.javaClass.simpleName}")
                launchCredential(unlock)
            }
        }
    }

    @Suppress("DEPRECATION")
    private fun launchCredential(unlock: Unlock) {
        if (pending !== unlock || unlock.usedCredentialFallback) return
        unlock.usedCredentialFallback = true
        try {
            val intent = keyguard?.createConfirmDeviceCredentialIntent(unlock.title, null)
            if (intent == null) fail(unlock, "no_screen_lock", "credential intent")
            else credentialLauncher.launch(intent)
        } catch (error: Exception) {
            fail(unlock, "recovery_prompt_failed", "start credential", error)
        }
    }

    private fun decrypt(unlock: Unlock, cipher: Cipher? = null) {
        worker.execute {
            try {
                val bytes = (cipher ?: decryptionCipher(unlock.alias)).doFinal(unlock.encrypted)
                main.execute {
                    try {
                        if (pending === unlock) {
                            if (BuildConfig.DEBUG) Log.d(tag, "Device recovery unwrapped the key.")
                            pending = null
                            unlock.encrypted.fill(0)
                            unlock.result.success(bytes)
                        }
                    } finally {
                        bytes.fill(0)
                    }
                }
            } catch (error: Exception) {
                main.execute onMain@{
                    if (pending !== unlock) return@onMain
                    if (error is UserNotAuthenticatedException &&
                        !unlock.perOperation && !unlock.usedCredentialFallback
                    ) {
                        Log.w(tag, "Keystore requires a separate device credential confirmation.")
                        launchCredential(unlock)
                    } else {
                        fail(unlock, keyError(error), "unwrap", error)
                    }
                }
            }
        }
    }

    private fun cancel(unlock: Unlock) {
        if (pending !== unlock) return
        pending = null
        unlock.encrypted.fill(0)
        unlock.result.success(null)
    }

    private fun fail(
        unlock: Unlock,
        code: String,
        stage: String,
        error: Exception? = null,
        promptCode: Int? = null,
    ) {
        if (pending !== unlock) return
        pending = null
        unlock.encrypted.fill(0)
        report(unlock.result, code, stage, error, promptCode)
    }

    private fun report(
        result: MethodChannel.Result,
        code: String,
        stage: String,
        error: Exception? = null,
        promptCode: Int? = null,
    ) {
        val detail = error?.javaClass?.simpleName ?: promptCode?.toString() ?: code
        Log.w(tag, "$stage: $detail")
        result.error(code, null, mapOf("stage" to stage, "reason" to detail))
    }

    private fun keyError(error: Exception): String = when (error) {
        is KeyPermanentlyInvalidatedException, is UnrecoverableKeyException -> "recovery_key_missing"
        is BadPaddingException -> "recovery_key_invalid"
        else -> "recovery_key_access_failed"
    }

    private fun keyStore(): KeyStore = KeyStore.getInstance("AndroidKeyStore").apply { load(null) }

    @Suppress("DEPRECATION")
    private fun wrap(alias: String, data: ByteArray, requireExistingLock: Boolean, timed: Boolean, passcodeOnly: Boolean): ByteArray {
        val spec = KeyGenParameterSpec.Builder(alias, KeyProperties.PURPOSE_DECRYPT)
            .setKeySize(2048)
            .setDigests(KeyProperties.DIGEST_SHA256)
            .setEncryptionPaddings(KeyProperties.ENCRYPTION_PADDING_RSA_OAEP)
            .setUserAuthenticationRequired(requireExistingLock)
        if (requireExistingLock && Build.VERSION.SDK_INT >= Build.VERSION_CODES.R) {
            spec.setUserAuthenticationParameters(
                if (timed) 15 else 0,
                if (passcodeOnly) KeyProperties.AUTH_DEVICE_CREDENTIAL
                else KeyProperties.AUTH_BIOMETRIC_STRONG or KeyProperties.AUTH_DEVICE_CREDENTIAL,
            )
        } else if (requireExistingLock) {
            spec.setUserAuthenticationValidityDurationSeconds(15)
        }
        val pair = KeyPairGenerator.getInstance(KeyProperties.KEY_ALGORITHM_RSA, "AndroidKeyStore")
            .run { initialize(spec.build()); generateKeyPair() }
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
        const val tag = "EntryNoteRecovery"
        const val transformation = "RSA/ECB/OAEPWithSHA-256AndMGF1Padding"
        val oaep = OAEPParameterSpec("SHA-256", "MGF1", MGF1ParameterSpec.SHA1, PSource.PSpecified.DEFAULT)
        val aliasPattern = Regex("entries_recovery_v(?:[12]|3_[A-Za-z0-9_-]{43})(?:_test_workspace_[a-z0-9_]+)?(?:_account_[0-9]+)?")
        val worker = Executors.newSingleThreadExecutor()
        val credentialFallbackErrors = setOf(
            BiometricPrompt.ERROR_HW_UNAVAILABLE,
            BiometricPrompt.ERROR_HW_NOT_PRESENT,
            BiometricPrompt.ERROR_LOCKOUT,
            BiometricPrompt.ERROR_LOCKOUT_PERMANENT,
            BiometricPrompt.ERROR_NO_BIOMETRICS,
            BiometricPrompt.ERROR_UNABLE_TO_PROCESS,
            BiometricPrompt.ERROR_TIMEOUT,
            BiometricPrompt.ERROR_NO_DEVICE_CREDENTIAL,
        )
    }
}
