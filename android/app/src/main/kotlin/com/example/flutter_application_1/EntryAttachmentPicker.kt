package com.example.flutter_application_1

import android.app.Activity
import android.content.Intent
import android.net.Uri
import android.os.Handler
import android.os.Looper
import android.provider.OpenableColumns
import android.webkit.MimeTypeMap
import androidx.activity.result.contract.ActivityResultContracts
import androidx.fragment.app.FragmentActivity
import io.flutter.plugin.common.BinaryMessenger
import io.flutter.plugin.common.MethodChannel
import java.io.File
import java.io.FileNotFoundException
import java.util.Locale

internal class EntryAttachmentPicker(private val activity: FragmentActivity) {
    private data class Request(
        val result: MethodChannel.Result,
        val extensions: Set<String>,
        val maxBytes: Long,
    )

    private var pending: Request? = null
    private val mainHandler = Handler(Looper.getMainLooper())
    private val launcher = activity.registerForActivityResult(
        ActivityResultContracts.StartActivityForResult(),
    ) { selection ->
        val request = pending ?: return@registerForActivityResult
        val data = selection.data
        if (selection.resultCode != Activity.RESULT_OK || data == null) {
            pending = null
            request.result.success(emptyList<Any>())
            return@registerForActivityResult
        }

        val uris = linkedSetOf<Uri>()
        val clip = data.clipData
        if (clip != null) {
            for (index in 0 until clip.itemCount) {
                clip.getItemAt(index).uri?.let { uris.add(it) }
            }
        }
        data.data?.let { uris.add(it) }

        // Keep provider reads and copies off Android's main thread.
        Thread({
            val files = uris.map { copyAttachment(it, request) }
            mainHandler.post {
                pending = null
                request.result.success(files)
            }
        }, "entry-attachment-import").start()
    }

    fun register(messenger: BinaryMessenger) {
        MethodChannel(messenger, "entries/attachment_picker").setMethodCallHandler { call, result ->
            if (call.method != "pick") {
                result.notImplemented()
                return@setMethodCallHandler
            }
            if (pending != null) {
                result.error("picker_busy", null, null)
                return@setMethodCallHandler
            }
            val extensions = call.argument<List<String>>("extensions").orEmpty().toSet()
            val mimeTypes = call.argument<List<String>>("mimeTypes").orEmpty().toMutableSet()
            val typeMap = MimeTypeMap.getSingleton()
            mimeTypes.addAll(extensions.mapNotNull(typeMap::getMimeTypeFromExtension))
            val request = Request(
                result,
                extensions,
                call.argument<Int>("maxBytes")?.toLong() ?: 0L,
            )
            val intent = Intent(Intent.ACTION_OPEN_DOCUMENT).apply {
                addCategory(Intent.CATEGORY_OPENABLE)
                type = "*/*"
                putExtra(Intent.EXTRA_MIME_TYPES, mimeTypes.toTypedArray())
                putExtra(Intent.EXTRA_ALLOW_MULTIPLE, true)
            }
            pending = request
            try {
                launcher.launch(intent)
            } catch (_: Exception) {
                pending = null
                result.error("picker_unavailable", null, null)
            }
        }
    }

    private fun copyAttachment(uri: Uri, request: Request): Map<String, String> {
        val context = activity.applicationContext
        val resolver = context.contentResolver
        val skipped = mapOf("status" to "skipped")
        var temporary: File? = null
        var complete = false
        try {
            var name = uri.lastPathSegment.orEmpty().substringAfterLast('/')
            resolver.query(
                uri,
                arrayOf(OpenableColumns.DISPLAY_NAME, OpenableColumns.SIZE),
                null,
                null,
                null,
            )?.use { cursor ->
                if (cursor.moveToFirst()) {
                    val nameColumn = cursor.getColumnIndex(OpenableColumns.DISPLAY_NAME)
                    if (nameColumn >= 0 && !cursor.isNull(nameColumn)) {
                        name = cursor.getString(nameColumn)
                    }
                    val sizeColumn = cursor.getColumnIndex(OpenableColumns.SIZE)
                    if (sizeColumn >= 0 && !cursor.isNull(sizeColumn) &&
                        cursor.getLong(sizeColumn) > request.maxBytes
                    ) {
                        return skipped
                    }
                }
            }
            val extension = name.substringAfterLast('.', "").lowercase(Locale.ROOT)
            if (extension !in request.extensions) return skipped

            val file = File.createTempFile("entry-attachment-", ".$extension", context.cacheDir)
            temporary = file
            val source = resolver.openInputStream(uri) ?: throw FileNotFoundException()
            source.use { input ->
                file.outputStream().use { output ->
                    val buffer = ByteArray(DEFAULT_BUFFER_SIZE)
                    var total = 0L
                    while (true) {
                        val count = input.read(buffer)
                        if (count < 0) break
                        total += count
                        if (total > request.maxBytes) return skipped
                        output.write(buffer, 0, count)
                    }
                }
            }
            complete = true
            return mapOf("path" to file.absolutePath, "name" to name)
        } catch (_: Exception) {
            return mapOf("status" to "unreadable")
        } finally {
            if (!complete) temporary?.delete()
        }
    }
}
