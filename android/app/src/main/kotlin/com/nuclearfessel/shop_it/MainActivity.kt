package com.nuclearfessel.shop_it

import android.app.Activity
import android.content.Context
import android.content.Intent
import android.net.wifi.WifiManager
import com.google.zxing.integration.android.IntentIntegrator
import io.flutter.embedding.android.FlutterActivity
import io.flutter.embedding.engine.FlutterEngine
import io.flutter.plugin.common.MethodChannel

class MainActivity : FlutterActivity() {
    private var multicastLock: WifiManager.MulticastLock? = null
    private var wifiLock: WifiManager.WifiLock? = null
    private var scanResult: MethodChannel.Result? = null

    override fun configureFlutterEngine(flutterEngine: FlutterEngine) {
        super.configureFlutterEngine(flutterEngine)
        MethodChannel(flutterEngine.dartExecutor.binaryMessenger, "shop.it/network")
            .setMethodCallHandler { call, result ->
                if (call.method != "multicastLock") {
                    result.notImplemented()
                    return@setMethodCallHandler
                }
                if (call.arguments == true) acquireMulticastLock() else releaseMulticastLock()
                result.success(null)
            }
        MethodChannel(flutterEngine.dartExecutor.binaryMessenger, "shop_it/barcode")
            .setMethodCallHandler { call, result ->
                if (call.method != "scan") {
                    result.notImplemented()
                    return@setMethodCallHandler
                }
                if (scanResult != null) {
                    result.error("busy", "A scan is already open", null)
                    return@setMethodCallHandler
                }
                scanResult = result
                val args = call.arguments as? Map<*, *>
                val portrait = args?.get("portrait") == true
                val sync = args?.get("sync") == true
                if (portrait) {
                    requestedOrientation =
                        android.content.pm.ActivityInfo.SCREEN_ORIENTATION_PORTRAIT
                }
                IntentIntegrator(this)
                    .setDesiredBarcodeFormats(
                        if (sync) listOf("QR_CODE") else IntentIntegrator.PRODUCT_CODE_TYPES,
                    )
                    .setPrompt(if (sync) "Scan the ShopIt QR code" else "Scan a barcode")
                    .setBeepEnabled(false)
                    .setOrientationLocked(portrait)
                    .initiateScan()
            }
    }

    override fun onActivityResult(requestCode: Int, resultCode: Int, data: Intent?) {
        val parsed = IntentIntegrator.parseActivityResult(requestCode, resultCode, data)
        if (parsed != null) {
            val pending = scanResult
            scanResult = null
            val code = parsed.contents
            if (resultCode == Activity.RESULT_OK && !code.isNullOrBlank()) {
                pending?.success(code)
            } else {
                pending?.success(null)
            }
            return
        }
        super.onActivityResult(requestCode, resultCode, data)
    }

    private fun acquireMulticastLock() {
        if (multicastLock?.isHeld == true) return
        val wifi = applicationContext.getSystemService(Context.WIFI_SERVICE) as WifiManager
        multicastLock = wifi.createMulticastLock("shop-it").apply {
            setReferenceCounted(false)
            acquire()
        }
        if (wifiLock?.isHeld != true) {
            wifiLock = wifi.createWifiLock(
                WifiManager.WIFI_MODE_FULL_HIGH_PERF,
                "shop-it-wifi",
            ).apply {
                setReferenceCounted(false)
                acquire()
            }
        }
    }

    private fun releaseMulticastLock() {
        multicastLock?.let { if (it.isHeld) it.release() }
        multicastLock = null
        wifiLock?.let { if (it.isHeld) it.release() }
        wifiLock = null
    }
}
