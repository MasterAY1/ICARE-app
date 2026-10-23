import 'package:flutter/material.dart';
import '../theme/icare_colors.dart';
import '../theme/icare_spacing.dart';

/// Clean loading skeleton for cards and metrics with smooth curved shimmer animation
class IcareSkeletonLoader extends StatefulWidget {
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
  State<IcareSkeletonLoader> createState() => _IcareSkeletonLoaderState();
}

class _IcareSkeletonLoaderState extends State<IcareSkeletonLoader>
    with SingleTickerProviderStateMixin {
  late AnimationController _controller;
  late Animation<double> _animation;

  @override
  void initState() {
    super.initState();
    _controller = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 1200),
    )..repeat(reverse: true);
    _animation = Tween<double>(begin: 0.4, end: 0.9).animate(
      CurvedAnimation(parent: _controller, curve: Curves.easeInOut),
    );
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return AnimatedBuilder(
      animation: _animation,
      builder: (context, child) {
        return Opacity(
          opacity: _animation.value,
          child: Container(
            height: widget.height,
            width: widget.width ?? double.infinity,
            decoration: BoxDecoration(
              color: const Color(0xFFE2E8F0),
              borderRadius: widget.borderRadius ?? IcareSpacing.roundedMd,
              border: Border.all(color: IcareColors.border),
            ),
          ),
        );
      },
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
              color: Colors.white,
              borderRadius: IcareSpacing.roundedLg,
              border: Border.all(color: IcareColors.border),
            ),
            child: Column(
              children: [
                // Header placeholder row
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
                  decoration: const BoxDecoration(
                    color: Color(0xFFF1F5F9),
                    borderRadius: BorderRadius.vertical(top: Radius.circular(8)),
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
                const Divider(height: 1, color: IcareColors.border),
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
                        const Divider(height: 1, color: Color(0xFFF1F5F9)),
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
            color: Colors.white,
            borderRadius: IcareSpacing.roundedMd,
            border: Border.all(color: IcareColors.border),
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
              color: Colors.white,
              borderRadius: IcareSpacing.roundedLg,
              border: Border.all(color: IcareColors.border),
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
    final animation = IcareShimmer.of(context);
    final base = baseColor ?? const Color(0xFFF1F5F9);
    final highlight = highlightColor ?? const Color(0xFFE2E8F0);

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
          _buildPortfolioShareSkeleton(mobile),
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
          _buildGovernanceSkeleton(),
          const SizedBox(height: 32),
        ],
      ),
    );
  }

  Widget _buildPortfolioShareSkeleton(bool mobile) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: const Color(0xFFE2E8F0)),
        boxShadow: const [
          BoxShadow(color: Color(0x040F172A), blurRadius: 4, offset: Offset(0, 1)),
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
                    decoration: const BoxDecoration(
                      color: Color(0xFFCBD5E1),
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
      itemBuilder: (_, __) {
        return Container(
          padding: const EdgeInsets.all(12),
          decoration: BoxDecoration(
            color: Colors.white,
            borderRadius: BorderRadius.circular(10),
            border: Border.all(color: const Color(0xFFE2E8F0)),
            boxShadow: const [BoxShadow(color: Color(0x040F172A), blurRadius: 3, offset: Offset(0, 1))],
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

  Widget _buildGovernanceSkeleton() {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: const Color(0xFFF8FAFC),
        borderRadius: BorderRadius.circular(10),
        border: Border.all(color: const Color(0xFFE2E8F0)),
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
    return Container(
      padding: const EdgeInsets.all(18),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: const Color(0xFFE2E8F0)),
        boxShadow: const [
          BoxShadow(color: Color(0x060F172A), blurRadius: 6, offset: Offset(0, 2)),
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
              color: const Color(0xFFF8FAFC),
              borderRadius: BorderRadius.circular(8),
              border: Border.all(color: const Color(0xFFE2E8F0)),
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

