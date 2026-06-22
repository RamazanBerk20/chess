package com.ramazan.chess

import android.content.Context
import android.net.wifi.WifiManager
import android.os.Bundle
import io.flutter.embedding.android.FlutterActivity

class MainActivity : FlutterActivity() {
    // mDNS (LAN game discovery) relies on multicast. Android's Wi-Fi driver
    // filters/throttles incoming multicast to save power unless a MulticastLock
    // is held — without it, finding a hosted game is very slow/unreliable. Hold
    // the lock for the activity's lifetime so browsing and hosting work promptly.
    private var multicastLock: WifiManager.MulticastLock? = null

    override fun onCreate(savedInstanceState: Bundle?) {
        super.onCreate(savedInstanceState)
        val wifi =
            applicationContext.getSystemService(Context.WIFI_SERVICE) as WifiManager
        multicastLock = wifi.createMulticastLock("chess-mdns").apply {
            setReferenceCounted(false)
            acquire()
        }
    }

    override fun onDestroy() {
        multicastLock?.let { if (it.isHeld) it.release() }
        multicastLock = null
        super.onDestroy()
    }
}
