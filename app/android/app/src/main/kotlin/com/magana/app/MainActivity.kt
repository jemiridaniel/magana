package com.magana.app

import android.Manifest
import android.content.Intent
import android.content.pm.PackageManager
import android.media.AudioAttributes
import android.media.AudioDeviceInfo
import android.media.AudioManager
import android.net.Uri
import android.os.Build
import android.provider.OpenableColumns
import android.speech.SpeechRecognizer
import io.flutter.embedding.android.FlutterActivity
import io.flutter.embedding.engine.FlutterEngine
import io.flutter.plugin.common.MethodChannel

class MainActivity : FlutterActivity() {
    private var pdfChannel: MethodChannel? = null
    // The answer to "may Magana use your Bluetooth headset's microphone?", while it is asked.
    private var bluetoothAsked: MethodChannel.Result? = null
    // A PDF the app was opened with, until Flutter takes it. Held in memory only.
    private var pendingPdf: Map<String, Any>? = null

    override fun configureFlutterEngine(flutterEngine: FlutterEngine) {
        super.configureFlutterEngine(flutterEngine)
        // Offline basic reading and the encrypted queue (OfflineChannels.kt).
        OfflineChannels.register(this, flutterEngine.dartExecutor.binaryMessenger)
        // Whether this phone can recognise speech fully on the device (Android 12+), so audio
        // never leaves it. speech_to_text silently uses the network recogniser when it can't,
        // which under-18 accounts must never do (lib/platform/speech_support.dart).
        MethodChannel(flutterEngine.dartExecutor.binaryMessenger, "magana/speech")
            .setMethodCallHandler { call, result ->
                when (call.method) {
                    "onDeviceAvailable" -> result.success(
                        Build.VERSION.SDK_INT >= Build.VERSION_CODES.S &&
                            SpeechRecognizer.isOnDeviceRecognitionAvailable(this)
                    )
                    "screenReaderSpeaking" -> result.success(screenReaderSpeaking())
                    "bluetoothHeadset" -> result.success(bluetoothHeadset())
                    "bluetoothAllowed" -> result.success(bluetoothAllowed())
                    "askBluetooth" -> askBluetooth(result)
                    else -> result.notImplemented()
                }
            }
        // The phone's maker and model, for problem reports (lib/platform/device_model.dart).
        MethodChannel(flutterEngine.dartExecutor.binaryMessenger, "magana/device")
            .setMethodCallHandler { call, result ->
                when (call.method) {
                    "model" -> result.success("${Build.MANUFACTURER} ${Build.MODEL}".trim())
                    else -> result.notImplemented()
                }
            }
        // "Open with Magana" and Share for PDFs (lib/platform/shared_pdf.dart).
        pdfChannel = MethodChannel(flutterEngine.dartExecutor.binaryMessenger, "magana/shared_pdf").also {
            it.setMethodCallHandler { call, result ->
                when (call.method) {
                    "take" -> {
                        if (pendingPdf == null) pendingPdf = readPdf(intent)
                        result.success(pendingPdf)
                        pendingPdf = null
                        intent = Intent(Intent.ACTION_MAIN) // taken once
                    }
                    else -> result.notImplemented()
                }
            }
        }
    }

    override fun onNewIntent(intent: Intent) {
        super.onNewIntent(intent)
        readPdf(intent)?.let { pdfChannel?.invokeMethod("arrived", it) }
    }

    private fun readPdf(intent: Intent?): Map<String, Any>? {
        if (intent == null) return null
        val uri: Uri? = when (intent.action) {
            Intent.ACTION_VIEW -> intent.data
            Intent.ACTION_SEND ->
                if (Build.VERSION.SDK_INT >= 33) intent.getParcelableExtra(Intent.EXTRA_STREAM, Uri::class.java)
                else @Suppress("DEPRECATION") intent.getParcelableExtra(Intent.EXTRA_STREAM)
            else -> null
        }
        if (uri == null) return null
        return try {
            val bytes = contentResolver.openInputStream(uri)?.use { input ->
                val out = java.io.ByteArrayOutputStream()
                val buf = ByteArray(64 * 1024)
                var total = 0
                while (true) {
                    val n = input.read(buf)
                    if (n < 0) break
                    total += n
                    if (total > MAX_BYTES) return null // too big to read on a phone; the backend says so too
                    out.write(buf, 0, n)
                }
                out.toByteArray()
            } ?: return null
            var name = "document.pdf"
            contentResolver.query(uri, arrayOf(OpenableColumns.DISPLAY_NAME), null, null, null)?.use { c ->
                if (c.moveToFirst()) c.getString(0)?.let { name = it }
            }
            mapOf("bytes" to bytes, "name" to name)
        } catch (e: Exception) {
            null
        }
    }

    companion object {
        const val MAX_BYTES = 15 * 1024 * 1024
        const val BLUETOOTH_REQUEST = 7301
    }

    /** A Bluetooth headset with a microphone is connected (docs/BLUETOOTH.md). */
    private fun bluetoothHeadset(): Boolean {
        val audio = getSystemService(AUDIO_SERVICE) as AudioManager
        return audio.getDevices(AudioManager.GET_DEVICES_INPUTS).any {
            it.type == AudioDeviceInfo.TYPE_BLUETOOTH_SCO ||
                (Build.VERSION.SDK_INT >= Build.VERSION_CODES.S && it.type == AudioDeviceInfo.TYPE_BLE_HEADSET)
        }
    }

    /** speech_to_text uses a Bluetooth microphone only with this permission (Android 12+). */
    private fun bluetoothAllowed(): Boolean =
        Build.VERSION.SDK_INT < Build.VERSION_CODES.S ||
            checkSelfPermission(Manifest.permission.BLUETOOTH_CONNECT) == PackageManager.PERMISSION_GRANTED

    private fun askBluetooth(result: MethodChannel.Result) {
        if (bluetoothAllowed()) return result.success(true)
        if (bluetoothAsked != null) return result.success(false)
        bluetoothAsked = result
        requestPermissions(arrayOf(Manifest.permission.BLUETOOTH_CONNECT), BLUETOOTH_REQUEST)
    }

    override fun onRequestPermissionsResult(requestCode: Int, permissions: Array<String>, grantResults: IntArray) {
        super.onRequestPermissionsResult(requestCode, permissions, grantResults)
        if (requestCode != BLUETOOTH_REQUEST) return
        bluetoothAsked?.success(grantResults.firstOrNull() == PackageManager.PERMISSION_GRANTED)
        bluetoothAsked = null
    }

    /**
     * TalkBack is talking right now, so Magana waits before speaking or opening the microphone
     * (docs/TALKBACK_AUDIT.md). Its speech plays from the TTS engine as accessibility audio
     * while it talks, and the player goes away when it stops; its sound effects are players
     * of music content that stay listed while idle, so they don't count.
     */
    private fun screenReaderSpeaking(): Boolean {
        if (Build.VERSION.SDK_INT < Build.VERSION_CODES.O) return false
        val audio = getSystemService(AUDIO_SERVICE) as AudioManager
        return audio.activePlaybackConfigurations.any {
            it.audioAttributes.usage == AudioAttributes.USAGE_ASSISTANCE_ACCESSIBILITY &&
                it.audioAttributes.contentType != AudioAttributes.CONTENT_TYPE_MUSIC
        }
    }
}
