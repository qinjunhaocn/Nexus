import 'package:flutter/foundation.dart';

@immutable
class Partition {
  const Partition({
    required this.id,
    required this.name,
    required this.blockPath,
    required this.sizeBytes,
    required this.isMounted,
    required this.isLogical,
  });

  final String id;
  final String name;
  final String blockPath;
  final int sizeBytes;
  final bool isMounted;
  final bool isLogical;

  String get formattedSize {
    const units = ['B', 'KB', 'MB', 'GB', 'TB'];
    var value = sizeBytes.toDouble();
    var index = 0;
    while (value >= 1024 && index < units.length - 1) {
      value /= 1024;
      index++;
    }
    return '${value.toStringAsFixed(index == 0 ? 0 : 1)} ${units[index]}';
  }

  factory Partition.fromMap(Map<Object?, Object?> map) {
    return Partition(
      id: map['id'] as String,
      name: map['name'] as String,
      blockPath: map['blockPath'] as String,
      sizeBytes: map['sizeBytes'] as int,
      isMounted: map['isMounted'] as bool? ?? false,
      isLogical: map['isLogical'] as bool? ?? false,
    );
  }
}
