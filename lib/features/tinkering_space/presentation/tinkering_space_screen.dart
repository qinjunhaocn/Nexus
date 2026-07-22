import 'dart:io';

import 'package:flutter/material.dart';

import '../data/android_root_tools_gateway.dart';
import '../domain/root_capability.dart';
import 'partition_manager_screen.dart';

class TinkeringSpaceScreen extends StatefulWidget {
  const TinkeringSpaceScreen({super.key, this.gateway});

  final AndroidRootToolsGateway? gateway;

  @override
  State<TinkeringSpaceScreen> createState() => _TinkeringSpaceScreenState();
}

class _TinkeringSpaceScreenState extends State<TinkeringSpaceScreen> {
  late final AndroidRootToolsGateway _gateway;
  RootCapability? _capability;
  bool _loading = true;
  bool _launching = false;

  @override
  void initState() {
    super.initState();
    _gateway = widget.gateway ?? AndroidRootToolsGateway();
    _refreshCapability();
  }

  Future<void> _refreshCapability() async {
    setState(() => _loading = true);
    final capability = await _gateway.getRootCapability();
    if (!mounted) return;
    setState(() {
      _capability = capability;
      _loading = false;
    });
  }

  Future<void> _launchLsposed() async {
    setState(() => _launching = true);
    try {
      await _gateway.launchLsposed();
    } catch (error) {
      if (!mounted) return;
      _showResult('无法启动', '$error');
    } finally {
      if (mounted) setState(() => _launching = false);
    }
  }

  void _openPartitionManager() {
    Navigator.of(context).push(
      MaterialPageRoute<void>(
        builder: (_) => PartitionManagerScreen(gateway: _gateway),
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
    final capability = _capability;
    final isAvailable = capability?.canUseRootTools ?? false;
    final statusText = _loading
        ? '正在检查 Root 授权…'
        : capability?.message ?? '无法确认 Root 状态。';

    return ListView(
      padding: const EdgeInsets.all(24),
      children: [
        Text('玩机空间', style: Theme.of(context).textTheme.headlineMedium),
        const SizedBox(height: 8),
        Text(
          '需要 Root 的高级设备工具。操作前请确认已做好可恢复备份。',
          style: Theme.of(
            context,
          ).textTheme.bodyLarge?.copyWith(color: colors.onSurfaceVariant),
        ),
        const SizedBox(height: 24),
        Card(
          child: ListTile(
            leading: Icon(
              isAvailable
                  ? Icons.verified_user_outlined
                  : Icons.security_outlined,
              color: isAvailable ? colors.primary : colors.onSurfaceVariant,
            ),
            title: Text(
              _loading ? '检查 Root 状态' : (isAvailable ? 'Root 已授权' : 'Root 不可用'),
            ),
            subtitle: Text(statusText),
            trailing: IconButton(
              onPressed: _loading ? null : _refreshCapability,
              tooltip: '重新检查',
              icon: const Icon(Icons.refresh),
            ),
          ),
        ),
        if (!Platform.isAndroid) ...[
          const SizedBox(height: 16),
          Card(
            child: Padding(
              padding: const EdgeInsets.all(20),
              child: Row(
                children: [
                  Icon(
                    Icons.desktop_windows_outlined,
                    color: colors.onSurfaceVariant,
                  ),
                  const SizedBox(width: 16),
                  const Expanded(
                    child: Text('Windows 可以浏览玩机空间，但 Root、分区导出和写入仅支持 Android。'),
                  ),
                ],
              ),
            ),
          ),
        ],
        const SizedBox(height: 16),
        _ToolCard(
          icon: Icons.rocket_launch_outlined,
          title: 'LSPosed 启动器',
          description: '通过 Root shell 发送设备相关的 secret-code 广播。设备固件可能不支持此操作。',
          actionLabel: _launching ? '正在启动…' : '启动',
          enabled: isAvailable && !_launching,
          onPressed: _launchLsposed,
        ),
        const SizedBox(height: 16),
        _ToolCard(
          icon: Icons.storage_outlined,
          title: '镜像分区管理',
          description: '通过 /dev/block/by-name 发现分区并导出原始镜像。写入真实分区未开放。',
          actionLabel: '打开',
          enabled: isAvailable,
          onPressed: _openPartitionManager,
        ),
      ],
    );
  }
}

class _ToolCard extends StatelessWidget {
  const _ToolCard({
    required this.icon,
    required this.title,
    required this.description,
    required this.actionLabel,
    required this.enabled,
    required this.onPressed,
  });

  final IconData icon;
  final String title;
  final String description;
  final String actionLabel;
  final bool enabled;
  final VoidCallback onPressed;

  @override
  Widget build(BuildContext context) {
    final colors = Theme.of(context).colorScheme;
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(20),
        child: Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Container(
              width: 48,
              height: 48,
              decoration: BoxDecoration(
                color: colors.secondaryContainer,
                borderRadius: BorderRadius.circular(16),
              ),
              child: Icon(icon, color: colors.onSecondaryContainer),
            ),
            const SizedBox(width: 16),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(title, style: Theme.of(context).textTheme.titleLarge),
                  const SizedBox(height: 6),
                  Text(
                    description,
                    style: Theme.of(context).textTheme.bodyMedium,
                  ),
                  const SizedBox(height: 16),
                  FilledButton(
                    onPressed: enabled ? onPressed : null,
                    child: Text(actionLabel),
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}
