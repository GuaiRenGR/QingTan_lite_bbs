package com.qingtan.hjyzbbs

import android.app.Activity
import android.content.ActivityNotFoundException
import android.content.Intent
import android.net.Uri
import android.provider.OpenableColumns
import io.flutter.embedding.engine.FlutterEngine
import io.flutter.embedding.android.FlutterActivity
import io.flutter.plugin.common.MethodChannel
import java.io.File

class MainActivity : FlutterActivity() {
    companion object {
        private const val CHANNEL = "com.qingtan.hjyzbbs/document_picker"
        private const val PICK_DOCUMENT_REQUEST = 7201
        private const val CACHE_MAX_AGE_MS = 24L * 60L * 60L * 1000L
    }

    private var pendingPickerResult: MethodChannel.Result? = null

    override fun configureFlutterEngine(flutterEngine: FlutterEngine) {
        super.configureFlutterEngine(flutterEngine)

        MethodChannel(
            flutterEngine.dartExecutor.binaryMessenger,
            CHANNEL,
        ).setMethodCallHandler { call, result ->
            if (call.method != "pickDocument") {
                result.notImplemented()
                return@setMethodCallHandler
            }
            if (pendingPickerResult != null) {
                result.error("PICK_IN_PROGRESS", "已有文件选择窗口正在打开", null)
                return@setMethodCallHandler
            }

            val mimeType = call.argument<String>("mimeType")
                ?.takeIf { it.isNotBlank() }
                ?: "*/*"
            val mimeTypes = call.argument<List<String>>("mimeTypes")
                ?.filter { it.isNotBlank() }
                ?.distinct()
                .orEmpty()

            val intent = Intent(Intent.ACTION_OPEN_DOCUMENT).apply {
                addCategory(Intent.CATEGORY_OPENABLE)
                type = mimeType
                addFlags(Intent.FLAG_GRANT_READ_URI_PERMISSION)
                addFlags(Intent.FLAG_GRANT_PERSISTABLE_URI_PERMISSION)
                if (mimeTypes.isNotEmpty()) {
                    putExtra(Intent.EXTRA_MIME_TYPES, mimeTypes.toTypedArray())
                }
            }

            try {
                pendingPickerResult = result
                startActivityForResult(intent, PICK_DOCUMENT_REQUEST)
            } catch (_: ActivityNotFoundException) {
                pendingPickerResult = null
                result.error("NO_DOCUMENT_PICKER", "系统中没有可用的文件选择器", null)
            } catch (error: Throwable) {
                pendingPickerResult = null
                result.error("OPEN_DOCUMENT_FAILED", error.message, null)
            }
        }
    }

    @Deprecated("Deprecated in Java")
    override fun onActivityResult(requestCode: Int, resultCode: Int, data: Intent?) {
        super.onActivityResult(requestCode, resultCode, data)
        if (requestCode != PICK_DOCUMENT_REQUEST) return

        val result = pendingPickerResult ?: return
        pendingPickerResult = null

        if (resultCode != Activity.RESULT_OK) {
            result.success(null)
            return
        }

        val uri = data?.data
        if (uri == null) {
            result.error("EMPTY_DOCUMENT", "没有获取到所选文件", null)
            return
        }

        persistReadPermission(uri, data?.flags ?: 0)
        Thread {
            try {
                val selected = copyDocumentToCache(uri)
                runOnUiThread { result.success(selected) }
            } catch (error: Throwable) {
                runOnUiThread {
                    result.error("READ_DOCUMENT_FAILED", error.message, null)
                }
            }
        }.start()
    }

    private fun persistReadPermission(uri: Uri, resultFlags: Int) {
        val takeFlags = resultFlags and Intent.FLAG_GRANT_READ_URI_PERMISSION
        if (takeFlags == 0) return
        try {
            contentResolver.takePersistableUriPermission(uri, takeFlags)
        } catch (_: SecurityException) {
            // Some providers only grant access for the current process.
        }
    }

    private fun copyDocumentToCache(uri: Uri): Map<String, Any?> {
        val cacheDirectory = File(cacheDir, "selected_documents")
        if (!cacheDirectory.exists() && !cacheDirectory.mkdirs()) {
            throw IllegalStateException("无法创建文件选择缓存目录")
        }
        cleanupOldDocuments(cacheDirectory)

        val displayName = queryDisplayName(uri) ?: "document"
        val safeName = sanitizeFileName(displayName)
        val selectionDirectory = File(
            cacheDirectory,
            System.currentTimeMillis().toString(),
        )
        if (!selectionDirectory.mkdirs()) {
            throw IllegalStateException("无法创建临时文件目录")
        }
        val target = File(selectionDirectory, safeName)

        try {
            val input = contentResolver.openInputStream(uri)
                ?: throw IllegalStateException("无法读取所选文件")
            input.use { source ->
                target.outputStream().use { output ->
                    source.copyTo(output, 128 * 1024)
                }
            }
        } catch (error: Throwable) {
            selectionDirectory.deleteRecursively()
            throw error
        }

        return mapOf(
            "path" to target.absolutePath,
            "name" to displayName,
            "size" to target.length(),
            "mimeType" to contentResolver.getType(uri),
            "uri" to uri.toString(),
            "temporary" to true,
        )
    }

    private fun queryDisplayName(uri: Uri): String? {
        return contentResolver.query(
            uri,
            arrayOf(OpenableColumns.DISPLAY_NAME),
            null,
            null,
            null,
        )?.use { cursor ->
            if (!cursor.moveToFirst()) return@use null
            val index = cursor.getColumnIndex(OpenableColumns.DISPLAY_NAME)
            if (index < 0) null else cursor.getString(index)
        }
    }

    private fun sanitizeFileName(name: String): String {
        val sanitized = name.map { character ->
            if (character.isLetterOrDigit() || character in "._- ()[]") {
                character
            } else {
                '_'
            }
        }.joinToString("").trim().take(180)
        return sanitized.ifBlank { "document" }
    }

    private fun cleanupOldDocuments(directory: File) {
        val expiresBefore = System.currentTimeMillis() - CACHE_MAX_AGE_MS
        directory.listFiles()?.forEach { file ->
            if (file.lastModified() < expiresBefore) {
                file.deleteRecursively()
            }
        }
    }
}
