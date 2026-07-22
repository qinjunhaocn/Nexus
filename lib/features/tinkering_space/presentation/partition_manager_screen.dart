import 'package:flutter/material.dart';

import '../data/android_root_tools_gateway.dart';
import '../domain/partition.dart';

class PartitionManagerScreen extends StatefulWidget {
  const PartitionManagerScreen({super.key, required this.gateway});

  final AndroidRootToolsGateway gateway;

  @override
  State<PartitionManagerScreen> createState() => _PartitionManagerScreenState();
}

class _PartitionManagerScreenState extends State<PartitionManagerScreen> {
  List<Partition> _partitions = const [];
  Object? _error;
  bool _loading = true;
  String? _operation;

  @override
  void initState() {
    super.initState();
    _loadPartitions();
  }

  Future<void> _loadPartitions() async {
    setState(() {
      _loading = true;
      _error = null;
    });
    try {
      final partitions = await widget.gateway.listPartitions();
      if (!mounted) return;
      setState(() => _partitions = partitions);
    } catch (error) {
      if (!mounted) return;
      setState(() => _error = error);
    } finally {
      if (mounted) setState(() => _loading = false);
    }
  }

  Future<void> _exportPartition(Partition partition) async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('导出原始分区镜像'),
        content: Text(
          '将导出 ${partition.name}（${partition.formattedSize}）的原始内容。镜像可能包含敏感数据，请保存到可信位置。',
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
      final destination = await widget.gateway.pickExportDestination();
      if (!mounted) return;
      setState(() => _operation = '正在导出 ${partition.name}…');
      final result = await widget.gateway.exportPartition(
        partition: partition,
        destinationUri: destination,
      );
      if (!mounted) return;
      _showResult('导出完成', result);
    } catch (error) {
      if (!mounted) return;
      _showResult('导出失败', '$error');
    } finally {
      if (mounted) setState(() => _operation = null);
    }
  }

  void _showWriteUnavailable(Partition partition) {
    showDialog<void>(
      context: context,
      builder: (context) => AlertDialog(
        icon: const Icon(Icons.warning_amber_rounded),
        title: const Text('写入功能未开放'),
        content: Text(
          '为保护设备，Nexus 当前不提供向 ${partition.name} 或其他真实设备分区写入镜像的功能。原始分区写入可能永久清除数据或使设备无法启动。',
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
    return Scaffold(
      appBar: AppBar(
        title: const Text('镜像分区管理'),
        actions: [
          IconButton(
            onPressed: _loading || _operation != null ? null : _loadPartitions,
            tooltip: '刷新分区',
            icon: const Icon(Icons.refresh),
          ),
        ],
      ),
      body: _loading
          ? const Center(child: CircularProgressIndicator())
          : _error != null
          ? _ErrorState(error: _error!, onRetry: _loadPartitions)
          : _partitions.isEmpty
          ? const Center(child: Text('没有识别到可用分区。'))
          : Stack(
              children: [
                ListView.separated(
                  padding: const EdgeInsets.all(16),
                  itemCount: _partitions.length + 1,
                  separatorBuilder: (_, _) => const SizedBox(height: 12),
                  itemBuilder: (context, index) {
                    if (index == 0) {
                      return Card(
                        color: colors.errorContainer,
                        child: Padding(
                          padding: const EdgeInsets.all(16),
                          child: Text(
                            '仅支持导出。原始镜像可能含有个人和设备敏感信息，请妥善保存。写入真实分区未开放。',
                            style: TextStyle(color: colors.onErrorContainer),
                          ),
                        ),
                      );
                    }
                    final partition = _partitions[index - 1];
                    return _PartitionCard(
                      partition: partition,
                      isBusy: _operation != null,
                      onExport: () => _exportPartition(partition),
                      onWrite: () => _showWriteUnavailable(partition),
                    );
                  },
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

class _PartitionCard extends StatelessWidget {
  const _PartitionCard({
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

class _ErrorState extends StatelessWidget {
  const _ErrorState({required this.error, required this.onRetry});

  final Object error;
  final VoidCallback onRetry;

  @override
  Widget build(BuildContext context) {
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(24),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            const Icon(Icons.error_outline, size: 48),
            const SizedBox(height: 16),
            Text('无法读取分区', style: Theme.of(context).textTheme.titleLarge),
            const SizedBox(height: 8),
            Text('$error', textAlign: TextAlign.center),
            const SizedBox(height: 16),
            FilledButton(onPressed: onRetry, child: const Text('重试')),
          ],
        ),
      ),
    );
  }
}
