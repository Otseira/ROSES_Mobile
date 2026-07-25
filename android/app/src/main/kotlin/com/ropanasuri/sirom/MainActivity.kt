package com.ropanasuri.sirom

import android.content.pm.PackageManager
import android.os.Build
import android.provider.Settings
import io.flutter.embedding.android.FlutterActivity
import io.flutter.embedding.engine.FlutterEngine
import io.flutter.plugin.common.MethodChannel

class MainActivity : FlutterActivity() {
    private val CHANNEL = "com.siro/mock_detection"

    private val fakeGpsPackages = listOf(
        "com.fakegps.location", "com.lexa.fakegps", "com.fly.gps",
        "com.locationchanger", "com.rosteam.gpsemulator",
        "com.incorporateapps.fakegps.fre", "com.gpslocation.mock",
        "com.mockgpslocation", "com.gps.emulator", "com.gpsjoystick"
    )

    override fun configureFlutterEngine(flutterEngine: FlutterEngine) {
        super.configureFlutterEngine(flutterEngine)
        MethodChannel(flutterEngine.dartExecutor.binaryMessenger, CHANNEL)
            .setMethodCallHandler { call, result ->
                when (call.method) {
                    "isDeveloperOptionsEnabled" -> result.success(isDevEnabled())
                    "isMockLocationAppInstalled" -> result.success(isFakeAppInstalled())
                    "isMockLocationEnabled" -> result.success(isMockEnabled())
                    else -> result.notImplemented()
                }
            }
    }

    private fun isDevEnabled(): Boolean = try {
        Settings.Secure.getInt(contentResolver, Settings.Global.DEVELOPMENT_SETTINGS_ENABLED) == 1
    } catch (e: Exception) { false }

    private fun isFakeAppInstalled(): Boolean {
        for (pkg in fakeGpsPackages) {
            try {
                packageManager.getPackageInfo(pkg, PackageManager.GET_ACTIVITIES)
                return true
            } catch (_: PackageManager.NameNotFoundException) { }
        }
        return false
    }

    private fun isMockEnabled(): Boolean = try {
        if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.M) {
            val ops = getSystemService(APP_OPS_SERVICE) as android.app.AppOpsManager
            ops.unsafeCheckOpNoThrow(
                "android:mock_location",
                android.os.Process.myUid(),
                packageName
            ) == android.app.AppOpsManager.MODE_ALLOWED
        } else {
            @Suppress("DEPRECATION")
            Settings.Secure.getString(contentResolver, "mock_location") != "0"
        }
    } catch (e: Exception) { false }
}
