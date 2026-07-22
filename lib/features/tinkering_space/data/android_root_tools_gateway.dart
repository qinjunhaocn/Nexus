import 'dart:io';

import 'package:flutter/services.dart';

import '../domain/partition.dart';
import '../domain/root_capability.dart';

class AndroidRootToolsGateway {
  AndroidRootToolsGateway({MethodChannel? channel})
    : _channel = channel ?? const MethodChannel(_channelName);

  static const _channelName = 'com.voxyn.nexus/root_tools';
  final MethodChannel _channel;

  Future<RootCapability> getRootCapability() async {
    if (!Platform.isAndroid) {
      return const RootCapability(
        isAndroid: false,
        isRootAvailable: false,
        message: 'Root 工具仅支持 Android 设备。',
      );
    }

    try {
      final response = await _channel.invokeMapMethod<Object?, Object?>(
        'getRootCapability',
      );
      return RootCapability.fromMap(response ?? const {});
    } on PlatformException catch (error) {
      return RootCapability(
        isAndroid: true,
        isRootAvailable: false,
        message: error.message ?? '无法检查 Root 状态。',
      );
    }
  }

  Future<String> launchLsposed() async {
    _ensureAndroid();
    return await _channel.invokeMethod<String>('launchLsposed') ?? '命令未返回结果。';
  }

  Future<List<Partition>> listPartitions() async {
    _ensureAndroid();
    final partitions = await _channel.invokeListMethod<Object?>(
      'listPartitions',
    );
    return (partitions ?? const [])
        .whereType<Map<Object?, Object?>>()
        .map(Partition.fromMap)
        .toList(growable: false);
  }

  Future<String> pickExportDestination() async {
    _ensureAndroid();
    return await _channel.invokeMethod<String>('pickExportDestination') ??
        (throw StateError('未选择输出文件。'));
  }

  Future<String> pickImportSource() async {
    _ensureAndroid();
    return await _channel.invokeMethod<String>('pickImportSource') ??
        (throw StateError('未选择输入镜像。'));
  }

  Future<String> exportPartition({
    required Partition partition,
    required String destinationUri,
  }) async {
    _ensureAndroid();
    return await _channel.invokeMethod<String>('exportPartition', {
          'id': partition.id,
          'destinationUri': destinationUri,
        }) ??
        '导出完成。';
  }

  void _ensureAndroid() {
    if (!Platform.isAndroid) {
      throw UnsupportedError('Root 工具仅支持 Android 设备。');
    }
  }
}
