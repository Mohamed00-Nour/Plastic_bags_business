package com.store.store_manager

import io.flutter.embedding.android.FlutterActivity
import io.flutter.embedding.engine.FlutterEngine

class MainActivity : FlutterActivity() {
    override fun configureFlutterEngine(flutterEngine: FlutterEngine) {
        super.configureFlutterEngine(flutterEngine)
        WhatsappShareHandler.registerWith(flutterEngine.dartExecutor.binaryMessenger, context)
    }
}
