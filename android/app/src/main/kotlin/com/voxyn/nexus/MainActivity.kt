package com.voxyn.nexus

import android.app.Activity
import android.content.Intent
import android.net.Uri
import android.os.Bundle
import androidx.activity.result.contract.ActivityResultContracts
import io.flutter.embedding.android.FlutterActivity
import io.flutter.embedding.engine.FlutterEngine
import io.flutter.plugin.common.MethodCall
import io.flutter.plugin.common.MethodChannel
import java.io.BufferedInputStream
import java.io.BufferedOutputStream
import java.io.File
import java.security.MessageDigest
import java.util.concurrent.Executors
import java.util.concurrent.TimeUnit

class MainActivity : FlutterActivity(), MethodChannel.MethodCallHandler {
    companion object {
        private const val CHANNEL = "com.voxyn.nexus/root_tools"
        private const val BUFFER_SIZE = 1024 * 1024
    }

    private val worker = Executors.newSingleThreadExecutor()
    private val partitions = mutableMapOf<String, PartitionRecord>()
    private lateinit var channel: MethodChannel
    private var pendingPickerResult: MethodChannel.Result? = null
    private var pendingPickerMode: PickerMode? = null

    private val createDocument = registerForActivityResult(
        ActivityResultContracts.StartActivityForResult(),
    ) { activityResult ->
        completePicker(activityResult.resultCode, activityResult.data?.data)
    }

    override fun configureFlutterEngine(flutterEngine: FlutterEngine) {
        super.configureFlutterEngine(flutterEngine)
        channel = MethodChannel(flutterEngine.dartExecutor.binaryMessenger, CHANNEL)
        channel.setMethodCallHandler(this)
    }

    override fun onMethodCall(call: MethodCall, result: MethodChannel.Result) {
        when (call.method) {
            "getRootCapability" -> runWorker(result) { rootCapability() }
            "launchLsposed" -> runWorker(result) { launchLsposed() }
            "listPartitions" -> runWorker(result) { listPartitions() }
            "pickExportDestination" -> pickExportDestination(result)
            "exportPartition" -> {
                val id = call.argument<String>("id") ?: return result.error("invalid_argument", "缺少分区 ID。", null)
                val destinationUri = call.argument<String>("destinationUri") ?: return result.error("invalid_argument", "缺少输出文件。", null)
                runWorker(result) { exportPartition(id, Uri.parse(destinationUri)) }
            }
            else -> result.notImplemented()
        }
    }

    private fun runWorker(result: MethodChannel.Result, action: () -> Any?) {
        worker.execute {
            try {
                result.success(action())
            } catch (error: RootToolsException) {
                result.error(error.code, error.message, null)
            } catch (error: Exception) {
                result.error("operation_failed", error.message ?: "操作失败。", null)
            }
        }
    }

    private fun rootCapability(): Map<String, Any> {
        return try {
            val output = runRoot("id -u", 5).trim()
            if (output == "0") {
                mapOf("isAndroid" to true, "isRootAvailable" to true, "message" to "Root 已授权，可以使用设备工具。")
            } else {
                mapOf("isAndroid" to true, "isRootAvailable" to false, "message" to "su 未返回 root 身份。")
            }
        } catch (error: RootToolsException) {
            mapOf("isAndroid" to true, "isRootAvailable" to false, "message" to error.message)
        }
    }

    private fun launchLsposed(): String {
        requireRoot()
        val command = "sdk=\$(getprop ro.build.version.sdk); if [ \"\$sdk\" -ge 29 ]; then am broadcast -a android.telephony.action.SECRET_CODE -d android_secret_code://5776733; else am broadcast -a android.provider.Telephony.SECRET_CODE -d android_secret_code://5776733; fi"
        return runRoot(command, 15).ifBlank { "广播命令已提交。" }
    }

    private fun listPartitions(): List<Map<String, Any>> {
        requireRoot()
        val script = """
            for link in /dev/block/by-name/*; do
              [ -e "\$link" ] || continue
              name=\$(basename "\$link")
              path=\$(readlink -f "\$link")
              case "\$path" in /dev/block/*) ;; *) continue ;; esac
              size=\$(blockdev --getsize64 "\$path" 2>/dev/null || echo 0)
              mounted=false
              grep -Fq " \$path " /proc/mounts && mounted=true
              logical=false
              case "\$path" in /dev/block/dm-*) logical=true ;; esac
              printf '%s|%s|%s|%s|%s\n' "\$name" "\$path" "\$size" "\$mounted" "\$logical"
            done
        """.trimIndent()
        val discovered = runRoot(script, 20).lineSequence().mapNotNull { line ->
            val fields = line.split('|')
            if (fields.size != 5 || !fields[1].startsWith("/dev/block/")) null else PartitionRecord(
                id = fields[0],
                name = fields[0],
                blockPath = fields[1],
                sizeBytes = fields[2].toLongOrNull()?.coerceAtLeast(0) ?: 0,
                isMounted = fields[3] == "true",
                isLogical = fields[4] == "true",
            )
        }.sortedBy { it.name }.toList()
        partitions.clear()
        discovered.forEach { partitions[it.id] = it }
        return discovered.map { it.toMap() }
    }

    private fun pickExportDestination(result: MethodChannel.Result) {
        if (pendingPickerResult != null) return result.error("picker_busy", "已有文件选择请求正在进行。", null)
        pendingPickerResult = result
        pendingPickerMode = PickerMode.EXPORT
        createDocument.launch(Intent(Intent.ACTION_CREATE_DOCUMENT).apply {
            addCategory(Intent.CATEGORY_OPENABLE)
            type = "application/octet-stream"
            putExtra(Intent.EXTRA_TITLE, "nexus-partition.img")
        })
    }

    private fun completePicker(resultCode: Int, uri: Uri?) {
        val result = pendingPickerResult ?: return
        val mode = pendingPickerMode
        pendingPickerResult = null
        pendingPickerMode = null
        if (resultCode != Activity.RESULT_OK || uri == null) {
            result.error("selection_cancelled", "未选择文件。", null)
            return
        }
        result.success(uri.toString())
    }

    private fun exportPartition(id: String, destination: Uri): String {
        val partition = requirePartition(id)
        requireRoot()
        contentResolver.openOutputStream(destination, "w")?.use { output ->
            val process = rootBinaryProcess("dd if=${partition.blockPath} bs=$BUFFER_SIZE status=none")
            BufferedInputStream(process.inputStream, BUFFER_SIZE).use { input ->
                BufferedOutputStream(output, BUFFER_SIZE).use { bufferedOutput ->
                    val digest = MessageDigest.getInstance("SHA-256")
                    var copied = 0L
                    val buffer = ByteArray(BUFFER_SIZE)
                    while (true) {
                        val count = input.read(buffer)
                        if (count < 0) break
                        bufferedOutput.write(buffer, 0, count)
                        digest.update(buffer, 0, count)
                        copied += count
                    }
                    bufferedOutput.flush()
                    waitForSuccess(process, 180)
                    if (copied != partition.sizeBytes) throw RootToolsException("short_read", "导出不完整：读取 $copied / ${partition.sizeBytes} 字节。")
                    return "导出完成：$copied 字节，SHA-256 ${digest.digest().toHex()}"
                }
            }
        } ?: throw RootToolsException("storage_error", "无法打开输出文件。")
    }

    private fun requireRoot() {
        if (runRoot("id -u", 5).trim() != "0") throw RootToolsException("root_unavailable", "Root 未授权或已失效。")
    }

    private fun requirePartition(id: String): PartitionRecord {
        val partition = partitions[id] ?: throw RootToolsException("partition_expired", "分区列表已失效，请刷新后重试。")
        if (!partition.blockPath.startsWith("/dev/block/")) throw RootToolsException("invalid_target", "目标分区无效。")
        return partition
    }

    private fun rootBinaryProcess(command: String): Process = ProcessBuilder("su", "-c", command).start()

    private fun rootProcess(command: String): Process = ProcessBuilder("su", "-c", command).redirectErrorStream(true).start()

    private fun runRoot(command: String, timeoutSeconds: Long): String {
        val process = rootProcess(command)
        val output = process.inputStream.bufferedReader().use { it.readText() }
        waitForSuccess(process, timeoutSeconds)
        return output
    }

    private fun waitForSuccess(process: Process, timeoutSeconds: Long) {
        if (!process.waitFor(timeoutSeconds, TimeUnit.SECONDS)) {
            process.destroyForcibly()
            throw RootToolsException("timeout", "Root 命令超时。")
        }
        if (process.exitValue() != 0) throw RootToolsException("root_command_failed", "Root 命令失败。")
    }

    private fun ByteArray.toHex(): String = joinToString("") { "%02x".format(it) }

    override fun onDestroy() {
        worker.shutdownNow()
        super.onDestroy()
    }
}

private enum class PickerMode { EXPORT }

private data class PartitionRecord(
    val id: String,
    val name: String,
    val blockPath: String,
    val sizeBytes: Long,
    val isMounted: Boolean,
    val isLogical: Boolean,
) {
    fun toMap(): Map<String, Any> = mapOf(
        "id" to id,
        "name" to name,
        "blockPath" to blockPath,
        "sizeBytes" to sizeBytes,
        "isMounted" to isMounted,
        "isLogical" to isLogical,
    )
}

private class RootToolsException(val code: String, override val message: String) : Exception(message)
