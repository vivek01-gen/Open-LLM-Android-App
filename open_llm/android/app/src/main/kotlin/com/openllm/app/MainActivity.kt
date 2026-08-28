package com.openllm.app

import android.content.Intent
import android.net.Uri
import android.os.Bundle
import android.os.StatFs
import io.flutter.embedding.android.FlutterActivity
import io.flutter.embedding.engine.FlutterEngine
import io.flutter.plugin.common.MethodChannel

class MainActivity : FlutterActivity() {
    private val channel = "open_llm/termux"
    private val deviceChannel = "open_llm/device"
    private val modelServerChannel = "open_llm/model_server"
    private var serverProcess: Process? = null

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
        MethodChannel(flutterEngine.dartExecutor.binaryMessenger, deviceChannel).setMethodCallHandler { call, result ->
            if (call.method != "freeStorageBytes") {
                result.notImplemented()
                return@setMethodCallHandler
            }
            result.success(StatFs(filesDir.path).availableBytes)
        }
        MethodChannel(flutterEngine.dartExecutor.binaryMessenger, modelServerChannel).setMethodCallHandler { call, result ->
            when (call.method) {
                "start" -> {
                    val modelPath = call.argument<String>("modelPath")
                    val threads = call.argument<Int>("threads") ?: 1
                    val contextSize = call.argument<Int>("contextSize") ?: 2048
                    val endpoint = call.argument<String>("endpoint") ?: "http://127.0.0.1:8080"
                    val endpointUri = Uri.parse(endpoint)
                    val port = endpointUri.port.takeIf { it in 1..65535 } ?: 8080
                    if (modelPath.isNullOrBlank()) {
                        result.success(false)
                        return@setMethodCallHandler
                    }
                    if (endpointUri.scheme != "http" ||
                        endpointUri.host !in listOf("localhost", "127.0.0.1", "::1")) {
                        result.success(false)
                        return@setMethodCallHandler
                    }
                    val executable = java.io.File(filesDir, "bin/llama-server")
                    if (!executable.exists()) {
                        result.success(false)
                        return@setMethodCallHandler
                    }
                    try {
                        serverProcess?.destroy()
                        executable.setExecutable(true)
                        serverProcess = ProcessBuilder(
                            executable.absolutePath,
                            "--model", modelPath,
                            "--host", "127.0.0.1",
                            "--port", port.toString(),
                            "--threads", threads.toString(),
                            "--ctx-size", contextSize.toString(),
                            "--mmap"
                        ).redirectErrorStream(true).start()
                        serverProcess?.let { process ->
                            Thread {
                                process.inputStream.bufferedReader().useLines { lines ->
                                    lines.forEach { /* Keep the process pipe drained. */ }
                                }
                            }.apply { isDaemon = true }.start()
                        }
                        result.success(serverProcess?.let(::isProcessRunning) == true)
                    } catch (_: Exception) {
                        result.success(false)
                    }
                }
                "stop" -> {
                    serverProcess?.destroy()
                    serverProcess = null
                    result.success(null)
                }
                else -> result.notImplemented()
            }
        }
    }

    override fun onDestroy() {
        serverProcess?.destroy()
        serverProcess = null
        super.onDestroy()
    }

    private fun isProcessRunning(process: Process): Boolean {
        return try {
            process.exitValue()
            false
        } catch (_: IllegalThreadStateException) {
            true
        }
    }
}