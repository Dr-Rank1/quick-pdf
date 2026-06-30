import 'package:flutter/material.dart';

/// Shared hero tag for document thumbnail → viewer transitions.
String docThumbHeroTag(String path) => 'doc_thumb_$path';

/// Fades the source thumbnail out on push (so pdfx can render underneath)
/// and fades it back in on pop.
Widget docThumbHeroFlightShuttle(
  BuildContext flightContext,
  Animation<double> animation,
  HeroFlightDirection flightDirection,
  BuildContext fromHeroContext,
  BuildContext toHeroContext,
) {
  final fromHero = fromHeroContext.widget as Hero;
  final Widget shuttleChild = fromHero.child;

  return AnimatedBuilder(
    animation: animation,
    builder: (context, child) {
      final t = Curves.easeInOutCubic.transform(animation.value);
      final opacity = flightDirection == HeroFlightDirection.push
          ? (1.0 - t).clamp(0.0, 1.0)
          : t.clamp(0.0, 1.0);

      return Opacity(
        opacity: opacity,
        child: Material(
          type: MaterialType.transparency,
          child: child,
        ),
      );
    },
    child: shuttleChild,
  );
}
