package com.prabincode.luminaexpense

import android.content.Intent
import android.net.Uri
import androidx.core.content.FileProvider
import io.flutter.embedding.android.FlutterFragmentActivity
import io.flutter.embedding.engine.FlutterEngine
import io.flutter.plugin.common.MethodChannel
import java.io.File

class MainActivity : FlutterFragmentActivity() {
    private val CHANNEL = "com.prabincode.luminaexpense/email"

    override fun configureFlutterEngine(flutterEngine: FlutterEngine) {
        super.configureFlutterEngine(flutterEngine)
        MethodChannel(flutterEngine.dartExecutor.binaryMessenger, CHANNEL).setMethodCallHandler { call, result ->
            if (call.method == "sendEmail") {
                val recipient = call.argument<String>("recipient") ?: "prabin@pcshrestha.com.np"
                val subject = call.argument<String>("subject") ?: ""
                val body = call.argument<String>("body") ?: ""
                val attachmentPath = call.argument<String?>("attachmentPath")

                try {
                    val intent = if (attachmentPath != null && File(attachmentPath).exists()) {
                        val file = File(attachmentPath)
                        val uri: Uri = FileProvider.getUriForFile(
                            this,
                            "${applicationContext.packageName}.fileprovider",
                            file
                        )
                        Intent(Intent.ACTION_SEND).apply {
                            type = "image/*"
                            putExtra(Intent.EXTRA_EMAIL, arrayOf(recipient))
                            putExtra(Intent.EXTRA_SUBJECT, subject)
                            putExtra(Intent.EXTRA_TEXT, body)
                            putExtra(Intent.EXTRA_STREAM, uri)
                            addFlags(Intent.FLAG_GRANT_READ_URI_PERMISSION)
                        }
                    } else {
                        val mailtoUri = Uri.parse("mailto:$recipient?subject=${Uri.encode(subject)}&body=${Uri.encode(body)}")
                        Intent(Intent.ACTION_SENDTO, mailtoUri)
                    }

                    val chooser = Intent.createChooser(intent, "Send Email via")
                    startActivity(chooser)
                    result.success(true)
                } catch (e: Exception) {
                    result.error("EMAIL_ERROR", e.message, null)
                }
            } else {
                result.notImplemented()
            }
        }
    }
}
