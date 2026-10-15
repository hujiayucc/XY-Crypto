package com.hujiayucc.decode

import android.Manifest
import android.content.Intent
import android.content.pm.PackageManager
import android.net.Uri
import android.os.Handler
import android.os.Looper
import android.os.Process
import android.provider.OpenableColumns
import android.provider.Settings
import android.util.Log
import java.io.ByteArrayOutputStream
import com.google.mlkit.common.MlKit

import io.flutter.embedding.android.FlutterActivity
import io.flutter.embedding.engine.FlutterEngine
import io.flutter.plugin.common.MethodChannel
import org.json.JSONObject

class MainActivity : FlutterActivity() {
    companion object {
        private const val SHARE_CHANNEL = "com.hujiayucc.decode/share"
        private const val PRIVACY_CHANNEL = "com.hujiayucc.decode/privacy"
        private const val POLICY_VERSION = "xy-legal-v2"
        private const val CAMERA_REQUEST = 701
        private const val DENIAL_INTERVAL = 48L * 60 * 60 * 1000
        private const val MAX_SHARE_FILE_BYTES = 32 * 1024 * 1024
    }
    private val preferences by lazy { getSharedPreferences("xy_privacy", MODE_PRIVATE) }
    private var engine: FlutterEngine? = null
    private var shareChannel: MethodChannel? = null
    @Volatile private var active = false
    @Volatile private var receiving = false
    private var pluginsRegistered = false
    private var scannerResult: MethodChannel.Result? = null

    override fun configureFlutterEngine(flutterEngine: FlutterEngine) {
        // Skip automatic registration: optional plugins run only after consent.
        engine = flutterEngine
        val messenger = flutterEngine.dartExecutor.binaryMessenger
        shareChannel = MethodChannel(messenger, SHARE_CHANNEL)
        shareChannel?.setMethodCallHandler { call, result ->
            when (call.method) {
                "getInitialSharedText" -> {
                    if (!active) result.error("consent_required", "请先同意隐私政策", null)
                    else {
                        receiving = true
                        result.success(consumeIntent())
                    }
                }
                "getInitialSharedFile" -> {
                    if (!active) result.error("consent_required", "请先同意隐私政策", null)
                    else {
                        val source = takeFileIntent()
                        if (source == null) result.success(null)
                        else Thread {
                            val content = readShareFile(source)
                            runOnUiThread { result.success(if (active) content else null) }
                        }.start()
                    }
                }
                "stopReceiving" -> { receiving = false; result.success(null) }
                else -> result.notImplemented()
            }
        }
        MethodChannel(messenger, PRIVACY_CHANNEL).setMethodCallHandler { call, result ->
            try {
                when (call.method) {
                    "readConsent" -> result.success(preferences.getString("record", null))
                    "saveConsent" -> {
                        val raw = call.arguments as? String ?: throw IllegalArgumentException()
                        require(validRecord(raw))
                        check(preferences.edit().putString("record", raw).commit())
                        result.success(null)
                    }
                    "activate" -> {
                        require(call.arguments == POLICY_VERSION && validRecord(preferences.getString("record", null)))
                        registerApprovedPlugins(flutterEngine)
                        active = true
                        result.success(null)
                    }
                    "revokeConsent" -> {
                        check(preferences.edit().remove("record").commit())
                        active = false
                        receiving = false
                        intent = Intent(Intent.ACTION_MAIN)
                        scannerResult?.error("consent_revoked", "隐私授权已撤回", null)
                        scannerResult = null
                        result.success(null)
                    }
                    "hasCameraPermission" -> result.success(
                        checkSelfPermission(Manifest.permission.CAMERA) == PackageManager.PERMISSION_GRANTED)
                    "prepareScanner" -> prepareScanner(result)
                    "openAppSettings" -> {
                        startActivity(Intent(Settings.ACTION_APPLICATION_DETAILS_SETTINGS,
                            Uri.parse("package:$packageName")))
                        result.success(null)
                    }
                    "exitApplication" -> {
                        active = false
                        receiving = false
                        intent = Intent(Intent.ACTION_MAIN)
                        result.success(null)
                        finishAndRemoveTask()
                        // Explicit exit terminates optional SDK background work;
                        // ML Kit exposes no process-wide shutdown API.
                        Handler(Looper.getMainLooper()).postDelayed({ Process.killProcess(Process.myPid()) }, 250)
                    }
                    else -> result.notImplemented()
                }
            } catch (error: Exception) {
                val code = when (call.method) {
                    "saveConsent" -> "consent_save_failed"
                    "activate" -> "consent_activation_failed"
                    else -> "privacy_operation_failed"
                }
                val rootCause = error.cause ?: error
                val details = mutableMapOf<String, String>(
                    "stage" to call.method,
                    "exception" to rootCause.javaClass.simpleName
                )
                if (error is PluginRegistrationException) {
                    details["plugin"] = error.plugin
                }
                // Do not log consent records, keys, shared text, or file contents.
                Log.e("XYPrivacy", "${call.method}: ${details["plugin"] ?: "native"}/${rootCause.javaClass.simpleName}")
                result.error(code, "操作未完成，请重试", details)
            }
        }
    }
    private fun validRecord(raw: String?): Boolean = try {
        val record = JSONObject(raw ?: "")
        record.optString("version") == POLICY_VERSION &&
            record.optString("acceptedAt").matches(Regex("\\d{4}-\\d{2}-\\d{2}T.+Z"))
    } catch (_: Exception) { false }

    private class PluginRegistrationException(
        val plugin: String,
        cause: Exception
    ) : IllegalStateException("Plugin registration failed: $plugin", cause)

    private fun addApprovedPlugin(
        flutterEngine: FlutterEngine,
        name: String,
        pluginClass: Class<out io.flutter.embedding.engine.plugins.FlutterPlugin>,
        create: () -> io.flutter.embedding.engine.plugins.FlutterPlugin
    ) {
        if (flutterEngine.plugins.has(pluginClass)) return
        try {
            flutterEngine.plugins.add(create())
        } catch (error: Exception) {
            throw PluginRegistrationException(name, error)
        }
    }

    private fun registerApprovedPlugins(flutterEngine: FlutterEngine) {
        if (pluginsRegistered) return
        addApprovedPlugin(flutterEngine, "flutter_secure_storage",
            com.it_nomads.fluttersecurestorage.FlutterSecureStoragePlugin::class.java) {
            com.it_nomads.fluttersecurestorage.FlutterSecureStoragePlugin()
        }
        addApprovedPlugin(flutterEngine, "flutter_plugin_android_lifecycle",
            io.flutter.plugins.flutter_plugin_android_lifecycle.FlutterAndroidLifecyclePlugin::class.java) {
            io.flutter.plugins.flutter_plugin_android_lifecycle.FlutterAndroidLifecyclePlugin()
        }
        addApprovedPlugin(flutterEngine, "file_picker",
            com.mr.flutter.plugin.filepicker.FilePickerPlugin::class.java) {
            com.mr.flutter.plugin.filepicker.FilePickerPlugin()
        }
        addApprovedPlugin(flutterEngine, "path_provider",
            io.flutter.plugins.pathprovider.PathProviderPlugin::class.java) {
            io.flutter.plugins.pathprovider.PathProviderPlugin()
        }
        addApprovedPlugin(flutterEngine, "share_plus",
            dev.fluttercommunity.plus.share.SharePlusPlugin::class.java) {
            dev.fluttercommunity.plus.share.SharePlusPlugin()
        }
        addApprovedPlugin(flutterEngine, "url_launcher",
            io.flutter.plugins.urllauncher.UrlLauncherPlugin::class.java) {
            io.flutter.plugins.urllauncher.UrlLauncherPlugin()
        }
        addApprovedPlugin(flutterEngine, "webview_flutter",
            io.flutter.plugins.webviewflutter.WebViewFlutterPlugin::class.java) {
            io.flutter.plugins.webviewflutter.WebViewFlutterPlugin()
        }
        pluginsRegistered = true
    }
    private fun prepareScanner(result: MethodChannel.Result) {
        if (!active) { result.error("consent_required", "请先同意隐私政策", null); return }
        if (checkSelfPermission(Manifest.permission.CAMERA) == PackageManager.PERMISSION_GRANTED) {
            enableScanner(result)
            return
        }
        val lastDenied = preferences.getLong("camera_last_denied", 0L)
        if (lastDenied != 0L && System.currentTimeMillis() - lastDenied < DENIAL_INTERVAL) {
            result.success("denied")
            return
        }
        if (scannerResult != null) { result.success("busy"); return }
        scannerResult = result
        requestPermissions(arrayOf(Manifest.permission.CAMERA), CAMERA_REQUEST)
    }
    private fun enableScanner(result: MethodChannel.Result) {
        if (!active) { result.success("denied"); return }
        try {
            val current = engine ?: throw IllegalStateException()
            if (!current.plugins.has(dev.steenbakker.mobile_scanner.MobileScannerPlugin::class.java)) {
                MlKit.initialize(applicationContext)
                current.plugins.add(dev.steenbakker.mobile_scanner.MobileScannerPlugin())
            }
            result.success("ready")
        } catch (_: Exception) {
            result.error("scanner_unavailable", "相机扫码暂未就绪，可选择图片识别", null)
        }
    }
    override fun onRequestPermissionsResult(requestCode: Int, permissions: Array<out String>, grantResults: IntArray) {
        if (requestCode == CAMERA_REQUEST) {
            val pending = scannerResult
            scannerResult = null
            if (grantResults.isNotEmpty() && grantResults[0] == PackageManager.PERMISSION_GRANTED) {
                if (pending != null) enableScanner(pending)
            } else {
                preferences.edit().putLong("camera_last_denied", System.currentTimeMillis()).apply()
                pending?.success("denied")
            }
            return
        }
        super.onRequestPermissionsResult(requestCode, permissions, grantResults)
    }
    override fun onNewIntent(intent: Intent) {
        setIntent(intent)
        // Keep the OS Intent opaque until consent; no extras or URI are read.
        if (!active) return
        super.onNewIntent(intent)
        if (receiving) {
            consumeIntent()?.let { shareChannel?.invokeMethod("sharedText", it) }
            takeFileIntent()?.let { source ->
                Thread {
                    val content = readShareFile(source)
                    if (active && receiving && content != null) {
                        runOnUiThread {
                            if (active && receiving) shareChannel?.invokeMethod("sharedFile", content)
                        }
                    }
                }.start()
            }
        }
    }
    private fun consumeIntent(): String? {
        if (!active) return null
        val source = intent ?: return null
        if (isPotentialShareFileIntent(source)) return null
        val value = when (source.action) {
            Intent.ACTION_VIEW -> source.dataString
            Intent.ACTION_SEND -> source.getCharSequenceExtra(Intent.EXTRA_TEXT)?.toString()
            Intent.ACTION_PROCESS_TEXT -> source.getCharSequenceExtra(Intent.EXTRA_PROCESS_TEXT)?.toString()
                ?: source.getCharSequenceExtra(Intent.EXTRA_TEXT)?.toString()
            else -> null
        }
        intent = Intent(Intent.ACTION_MAIN)
        return value?.trim()?.takeIf { it.isNotEmpty() }
    }

    private fun fileUri(source: Intent): Uri? = when (source.action) {
        Intent.ACTION_VIEW -> source.data?.takeIf {
            it.scheme == "content" || it.scheme == "file"
        }
        Intent.ACTION_SEND -> {
            @Suppress("DEPRECATION")
            (source.getParcelableExtra(Intent.EXTRA_STREAM) as? Uri)
                ?: source.clipData?.takeIf { it.itemCount > 0 }?.getItemAt(0)?.uri
        }
        else -> null
    }

    private fun displayName(uri: Uri): String? {
        if (uri.scheme == "file") return uri.lastPathSegment
        contentResolver.query(uri, arrayOf(OpenableColumns.DISPLAY_NAME), null, null, null)?.use { cursor ->
            if (cursor.moveToFirst()) {
                val index = cursor.getColumnIndex(OpenableColumns.DISPLAY_NAME)
                if (index >= 0) return cursor.getString(index)
            }
        }
        return uri.lastPathSegment
    }

    private fun isPotentialShareFileIntent(source: Intent): Boolean {
        val uri = fileUri(source) ?: return false
        val mime = source.type?.substringBefore(';')?.trim()?.lowercase().orEmpty()
        return when (source.action) {
            Intent.ACTION_VIEW -> uri.scheme == "content" || uri.scheme == "file"
            Intent.ACTION_SEND -> uri.scheme == "content" &&
                mime in setOf("application/x-xyshare", "application/octet-stream")
            else -> false
        }
    }

    private fun takeFileIntent(): Intent? {
        if (!active) return null
        val source = intent ?: return null
        if (!isPotentialShareFileIntent(source)) return null
        intent = Intent(Intent.ACTION_MAIN)
        return source
    }

    private fun readShareFile(source: Intent): Map<String, Any>? {
        val uri = fileUri(source) ?: return null
        return try {
            val name = displayName(uri) ?: return null
            if (!name.trim().lowercase().endsWith(".xyshare")) return null
            val bytes = (if (uri.scheme == "file") {
                java.io.FileInputStream(java.io.File(uri.path!!))
            } else {
                contentResolver.openInputStream(uri)
            })?.use { input ->
                val output = ByteArrayOutputStream()
                val buffer = ByteArray(8192)
                var total = 0
                while (true) {
                    val count = input.read(buffer)
                    if (count < 0) break
                    total += count
                    if (total > MAX_SHARE_FILE_BYTES) return null
                    output.write(buffer, 0, count)
                }
                output.toByteArray()
            } ?: return null
            mapOf("name" to name, "bytes" to bytes)
        } catch (_: Exception) {
            null
        }
    }
}