import 'dart:ui';

import 'package:flutter/material.dart';

class FloatingMaterialTabBar extends StatelessWidget {
  const FloatingMaterialTabBar({
    super.key,
    required this.destinations,
    required this.selectedIndex,
    required this.onSelected,
    required this.height,
  });

  static double heightFor(TextScaler textScaler) {
    final labelHeight = textScaler.scale(11) * 2;
    return (38 + labelHeight).clamp(60.0, double.infinity);
  }

  final List<NavigationDestination> destinations;
  final int selectedIndex;
  final ValueChanged<int> onSelected;
  final double height;

  @override
  Widget build(BuildContext context) {
    final colors = Theme.of(context).colorScheme;
    final dark = colors.brightness == Brightness.dark;
    final shape = BorderRadius.circular(height / 2);
    return SizedBox(
      height: height,
      child: DecoratedBox(
        decoration: BoxDecoration(
          borderRadius: shape,
          boxShadow: [
            BoxShadow(
              color: colors.shadow.withValues(alpha: dark ? .45 : .13),
              blurRadius: 14,
              offset: const Offset(0, 4),
            ),
          ],
        ),
        child: ClipRRect(
          borderRadius: shape,
          child: BackdropFilter(
            filter: ImageFilter.blur(sigmaX: 10, sigmaY: 10),
            child: DecoratedBox(
              decoration: BoxDecoration(
                color: colors.surface.withValues(alpha: dark ? .87 : .8),
                borderRadius: shape,
                border: Border.all(
                  color: colors.outline.withValues(alpha: dark ? .55 : .36),
                ),
              ),
              child: Material(
                type: MaterialType.transparency,
                child: Padding(
                  padding: const EdgeInsets.all(5),
                  child: Row(
                    crossAxisAlignment: CrossAxisAlignment.stretch,
                    children: [
                      for (final (index, destination) in destinations.indexed)
                        Expanded(
                          child: _FloatingDestination(
                            destination: destination,
                            selected: selectedIndex == index,
                            onTap: () => onSelected(index),
                          ),
                        ),
                    ],
                  ),
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }
}

class _FloatingDestination extends StatelessWidget {
  const _FloatingDestination({
    required this.destination,
    required this.selected,
    required this.onTap,
  });

  final NavigationDestination destination;
  final bool selected;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final colors = Theme.of(context).colorScheme;
    final foreground = selected ? colors.primary : colors.onSurface;
    return Semantics(
      button: true,
      selected: selected,
      label: destination.label,
      excludeSemantics: true,
      onTap: onTap,
      child: Ink(
        decoration: ShapeDecoration(
          shape: const StadiumBorder(),
          color: selected
              ? colors.onSurface.withValues(alpha: .11)
              : Colors.transparent,
        ),
        child: InkWell(
          customBorder: const StadiumBorder(),
          onTap: onTap,
          child: Padding(
            padding: const EdgeInsets.symmetric(horizontal: 3),
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                IconTheme(
                  data: IconThemeData(color: foreground, size: 21),
                  child: destination.icon,
                ),
                const SizedBox(height: 2),
                Flexible(
                  child: Text(
                    destination.label,
                    textAlign: TextAlign.center,
                    maxLines: 2,
                    overflow: TextOverflow.ellipsis,
                    style: TextStyle(
                      color: foreground,
                      fontSize: 11,
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}
