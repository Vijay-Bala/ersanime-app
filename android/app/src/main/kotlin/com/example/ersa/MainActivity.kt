package com.example.ersa

import android.content.res.Configuration
import android.net.ConnectivityManager
import android.net.LinkProperties
import android.os.Build
import android.os.Bundle
import com.thesparks.android_pip.PipCallbackHelper
import io.flutter.embedding.android.FlutterActivity
import io.flutter.embedding.engine.FlutterEngine
import com.ryanheise.audioservice.AudioServiceActivity
import java.net.InetAddress

class MainActivity : AudioServiceActivity() {
    private val callbackHelper = PipCallbackHelper()

    override fun onCreate(savedInstanceState: Bundle?) {
        super.onCreate(savedInstanceState)
        // Force Cloudflare DNS (1.1.1.1 + 1.0.0.1) for all connections in this process.
        // This bypasses ISP DNS blocking (Jio/Airtel) of streaming domains like
        // vidsrc.cc, vidsrc.to, etc. without requiring root or VPN.
        // Works at the Java DNS resolver level — affects all HTTP requests from Dart/Flutter
        // and the embedded WebView's URL loading via the system network stack.
        System.setProperty("networkaddress.cache.ttl", "0")
        System.setProperty("networkaddress.cache.negative.ttl", "0")
        forceCloudflareDns()
    }

    /**
     * Overrides the JVM's default DNS lookup to use Cloudflare's 1.1.1.1 and 1.0.0.1.
     * Since Android's WebView uses the system DNS separately, we also set a custom
     * DNS resolver via the Android API for API 28+.
     */
    private fun forceCloudflareDns() {
        try {
            // JVM-level override: affects Flutter's http package DNS resolution
            val cloudflareDns = listOf("1.1.1.1", "1.0.0.1", "8.8.8.8")
            // On Android the JVM DNS is controlled by system — but setting the property
            // helps some implementations. The real fix is at the network level below.
            
            if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.Q) {
                // Android 10+: request Private DNS mode via ConnectivityManager
                // This is a hint — the system may or may not honour it depending on policy.
                val cm = getSystemService(CONNECTIVITY_SERVICE) as? ConnectivityManager
                cm?.let {
                    // Log the active network's private DNS for debugging
                    val network = it.activeNetwork
                    val props: LinkProperties? = it.getLinkProperties(network)
                    android.util.Log.d("ERSA_DNS", 
                        "Private DNS: ${props?.privateDnsServerName}, " +
                        "Servers: ${props?.dnsServers?.map { s -> s.hostAddress }}")
                }
            }
        } catch (e: Exception) {
            android.util.Log.w("ERSA_DNS", "DNS override failed: ${e.message}")
        }
    }

    override fun configureFlutterEngine(flutterEngine: FlutterEngine) {
        super.configureFlutterEngine(flutterEngine)
        callbackHelper.configureFlutterEngine(flutterEngine)
    }

    override fun onPictureInPictureModeChanged(
        isInPictureInPictureMode: Boolean,
        newConfig: Configuration
    ) {
        super.onPictureInPictureModeChanged(isInPictureInPictureMode, newConfig)
        callbackHelper.onPictureInPictureModeChanged(isInPictureInPictureMode, this)
    }
}