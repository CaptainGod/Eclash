package com.captaingod.eclash

import android.app.Notification
import android.app.NotificationChannel
import android.app.NotificationManager
import android.app.PendingIntent
import android.content.Intent
import android.content.pm.PackageManager
import android.net.VpnService
import android.os.Build
import android.os.ParcelFileDescriptor
import android.system.Os
import android.system.OsConstants
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
    private var tun2socksProcess: Process? = null

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

        // 排除本应用自身流量，防止 mihomo 出站流量被 VPN 再次捕获形成路由环
        val pfd = Builder()
            .setSession("Eclash")
            .addAddress("198.18.0.1", 16)
            .addDnsServer("198.18.0.2")
            .addRoute("0.0.0.0", 0)
            .setMtu(1500)
            .addDisallowedApplication(packageName)
            .establish() ?: run { stopSelf(); return }

        vpnInterface = pfd

        // 清除 CLOEXEC 标志，让子进程能继承此 fd
        try {
            val flags = Os.fcntl(pfd.fileDescriptor, OsConstants.F_GETFD, 0)
            Os.fcntl(pfd.fileDescriptor, OsConstants.F_SETFD,
                flags and OsConstants.FD_CLOEXEC.inv())
        } catch (_: Exception) {}

        val tunFd = pfd.fd

        // 启动 mihomo（HTTP + SOCKS5 代理模式，不使用 TUN）
        val mihomo = getBinaryFile("libmihomo.so")
        if (mihomo != null) {
            mihomoProcess = ProcessBuilder(mihomo.absolutePath, "-f", configPath)
                .redirectErrorStream(true)
                .start()
        }

        // 等待 mihomo 启动完成
        Thread.sleep(1500)

        // 启动 tun2socks：将 TUN fd 的流量转发到 mihomo 的 SOCKS5 端口
        // 流量路径: 其他 App → VPN TUN → tun2socks → mihomo:7891 → 代理服务器
        val tun2socks = getBinaryFile("libtun2socks.so")
        if (tun2socks != null) {
            tun2socksProcess = ProcessBuilder(
                tun2socks.absolutePath,
                "-device", "fd://$tunFd",
                "-proxy", "socks5://127.0.0.1:7891",
                "-loglevel", "warning"
            )
                .redirectErrorStream(true)
                .start()
        }

        isRunning = true
    }

    private fun getBinaryFile(libName: String): File? {
        return try {
            val appInfo = packageManager.getApplicationInfo(packageName, PackageManager.GET_META_DATA)
            val nativeDir = appInfo.javaClass.getField("nativeLibDir").get(appInfo) as? String
                ?: return null
            val file = File(nativeDir, libName)
            if (file.exists()) {
                file.setExecutable(true)
                file
            } else null
        } catch (_: Exception) { null }
    }

    private fun stopVpn() {
        tun2socksProcess?.destroy()
        tun2socksProcess = null
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
