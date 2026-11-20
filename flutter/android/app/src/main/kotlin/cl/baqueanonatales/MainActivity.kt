/**
 * MainActivity: Punto de entrada nativo para la app Flutter.
 * 
 * ## Canales de comunicación (MethodChannels)
 * 1. `com.baqueano/url_launcher`: Abre navegadores externos forzando Chrome
 *    si está disponible (para solucionar bugs de CustomTabs en Motorola).
 * 2. `com.baqueano/lifecycle`: Gestiona el ciclo de vida avanzado de la app.
 * 
 * ## Por qué existe el canal "lifecycle":
 * Flutter no tiene un método nativo para "cerrar la app y borrarla de la
 * lista de Recientes". El método `finishAndRemoveTask()` de Android (API 21+)
 * hace exactamente eso. Lo exponemos a Dart para que el AppUpdateService
 * pueda invocarlo antes de que el usuario actualice el APK.
 */
package cl.baqueanonatales

import android.content.Intent
import android.net.Uri
import io.flutter.embedding.android.FlutterActivity
import io.flutter.embedding.engine.FlutterEngine
import io.flutter.plugin.common.MethodChannel

class MainActivity: FlutterActivity() {
    private val CHANNEL = "com.baqueano/url_launcher"
    private val CHANNEL_LIFECYCLE = "com.baqueano/lifecycle"

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
        
        // Canal para operaciones de ciclo de vida (cerrar app, etc).
        // finishAndRemoveTask() cierra la Activity Y elimina la entrada
        // de "Recientes". Es la forma correcta de cerrar la app después
        // de actualizar el APK, para que no quede una ventana fantasma.
        MethodChannel(flutterEngine.dartExecutor.binaryMessenger, CHANNEL_LIFECYCLE).setMethodCallHandler { call, result ->
            if (call.method == "finishAndRemoveTask") {
                finishAndRemoveTask()
                result.success(true)
            } else {
                result.notImplemented()
            }
        }
    }

    private fun abrirUrlSeguro(url: String, result: MethodChannel.Result) {
        val uri = Uri.parse(url)
        try {
            // 1. Intentar forzar Google Chrome (Solución Motorola)
            val chromeIntent = Intent(Intent.ACTION_VIEW, uri).apply {
                setPackage("com.android.chrome")
                addFlags(Intent.FLAG_ACTIVITY_NEW_TASK)
            }
            try {
                startActivity(chromeIntent)
                result.success(true)
                return
            } catch (_: android.content.ActivityNotFoundException) {
                // Chrome no disponible; continuar al navegador por defecto
            }

            // 2. Usar el navegador por defecto / selector del sistema
            val defaultIntent = Intent(Intent.ACTION_VIEW, uri).apply {
                addFlags(Intent.FLAG_ACTIVITY_NEW_TASK)
            }
            startActivity(defaultIntent)
            result.success(true)
        } catch (_: android.content.ActivityNotFoundException) {
            result.error("NO_BROWSER", "No se encontró ningún navegador instalado", null)
        } catch (e: Exception) {
            result.error("INTENT_ERROR", "Error crítico: ${e.message}", null)
        }
    }
}
