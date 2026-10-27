package com.ropanasuri.siro_mobile

import android.app.AppOpsManager
import android.content.Context
import android.content.pm.PackageManager
import android.os.Build
import android.os.Process
import android.provider.Settings
import io.flutter.embedding.android.FlutterActivity
import io.flutter.embedding.engine.FlutterEngine
import io.flutter.plugin.common.MethodChannel
import java.io.File

class MainActivity : FlutterActivity() {
    private val CHANNEL = "com.siro/mock_detection"

    companion object {
        val FAKE_GPS_PACKAGES = arrayOf(
            "com.lexa.fakegps",
            "com.fakegps.location",
            "com.fly.gps",
            "com.locationchanger",
            "com.rosteam.gpsemulator",
            "com.incorporateapps.fakegps.fre",
            "com.incorporateapps.fakegps",
            "com.gpslocation.mock",
            "com.mockgpslocation",
            "com.gps.emulator",
            "com.gpsjoystick",
            "com.hopeway.fakegps",
            "com.gsmartstudio.fakegps",
            "com.app.fakegps",
            "com.evezzon.fakegps",
            "com.ninja.gogps",
            "com.theappninjas.fakegpsjoystick",
            "com.lkr.fakegps",
            "ru.gavrikov.mocklocations",
            "com.marlon.floating.fake.location",
            "com.xposed.fakemygps"
        )
    }

    override fun configureFlutterEngine(flutterEngine: FlutterEngine) {
        super.configureFlutterEngine(flutterEngine)

        MethodChannel(flutterEngine.dartExecutor.binaryMessenger, CHANNEL).setMethodCallHandler { call, result ->
            when (call.method) {
                "isDeveloperOptionsEnabled" -> {
                    result.success(isDeveloperOptionsEnabled())
                }
                "isMockLocationAppInstalled" -> {
                    result.success(isMockLocationAppInstalled())
                }
                "isMockLocationEnabled" -> {
                    result.success(isMockLocationEnabled())
                }
                "isDeviceRooted" -> {
                    result.success(isDeviceRooted())
                }
                "isEmulator" -> {
                    result.success(isEmulator())
                }
                else -> {
                    result.notImplemented()
                }
            }
        }
    }

    private fun isDeveloperOptionsEnabled(): Boolean {
        return try {
            Settings.Global.getInt(
                contentResolver,
                Settings.Global.DEVELOPMENT_SETTINGS_ENABLED,
                0
            ) != 0
        } catch (_: Exception) {
            false
        }
    }

    private fun isMockLocationAppInstalled(): Boolean {
        val pm = packageManager
        for (pkg in FAKE_GPS_PACKAGES) {
            try {
                pm.getPackageInfo(pkg, 0)
                return true
            } catch (_: PackageManager.NameNotFoundException) {
                // Not found
            } catch (_: Exception) {
                // Ignore
            }
        }
        return false
    }

    private fun isMockLocationEnabled(): Boolean {
        return try {
            if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.M) {
                val appOps = getSystemService(Context.APP_OPS_SERVICE) as? AppOpsManager
                if (appOps == null) return false

                val pm = packageManager
                for (pkg in FAKE_GPS_PACKAGES) {
                    try {
                        val packageInfo = pm.getPackageInfo(pkg, 0)
                        val appInfo = packageInfo.applicationInfo ?: continue
                        val mode = appOps.checkOpNoThrow(
                            AppOpsManager.OPSTR_MOCK_LOCATION,
                            appInfo.uid,
                            pkg
                        )
                        if (mode == AppOpsManager.MODE_ALLOWED) {
                            return true
                        }
                    } catch (_: Exception) {}
                }
                false
            } else {
                Settings.Secure.getString(contentResolver, Settings.Secure.ALLOW_MOCK_LOCATION) != "0"
            }
        } catch (_: Exception) {
            false
        }
    }

    private fun isDeviceRooted(): Boolean {
        val suPaths = arrayOf(
            "/system/app/Superuser.apk",
            "/sbin/su",
            "/system/bin/su",
            "/system/xbin/su",
            "/data/local/xbin/su",
            "/data/local/bin/su",
            "/system/sd/xbin/su",
            "/system/bin/failsafe/su",
            "/data/local/su",
            "/su/bin/su",
            "/data/adb/magisk",
            "/sbin/.magisk"
        )
        for (path in suPaths) {
            try {
                if (File(path).exists()) return true
            } catch (_: Exception) {}
        }

        val buildTags = Build.TAGS
        if (buildTags != null && buildTags.contains("test-keys")) {
            return true
        }

        return false
    }

    private fun isEmulator(): Boolean {
        return (Build.BRAND.startsWith("generic") && Build.DEVICE.startsWith("generic"))
                || Build.FINGERPRINT.startsWith("generic")
                || Build.FINGERPRINT.startsWith("unknown")
                || Build.HARDWARE.contains("goldfish")
                || Build.HARDWARE.contains("ranchu")
                || Build.HARDWARE.contains("vbox86")
                || Build.MODEL.contains("google_sdk")
                || Build.MODEL.contains("Emulator")
                || Build.MODEL.contains("Android SDK built for x86")
                || Build.MANUFACTURER.contains("Genymotion")
                || Build.PRODUCT.contains("sdk_google")
                || Build.PRODUCT.contains("google_sdk")
                || Build.PRODUCT.contains("sdk")
                || Build.PRODUCT.contains("vbox86p")
                || Build.PRODUCT.contains("emulator")
                || Build.PRODUCT.contains("simulator")
    }
}
