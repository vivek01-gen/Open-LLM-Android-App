package com.openllm.app

import android.content.Intent
import android.os.Bundle
import io.flutter.embedding.android.FlutterActivity
import io.flutter.embedding.engine.FlutterEngine
import io.flutter.plugin.common.MethodChannel

class MainActivity : FlutterActivity() {
    private val channel = "open_llm/termux"

    override fun configureFlutterEngine(flutterEngine: FlutterEngine) {
        super.configureFlutterEngine(flutterEngine)
        MethodChannel(flutterEngine.dartExecutor.binaryMessenger, channel).setMethodCallHandler { call, result ->
            if (call.method != "runCommand") {
                result.notImplemented()
                return@setMethodCallHandler
            }
            val command = call.argument<String>("command")
            if (command.isNullOrBlank()) {
                result.error("INVALID_COMMAND", "Command is empty", null)
                return@setMethodCallHandler
            }
            try {
                val intent = Intent("com.termux.api.RUN_COMMAND")
                intent.setPackage("com.termux.api")
                if (packageManager.queryBroadcastReceivers(intent, 0).isEmpty()) {
                    result.success(false)
                    return@setMethodCallHandler
                }
                intent.putExtra("com.termux.api.RUN_COMMAND_PATH", "/data/data/com.termux/files/usr/bin/sh")
                intent.putExtra("com.termux.api.RUN_COMMAND_ARGUMENTS", arrayOf("-c", command))
                intent.putExtra("com.termux.api.RUN_COMMAND_BACKGROUND", true)
                sendBroadcast(intent)
                result.success(true)
            } catch (_: Exception) {
                result.success(false)
            }
        }
    }
}