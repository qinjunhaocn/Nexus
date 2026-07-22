package com.voxyn.nexus

import android.app.Activity
import android.content.Intent
import android.net.Uri
import android.os.Handler
import android.os.Looper
import io.flutter.embedding.android.FlutterActivity
import io.flutter.embedding.engine.FlutterEngine
import io.flutter.plugin.common.EventChannel
import io.flutter.plugin.common.MethodCall
import io.flutter.plugin.common.MethodChannel
import java.io.BufferedInputStream
import java.io.BufferedOutputStream
import java.security.MessageDigest
import java.util.concurrent.Executors
import java.util.concurrent.TimeUnit

class MainActivity : FlutterActivity(), MethodChannel.MethodCallHandler,
    EventChannel.StreamHandler {
    companion object {
        private const val CHANNEL = "com.voxyn.nexus/root_tools"
        private const val PARTITION_EVENTS = "com.voxyn.nexus/root_tools/partitions"
        private const val BUFFER_SIZE = 1024 * 1024
        private const val EXPORT_DOCUMENT_REQUEST = 1001
    }

    private val worker = Executors.newSingleThreadExecutor()
    private val mainHandler = Handler(Looper.getMainLooper())
    private val partitions = mutableMapOf<String, PartitionRecord>()
    private lateinit var channel: MethodChannel
    private var eventSink: EventChannel.EventSink? = null
    private var pendingPickerResult: MethodChannel.Result? = null
    private var scanId = 0
    private var activeScanProcess: Process? = null

    override fun configureFlutterEngine(flutterEngine: FlutterEngine) {
        super.configureFlutterEngine(flutterEngine)
        channel = MethodChannel(flutterEngine.dartExecutor.binaryMessenger, CHANNEL)
        channel.setMethodCallHandler(this)
        EventChannel(flutterEngine.dartExecutor.binaryMessenger, PARTITION_EVENTS)
            .setStreamHandler(this)
    }

    override fun onMethodCall(call: MethodCall, result: MethodChannel.Result) {
        when (call.method) {
            "getRootCapability" -> runWorker(result) { rootCapability() }
            "launchLsposed" -> runWorker(result) { launchLsposed() }
            "startPartitionDiscovery" -> startPartitionDiscovery(result)
            "cancelPartitionDiscovery" -> {
                val requestedId = call.argument<Int>("scanId")
                if (requestedId == scanId) activeScanProcess?.destroyForcibly()
                result.success(null)
            }
            "pickExportDestination" -> pickExportDestination(
                call.argument<String>("suggestedName"), result,
            )
            "exportPartition" -> {
                val id = call.argument<String>("id") ?: return result.error("invalid_argument", "缺少分区 ID。", null)
                val destinationUri = call.argument<String>("destinationUri") ?: return result.error("invalid_argument", "缺少输出文件。", null)
                runWorker(result) { exportPartition(id, Uri.parse(destinationUri)) }
            }
            else -> result.notImplemented()
        }
    }

    override fun onListen(arguments: Any?, events: EventChannel.EventSink?) { eventSink = events }
    override fun onCancel(arguments: Any?) { eventSink = null; activeScanProcess?.destroyForcibly() }

    private fun runWorker(result: MethodChannel.Result, action: () -> Any?) {
        worker.execute {
            try { result.success(action()) }
            catch (error: RootToolsException) { result.error(error.code, error.message, null) }
            catch (error: Exception) { result.error("operation_failed", error.message ?: "操作失败。", null) }
        }
    }

    private fun rootCapability(): Map<String, Any> = try {
        val available = runRoot("id -u", 5).trim() == "0"
        mapOf("isAndroid" to true, "isRootAvailable" to available,
            "message" to if (available) "Root 已授权，可以使用设备工具。" else "su 未返回 root 身份。")
    } catch (error: RootToolsException) {
        mapOf("isAndroid" to true, "isRootAvailable" to false, "message" to error.message)
    }

    private fun launchLsposed(): String {
        requireRoot()
        val command = "sdk=\$(getprop ro.build.version.sdk); if [ \"\$sdk\" -ge 29 ]; then am broadcast -a android.telephony.action.SECRET_CODE -d android_secret_code://5776733; else am broadcast -a android.provider.Telephony.SECRET_CODE -d android_secret_code://5776733; fi"
        return runRoot(command, 15).ifBlank { "广播命令已提交。" }
    }

    private fun startPartitionDiscovery(result: MethodChannel.Result) {
        val id = ++scanId
        activeScanProcess?.destroyForcibly()
        partitions.clear()
        result.success(id)
        worker.execute {
            try {
                requireRoot()
                emit(mapOf("type" to "started", "scanId" to id))
                val script = """
                    for link in /dev/block/by-name/*; do
                      [ -e "${'$'}link" ] || continue
                      name=${'$'}(basename "${'$'}link"); path=${'$'}(readlink -f "${'$'}link")
                      case "${'$'}path" in /dev/block/*) ;; *) continue ;; esac
                      size=${'$'}(blockdev --getsize64 "${'$'}path" 2>/dev/null || echo 0)
                      mounted=false; grep -Fq " ${'$'}path " /proc/mounts && mounted=true
                      logical=false; case "${'$'}path" in /dev/block/dm-*) logical=true ;; esac
                      printf '%s|%s|%s|%s|%s\n' "${'$'}name" "${'$'}path" "${'$'}size" "${'$'}mounted" "${'$'}logical"
                    done
                """.trimIndent()
                val process = rootProcess(script)
                activeScanProcess = process
                var count = 0
                process.inputStream.bufferedReader().useLines { lines -> lines.forEach { line ->
                    if (id != scanId) return@forEach
                    parsePartition(line)?.let { partition ->
                        partitions[partition.id] = partition
                        count++
                        emit(mapOf("type" to "partition", "scanId" to id, "partition" to partition.toMap()))
                    }
                } }
                if (id == scanId) {
                    waitForSuccess(process, 30)
                    emit(mapOf("type" to "completed", "scanId" to id, "discoveredCount" to count))
                }
            } catch (error: Exception) {
                if (id == scanId) emit(mapOf("type" to "failed", "scanId" to id, "message" to (error.message ?: "分区发现失败。")))
            } finally { if (id == scanId) activeScanProcess = null }
        }
    }

    private fun parsePartition(line: String): PartitionRecord? {
        val fields = line.split('|')
        if (fields.size != 5 || fields[0].isBlank() || !fields[1].startsWith("/dev/block/")) return null
        return PartitionRecord(fields[0], fields[0], fields[1], fields[2].toLongOrNull()?.coerceAtLeast(0) ?: 0, fields[3] == "true", fields[4] == "true")
    }

    private fun emit(event: Map<String, Any>) { mainHandler.post { eventSink?.success(event) } }

    private fun pickExportDestination(suggestedName: String?, result: MethodChannel.Result) {
        if (pendingPickerResult != null) return result.error("picker_busy", "已有文件选择请求正在进行。", null)
        pendingPickerResult = result
        startActivityForResult(Intent(Intent.ACTION_CREATE_DOCUMENT).apply {
            addCategory(Intent.CATEGORY_OPENABLE); type = "application/octet-stream"
            putExtra(Intent.EXTRA_TITLE, safeExportName(suggestedName))
        }, EXPORT_DOCUMENT_REQUEST)
    }

    private fun safeExportName(name: String?): String {
        val base = name?.removeSuffix(".img") ?: return "nexus-partition.img"
        return if (base.matches(Regex("[A-Za-z0-9._-]+"))) "$base.img" else "nexus-partition.img"
    }

    @Deprecated("Deprecated in Java")
    override fun onActivityResult(requestCode: Int, resultCode: Int, data: Intent?) {
        super.onActivityResult(requestCode, resultCode, data)
        if (requestCode == EXPORT_DOCUMENT_REQUEST) completePicker(resultCode, data?.data)
    }

    private fun completePicker(resultCode: Int, uri: Uri?) {
        val result = pendingPickerResult ?: return
        pendingPickerResult = null
        if (resultCode != Activity.RESULT_OK || uri == null) result.error("selection_cancelled", "未选择文件。", null)
        else result.success(uri.toString())
    }

    private fun exportPartition(id: String, destination: Uri): String {
        val partition = requirePartition(id); requireRoot()
        contentResolver.openOutputStream(destination, "w")?.use { output ->
            val process = rootBinaryProcess("dd if=${partition.blockPath} bs=$BUFFER_SIZE status=none")
            BufferedInputStream(process.inputStream, BUFFER_SIZE).use { input ->
                BufferedOutputStream(output, BUFFER_SIZE).use { bufferedOutput ->
                    val digest = MessageDigest.getInstance("SHA-256"); var copied = 0L; val buffer = ByteArray(BUFFER_SIZE)
                    while (true) { val count = input.read(buffer); if (count < 0) break; bufferedOutput.write(buffer, 0, count); digest.update(buffer, 0, count); copied += count }
                    bufferedOutput.flush(); waitForSuccess(process, 180)
                    if (copied != partition.sizeBytes) throw RootToolsException("short_read", "导出不完整：读取 $copied / ${partition.sizeBytes} 字节。")
                    return "导出完成：$copied 字节，SHA-256 ${digest.digest().toHex()}"
                }
            }
        } ?: throw RootToolsException("storage_error", "无法打开输出文件。")
    }

    private fun requireRoot() { if (runRoot("id -u", 5).trim() != "0") throw RootToolsException("root_unavailable", "Root 未授权或已失效。") }
    private fun requirePartition(id: String): PartitionRecord = partitions[id]?.takeIf { it.blockPath.startsWith("/dev/block/") } ?: throw RootToolsException("partition_expired", "分区列表已失效，请刷新后重试。")
    private fun rootBinaryProcess(command: String): Process = ProcessBuilder("su", "-c", command).start()
    private fun rootProcess(command: String): Process = ProcessBuilder("su", "-c", command).redirectErrorStream(true).start()
    private fun runRoot(command: String, timeoutSeconds: Long): String { val process = rootProcess(command); val output = process.inputStream.bufferedReader().use { it.readText() }; waitForSuccess(process, timeoutSeconds); return output }
    private fun waitForSuccess(process: Process, timeoutSeconds: Long) { if (!process.waitFor(timeoutSeconds, TimeUnit.SECONDS)) { process.destroyForcibly(); throw RootToolsException("timeout", "Root 命令超时。") }; if (process.exitValue() != 0) throw RootToolsException("root_command_failed", "Root 命令失败。") }
    private fun ByteArray.toHex(): String = joinToString("") { "%02x".format(it) }
    override fun onDestroy() { activeScanProcess?.destroyForcibly(); worker.shutdownNow(); super.onDestroy() }
}

private data class PartitionRecord(val id: String, val name: String, val blockPath: String, val sizeBytes: Long, val isMounted: Boolean, val isLogical: Boolean) {
    fun toMap(): Map<String, Any> = mapOf("id" to id, "name" to name, "blockPath" to blockPath, "sizeBytes" to sizeBytes, "isMounted" to isMounted, "isLogical" to isLogical)
}
private class RootToolsException(val code: String, override val message: String) : Exception(message)
