package ir.example.pashmak_app

import android.provider.Settings
import io.flutter.embedding.android.FlutterActivity
import io.flutter.embedding.engine.FlutterEngine
import io.flutter.plugin.common.MethodChannel

class MainActivity : FlutterActivity() {
    override fun configureFlutterEngine(flutterEngine: FlutterEngine) {
        super.configureFlutterEngine(flutterEngine)
        // Tiny channel: the raw ANDROID_ID used (salted+hashed server-side) to limit one trial per device.
        MethodChannel(flutterEngine.dartExecutor.binaryMessenger, "app/device").setMethodCallHandler { call, result ->
            if (call.method == "androidId") {
                result.success(Settings.Secure.getString(contentResolver, Settings.Secure.ANDROID_ID) ?: "unknown")
            } else {
                result.notImplemented()
            }
        }
    }
}
