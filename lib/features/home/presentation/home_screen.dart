import 'package:flutter/material.dart';

import '../../tinkering_space/presentation/tinkering_space_screen.dart';
import 'widgets/empty_toolbox_state.dart';

class HomeScreen extends StatefulWidget {
  const HomeScreen({super.key});

  @override
  State<HomeScreen> createState() => _HomeScreenState();
}

class _HomeScreenState extends State<HomeScreen> {
  static const _destinations = [
    _Destination(
      label: '玩机空间',
      icon: Icons.space_dashboard_outlined,
      selectedIcon: Icons.space_dashboard,
    ),
    _Destination(
      label: 'Tools',
      icon: Icons.handyman_outlined,
      selectedIcon: Icons.handyman,
    ),
    _Destination(
      label: '关于',
      icon: Icons.settings_outlined,
      selectedIcon: Icons.settings,
    ),
  ];

  int _selectedIndex = 0;

  @override
  Widget build(BuildContext context) {
    return LayoutBuilder(
      builder: (context, constraints) {
        final isDesktopLayout = constraints.maxWidth >= 720;

        return Scaffold(
          appBar: AppBar(
            titleSpacing: isDesktopLayout ? 24 : 16,
            title: const _AppTitle(),
          ),
          body: isDesktopLayout
              ? Row(
                  children: [
                    NavigationRail(
                      extended: constraints.maxWidth >= 1024,
                      selectedIndex: _selectedIndex,
                      onDestinationSelected: _selectDestination,
                      labelType: constraints.maxWidth >= 1024
                          ? NavigationRailLabelType.none
                          : NavigationRailLabelType.all,
                      leading: const Padding(
                        padding: EdgeInsets.only(bottom: 16),
                        child: Icon(Icons.grid_view_rounded),
                      ),
                      destinations: _destinations
                          .map(
                            (destination) => NavigationRailDestination(
                              icon: Icon(destination.icon),
                              selectedIcon: Icon(destination.selectedIcon),
                              label: Text(destination.label),
                            ),
                          )
                          .toList(),
                    ),
                    const VerticalDivider(width: 1),
                    Expanded(
                      child: _Content(destination: _selectedDestination),
                    ),
                  ],
                )
              : _Content(destination: _selectedDestination),
          bottomNavigationBar: isDesktopLayout
              ? null
              : NavigationBar(
                  selectedIndex: _selectedIndex,
                  onDestinationSelected: _selectDestination,
                  destinations: _destinations
                      .map(
                        (destination) => NavigationDestination(
                          icon: Icon(destination.icon),
                          selectedIcon: Icon(destination.selectedIcon),
                          label: destination.label,
                        ),
                      )
                      .toList(),
                ),
        );
      },
    );
  }

  _Destination get _selectedDestination => _destinations[_selectedIndex];

  void _selectDestination(int index) {
    setState(() => _selectedIndex = index);
  }
}

class _AppTitle extends StatelessWidget {
  const _AppTitle();

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final colors = theme.colorScheme;

    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        Container(
          width: 36,
          height: 36,
          decoration: BoxDecoration(
            color: colors.primaryContainer,
            borderRadius: BorderRadius.circular(12),
          ),
          child: Icon(Icons.hub_outlined, color: colors.onPrimaryContainer),
        ),
        const SizedBox(width: 12),
        Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text('Nexus', style: theme.textTheme.titleLarge),
            Text(
              'Aggregation toolbox',
              style: theme.textTheme.labelMedium?.copyWith(
                color: colors.onSurfaceVariant,
              ),
            ),
          ],
        ),
      ],
    );
  }
}

class _Content extends StatelessWidget {
  const _Content({required this.destination});

  final _Destination destination;

  @override
  Widget build(BuildContext context) {
    if (destination.label == '玩机空间') {
      return const TinkeringSpaceScreen();
    }

    return SafeArea(
      top: false,
      child: Center(
        child: Padding(
          padding: const EdgeInsets.all(24),
          child: EmptyToolboxState(destinationName: destination.label),
        ),
      ),
    );
  }
}

class _Destination {
  const _Destination({
    required this.label,
    required this.icon,
    required this.selectedIcon,
  });

  final String label;
  final IconData icon;
  final IconData selectedIcon;
}
