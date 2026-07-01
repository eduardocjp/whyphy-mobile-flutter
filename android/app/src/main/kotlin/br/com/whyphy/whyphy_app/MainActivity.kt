package br.com.whyphy.whyphy_app

import android.util.Log
import android.Manifest
import android.app.Activity
import android.app.AlarmManager
import android.app.DownloadManager
import android.app.Notification
import android.app.NotificationChannel
import android.app.NotificationManager
import android.app.PendingIntent
import android.content.BroadcastReceiver
import android.content.ContentValues
import android.content.Context
import android.content.Intent
import android.content.IntentFilter
import android.content.pm.PackageManager
import android.graphics.Color
import android.graphics.pdf.PdfDocument
import android.os.Build
import android.net.Uri
import android.os.Handler
import android.os.Looper
import android.os.Environment
import android.provider.OpenableColumns
import android.provider.MediaStore
import android.provider.Settings
import android.security.keystore.KeyGenParameterSpec
import android.security.keystore.KeyProperties
import android.util.Base64
import android.view.View
import android.webkit.CookieManager
import android.webkit.JavascriptInterface
import android.webkit.JsPromptResult
import android.webkit.JsResult
import android.webkit.PermissionRequest
import android.webkit.URLUtil
import android.webkit.ValueCallback
import android.webkit.WebChromeClient
import android.webkit.WebResourceError
import android.webkit.WebResourceRequest
import android.webkit.WebResourceResponse
import android.webkit.WebSettings
import android.webkit.WebStorage
import android.webkit.WebView
import android.webkit.WebViewClient
import android.view.ViewGroup
import io.flutter.embedding.android.FlutterActivity
import io.flutter.embedding.engine.FlutterEngine
import io.flutter.plugin.common.MethodCall
import io.flutter.plugin.common.MethodChannel
import io.flutter.plugin.common.StandardMessageCodec
import io.flutter.plugin.platform.PlatformView
import io.flutter.plugin.platform.PlatformViewFactory
import org.json.JSONObject
import java.io.File
import java.text.SimpleDateFormat
import java.security.KeyStore
import java.util.Locale
import java.util.TimeZone
import java.util.UUID
import javax.crypto.Cipher
import javax.crypto.KeyGenerator
import javax.crypto.SecretKey
import javax.crypto.spec.GCMParameterSpec

private const val CANAL_NOTIFICACAO_TREINO_LOCAL = "WhyPhyWorkoutNotifications"
private const val CANAL_NOTIFICACAO_REFEICAO_LOCAL = "WhyPhyMealNotifications"
private const val PREFS_NOTIFICACOES_LOCAIS = "whyphy_notificacoes_locais"
private const val PREFS_AGENDAMENTOS_NOTIFICACAO = "agendamentos"

class MainActivity : FlutterActivity() {
    private var arquivoSelecionadoCallback: ValueCallback<Array<Uri>>? = null
    private var arquivoSelecionadoParamsPendente: WebChromeClient.FileChooserParams? = null
    private var arquivoUploadNativoResult: MethodChannel.Result? = null
    private var canalEventosWebview: MethodChannel? = null
    private var permissaoCameraPendente: PermissionRequest? = null
    private var payloadPushPendente: Map<String, String>? = null
    private var webViewAtiva: WebView? = null
    private var webViewAllowedHostAtivo: String = ""
    private var webViewHeadersAtivos: Map<String, String> = emptyMap()

    override fun configureFlutterEngine(flutterEngine: FlutterEngine) {
        super.configureFlutterEngine(flutterEngine)
        criarCanaisNotificacaoLocal()
        garantirPermissaoNotificacaoLocal()

        val armazenamento = ArmazenamentoSeguroWhyPhy(applicationContext)

        MethodChannel(
            flutterEngine.dartExecutor.binaryMessenger,
            "br.com.whyphy/armazenamento_seguro",
        ).setMethodCallHandler { call, result ->
            tratarArmazenamentoSeguro(call, result, armazenamento)
        }

        MethodChannel(
            flutterEngine.dartExecutor.binaryMessenger,
            "br.com.whyphy/push_mobile",
        ).setMethodCallHandler { call, result ->
            when (call.method) {
                "inicializarPush" -> result.success(null)
                "obterRegistroPush" -> result.success(null)
                else -> result.notImplemented()
            }
        }

        MethodChannel(
            flutterEngine.dartExecutor.binaryMessenger,
            "br.com.whyphy/upload_nativo",
        ).setMethodCallHandler { call, result ->
            when (call.method) {
                "selecionarArquivo" -> selecionarArquivoUploadNativo(result)
                else -> result.notImplemented()
            }
        }

        MethodChannel(
            flutterEngine.dartExecutor.binaryMessenger,
            "br.com.whyphy/notificacoes_locais",
        ).setMethodCallHandler { call, result ->
            when (call.method) {
                "agendar" -> {
                    agendarNotificacaoLocalFlutter(call.arguments)
                    result.success(null)
                }
                "cancelar" -> {
                    cancelarNotificacaoLocalFlutter(call.arguments)
                    result.success(null)
                }
                else -> result.notImplemented()
            }
        }

        MethodChannel(
            flutterEngine.dartExecutor.binaryMessenger,
            "br.com.whyphy/compartilhamento_work",
        ).setMethodCallHandler { call, result ->
            when (call.method) {
                "compartilharTexto" -> {
                    result.success(compartilharTextoWork(call.arguments))
                }
                "abrirCamera" -> {
                    result.success(abrirCameraCompartilhamentoWork(call.arguments))
                }
                "abrirGaleria" -> {
                    result.success(abrirGaleriaCompartilhamentoWork(call.arguments))
                }
                else -> result.notImplemented()
            }
        }

        canalEventosWebview = MethodChannel(
            flutterEngine.dartExecutor.binaryMessenger,
            "br.com.whyphy/webview_eventos",
        )
        val canalEventosWebview = canalEventosWebview
            ?: error("Canal de eventos da WebView nao inicializado.")
        val gerenciadorPopups = GerenciadorPopupsWebview(canalEventosWebview)
        val gerenciadorDownloads = GerenciadorDownloadsWebview(
            context = this,
            canalEventosWebview = canalEventosWebview,
        )
        payloadPushPendente = extrairPayloadPush(intent) ?: payloadPushPendente

        canalEventosWebview.setMethodCallHandler { call, result ->
            when (call.method) {
                "consumirPushAberto" -> {
                    result.success(consumirPayloadPushPendente())
                }
                "responderPopupNativo" -> {
                    gerenciadorPopups.responder(
                        id = call.argument<String>("id"),
                        confirmado = call.argument<Boolean>("confirmado") ?: false,
                        texto = call.argument<String>("texto"),
                    )
                    result.success(null)
                }
                "voltarWebview" -> {
                    result.success(voltarWebviewAtiva())
                }
                "podeVoltarWebview" -> {
                    result.success(webViewAtiva?.canGoBack() == true)
                }
                "navegarWebview" -> {
                    result.success(navegarWebviewAtiva(call.argument<String>("url")))
                }
                "recarregarWebview" -> {
                    result.success(recarregarWebviewAtiva())
                }
                "limparCookiesWebview" -> {
                    limparCookiesWebviewAtiva()
                    result.success(null)
                }
                "responderUploadNativo" -> {
                    responderUploadNativoWebview(call.arguments)
                    result.success(null)
                }
                "executarJavascriptWebview" -> {
                    result.success(executarJavascriptWebviewAtiva(call.argument<String>("script")))
                }
                else -> result.notImplemented()
            }
        }

        flutterEngine
            .platformViewsController
            .registry
            .registerViewFactory(
                "br.com.whyphy/webview",
                WebViewWhyPhyFactory(
                    this,
                    canalEventosWebview,
                    gerenciadorPopups,
                    gerenciadorDownloads,
                ),
            )
    }

    override fun onNewIntent(intent: Intent) {
        super.onNewIntent(intent)
        setIntent(intent)

        val payloadPush = extrairPayloadPush(intent) ?: return
        payloadPushPendente = payloadPush
        canalEventosWebview?.invokeMethod("pushAberto", payloadPush)
    }

    private fun consumirPayloadPushPendente(): Map<String, String>? {
        val payload = payloadPushPendente
        payloadPushPendente = null
        return payload
    }

    private fun extrairPayloadPush(intent: Intent?): Map<String, String>? {
        if (intent == null) {
            return null
        }

        val routePath = (
            intent.getStringExtra("routePath")
                ?: intent.getStringExtra("next")
                ?: ""
            ).trim()

        if (!routePath.startsWith("/") || routePath.startsWith("//")) {
            return null
        }

        val payload = linkedMapOf<String, String>()
        payload["routePath"] = routePath

        adicionarExtraPush(payload, "mensagem", intent.getStringExtra("mensagem"))
        adicionarExtraPush(payload, "mensagem", intent.getStringExtra("body"))
        adicionarExtraPush(payload, "title", intent.getStringExtra("title"))
        adicionarExtraPush(payload, "tipo", intent.getStringExtra("tipo"))
        adicionarExtraPush(payload, "stage", intent.getStringExtra("stage"))
        adicionarExtraPush(payload, "appointmentId", intent.getStringExtra("appointmentId"))
        adicionarExtraPush(payload, "appointmentKind", intent.getStringExtra("appointmentKind"))
        adicionarExtraPush(payload, "consultaId", intent.getStringExtra("consultaId"))

        return payload
    }

    private fun adicionarExtraPush(
        payload: MutableMap<String, String>,
        key: String,
        value: String?,
    ) {
        val normalizedValue = value?.trim().orEmpty()

        if (normalizedValue.isNotEmpty() && !payload.containsKey(key)) {
            payload[key] = normalizedValue
        }
    }

    private fun criarCanaisNotificacaoLocal() {
        if (Build.VERSION.SDK_INT < Build.VERSION_CODES.O) {
            return
        }

        val notificationManager = getSystemService(NotificationManager::class.java)
        val canais = listOf(
            NotificationChannel(
                CANAL_NOTIFICACAO_TREINO,
                "WhyPhy treinos",
                NotificationManager.IMPORTANCE_DEFAULT,
            ).apply {
                description = "Alertas locais de treino do WhyPhy."
            },
            NotificationChannel(
                CANAL_NOTIFICACAO_REFEICAO,
                "WhyPhy refeiÃ§Ãµes",
                NotificationManager.IMPORTANCE_DEFAULT,
            ).apply {
                description = "Alertas locais de refeiÃ§Ã£o do WhyPhy."
            },
        )

        canais.forEach(notificationManager::createNotificationChannel)
    }

    private fun garantirPermissaoNotificacaoLocal() {
        if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.TIRAMISU &&
            checkSelfPermission(Manifest.permission.POST_NOTIFICATIONS) != PackageManager.PERMISSION_GRANTED
        ) {
            requestPermissions(
                arrayOf(Manifest.permission.POST_NOTIFICATIONS),
                REQUEST_NOTIFICACAO_PERMISSION,
            )
        }
    }

    fun abrirSeletorArquivo(
        callback: ValueCallback<Array<Uri>>,
        params: WebChromeClient.FileChooserParams,
    ): Boolean {
        arquivoSelecionadoCallback?.onReceiveValue(null)
        arquivoSelecionadoCallback = callback
        arquivoSelecionadoParamsPendente = null

        if (precisaPermissaoCameraParaChooser(params) && !cameraPermitida()) {
            arquivoSelecionadoParamsPendente = params
            requestPermissions(
                arrayOf(Manifest.permission.CAMERA),
                REQUEST_CAMERA_PERMISSION_FILE_CHOOSER,
            )
            return true
        }

        return abrirSeletorArquivoComPermissao(params)
    }

    fun solicitarPermissaoWebview(request: PermissionRequest) {
        val recursosPermitidos = request.resources.filter { recurso ->
            recurso == PermissionRequest.RESOURCE_VIDEO_CAPTURE
        }.toTypedArray()

        if (recursosPermitidos.isEmpty()) {
            request.deny()
            return
        }

        if (cameraPermitida()) {
            request.grant(recursosPermitidos)
            return
        }

        permissaoCameraPendente?.deny()
        permissaoCameraPendente = request
        requestPermissions(
            arrayOf(Manifest.permission.CAMERA),
            REQUEST_CAMERA_PERMISSION_WEBVIEW,
        )
    }

    fun registrarWebViewAtiva(
        webView: WebView,
        allowedHost: String,
        headers: Map<String, String>,
    ) {
        webViewAtiva = webView
        webViewAllowedHostAtivo = allowedHost
        webViewHeadersAtivos = headers
    }

    fun limparWebViewAtiva(webView: WebView) {
        if (webViewAtiva == webView) {
            webViewAtiva = null
            webViewAllowedHostAtivo = ""
            webViewHeadersAtivos = emptyMap()
        }
    }

    private fun abrirSeletorArquivoComPermissao(
        params: WebChromeClient.FileChooserParams,
    ): Boolean {
        return try {
            startActivityForResult(params.createIntent(), REQUEST_FILE_CHOOSER)
            true
        } catch (erro: Exception) {
            arquivoSelecionadoCallback?.onReceiveValue(null)
            arquivoSelecionadoCallback = null
            false
        }
    }

    private fun voltarWebviewAtiva(): Boolean {
        val webView = webViewAtiva ?: return false

        if (!webView.canGoBack()) {
            return false
        }

        webView.goBack()
        return true
    }

    private fun navegarWebviewAtiva(url: String?): Boolean {
        val webView = webViewAtiva ?: return false
        val uri = Uri.parse(url?.trim().orEmpty())
        val scheme = uri.scheme.orEmpty()

        if ((scheme != "http" && scheme != "https") || !hostPermitidoWebviewAtiva(uri.host.orEmpty())) {
            return false
        }

        webView.visibility = View.VISIBLE
        webView.alpha = 1f
        webView.isClickable = true
        webView.isFocusable = true
        webView.loadUrl(uri.toString(), webViewHeadersAtivos)

        return true
    }

    private fun recarregarWebviewAtiva(): Boolean {
        val webView = webViewAtiva ?: return false
        webView.reload()
        return true
    }

    private fun limparCookiesWebviewAtiva() {
        val webView = webViewAtiva

        webView?.stopLoading()
        webView?.clearHistory()
        webView?.clearCache(true)
        webView?.clearFormData()
        WebStorage.getInstance().deleteAllData()
        CookieManager.getInstance().removeAllCookies(null)
        CookieManager.getInstance().flush()
    }

    private fun responderUploadNativoWebview(arguments: Any?) {
        val webView = webViewAtiva ?: return
        val payload = JSONObject()
        val map = arguments as? Map<*, *> ?: emptyMap<String, Any?>()

        for ((key, value) in map) {
            val nome = key as? String ?: continue
            payload.put(nome, value)
        }

        val script = """
            (function() {
              var detalhe = $payload;
              window.dispatchEvent(new CustomEvent("WhyPhyUploadResultado", { detail: detalhe }));
              var callbacks = window.__whyphyUploadCallbacks || {};
              var callbackId = detalhe && detalhe.callbackId;
              if (callbackId && callbacks[callbackId]) {
                callbacks[callbackId](detalhe);
                delete callbacks[callbackId];
              }
            })();
        """.trimIndent()

        webView.evaluateJavascript(script, null)
    }

    private fun executarJavascriptWebviewAtiva(script: String?): Boolean {
        val webView = webViewAtiva ?: return false
        val codigo = script?.trim().orEmpty()

        if (codigo.isEmpty()) {
            return false
        }

        webView.evaluateJavascript(codigo, null)
        return true
    }

    private fun agendarNotificacaoLocalFlutter(arguments: Any?) {
        val map = arguments as? Map<*, *> ?: return
        val id = (map["notificationId"] as? String)?.trim().orEmpty()
        val tituloRaw = (map["title"] as? String)?.trim().orEmpty()
        val mensagemRaw = (map["body"] as? String)?.trim().orEmpty()
        val titulo = tituloRaw.ifBlank { "WhyPhy" }
        val mensagem = mensagemRaw.ifBlank { "Voce tem uma atividade pendente." }
        val routePath = (map["routePath"] as? String)?.trim().orEmpty()
        val tipo = (map["type"] as? String)?.lowercase(Locale.ROOT).orEmpty()
        val triggerAtMillis = when (val valor = map["triggerAtMillis"]) {
            is Number -> valor.toLong()
            is String -> valor.toLongOrNull() ?: System.currentTimeMillis()
            else -> System.currentTimeMillis()
        }

        if (id.isEmpty()) {
            return
        }

        val canal = if (tipo.contains("meal") || tipo.contains("refeic")) {
            CANAL_NOTIFICACAO_REFEICAO_LOCAL
        } else {
            CANAL_NOTIFICACAO_TREINO_LOCAL
        }

        AgendadorNotificacaoLocalWhyPhy.agendar(
            this,
            AgendamentoNotificacaoLocal(
                id = id,
                canal = canal,
                routePath = routePath,
                titulo = titulo,
                mensagem = mensagem,
                quandoMillis = triggerAtMillis,
            ),
        )
    }

    private fun cancelarNotificacaoLocalFlutter(arguments: Any?) {
        val map = arguments as? Map<*, *> ?: return
        val id = (map["notificationId"] as? String)?.trim().orEmpty()

        if (id.isNotEmpty()) {
            AgendadorNotificacaoLocalWhyPhy.cancelar(this, id)
        }
    }

    private fun compartilharTextoWork(arguments: Any?): Boolean {
        val map = arguments as? Map<*, *> ?: return false
        val texto = (map["texto"] as? String)?.trim().orEmpty()
        val tituloRaw = (map["titulo"] as? String)?.trim().orEmpty()
        val titulo = tituloRaw.ifBlank { "Compartilhar treino WhyPhy" }

        if (texto.isEmpty()) {
            return false
        }

        return try {
            val sendIntent = Intent(Intent.ACTION_SEND).apply {
                type = "text/plain"
                putExtra(Intent.EXTRA_TEXT, texto)
                putExtra(Intent.EXTRA_TITLE, titulo)
            }
            val chooser = Intent.createChooser(sendIntent, titulo).apply {
                addFlags(Intent.FLAG_ACTIVITY_NEW_TASK)
            }
            startActivity(chooser)
            true
        } catch (erro: Exception) {
            false
        }
    }

    private fun abrirCameraCompartilhamentoWork(arguments: Any?): Boolean {
        val map = arguments as? Map<*, *> ?: emptyMap<String, Any?>()
        val titulo = (map["titulo"] as? String)?.trim().orEmpty()
            .ifBlank { "Compartilhar treino WhyPhy" }
        val intent = Intent(MediaStore.ACTION_IMAGE_CAPTURE)

        return try {
            startActivity(Intent.createChooser(intent, titulo))
            true
        } catch (erro: Exception) {
            false
        }
    }

    private fun abrirGaleriaCompartilhamentoWork(arguments: Any?): Boolean {
        val map = arguments as? Map<*, *> ?: emptyMap<String, Any?>()
        val titulo = (map["titulo"] as? String)?.trim().orEmpty()
            .ifBlank { "Compartilhar treino WhyPhy" }
        val intent = Intent(Intent.ACTION_PICK, MediaStore.Images.Media.EXTERNAL_CONTENT_URI).apply {
            type = "image/*"
        }

        return try {
            startActivity(Intent.createChooser(intent, titulo))
            true
        } catch (erro: Exception) {
            false
        }
    }

    private fun selecionarArquivoUploadNativo(result: MethodChannel.Result) {
        if (arquivoUploadNativoResult != null) {
            result.error("upload_em_andamento", "JÃ¡ existe uma seleÃ§Ã£o de arquivo em andamento.", null)
            return
        }

        arquivoUploadNativoResult = result

        val intent = Intent(Intent.ACTION_OPEN_DOCUMENT).apply {
            addCategory(Intent.CATEGORY_OPENABLE)
            type = "*/*"
            putExtra(
                Intent.EXTRA_MIME_TYPES,
                arrayOf("image/*", "application/pdf"),
            )
        }

        try {
            startActivityForResult(intent, REQUEST_UPLOAD_NATIVO)
        } catch (erro: Exception) {
            arquivoUploadNativoResult = null
            result.error("seletor_indisponivel", "NÃ£o foi possÃ­vel abrir o seletor de arquivo.", null)
        }
    }

    private fun concluirUploadNativo(data: Intent?) {
        val result = arquivoUploadNativoResult ?: return
        arquivoUploadNativoResult = null
        val uri = data?.data

        if (uri == null) {
            result.success(null)
            return
        }

        try {
            result.success(copiarArquivoUploadNativo(uri))
        } catch (erro: Exception) {
            result.error("arquivo_indisponivel", "NÃ£o foi possÃ­vel preparar o arquivo selecionado.", null)
        }
    }

    private fun copiarArquivoUploadNativo(uri: Uri): Map<String, Any?> {
        val resolver = contentResolver
        val nomeOriginal = nomeArquivoUri(uri)
        val nomeSeguro = normalizarNomeArquivoUpload(nomeOriginal)
        val diretorio = File(cacheDir, "whyphy_uploads")

        if (!diretorio.exists()) {
            diretorio.mkdirs()
        }

        val destino = File(diretorio, "${System.currentTimeMillis()}_${UUID.randomUUID()}_$nomeSeguro")

        resolver.openInputStream(uri)?.use { input ->
            destino.outputStream().use { output ->
                input.copyTo(output)
            }
        } ?: throw IllegalStateException("upload_input_indisponivel")

        val mimeType = resolver.getType(uri) ?: "application/octet-stream"

        return mapOf(
            "caminhoLocal" to destino.absolutePath,
            "mimeType" to mimeType,
            "nome" to nomeSeguro,
            "tamanhoBytes" to destino.length(),
        )
    }

    private fun nomeArquivoUri(uri: Uri): String {
        contentResolver.query(uri, null, null, null, null)?.use { cursor ->
            val indiceNome = cursor.getColumnIndex(OpenableColumns.DISPLAY_NAME)

            if (indiceNome >= 0 && cursor.moveToFirst()) {
                val nome = cursor.getString(indiceNome)

                if (!nome.isNullOrBlank()) {
                    return nome
                }
            }
        }

        return uri.lastPathSegment?.substringAfterLast('/') ?: "whyphy-arquivo"
    }

    private fun normalizarNomeArquivoUpload(nomeArquivo: String): String {
        return nomeArquivo
            .trim()
            .ifBlank { "whyphy-arquivo" }
            .replace(Regex("[^A-Za-z0-9._-]"), "-")
            .replace(Regex("-+"), "-")
            .trim('-')
            .ifBlank { "whyphy-arquivo" }
    }

    private fun hostPermitidoWebviewAtiva(host: String): Boolean {
        if (host.isBlank()) {
            return false
        }

        if (host == webViewAllowedHostAtivo) {
            return true
        }

        val dominioPrincipal = "whyphy.com.br"
        val ambienteWhyPhy = webViewAllowedHostAtivo == dominioPrincipal ||
            webViewAllowedHostAtivo.endsWith(".$dominioPrincipal")

        return ambienteWhyPhy &&
            (host == dominioPrincipal || host.endsWith(".$dominioPrincipal"))
    }

    private fun tratarVoltarFisicoAndroid() {
        if (voltarWebviewAtiva()) {
            return
        }

        canalEventosWebview?.invokeMethod(
            "notificacaoWeb",
            mapOf(
                "mensagem" to "Use a navegação do WhyPhy para sair ou voltar.",
                "modulo" to "",
            ),
        )
    }

    private fun precisaPermissaoCameraParaChooser(
        params: WebChromeClient.FileChooserParams,
    ): Boolean {
        if (!params.isCaptureEnabled) {
            return false
        }

        if (params.acceptTypes.isEmpty()) {
            return true
        }

        return params.acceptTypes.any { tipo ->
            val normalizado = tipo.lowercase(Locale.ROOT).trim()
            normalizado.isEmpty() ||
                normalizado == "*/*" ||
                normalizado == "image/*" ||
                normalizado == "video/*" ||
                normalizado.startsWith("image/") ||
                normalizado.startsWith("video/")
        }
    }

    private fun cameraPermitida(): Boolean {
        return Build.VERSION.SDK_INT < Build.VERSION_CODES.M ||
            checkSelfPermission(Manifest.permission.CAMERA) == PackageManager.PERMISSION_GRANTED
    }

    override fun onActivityResult(requestCode: Int, resultCode: Int, data: Intent?) {
        if (requestCode == REQUEST_FILE_CHOOSER) {
            val resultado = if (resultCode == Activity.RESULT_OK) {
                WebChromeClient.FileChooserParams.parseResult(resultCode, data)
            } else {
                null
            }

            arquivoSelecionadoCallback?.onReceiveValue(resultado)
            arquivoSelecionadoCallback = null
            return
        }

        if (requestCode == REQUEST_UPLOAD_NATIVO) {
            if (resultCode == Activity.RESULT_OK) {
                concluirUploadNativo(data)
            } else {
                arquivoUploadNativoResult?.success(null)
                arquivoUploadNativoResult = null
            }
            return
        }

        super.onActivityResult(requestCode, resultCode, data)
    }

    override fun onRequestPermissionsResult(
        requestCode: Int,
        permissions: Array<out String>,
        grantResults: IntArray,
    ) {
        super.onRequestPermissionsResult(requestCode, permissions, grantResults)

        val permitido = grantResults.firstOrNull() == PackageManager.PERMISSION_GRANTED

        when (requestCode) {
            REQUEST_CAMERA_PERMISSION_FILE_CHOOSER -> {
                val params = arquivoSelecionadoParamsPendente
                arquivoSelecionadoParamsPendente = null

                if (permitido && params != null) {
                    abrirSeletorArquivoComPermissao(params)
                } else {
                    arquivoSelecionadoCallback?.onReceiveValue(null)
                    arquivoSelecionadoCallback = null
                }
            }
            REQUEST_CAMERA_PERMISSION_WEBVIEW -> {
                val request = permissaoCameraPendente
                permissaoCameraPendente = null

                if (permitido && request != null) {
                    val recursosPermitidos = request.resources.filter { recurso ->
                        recurso == PermissionRequest.RESOURCE_VIDEO_CAPTURE
                    }.toTypedArray()

                    if (recursosPermitidos.isNotEmpty()) {
                        request.grant(recursosPermitidos)
                    } else {
                        request.deny()
                    }
                } else {
                    request?.deny()
                }
            }
            REQUEST_NOTIFICACAO_PERMISSION -> {
                Log.d("WhyPhyLocalNotif", "permissao POST_NOTIFICATIONS concedida=$permitido")
            }
        }
    }

    @Suppress("DEPRECATION")
    override fun onBackPressed() {
        tratarVoltarFisicoAndroid()
    }

    private fun tratarArmazenamentoSeguro(
        call: MethodCall,
        result: MethodChannel.Result,
        armazenamento: ArmazenamentoSeguroWhyPhy,
    ) {
        val chave = call.argument<String>("chave")

        when (call.method) {
            "ler" -> {
                if (chave.isNullOrBlank()) {
                    result.success(null)
                    return
                }

                result.success(armazenamento.ler(chave))
            }
            "salvar" -> {
                val valor = call.argument<String>("valor")

                if (chave.isNullOrBlank() || valor == null) {
                    result.error("argumentos_invalidos", "Chave ou valor inválido.", null)
                    return
                }

                armazenamento.salvar(chave, valor)
                result.success(null)
            }
            "remover" -> {
                if (!chave.isNullOrBlank()) {
                    armazenamento.remover(chave)
                }

                result.success(null)
            }
            "limpar" -> {
                armazenamento.limpar()
                result.success(null)
            }
            else -> result.notImplemented()
        }
    }

    private companion object {
        const val REQUEST_FILE_CHOOSER = 9001
        const val REQUEST_CAMERA_PERMISSION_FILE_CHOOSER = 9002
        const val REQUEST_CAMERA_PERMISSION_WEBVIEW = 9003
        const val REQUEST_UPLOAD_NATIVO = 9004
        const val REQUEST_NOTIFICACAO_PERMISSION = 9005
        const val CANAL_NOTIFICACAO_TREINO = "WhyPhyWorkoutNotifications"
        const val CANAL_NOTIFICACAO_REFEICAO = "WhyPhyMealNotifications"
    }
}

class NotificacaoLocalWhyPhyReceiver : BroadcastReceiver() {
    override fun onReceive(context: Context, intent: Intent) {
        val canal = intent.getStringExtra("canal").orEmpty().ifBlank {
            CANAL_NOTIFICACAO_TREINO_LOCAL
        }
        val titulo = intent.getStringExtra("titulo").orEmpty().ifBlank { "WhyPhy" }
        val mensagem = intent.getStringExtra("mensagem").orEmpty().ifBlank {
            "Você tem uma atividade pendente."
        }
        val routePath = intent.getStringExtra("routePath").orEmpty()
        val id = intent.getStringExtra("id").orEmpty().ifBlank {
            "whyphy_${System.currentTimeMillis()}"
        }

        Log.d(
            "WhyPhyLocalNotif",
            "receiver disparou id=$id canal=$canal route=$routePath",
        )

        AgendadorNotificacaoLocalWhyPhy.removerPersistido(context, id)
        val notificationManager =
            context.getSystemService(Context.NOTIFICATION_SERVICE) as NotificationManager

        if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.O &&
            notificationManager.getNotificationChannel(canal) == null
        ) {
            notificationManager.createNotificationChannel(
                NotificationChannel(canal, "WhyPhy", NotificationManager.IMPORTANCE_DEFAULT),
            )
        }

        val abrirApp = Intent(context, MainActivity::class.java).apply {
            flags = Intent.FLAG_ACTIVITY_SINGLE_TOP or Intent.FLAG_ACTIVITY_CLEAR_TOP
            if (routePath.startsWith("/") && !routePath.startsWith("//")) {
                putExtra("routePath", routePath)
            }
            putExtra("title", titulo)
            putExtra("mensagem", mensagem)
        }
        val pendingIntent = PendingIntent.getActivity(
            context,
            id.hashCode(),
            abrirApp,
            PendingIntent.FLAG_UPDATE_CURRENT or PendingIntent.FLAG_IMMUTABLE,
        )
        val notification = if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.O) {
            Notification.Builder(context, canal)
        } else {
            @Suppress("DEPRECATION")
            Notification.Builder(context)
        }
            .setSmallIcon(R.mipmap.ic_launcher)
            .setContentTitle(titulo)
            .setContentText(mensagem)
            .setContentIntent(pendingIntent)
            .setAutoCancel(true)
            .build()

        notificationManager.notify(id.hashCode(), notification)
    }
}

class BootWhyPhyReceiver : BroadcastReceiver() {
    override fun onReceive(context: Context, intent: Intent) {
        if (intent.action == Intent.ACTION_BOOT_COMPLETED) {
            AgendadorNotificacaoLocalWhyPhy.reagendarPendentes(context)
        }
    }
}

private data class AgendamentoNotificacaoLocal(
    val id: String,
    val canal: String,
    val routePath: String,
    val titulo: String,
    val mensagem: String,
    val quandoMillis: Long,
) {
    fun paraJson(): JSONObject {
        return JSONObject()
            .put("id", id)
            .put("canal", canal)
            .put("routePath", routePath)
            .put("titulo", titulo)
            .put("mensagem", mensagem)
            .put("quandoMillis", quandoMillis)
    }

    companion object {
        fun deJson(payload: JSONObject): AgendamentoNotificacaoLocal? {
            val id = payload.optString("id").trim()
            val canal = payload.optString("canal").trim()
            val quandoMillis = payload.optLong("quandoMillis", 0L)

            if (id.isEmpty() || canal.isEmpty() || quandoMillis <= 0L) {
                return null
            }

            return AgendamentoNotificacaoLocal(
                id = id,
                canal = canal,
                routePath = payload.optString("routePath").trim(),
                titulo = payload.optString("titulo").ifBlank { "WhyPhy" },
                mensagem = payload.optString("mensagem").ifBlank {
                    "Você tem uma atividade pendente."
                },
                quandoMillis = quandoMillis,
            )
        }
    }
}

private object AgendadorNotificacaoLocalWhyPhy {
    fun criarCanais(context: Context) {
        if (Build.VERSION.SDK_INT < Build.VERSION_CODES.O) {
            return
        }

        val notificationManager = context.getSystemService(NotificationManager::class.java)
        val canais = listOf(
            NotificationChannel(
                CANAL_NOTIFICACAO_TREINO_LOCAL,
                "WhyPhy treinos",
                NotificationManager.IMPORTANCE_DEFAULT,
            ).apply {
                description = "Alertas locais de treino do WhyPhy."
            },
            NotificationChannel(
                CANAL_NOTIFICACAO_REFEICAO_LOCAL,
                "WhyPhy refeições",
                NotificationManager.IMPORTANCE_DEFAULT,
            ).apply {
                description = "Alertas locais de refeição do WhyPhy."
            },
        )

        canais.forEach(notificationManager::createNotificationChannel)
    }

    fun agendar(
    context: Context,
    agendamento: AgendamentoNotificacaoLocal,
    persistir: Boolean = true,
) {
    val appContext = context.applicationContext
    val pendingIntent = criarPendingIntent(
        appContext,
        agendamento,
        PendingIntent.FLAG_UPDATE_CURRENT,
    )
    val alarmManager = appContext.getSystemService(Context.ALARM_SERVICE) as AlarmManager

    Log.d(
        "WhyPhyLocalNotif",
        "agendando id=${agendamento.id} canal=${agendamento.canal} quando=${agendamento.quandoMillis} route=${agendamento.routePath}",
    )

    if (persistir && agendamento.quandoMillis > System.currentTimeMillis()) {
        salvar(appContext, agendamento)
    }

    try {
        when {
            Build.VERSION.SDK_INT >= Build.VERSION_CODES.S &&
                alarmManager.canScheduleExactAlarms() -> {
                Log.d("WhyPhyLocalNotif", "usando setExactAndAllowWhileIdle com permissão exata")

                alarmManager.setExactAndAllowWhileIdle(
                    AlarmManager.RTC_WAKEUP,
                    agendamento.quandoMillis,
                    pendingIntent,
                )
            }

            Build.VERSION.SDK_INT >= Build.VERSION_CODES.S -> {
                Log.d("WhyPhyLocalNotif", "sem permissão de alarme exato, usando setAndAllowWhileIdle")

                alarmManager.setAndAllowWhileIdle(
                    AlarmManager.RTC_WAKEUP,
                    agendamento.quandoMillis,
                    pendingIntent,
                )
            }

            Build.VERSION.SDK_INT >= Build.VERSION_CODES.M -> {
                Log.d("WhyPhyLocalNotif", "usando setExactAndAllowWhileIdle API M+")

                alarmManager.setExactAndAllowWhileIdle(
                    AlarmManager.RTC_WAKEUP,
                    agendamento.quandoMillis,
                    pendingIntent,
                )
            }

            else -> {
                Log.d("WhyPhyLocalNotif", "usando setExact API antiga")

                alarmManager.setExact(
                    AlarmManager.RTC_WAKEUP,
                    agendamento.quandoMillis,
                    pendingIntent,
                )
            }
        }
    } catch (erro: SecurityException) {
        Log.e("WhyPhyLocalNotif", "falhou alarme exato, usando fallback", erro)

        if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.M) {
            alarmManager.setAndAllowWhileIdle(
                AlarmManager.RTC_WAKEUP,
                agendamento.quandoMillis,
                pendingIntent,
            )
        } else {
            alarmManager.set(
                AlarmManager.RTC_WAKEUP,
                agendamento.quandoMillis,
                pendingIntent,
            )
        }
    }
}

    fun cancelar(context: Context, id: String) {
        val normalizado = id.trim()

        if (normalizado.isEmpty()) {
            return
        }

        Log.d("WhyPhyLocalNotif", "cancelando id=$normalizado")

        removerPersistido(context, normalizado)

        val intent = Intent(context.applicationContext, NotificacaoLocalWhyPhyReceiver::class.java)
        val pendingIntent = PendingIntent.getBroadcast(
            context.applicationContext,
            normalizado.hashCode(),
            intent,
            PendingIntent.FLAG_NO_CREATE or PendingIntent.FLAG_IMMUTABLE,
        )
        val alarmManager = context.getSystemService(Context.ALARM_SERVICE) as AlarmManager

        if (pendingIntent != null) {
            alarmManager.cancel(pendingIntent)
            pendingIntent.cancel()
        }

        val notificationManager = context.getSystemService(Context.NOTIFICATION_SERVICE) as NotificationManager
        notificationManager.cancel(normalizado.hashCode())
    }

    fun removerPersistido(context: Context, id: String) {
        val agendamentos = lerAgendamentos(context).apply {
            remove(id)
        }
        salvarAgendamentos(context, agendamentos)
    }

    fun reagendarPendentes(context: Context) {
        criarCanais(context)

        val agora = System.currentTimeMillis()
        val agendamentos = lerAgendamentos(context)
        val pendentes = linkedMapOf<String, AgendamentoNotificacaoLocal>()

        agendamentos.values.forEach { agendamento ->
            if (agendamento.quandoMillis > agora) {
                pendentes[agendamento.id] = agendamento
                agendar(context, agendamento, persistir = false)
            }
        }

        salvarAgendamentos(context, pendentes)
    }

    private fun criarPendingIntent(
        context: Context,
        agendamento: AgendamentoNotificacaoLocal,
        flagAtualizacao: Int,
    ): PendingIntent {
        val intent = Intent(context, NotificacaoLocalWhyPhyReceiver::class.java).apply {
            putExtra("id", agendamento.id)
            putExtra("canal", agendamento.canal)
            putExtra("routePath", agendamento.routePath)
            putExtra("titulo", agendamento.titulo)
            putExtra("mensagem", agendamento.mensagem)
        }

        return PendingIntent.getBroadcast(
            context,
            agendamento.id.hashCode(),
            intent,
            flagAtualizacao or PendingIntent.FLAG_IMMUTABLE,
        )
    }

    private fun salvar(context: Context, agendamento: AgendamentoNotificacaoLocal) {
        val agendamentos = lerAgendamentos(context).apply {
            put(agendamento.id, agendamento)
        }
        salvarAgendamentos(context, agendamentos)
    }

    private fun lerAgendamentos(context: Context): MutableMap<String, AgendamentoNotificacaoLocal> {
        val raw = preferencias(context).getString(PREFS_AGENDAMENTOS_NOTIFICACAO, "{}").orEmpty()
        val json = try {
            JSONObject(raw)
        } catch (erro: Exception) {
            JSONObject()
        }
        val agendamentos = linkedMapOf<String, AgendamentoNotificacaoLocal>()
        val keys = json.keys()

        while (keys.hasNext()) {
            val key = keys.next()
            val agendamento = json.optJSONObject(key)?.let(AgendamentoNotificacaoLocal::deJson)

            if (agendamento != null) {
                agendamentos[agendamento.id] = agendamento
            }
        }

        return agendamentos
    }

    private fun salvarAgendamentos(
        context: Context,
        agendamentos: Map<String, AgendamentoNotificacaoLocal>,
    ) {
        val json = JSONObject()

        agendamentos.forEach { (id, agendamento) ->
            json.put(id, agendamento.paraJson())
        }

        preferencias(context)
            .edit()
            .putString(PREFS_AGENDAMENTOS_NOTIFICACAO, json.toString())
            .apply()
    }

    private fun preferencias(context: Context) =
        context.applicationContext.getSharedPreferences(PREFS_NOTIFICACOES_LOCAIS, Context.MODE_PRIVATE)
}

private class ArmazenamentoSeguroWhyPhy(context: Context) {
    private val preferencias = context.getSharedPreferences(
        "whyphy_secure_storage",
        Context.MODE_PRIVATE,
    )
    private val keyStore = KeyStore.getInstance("AndroidKeyStore").apply {
        load(null)
    }

    fun ler(chave: String): String? {
        val payload = preferencias.getString(chave, null) ?: return null
        val parts = payload.split(":", limit = 2)

        if (parts.size != 2) {
            return null
        }

        val iv = Base64.decode(parts[0], Base64.NO_WRAP)
        val criptografado = Base64.decode(parts[1], Base64.NO_WRAP)
        val cipher = Cipher.getInstance("AES/GCM/NoPadding")
        cipher.init(Cipher.DECRYPT_MODE, obterChave(), GCMParameterSpec(128, iv))

        return String(cipher.doFinal(criptografado), Charsets.UTF_8)
    }

    fun salvar(chave: String, valor: String) {
        val cipher = Cipher.getInstance("AES/GCM/NoPadding")
        cipher.init(Cipher.ENCRYPT_MODE, obterChave())
        val criptografado = cipher.doFinal(valor.toByteArray(Charsets.UTF_8))
        val payload = "${Base64.encodeToString(cipher.iv, Base64.NO_WRAP)}:" +
            Base64.encodeToString(criptografado, Base64.NO_WRAP)

        preferencias.edit().putString(chave, payload).apply()
    }

    fun remover(chave: String) {
        preferencias.edit().remove(chave).apply()
    }

    fun limpar() {
        preferencias.edit().clear().apply()
    }

    private fun obterChave(): SecretKey {
        val entrada = keyStore.getEntry(KEY_ALIAS, null) as? KeyStore.SecretKeyEntry

        if (entrada != null) {
            return entrada.secretKey
        }

        val keyGenerator = KeyGenerator.getInstance(
            KeyProperties.KEY_ALGORITHM_AES,
            "AndroidKeyStore",
        )
        val keySpec = KeyGenParameterSpec.Builder(
            KEY_ALIAS,
            KeyProperties.PURPOSE_ENCRYPT or KeyProperties.PURPOSE_DECRYPT,
        )
            .setBlockModes(KeyProperties.BLOCK_MODE_GCM)
            .setEncryptionPaddings(KeyProperties.ENCRYPTION_PADDING_NONE)
            .setRandomizedEncryptionRequired(true)
            .build()

        keyGenerator.init(keySpec)
        return keyGenerator.generateKey()
    }

    private companion object {
        const val KEY_ALIAS = "whyphy_secure_storage_key"
    }
}

private class WebViewWhyPhyFactory(
    private val activity: MainActivity,
    private val canalEventosWebview: MethodChannel,
    private val gerenciadorPopups: GerenciadorPopupsWebview,
    private val gerenciadorDownloads: GerenciadorDownloadsWebview,
) : PlatformViewFactory(StandardMessageCodec.INSTANCE) {
    override fun create(context: Context, viewId: Int, args: Any?): PlatformView {
        val params = args as? Map<*, *> ?: emptyMap<String, Any?>()
        return WebViewWhyPhy(
            context,
            params,
            activity,
            canalEventosWebview,
            gerenciadorPopups,
            gerenciadorDownloads,
        )
    }
}

private class WebViewWhyPhy(
    context: Context,
    params: Map<*, *>,
    private val activity: MainActivity,
    private val canalEventosWebview: MethodChannel,
    private val gerenciadorPopups: GerenciadorPopupsWebview,
    private val gerenciadorDownloads: GerenciadorDownloadsWebview,
) : PlatformView {
    private val webView = WebView(context)
    private val url = params["url"] as? String ?: "about:blank"
    private val allowedHost = params["allowedHost"] as? String ?: Uri.parse(url).host.orEmpty()
    private val metricasWebviewJson = JSONObject().apply {
        put("safeAreaBottom", lerParametroNumero(params, "safeAreaBottom"))
        put("screenHeight", lerParametroNumero(params, "screenHeight"))
        put("viewportHeight", lerParametroNumero(params, "viewportHeight"))
    }.toString()
    private val initialHeaders = ((params["initialHeaders"] as? Map<*, *>) ?: emptyMap<Any?, Any?>())
        .entries
        .mapNotNull { entry ->
            val key = entry.key as? String
            val value = entry.value as? String
            if (key.isNullOrBlank() || value == null) {
                null
            } else {
                key to value
            }
        }
        .toMap()
    private var logoutNotificado = false
    private var logoutVisualOcultado = false

    init {
        activity.registrarWebViewAtiva(webView, allowedHost, initialHeaders)
        configurarWebView()
        webView.loadUrl(url, initialHeaders)
    }

    override fun getView(): View {
        return webView
    }

    override fun dispose() {
        gerenciadorPopups.cancelarTodos()
        activity.limparWebViewAtiva(webView)
        webView.destroy()
    }

    private fun configurarWebView() {
        webView.setLayerType(View.LAYER_TYPE_HARDWARE, null)
        webView.setBackgroundColor(Color.BLACK)
        webView.isVerticalScrollBarEnabled = false
        webView.isHorizontalScrollBarEnabled = false
        webView.overScrollMode = View.OVER_SCROLL_NEVER
        webView.settings.apply {
            javaScriptEnabled = true
            domStorageEnabled = true
            databaseEnabled = true
            cacheMode = WebSettings.LOAD_DEFAULT
            loadsImagesAutomatically = true
            blockNetworkImage = false
            useWideViewPort = true
            loadWithOverviewMode = true
            builtInZoomControls = false
            displayZoomControls = false
            textZoom = 100
            mediaPlaybackRequiresUserGesture = false
            setSupportMultipleWindows(false)
        }
        webView.addJavascriptInterface(
            BridgeWhyPhyApp(
                webView.context,
                canalEventosWebview,
                gerenciadorDownloads,
                initialHeaders,
            ) {
                ocultarWebViewParaLogout()
            },
            "WhyPhyApp",
        )
        webView.setDownloadListener { downloadUrl, userAgent, contentDisposition, mimeType, _ ->
            gerenciadorDownloads.baixarUrl(
                url = downloadUrl,
                nomeArquivo = URLUtil.guessFileName(downloadUrl, contentDisposition, mimeType),
                mimeType = mimeType.orEmpty(),
                headers = initialHeaders,
            )
        }
        webView.webChromeClient = object : WebChromeClient() {
            override fun onShowFileChooser(
                webView: WebView,
                filePathCallback: ValueCallback<Array<Uri>>,
                fileChooserParams: FileChooserParams,
            ): Boolean {
                return activity.abrirSeletorArquivo(filePathCallback, fileChooserParams)
            }

            override fun onPermissionRequest(request: PermissionRequest) {
                activity.runOnUiThread {
                    activity.solicitarPermissaoWebview(request)
                }
            }

            override fun onJsAlert(
                view: WebView,
                url: String,
                message: String?,
                result: JsResult,
            ): Boolean {
                gerenciadorPopups.registrar(
                    tipo = "alerta",
                    mensagem = message.orEmpty(),
                    textoPadrao = null,
                    resultado = result,
                )
                return true
            }

            override fun onJsConfirm(
                view: WebView,
                url: String,
                message: String?,
                result: JsResult,
            ): Boolean {
                gerenciadorPopups.registrar(
                    tipo = "confirmacao",
                    mensagem = message.orEmpty(),
                    textoPadrao = null,
                    resultado = result,
                )
                return true
            }

            override fun onJsPrompt(
                view: WebView,
                url: String,
                message: String?,
                defaultValue: String?,
                result: JsPromptResult,
            ): Boolean {
                gerenciadorPopups.registrarPrompt(
                    mensagem = message.orEmpty(),
                    textoPadrao = defaultValue.orEmpty(),
                    resultado = result,
                )
                return true
            }
        }
        webView.webViewClient = object : WebViewClient() {
            override fun onPageStarted(view: WebView, url: String, favicon: android.graphics.Bitmap?) {
                super.onPageStarted(view, url, favicon)
                notificarCarregamento(iniciado = true)
                notificarLogoutSeNecessario(Uri.parse(url))
            }

            override fun onPageFinished(view: WebView, url: String) {
                super.onPageFinished(view, url)
                injetarMetricasWebviewFlutter(view)
                injetarAjustesDeInputArquivo(view)
                injetarInterceptadorLogout(view)
                injetarInterceptadorDownloads(view)
                injetarInterceptadorDeAvisos(view)
                injetarInterceptadorWorkNativo(view)
                notificarCarregamento(iniciado = false)
                injetarBridgeNotificacoesLocais(view)
            }

            override fun doUpdateVisitedHistory(view: WebView, url: String, isReload: Boolean) {
                super.doUpdateVisitedHistory(view, url, isReload)
                notificarLogoutSeNecessario(Uri.parse(url))
            }

            override fun shouldOverrideUrlLoading(
                view: WebView,
                request: WebResourceRequest,
            ): Boolean {
                return tratarNavegacao(view.context, request.url)
            }

            @Suppress("DEPRECATION", "OVERRIDE_DEPRECATION")
            override fun shouldOverrideUrlLoading(view: WebView, url: String): Boolean {
                return tratarNavegacao(view.context, Uri.parse(url))
            }

            override fun onReceivedError(
                view: WebView,
                request: WebResourceRequest,
                error: WebResourceError,
            ) {
                super.onReceivedError(view, request, error)

                if (!request.isForMainFrame) {
                    return
                }

                canalEventosWebview.invokeMethod(
                    "erroWebview",
                    mapOf(
                        "tipo" to "offline",
                        "mensagem" to "Verifique sua conexão e tente carregar o WhyPhy novamente.",
                    ),
                )
            }

            override fun onReceivedHttpError(
                view: WebView,
                request: WebResourceRequest,
                errorResponse: WebResourceResponse,
            ) {
                super.onReceivedHttpError(view, request, errorResponse)

                if (!request.isForMainFrame) {
                    return
                }

                val status = errorResponse.statusCode

                if (status == 401 || status == 403) {
                    canalEventosWebview.invokeMethod("sessaoExpiradaWebview", emptyMap<String, String>())
                    return
                }

                if (status >= 500) {
                    canalEventosWebview.invokeMethod(
                        "erroWebview",
                        mapOf(
                            "tipo" to "servidor",
                            "mensagem" to "O WhyPhy não respondeu agora. Tente novamente em instantes.",
                        ),
                    )
                }
            }
        }
    }

    private fun lerParametroNumero(params: Map<*, *>, nome: String): Double {
        return when (val valor = params[nome]) {
            is Number -> valor.toDouble()
            is String -> valor.toDoubleOrNull() ?: 0.0
            else -> 0.0
        }
    }

    private fun injetarMetricasWebviewFlutter(view: WebView) {
        val script = """
            (function() {
              var metricas = $metricasWebviewJson;
              var root = document.documentElement;
              if (!root || !metricas) return;
              var safeBottom = Math.max(Number(metricas.safeAreaBottom) || 0, 0);
              root.style.setProperty("--flutter-safe-bottom", safeBottom + "px");
              window.__whyphyViewportInfo = metricas;
              window.dispatchEvent(new CustomEvent("whyphy:flutter-viewport", { detail: metricas }));
            })();
        """.trimIndent()

        view.evaluateJavascript(script, null)
    }

    private fun tratarNavegacao(context: Context, uri: Uri): Boolean {
        if (notificarLogoutSeNecessario(uri)) {
            return true
        }

        if (uri.scheme.orEmpty() == "blob" || uri.scheme.orEmpty() == "data") {
            return true
        }

        if (deveBaixarNaWebView(uri)) {
            gerenciadorDownloads.baixarUrl(
                url = uri.toString(),
                nomeArquivo = nomeDownloadParaUri(uri),
                mimeType = mimeParaUri(uri),
                headers = initialHeaders,
            )
            return true
        }

        if (hostPermitido(uri.host.orEmpty()) &&
            ehRotaWork(uri) &&
            uri.getQueryParameter("native_sync") != "1"
        ) {
            canalEventosWebview.invokeMethod(
                "workNativoAbrirRota",
                mapOf("routePath" to routePathParaUri(uri)),
            )
            return true
        }

        if (hostPermitido(uri.host.orEmpty())) {
            return false
        }

        val scheme = uri.scheme.orEmpty()
        val podeAbrirFora = scheme == "http" ||
            scheme == "https" ||
            scheme == "mailto" ||
            scheme == "tel"

        if (podeAbrirFora) {
            abrirForaDaWebView(context, uri)
        }

        return true
    }

    private fun deveBaixarNaWebView(uri: Uri): Boolean {
        val path = uri.path.orEmpty().lowercase(Locale.ROOT)
        return path.endsWith(".pdf")
    }

    private fun ehRotaWork(uri: Uri): Boolean {
        val path = uri.path.orEmpty().lowercase(Locale.ROOT)
        return path == "/work" || path.startsWith("/work/")
    }

    private fun routePathParaUri(uri: Uri): String {
        val query = uri.encodedQuery?.let { "?$it" }.orEmpty()
        val fragment = uri.encodedFragment?.let { "#$it" }.orEmpty()
        return "${uri.path.orEmpty()}$query$fragment"
    }

    private fun nomeDownloadParaUri(uri: Uri): String {
        val ultimoSegmento = uri.lastPathSegment

        if (!ultimoSegmento.isNullOrBlank() && ultimoSegmento.contains(".")) {
            return ultimoSegmento
        }

        return if (uri.path.orEmpty().lowercase(Locale.ROOT).endsWith(".pdf")) {
            "whyphy-documento.pdf"
        } else {
            "whyphy-arquivo"
        }
    }

    private fun mimeParaUri(uri: Uri): String {
        return if (uri.path.orEmpty().lowercase(Locale.ROOT).endsWith(".pdf")) {
            "application/pdf"
        } else {
            "application/octet-stream"
        }
    }

    private fun abrirForaDaWebView(context: Context, uri: Uri) {
        try {
            context.startActivity(Intent(Intent.ACTION_VIEW, uri))
        } catch (erro: Exception) {
            return
        }
    }

    private fun hostPermitido(host: String): Boolean {
        if (host == allowedHost) {
            return true
        }

        val dominioPrincipal = "whyphy.com.br"
        val ambienteWhyPhy = allowedHost == dominioPrincipal ||
            allowedHost.endsWith(".$dominioPrincipal")

        return ambienteWhyPhy &&
            (host == dominioPrincipal || host.endsWith(".$dominioPrincipal"))
    }

    private fun notificarLogoutSeNecessario(uri: Uri): Boolean {
        if (logoutNotificado || !ehRotaLogout(uri)) {
            return false
        }

        logoutNotificado = true
        ocultarWebViewParaLogout()
        canalEventosWebview.invokeMethod(
            "logoutDetectado",
            mapOf("url" to uri.toString()),
        )

        return true
    }

    private fun ocultarWebViewParaLogout() {
        if (logoutVisualOcultado) {
            return
        }

        logoutVisualOcultado = true
        webView.setBackgroundColor(Color.BLACK)
        webView.isClickable = false
        webView.isFocusable = false
        webView.animate()
            .alpha(0f)
            .setDuration(140)
            .withEndAction {
                webView.visibility = View.INVISIBLE
            }
            .start()
    }

    private fun notificarMensagemWeb(mensagem: String) {
        val texto = mensagem.trim()

        if (texto.isEmpty()) {
            return
        }

        canalEventosWebview.invokeMethod(
            "notificacaoWeb",
            mapOf("mensagem" to texto.take(180)),
        )
    }

    private fun notificarCarregamento(iniciado: Boolean) {
        canalEventosWebview.invokeMethod(
            if (iniciado) "carregamentoWebviewIniciado" else "carregamentoWebviewConcluido",
            null,
        )
    }

    private fun injetarAjustesDeInputArquivo(view: WebView) {
        val script = """
            (function() {
              if (window.__whyphyAppFileInputObserver) return;
              window.__whyphyAppFileInputObserver = true;
              function prepararInput(input) {
                if (!input || input.dataset.whyphyAppFileReady === "1") return;
                input.dataset.whyphyAppFileReady = "1";
                var label = input.closest && input.closest("label");
                if (!label) return;
                label.style.position = label.style.position || "relative";
                label.style.overflow = "hidden";
                input.style.setProperty("display", "block", "important");
                input.style.position = "absolute";
                input.style.inset = "0";
                input.style.width = "100%";
                input.style.height = "100%";
                input.style.opacity = "0";
                input.style.zIndex = "20";
                input.style.cursor = "pointer";
              }
              function varrerArquivos(raiz) {
                if (!raiz) return;
                if (raiz.matches && raiz.matches("input[type='file']")) prepararInput(raiz);
                if (!raiz.querySelectorAll) return;
                raiz.querySelectorAll("input[type='file']").forEach(prepararInput);
              }
              varrerArquivos(document);
              new MutationObserver(function(mudancas) {
                mudancas.forEach(function(mudanca) {
                  mudanca.addedNodes.forEach(varrerArquivos);
                });
              }).observe(document.documentElement, { childList: true, subtree: true });
            })();
        """.trimIndent()

        view.evaluateJavascript(script, null)
    }

    private fun injetarInterceptadorLogout(view: WebView) {
        val script = """
            (function() {
              if (window.__whyphyAppLogoutObserver) return;
              window.__whyphyAppLogoutObserver = true;
              function normalizarUrl(url) {
                try {
                  return new URL(String(url), window.location.origin).pathname;
                } catch (erro) {
                  return String(url || "");
                }
              }
              function ehLogout(url) {
                var path = normalizarUrl(url);
                return path === "/logout" ||
                  path === "/api/auth/logout" ||
                  path === "/api/mobile/auth/logout" ||
                  path === "/api/auth/force-logout";
              }
              function notificarLogout() {
                if (window.WhyPhyApp && window.WhyPhyApp.logoutDetectado) {
                  window.WhyPhyApp.logoutDetectado(window.location.href);
                }
              }
              var fetchOriginal = window.fetch;
              if (fetchOriginal) {
                window.fetch = function(input, init) {
                  var url = typeof input === "string" ? input : input && input.url;
                  var deveNotificar = ehLogout(url);
                  var resposta = fetchOriginal.apply(this, arguments);
                  if (deveNotificar && resposta && resposta.finally) {
                    resposta.finally(function() { window.setTimeout(notificarLogout, 0); });
                  }
                  return resposta;
                };
              }
              var abrirOriginal = XMLHttpRequest.prototype.open;
              var enviarOriginal = XMLHttpRequest.prototype.send;
              XMLHttpRequest.prototype.open = function(method, url) {
                this.__whyphyAppLogout = ehLogout(url);
                return abrirOriginal.apply(this, arguments);
              };
              XMLHttpRequest.prototype.send = function() {
                if (this.__whyphyAppLogout) {
                  this.addEventListener("loadend", function() {
                    window.setTimeout(notificarLogout, 0);
                  }, { once: true });
                }
                return enviarOriginal.apply(this, arguments);
              };
              document.addEventListener("click", function(evento) {
                var alvo = evento.target && evento.target.closest && evento.target.closest("a[href]");
                if (alvo && ehLogout(alvo.getAttribute("href"))) {
                  window.setTimeout(notificarLogout, 0);
                }
              }, true);
            })();
        """.trimIndent()

        view.evaluateJavascript(script, null)
    }

    private fun injetarInterceptadorDownloads(view: WebView) {
        val script = """
            (function() {
              if (window.__whyphyAppDownloadObserver) return;
              window.__whyphyAppDownloadObserver = true;
              window.__whyphyAppUltimoDownloadEm = 0;

              function moduloAtual() {
                var path = "";
                try {
                  path = String(window.location.pathname || "").toLowerCase();
                } catch (erro) {}
                if (path.indexOf("/work") === 0 || path.indexOf("/treino") >= 0) return "treinos";
                if (path.indexOf("/dieta") >= 0) return "dieta";
                if (path.indexOf("/evolucao") >= 0 || path.indexOf("/evolucoes") >= 0) return "evolucao";
                return "";
              }

              function notificar(mensagem) {
                var modulo = moduloAtual();
                if (window.WhyPhyApp && window.WhyPhyApp.notificarContexto) {
                  window.WhyPhyApp.notificarContexto(mensagem, modulo);
                  return;
                }
                if (window.WhyPhyApp && window.WhyPhyApp.notificar) {
                  window.WhyPhyApp.notificar(mensagem);
                }
              }

              function nomeSeguro(nome, fallback) {
                var valor = String(nome || "").trim();
                return valor.length > 0 ? valor : fallback;
              }

              function origemPdfDoHtml(html) {
                var origem = "";
                try {
                  var texto = String(html || "");
                  var body = texto.match(/<body[^>]*class=["']([^"']+)["']/i);
                  if (body && body[1]) {
                    origem = body[1].split(/\s+/)[0] || "";
                  }
                  if (!origem) {
                    var h1 = texto.match(/<h1[^>]*>(.*?)<\/h1>/i);
                    if (h1 && h1[1]) {
                      origem = h1[1].replace(/<[^>]+>/g, " ");
                    }
                  }
                } catch (erro) {}
                origem = String(origem || "whyphy").toLowerCase()
                  .normalize("NFD")
                  .replace(/[\u0300-\u036f]/g, "")
                  .replace(/[^a-z0-9]+/g, "_")
                  .replace(/^_+|_+$/g, "");
                if (origem.indexOf("dieta") >= 0) return "dieta";
                if (origem.indexOf("treino") >= 0) return "treino";
                if (origem.indexOf("consulta") >= 0) return "consulta";
                if (origem.indexOf("fisioterapia") >= 0) return "fisioterapia";
                return origem || "whyphy";
              }

              function dataHoraArquivo() {
                var agora = new Date();
                function dois(valor) {
                  return String(valor).padStart(2, "0");
                }
                return agora.getFullYear() + "-" +
                  dois(agora.getMonth() + 1) + "-" +
                  dois(agora.getDate()) + "_" +
                  dois(agora.getHours()) + "-" +
                  dois(agora.getMinutes());
              }

              function nomePdfDoHtml(html) {
                return origemPdfDoHtml(html) + "_" + dataHoraArquivo() + ".pdf";
              }

              function salvarBase64(nome, mime, base64) {
                window.__whyphyAppUltimoDownloadEm = Date.now();
                if (window.WhyPhyApp && window.WhyPhyApp.salvarArquivoBase64) {
                  window.WhyPhyApp.salvarArquivoBase64(
                    nomeSeguro(nome, "whyphy-arquivo"),
                    mime || "application/octet-stream",
                    base64 || ""
                  );
                  return true;
                }
                return false;
              }

              function salvarBlob(blob, nome) {
                return new Promise(function(resolve) {
                  if (!blob) {
                    resolve(false);
                    return;
                  }
                  var leitor = new FileReader();
                  leitor.onloadend = function() {
                    var resultado = String(leitor.result || "");
                    var base64 = resultado.indexOf(",") >= 0 ? resultado.split(",").pop() : resultado;
                    resolve(salvarBase64(nome, blob.type || "application/octet-stream", base64));
                  };
                  leitor.onerror = function() { resolve(false); };
                  leitor.readAsDataURL(blob);
                });
              }

              function compartilharBlob(blob, dados, nome) {
                return new Promise(function(resolve) {
                  if (!blob || !window.WhyPhyApp || !window.WhyPhyApp.compartilharArquivoBase64) {
                    resolve(false);
                    return;
                  }
                  var leitor = new FileReader();
                  leitor.onloadend = function() {
                    var resultado = String(leitor.result || "");
                    var base64 = resultado.indexOf(",") >= 0 ? resultado.split(",").pop() : resultado;
                    window.WhyPhyApp.compartilharArquivoBase64(
                      nomeSeguro(nome, "whyphy-compartilhar.png"),
                      blob.type || "image/png",
                      base64 || "",
                      String((dados && dados.text) || ""),
                      String((dados && dados.title) || "Compartilhar imagem WhyPhy"),
                      moduloAtual()
                    );
                    resolve(true);
                  };
                  leitor.onerror = function() { resolve(false); };
                  leitor.readAsDataURL(blob);
                });
              }

              function salvarUrlInterna(url, nome) {
                if (!url) return false;
                var texto = String(url);
                if (texto.indexOf("data:") === 0) {
                  try {
                    var partes = texto.split(",");
                    var cabecalho = partes.shift() || "";
                    var base64 = partes.join(",");
                    var mime = (cabecalho.match(/^data:([^;]+)/) || [])[1] || "application/octet-stream";
                    return salvarBase64(nomeSeguro(nome, "whyphy-arquivo"), mime, base64);
                  } catch (erro) {
                    return false;
                  }
                }
                if (texto.indexOf("blob:") === 0) {
                  fetch(texto).then(function(resposta) {
                    return resposta.blob();
                  }).then(function(blob) {
                    return salvarBlob(blob, nomeSeguro(nome, "whyphy-compartilhar.png"));
                  }).catch(function() {
                    notificar("Não foi possível salvar o arquivo gerado.");
                  });
                  return true;
                }
                if (/\.pdf(\?|#|$)/i.test(texto) && window.WhyPhyApp && window.WhyPhyApp.baixarUrl) {
                  window.__whyphyAppUltimoDownloadEm = Date.now();
                  window.WhyPhyApp.baixarUrl(texto, nomeSeguro(nome, "whyphy-documento.pdf"), "application/pdf");
                  return true;
                }
                return false;
              }

              var clickOriginal = HTMLAnchorElement.prototype.click;
              HTMLAnchorElement.prototype.click = function() {
                var nome = this.getAttribute("download") || "";
                if (salvarUrlInterna(this.href, nome)) return;
                return clickOriginal.apply(this, arguments);
              };

              document.addEventListener("click", function(evento) {
                var alvo = evento.target && evento.target.closest && evento.target.closest("a[href]");
                if (!alvo) return;
                var nome = alvo.getAttribute("download") || "";
                if (nome || /^blob:|^data:|\.pdf(\?|#|$)/i.test(alvo.href || "")) {
                  if (salvarUrlInterna(alvo.href, nome)) {
                    evento.preventDefault();
                    evento.stopPropagation();
                  }
                }
              }, true);

              function temArquivoCompartilhavel(dados) {
                return !!(
                  dados &&
                  dados.files &&
                  dados.files.length > 0 &&
                  dados.files[0]
                );
              }

              function definirMetodoNavigator(nome, metodo) {
                try {
                  Object.defineProperty(navigator, nome, {
                    configurable: true,
                    value: metodo
                  });
                  return;
                } catch (erro) {}
                try {
                  navigator[nome] = metodo;
                } catch (erro) {}
              }

              var canShareOriginal = navigator.canShare;
              definirMetodoNavigator("canShare", function(dados) {
                if (temArquivoCompartilhavel(dados)) {
                  return true;
                }
                if (typeof canShareOriginal === "function") {
                  return canShareOriginal.apply(navigator, arguments);
                }
                return false;
              });

              var shareOriginal = navigator.share;
              definirMetodoNavigator("share", function(dados) {
                var arquivo = dados && dados.files && dados.files[0];
                if (arquivo) {
                  return compartilharBlob(arquivo, dados, arquivo.name || "whyphy-compartilhar.png").then(function(compartilhou) {
                    if (compartilhou) return;
                    return salvarBlob(arquivo, arquivo.name || "whyphy-compartilhar.png").then(function(salvou) {
                      if (salvou) return;
                      if (typeof shareOriginal === "function") {
                        return shareOriginal.apply(navigator, [dados]);
                      }
                    });
                  }).catch(function() {
                    if (typeof shareOriginal === "function") {
                      return shareOriginal.apply(navigator, [dados]);
                    }
                  });
                }
                if (typeof shareOriginal === "function") {
                  return shareOriginal.apply(navigator, arguments);
                }
                return Promise.reject(new Error("Compartilhamento indisponivel."));
              });

              var openOriginal = window.open;
              window.open = function(url) {
                var destino = String(url || "");
                if (!destino) {
                  var partes = [];
                  return {
                    close: function() {},
                    focus: function() {},
                    document: {
                      open: function() { partes = []; },
                      write: function(html) { partes.push(String(html || "")); },
                      close: function() {
                        var html = partes.join("");
                        if (window.WhyPhyApp && window.WhyPhyApp.salvarPdfHtml) {
                          window.__whyphyAppUltimoDownloadEm = Date.now();
                          window.WhyPhyApp.salvarPdfHtml(nomePdfDoHtml(html), html);
                        }
                      }
                    }
                  };
                }
                if (salvarUrlInterna(destino, "")) return null;
                var recente = Date.now() - (window.__whyphyAppUltimoDownloadEm || 0) < 4000;
                if (recente && /facebook\.com\/sharer|instagram\.com|wa\.me/i.test(destino)) {
                  notificar("Arquivo salvo no dispositivo para compartilhamento manual.");
                  return null;
                }
                return openOriginal.apply(window, arguments);
              };
            })();
        """.trimIndent()

        view.evaluateJavascript(script, null)
    }

    private fun injetarInterceptadorDeAvisos(view: WebView) {
        val script = """
            (function() {
              if (window.__whyphyAppToastObserver) return;
              window.__whyphyAppToastObserver = true;
              var ultimoAviso = "";
              var ultimoAvisoEm = 0;
              function moduloAtual() {
                var path = "";
                try {
                  path = String(window.location.pathname || "").toLowerCase();
                } catch (erro) {}
                if (path.indexOf("/work") === 0 || path.indexOf("/treino") >= 0) return "treinos";
                if (path.indexOf("/dieta") >= 0) return "dieta";
                if (path.indexOf("/evolucao") >= 0 || path.indexOf("/evolucoes") >= 0) return "evolucao";
                return "";
              }
              function textoValido(texto) {
                return (texto || "").replace(/\s+/g, " ").trim();
              }
              function classeContem(no, trecho) {
                return no && no.className && String(no.className).indexOf(trecho) !== -1;
              }
              function elementoDeAviso(no) {
                if (!no || no.nodeType !== 1) return false;
                if (no.matches && (
                  no.matches("[data-sonner-toast]") ||
                  no.matches("[role='status']") ||
                  no.matches("[role='alert']") ||
                  no.matches(".sonner, [class*='sonner']")
                )) return true;
                if (
                  no.closest &&
                  no.closest("[data-help='users-evolucao-modal-foto-fisica']") &&
                  (classeContem(no, "border-emerald-500") || classeContem(no, "border-red-500"))
                ) return true;
                return false;
              }
              function coletarTexto(no) {
                if (!no || no.nodeType !== 1) return "";
                if (elementoDeAviso(no)) return textoValido(no.innerText);
                var alvo = no.querySelector && no.querySelector(
                  "[data-sonner-toast], [role='status'], [role='alert'], .sonner, [class*='sonner']"
                );
                return alvo ? textoValido(alvo.innerText) : "";
              }
              function enviar(no) {
                var texto = coletarTexto(no);
                var agora = Date.now();
                if (!texto || (texto === ultimoAviso && agora - ultimoAvisoEm < 2500)) return;
                ultimoAviso = texto;
                ultimoAvisoEm = agora;
                if (window.WhyPhyApp && window.WhyPhyApp.notificarContexto) {
                  window.WhyPhyApp.notificarContexto(texto.slice(0, 180), moduloAtual());
                  return;
                }
                if (window.WhyPhyApp && window.WhyPhyApp.notificar) {
                  window.WhyPhyApp.notificar(texto.slice(0, 180));
                }
              }
              function varrerAvisos() {
                [
                  "[data-sonner-toast]",
                  "[role='status']",
                  "[role='alert']",
                  ".sonner",
                  "[class*='sonner']",
                  "[data-help='users-evolucao-modal-foto-fisica'] [class*='border-emerald-500']",
                  "[data-help='users-evolucao-modal-foto-fisica'] [class*='border-red-500']"
                ].forEach(function(seletor) {
                  document.querySelectorAll(seletor).forEach(enviar);
                });
              }
              new MutationObserver(function(mudancas) {
                mudancas.forEach(function(mudanca) {
                  mudanca.addedNodes.forEach(enviar);
                  if (mudanca.target && mudanca.target.nodeType === 1) enviar(mudanca.target);
                  if (mudanca.target && mudanca.target.parentElement) enviar(mudanca.target.parentElement);
                });
              }).observe(document.documentElement, {
                attributes: true,
                characterData: true,
                childList: true,
                subtree: true
              });
              setTimeout(varrerAvisos, 250);
            })();
        """.trimIndent()

        view.evaluateJavascript(script, null)
    }

    private fun injetarInterceptadorWorkNativo(view: WebView) {
        val script = """
            (function() {
              if (window.__whyphyWorkNativeRouteBridge) return;
              window.__whyphyWorkNativeRouteBridge = true;

              function ehRotaWork(url) {
                try {
                  var destino = new URL(String(url || ""), window.location.href);
                  return destino.pathname === "/work" || destino.pathname.indexOf("/work/") === 0;
                } catch (_) {
                  return false;
                }
              }

              function routePath(url) {
                var destino = new URL(String(url || ""), window.location.href);
                return destino.pathname + destino.search + destino.hash;
              }

              function abrirWork(url) {
                if (!window.WhyPhyApp || !window.WhyPhyApp.abrirWorkNativoPorRota) return;
                window.WhyPhyApp.abrirWorkNativoPorRota(routePath(url || "/work"));
              }

              document.addEventListener("click", function(event) {
                var alvo = event.target && event.target.closest ? event.target.closest("a[href]") : null;
                if (!alvo || !ehRotaWork(alvo.href)) return;
                event.preventDefault();
                event.stopPropagation();
                abrirWork(alvo.href);
              }, true);
            })();
        """.trimIndent()

        view.evaluateJavascript(script, null)
    }

    private fun injetarBridgeNotificacoesLocais(view: WebView) {
        val script = """
            (function() {
              if (window.__whyphyAppLocalNotificationBridge) return;
              window.__whyphyAppLocalNotificationBridge = true;

              function enviarParaApp(payload) {
                try {
                  var texto = typeof payload === "string"
                    ? payload
                    : JSON.stringify(payload || {});

                  if (window.WhyPhyApp && window.WhyPhyApp.agendarNotificacaoLocal) {
                    window.WhyPhyApp.agendarNotificacaoLocal(texto);
                    return true;
                  }
                } catch (erro) {}
                return false;
              }

              function cancelarNoApp(id) {
                try {
                  if (window.WhyPhyApp && window.WhyPhyApp.cancelarNotificacaoLocal) {
                    window.WhyPhyApp.cancelarNotificacaoLocal(String(id || ""));
                    return true;
                  }
                } catch (erro) {}
                return false;
              }

              window.WhyPhyWorkoutNotifications = window.WhyPhyWorkoutNotifications || {};
              window.WhyPhyMealNotifications = window.WhyPhyMealNotifications || {};

              window.WhyPhyWorkoutNotifications.postMessage = function(payload) {
                return enviarParaApp(payload);
              };

              window.WhyPhyMealNotifications.postMessage = function(payload) {
                return enviarParaApp(payload);
              };

              window.WhyPhyWorkoutNotifications.cancel = function(id) {
                return cancelarNoApp(id);
              };

              window.WhyPhyMealNotifications.cancel = function(id) {
                return cancelarNoApp(id);
              };
            })();
        """.trimIndent()

        view.evaluateJavascript(script, null)
    }

    private fun ehRotaLogout(uri: Uri): Boolean {
        if (!hostPermitido(uri.host.orEmpty())) {
            return false
        }

        val path = uri.path.orEmpty()

        return path == "/login" ||
            path == "/logout" ||
            path == "/api/auth/logout" ||
            path == "/api/auth/force-logout"
    }
}

private class BridgeWhyPhyApp(
    private val context: Context,
    private val canalEventosWebview: MethodChannel,
    private val gerenciadorDownloads: GerenciadorDownloadsWebview,
    private val headers: Map<String, String>,
    private val aoLogoutDetectado: () -> Unit,
) {
    private val mainHandler = Handler(Looper.getMainLooper())

    @JavascriptInterface
    fun notificar(mensagem: String) {
        notificarContexto(mensagem, "")
    }

    @JavascriptInterface
    fun notificarContexto(mensagem: String, modulo: String) {
        val texto = mensagem.trim()
        val moduloNormalizado = modulo.trim()

        if (texto.isEmpty()) {
            return
        }

        mainHandler.post {
            canalEventosWebview.invokeMethod(
                "notificacaoWeb",
                mapOf(
                    "mensagem" to texto.take(180),
                    "modulo" to moduloNormalizado,
                ),
            )
        }
    }

    @JavascriptInterface
    fun logoutDetectado(url: String) {
        mainHandler.post {
            aoLogoutDetectado()
            canalEventosWebview.invokeMethod(
                "logoutDetectado",
                mapOf("url" to url),
            )
        }
    }

    @JavascriptInterface
    fun salvarArquivoBase64(nomeArquivo: String, mimeType: String, base64: String) {
        mainHandler.post {
            gerenciadorDownloads.salvarBase64(
                nomeArquivo = nomeArquivo,
                mimeType = mimeType,
                base64 = base64,
            )
        }
    }

    @JavascriptInterface
    fun compartilharArquivoBase64(
        nomeArquivo: String,
        mimeType: String,
        base64: String,
        texto: String,
        titulo: String,
        modulo: String,
    ) {
        mainHandler.post {
            gerenciadorDownloads.compartilharBase64(
                nomeArquivo = nomeArquivo,
                mimeType = mimeType,
                base64 = base64,
                texto = texto,
                titulo = titulo,
                modulo = modulo,
            )
        }
    }

    @JavascriptInterface
    fun baixarUrl(url: String, nomeArquivo: String, mimeType: String) {
        mainHandler.post {
            gerenciadorDownloads.baixarUrl(
                url = url,
                nomeArquivo = nomeArquivo,
                mimeType = mimeType,
                headers = headers,
            )
        }
    }

    @JavascriptInterface
    fun salvarPdfHtml(nomeArquivo: String, html: String) {
        mainHandler.post {
            gerenciadorDownloads.salvarHtmlComoPdf(
                nomeArquivo = nomeArquivo,
                html = html,
            )
        }
    }

    @JavascriptInterface
    fun uploadArquivo(solicitacaoJson: String) {
        mainHandler.post {
            val payload = try {
                JSONObject(solicitacaoJson.ifBlank { "{}" })
            } catch (erro: Exception) {
                JSONObject()
            }
            val map = mutableMapOf<String, Any?>()
            val keys = payload.keys()

            while (keys.hasNext()) {
                val key = keys.next()
                val value = payload.opt(key)
                map[key] = if (value == JSONObject.NULL) null else value
            }

            if ((map["callbackId"] as? String).isNullOrBlank()) {
                map["callbackId"] = "upload_${System.currentTimeMillis()}"
            }

            canalEventosWebview.invokeMethod("uploadNativoSolicitado", map)
        }
    }

    @JavascriptInterface
    fun abrirWorkNativo(payloadJson: String) {
        encaminharEventoWork("abrirWorkNativo", payloadJson)
    }

    @JavascriptInterface
    fun sincronizarWorkNativo(payloadJson: String) {
        encaminharEventoWork("sincronizarWorkNativo", payloadJson)
    }

    @JavascriptInterface
    fun pausarWorkNativo(payloadJson: String) {
        encaminharEventoWork("pausarWorkNativo", payloadJson)
    }

    @JavascriptInterface
    fun cancelarDescansoWorkNativo(payloadJson: String) {
        encaminharEventoWork("cancelarDescansoWorkNativo", payloadJson)
    }

    @JavascriptInterface
    fun finalizarWorkNativo(payloadJson: String) {
        encaminharEventoWork("finalizarWorkNativo", payloadJson)
    }

    @JavascriptInterface
    fun abrirWorkNativoPorRota(routePath: String) {
        mainHandler.post {
            canalEventosWebview.invokeMethod(
                "workNativoAbrirRota",
                mapOf("routePath" to routePath.trim().ifBlank { "/work" }),
            )
        }
    }

    private fun encaminharEventoWork(metodo: String, payloadJson: String) {
        mainHandler.post {
            canalEventosWebview.invokeMethod(
                "workNativoEvento",
                mapOf(
                    "metodo" to metodo,
                    "payloadJson" to normalizarPayloadJson(payloadJson),
                ),
            )
        }
    }

    private fun normalizarPayloadJson(payloadJson: String): String {
        val texto = payloadJson.trim()

        if (texto.isEmpty()) {
            return "{}"
        }

        if (texto.startsWith("{") && texto.endsWith("}")) {
            return texto
        }

        return JSONObject(mapOf("valor" to texto)).toString()
    }


    @JavascriptInterface
    fun solicitarPermissaoAlarmesExatos() {
        mainHandler.post {
            if (Build.VERSION.SDK_INT < Build.VERSION_CODES.S) {
                Log.d("WhyPhyLocalNotif", "alarme exato não exige permissão especial nesta API")
                return@post
            }

            val alarmManager = context.getSystemService(Context.ALARM_SERVICE) as AlarmManager

            if (alarmManager.canScheduleExactAlarms()) {
                Log.d("WhyPhyLocalNotif", "permissão de alarme exato já concedida")
                return@post
            }

            try {
                val intent = Intent(Settings.ACTION_REQUEST_SCHEDULE_EXACT_ALARM).apply {
                    data = Uri.parse("package:${context.packageName}")
                    flags = Intent.FLAG_ACTIVITY_NEW_TASK
                }

                context.startActivity(intent)
                Log.d("WhyPhyLocalNotif", "solicitando permissão de alarme exato")
            } catch (erro: Exception) {
                Log.e("WhyPhyLocalNotif", "não foi possível abrir permissão de alarme exato", erro)

                try {
                    val intent = Intent(Settings.ACTION_APPLICATION_DETAILS_SETTINGS).apply {
                        data = Uri.parse("package:${context.packageName}")
                        flags = Intent.FLAG_ACTIVITY_NEW_TASK
                    }

                    context.startActivity(intent)
                } catch (erroFallback: Exception) {
                    Log.e("WhyPhyLocalNotif", "não foi possível abrir configurações do app", erroFallback)
                }
            }
        }
    }

    @JavascriptInterface
    fun agendarNotificacaoLocal(solicitacaoJson: String) {
        Log.d("WhyPhyLocalNotif", "bridge agendarNotificacaoLocal: $solicitacaoJson")

        mainHandler.post {
            try {
                agendarNotificacaoLocalJson(JSONObject(solicitacaoJson.ifBlank { "{}" }))
            } catch (erro: Exception) {
                Log.e("WhyPhyLocalNotif", "erro ao agendar", erro)
                canalEventosWebview.invokeMethod(
                    "notificacaoWeb",
                    mapOf(
                        "mensagem" to "Não foi possível agendar a notificação local.",
                        "modulo" to "",
                    ),
                )
            }
        }
    }

    @JavascriptInterface
    fun cancelarNotificacaoLocal(id: String) {
        Log.d("WhyPhyLocalNotif", "bridge cancelarNotificacaoLocal: $id")

        mainHandler.post {
            cancelarNotificacaoLocalId(id)
        }
    }

    private fun idNotificacaoPayload(payload: JSONObject): String? {
        val notificationId = payload.optString("notificationId").trim()

        if (notificationId.isNotEmpty()) {
            return notificationId
        }

        return payload.optString("id").trim().ifBlank { null }
    }

    private fun horarioNotificacaoPayload(payload: JSONObject): Long {
        val triggerAtMillis = payload.optLong("triggerAtMillis", 0L)
        val delayMillis = payload.optLong("delayMillis", 0L)

        if (triggerAtMillis > 0L) {
            return triggerAtMillis
        }

        if (delayMillis > 0L) {
            return System.currentTimeMillis() + delayMillis
        }

        return parsearTriggerAtIso(payload.optString("triggerAt")) ?: System.currentTimeMillis()
    }

    private fun parsearTriggerAtIso(triggerAt: String): Long? {
        val valor = triggerAt.trim()

        if (valor.isEmpty()) {
            return null
        }

        val formatos = listOf(
            "yyyy-MM-dd'T'HH:mm:ss.SSSX",
            "yyyy-MM-dd'T'HH:mm:ssX",
            "yyyy-MM-dd'T'HH:mm:ss.SSS'Z'",
            "yyyy-MM-dd'T'HH:mm:ss'Z'",
        )

        formatos.forEach { formato ->
            try {
                val parser = SimpleDateFormat(formato, Locale.US).apply {
                    isLenient = false
                    timeZone = TimeZone.getTimeZone("UTC")
                }

                return parser.parse(valor)?.time
            } catch (erro: Exception) {
                // Tenta o próximo formato aceito pelo bridge.
            }
        }

        return null
    }

    @JavascriptInterface
    fun abrirExterno(url: String) {
        mainHandler.post {
            try {
                val uri = Uri.parse(url.trim())
                context.startActivity(Intent(Intent.ACTION_VIEW, uri))
            } catch (erro: Exception) {
                canalEventosWebview.invokeMethod(
                    "notificacaoWeb",
                    mapOf(
                        "mensagem" to "Não foi possível abrir este link fora do app.",
                        "modulo" to "",
                    ),
                )
            }
        }
    }

    private fun agendarNotificacaoLocalJson(payload: JSONObject) {
        val action = payload.optString("action").lowercase(Locale.ROOT).trim()

        if (action == "cancel") {
            idNotificacaoPayload(payload)?.let(::cancelarNotificacaoLocalId)
            return
        }

        val id = idNotificacaoPayload(payload) ?: "whyphy_${System.currentTimeMillis()}"
        val tipo = payload.optString("type")
            .ifBlank { payload.optString("tipo") }
            .lowercase(Locale.ROOT)
            .trim()
        val routePath = payload.optString("routePath").trim()
        val titulo = payload.optString("titulo").ifBlank {
            payload.optString("title").ifBlank { "WhyPhy" }
        }
        val mensagem = payload.optString("mensagem").ifBlank {
            payload.optString("body").ifBlank { "Você tem uma atividade pendente." }
        }
        val canal = if (tipo.contains("meal") || tipo.contains("refeic")) {
            CANAL_NOTIFICACAO_REFEICAO_LOCAL
        } else {
            CANAL_NOTIFICACAO_TREINO_LOCAL
        }

        AgendadorNotificacaoLocalWhyPhy.agendar(
            context,
            AgendamentoNotificacaoLocal(
                id = id,
                canal = canal,
                routePath = routePath,
                titulo = titulo,
                mensagem = mensagem,
                quandoMillis = horarioNotificacaoPayload(payload),
            ),
        )
    }

    private fun cancelarNotificacaoLocalId(id: String) {
        AgendadorNotificacaoLocalWhyPhy.cancelar(context, id)
    }
}

private class GerenciadorDownloadsWebview(
    private val context: Context,
    private val canalEventosWebview: MethodChannel,
) {
    fun salvarBase64(nomeArquivo: String, mimeType: String, base64: String) {
        try {
            val bytes = Base64.decode(base64, Base64.DEFAULT)
            val nomeFinal = normalizarNomeArquivo(nomeArquivo, extensaoParaMime(mimeType))
            val mimeFinal = normalizarMime(mimeType)
            val uri = salvarBytes(nomeFinal, mimeFinal, bytes)
            abrirArquivoSalvo(uri, mimeFinal)
            notificar("Arquivo salvo em Downloads.")
        } catch (erro: Exception) {
            notificar("Não foi possível salvar o arquivo.")
        }
    }

    fun compartilharBase64(
        nomeArquivo: String,
        mimeType: String,
        base64: String,
        texto: String,
        titulo: String,
        modulo: String,
    ) {
        try {
            val mimeFinal = normalizarMime(mimeType).ifBlank { "image/png" }
            val nomeFinal = normalizarNomeArquivo(
                nomeArquivo.ifBlank { "whyphy-compartilhar" },
                extensaoParaMime(mimeFinal).ifBlank { ".png" },
            )
            val bytes = Base64.decode(base64, Base64.DEFAULT)
            val uri = salvarImagemCompartilhavel(nomeFinal, mimeFinal, bytes)
            val intentCompartilhar = Intent(Intent.ACTION_SEND).apply {
                type = mimeFinal
                putExtra(Intent.EXTRA_STREAM, uri)
                if (texto.isNotBlank()) {
                    putExtra(Intent.EXTRA_TEXT, texto)
                }
                if (titulo.isNotBlank()) {
                    putExtra(Intent.EXTRA_TITLE, titulo)
                }
                addFlags(Intent.FLAG_GRANT_READ_URI_PERMISSION)
            }
            val tituloChooser = titulo.ifBlank { "Compartilhar imagem WhyPhy" }
            context.startActivity(Intent.createChooser(intentCompartilhar, tituloChooser))
            notificar("Compartilhamento aberto no dispositivo.", modulo)
        } catch (erro: Exception) {
            notificar("N\u00e3o foi poss\u00edvel compartilhar a imagem.", modulo)
        }
    }

    fun baixarUrl(
        url: String,
        nomeArquivo: String,
        mimeType: String,
        headers: Map<String, String>,
    ) {
        val uri = Uri.parse(url)
        val scheme = uri.scheme.orEmpty()

        if (scheme != "http" && scheme != "https") {
            notificar("Não foi possível baixar esse arquivo.")
            return
        }

        try {
            val mimeFinal = normalizarMime(mimeType)
            val nomeFinal = normalizarNomeArquivo(
                nomeArquivo.ifBlank {
                    URLUtil.guessFileName(url, null, mimeFinal)
                },
                extensaoParaMime(mimeFinal),
            )
            val request = DownloadManager.Request(uri)
                .setTitle(nomeFinal)
                .setMimeType(mimeFinal)
                .setNotificationVisibility(
                    DownloadManager.Request.VISIBILITY_VISIBLE_NOTIFY_COMPLETED,
                )
                .setDestinationInExternalPublicDir(
                    Environment.DIRECTORY_DOWNLOADS,
                    nomeFinal,
                )

            headers.forEach { (nome, valor) ->
                if (nome.isNotBlank() && valor.isNotBlank()) {
                    request.addRequestHeader(nome, valor)
                }
            }

            CookieManager.getInstance().getCookie(url)?.let { cookies ->
                if (cookies.isNotBlank()) {
                    request.addRequestHeader("Cookie", cookies)
                }
            }

            val downloadManager = context.getSystemService(Context.DOWNLOAD_SERVICE) as DownloadManager
            val downloadId = downloadManager.enqueue(request)
            abrirDownloadAoConcluir(downloadManager, downloadId, mimeFinal)
            notificar("Download iniciado em Downloads.")
        } catch (erro: Exception) {
            notificar("Não foi possível iniciar o download.")
        }
    }

    fun salvarHtmlComoPdf(nomeArquivo: String, html: String) {
        if (html.isBlank()) {
            notificar("Não foi possível gerar o PDF.")
            return
        }

        val nomeFinal = normalizarNomeArquivo(nomeArquivo, ".pdf")
        val webViewPdf = WebView(context)
        webViewPdf.settings.javaScriptEnabled = true
        webViewPdf.settings.domStorageEnabled = true
        webViewPdf.settings.loadWithOverviewMode = false
        webViewPdf.settings.useWideViewPort = false
        webViewPdf.setBackgroundColor(Color.WHITE)
        webViewPdf.setLayerType(View.LAYER_TYPE_SOFTWARE, null)

        val parent = (context as? Activity)?.window?.decorView as? ViewGroup
        parent?.addView(
            webViewPdf,
            ViewGroup.LayoutParams(LARGURA_PAGINA_PDF, ALTURA_PAGINA_PDF),
        )
        webViewPdf.alpha = 0.01f
        webViewPdf.isClickable = false
        webViewPdf.isFocusable = false

        webViewPdf.webViewClient = object : WebViewClient() {
            override fun onPageFinished(view: WebView, url: String) {
                super.onPageFinished(view, url)
                Handler(Looper.getMainLooper()).postDelayed(
                    {
                        try {
                            @Suppress("DEPRECATION")
                            val alturaCss = view.contentHeight
                                .times(view.scale)
                                .toInt()
                                .coerceAtLeast(ALTURA_PAGINA_PDF)

                            renderizarPdfPorPaginas(view, alturaCss) { bytes ->
                                try {
                                    if (bytes == null) {
                                        notificar("Não foi possível salvar o PDF.")
                                        return@renderizarPdfPorPaginas
                                    }
                                    val uri = salvarBytes(nomeFinal, "application/pdf", bytes)
                                    abrirArquivoSalvo(uri, "application/pdf")
                                    notificar("PDF salvo em Downloads.")
                                } catch (erro: Exception) {
                                    notificar("Não foi possível salvar o PDF.")
                                } finally {
                                    parent?.removeView(view)
                                    view.destroy()
                                }
                            }
                        } catch (erro: Exception) {
                            parent?.removeView(view)
                            view.destroy()
                            notificar("Não foi possível salvar o PDF.")
                        }
                    },
                    900,
                )
            }
        }
        webViewPdf.loadDataWithBaseURL(
            "https://www.whyphy.com.br",
            html,
            "text/html",
            "UTF-8",
            null,
        )
    }

    private fun renderizarPdfPorPaginas(
        webView: WebView,
        alturaConteudo: Int,
        aoConcluir: (ByteArray?) -> Unit,
    ) {
        val largura = LARGURA_PAGINA_PDF
        val alturaPagina = ALTURA_PAGINA_PDF
        val alturaTotal = alturaConteudo.coerceAtLeast(alturaPagina)

        webView.measure(
            View.MeasureSpec.makeMeasureSpec(largura, View.MeasureSpec.EXACTLY),
            View.MeasureSpec.makeMeasureSpec(alturaPagina, View.MeasureSpec.EXACTLY),
        )
        webView.layout(0, 0, largura, alturaPagina)

        val documento = PdfDocument()

        fun finalizarComErro() {
            try {
                documento.close()
            } catch (erro: Exception) {
                // Ignora falha de fechamento depois de erro de renderização.
            }
            aoConcluir(null)
        }

        fun capturarPagina(topo: Int, paginaAtual: Int) {
            if (topo >= alturaTotal) {
                try {
                    val stream = java.io.ByteArrayOutputStream()
                    documento.writeTo(stream)
                    documento.close()
                    aoConcluir(stream.toByteArray())
                } catch (erro: Exception) {
                    finalizarComErro()
                }
                return
            }

            try {
                webView.scrollTo(0, topo)
                webView.postDelayed(
                    {
                        try {
                            val info = PdfDocument.PageInfo
                                .Builder(largura, alturaPagina, paginaAtual)
                                .create()
                            val pagina = documento.startPage(info)
                            pagina.canvas.drawColor(Color.WHITE)
                            webView.draw(pagina.canvas)
                            documento.finishPage(pagina)
                            capturarPagina(topo + alturaPagina, paginaAtual + 1)
                        } catch (erro: Exception) {
                            finalizarComErro()
                        }
                    },
                    140,
                )
            } catch (erro: Exception) {
                finalizarComErro()
            }
        }

        capturarPagina(0, 1)
    }

    private fun salvarBytes(nomeArquivo: String, mimeType: String, bytes: ByteArray): Uri? {
        if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.Q) {
            val values = ContentValues().apply {
                put(MediaStore.Downloads.DISPLAY_NAME, nomeArquivo)
                put(MediaStore.Downloads.MIME_TYPE, mimeType)
                put(MediaStore.Downloads.RELATIVE_PATH, Environment.DIRECTORY_DOWNLOADS)
                put(MediaStore.Downloads.IS_PENDING, 1)
            }
            val resolver = context.contentResolver
            val uri = resolver.insert(MediaStore.Downloads.EXTERNAL_CONTENT_URI, values)
                ?: throw IllegalStateException("download_uri_indisponivel")

            resolver.openOutputStream(uri)?.use { output ->
                output.write(bytes)
            } ?: throw IllegalStateException("download_output_indisponivel")

            values.clear()
            values.put(MediaStore.Downloads.IS_PENDING, 0)
            resolver.update(uri, values, null, null)
            return uri
        }

        val diretorio = Environment.getExternalStoragePublicDirectory(Environment.DIRECTORY_DOWNLOADS)
        if (!diretorio.exists()) {
            diretorio.mkdirs()
        }

        File(diretorio, nomeArquivo).outputStream().use { output ->
            output.write(bytes)
        }

        return null
    }

    private fun abrirDownloadAoConcluir(
        downloadManager: DownloadManager,
        downloadId: Long,
        mimeType: String,
    ) {
        val appContext = context.applicationContext
        val receiver = object : BroadcastReceiver() {
            override fun onReceive(contexto: Context, intent: Intent) {
                val idConcluido = intent.getLongExtra(DownloadManager.EXTRA_DOWNLOAD_ID, -1L)

                if (idConcluido != downloadId) {
                    return
                }

                try {
                    appContext.unregisterReceiver(this)
                } catch (erro: Exception) {
                    // O receiver pode já ter sido removido pelo sistema.
                }

                val uri = downloadManager.getUriForDownloadedFile(downloadId)

                if (!abrirArquivoSalvo(uri, mimeType)) {
                    notificar("Arquivo salvo em Downloads.")
                }
            }
        }
        val filtro = IntentFilter(DownloadManager.ACTION_DOWNLOAD_COMPLETE)

        if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.TIRAMISU) {
            appContext.registerReceiver(receiver, filtro, Context.RECEIVER_NOT_EXPORTED)
        } else {
            @Suppress("DEPRECATION")
            appContext.registerReceiver(receiver, filtro)
        }
    }

    private fun abrirArquivoSalvo(uri: Uri?, mimeType: String): Boolean {
        if (uri == null) {
            return false
        }

        return try {
            val intentAbrir = Intent(Intent.ACTION_VIEW).apply {
                setDataAndType(uri, normalizarMime(mimeType))
                addFlags(Intent.FLAG_GRANT_READ_URI_PERMISSION)
                addFlags(Intent.FLAG_ACTIVITY_NEW_TASK)
            }

            context.startActivity(intentAbrir)
            true
        } catch (erro: Exception) {
            false
        }
    }

    private fun salvarImagemCompartilhavel(nomeArquivo: String, mimeType: String, bytes: ByteArray): Uri {
        val resolver = context.contentResolver
        val values = ContentValues().apply {
            put(MediaStore.Images.Media.DISPLAY_NAME, nomeArquivo)
            put(MediaStore.Images.Media.MIME_TYPE, mimeType)
            if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.Q) {
                put(
                    MediaStore.Images.Media.RELATIVE_PATH,
                    "${Environment.DIRECTORY_PICTURES}/WhyPhy",
                )
                put(MediaStore.Images.Media.IS_PENDING, 1)
            }
        }
        val uri = resolver.insert(MediaStore.Images.Media.EXTERNAL_CONTENT_URI, values)
            ?: throw IllegalStateException("share_uri_indisponivel")

        resolver.openOutputStream(uri)?.use { output ->
            output.write(bytes)
        } ?: throw IllegalStateException("share_output_indisponivel")

        if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.Q) {
            values.clear()
            values.put(MediaStore.Images.Media.IS_PENDING, 0)
            resolver.update(uri, values, null, null)
        }

        return uri
    }

    private fun normalizarNomeArquivo(nomeArquivo: String, extensaoFallback: String): String {
        val limpo = nomeArquivo
            .trim()
            .ifBlank { "whyphy-arquivo$extensaoFallback" }
            .replace(Regex("[^A-Za-z0-9._-]"), "-")
            .replace(Regex("-+"), "-")
            .trim('-')

        if (limpo.contains(".") || extensaoFallback.isBlank()) {
            return limpo.ifBlank { "whyphy-arquivo$extensaoFallback" }
        }

        return "$limpo$extensaoFallback"
    }

    private fun normalizarMime(mimeType: String): String {
        return mimeType.trim().ifBlank { "application/octet-stream" }
    }

    private fun extensaoParaMime(mimeType: String): String {
        return when (normalizarMime(mimeType).lowercase(Locale.ROOT)) {
            "application/pdf" -> ".pdf"
            "image/jpeg", "image/jpg" -> ".jpg"
            "image/png" -> ".png"
            "image/webp" -> ".webp"
            else -> ""
        }
    }

    private fun notificar(mensagem: String, modulo: String = "") {
        canalEventosWebview.invokeMethod(
            "notificacaoWeb",
            mapOf(
                "mensagem" to mensagem,
                "modulo" to modulo.trim(),
            ),
        )
    }

    private companion object {
        const val LARGURA_PAGINA_PDF = 1240
        const val ALTURA_PAGINA_PDF = 1754
    }
}

private class GerenciadorPopupsWebview(
    private val canalEventosWebview: MethodChannel,
) {
    private val popups = mutableMapOf<String, JsResult>()
    private val prompts = mutableMapOf<String, JsPromptResult>()
    private var contador = 0

    fun registrar(
        tipo: String,
        mensagem: String,
        textoPadrao: String?,
        resultado: JsResult,
    ) {
        val id = proximoId()
        popups[id] = resultado
        emitirPopup(id = id, tipo = tipo, mensagem = mensagem, textoPadrao = textoPadrao)
    }

    fun registrarPrompt(
        mensagem: String,
        textoPadrao: String,
        resultado: JsPromptResult,
    ) {
        val id = proximoId()
        prompts[id] = resultado
        emitirPopup(
            id = id,
            tipo = "entrada",
            mensagem = mensagem,
            textoPadrao = textoPadrao,
        )
    }
    fun responder(id: String?, confirmado: Boolean, texto: String?) {
        if (id.isNullOrBlank()) {
            return
        }

        val prompt = prompts.remove(id)
        if (prompt != null) {
            if (confirmado) {
                prompt.confirm(texto.orEmpty())
            } else {
                prompt.cancel()
            }
            return
        }

        val popup = popups.remove(id) ?: return
        if (confirmado) {
            popup.confirm()
        } else {
            popup.cancel()
        }
    }

    fun cancelarTodos() {
        popups.values.forEach { it.cancel() }
        prompts.values.forEach { it.cancel() }
        popups.clear()
        prompts.clear()
    }

    private fun emitirPopup(
        id: String,
        tipo: String,
        mensagem: String,
        textoPadrao: String?,
    ) {
        canalEventosWebview.invokeMethod(
            "popupNativoWeb",
            mapOf(
                "id" to id,
                "tipo" to tipo,
                "mensagem" to mensagem,
                "textoPadrao" to textoPadrao.orEmpty(),
            ),
        )
    }

    private fun proximoId(): String {
        contador += 1
        return "popup_${System.currentTimeMillis()}_$contador"
    }
}
