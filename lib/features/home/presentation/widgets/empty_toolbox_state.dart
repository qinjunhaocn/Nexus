import 'package:flutter/material.dart';

class EmptyToolboxState extends StatelessWidget {
  const EmptyToolboxState({super.key, required this.destinationName});

  final String destinationName;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final colors = theme.colorScheme;

    return ConstrainedBox(
      constraints: const BoxConstraints(maxWidth: 520),
      child: Card(
        child: Padding(
          padding: const EdgeInsets.all(32),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Container(
                width: 72,
                height: 72,
                decoration: BoxDecoration(
                  color: colors.secondaryContainer,
                  borderRadius: BorderRadius.circular(24),
                ),
                child: Icon(
                  Icons.widgets_outlined,
                  color: colors.onSecondaryContainer,
                  size: 36,
                  semanticLabel: 'Toolbox ready',
                ),
              ),
              const SizedBox(height: 24),
              Text(
                'Your toolbox is ready',
                textAlign: TextAlign.center,
                style: theme.textTheme.headlineSmall,
              ),
              const SizedBox(height: 12),
              Text(
                '$destinationName 正在等待第一个工具。准备好后，Nexus 会把你需要的一切集中到清爽、专注的工作区。',
                textAlign: TextAlign.center,
                style: theme.textTheme.bodyLarge?.copyWith(
                  color: colors.onSurfaceVariant,
                ),
              ),
              const SizedBox(height: 24),
              Tooltip(
                message: 'Tool creation will be available in a future update',
                child: FilledButton.icon(
                  onPressed: null,
                  icon: const Icon(Icons.add),
                  label: const Text('Add a tool'),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
