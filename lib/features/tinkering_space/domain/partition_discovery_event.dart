import 'package:flutter/foundation.dart';

import 'partition.dart';

enum PartitionDiscoveryEventKind { started, partition, completed, failed }

@immutable
class PartitionDiscoveryEvent {
  const PartitionDiscoveryEvent({
    required this.kind,
    required this.scanId,
    this.partition,
    this.message,
    this.discoveredCount,
  });

  final PartitionDiscoveryEventKind kind;
  final int scanId;
  final Partition? partition;
  final String? message;
  final int? discoveredCount;

  factory PartitionDiscoveryEvent.fromMap(Map<Object?, Object?> map) {
    final type = map['type'] as String?;
    final kind = switch (type) {
      'started' => PartitionDiscoveryEventKind.started,
      'partition' => PartitionDiscoveryEventKind.partition,
      'completed' => PartitionDiscoveryEventKind.completed,
      'failed' => PartitionDiscoveryEventKind.failed,
      _ => throw FormatException('未知的分区发现事件：$type'),
    };
    final scanId = map['scanId'] as int?;
    if (scanId == null) {
      throw const FormatException('分区发现事件缺少 scan ID。');
    }

    final partitionMap = map['partition'];
    return PartitionDiscoveryEvent(
      kind: kind,
      scanId: scanId,
      partition: partitionMap is Map<Object?, Object?>
          ? Partition.fromMap(partitionMap)
          : null,
      message: map['message'] as String?,
      discoveredCount: map['discoveredCount'] as int?,
    );
  }
}
