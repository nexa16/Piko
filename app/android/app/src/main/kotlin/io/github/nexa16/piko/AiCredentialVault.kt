package io.github.nexa16.piko

import android.content.Context
import android.content.pm.ApplicationInfo
import android.security.keystore.KeyGenParameterSpec
import android.security.keystore.KeyProperties
import android.util.Base64
import io.flutter.plugin.common.BinaryMessenger
import io.flutter.plugin.common.MethodChannel
import java.security.KeyStore
import javax.crypto.Cipher
import javax.crypto.KeyGenerator
import javax.crypto.SecretKey
import javax.crypto.spec.GCMParameterSpec

/** Only an encrypted backend session is persisted. Provider keys never enter
 * this channel. Synthetic namespaces are available solely in debuggable APKs. */
class AiCredentialVault(private val context: Context, messenger: BinaryMessenger) {
    private val channel = MethodChannel(messenger, "piko/ai_access_vault")
    private val preferences get() = context.getSharedPreferences("piko_ai_access", Context.MODE_PRIVATE)
    init {
        channel.setMethodCallHandler { call, result ->
            try {
                val name = call.argument<String>("namespace") ?: "session"
                val debug = context.applicationInfo.flags and ApplicationInfo.FLAG_DEBUGGABLE != 0
                require(name == "session" || (debug && Regex("test-[a-z0-9-]{1,64}").matches(name)))
                val alias = "piko.ai.access.$name"
                when (call.method) {
                    "read" -> {
                        val stored = preferences.getString(name, null)
                        if (stored == null) result.success(null) else {
                            require(stored.length <= 131072)
                            val parts = stored.split(':')
                            require(parts.size == 2)
                            val store = KeyStore.getInstance("AndroidKeyStore").apply { load(null) }
                            val key = store.getKey(alias, null) as? SecretKey ?: error("key unavailable")
                            val cipher = Cipher.getInstance("AES/GCM/NoPadding")
                            cipher.init(Cipher.DECRYPT_MODE, key, GCMParameterSpec(128, Base64.decode(parts[0], Base64.NO_WRAP)))
                            cipher.updateAAD(name.toByteArray(Charsets.UTF_8))
                            result.success(String(cipher.doFinal(Base64.decode(parts[1], Base64.NO_WRAP)), Charsets.UTF_8))
                        }
                    }
                    "write" -> {
                        val value = call.argument<String>("value") ?: error("value required")
                        require(value.toByteArray(Charsets.UTF_8).size <= 65536)
                        val store = KeyStore.getInstance("AndroidKeyStore").apply { load(null) }
                        val key = (store.getKey(alias, null) as? SecretKey) ?: KeyGenerator.getInstance(KeyProperties.KEY_ALGORITHM_AES, "AndroidKeyStore").run {
                            init(KeyGenParameterSpec.Builder(alias, KeyProperties.PURPOSE_ENCRYPT or KeyProperties.PURPOSE_DECRYPT)
                                .setBlockModes(KeyProperties.BLOCK_MODE_GCM)
                                .setEncryptionPaddings(KeyProperties.ENCRYPTION_PADDING_NONE)
                                .setKeySize(256).build())
                            generateKey()
                        }
                        val cipher = Cipher.getInstance("AES/GCM/NoPadding")
                        cipher.init(Cipher.ENCRYPT_MODE, key) // Keystore-generated random IV.
                        cipher.updateAAD(name.toByteArray(Charsets.UTF_8))
                        val encrypted = cipher.doFinal(value.toByteArray(Charsets.UTF_8))
                        val payload = Base64.encodeToString(cipher.iv, Base64.NO_WRAP) + ":" + Base64.encodeToString(encrypted, Base64.NO_WRAP)
                        check(preferences.edit().putString(name, payload).commit())
                        result.success(null)
                    }
                    "delete" -> {
                        check(preferences.edit().remove(name).commit())
                        KeyStore.getInstance("AndroidKeyStore").apply { load(null); deleteEntry(alias) }
                        result.success(null)
                    }
                    else -> result.notImplemented()
                }
            } catch (_: Exception) {
                // No raw exception, ciphertext, session or key enters diagnostics.
                result.error("AI_ACCESS_STORAGE_UNAVAILABLE", "Secure AI access storage is unavailable", null)
            }
        }
    }
    fun close() { channel.setMethodCallHandler(null) }
}
