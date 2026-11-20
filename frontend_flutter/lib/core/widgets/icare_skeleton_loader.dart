import 'package:flutter/material.dart';
import 'package:skeletonizer/skeletonizer.dart';
import '../theme/icare_motion.dart';
import '../theme/icare_spacing.dart';
import '../theme/icare_theme_tokens.dart';

/// Clean loading skeleton for cards and metrics with smooth shimmer and reduced-motion fallback.
class IcareSkeletonLoader extends StatelessWidget {
  final double height;
  final double? width;
  final BorderRadius? borderRadius;

  const IcareSkeletonLoader({
    super.key,
    this.height = 80,
    this.width,
    this.borderRadius,
  });

  @override
  Widget build(BuildContext context) {
    final tokens = IcareSurfaceTokens.of(context);
    final reduced = IcareFluidMotion.isReduced(context);
    final baseColor =
        tokens.isDark ? tokens.surfaceElevated : const Color(0xFFE2E8F0);
    final highlightColor =
        tokens.isDark ? tokens.surfaceHover : const Color(0xFFF1F5F9);

    return LayoutBuilder(
      builder: (context, constraints) {
        final effectiveWidth = width ??
            (constraints.hasBoundedWidth ? constraints.maxWidth : 120.0);

        return Skeletonizer.zone(
          effect: reduced
              ? SolidColorEffect(color: baseColor)
              : ShimmerEffect(
                  baseColor: baseColor,
                  highlightColor: highlightColor,
                  duration: const Duration(milliseconds: 1400),
                ),
          child: Bone(
            width: effectiveWidth,
            height: height,
            borderRadius: borderRadius ?? IcareSpacing.roundedMd,
          ),
        );
      },
    );
  }
}

/// Wraps any live ICARE widget or card list in a layout-matched shimmer overlay while loading.
class IcareSkeletonWrapper extends StatelessWidget {
  final bool enabled;
  final Widget child;

  const IcareSkeletonWrapper({
    super.key,
    required this.enabled,
    required this.child,
  });

  @override
  Widget build(BuildContext context) {
    final tokens = IcareSurfaceTokens.of(context);
    final reduced = IcareFluidMotion.isReduced(context);
    final baseColor =
        tokens.isDark ? tokens.surfaceElevated : const Color(0xFFE2E8F0);
    final highlightColor =
        tokens.isDark ? tokens.surfaceHover : const Color(0xFFF1F5F9);

    return Skeletonizer(
      enabled: enabled,
      enableSwitchAnimation: !reduced,
      effect: reduced
          ? SolidColorEffect(color: baseColor)
          : ShimmerEffect(
              baseColor: baseColor,
              highlightColor: highlightColor,
              duration: const Duration(milliseconds: 1400),
            ),
      child: child,
    );
  }
}

/// Dashboard loading placeholder
class IcareDashboardSkeleton extends StatelessWidget {
  final EdgeInsetsGeometry? padding;

  const IcareDashboardSkeleton({
    super.key,
    this.padding,
  });

  @override
  Widget build(BuildContext context) {
    return SingleChildScrollView(
      padding: padding ?? IcareSpacing.screenPadding(context),
      child: const Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          IcareSkeletonLoader(height: 52),
          SizedBox(height: 16),
          IcareSkeletonLoader(height: 40),
          SizedBox(height: 24),
          Row(
            children: [
              Expanded(child: IcareSkeletonLoader(height: 96)),
              SizedBox(width: 12),
              Expanded(child: IcareSkeletonLoader(height: 96)),
            ],
          ),
          SizedBox(height: 16),
          IcareSkeletonLoader(height: 180),
          SizedBox(height: 24),
          Row(
            children: [
              Expanded(child: IcareSkeletonLoader(height: 90)),
              SizedBox(width: 12),
              Expanded(child: IcareSkeletonLoader(height: 90)),
              SizedBox(width: 12),
              Expanded(child: IcareSkeletonLoader(height: 90)),
            ],
          ),
        ],
      ),
    );
  }
}

/// Table loading skeleton for audit screens, cashbooks, lists, and reports
class IcareTableSkeleton extends StatelessWidget {
  final int rowCount;
  final bool hasFilterBar;
  final EdgeInsetsGeometry? padding;

  const IcareTableSkeleton({
    super.key,
    this.rowCount = 8,
    this.hasFilterBar = true,
    this.padding,
  });

  @override
  Widget build(BuildContext context) {
    final tokens = IcareSurfaceTokens.of(context);
    return SingleChildScrollView(
      padding: padding ?? IcareSpacing.screenPadding(context),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          if (hasFilterBar) ...[
            const IcareSkeletonLoader(height: 48),
            const SizedBox(height: 16),
          ],
          Container(
            decoration: BoxDecoration(
              color: tokens.surface,
              borderRadius: IcareSpacing.roundedLg,
              border: Border.all(color: tokens.borderSubtle),
            ),
            child: Column(
              children: [
                // Header placeholder row
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
                  decoration: BoxDecoration(
                    color: tokens.surfaceHover,
                    borderRadius: const BorderRadius.vertical(top: Radius.circular(8)),
                  ),
                  child: const Row(
                    children: [
                      Expanded(flex: 2, child: IcareSkeletonLoader(height: 16)),
                      SizedBox(width: 12),
                      Expanded(flex: 3, child: IcareSkeletonLoader(height: 16)),
                      SizedBox(width: 12),
                      Expanded(flex: 2, child: IcareSkeletonLoader(height: 16)),
                      SizedBox(width: 12),
                      Expanded(flex: 2, child: IcareSkeletonLoader(height: 16)),
                    ],
                  ),
                ),
                Divider(height: 1, color: tokens.borderSubtle),
                // Body rows
                ...List.generate(rowCount, (index) {
                  return Column(
                    children: [
                      Padding(
                        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
                        child: Row(
                          children: [
                            Expanded(flex: 2, child: IcareSkeletonLoader(height: 14, borderRadius: BorderRadius.circular(4))),
                            const SizedBox(width: 12),
                            Expanded(flex: 3, child: IcareSkeletonLoader(height: 14, borderRadius: BorderRadius.circular(4))),
                            const SizedBox(width: 12),
                            Expanded(flex: 2, child: IcareSkeletonLoader(height: 14, borderRadius: BorderRadius.circular(4))),
                            const SizedBox(width: 12),
                            Expanded(flex: 2, child: IcareSkeletonLoader(height: 14, borderRadius: BorderRadius.circular(4))),
                          ],
                        ),
                      ),
                      if (index < rowCount - 1)
                        Divider(height: 1, color: tokens.borderSubtle),
                    ],
                  );
                }),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

/// Responsive KPI metric cards skeleton (2x2 on mobile, 4x1 on desktop)
class IcareCardGridSkeleton extends StatelessWidget {
  final int cardCount;
  final EdgeInsetsGeometry? padding;

  const IcareCardGridSkeleton({
    super.key,
    this.cardCount = 4,
    this.padding,
  });

  @override
  Widget build(BuildContext context) {
    final isMobile = MediaQuery.of(context).size.width < 600;
    return Padding(
      padding: padding ?? EdgeInsets.zero,
      child: isMobile
          ? const Column(
              children: [
                Row(
                  children: [
                    Expanded(child: IcareSkeletonLoader(height: 84)),
                    SizedBox(width: 8),
                    Expanded(child: IcareSkeletonLoader(height: 84)),
                  ],
                ),
                SizedBox(height: 8),
                Row(
                  children: [
                    Expanded(child: IcareSkeletonLoader(height: 84)),
                    SizedBox(width: 8),
                    Expanded(child: IcareSkeletonLoader(height: 84)),
                  ],
                ),
              ],
            )
          : const Row(
              children: [
                Expanded(child: IcareSkeletonLoader(height: 84)),
                SizedBox(width: 12),
                Expanded(child: IcareSkeletonLoader(height: 84)),
                SizedBox(width: 12),
                Expanded(child: IcareSkeletonLoader(height: 84)),
                SizedBox(width: 12),
                Expanded(child: IcareSkeletonLoader(height: 84)),
              ],
            ),
    );
  }
}

/// List / dossier skeleton with avatar and multi-line text placeholders
class IcareListSkeleton extends StatelessWidget {
  final int itemCount;
  final EdgeInsetsGeometry? padding;

  const IcareListSkeleton({
    super.key,
    this.itemCount = 6,
    this.padding,
  });

  @override
  Widget build(BuildContext context) {
    final tokens = IcareSurfaceTokens.of(context);
    return ListView.separated(
      shrinkWrap: true,
      physics: const NeverScrollableScrollPhysics(),
      padding: padding ?? IcareSpacing.screenPadding(context),
      itemCount: itemCount,
      separatorBuilder: (_, __) => const SizedBox(height: 12),
      itemBuilder: (_, __) {
        return Container(
          padding: const EdgeInsets.all(14),
          decoration: BoxDecoration(
            color: tokens.surface,
            borderRadius: IcareSpacing.roundedMd,
            border: Border.all(color: tokens.borderSubtle),
          ),
          child: const Row(
            children: [
              IcareSkeletonLoader(
                height: 40,
                width: 40,
                borderRadius: BorderRadius.all(Radius.circular(20)),
              ),
              SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    IcareSkeletonLoader(height: 14, width: 140),
                    SizedBox(height: 6),
                    IcareSkeletonLoader(height: 10, width: 90),
                  ],
                ),
              ),
              SizedBox(width: 12),
              IcareSkeletonLoader(height: 20, width: 60),
            ],
          ),
        );
      },
    );
  }
}

/// Form loading skeleton for collection sheets and operational entry forms
class IcareFormSkeleton extends StatelessWidget {
  final int fieldCount;
  final EdgeInsetsGeometry? padding;

  const IcareFormSkeleton({
    super.key,
    this.fieldCount = 4,
    this.padding,
  });

  @override
  Widget build(BuildContext context) {
    final tokens = IcareSurfaceTokens.of(context);
    return SingleChildScrollView(
      padding: padding ?? IcareSpacing.screenPadding(context),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const IcareSkeletonLoader(height: 28, width: 220),
          const SizedBox(height: 8),
          const IcareSkeletonLoader(height: 16, width: 340),
          const SizedBox(height: 20),
          Container(
            padding: const EdgeInsets.all(16),
            decoration: BoxDecoration(
              color: tokens.surface,
              borderRadius: IcareSpacing.roundedLg,
              border: Border.all(color: tokens.borderSubtle),
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                ...List.generate(fieldCount, (index) {
                  return const Padding(
                    padding: EdgeInsets.only(bottom: 16),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        IcareSkeletonLoader(height: 14, width: 100),
                        SizedBox(height: 6),
                        IcareSkeletonLoader(height: 46),
                      ],
                    ),
                  );
                }),
                const SizedBox(height: 8),
                const IcareSkeletonLoader(height: 46),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

// =============================================================================
// ICARE UNIFIED SHIMMER CONTROLLER & SHIMMER BOX (PILLAR 6)
// =============================================================================

/// Synchronized shimmer controller for high-performance multi-box page skeletons
class IcareShimmer extends StatefulWidget {
  final Widget child;
  final Duration duration;

  const IcareShimmer({
    super.key,
    required this.child,
    this.duration = const Duration(milliseconds: 1400),
  });

  static Animation<double>? of(BuildContext context) {
    return context.dependOnInheritedWidgetOfExactType<_IcareShimmerScope>()?.animation;
  }

  @override
  State<IcareShimmer> createState() => _IcareShimmerState();
}

class _IcareShimmerState extends State<IcareShimmer> with SingleTickerProviderStateMixin {
  late final AnimationController _controller;

  @override
  void initState() {
    super.initState();
    _controller = AnimationController(vsync: this, duration: widget.duration)..repeat();
  }

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    if (MediaQuery.disableAnimationsOf(context)) {
      _controller.stop();
      _controller.value = 0.5;
    } else if (!_controller.isAnimating) {
      _controller.repeat();
    }
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return _IcareShimmerScope(
      animation: _controller,
      child: widget.child,
    );
  }
}

class _IcareShimmerScope extends InheritedWidget {
  final Animation<double> animation;

  const _IcareShimmerScope({
    required this.animation,
    required super.child,
  });

  @override
  bool updateShouldNotify(_IcareShimmerScope oldWidget) => animation != oldWidget.animation;
}

/// Universal linear gradient shimmer box following ICARE design system (Pillar 6)
class SkeletonShimmerBox extends StatelessWidget {
  final double? width;
  final double height;
  final double borderRadius;
  final Color? baseColor;
  final Color? highlightColor;

  const SkeletonShimmerBox({
    super.key,
    this.width,
    required this.height,
    this.borderRadius = 8.0,
    this.baseColor,
    this.highlightColor,
  });

  @override
  Widget build(BuildContext context) {
    final tokens = IcareSurfaceTokens.of(context);
    final animation = IcareShimmer.of(context);
    final base = baseColor ?? (tokens.isDark ? tokens.surfaceHover : const Color(0xFFF1F5F9));
    final highlight = highlightColor ?? (tokens.isDark ? tokens.surfaceElevated : const Color(0xFFE2E8F0));

    if (animation == null) {
      return _StandaloneShimmerBox(
        width: width,
        height: height,
        borderRadius: borderRadius,
        baseColor: base,
        highlightColor: highlight,
      );
    }

    return AnimatedBuilder(
      animation: animation,
      builder: (context, child) {
        return Container(
          width: width,
          height: height,
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(borderRadius),
            gradient: LinearGradient(
              begin: Alignment(-1.5 + (animation.value * 3), -0.3),
              end: Alignment(-0.5 + (animation.value * 3), 0.3),
              colors: [base, highlight, base],
            ),
          ),
        );
      },
    );
  }
}

class _StandaloneShimmerBox extends StatefulWidget {
  final double? width;
  final double height;
  final double borderRadius;
  final Color baseColor;
  final Color highlightColor;

  const _StandaloneShimmerBox({
    this.width,
    required this.height,
    required this.borderRadius,
    required this.baseColor,
    required this.highlightColor,
  });

  @override
  State<_StandaloneShimmerBox> createState() => _StandaloneShimmerBoxState();
}

class _StandaloneShimmerBoxState extends State<_StandaloneShimmerBox>
    with SingleTickerProviderStateMixin {
  late final AnimationController _controller;

  @override
  void initState() {
    super.initState();
    _controller = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 1400),
    )..repeat();
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return AnimatedBuilder(
      animation: _controller,
      builder: (context, child) {
        return Container(
          width: widget.width,
          height: widget.height,
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(widget.borderRadius),
            gradient: LinearGradient(
              begin: Alignment(-1.5 + (_controller.value * 3), -0.3),
              end: Alignment(-0.5 + (_controller.value * 3), 0.3),
              colors: [widget.baseColor, widget.highlightColor, widget.baseColor],
            ),
          ),
        );
      },
    );
  }
}

// =============================================================================
// AREA MANAGER REGIONAL PORTFOLIO SKELETON LOADER
// =============================================================================

/// Tailored living skeleton for the Area Manager Regional Portfolio screen
class IcareAmPortfolioSkeleton extends StatelessWidget {
  final bool? isMobile;
  final bool? isTablet;
  final bool? isDesktop;

  const IcareAmPortfolioSkeleton({
    super.key,
    this.isMobile,
    this.isTablet,
    this.isDesktop,
  });

  @override
  Widget build(BuildContext context) {
    final width = MediaQuery.of(context).size.width;
    final mobile = isMobile ?? (width < 600);
    final tablet = isTablet ?? (width >= 600 && width < 1000);
    final desktop = isDesktop ?? (width >= 1000);

    return IcareShimmer(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // 1. Regional Loan Book Distribution Skeleton Card
          _buildPortfolioShareSkeleton(context, mobile),
          const SizedBox(height: 18),

          // 2. 6 Regional KPI Summary Cards Skeleton Grid
          _buildRegionalKpisSkeleton(mobile, tablet, desktop),
          const SizedBox(height: 24),

          // 3. Section Header Skeleton
          _buildSectionHeaderSkeleton(),
          const SizedBox(height: 14),

          // 4. Branch Summary Cards Grid Skeleton
          _buildBranchCardsSkeleton(mobile, tablet, desktop),
          const SizedBox(height: 24),

          // 5. Governance Advisory Skeleton Card
          _buildGovernanceSkeleton(context),
          const SizedBox(height: 32),
        ],
      ),
    );
  }

  Widget _buildPortfolioShareSkeleton(BuildContext context, bool mobile) {
    final tokens = IcareSurfaceTokens.of(context);
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: tokens.surface,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: tokens.borderSubtle),
        boxShadow: [
          BoxShadow(color: tokens.isDark ? const Color(0x20000000) : const Color(0x040F172A), blurRadius: 4, offset: const Offset(0, 1)),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              SkeletonShimmerBox(width: 200, height: 14, borderRadius: 4),
              SkeletonShimmerBox(width: 90, height: 12, borderRadius: 4),
            ],
          ),
          const SizedBox(height: 12),
          const SkeletonShimmerBox(height: 10, borderRadius: 6),
          const SizedBox(height: 14),
          Wrap(
            spacing: 16,
            runSpacing: 8,
            children: List.generate(3, (index) {
              return Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Container(
                    width: 8,
                    height: 8,
                    decoration: BoxDecoration(
                      color: tokens.borderStrong,
                      shape: BoxShape.circle,
                    ),
                  ),
                  const SizedBox(width: 6),
                  SkeletonShimmerBox(width: mobile ? 95 : 130, height: 12, borderRadius: 4),
                ],
              );
            }),
          ),
        ],
      ),
    );
  }

  Widget _buildRegionalKpisSkeleton(bool mobile, bool tablet, bool desktop) {
    final crossAxisCount = desktop ? 6 : (tablet ? 3 : 2);
    return GridView.builder(
      shrinkWrap: true,
      physics: const NeverScrollableScrollPhysics(),
      itemCount: 6,
      gridDelegate: SliverGridDelegateWithFixedCrossAxisCount(
        crossAxisCount: crossAxisCount,
        crossAxisSpacing: 10,
        mainAxisSpacing: 10,
        childAspectRatio: desktop ? 1.55 : 1.65,
      ),
      itemBuilder: (ctx, __) {
        final tokens = IcareSurfaceTokens.of(ctx);
        return Container(
          padding: const EdgeInsets.all(12),
          decoration: BoxDecoration(
            color: tokens.surface,
            borderRadius: BorderRadius.circular(10),
            border: Border.all(color: tokens.borderSubtle),
            boxShadow: [BoxShadow(color: tokens.isDark ? const Color(0x20000000) : const Color(0x040F172A), blurRadius: 3, offset: const Offset(0, 1))],
          ),
          child: const Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  SkeletonShimmerBox(width: 70, height: 11, borderRadius: 3),
                  SkeletonShimmerBox(width: 26, height: 26, borderRadius: 6),
                ],
              ),
              SkeletonShimmerBox(width: 100, height: 18, borderRadius: 4),
              SkeletonShimmerBox(width: 80, height: 10, borderRadius: 3),
            ],
          ),
        );
      },
    );
  }

  Widget _buildSectionHeaderSkeleton() {
    return const Row(
      mainAxisAlignment: MainAxisAlignment.spaceBetween,
      children: [
        Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            SkeletonShimmerBox(width: 190, height: 18, borderRadius: 4),
            SizedBox(height: 6),
            SkeletonShimmerBox(width: 260, height: 12, borderRadius: 3),
          ],
        ),
        SkeletonShimmerBox(width: 32, height: 32, borderRadius: 8),
      ],
    );
  }

  Widget _buildBranchCardsSkeleton(bool mobile, bool tablet, bool desktop) {
    const count = 3;
    if (mobile) {
      return Column(
        children: List.generate(
          count,
          (_) => const Padding(
            padding: EdgeInsets.only(bottom: 16),
            child: _BranchCardSkeleton(),
          ),
        ),
      );
    }

    final crossAxisCount = desktop ? 3 : 2;
    return GridView.builder(
      shrinkWrap: true,
      physics: const NeverScrollableScrollPhysics(),
      itemCount: count,
      gridDelegate: SliverGridDelegateWithFixedCrossAxisCount(
        crossAxisCount: crossAxisCount,
        crossAxisSpacing: 16,
        mainAxisSpacing: 16,
        childAspectRatio: desktop ? 0.88 : 0.95,
      ),
      itemBuilder: (_, __) => const _BranchCardSkeleton(),
    );
  }

  Widget _buildGovernanceSkeleton(BuildContext context) {
    final tokens = IcareSurfaceTokens.of(context);
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: tokens.surfaceSubtle,
        borderRadius: BorderRadius.circular(10),
        border: Border.all(color: tokens.borderSubtle),
      ),
      child: const Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          SkeletonShimmerBox(width: 32, height: 32, borderRadius: 8),
          SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                SkeletonShimmerBox(width: 160, height: 14, borderRadius: 3),
                SizedBox(height: 6),
                SkeletonShimmerBox(width: double.infinity, height: 11, borderRadius: 3),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

class _BranchCardSkeleton extends StatelessWidget {
  const _BranchCardSkeleton();

  @override
  Widget build(BuildContext context) {
    final tokens = IcareSurfaceTokens.of(context);
    return Container(
      padding: const EdgeInsets.all(18),
      decoration: BoxDecoration(
        color: tokens.surface,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: tokens.borderSubtle),
        boxShadow: [
          BoxShadow(color: tokens.isDark ? const Color(0x20000000) : const Color(0x060F172A), blurRadius: 6, offset: const Offset(0, 2)),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Header: branch name pill & status badges
          const Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              SkeletonShimmerBox(width: 90, height: 26, borderRadius: 6),
              SkeletonShimmerBox(width: 80, height: 22, borderRadius: 6),
            ],
          ),
          const SizedBox(height: 8),
          const Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              SkeletonShimmerBox(width: 70, height: 18, borderRadius: 4),
              SkeletonShimmerBox(width: 60, height: 18, borderRadius: 4),
            ],
          ),
          const SizedBox(height: 14),

          // Progress bar
          const SkeletonShimmerBox(height: 8, borderRadius: 4),
          const SizedBox(height: 8),
          const Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              SkeletonShimmerBox(width: 100, height: 11, borderRadius: 3),
              SkeletonShimmerBox(width: 100, height: 11, borderRadius: 3),
            ],
          ),
          const SizedBox(height: 14),

          // 3 Metric columns
          Container(
            padding: const EdgeInsets.all(10),
            decoration: BoxDecoration(
              color: tokens.surfaceSubtle,
              borderRadius: BorderRadius.circular(8),
              border: Border.all(color: tokens.borderSubtle),
            ),
            child: const Row(
              mainAxisAlignment: MainAxisAlignment.spaceAround,
              children: [
                Column(
                  children: [
                    SkeletonShimmerBox(width: 48, height: 10, borderRadius: 3),
                    SizedBox(height: 4),
                    SkeletonShimmerBox(width: 65, height: 14, borderRadius: 3),
                  ],
                ),
                Column(
                  children: [
                    SkeletonShimmerBox(width: 48, height: 10, borderRadius: 3),
                    SizedBox(height: 4),
                    SkeletonShimmerBox(width: 65, height: 14, borderRadius: 3),
                  ],
                ),
                Column(
                  children: [
                    SkeletonShimmerBox(width: 48, height: 10, borderRadius: 3),
                    SizedBox(height: 4),
                    SkeletonShimmerBox(width: 65, height: 14, borderRadius: 3),
                  ],
                ),
              ],
            ),
          ),
          const SizedBox(height: 14),

          // Officers Header & Table rows placeholder
          const SkeletonShimmerBox(width: 110, height: 13, borderRadius: 3),
          const SizedBox(height: 8),
          const SkeletonShimmerBox(height: 24, borderRadius: 4),
          const SizedBox(height: 6),
          const SkeletonShimmerBox(height: 24, borderRadius: 4),
        ],
      ),
    );
  }
}

// =============================================================================
// BRANCH ONBOARDING LIVING SKELETON
// =============================================================================

/// Living skeleton loader for the Branch Onboarding Management screen
class IcareOnboardingSkeleton extends StatelessWidget {
  final int cardCount;

  const IcareOnboardingSkeleton({
    super.key,
    this.cardCount = 3,
  });

  @override
  Widget build(BuildContext context) {
    final tokens = IcareSurfaceTokens.of(context);
    return IcareShimmer(
      child: Column(
        children: List.generate(
          cardCount,
          (_) => Container(
            margin: const EdgeInsets.only(bottom: 12),
            padding: const EdgeInsets.all(18),
            decoration: BoxDecoration(
              color: tokens.surface,
              borderRadius: BorderRadius.circular(10),
              border: Border.all(color: tokens.borderSubtle),
            ),
            child: const Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                // Header row: branch pill & status badge
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    Row(
                      children: [
                        SkeletonShimmerBox(width: 80, height: 24, borderRadius: 4),
                        SizedBox(width: 8),
                        SkeletonShimmerBox(width: 140, height: 18, borderRadius: 4),
                      ],
                    ),
                    SkeletonShimmerBox(width: 75, height: 22, borderRadius: 12),
                  ],
                ),
                SizedBox(height: 14),

                // Contact details row
                Row(
                  children: [
                    SkeletonShimmerBox(width: 120, height: 12, borderRadius: 3),
                    SizedBox(width: 16),
                    SkeletonShimmerBox(width: 100, height: 12, borderRadius: 3),
                  ],
                ),
                SizedBox(height: 14),

                // Metrics row (Groups, Members, Savings, Balance)
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        SkeletonShimmerBox(width: 50, height: 10, borderRadius: 2),
                        SizedBox(height: 4),
                        SkeletonShimmerBox(width: 65, height: 16, borderRadius: 3),
                      ],
                    ),
                    Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        SkeletonShimmerBox(width: 50, height: 10, borderRadius: 2),
                        SizedBox(height: 4),
                        SkeletonShimmerBox(width: 65, height: 16, borderRadius: 3),
                      ],
                    ),
                    Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        SkeletonShimmerBox(width: 50, height: 10, borderRadius: 2),
                        SizedBox(height: 4),
                        SkeletonShimmerBox(width: 75, height: 16, borderRadius: 3),
                      ],
                    ),
                    Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        SkeletonShimmerBox(width: 50, height: 10, borderRadius: 2),
                        SizedBox(height: 4),
                        SkeletonShimmerBox(width: 75, height: 16, borderRadius: 3),
                      ],
                    ),
                  ],
                ),
                SizedBox(height: 16),

                // Action buttons row
                Row(
                  mainAxisAlignment: MainAxisAlignment.end,
                  children: [
                    SkeletonShimmerBox(width: 80, height: 30, borderRadius: 6),
                    SizedBox(width: 8),
                    SkeletonShimmerBox(width: 100, height: 30, borderRadius: 6),
                  ],
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}


