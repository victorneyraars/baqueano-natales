package cl.baqueanonatales

import android.content.Intent
import android.net.Uri
import io.flutter.embedding.android.FlutterActivity
import io.flutter.embedding.engine.FlutterEngine
import io.flutter.plugin.common.MethodChannel

class MainActivity: FlutterActivity() {
    private val CHANNEL = "baqueano/url_launcher"

    override fun configureFlutterEngine(flutterEngine: FlutterEngine) {
        super.configureFlutterEngine(flutterEngine)
        MethodChannel(flutterEngine.dartExecutor.binaryMessenger, CHANNEL).setMethodCallHandler { call, result ->
            if (call.method == "launchUrl") {
                val url = call.argument<String>("url")
                if (url != null) {
                    abrirUrlSeguro(url, result)
                } else {
                    result.error("INVALID_URL", "La URL es nula", null)
                }
            } else {
                result.notImplemented()
            }
        }
    }

    private fun abrirUrlSeguro(url: String, result: MethodChannel.Result) {
        try {
            val intent = Intent(Intent.ACTION_VIEW, Uri.parse(url))
            intent.addFlags(Intent.FLAG_ACTIVITY_NEW_TASK)

            // 1. Intentar forzar Google Chrome (Solución Motorola)
            intent.setPackage("com.android.chrome")
            if (intent.resolveActivity(packageManager) != null) {
                startActivity(intent)
                result.success(true)
                return
            }

            // 2. Si Chrome no está instalado, usar el navegador por defecto
            intent.setPackage(null)
            if (intent.resolveActivity(packageManager) != null) {
                startActivity(intent)
                result.success(true)
                return
            }

            result.error("NO_BROWSER", "No se encontró ningún navegador instalado", null)
        } catch (e: Exception) {
            result.error("INTENT_ERROR", "Error crítico: \${e.message}", null)
        }
    }
}
