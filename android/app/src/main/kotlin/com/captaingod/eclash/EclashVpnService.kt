package com.captaingod.eclash

import android.app.Notification
import android.app.NotificationChannel
import android.app.NotificationManager
import android.app.PendingIntent
import android.content.Intent
import android.content.pm.ApplicationInfo
import android.content.pm.PackageManager
import android.net.VpnService
import android.os.Build
import android.os.ParcelFileDescriptor
import androidx.core.app.NotificationCompat
import java.io.File

class EclashVpnService : VpnService() {

    companion object {
        const val ACTION_START = "com.captaingod.eclash.START_VPN"
        const val ACTION_STOP  = "com.captaingod.eclash.STOP_VPN"
        const val EXTRA_CONFIG = "config_path"
        const val CHANNEL_ID   = "eclash_vpn"
        var isRunning = false
    }

    private var vpnInterface: ParcelFileDescriptor? = null
    private var mihomoProcess: Process? = null

    override fun onStartCommand(intent: Intent?, flags: Int, startId: Int): Int {
        when (intent?.action) {
            ACTION_START -> {
                val configPath = intent.getStringExtra(EXTRA_CONFIG) ?: return START_NOT_STICKY
                startVpn(configPath)
            }
            ACTION_STOP -> stopVpn()
        }
        return START_STICKY
    }

    private fun startVpn(configPath: String) {
        createNotificationChannel()
        startForeground(1, buildNotification())

        vpnInterface = Builder()
            .setSession("Eclash")
            .addAddress("172.19.0.1", 30)
            .addDnsServer("8.8.8.8")
            .addDnsServer("1.1.1.1")
            .addRoute("0.0.0.0", 0)
            .setMtu(1500)
            .establish()

        val mihomoFile = getMihomoBinary()
        if (mihomoFile != null && mihomoFile.exists()) {
            mihomoFile.setExecutable(true)
            mihomoProcess = ProcessBuilder(mihomoFile.absolutePath, "-f", configPath)
                .redirectErrorStream(true)
                .start()
        }

        isRunning = true
    }

    private fun getMihomoBinary(): File? {
        return try {
            // 通过 PackageManager 显式获取 nativeLibDir，避免 Kotlin 类型推断问题
            val appInfo: ApplicationInfo = packageManager.getApplicationInfo(
                packageName, PackageManager.GET_META_DATA
            )
            File(appInfo.nativeLibDir, "libmihomo.so")
        } catch (e: Exception) {
            null
        }
    }

    private fun stopVpn() {
        mihomoProcess?.destroy()
        mihomoProcess = null
        vpnInterface?.close()
        vpnInterface = null
        isRunning = false
        stopForeground(STOP_FOREGROUND_REMOVE)
        stopSelf()
    }

    override fun onDestroy() {
        stopVpn()
        super.onDestroy()
    }

    private fun createNotificationChannel() {
        if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.O) {
            val channel = NotificationChannel(
                CHANNEL_ID, "Eclash VPN",
                NotificationManager.IMPORTANCE_LOW
            )
            getSystemService(NotificationManager::class.java)
                .createNotificationChannel(channel)
        }
    }

    private fun buildNotification(): Notification {
        val stopIntent = PendingIntent.getService(
            this, 0,
            Intent(this, EclashVpnService::class.java).apply { action = ACTION_STOP },
            PendingIntent.FLAG_IMMUTABLE
        )
        return NotificationCompat.Builder(this, CHANNEL_ID)
            .setContentTitle("Eclash 运行中")
            .setContentText("代理已连接，点击停止")
            .setSmallIcon(android.R.drawable.ic_dialog_info)
            .addAction(android.R.drawable.ic_delete, "停止", stopIntent)
            .build()
    }
}
