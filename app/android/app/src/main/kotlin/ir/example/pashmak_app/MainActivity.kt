package ir.example.pashmak_app

import android.provider.Settings
import android.view.WindowManager
import io.flutter.embedding.android.FlutterActivity
import io.flutter.embedding.engine.FlutterEngine
import io.flutter.plugin.common.MethodChannel

class MainActivity : FlutterActivity() {
    override fun configureFlutterEngine(flutterEngine: FlutterEngine) {
        super.configureFlutterEngine(flutterEngine)
        FlavorBilling.register(this, flutterEngine) // implemented per flavor (src/bazaar, src/myket)
        // Tiny channel: the raw ANDROID_ID used (salted+hashed server-side) to limit one trial per device.
        MethodChannel(flutterEngine.dartExecutor.binaryMessenger, "app/device").setMethodCallHandler { call, result ->
            when (call.method) {
                "androidId" -> result.success(Settings.Secure.getString(contentResolver, Settings.Secure.ANDROID_ID) ?: "unknown")
                "keepScreenOn" -> {
                    val on = call.arguments as? Boolean ?: false
                    if (on) window.addFlags(WindowManager.LayoutParams.FLAG_KEEP_SCREEN_ON)
                    else window.clearFlags(WindowManager.LayoutParams.FLAG_KEEP_SCREEN_ON)
                    result.success(null)
                }
                else -> result.notImplemented()
            }
        }
    }
}
