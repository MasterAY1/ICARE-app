import 'dart:math' as math;

import 'package:flutter/material.dart';

import '../../../../core/theme/icare_colors.dart';

/// Shared institutional ICARE crest medallion used across Welcome Splash and Auth Entry.
///
/// Preserves the official `assets/icare_logo.png` asset with Hero continuity,
/// optional reduced-motion-aware halo/sweep, and crisp monogram fallback.
class IcareBrandCrest extends StatefulWidget {
  final double size;
  final String? heroTag;
  final bool animateSweep;
  final bool showAccentRing;

  const IcareBrandCrest({
    super.key,
    this.size = 96,
    this.heroTag = 'icare_brand_crest',
    this.animateSweep = true,
    this.showAccentRing = true,
  });

  @override
  State<IcareBrandCrest> createState() => _IcareBrandCrestState();
}

class _IcareBrandCrestState extends State<IcareBrandCrest>
    with SingleTickerProviderStateMixin {
  AnimationController? _sweepController;
  bool _disableAnimations = false;

  @override
  void initState() {
    super.initState();
    _sweepController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 2400),
    );
  }

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    _disableAnimations = MediaQuery.disableAnimationsOf(context);
    _syncAnimationState();
  }

  @override
  void didUpdateWidget(covariant IcareBrandCrest oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.animateSweep != widget.animateSweep) {
      _syncAnimationState();
    }
  }

  void _syncAnimationState() {
    final controller = _sweepController;
    if (controller == null) return;
    if (widget.animateSweep && !_disableAnimations) {
      if (!controller.isAnimating) {
        controller.repeat();
      }
    } else {
      controller.stop();
      controller.value = 0.0;
    }
  }

  @override
  void dispose() {
    _sweepController?.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final double innerSize = widget.size;
    final Widget medallion = Semantics(
      label: 'ICARE Core Banking Institutional Crest',
      image: true,
      child: Container(
        width: innerSize,
        height: innerSize,
        padding: EdgeInsets.all(innerSize * 0.06),
        decoration: BoxDecoration(
          shape: BoxShape.circle,
          gradient: const LinearGradient(
            begin: Alignment.topLeft,
            end: Alignment.bottomRight,
            colors: [
              Color(0xFF0A684F),
              IcareColors.primaryDark,
            ],
          ),
          border: Border.all(
            color: widget.showAccentRing
                ? const Color(0xFF34D399).withValues(alpha: 0.48)
                : Colors.white.withValues(alpha: 0.22),
            width: innerSize >= 88 ? 2.0 : 1.5,
          ),
          boxShadow: [
            BoxShadow(
              color: const Color(0xFF10B981).withValues(alpha: 0.22),
              blurRadius: innerSize * 0.28,
              spreadRadius: 1,
            ),
            BoxShadow(
              color: IcareColors.primaryDark.withValues(alpha: 0.45),
              blurRadius: 14,
              offset: const Offset(0, 6),
            ),
          ],
        ),
        child: Stack(
          alignment: Alignment.center,
          children: [
            Container(
              decoration: const BoxDecoration(
                shape: BoxShape.circle,
                color: Colors.white,
              ),
              clipBehavior: Clip.antiAlias,
              child: Image.asset(
                'assets/icare_logo.png',
                fit: BoxFit.cover,
                width: innerSize,
                height: innerSize,
                errorBuilder: (context, error, stackTrace) {
                  return Center(
                    child: Text(
                      'IC',
                      style: TextStyle(
                        color: IcareColors.primary,
                        fontSize: innerSize * 0.30,
                        fontWeight: FontWeight.w800,
                        letterSpacing: -0.5,
                      ),
                    ),
                  );
                },
              ),
            ),
            if (widget.animateSweep &&
                !_disableAnimations &&
                _sweepController != null)
              IgnorePointer(
                child: ClipOval(
                  child: AnimatedBuilder(
                    animation: _sweepController!,
                    builder: (context, _) {
                      final double slide =
                          (_sweepController!.value * 2.6) - 1.3;
                      return Transform.translate(
                        offset: Offset(slide * innerSize, 0),
                        child: Transform.rotate(
                          angle: math.pi / 6,
                          child: Container(
                            width: innerSize * 0.26,
                            height: innerSize * 1.4,
                            decoration: BoxDecoration(
                              gradient: LinearGradient(
                                colors: [
                                  Colors.white.withValues(alpha: 0.0),
                                  Colors.white.withValues(alpha: 0.22),
                                  Colors.white.withValues(alpha: 0.0),
                                ],
                              ),
                            ),
                          ),
                        ),
                      );
                    },
                  ),
                ),
              ),
          ],
        ),
      ),
    );

    final String? tag = widget.heroTag;
    if (tag == null || tag.isEmpty) {
      return medallion;
    }

    return Hero(
      tag: tag,
      flightShuttleBuilder: (
        BuildContext flightContext,
        Animation<double> animation,
        HeroFlightDirection flightDirection,
        BuildContext fromHeroContext,
        BuildContext toHeroContext,
      ) {
        return Material(
          color: Colors.transparent,
          child: toHeroContext.widget,
        );
      },
      child: Material(
        color: Colors.transparent,
        child: medallion,
      ),
    );
  }
}

/// Crisp, lightweight custom painter rendering subtle institutional emerald rings
/// and grid accents across dark brand canopies without expensive blur layers.
class IcareEmeraldBackdropPainter extends CustomPainter {
  final double? alignmentYFactor;

  const IcareEmeraldBackdropPainter({this.alignmentYFactor = 0.28});

  @override
  void paint(Canvas canvas, Size size) {
    final Offset center = Offset(
      size.width * 0.5,
      size.height * (alignmentYFactor ?? 0.28),
    );
    final double baseRadius = math.min(size.width, size.height) * 0.28;

    final Paint ringPaint = Paint()
      ..style = PaintingStyle.stroke
      ..strokeWidth = 1.0
      ..color = const Color(0xFF34D399).withValues(alpha: 0.09);

    for (int i = 1; i <= 4; i++) {
      canvas.drawCircle(center, baseRadius * i * 0.72, ringPaint);
    }

    final Paint fineGridPaint = Paint()
      ..style = PaintingStyle.stroke
      ..strokeWidth = 0.6
      ..color = Colors.white.withValues(alpha: 0.03);

    const double step = 48.0;
    for (double x = 0; x < size.width; x += step) {
      canvas.drawLine(Offset(x, 0), Offset(x, size.height), fineGridPaint);
    }
    for (double y = 0; y < size.height; y += step) {
      canvas.drawLine(Offset(0, y), Offset(size.width, y), fineGridPaint);
    }
  }

  @override
  bool shouldRepaint(covariant IcareEmeraldBackdropPainter oldDelegate) {
    return oldDelegate.alignmentYFactor != alignmentYFactor;
  }
}
