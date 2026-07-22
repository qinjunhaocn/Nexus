import 'dart:async';
import 'dart:io';

import 'package:flutter/services.dart';

import '../domain/partition.dart';
import '../domain/partition_discovery_event.dart';
import '../domain/root_capability.dart';

class AndroidRootToolsGateway {
  AndroidRootToolsGateway({
    MethodChannel? channel,
    EventChannel? partitionEvents,
  }) : _channel = channel ?? const MethodChannel(_channelName),
       _partitionEvents =
           partitionEvents ?? const EventChannel(_partitionEventsName);

  static const _channelName = 'com.voxyn.nexus/root_tools';
  static const _partitionEventsName = 'com.voxyn.nexus/root_tools/partitions';

  final MethodChannel _channel;
  final EventChannel _partitionEvents;

  Stream<PartitionDiscoveryEvent> get partitionDiscoveryEvents {
    if (!Platform.isAndroid) {
      return Stream<PartitionDiscoveryEvent>.error(
        UnsupportedError('分区管理仅支持 Android 设备。'),
      );
    }
    return _partitionEvents.receiveBroadcastStream().map((event) {
      if (event is! Map<Object?, Object?>) {
        throw const FormatException('分区发现事件格式无效。');
      }
      return PartitionDiscoveryEvent.fromMap(event);
    });
  }

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

  Future<int> startPartitionDiscovery() async {
    _ensureAndroid();
    return await _channel.invokeMethod<int>('startPartitionDiscovery') ??
        (throw StateError('无法启动分区发现。'));
  }

  Future<void> cancelPartitionDiscovery(int scanId) async {
    if (!Platform.isAndroid) return;
    await _channel.invokeMethod<void>('cancelPartitionDiscovery', {
      'scanId': scanId,
    });
  }

  Future<String> pickExportDestination(Partition partition) async {
    _ensureAndroid();
    return await _channel.invokeMethod<String>('pickExportDestination', {
          'suggestedName': '${partition.name}.img',
        }) ??
        (throw StateError('未选择输出文件。'));
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
