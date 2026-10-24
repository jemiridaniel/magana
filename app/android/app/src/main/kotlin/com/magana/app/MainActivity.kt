package com.magana.app

import android.os.Build
import android.speech.SpeechRecognizer
import io.flutter.embedding.android.FlutterActivity
import io.flutter.embedding.engine.FlutterEngine
import io.flutter.plugin.common.MethodChannel

class MainActivity : FlutterActivity() {
    override fun configureFlutterEngine(flutterEngine: FlutterEngine) {
        super.configureFlutterEngine(flutterEngine)
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
                    else -> result.notImplemented()
                }
            }
    }
}
