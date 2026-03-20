package com.captaingod.eclash

import android.app.Activity
import android.content.Intent
import android.net.VpnService
import io.flutter.embedding.android.FlutterActivity
import io.flutter.embedding.engine.FlutterEngine
import io.flutter.plugin.common.MethodChannel

class MainActivity : FlutterActivity() {

    companion object {
        const val CHANNEL = "com.captaingod.eclash/vpn"
        const val VPN_REQUEST_CODE = 100
    }

    private lateinit var methodChannel: MethodChannel
    private var pendingResult: MethodChannel.Result? = null

    override fun configureFlutterEngine(flutterEngine: FlutterEngine) {
        super.configureFlutterEngine(flutterEngine)

        methodChannel = MethodChannel(
            flutterEngine.dartExecutor.binaryMessenger, CHANNEL
        )

        methodChannel.setMethodCallHandler { call, result ->
            when (call.method) {
                "startVpn" -> {
                    val configPath = call.argument<String>("configPath") ?: run {
                        result.error("INVALID_ARG", "configPath required", null)
                        return@setMethodCallHandler
                    }
                    val intent = VpnService.prepare(this)
                    if (intent != null) {
                        // 需要用户授权 VPN
                        pendingResult = result
                        // 保存 configPath 供授权回调使用
                        this.pendingConfigPath = configPath
                        startActivityForResult(intent, VPN_REQUEST_CODE)
                    } else {
                        // 已有权限，直接启动
                        doStartVpn(configPath)
                        result.success(true)
                    }
                }
                "stopVpn" -> {
                    val stopIntent = Intent(this, EclashVpnService::class.java).apply {
                        action = EclashVpnService.ACTION_STOP
                    }
                    startService(stopIntent)
                    result.success(true)
                }
                "isRunning" -> {
                    result.success(EclashVpnService.isRunning)
                }
                else -> result.notImplemented()
            }
        }
    }

    private var pendingConfigPath: String = ""

    override fun onActivityResult(requestCode: Int, resultCode: Int, data: Intent?) {
        super.onActivityResult(requestCode, resultCode, data)
        if (requestCode == VPN_REQUEST_CODE) {
            if (resultCode == Activity.RESULT_OK) {
                doStartVpn(pendingConfigPath)
                pendingResult?.success(true)
            } else {
                pendingResult?.success(false)
            }
            pendingResult = null
        }
    }

    private fun doStartVpn(configPath: String) {
        val intent = Intent(this, EclashVpnService::class.java).apply {
            action = EclashVpnService.ACTION_START
            putExtra(EclashVpnService.EXTRA_CONFIG, configPath)
        }
        startService(intent)
    }
}
