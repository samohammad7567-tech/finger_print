import 'package:flutter/material.dart';

import '../style/theme/app_dimens.dart';
import '../style/theme/context_extension.dart';

/// One grey placeholder in the shape of the thing that has not arrived yet.
///
/// A skeleton is not a spinner with extra steps: it claims the same space the
/// real content will claim, so nothing jumps when the data lands. That only
/// works if the call site builds the *layout* out of these — a row of cells at
/// the table's own row height, a card with a title line and three body lines —
/// rather than dropping one grey slab where a screen used to be.
///
/// The sweep is not here. Wrap a group in [AppShimmer] and it animates all of
/// them off one ticker; a skeleton on its own is a static box, which is also
/// the correct rendering when the viewer has asked for reduced motion.
class AppSkeleton extends StatelessWidget {
  /// A rectangle of [width] x [height]. A null [width] fills the parent.
  const AppSkeleton({
    super.key,
    this.width,
    required this.height,
    this.radius = AppDimens.radiusSm,
  }) : _shape = BoxShape.rectangle;

  /// A line of text that is not there yet. Sized to the line, not the glyphs:
  /// [height] defaults to the 13px body face's drawn height.
  const AppSkeleton.line({super.key, this.width, this.height = 11})
    : radius = AppDimens.radiusXs,
      _shape = BoxShape.rectangle;

  /// An avatar, a status dot, a round icon slot.
  const AppSkeleton.circle({super.key, required double size})
    : width = size,
      height = size,
      radius = 0,
      _shape = BoxShape.circle;

  final double? width;
  final double height;
  final double radius;
  final BoxShape _shape;

  @override
  Widget build(BuildContext context) {
    return Container(
      width: width,
      height: height,
      decoration: BoxDecoration(
        color: context.color.muted,
        shape: _shape,
        borderRadius: _shape == BoxShape.circle
            ? null
            : BorderRadius.circular(radius),
      ),
    );
  }
}

/// Sweeps a band of light across every [AppSkeleton] beneath it.
///
/// One ticker for the whole subtree. A table skeleton is sixty boxes, and
/// sixty controllers animating in step is sixty times the work for a result
/// indistinguishable from this.
///
/// Renders its child untouched — static grey, still correctly shaped — when
/// the platform reports reduced motion, or when [enabled] is false because the
/// data has arrived and the skeleton is on its way out.
class AppShimmer extends StatefulWidget {
  const AppShimmer({super.key, required this.child, this.enabled = true});

  final Widget child;
  final bool enabled;

  @override
  State<AppShimmer> createState() => _AppShimmerState();
}

class _AppShimmerState extends State<AppShimmer>
    with SingleTickerProviderStateMixin {
  late final AnimationController _controller = AnimationController(
    vsync: this,
    duration: const Duration(milliseconds: 1400),
  );

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    // Asked every build rather than cached: the setting can change under a
    // running app, and a skeleton that keeps sweeping after the viewer turned
    // motion off is the one place it would be noticed.
    final still =
        !widget.enabled || MediaQuery.maybeDisableAnimationsOf(context) == true;

    if (still) {
      if (_controller.isAnimating) _controller.stop();
      return widget.child;
    }

    if (!_controller.isAnimating) _controller.repeat();

    final base = context.color.muted;
    // A contrast sweep rather than a lighter one: `muted` sits above `card` in
    // the light palette and below it in the dark, so leaning on the foreground
    // ink is the only direction that reads as movement in both.
    final crest = Color.lerp(base, context.color.mutedForeground, 0.10)!;

    return AnimatedBuilder(
      animation: _controller,
      builder: (context, child) => ShaderMask(
        blendMode: BlendMode.srcATop,
        shaderCallback: (bounds) => LinearGradient(
          colors: <Color>[base, crest, base],
          stops: const <double>[0.32, 0.5, 0.68],
          transform: _Sweep(
            _controller.value,
            Directionality.maybeOf(context) ?? TextDirection.ltr,
          ),
        ).createShader(bounds),
        child: child,
      ),
      child: widget.child,
    );
  }
}

/// Slides the gradient from one edge to the other, leading edge first — so the
/// sweep runs right-to-left in Arabic without the caller knowing.
class _Sweep extends GradientTransform {
  const _Sweep(this.t, this.direction);

  final double t;
  final TextDirection direction;

  @override
  Matrix4 transform(Rect bounds, {TextDirection? textDirection}) {
    final travel = bounds.width * (t * 3 - 1);
    return Matrix4.translationValues(
      direction == TextDirection.rtl ? -travel : travel,
      0,
      0,
    );
  }
}
