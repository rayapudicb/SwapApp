import 'package:flutter/material.dart';

import '../swappy_visual_theme.dart';
import 'swappy_glass_surface.dart';

@immutable
class SwappyDockDestination {
  const SwappyDockDestination({required this.icon, required this.label});

  final IconData icon;
  final String label;
}

/// Swappy's floating navigation dock.
///
/// Selection is communicated by the outlined icon's gradient stroke, label
/// color and semantics. It intentionally has no inner circle or selected pill.
class SwappyFloatingDock extends StatelessWidget {
  const SwappyFloatingDock({
    required this.destinations,
    required this.selectedIndex,
    required this.onDestinationSelected,
    super.key,
    this.visible = true,
  }) : assert(destinations.length >= 2),
       assert(selectedIndex >= 0 && selectedIndex < destinations.length);

  final List<SwappyDockDestination> destinations;
  final int selectedIndex;
  final ValueChanged<int> onDestinationSelected;
  final bool visible;

  @override
  Widget build(BuildContext context) {
    final duration = SwappyMotion.duration(context, SwappyMotion.standard);

    return IgnorePointer(
      ignoring: !visible,
      child: AnimatedSlide(
        duration: duration,
        curve: SwappyMotion.expressive,
        offset: visible ? Offset.zero : const Offset(0, 1.35),
        child: AnimatedOpacity(
          duration: duration,
          curve: SwappyMotion.fluid,
          opacity: visible ? 1 : 0,
          child: SwappyGlassSurface(
            key: const ValueKey('swappy-floating-dock-surface'),
            padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 7),
            child: Material(
              type: MaterialType.transparency,
              child: SizedBox(
                height: 62,
                child: Row(
                  children: [
                    for (var index = 0; index < destinations.length; index++)
                      Expanded(
                        child: _DockDestination(
                          destination: destinations[index],
                          selected: index == selectedIndex,
                          index: index,
                          onTap: () => onDestinationSelected(index),
                        ),
                      ),
                  ],
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }
}

class _DockDestination extends StatelessWidget {
  const _DockDestination({
    required this.destination,
    required this.selected,
    required this.index,
    required this.onTap,
  });

  final SwappyDockDestination destination;
  final bool selected;
  final int index;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final visual = context.swappyVisual;
    final duration = SwappyMotion.duration(context, SwappyMotion.quick);
    final labelStyle = Theme.of(context).textTheme.labelSmall?.copyWith(
      color: selected ? visual.selectedIconStroke : visual.inactiveIcon,
      fontWeight: selected ? FontWeight.w700 : FontWeight.w500,
    );

    return Semantics(
      button: true,
      selected: selected,
      label: destination.label,
      child: Tooltip(
        message: destination.label,
        child: InkResponse(
          key: ValueKey('swappy-dock-destination-$index'),
          onTap: onTap,
          containedInkWell: true,
          highlightShape: BoxShape.rectangle,
          radius: 38,
          child: ExcludeSemantics(
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              mainAxisSize: MainAxisSize.min,
              children: [
                AnimatedScale(
                  duration: duration,
                  curve: SwappyMotion.expressive,
                  scale: selected ? 1.06 : 1,
                  child: _StrokedDockIcon(
                    icon: destination.icon,
                    selected: selected,
                    index: index,
                  ),
                ),
                const SizedBox(height: 3),
                AnimatedDefaultTextStyle(
                  duration: duration,
                  curve: SwappyMotion.fluid,
                  style: labelStyle ?? const TextStyle(),
                  child: Text(destination.label),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

class _StrokedDockIcon extends StatelessWidget {
  const _StrokedDockIcon({
    required this.icon,
    required this.selected,
    required this.index,
  });

  final IconData icon;
  final bool selected;
  final int index;

  @override
  Widget build(BuildContext context) {
    final visual = context.swappyVisual;
    final iconWidget = Icon(
      icon,
      size: 25,
      fill: 0,
      weight: selected ? 700 : 400,
      color: selected ? visual.onEnergy : visual.inactiveIcon,
      shadows: selected
          ? [
              Shadow(
                color: visual.selectedIconStroke.withValues(alpha: 0.7),
                blurRadius: 10,
              ),
            ]
          : null,
    );

    if (!selected) return iconWidget;
    return ShaderMask(
      key: ValueKey('swappy-dock-selected-icon-stroke-$index'),
      blendMode: BlendMode.srcIn,
      shaderCallback: visual.selectedIconGradient.createShader,
      child: iconWidget,
    );
  }
}
