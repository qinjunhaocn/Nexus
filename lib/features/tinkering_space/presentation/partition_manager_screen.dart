import 'dart:async';

import 'package:flutter/material.dart';

import '../data/android_root_tools_gateway.dart';
import '../domain/partition.dart';
import '../domain/partition_discovery_event.dart';

class PartitionManagerScreen extends StatefulWidget {
  const PartitionManagerScreen({super.key, required this.gateway});

  final AndroidRootToolsGateway gateway;

  @override
  State<PartitionManagerScreen> createState() => _PartitionManagerScreenState();
}

class _PartitionManagerScreenState extends State<PartitionManagerScreen> {
  final _partitions = <String, Partition>{};
  final _pendingPartitions = <Partition>[];
  final _searchController = TextEditingController();
  StreamSubscription<PartitionDiscoveryEvent>? _subscription;
  Timer? _batchTimer;
  Timer? _searchTimer;
  int? _scanId;
  String _query = '';
  String? _error;
  String? _operation;
  bool _discovering = false;

  @override
  void initState() {
    super.initState();
    _subscription = widget.gateway.partitionDiscoveryEvents.listen(
      _handleDiscoveryEvent,
      onError: (Object error) {
        if (mounted) setState(() => _error = '$error');
      },
    );
    _startDiscovery();
  }

  @override
  void dispose() {
    _batchTimer?.cancel();
    _searchTimer?.cancel();
    _subscription?.cancel();
    final scanId = _scanId;
    if (scanId != null) {
      unawaited(widget.gateway.cancelPartitionDiscovery(scanId));
    }
    _searchController.dispose();
    super.dispose();
  }

  Future<void> _startDiscovery() async {
    final previousScanId = _scanId;
    if (previousScanId != null) {
      await widget.gateway.cancelPartitionDiscovery(previousScanId);
    }
    if (!mounted) return;
    setState(() {
      _partitions.clear();
      _pendingPartitions.clear();
      _error = null;
      _discovering = true;
      _scanId = null;
    });
    try {
      final scanId = await widget.gateway.startPartitionDiscovery();
      if (!mounted) return;
      setState(() => _scanId = scanId);
    } catch (error) {
      if (mounted) {
        setState(() {
          _discovering = false;
          _error = '$error';
        });
      }
    }
  }

  void _handleDiscoveryEvent(PartitionDiscoveryEvent event) {
    final activeScanId = _scanId;
    if (activeScanId != null && event.scanId != activeScanId) return;
    if (activeScanId == null &&
        event.kind == PartitionDiscoveryEventKind.started) {
      setState(() => _scanId = event.scanId);
    }

    switch (event.kind) {
      case PartitionDiscoveryEventKind.started:
        if (mounted) setState(() => _discovering = true);
        break;
      case PartitionDiscoveryEventKind.partition:
        final partition = event.partition;
        if (partition == null) return;
        _pendingPartitions.add(partition);
        _batchTimer ??= Timer(const Duration(milliseconds: 32), _flushPending);
        break;
      case PartitionDiscoveryEventKind.completed:
        _flushPending();
        if (mounted) setState(() => _discovering = false);
        break;
      case PartitionDiscoveryEventKind.failed:
        _flushPending();
        if (mounted) {
          setState(() {
            _discovering = false;
            _error = event.message ?? '分区发现失败。';
          });
        }
        break;
    }
  }

  void _flushPending() {
    _batchTimer?.cancel();
    _batchTimer = null;
    if (_pendingPartitions.isEmpty || !mounted) return;
    setState(() {
      for (final partition in _pendingPartitions) {
        _partitions[partition.id] = partition;
      }
      _pendingPartitions.clear();
    });
  }

  void _updateSearch(String value) {
    _searchTimer?.cancel();
    _searchTimer = Timer(const Duration(milliseconds: 150), () {
      if (mounted) setState(() => _query = value.trim().toLowerCase());
    });
  }

  List<Partition> get _visiblePartitions {
    final partitions = _partitions.values.toList(growable: false);
    if (_query.isEmpty) return partitions;
    return partitions
        .where((partition) {
          return partition.name.toLowerCase().contains(_query) ||
              partition.blockPath.toLowerCase().contains(_query) ||
              (partition.isMounted && '已挂载'.contains(_query)) ||
              (partition.isLogical && '逻辑分区'.contains(_query));
        })
        .toList(growable: false);
  }

  Future<void> _exportPartition(Partition partition) async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('导出原始分区镜像'),
        content: Text(
          '将导出 ${partition.name}（${partition.formattedSize}）的原始内容。系统文件选择器会建议文件名 ${partition.name}.img。镜像可能包含敏感数据，请保存到可信位置。',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            child: const Text('取消'),
          ),
          FilledButton(
            onPressed: () => Navigator.pop(context, true),
            child: const Text('选择保存位置'),
          ),
        ],
      ),
    );
    if (confirmed != true) return;
    try {
      final destination = await widget.gateway.pickExportDestination(partition);
      if (!mounted) return;
      setState(() => _operation = '正在导出 ${partition.name}…');
      final result = await widget.gateway.exportPartition(
        partition: partition,
        destinationUri: destination,
      );
      if (mounted) _showResult('导出完成', result);
    } catch (error) {
      if (mounted) _showResult('导出失败', '$error');
    } finally {
      if (mounted) setState(() => _operation = null);
    }
  }

  void _showWriteUnavailable(Partition partition) {
    showDialog<void>(
      context: context,
      builder: (context) => AlertDialog(
        icon: const Icon(Icons.warning_amber_rounded),
        title: const Text('原始分区写入未开放'),
        content: Text(
          'Nexus 不会向 ${partition.name} 或其他真实设备分区写入镜像。即使设置 10 秒阅读倒计时，也无法避免镜像不兼容、部分写入、数据永久丢失或设备无法启动的风险。',
        ),
        actions: [
          FilledButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('我知道了'),
          ),
        ],
      ),
    );
  }

  void _showResult(String title, String message) {
    showDialog<void>(
      context: context,
      builder: (context) => AlertDialog(
        title: Text(title),
        content: SelectableText(message),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('关闭'),
          ),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final colors = Theme.of(context).colorScheme;
    final visiblePartitions = _visiblePartitions;
    return Scaffold(
      appBar: AppBar(
        title: const Text('镜像分区管理'),
        actions: [
          IconButton(
            onPressed: _operation == null ? _startDiscovery : null,
            tooltip: '刷新分区',
            icon: const Icon(Icons.refresh),
          ),
        ],
      ),
      body: Stack(
        children: [
          Column(
            children: [
              Padding(
                padding: const EdgeInsets.fromLTRB(16, 8, 16, 8),
                child: SearchBar(
                  controller: _searchController,
                  hintText: '搜索分区名称或路径',
                  leading: const Icon(Icons.search),
                  trailing: _query.isEmpty
                      ? null
                      : [
                          IconButton(
                            onPressed: () {
                              _searchController.clear();
                              _updateSearch('');
                            },
                            icon: const Icon(Icons.clear),
                            tooltip: '清除搜索',
                          ),
                        ],
                  onChanged: _updateSearch,
                ),
              ),
              _DiscoveryStatus(
                discovering: _discovering,
                foundCount: _partitions.length,
                error: _error,
                onRetry: _startDiscovery,
              ),
              Expanded(
                child: visiblePartitions.isEmpty
                    ? Center(
                        child: Text(
                          _query.isEmpty
                              ? (_discovering
                                    ? '正在从 /dev/block/by-name 发现分区…'
                                    : '没有识别到可用分区。')
                              : '没有匹配的分区。',
                        ),
                      )
                    : ListView.builder(
                        padding: const EdgeInsets.fromLTRB(16, 8, 16, 16),
                        itemCount: visiblePartitions.length + 1,
                        itemBuilder: (context, index) {
                          if (index == 0) {
                            return Padding(
                              padding: const EdgeInsets.only(bottom: 12),
                              child: Card(
                                color: colors.errorContainer,
                                child: Padding(
                                  padding: const EdgeInsets.all(16),
                                  child: Text(
                                    '仅支持导出。原始镜像可能含有个人和设备敏感信息，请妥善保存。写入真实分区未开放。',
                                    style: TextStyle(
                                      color: colors.onErrorContainer,
                                    ),
                                  ),
                                ),
                              ),
                            );
                          }
                          final partition = visiblePartitions[index - 1];
                          return Padding(
                            padding: const EdgeInsets.only(bottom: 12),
                            child: _PartitionCard(
                              key: ValueKey(partition.id),
                              partition: partition,
                              isBusy: _operation != null,
                              onExport: () => _exportPartition(partition),
                              onWrite: () => _showWriteUnavailable(partition),
                            ),
                          );
                        },
                      ),
              ),
            ],
          ),
          if (_operation case final operation?)
            ColoredBox(
              color: colors.scrim.withValues(alpha: 0.45),
              child: Center(
                child: Card(
                  child: Padding(
                    padding: const EdgeInsets.all(24),
                    child: Column(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        const CircularProgressIndicator(),
                        const SizedBox(height: 16),
                        Text(operation),
                      ],
                    ),
                  ),
                ),
              ),
            ),
        ],
      ),
    );
  }
}

class _DiscoveryStatus extends StatelessWidget {
  const _DiscoveryStatus({
    required this.discovering,
    required this.foundCount,
    required this.error,
    required this.onRetry,
  });
  final bool discovering;
  final int foundCount;
  final String? error;
  final VoidCallback onRetry;
  @override
  Widget build(BuildContext context) => Padding(
    padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 4),
    child: Row(
      children: [
        if (discovering)
          const SizedBox(
            width: 16,
            height: 16,
            child: CircularProgressIndicator(strokeWidth: 2),
          ),
        if (discovering) const SizedBox(width: 8),
        Expanded(
          child: Text(
            error ??
                (discovering
                    ? '正在发现：已找到 $foundCount 个分区'
                    : '发现完成：共 $foundCount 个分区'),
          ),
        ),
        if (error != null)
          TextButton(onPressed: onRetry, child: const Text('重试')),
      ],
    ),
  );
}

class _PartitionCard extends StatelessWidget {
  const _PartitionCard({
    super.key,
    required this.partition,
    required this.isBusy,
    required this.onExport,
    required this.onWrite,
  });
  final Partition partition;
  final bool isBusy;
  final VoidCallback onExport;
  final VoidCallback onWrite;
  @override
  Widget build(BuildContext context) {
    final colors = Theme.of(context).colorScheme;
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Icon(Icons.memory_outlined, color: colors.primary),
                const SizedBox(width: 12),
                Expanded(
                  child: Text(
                    partition.name,
                    style: Theme.of(context).textTheme.titleMedium,
                  ),
                ),
                Text(partition.formattedSize),
              ],
            ),
            const SizedBox(height: 12),
            SelectableText(
              partition.blockPath,
              style: Theme.of(context).textTheme.bodySmall,
            ),
            const SizedBox(height: 8),
            Wrap(
              spacing: 8,
              runSpacing: 8,
              children: [
                if (partition.isMounted) const Chip(label: Text('已挂载')),
                if (partition.isLogical) const Chip(label: Text('逻辑分区')),
                if (!partition.isMounted && !partition.isLogical)
                  const Chip(label: Text('块分区')),
              ],
            ),
            const SizedBox(height: 12),
            Wrap(
              spacing: 8,
              children: [
                OutlinedButton.icon(
                  onPressed: isBusy ? null : onExport,
                  icon: const Icon(Icons.download_outlined),
                  label: const Text('导出镜像'),
                ),
                FilledButton.tonalIcon(
                  onPressed: isBusy ? null : onWrite,
                  icon: const Icon(Icons.upload_outlined),
                  label: const Text('写入不可用'),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }
}
