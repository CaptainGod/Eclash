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

        // 1. 创建 TUN 接口，排除本应用自身流量防止路由环
        val pfd = Builder()
            .setSession("Eclash")
            .addAddress("198.18.0.1", 16)
            .addDnsServer("198.18.0.2")
            .addRoute("0.0.0.0", 0)
            .setMtu(1500)
            .addDisallowedApplication(packageName)
            .establish() ?: run { stopSelf(); return }

        vpnInterface = pfd

        // 2. 清除 FD_CLOEXEC，让 mihomo 子进程继承此 fd
        // Os.fcntl 是 @hide API，通过反射调用绕过编译限制
        clearCloseOnExec(pfd)

        // 3. 将 fd 注入配置，写入 filesDir（不用 cacheDir，避免被系统清除）
        val runtimeConfig = buildRuntimeConfig(configPath, pfd.fd)

        // 4. 启动 mihomo，-d 指定 home 目录，rule-providers 等相对路径才能正确解析
        val mihomo = getBinaryFile("libmihomo.so") ?: run {
            pfd.close()
            stopSelf()
            return
        }
        mihomoProcess = ProcessBuilder(
            mihomo.absolutePath,
            "-d", filesDir.absolutePath,   // home dir：rule-providers / store-selected / store-fake-ip 都写这里
            "-f", runtimeConfig
        )
            .redirectErrorStream(true)
            .start()

        isRunning = true

        // 5. 后台线程监控 mihomo 进程，崩溃时自动清理状态
        Thread {
            try {
                mihomoProcess?.waitFor()
            } catch (_: InterruptedException) {
                return@Thread
            }
            // 走到这里说明进程已退出；若非主动 stop（isRunning 仍为 true）则是崩溃
            if (isRunning) {
                isRunning = false
                vpnInterface?.close()
                vpnInterface = null
                mihomoProcess = null
                stopForeground(STOP_FOREGROUND_REMOVE)
                stopSelf()
            }
        }.apply { isDaemon = true; start() }
    }

    /**
     * 剥离原配置中已有的 tun: 块（如有），追加以当前 TUN fd 为核心的原生 TUN 配置。
     * 写入 filesDir/runtime_config.yaml 并返回路径。
     */
    private fun buildRuntimeConfig(basePath: String, tunFd: Int): String {
        val lines = File(basePath).readLines()
        val out = mutableListOf<String>()
        var inTunBlock = false

        for (line in lines) {
            val isRootKey = line.isNotEmpty() && !line[0].isWhitespace() && !line.startsWith('#')
            when {
                line.startsWith("tun:") -> inTunBlock = true
                inTunBlock && isRootKey -> { inTunBlock = false; out.add(line) }
                !inTunBlock -> out.add(line)
            }
        }

        out += listOf(
            "",
            "tun:",
            "  enable: true",
            "  stack: gvisor",
            "  dns-hijack:",
            "    - any:53",
            "  auto-route: false",   // 路由已由 VpnService.Builder 接管
            "  fd: $tunFd",          // 直接复用 Android VPN 创建的 TUN fd
        )

        val tmp = File(filesDir, "runtime_config.yaml")
        tmp.writeText(out.joinToString("\n"))
        return tmp.absolutePath
    }

    private fun clearCloseOnExec(pfd: ParcelFileDescriptor) {
        try {
            val osClass = Class.forName("android.system.Os")
            val fcntl = osClass.getMethod(
                "fcntl",
                java.io.FileDescriptor::class.java,
                Int::class.javaPrimitiveType,
                Int::class.javaPrimitiveType,
            )
            val flags = fcntl.invoke(null, pfd.fileDescriptor, OsConstants.F_GETFD, 0) as Int
            fcntl.invoke(null, pfd.fileDescriptor, OsConstants.F_SETFD, flags and OsConstants.FD_CLOEXEC.inv())
        } catch (_: Exception) {}
    }

    private fun getBinaryFile(libName: String): File? {
        return try {
            val appInfo = packageManager.getApplicationInfo(packageName, PackageManager.GET_META_DATA)
            val nativeDir = appInfo.javaClass.getField("nativeLibDir").get(appInfo) as? String
                ?: return null
            val file = File(nativeDir, libName)
            if (file.exists()) { file.setExecutable(true); file } else null
        } catch (_: Exception) { null }
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
            getSystemService(NotificationManager::class.java).createNotificationChannel(channel)
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
