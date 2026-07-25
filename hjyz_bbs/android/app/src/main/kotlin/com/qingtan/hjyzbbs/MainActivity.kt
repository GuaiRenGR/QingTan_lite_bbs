package com.qingtan.hjyzbbs

import android.content.ContentValues
import android.content.Intent
import android.net.Uri
import android.os.Build
import android.os.Environment
import android.provider.DocumentsContract
import android.provider.MediaStore
import android.provider.Settings
import android.webkit.MimeTypeMap
import androidx.core.content.FileProvider
import io.flutter.embedding.android.FlutterActivity
import io.flutter.embedding.engine.FlutterEngine
import io.flutter.plugin.common.MethodChannel
import java.io.File

class MainActivity : FlutterActivity() {
    companion object {
        private const val CHANNEL = "com.qingtan.hjyzbbs/file_actions"
        private const val DOWNLOAD_FOLDER = "QingTan"
    }

    private data class PendingApk(val path: String, val contentUri: String?)

    private var pendingApk: PendingApk? = null

    override fun configureFlutterEngine(flutterEngine: FlutterEngine) {
        super.configureFlutterEngine(flutterEngine)
        MethodChannel(
            flutterEngine.dartExecutor.binaryMessenger,
            CHANNEL,
        ).setMethodCallHandler { call, result ->
            when (call.method) {
                "publishDownload" -> {
                    val path = call.argument<String>("path").orEmpty()
                    val fileName = call.argument<String>("fileName").orEmpty()
                    Thread {
                        try {
                            val uri = publishDownload(path, fileName)
                            runOnUiThread {
                                result.success(
                                    mapOf(
                                        "status" to "done",
                                        "uri" to uri.toString(),
                                        "displayPath" to "Download/$DOWNLOAD_FOLDER/$fileName",
                                    ),
                                )
                            }
                        } catch (error: Throwable) {
                            runOnUiThread {
                                result.error("PUBLISH_FAILED", error.message, null)
                            }
                        }
                    }.start()
                }

                "openFile" -> {
                    val path = call.argument<String>("path").orEmpty()
                    val contentUri = call.argument<String>("contentUri")
                    try {
                        result.success(openFile(path, contentUri))
                    } catch (error: Throwable) {
                        result.error("OPEN_FAILED", error.message, null)
                    }
                }

                "openFolder" -> {
                    try {
                        openDownloadFolder()
                        result.success(
                            mapOf("status" to "done", "message" to "已打开下载目录"),
                        )
                    } catch (error: Throwable) {
                        result.error("OPEN_FOLDER_FAILED", error.message, null)
                    }
                }

                else -> result.notImplemented()
            }
        }
    }

    override fun onResume() {
        super.onResume()
        val pending = pendingApk ?: return
        if (Build.VERSION.SDK_INT < Build.VERSION_CODES.O ||
            packageManager.canRequestPackageInstalls()
        ) {
            pendingApk = null
            try {
                launchFile(pending.path, pending.contentUri, isApk = true)
            } catch (_: Throwable) {
            }
        }
    }

    private fun publishDownload(path: String, fileName: String): Uri {
        val source = File(path)
        require(source.isFile) { "下载文件不存在" }
        require(fileName.isNotBlank()) { "文件名不能为空" }

        if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.Q) {
            val values = ContentValues().apply {
                put(MediaStore.Downloads.DISPLAY_NAME, fileName)
                put(MediaStore.Downloads.MIME_TYPE, mimeType(fileName))
                put(
                    MediaStore.Downloads.RELATIVE_PATH,
                    "${Environment.DIRECTORY_DOWNLOADS}/$DOWNLOAD_FOLDER",
                )
                put(MediaStore.Downloads.IS_PENDING, 1)
            }
            val collection = MediaStore.Downloads.getContentUri(
                MediaStore.VOLUME_EXTERNAL_PRIMARY,
            )
            val uri = contentResolver.insert(collection, values)
                ?: error("无法创建公共下载文件")
            try {
                contentResolver.openOutputStream(uri)?.use { output ->
                    source.inputStream().use { input -> input.copyTo(output) }
                } ?: error("无法写入公共下载文件")
                values.clear()
                values.put(MediaStore.Downloads.IS_PENDING, 0)
                contentResolver.update(uri, values, null, null)
                return uri
            } catch (error: Throwable) {
                contentResolver.delete(uri, null, null)
                throw error
            }
        }

        val directory = File(
            Environment.getExternalStoragePublicDirectory(Environment.DIRECTORY_DOWNLOADS),
            DOWNLOAD_FOLDER,
        )
        if (!directory.exists() && !directory.mkdirs()) {
            error("无法创建公共下载目录")
        }
        val target = File(directory, fileName)
        source.copyTo(target, overwrite = true)
        return FileProvider.getUriForFile(
            this,
            "$packageName.file_provider",
            target,
        )
    }

    private fun openFile(path: String, contentUri: String?): Map<String, String> {
        val isApk = path.endsWith(".apk", ignoreCase = true)
        if (isApk && Build.VERSION.SDK_INT >= Build.VERSION_CODES.O &&
            !packageManager.canRequestPackageInstalls()
        ) {
            pendingApk = PendingApk(path, contentUri)
            startActivity(
                Intent(
                    Settings.ACTION_MANAGE_UNKNOWN_APP_SOURCES,
                    Uri.parse("package:$packageName"),
                ),
            )
            return mapOf(
                "status" to "permission_requested",
                "message" to "请允许安装未知应用，授权后将自动继续",
            )
        }

        launchFile(path, contentUri, isApk)
        return mapOf("status" to "done", "message" to "请选择要使用的应用")
    }

    private fun launchFile(path: String, contentUri: String?, isApk: Boolean) {
        val uri = contentUri
            ?.takeIf { it.startsWith("content://") }
            ?.let(Uri::parse)
            ?: FileProvider.getUriForFile(
                this,
                "$packageName.file_provider",
                File(path),
            )
        val type = if (isApk) {
            "application/vnd.android.package-archive"
        } else {
            mimeType(path)
        }
        val intent = Intent(Intent.ACTION_VIEW).apply {
            setDataAndType(uri, type)
            addFlags(Intent.FLAG_GRANT_READ_URI_PERMISSION)
        }
        startActivity(Intent.createChooser(intent, "使用其他应用打开"))
    }

    private fun openDownloadFolder() {
        val folderUri = DocumentsContract.buildDocumentUri(
            "com.android.externalstorage.documents",
            "primary:${Environment.DIRECTORY_DOWNLOADS}/$DOWNLOAD_FOLDER",
        )
        val viewIntent = Intent(Intent.ACTION_VIEW).apply {
            setDataAndType(folderUri, DocumentsContract.Document.MIME_TYPE_DIR)
            addFlags(Intent.FLAG_GRANT_READ_URI_PERMISSION)
        }
        try {
            startActivity(viewIntent)
        } catch (_: Throwable) {
            val picker = Intent(Intent.ACTION_OPEN_DOCUMENT_TREE).apply {
                if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.O) {
                    putExtra(DocumentsContract.EXTRA_INITIAL_URI, folderUri)
                }
            }
            startActivity(picker)
        }
    }

    private fun mimeType(name: String): String {
        val extension = name.substringAfterLast('.', "").lowercase()
        return MimeTypeMap.getSingleton().getMimeTypeFromExtension(extension)
            ?: "application/octet-stream"
    }
}
