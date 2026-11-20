import 'package:animations/animations.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:motor/motor.dart';
import 'package:smooth_sheets/smooth_sheets.dart';

/// Physics-based spring tokens, tactile wrappers, and adaptive sheet/dialog helpers for ICARE.
/// Complements [IcareMotion] in `icare_theme_tokens.dart` and honors reduced motion settings.
class IcareFluidMotion {
  IcareFluidMotion._();

  static const Duration microDuration = Duration(milliseconds: 140);
  static const Duration tabDuration = Duration(milliseconds: 220);
  static const Duration routeDuration = Duration(milliseconds: 280);
  static const Duration sheetDuration = Duration(milliseconds: 300);

  static const Curve standardCurve = Curves.easeOutCubic;
  static const Curve emphasizedCurve = Curves.fastOutSlowIn;

  static const Motion snappySpring = Motion.snappySpring(
    duration: Duration(milliseconds: 240),
  );

  static const Motion smoothSpring = Motion.smoothSpring(
    duration: Duration(milliseconds: 280),
  );

  static const Motion tactilePress = Motion.interactiveSpring(
    duration: Duration(milliseconds: 180),
  );

  static bool isReduced(BuildContext context) {
    return MediaQuery.disableAnimationsOf(context);
  }

  static Motion resolve(BuildContext context, Motion normal) {
    return isReduced(context) ? const Motion.none() : normal;
  }

  static Duration resolveDuration(BuildContext context, Duration normal) {
    return isReduced(context) ? Duration.zero : normal;
  }

  static void selectionHaptic(bool enabled) {
    if (enabled) {
      HapticFeedback.selectionClick();
    }
  }

  static void lightImpactHaptic(bool enabled) {
    if (enabled) {
      HapticFeedback.lightImpact();
    }
  }
}

/// Subtle interruptible spring compression for tappable cards and controls.
/// Uses Listener so it never competes with scrolling or InkWell tap recognizers.
class IcareTactileScale extends StatefulWidget {
  final Widget child;
  final bool enabled;
  final double pressedScale;

  const IcareTactileScale({
    super.key,
    required this.child,
    this.enabled = true,
    this.pressedScale = 0.985,
  });

  @override
  State<IcareTactileScale> createState() => _IcareTactileScaleState();
}

class _IcareTactileScaleState extends State<IcareTactileScale> {
  bool _pressed = false;

  void _setPressed(bool next) {
    if (_pressed == next || !mounted) return;
    setState(() => _pressed = next);
  }

  @override
  Widget build(BuildContext context) {
    if (!widget.enabled || IcareFluidMotion.isReduced(context)) {
      return widget.child;
    }

    return Listener(
      behavior: HitTestBehavior.translucent,
      onPointerDown: (_) => _setPressed(true),
      onPointerUp: (_) => _setPressed(false),
      onPointerCancel: (_) => _setPressed(false),
      child: SingleMotionBuilder(
        value: _pressed ? widget.pressedScale : 1.0,
        motion: IcareFluidMotion.tactilePress,
        builder: (context, scale, child) {
          return Transform.scale(
            scale: scale,
            alignment: Alignment.center,
            child: child,
          );
        },
        child: widget.child,
      ),
    );
  }
}

/// Displays a Material Motion FadeScale modal dialog honoring reduced motion settings.
Future<T?> showIcareDialog<T>({
  required BuildContext context,
  required WidgetBuilder builder,
  bool barrierDismissible = true,
  Color barrierColor = Colors.black54,
  String barrierLabel = 'Dismiss',
  bool useSafeArea = true,
  bool useRootNavigator = true,
  RouteSettings? routeSettings,
}) {
  final modalDuration = IcareFluidMotion.resolveDuration(
    context,
    IcareFluidMotion.tabDuration,
  );
  final reverseDuration = IcareFluidMotion.resolveDuration(
    context,
    IcareFluidMotion.microDuration,
  );

  return showModal<T>(
    context: context,
    useRootNavigator: useRootNavigator,
    routeSettings: routeSettings,
    configuration: FadeScaleTransitionConfiguration(
      barrierColor: barrierColor,
      barrierDismissible: barrierDismissible,
      barrierLabel: barrierLabel,
      transitionDuration: modalDuration,
      reverseTransitionDuration: reverseDuration,
    ),
    builder: useSafeArea ? (ctx) => SafeArea(child: builder(ctx)) : builder,
  );
}

/// Displays a smooth physics-based swipe-dismissible bottom sheet backed by smooth_sheets.
Future<T?> showIcareModalSheet<T>({
  required BuildContext context,
  required WidgetBuilder builder,
  Color? backgroundColor,
  BorderRadiusGeometry borderRadius = const BorderRadius.vertical(
    top: Radius.circular(18),
  ),
  bool swipeDismissible = true,
  bool barrierDismissible = true,
  bool useScrollSync = true,
}) {
  final sheetDuration = IcareFluidMotion.resolveDuration(
    context,
    IcareFluidMotion.sheetDuration,
  );

  return Navigator.of(context).push<T>(
    ModalSheetRoute<T>(
      swipeDismissible: swipeDismissible,
      barrierDismissible: barrierDismissible,
      transitionDuration: sheetDuration,
      builder: (sheetCtx) => Sheet(
        initialOffset: const SheetOffset(1),
        snapGrid: const SheetSnapGrid.single(snap: SheetOffset(1)),
        physics: const BouncingSheetPhysics(),
        scrollConfiguration: useScrollSync
            ? const SheetScrollConfiguration(
                scrollSyncMode: SheetScrollHandlingBehavior.onlyFromTop,
              )
            : SheetScrollConfiguration.disabled,
        decoration: MaterialSheetDecoration(
          size: SheetSize.fit,
          color: backgroundColor ?? Colors.transparent,
          borderRadius: borderRadius,
          clipBehavior: Clip.antiAlias,
        ),
        child: builder(sheetCtx),
      ),
    ),
  );
}

/// Presents an adaptive modal overlay:
/// - Compact screens (< [mobileBreakpoint]): smooth physics-based swipe-dismissible bottom sheet
/// - Wide screens (>= [mobileBreakpoint]): Material Motion FadeScale dialog
Future<T?> showIcareAdaptiveSheet<T>({
  required BuildContext context,
  required Widget Function(BuildContext dialogContext, bool isDialog) builder,
  double mobileBreakpoint = 768,
  double mobileHeightFactor = 0.88,
  double peekHeightFactor = 0.56,
  bool enablePeekSnap = true,
  bool fitContent = false,
  BoxConstraints desktopConstraints = const BoxConstraints(
    maxWidth: 680,
    maxHeight: 720,
  ),
  EdgeInsets desktopInsetPadding = const EdgeInsets.symmetric(
    horizontal: 40,
    vertical: 24,
  ),
}) {
  final width = MediaQuery.sizeOf(context).width;
  final isMobile = width < mobileBreakpoint;

  if (isMobile) {
    final sheetDuration = IcareFluidMotion.resolveDuration(
      context,
      IcareFluidMotion.sheetDuration,
    );
    final snapGrid = fitContent
        ? const SheetSnapGrid.single(snap: SheetOffset(1))
        : SheetSnapGrid(
            snaps: [
              if (enablePeekSnap && peekHeightFactor < mobileHeightFactor)
                SheetOffset.proportionalToViewport(peekHeightFactor),
              SheetOffset.proportionalToViewport(mobileHeightFactor),
            ],
          );

    return Navigator.of(context).push<T>(
      ModalSheetRoute<T>(
        swipeDismissible: true,
        barrierDismissible: true,
        transitionDuration: sheetDuration,
        builder: (sheetCtx) => Sheet(
          initialOffset: fitContent
              ? const SheetOffset(1)
              : SheetOffset.proportionalToViewport(mobileHeightFactor),
          snapGrid: snapGrid,
          physics: const BouncingSheetPhysics(),
          scrollConfiguration: const SheetScrollConfiguration(
            scrollSyncMode: SheetScrollHandlingBehavior.onlyFromTop,
          ),
          decoration: MaterialSheetDecoration(
            size: fitContent ? SheetSize.fit : SheetSize.stretch,
            color: Colors.transparent,
            borderRadius: const BorderRadius.vertical(top: Radius.circular(18)),
            clipBehavior: Clip.antiAlias,
          ),
          child: builder(sheetCtx, false),
        ),
      ),
    );
  }

  return showIcareDialog<T>(
    context: context,
    useSafeArea: false,
    builder: (dialogCtx) => Dialog(
      backgroundColor: Colors.transparent,
      elevation: 0,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
      insetPadding: desktopInsetPadding,
      child: ConstrainedBox(
        constraints: desktopConstraints,
        child: ClipRRect(
          borderRadius: BorderRadius.circular(14),
          child: builder(dialogCtx, true),
        ),
      ),
    ),
  );
}
