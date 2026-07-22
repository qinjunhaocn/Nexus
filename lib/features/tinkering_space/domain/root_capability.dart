import 'package:flutter/foundation.dart';

@immutable
class RootCapability {
  const RootCapability({
    required this.isAndroid,
    required this.isRootAvailable,
    required this.message,
  });

  final bool isAndroid;
  final bool isRootAvailable;
  final String message;

  bool get canUseRootTools => isAndroid && isRootAvailable;

  factory RootCapability.fromMap(Map<Object?, Object?> map) {
    return RootCapability(
      isAndroid: map['isAndroid'] as bool? ?? false,
      isRootAvailable: map['isRootAvailable'] as bool? ?? false,
      message: map['message'] as String? ?? '无法确认 Root 状态。',
    );
  }
}
