package com.magana.app

import android.content.Context
import android.graphics.Bitmap
import android.graphics.BitmapFactory
import android.graphics.Matrix
import android.media.ExifInterface
import android.security.keystore.KeyGenParameterSpec
import android.security.keystore.KeyProperties
import io.flutter.plugin.common.BinaryMessenger
import io.flutter.plugin.common.MethodChannel
import java.io.File
import java.security.KeyStore
import javax.crypto.Cipher
import javax.crypto.KeyGenerator
import javax.crypto.SecretKey
import javax.crypto.spec.GCMParameterSpec

/**
 * Offline basic reading (board 5e; lib/offline/): nothing here leaves the phone.
 * - "magana/offline": an upright copy of a photo for on-device text recognition, and crops of
 *   it so each number can be read a second time. Files live in the app's private cache and the
 *   app deletes each one as soon as it is read.
 * - "magana/vault": AES-GCM with a key that never leaves the Android Keystore, for photos
 *   waiting for a full reading when the phone is back online (lib/offline/photo_queue.dart).
 */
object OfflineChannels {
    private const val KEY_ALIAS = "magana_queue"
    private const val MAX_SIDE = 2400

    fun register(context: Context, messenger: BinaryMessenger) {
        MethodChannel(messenger, "magana/offline").setMethodCallHandler { call, result ->
            try {
                when (call.method) {
                    "upright" -> result.success(upright(context, call.argument<ByteArray>("bytes")!!))
                    "crop" -> result.success(
                        crop(
                            context,
                            call.argument<String>("path")!!,
                            call.argument<Int>("left")!!,
                            call.argument<Int>("top")!!,
                            call.argument<Int>("width")!!,
                            call.argument<Int>("height")!!,
                            call.argument<Double>("scale")!!,
                        )
                    )
                    "delete" -> result.success(File(call.argument<String>("path")!!).delete())
                    else -> result.notImplemented()
                }
            } catch (e: Exception) {
                result.error("offline", e.javaClass.simpleName, null)
            }
        }
        MethodChannel(messenger, "magana/vault").setMethodCallHandler { call, result ->
            try {
                when (call.method) {
                    "encrypt" -> result.success(encrypt(call.argument<ByteArray>("bytes")!!))
                    "decrypt" -> result.success(decrypt(call.argument<ByteArray>("bytes")!!))
                    else -> result.notImplemented()
                }
            } catch (e: Exception) {
                result.error("vault", e.javaClass.simpleName, null)
            }
        }
    }

    private fun cacheFile(context: Context, ext: String): File =
        File.createTempFile("offline_", ext, File(context.cacheDir, "offline").apply { mkdirs() })

    /** The photo turned upright (EXIF), at most MAX_SIDE wide or tall, as a private JPEG. */
    private fun upright(context: Context, bytes: ByteArray): Map<String, Any> {
        val raw = cacheFile(context, ".jpg").apply { writeBytes(bytes) }
        try {
            val bounds = BitmapFactory.Options().apply { inJustDecodeBounds = true }
            BitmapFactory.decodeFile(raw.path, bounds)
            var sample = 1
            while (maxOf(bounds.outWidth, bounds.outHeight) / (sample * 2) >= MAX_SIDE) sample *= 2
            val decoded = BitmapFactory.decodeFile(raw.path, BitmapFactory.Options().apply { inSampleSize = sample })
                ?: throw IllegalArgumentException("not an image")
            val degrees = when (ExifInterface(raw.path).getAttributeInt(ExifInterface.TAG_ORIENTATION, 1)) {
                ExifInterface.ORIENTATION_ROTATE_90 -> 90f
                ExifInterface.ORIENTATION_ROTATE_180 -> 180f
                ExifInterface.ORIENTATION_ROTATE_270 -> 270f
                else -> 0f
            }
            val turned = if (degrees == 0f) decoded else
                Bitmap.createBitmap(decoded, 0, 0, decoded.width, decoded.height, Matrix().apply { postRotate(degrees) }, true)
            val out = cacheFile(context, ".jpg")
            out.outputStream().use { turned.compress(Bitmap.CompressFormat.JPEG, 92, it) }
            return mapOf("path" to out.path, "width" to turned.width, "height" to turned.height)
        } finally {
            raw.delete()
        }
    }

    /** A crop of an upright photo, scaled by [scale], on a white border (like the server's). */
    private fun crop(context: Context, path: String, left: Int, top: Int, width: Int, height: Int, scale: Double): String {
        val source = BitmapFactory.decodeFile(path) ?: throw IllegalArgumentException("not an image")
        val x = left.coerceIn(0, source.width - 1)
        val y = top.coerceIn(0, source.height - 1)
        val w = width.coerceAtMost(source.width - x).coerceAtLeast(1)
        val h = height.coerceAtMost(source.height - y).coerceAtLeast(1)
        val cut = Bitmap.createBitmap(source, x, y, w, h)
        val scaled = Bitmap.createScaledBitmap(cut, (w * scale).toInt().coerceAtLeast(1), (h * scale).toInt().coerceAtLeast(1), true)
        val border = 32
        val framed = Bitmap.createBitmap(scaled.width + 2 * border, scaled.height + 2 * border, Bitmap.Config.ARGB_8888)
        android.graphics.Canvas(framed).apply {
            drawColor(android.graphics.Color.WHITE)
            drawBitmap(scaled, border.toFloat(), border.toFloat(), null)
        }
        val out = cacheFile(context, ".png")
        out.outputStream().use { framed.compress(Bitmap.CompressFormat.PNG, 100, it) }
        return out.path
    }

    private fun key(): SecretKey {
        val store = KeyStore.getInstance("AndroidKeyStore").apply { load(null) }
        (store.getEntry(KEY_ALIAS, null) as? KeyStore.SecretKeyEntry)?.let { return it.secretKey }
        val generator = KeyGenerator.getInstance(KeyProperties.KEY_ALGORITHM_AES, "AndroidKeyStore")
        generator.init(
            KeyGenParameterSpec.Builder(KEY_ALIAS, KeyProperties.PURPOSE_ENCRYPT or KeyProperties.PURPOSE_DECRYPT)
                .setBlockModes(KeyProperties.BLOCK_MODE_GCM)
                .setEncryptionPaddings(KeyProperties.ENCRYPTION_PADDING_NONE)
                .setKeySize(256)
                .build()
        )
        return generator.generateKey()
    }

    /** IV (12 bytes) then the AES-GCM ciphertext and tag. */
    private fun encrypt(plain: ByteArray): ByteArray {
        val cipher = Cipher.getInstance("AES/GCM/NoPadding").apply { init(Cipher.ENCRYPT_MODE, key()) }
        return cipher.iv + cipher.doFinal(plain)
    }

    private fun decrypt(sealed: ByteArray): ByteArray {
        val cipher = Cipher.getInstance("AES/GCM/NoPadding")
        cipher.init(Cipher.DECRYPT_MODE, key(), GCMParameterSpec(128, sealed, 0, 12))
        return cipher.doFinal(sealed, 12, sealed.size - 12)
    }
}
