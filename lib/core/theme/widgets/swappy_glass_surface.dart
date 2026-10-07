import 'dart:ui';

import 'package:flutter/material.dart';

import '../swappy_visual_theme.dart';

/// A bounded, reusable glass layer for top-level controls and navigation.
///
/// Keep ordinary content cards on standard surfaces. Multiple overlapping
/// backdrop filters are deliberately avoided to protect frame performance.
class SwappyGlassSurface extends StatelessWidget {
  const SwappyGlassSurface({
    required this.child,
    super.key,
    this.padding = EdgeInsets.zero,
    this.borderRadius = SwappyRadii.dock,
    this.blurSigma = 18,
  });

  final Widget child;
  final EdgeInsetsGeometry padding;
  final double borderRadius;
  final double blurSigma;

  @override
  Widget build(BuildContext context) {
    final visual = context.swappyVisual;
    final radius = BorderRadius.circular(borderRadius);

    return RepaintBoundary(
      child: DecoratedBox(
        decoration: BoxDecoration(
          borderRadius: radius,
          boxShadow: [
            BoxShadow(
              color: visual.glassShadow,
              blurRadius: 28,
              spreadRadius: -8,
              offset: const Offset(0, 12),
            ),
          ],
        ),
        child: DecoratedBox(
          decoration: BoxDecoration(
            borderRadius: radius,
            gradient: visual.dockRimGradient,
          ),
          child: Padding(
            padding: const EdgeInsets.all(1),
            child: ClipRRect(
              borderRadius: BorderRadius.circular(borderRadius - 1),
              child: BackdropFilter(
                filter: ImageFilter.blur(sigmaX: blurSigma, sigmaY: blurSigma),
                child: DecoratedBox(
                  decoration: BoxDecoration(gradient: visual.glassGradient),
                  child: Padding(padding: padding, child: child),
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }
}
