package br.com.whyphy.whyphy_app

import android.Manifest
import android.app.Activity
import android.app.DownloadManager
import android.content.ContentValues
import android.content.Context
import android.content.Intent
import android.content.pm.PackageManager
import android.graphics.Color
import android.graphics.pdf.PdfDocument
import android.os.Build
import android.net.Uri
import android.os.Handler
import android.os.Looper
import android.os.Environment
import android.provider.MediaStore
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
import android.webkit.WebResourceRequest
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
import java.io.File
import java.security.KeyStore
import java.util.Locale
import javax.crypto.Cipher
import javax.crypto.KeyGenerator
import javax.crypto.SecretKey
import javax.crypto.spec.GCMParameterSpec

class MainActivity : FlutterActivity() {
    private var arquivoSelecionadoCallback: ValueCallback<Array<Uri>>? = null
    private var arquivoSelecionadoParamsPendente: WebChromeClient.FileChooserParams? = null
    private var canalEventosWebview: MethodChannel? = null
    private var permissaoCameraPendente: PermissionRequest? = null
    private var payloadPushPendente: Map<String, String>? = null
    private var webViewAtiva: WebView? = null
    private var webViewAllowedHostAtivo: String = ""
    private var webViewHeadersAtivos: Map<String, String> = emptyMap()

    override fun configureFlutterEngine(flutterEngine: FlutterEngine) {
        super.configureFlutterEngine(flutterEngine)

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
    }
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
        webView.settings.javaScriptEnabled = true
        webView.settings.domStorageEnabled = true
        webView.settings.setSupportMultipleWindows(false)
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
                injetarAjustesDeInputArquivo(view)
                injetarInterceptadorLogout(view)
                injetarInterceptadorDownloads(view)
                injetarInterceptadorDeAvisos(view)
                notificarCarregamento(iniciado = false)
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
        }
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
}

private class GerenciadorDownloadsWebview(
    private val context: Context,
    private val canalEventosWebview: MethodChannel,
) {
    fun salvarBase64(nomeArquivo: String, mimeType: String, base64: String) {
        try {
            val bytes = Base64.decode(base64, Base64.DEFAULT)
            val nomeFinal = normalizarNomeArquivo(nomeArquivo, extensaoParaMime(mimeType))
            salvarBytes(nomeFinal, normalizarMime(mimeType), bytes)
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
            downloadManager.enqueue(request)
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
                                    salvarBytes(nomeFinal, "application/pdf", bytes)
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

    private fun salvarBytes(nomeArquivo: String, mimeType: String, bytes: ByteArray) {
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
            return
        }

        val diretorio = Environment.getExternalStoragePublicDirectory(Environment.DIRECTORY_DOWNLOADS)
        if (!diretorio.exists()) {
            diretorio.mkdirs()
        }

        File(diretorio, nomeArquivo).outputStream().use { output ->
            output.write(bytes)
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
