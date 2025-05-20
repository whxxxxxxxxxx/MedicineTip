package com.example.medicinetip

import android.content.pm.PackageManager
import io.flutter.embedding.android.FlutterActivity
import io.flutter.embedding.engine.FlutterEngine

class MainActivity : FlutterActivity() {
    private lateinit var microphonePermissionHandler: MicrophonePermissionHandler
    
    override fun configureFlutterEngine(flutterEngine: FlutterEngine) {
        super.configureFlutterEngine(flutterEngine)
        microphonePermissionHandler = MicrophonePermissionHandler(this)
        microphonePermissionHandler.registerWith(flutterEngine)
    }
    
    override fun onRequestPermissionsResult(requestCode: Int, permissions: Array<out String>, grantResults: IntArray) {
        super.onRequestPermissionsResult(requestCode, permissions, grantResults)
        microphonePermissionHandler.handlePermissionResult(requestCode, permissions, grantResults)
    }
}
