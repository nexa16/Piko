package io.github.nexa16.piko

import android.content.BroadcastReceiver
import android.content.Context
import android.content.Intent
import android.content.IntentFilter
import android.os.Build
import io.flutter.embedding.android.FlutterActivity
import io.flutter.embedding.engine.FlutterEngine
import io.flutter.plugin.common.EventChannel

class MainActivity : FlutterActivity() {
    private var clockChannel: EventChannel? = null
    private var clockReceiver: BroadcastReceiver? = null

    private fun stopClockReceiver() {
        clockReceiver?.let { unregisterReceiver(it) }
        clockReceiver = null
    }

    override fun configureFlutterEngine(flutterEngine: FlutterEngine) {
        super.configureFlutterEngine(flutterEngine)
        clockChannel = EventChannel(flutterEngine.dartExecutor.binaryMessenger, "piko/clock_changes")
        clockChannel?.setStreamHandler(object : EventChannel.StreamHandler {
            override fun onListen(arguments: Any?, events: EventChannel.EventSink) {
                stopClockReceiver()
                val receiver = object : BroadcastReceiver() {
                    override fun onReceive(context: Context?, intent: Intent?) {
                        events.success(null)
                    }
                }
                val filter = IntentFilter().apply {
                    addAction(Intent.ACTION_TIME_CHANGED)
                    addAction(Intent.ACTION_TIMEZONE_CHANGED)
                    addAction(Intent.ACTION_DATE_CHANGED)
                }
                if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.TIRAMISU) {
                    registerReceiver(receiver, filter, Context.RECEIVER_NOT_EXPORTED)
                } else {
                    @Suppress("DEPRECATION")
                    registerReceiver(receiver, filter)
                }
                clockReceiver = receiver
            }

            override fun onCancel(arguments: Any?) = stopClockReceiver()
        })
    }

    override fun cleanUpFlutterEngine(flutterEngine: FlutterEngine) {
        stopClockReceiver()
        clockChannel?.setStreamHandler(null)
        clockChannel = null
        super.cleanUpFlutterEngine(flutterEngine)
    }
}
