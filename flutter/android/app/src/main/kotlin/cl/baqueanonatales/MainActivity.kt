package cl.baqueanonatales

import android.content.Intent
import android.net.Uri
import io.flutter.embedding.android.FlutterActivity
import io.flutter.embedding.engine.FlutterEngine
import io.flutter.plugin.common.MethodChannel

class MainActivity: FlutterActivity() {
    private val CHANNEL = "com.baqueano/url_launcher"

    override fun configureFlutterEngine(flutterEngine: FlutterEngine) {
        super.configureFlutterEngine(flutterEngine)
        MethodChannel(flutterEngine.dartExecutor.binaryMessenger, CHANNEL).setMethodCallHandler { call, result ->
            if (call.method == "launchUrl") {
                val url = call.argument<String>("url")
                if (url.isNullOrEmpty()) {
                    result.error("INVALID_URL", "URL is null or empty", null)
                    return@setMethodCallHandler
                }
                try {
                    val intent = Intent(Intent.ACTION_VIEW, Uri.parse(url))
                    intent.addCategory(Intent.CATEGORY_BROWSABLE)
                    startActivity(intent)
                    result.success(true)
                } catch (e: Exception) {
                    result.error("UNAVAILABLE", "No se pudo abrir la URL: ${e.message}", null)
                }
            } else {
                result.notImplemented()
            }
        }
    }
}
