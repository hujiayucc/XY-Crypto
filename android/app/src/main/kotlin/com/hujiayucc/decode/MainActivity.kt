package com.hujiayucc.decode

import android.Manifest
import android.content.Intent
import android.content.pm.PackageManager
import android.net.Uri
import android.os.Handler
import android.os.Looper
import android.os.Process
import android.provider.Settings
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
    }
    private val preferences by lazy { getSharedPreferences("xy_privacy", MODE_PRIVATE) }
    private var engine: FlutterEngine? = null
    private var shareChannel: MethodChannel? = null
    private var active = false
    private var receiving = false
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
            } catch (_: Exception) {
                result.error("privacy_operation_failed", "操作未完成，请重试", null)
            }
        }
    }
    private fun validRecord(raw: String?): Boolean = try {
        val record = JSONObject(raw ?: "")
        record.optString("version") == POLICY_VERSION &&
            record.optString("acceptedAt").matches(Regex("\\d{4}-\\d{2}-\\d{2}T.+Z"))
    } catch (_: Exception) { false }

    private fun registerApprovedPlugins(flutterEngine: FlutterEngine) {
        if (pluginsRegistered) return
        val plugins = flutterEngine.plugins
        // Android VIEW and text shares use our own channel, avoiding app_links'
        // pre-consent Intent parsing and debug URL logging.
        plugins.add(com.it_nomads.fluttersecurestorage.FlutterSecureStoragePlugin())
        plugins.add(io.flutter.plugins.flutter_plugin_android_lifecycle.FlutterAndroidLifecyclePlugin())
        plugins.add(com.mr.flutter.plugin.filepicker.FilePickerPlugin())
        plugins.add(io.flutter.plugins.pathprovider.PathProviderPlugin())
        plugins.add(dev.fluttercommunity.plus.share.SharePlusPlugin())
        plugins.add(io.flutter.plugins.urllauncher.UrlLauncherPlugin())
        plugins.add(io.flutter.plugins.webviewflutter.WebViewFlutterPlugin())
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
        if (receiving) consumeIntent()?.let { shareChannel?.invokeMethod("sharedText", it) }
    }
    private fun consumeIntent(): String? {
        if (!active) return null
        val source = intent ?: return null
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
}