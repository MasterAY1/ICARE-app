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
