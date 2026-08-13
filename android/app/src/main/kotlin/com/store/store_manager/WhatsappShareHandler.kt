package com.store.store_manager

import android.content.Context
import android.content.Intent
import android.net.Uri
import androidx.core.content.FileProvider
import io.flutter.plugin.common.BinaryMessenger
import io.flutter.plugin.common.MethodCall
import io.flutter.plugin.common.MethodChannel
import java.io.File
import java.util.ArrayList

class WhatsappShareHandler(private val context: Context) : MethodChannel.MethodCallHandler {
    companion object {
        private const val CHANNEL = "app.store/whatsapp"

        fun registerWith(messenger: BinaryMessenger, context: Context) {
            val channel = MethodChannel(messenger, CHANNEL)
            channel.setMethodCallHandler(WhatsappShareHandler(context))
        }
    }

    override fun onMethodCall(call: MethodCall, result: MethodChannel.Result) {
        if (call.method == "shareImages") {
            try {
                val rawPhone = call.argument<String>("phone") ?: ""
                val paths = call.argument<List<String>>("paths") ?: emptyList()
                val text = call.argument<String>("text") ?: ""

                if (paths.isEmpty()) {
                    result.error("NO_PATHS", "No image file paths provided", null)
                    return
                }

                // Clean phone digits (e.g., 01126697513 -> 201126697513)
                var cleanDigits = rawPhone.replace(Regex("[^0-9]"), "")
                if (cleanDigits.startsWith("01") && cleanDigits.length == 11) {
                    cleanDigits = "2$cleanDigits"
                }

                val jid = if (cleanDigits.isNotEmpty()) "$cleanDigits@s.whatsapp.net" else ""

                val imageUris = ArrayList<Uri>()
                val authority = "${context.packageName}.fileProvider"

                for (path in paths) {
                    val file = File(path)
                    if (file.exists()) {
                        val uri = FileProvider.getUriForFile(context, authority, file)
                        imageUris.add(uri)
                    }
                }

                if (imageUris.isEmpty()) {
                    result.error("FILE_NOT_FOUND", "Image files do not exist", null)
                    return
                }

                val firstPath = paths.firstOrNull()?.lowercase() ?: ""
                val mimeType = when {
                    firstPath.endsWith(".pdf") -> "application/pdf"
                    firstPath.endsWith(".jpg") || firstPath.endsWith(".jpeg") -> "image/jpeg"
                    else -> "image/png"
                }

                val intent = if (imageUris.size == 1) {
                    Intent(Intent.ACTION_SEND).apply {
                        type = mimeType
                        putExtra(Intent.EXTRA_STREAM, imageUris[0])
                    }
                } else {
                    Intent(Intent.ACTION_SEND_MULTIPLE).apply {
                        type = mimeType
                        putParcelableArrayListExtra(Intent.EXTRA_STREAM, imageUris)
                    }
                }

                if (text.isNotEmpty()) {
                    intent.putExtra(Intent.EXTRA_TEXT, text)
                }

                if (jid.isNotEmpty()) {
                    intent.putExtra("jid", jid)
                }

                intent.addFlags(Intent.FLAG_GRANT_READ_URI_PERMISSION)
                intent.addFlags(Intent.FLAG_ACTIVITY_NEW_TASK)

                val packageManager = context.packageManager
                val whatsappPackage = "com.whatsapp"
                val whatsappBusinessPackage = "com.whatsapp.w4b"

                val isStandardInstalled = try {
                    packageManager.getPackageInfo(whatsappPackage, 0)
                    true
                } catch (e: Exception) {
                    false
                }

                val isBusinessInstalled = try {
                    packageManager.getPackageInfo(whatsappBusinessPackage, 0)
                    true
                } catch (e: Exception) {
                    false
                }

                val targetPackage = when {
                    isStandardInstalled -> whatsappPackage
                    isBusinessInstalled -> whatsappBusinessPackage
                    else -> null
                }

                if (targetPackage != null) {
                    intent.setPackage(targetPackage)
                }

                context.startActivity(intent)
                result.success(true)
            } catch (e: Exception) {
                result.error("SHARE_FAILED", e.localizedMessage, null)
            }
        } else {
            result.notImplemented()
        }
    }
}
