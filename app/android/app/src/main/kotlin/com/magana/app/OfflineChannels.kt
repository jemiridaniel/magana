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
 * - "magana/offline": an upright copy of a photo for on-device text recognition, crops of it so
 *   each number can be read a second time, and a flattened copy for faint print. Files live in the app's private cache and the
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
                    "flatten" -> result.success(flatten(context, call.argument<String>("path")!!))
                    "shrink" -> result.success(
                        shrink(context, call.argument<ByteArray>("bytes")!!, call.argument<Int>("maxWidth")!!,
                            call.argument<Int>("quality")!!)
                    )
                    "delete" -> result.success(File(call.argument<String>("path")!!).delete())
                    "inkDepth" -> result.success(
                        inkDepth(call.argument<String>("path")!!, call.argument<List<List<Int>>>("boxes")!!)
                    )
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

    /**
     * The photo to send for reading: turned upright (EXIF), at most [maxWidth] wide, re-encoded as a
     * JPEG at [quality]. 1080 px at 85 reads all the numbers on the 40-page set that 720 px missed,
     * at about 37 KB a page (docs/FINDINGS.md, 27 Oct 2026).
     */
    private fun shrink(context: Context, bytes: ByteArray, maxWidth: Int, quality: Int): ByteArray {
        val raw = cacheFile(context, ".jpg").apply { writeBytes(bytes) }
        try {
            val bounds = BitmapFactory.Options().apply { inJustDecodeBounds = true }
            BitmapFactory.decodeFile(raw.path, bounds)
            var sample = 1
            while (minOf(bounds.outWidth, bounds.outHeight) / (sample * 2) >= maxWidth) sample *= 2
            val decoded = BitmapFactory.decodeFile(raw.path, BitmapFactory.Options().apply { inSampleSize = sample })
                ?: throw IllegalArgumentException("not an image")
            val degrees = when (ExifInterface(raw.path).getAttributeInt(ExifInterface.TAG_ORIENTATION, 1)) {
                ExifInterface.ORIENTATION_ROTATE_90 -> 90f
                ExifInterface.ORIENTATION_ROTATE_180 -> 180f
                ExifInterface.ORIENTATION_ROTATE_270 -> 270f
                else -> 0f
            }
            var turned = if (degrees == 0f) decoded else
                Bitmap.createBitmap(decoded, 0, 0, decoded.width, decoded.height, Matrix().apply { postRotate(degrees) }, true)
            if (turned.width > maxWidth) {
                turned = Bitmap.createScaledBitmap(turned, maxWidth, (turned.height.toLong() * maxWidth / turned.width).toInt(), true)
            }
            val out = java.io.ByteArrayOutputStream()
            turned.compress(Bitmap.CompressFormat.JPEG, quality, out)
            return out.toByteArray()
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

    /**
     * Thermal or faint print (as the server's reader.flatten_contrast): each pixel divided by the
     * blurred paper around it, so uneven light goes and the paper turns even white, then stretched
     * to full contrast (1% clipped at each end). Cheap on a phone: the blur is three small box blurs
     * on an image an eighth of the size (about the server's Gaussian of 25 px), sampled back
     * bilinearly. Returns a grey private JPEG, like [upright].
     */
    /**
     * For each box [left, top, width, height]: how dark its strokes are against the paper around
     * it (the paper's 90th percentile brightness minus the box's 5th). Show-through is faint.
     */
    private fun inkDepth(path: String, boxes: List<List<Int>>): List<Double> {
        val bitmap = BitmapFactory.decodeFile(path) ?: return boxes.map { 0.0 }
        val w = bitmap.width
        val h = bitmap.height
        val pixels = IntArray(w * h)
        bitmap.getPixels(pixels, 0, w, 0, 0, w, h)
        bitmap.recycle()
        fun values(x0: Int, y0: Int, x1: Int, y1: Int): IntArray {
            val l = maxOf(0, x0); val t = maxOf(0, y0); val r = minOf(w, x1); val b = minOf(h, y1)
            if (r <= l || b <= t) return IntArray(0)
            val out = IntArray((r - l) * (b - t))
            var i = 0
            for (y in t until b) for (x in l until r) {
                val p = pixels[y * w + x]
                out[i++] = (((p shr 16) and 255) * 299 + ((p shr 8) and 255) * 587 + (p and 255) * 114) / 1000
            }
            out.sort()
            return out
        }
        return boxes.map { box ->
            if (box.size != 4) return@map 0.0
            val (l, t, bw, bh) = box
            val ink = values(l, t, l + bw, t + bh)
            val paper = values(l - bh, t - bh, l + bw + bh, t + 2 * bh)
            if (ink.isEmpty() || paper.isEmpty()) 0.0
            else maxOf(0.0, (paper[paper.size * 9 / 10] - ink[ink.size / 20]).toDouble())
        }
    }

    private fun flatten(context: Context, path: String): Map<String, Any> {
        val src = BitmapFactory.decodeFile(path) ?: throw IllegalArgumentException("not an image")
        val w = src.width
        val h = src.height
        val px = IntArray(w * h)
        src.getPixels(px, 0, w, 0, 0, w, h)
        val gray = FloatArray(w * h)
        for (i in px.indices) {
            val c = px[i]
            gray[i] = 0.299f * ((c shr 16) and 255) + 0.587f * ((c shr 8) and 255) + 0.114f * (c and 255)
        }
        val s = 8
        val sw = (w + s - 1) / s
        val sh = (h + s - 1) / s
        var small = FloatArray(sw * sh)
        val count = IntArray(sw * sh)
        for (y in 0 until h) for (x in 0 until w) {
            val i = (y / s) * sw + x / s
            small[i] += gray[y * w + x]
            count[i]++
        }
        for (i in small.indices) small[i] /= count[i]
        repeat(3) { small = boxBlur(small, sw, sh, 3) }
        val v = FloatArray(w * h)
        val hist = IntArray(256)
        for (y in 0 until h) {
            val fy = ((y + 0.5f) / s - 0.5f).coerceIn(0f, (sh - 1).toFloat())
            val y0 = fy.toInt()
            val y1 = minOf(y0 + 1, sh - 1)
            val ty = fy - y0
            for (x in 0 until w) {
                val fx = ((x + 0.5f) / s - 0.5f).coerceIn(0f, (sw - 1).toFloat())
                val x0 = fx.toInt()
                val x1 = minOf(x0 + 1, sw - 1)
                val tx = fx - x0
                val bg = small[y0 * sw + x0] * (1 - ty) * (1 - tx) + small[y0 * sw + x1] * (1 - ty) * tx +
                    small[y1 * sw + x0] * ty * (1 - tx) + small[y1 * sw + x1] * ty * tx
                val f = (gray[y * w + x] / (bg + 1) * 235f).coerceIn(0f, 255f)
                v[y * w + x] = f
                hist[f.toInt().coerceIn(0, 255)]++
            }
        }
        var lo = 0
        var hi = 255
        var acc = 0
        for (i in 0..255) { acc += hist[i]; if (acc >= px.size / 100) { lo = i; break } }
        acc = 0
        for (i in 255 downTo 0) { acc += hist[i]; if (acc >= px.size / 100) { hi = i; break } }
        val span = maxOf(1, hi - lo).toFloat()
        for (i in px.indices) {
            val g = ((v[i] - lo) * 255f / span).toInt().coerceIn(0, 255)
            px[i] = (0xFF shl 24) or (g shl 16) or (g shl 8) or g
        }
        val out = cacheFile(context, ".jpg")
        out.outputStream().use { Bitmap.createBitmap(px, w, h, Bitmap.Config.ARGB_8888).compress(Bitmap.CompressFormat.JPEG, 92, it) }
        return mapOf("path" to out.path, "width" to w, "height" to h)
    }

    /** A box blur of radius [r], across then down (edges repeat). */
    private fun boxBlur(a: FloatArray, w: Int, h: Int, r: Int): FloatArray {
        val k = 2 * r + 1
        val across = FloatArray(a.size)
        for (y in 0 until h) for (x in 0 until w) {
            var sum = 0f
            for (d in -r..r) sum += a[y * w + (x + d).coerceIn(0, w - 1)]
            across[y * w + x] = sum / k
        }
        val down = FloatArray(a.size)
        for (y in 0 until h) for (x in 0 until w) {
            var sum = 0f
            for (d in -r..r) sum += across[(y + d).coerceIn(0, h - 1) * w + x]
            down[y * w + x] = sum / k
        }
        return down
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
