# ICARE Flutter Widget Blueprints

Ready-to-use Flutter widget blueprints adhering strictly to the ICARE Design System tokens, animations, and anti-clipping invariants.

---

## 1. NoticeBanner (Anti-Clipping Invariant Enforced)

Guarantees 100% responsive text wrapping on mobile screens (< 450dp), resolving the horizontal overflow defect permanently.

```dart
import 'package:flutter/material.dart';

enum NoticeType { info, success, warning, danger, neutral }

class NoticeBanner extends StatelessWidget {
  final String message;
  final NoticeType type;
  final IconData? customIcon;
  final VoidCallback? onAction;
  final String? actionLabel;

  const NoticeBanner({
    super.key,
    required this.message,
    this.type = NoticeType.neutral,
    this.customIcon,
    this.onAction,
    this.actionLabel,
  });

  @override
  Widget build(BuildContext context) {
    final (bg, border, text, icon) = switch (type) {
      NoticeType.success => (
        const Color(0xFFECFDF5),
        const Color(0xFFA7F3D0),
        const Color(0xFF065F46),
        Icons.check_circle_outline,
      ),
      NoticeType.warning => (
        const Color(0xFFFFFBEB),
        const Color(0xFFFDE68A),
        const Color(0xFF92400E),
        Icons.warning_amber_rounded,
      ),
      NoticeType.danger => (
        const Color(0xFFFEF2F2),
        const Color(0xFFFECACA),
        const Color(0xFF991B1B),
        Icons.error_outline,
      ),
      NoticeType.info => (
        const Color(0xFFEFF6FF),
        const Color(0xFFBFDBFE),
        const Color(0xFF1E40AF),
        Icons.info_outline,
      ),
      NoticeType.neutral => (
        const Color(0xFFF8FAFC),
        const Color(0xFFE2E8F0),
        const Color(0xFF475569),
        Icons.info_outline,
      ),
    };

    return Container(
      width: double.infinity,
      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
      decoration: BoxDecoration(
        color: bg,
        borderRadius: BorderRadius.circular(8),
        border: Border.all(color: border, width: 1),
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Icon(customIcon ?? icon, size: 16, color: text),
          const SizedBox(width: 10),
          // MANDATORY INVARIANT: Always wrap in Expanded with softWrap: true
          Expanded(
            child: Text(
              message,
              style: TextStyle(
                fontSize: 12.5,
                fontWeight: FontWeight.w400,
                color: text,
                height: 1.4,
              ),
              softWrap: true,
            ),
          ),
          if (onAction != null && actionLabel != null) ...[
            const SizedBox(width: 8),
            GestureDetector(
              onTap: onAction,
              child: Text(
                actionLabel!,
                style: TextStyle(
                  fontSize: 12,
                  fontWeight: FontWeight.w600,
                  color: text,
                  decoration: TextDecoration.underline,
                ),
              ),
            ),
          ],
        ],
      ),
    );
  }
}
```

---

## 2. AnimatedSubmitButton (Morphing Button)

Provides tactile scale bounce on press, morphs smoothly into an inline circular spinner during execution, displays a success checkmark on completion, or triggers a horizontal shake sequence on validation error.

```dart
import 'dart:math';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

enum SubmitState { idle, loading, success, error }

class AnimatedSubmitButton extends StatefulWidget {
  final String label;
  final IconData? icon;
  final SubmitState state;
  final VoidCallback? onPressed;
  final double height;
  final double? width;
  final Color primaryColor;

  const AnimatedSubmitButton({
    super.key,
    required this.label,
    this.icon,
    this.state = SubmitState.idle,
    this.onPressed,
    this.height = 48.0,
    this.width,
    this.primaryColor = const Color(0xFF064E3B),
  });

  @override
  State<AnimatedSubmitButton> createState() => AnimatedSubmitButtonState();
}

class AnimatedSubmitButtonState extends State<AnimatedSubmitButton>
    with TickerProviderStateMixin {
  late final AnimationController _pressController;
  late final AnimationController _shakeController;
  late final Animation<double> _scaleAnimation;
  late final Animation<double> _shakeAnimation;

  @override
  void initState() {
    super.initState();
    _pressController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 80),
    );
    _scaleAnimation = Tween<double>(begin: 1.0, end: 0.98).animate(
      CurvedAnimation(parent: _pressController, curve: Curves.easeInOut),
    );

    _shakeController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 350),
    );
    _shakeAnimation = TweenSequence<double>([
      TweenSequenceItem(tween: Tween(begin: 0.0, end: -8.0), weight: 1),
      TweenSequenceItem(tween: Tween(begin: -8.0, end: 8.0), weight: 2),
      TweenSequenceItem(tween: Tween(begin: 8.0, end: -6.0), weight: 2),
      TweenSequenceItem(tween: Tween(begin: -6.0, end: 4.0), weight: 2),
      TweenSequenceItem(tween: Tween(begin: 4.0, end: 0.0), weight: 1),
    ]).animate(CurvedAnimation(parent: _shakeController, curve: Curves.easeInOut));
  }

  @override
  void didUpdateWidget(covariant AnimatedSubmitButton oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (widget.state == SubmitState.error && oldWidget.state != SubmitState.error) {
      triggerErrorShake();
    }
  }

  void triggerErrorShake() {
    HapticFeedback.vibrate();
    _shakeController.forward(from: 0.0);
  }

  @override
  void dispose() {
    _pressController.dispose();
    _shakeController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final isInteractive = widget.state == SubmitState.idle && widget.onPressed != null;

    return AnimatedBuilder(
      animation: Listenable.merge([_scaleAnimation, _shakeAnimation]),
      builder: (context, child) {
        return Transform.translate(
          offset: Offset(_shakeAnimation.value, 0),
          child: Transform.scale(
            scale: _scaleAnimation.value,
            child: child,
          ),
        );
      },
      child: MouseRegion(
        cursor: isInteractive ? SystemMouseCursors.click : SystemMouseCursors.basic,
        child: GestureDetector(
          onTapDown: isInteractive
              ? (_) => _pressController.forward()
              : null,
          onTapUp: isInteractive
              ? (_) {
                  _pressController.reverse();
                  HapticFeedback.mediumImpact();
                  widget.onPressed!();
                }
              : null,
          onTapCancel: () => _pressController.reverse(),
          child: AnimatedContainer(
            duration: const Duration(milliseconds: 250),
            curve: Curves.easeInOutCubic,
            height: widget.height,
            width: widget.state == SubmitState.loading ? widget.height : (widget.width ?? double.infinity),
            decoration: BoxDecoration(
              color: isInteractive ? widget.primaryColor : const Color(0xFF0F766E).withOpacity(0.85),
              borderRadius: BorderRadius.circular(widget.state == SubmitState.loading ? widget.height / 2 : 8),
              boxShadow: isInteractive
                  ? [
                      BoxShadow(
                        color: widget.primaryColor.withOpacity(0.25),
                        blurRadius: 10,
                        offset: const Offset(0, 3),
                      )
                    ]
                  : null,
            ),
            alignment: Alignment.center,
            child: AnimatedSwitcher(
              duration: const Duration(milliseconds: 200),
              child: switch (widget.state) {
                SubmitState.loading => const SizedBox(
                    width: 20,
                    height: 20,
                    child: CircularProgressIndicator(
                      strokeWidth: 2.2,
                      valueColor: AlwaysStoppedAnimation<Color>(Colors.white),
                    ),
                  ),
                SubmitState.success => const Icon(
                    Icons.check,
                    key: ValueKey('success'),
                    color: Colors.white,
                    size: 22,
                  ),
                _ => Row(
                    key: const ValueKey('idle'),
                    mainAxisSize: MainAxisSize.min,
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      if (widget.icon != null) ...[
                        Icon(widget.icon, size: 18, color: Colors.white),
                        const SizedBox(width: 8),
                      ],
                      Text(
                        widget.label,
                        style: const TextStyle(
                          color: Colors.white,
                          fontSize: 14.5,
                          fontWeight: FontWeight.w600,
                          letterSpacing: 0.1,
                        ),
                      ),
                    ],
                  ),
              },
            ),
          ),
        ),
      ),
    );
  }
}
```

---

## 3. SkeletonShimmerWave (Universal Skeleton Page Loading)

Continuous smooth gradient shimmer replacing jarring spinners across all page loading states.

```dart
import 'package:flutter/material.dart';

class SkeletonShimmerBox extends StatefulWidget {
  final double width;
  final double height;
  final double borderRadius;

  const SkeletonShimmerBox({
    super.key,
    required this.width,
    required this.height,
    this.borderRadius = 8.0,
  });

  @override
  State<SkeletonShimmerBox> createState() => _SkeletonShimmerBoxState();
}

class _SkeletonShimmerBoxState extends State<SkeletonShimmerBox>
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
              colors: const [
                Color(0xFFF1F5F9),
                Color(0xFFE2E8F0),
                Color(0xFFF1F5F9),
              ],
            ),
          ),
        );
      },
    );
  }
}

class ShimmerSkeletonPage extends StatelessWidget {
  const ShimmerSkeletonPage({super.key});

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.all(16.0),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Header shimmer
          const SkeletonShimmerBox(width: 180, height: 26, borderRadius: 6),
          const SizedBox(height: 8),
          const SkeletonShimmerBox(width: 280, height: 14, borderRadius: 4),
          const SizedBox(height: 20),
          // 3-KPI Cards shimmer row
          Row(
            children: [
              Expanded(child: const SkeletonShimmerBox(width: double.infinity, height: 96, borderRadius: 10)),
              const SizedBox(width: 12),
              Expanded(child: const SkeletonShimmerBox(width: double.infinity, height: 96, borderRadius: 10)),
              const SizedBox(width: 12),
              Expanded(child: const SkeletonShimmerBox(width: double.infinity, height: 96, borderRadius: 10)),
            ],
          ),
          const SizedBox(height: 24),
          // Table skeleton
          const SkeletonShimmerBox(width: double.infinity, height: 240, borderRadius: 10),
        ],
      ),
    );
  }
}
```

---

## 4. InteractiveHoverCard (Web Hover & Mobile Tactile Card)

Elevates slightly and highlights hairline borders on desktop web mouse hover, while providing a snappy touch feedback on mobile.

```dart
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

class InteractiveHoverCard extends StatefulWidget {
  final Widget child;
  final VoidCallback? onTap;
  final EdgeInsetsGeometry padding;
  final double borderRadius;
  final Color backgroundColor;

  const InteractiveHoverCard({
    super.key,
    required this.child,
    this.onTap,
    this.padding = const EdgeInsets.all(16.0),
    this.borderRadius = 10.0,
    this.backgroundColor = Colors.white,
  });

  @override
  State<InteractiveHoverCard> createState() => _InteractiveHoverCardState();
}

class _InteractiveHoverCardState extends State<InteractiveHoverCard> {
  bool _isHovered = false;
  bool _isPressed = false;

  @override
  Widget build(BuildContext context) {
    final border = _isHovered
        ? const Color(0xFF0F766E).withOpacity(0.4)
        : const Color(0xFFE2E8F0);

    final shadow = _isHovered
        ? [
            BoxShadow(
              color: const Color(0x0F0F172A),
              blurRadius: 12,
              offset: const Offset(0, 4),
            )
          ]
        : [
            BoxShadow(
              color: const Color(0x060F172A),
              blurRadius: 4,
              offset: const Offset(0, 1),
            )
          ];

    return MouseRegion(
      cursor: widget.onTap != null ? SystemMouseCursors.click : SystemMouseCursors.basic,
      onEnter: (_) => setState(() => _isHovered = true),
      onExit: (_) => setState(() => _isHovered = false),
      child: GestureDetector(
        onTapDown: widget.onTap != null ? (_) => setState(() => _isPressed = true) : null,
        onTapUp: widget.onTap != null
            ? (_) {
                setState(() => _isPressed = false);
                HapticFeedback.lightImpact();
                widget.onTap!();
              }
            : null,
        onTapCancel: () => setState(() => _isPressed = false),
        child: AnimatedScale(
          scale: _isPressed ? 0.985 : 1.0,
          duration: const Duration(milliseconds: 100),
          curve: Curves.easeOutCubic,
          child: AnimatedContainer(
            duration: const Duration(milliseconds: 180),
            curve: Curves.easeOutCubic,
            padding: widget.padding,
            decoration: BoxDecoration(
              color: widget.backgroundColor,
              borderRadius: BorderRadius.circular(widget.borderRadius),
              border: Border.all(color: border, width: 1.0),
              boxShadow: shadow,
            ),
            child: widget.child,
          ),
        ),
      ),
    );
  }
}
```

---

## 5. StatusPillBadge

Institutional banking status badge with a circular indicator dot and semantic styling.

```dart
import 'package:flutter/material.dart';

class StatusPillBadge extends StatelessWidget {
  final String label;
  final Color background;
  final Color text;
  final Color? dotColor;
  final IconData? icon;

  const StatusPillBadge({
    super.key,
    required this.label,
    required this.background,
    required this.text,
    this.dotColor,
    this.icon,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8.5, vertical: 3.5),
      decoration: BoxDecoration(
        color: background,
        borderRadius: BorderRadius.circular(999),
        border: Border.all(color: text.withOpacity(0.2), width: 0.8),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          if (icon != null) ...[
            Icon(icon, size: 12, color: text),
            const SizedBox(width: 4),
          ] else if (dotColor != null) ...[
            Container(
              width: 6,
              height: 6,
              decoration: BoxDecoration(
                color: dotColor,
                shape: BoxShape.circle,
              ),
            ),
            const SizedBox(width: 5),
          ],
          Text(
            label,
            style: TextStyle(
              fontSize: 11.5,
              fontWeight: FontWeight.w600,
              color: text,
              height: 1.2,
            ),
          ),
        ],
      ),
    );
  }
}
```
