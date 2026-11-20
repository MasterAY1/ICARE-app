import 'package:animations/animations.dart';
import 'package:flutter/cupertino.dart' show CupertinoPageTransitionsBuilder;
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:frontend_flutter/core/theme/icare_motion.dart';
import 'package:frontend_flutter/core/theme/icare_theme.dart';
import 'package:frontend_flutter/core/theme/icare_theme_tokens.dart';
import 'package:frontend_flutter/core/widgets/icare_card.dart';
import 'package:frontend_flutter/core/widgets/icare_skeleton_loader.dart';
import 'package:motor/motor.dart';
import 'package:smooth_sheets/smooth_sheets.dart';

void main() {
  testWidgets('IcareFluidMotion respects MediaQuery.disableAnimations', (tester) async {
    late bool normalReduced;
    late bool disabledReduced;
    late Duration normalDuration;
    late Duration disabledDuration;
    late Motion normalMotion;
    late Motion disabledMotion;

    await tester.pumpWidget(
      MaterialApp(
        theme: IcareTheme.lightTheme,
        home: const Column(
          children: [],
        ),
        builder: (context, _) => Column(
          children: [
            Builder(
              builder: (context) {
                normalReduced = IcareFluidMotion.isReduced(context);
                normalDuration = IcareFluidMotion.resolveDuration(
                  context,
                  IcareFluidMotion.tabDuration,
                );
                normalMotion = IcareFluidMotion.resolve(
                  context,
                  IcareFluidMotion.snappySpring,
                );
                return const SizedBox.shrink();
              },
            ),
            MediaQuery(
              data: const MediaQueryData(disableAnimations: true),
              child: Builder(
                builder: (context) {
                  disabledReduced = IcareFluidMotion.isReduced(context);
                  disabledDuration = IcareFluidMotion.resolveDuration(
                    context,
                    IcareFluidMotion.tabDuration,
                  );
                  disabledMotion = IcareFluidMotion.resolve(
                    context,
                    IcareFluidMotion.snappySpring,
                  );
                  return const SizedBox.shrink();
                },
              ),
            ),
          ],
        ),
      ),
    );

    expect(normalReduced, isFalse);
    expect(normalDuration, IcareFluidMotion.tabDuration);
    expect(normalMotion, isNot(const Motion.none()));

    expect(disabledReduced, isTrue);
    expect(disabledDuration, Duration.zero);
    expect(disabledMotion, const Motion.none());
  });

  testWidgets('IcareCard triggers onTap with IcareTactileScale', (tester) async {
    var tapped = false;
    await tester.pumpWidget(
      MaterialApp(
        theme: IcareTheme.lightTheme,
        home: Scaffold(
          body: IcareCard(
            onTap: () => tapped = true,
            child: const Text('Branch Vault'),
          ),
        ),
      ),
    );

    expect(find.byType(IcareTactileScale), findsOneWidget);
    await tester.tap(find.text('Branch Vault'));
    await tester.pumpAndSettle();
    expect(tapped, isTrue);
  });

  testWidgets('IcareSkeletonLoader renders cleanly inside Row without unbounded errors', (tester) async {
    await tester.pumpWidget(
      MaterialApp(
        theme: IcareTheme.darkTheme,
        home: const Scaffold(
          body: Column(
            children: [
              Row(
                children: [
                  IcareSkeletonLoader(height: 36),
                  SizedBox(width: 8),
                  Expanded(child: IcareSkeletonLoader(height: 36)),
                ],
              ),
              SizedBox(height: 12),
              IcareSkeletonWrapper(
                enabled: true,
                child: Text('Loading metric'),
              ),
            ],
          ),
        ),
      ),
    );

    await tester.pump(const Duration(milliseconds: 100));
    expect(tester.takeException(), isNull);
    expect(find.byType(IcareSkeletonLoader), findsNWidgets(2));
  });

  testWidgets('IcareTheme configures FadeThroughPageTransitionsBuilder on Android/Desktop', (tester) async {
    final light = IcareTheme.buildTheme(
      brightness: Brightness.light,
      accent: IcareAccentPreset.emerald,
    );
    expect(
      light.pageTransitionsTheme.builders[TargetPlatform.android],
      isA<FadeThroughPageTransitionsBuilder>(),
    );
    expect(
      light.pageTransitionsTheme.builders[TargetPlatform.windows],
      isA<FadeThroughPageTransitionsBuilder>(),
    );
    expect(
      light.pageTransitionsTheme.builders[TargetPlatform.iOS],
      isA<CupertinoPageTransitionsBuilder>(),
    );
  });

  testWidgets('showIcareAdaptiveSheet uses smooth_sheets Sheet on mobile and Dialog on desktop', (tester) async {
    // Mobile viewport (375x812)
    tester.view.physicalSize = const Size(375, 812);
    tester.view.devicePixelRatio = 1.0;
    addTearDown(tester.view.resetPhysicalSize);

    await tester.pumpWidget(
      MaterialApp(
        theme: IcareTheme.lightTheme,
        home: Builder(
          builder: (context) => Scaffold(
            body: ElevatedButton(
              onPressed: () {
                showIcareAdaptiveSheet<void>(
                  context: context,
                  builder: (_, isDialog) => Container(
                    color: Colors.white,
                    child: Center(child: Text(isDialog ? 'Desktop' : 'Mobile')),
                  ),
                );
              },
              child: const Text('Open'),
            ),
          ),
        ),
      ),
    );

    await tester.tap(find.text('Open'));
    await tester.pumpAndSettle();
    expect(find.byType(Sheet), findsOneWidget);
    expect(find.text('Mobile'), findsOneWidget);

    Navigator.of(tester.element(find.text('Mobile'))).pop();
    await tester.pumpAndSettle();

    // Desktop viewport (1280x800)
    tester.view.physicalSize = const Size(1280, 800);
    await tester.pumpWidget(
      MaterialApp(
        theme: IcareTheme.lightTheme,
        home: Builder(
          builder: (context) => Scaffold(
            body: ElevatedButton(
              onPressed: () {
                showIcareAdaptiveSheet<void>(
                  context: context,
                  builder: (_, isDialog) => Container(
                    color: Colors.white,
                    child: Center(child: Text(isDialog ? 'Desktop' : 'Mobile')),
                  ),
                );
              },
              child: const Text('Open'),
            ),
          ),
        ),
      ),
    );

    await tester.tap(find.text('Open'));
    await tester.pumpAndSettle();
    expect(find.byType(Dialog), findsOneWidget);
    expect(find.text('Desktop'), findsOneWidget);
  });

  testWidgets('showIcareDialog returns resolved value with FadeScale transition', (tester) async {
    bool? dialogResult;
    await tester.pumpWidget(
      MaterialApp(
        theme: IcareTheme.lightTheme,
        home: Builder(
          builder: (context) => Scaffold(
            body: ElevatedButton(
              onPressed: () async {
                dialogResult = await showIcareDialog<bool>(
                  context: context,
                  barrierDismissible: false,
                  builder: (ctx) => AlertDialog(
                    title: const Text('Confirm'),
                    actions: [
                      TextButton(
                        onPressed: () => Navigator.of(ctx).pop(true),
                        child: const Text('Proceed'),
                      ),
                    ],
                  ),
                );
              },
              child: const Text('Trigger'),
            ),
          ),
        ),
      ),
    );

    await tester.tap(find.text('Trigger'));
    await tester.pumpAndSettle();
    expect(find.byType(FadeScaleTransition), findsOneWidget);
    await tester.tap(find.text('Proceed'));
    await tester.pumpAndSettle();
    expect(dialogResult, isTrue);
  });

  testWidgets('showIcareModalSheet renders Sheet and returns selection', (tester) async {
    String? chosen;
    await tester.pumpWidget(
      MaterialApp(
        theme: IcareTheme.lightTheme,
        home: Builder(
          builder: (context) => Scaffold(
            body: ElevatedButton(
              onPressed: () async {
                chosen = await showIcareModalSheet<String>(
                  context: context,
                  builder: (ctx) => SafeArea(
                    child: Padding(
                      padding: const EdgeInsets.all(16),
                      child: ListTile(
                        title: const Text('Gallery Option'),
                        onTap: () => Navigator.of(ctx).pop('gallery'),
                      ),
                    ),
                  ),
                );
              },
              child: const Text('Pick'),
            ),
          ),
        ),
      ),
    );

    await tester.tap(find.text('Pick'));
    await tester.pumpAndSettle();
    expect(find.byType(Sheet), findsOneWidget);
    await tester.tap(find.text('Gallery Option'));
    await tester.pumpAndSettle();
    expect(chosen, 'gallery');
  });
}
