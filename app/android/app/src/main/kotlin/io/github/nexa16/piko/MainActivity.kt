package io.github.nexa16.piko

import android.app.ActivityManager
import android.content.BroadcastReceiver
import android.content.ComponentName
import android.content.Context
import android.content.Intent
import android.content.IntentFilter
import android.os.Build
import android.os.Bundle
import io.flutter.embedding.android.FlutterActivity
import io.flutter.embedding.engine.FlutterEngine
import io.flutter.plugin.common.EventChannel

class MainActivity : FlutterActivity() {
    private var aiVault: AiCredentialVault? = null
    private var clockChannel: EventChannel? = null
    private var clockReceiver: BroadcastReceiver? = null

    override fun onCreate(savedInstanceState: Bundle?) {
        super.onCreate(savedInstanceState)
        removeObsoleteEmptyTasks()
    }

    private fun removeObsoleteEmptyTasks() {
        // Older Android releases cannot prove numActivities through TaskInfo.
        // Preserve their history rather than guessing whether a task is empty.
        if (Build.VERSION.SDK_INT < Build.VERSION_CODES.Q || !isTaskRoot) return
        val manager = getSystemService(Context.ACTIVITY_SERVICE) as? ActivityManager ?: return
        val tasks = try {
            manager.appTasks
        } catch (_: SecurityException) {
            return
        }
        for (task in tasks) {
            try {
                if (!isObsoleteEmptyTask(task.taskInfo)) continue
                // The list may be stale by now. Never finish an old task that
                // acquired an activity while this launch was being created.
                if (isObsoleteEmptyTask(task.taskInfo)) task.finishAndRemoveTask()
            } catch (_: IllegalArgumentException) {
                // Android/launcher already removed this recent-task record.
            } catch (_: SecurityException) {
                // Access/ownership changed while reading the task snapshot.
            }
        }
    }

    @android.annotation.TargetApi(Build.VERSION_CODES.Q)
    private fun isObsoleteEmptyTask(info: ActivityManager.RecentTaskInfo?): Boolean {
        if (info == null || info.taskId == taskId || info.numActivities != 0 ||
            info.isRunning || info.baseActivity != null || info.topActivity != null) return false
        val ownActivity = ComponentName(this, MainActivity::class.java)
        val component = info.baseIntent.component ?: return false
        return component.packageName == packageName && component == ownActivity
    }

    private fun stopClockReceiver() {
        clockReceiver?.let { unregisterReceiver(it) }
        clockReceiver = null
    }

    override fun configureFlutterEngine(flutterEngine: FlutterEngine) {
        super.configureFlutterEngine(flutterEngine)
        aiVault = AiCredentialVault(this, flutterEngine.dartExecutor.binaryMessenger)
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
        aiVault?.close()
        aiVault = null
        stopClockReceiver()
        clockChannel?.setStreamHandler(null)
        clockChannel = null
        super.cleanUpFlutterEngine(flutterEngine)
    }
}
