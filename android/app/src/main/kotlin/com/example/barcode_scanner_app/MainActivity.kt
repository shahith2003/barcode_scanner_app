package com.example.barcode_scanner_app

import android.content.BroadcastReceiver
import android.content.Context
import android.content.Intent
import android.content.IntentFilter
import android.os.Build
import android.os.Bundle
import android.util.Log
import io.flutter.embedding.android.FlutterActivity
import io.flutter.embedding.engine.FlutterEngine
import io.flutter.plugin.common.MethodChannel

class MainActivity : FlutterActivity() {

    private val channel = "com.example.barcode_scanner_app/scanner"
    private var methodChannel: MethodChannel? = null

    // ── Two receivers needed for Urovo DT50S ─────────────────────────────
    // Receiver 1: catches the BUTTON PRESS event (ACTION_KEYCODE_SCAN_PRESSED)
    // Receiver 2: catches the DECODE RESULT after laser reads the barcode
    private val buttonPressReceiver = object : BroadcastReceiver() {
        override fun onReceive(context: Context, intent: Intent) {
            Log.d("SCAN_DEBUG", "Button pressed: ${intent.action}")
            // Tell Flutter the physical button was pressed — open scanner UI
            runOnUiThread {
                methodChannel?.invokeMethod("onScanButtonPressed", null)
            }
        }
    }

    private val decodeResultReceiver = object : BroadcastReceiver() {
        override fun onReceive(context: Context, intent: Intent) {
            Log.d("SCAN_DEBUG", "Decode result received: ${intent.action}")

            // Log all extras to find the right key
            val extras = intent.extras
            if (extras != null) {
                for (key in extras.keySet()) {
                    Log.d("SCAN_DEBUG", "  Extra: $key = ${extras.get(key)}")
                }
            }

            // Try all known Urovo extra key names
            val barcodeValue: String? =
                intent.getStringExtra("barcode_string")
                    ?: intent.getStringExtra("BARCODE_STRING_TAG")
                    ?: intent.getStringExtra("barCodeValue")
                    ?: intent.getStringExtra("scannerdata")
                    ?: intent.getStringExtra("data")
                    ?: intent.getStringExtra("decode_data")
                    ?: intent.getStringExtra("EXTRA_BARCODE_DECODING_DATA")
                    ?: run {
                        val bytes = intent.getByteArrayExtra("barcode_bytes")
                            ?: intent.getByteArrayExtra("DECODE_DATA_TAG")
                        bytes?.let { String(it).trim() }
                    }

            if (!barcodeValue.isNullOrEmpty()) {
                Log.d("SCAN_DEBUG", "Barcode found: $barcodeValue")
                runOnUiThread {
                    methodChannel?.invokeMethod("onBarcodeScanned", barcodeValue)
                }
            }
        }
    }

    override fun configureFlutterEngine(flutterEngine: FlutterEngine) {
        super.configureFlutterEngine(flutterEngine)
        methodChannel = MethodChannel(
            flutterEngine.dartExecutor.binaryMessenger,
            channel
        )
        methodChannel?.setMethodCallHandler { _, result ->
            result.notImplemented()
        }
    }

    override fun onCreate(savedInstanceState: Bundle?) {
        super.onCreate(savedInstanceState)
        registerButtonReceiver()
        registerDecodeReceiver()
    }

    override fun onDestroy() {
        super.onDestroy()
        tryUnregister(buttonPressReceiver)
        tryUnregister(decodeResultReceiver)
    }

    // ── Register listener for BUTTON PRESS ───────────────────────────────
    // This is the action we confirmed from your logs
    private fun registerButtonReceiver() {
        val filter = IntentFilter()
        filter.addAction("ACTION_KEYCODE_SCAN_PRESSED")  // confirmed from your logs
        filter.priority = 1000

        if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.TIRAMISU) {
            registerReceiver(buttonPressReceiver, filter, RECEIVER_NOT_EXPORTED)
        } else {
            @Suppress("UnspecifiedRegisterReceiverFlag")
            registerReceiver(buttonPressReceiver, filter)
        }
        Log.d("SCAN_DEBUG", "Button press receiver registered")
    }

    // ── Register listener for DECODE RESULT ──────────────────────────────
    // All known Urovo decode result actions
    private fun registerDecodeReceiver() {
        val filter = IntentFilter()
        filter.addAction("android.intent.ACTION_DECODE_DATA")
        filter.addAction("com.android.server.scannerservice.broadcast")
        filter.addAction("urovo.rcv.message")
        filter.addAction("scan.rcv.message")
        filter.addAction("android.intent.action.DECODE_DATA")
        filter.addAction("ACTION_BARCODE_DATA")
        filter.addAction("device.scanner.SCAN_ACT")
        filter.priority = 1000

        if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.TIRAMISU) {
            registerReceiver(decodeResultReceiver, filter, RECEIVER_NOT_EXPORTED)
        } else {
            @Suppress("UnspecifiedRegisterReceiverFlag")
            registerReceiver(decodeResultReceiver, filter)
        }
        Log.d("SCAN_DEBUG", "Decode result receiver registered")
    }

    private fun tryUnregister(receiver: BroadcastReceiver) {
        try { unregisterReceiver(receiver) } catch (e: Exception) { }
    }
}