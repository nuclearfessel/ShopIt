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
                // A refused lock must not fail the call. Sharing still works,
                // and a thrown SecurityException was reaching the share dialog.
                try {
                    if (call.arguments == true) acquireMulticastLock() else releaseMulticastLock()
                } catch (_: RuntimeException) {
                }
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
                val args = call.arguments as? Map<*, *>
                val portrait = args?.get("portrait") == true
                val sync = args?.get("sync") == true
                if (portrait) {
                    try {
                        requestedOrientation =
                            android.content.pm.ActivityInfo.SCREEN_ORIENTATION_PORTRAIT
                    } catch (_: RuntimeException) {
                        // Phones are already locked to portrait. Android
                        // refuses another change on a non-opaque window, and
                        // that must not cancel the scan.
                    }
                }
                try {
                    scanResult = result
                    IntentIntegrator(this)
                        .setDesiredBarcodeFormats(
                            if (sync) listOf("QR_CODE") else IntentIntegrator.PRODUCT_CODE_TYPES,
                        )
                        .setPrompt(if (sync) "Scan the ShopIt QR code" else "Scan a barcode")
                        .setBeepEnabled(false)
                        .setOrientationLocked(portrait)
                        .initiateScan()
                } catch (error: RuntimeException) {
                    scanResult = null
                    result.error("scan", error.message, null)
                }
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
        val wifi = applicationContext.getSystemService(Context.WIFI_SERVICE) as WifiManager
        if (multicastLock?.isHeld != true) {
            try {
                multicastLock = wifi.createMulticastLock("shop-it").apply {
                    setReferenceCounted(false)
                    acquire()
                }
            } catch (_: RuntimeException) {
                multicastLock = null
            }
        }
        if (wifiLock?.isHeld == true) return
        // High-perf keeps the radio awake for UDP announcements. Newer
        // Android releases reject that mode, so the low-latency lock is tried
        // first. Either failure leaves the multicast lock in place.
        val modes = intArrayOf(
            WifiManager.WIFI_MODE_FULL_LOW_LATENCY,
            WifiManager.WIFI_MODE_FULL_HIGH_PERF,
        )
        for (mode in modes) {
            try {
                wifiLock = wifi.createWifiLock(mode, "shop-it-wifi").apply {
                    setReferenceCounted(false)
                    acquire()
                }
                return
            } catch (_: RuntimeException) {
                wifiLock = null
            }
        }
    }

    private fun releaseMulticastLock() {
        try {
            multicastLock?.let { if (it.isHeld) it.release() }
        } catch (_: RuntimeException) {
        }
        multicastLock = null
        try {
            wifiLock?.let { if (it.isHeld) it.release() }
        } catch (_: RuntimeException) {
        }
        wifiLock = null
    }
}
