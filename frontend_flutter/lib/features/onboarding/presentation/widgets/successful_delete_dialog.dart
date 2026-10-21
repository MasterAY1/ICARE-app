import 'package:flutter/material.dart';

/// Modal dialog with smooth entry animations confirming successful deletion of an onboarding package.
class SuccessfulDeleteAnimationDialog extends StatefulWidget {
  final String branchName;
  final String branchCode;

  const SuccessfulDeleteAnimationDialog({
    super.key,
    required this.branchName,
    required this.branchCode,
  });

  /// Helper method to display the dialog over the active navigator context
  static Future<void> show(
    BuildContext context, {
    required String branchName,
    required String branchCode,
  }) {
    return showDialog<void>(
      context: context,
      barrierDismissible: true,
      builder: (_) => SuccessfulDeleteAnimationDialog(
        branchName: branchName,
        branchCode: branchCode,
      ),
    );
  }

  @override
  State<SuccessfulDeleteAnimationDialog> createState() => _SuccessfulDeleteAnimationDialogState();
}

class _SuccessfulDeleteAnimationDialogState extends State<SuccessfulDeleteAnimationDialog>
    with SingleTickerProviderStateMixin {
  late AnimationController _controller;
  late Animation<double> _scaleAnimation;
  late Animation<double> _checkScaleAnimation;
  late Animation<double> _fadeAnimation;
  late Animation<Offset> _slideAnimation;

  @override
  void initState() {
    super.initState();
    _controller = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 750),
    );

    _scaleAnimation = Tween<double>(begin: 0.0, end: 1.0).animate(
      CurvedAnimation(
        parent: _controller,
        curve: const Interval(0.0, 0.65, curve: Curves.elasticOut),
      ),
    );

    _checkScaleAnimation = Tween<double>(begin: 0.0, end: 1.0).animate(
      CurvedAnimation(
        parent: _controller,
        curve: const Interval(0.25, 0.75, curve: Curves.easeOutBack),
      ),
    );

    _fadeAnimation = Tween<double>(begin: 0.0, end: 1.0).animate(
      CurvedAnimation(
        parent: _controller,
        curve: const Interval(0.35, 0.9, curve: Curves.easeIn),
      ),
    );

    _slideAnimation = Tween<Offset>(begin: const Offset(0, 0.15), end: Offset.zero).animate(
      CurvedAnimation(
        parent: _controller,
        curve: const Interval(0.35, 0.9, curve: Curves.easeOutCubic),
      ),
    );

    _controller.forward();

    // Auto-dismiss smoothly after 2.2 seconds
    Future.delayed(const Duration(milliseconds: 2200), () {
      if (mounted) {
        Navigator.of(context, rootNavigator: true).pop();
      }
    });
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Dialog(
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
      elevation: 10,
      backgroundColor: Colors.white,
      child: Container(
        constraints: const BoxConstraints(maxWidth: 420),
        padding: const EdgeInsets.symmetric(horizontal: 26, vertical: 30),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            // Animated Icon with Pulse Outer Circle
            ScaleTransition(
              scale: _scaleAnimation,
              child: Container(
                width: 78,
                height: 78,
                decoration: BoxDecoration(
                  shape: BoxShape.circle,
                  color: const Color(0xFFFEF2F2),
                  border: Border.all(color: const Color(0xFFFCA5A5), width: 2),
                  boxShadow: const [
                    BoxShadow(
                      color: Color(0x18DC2626),
                      blurRadius: 18,
                      spreadRadius: 4,
                    ),
                  ],
                ),
                child: Center(
                  child: ScaleTransition(
                    scale: _checkScaleAnimation,
                    child: Container(
                      width: 52,
                      height: 52,
                      decoration: const BoxDecoration(
                        shape: BoxShape.circle,
                        color: Color(0xFFDC2626),
                      ),
                      child: const Icon(
                        Icons.delete_sweep_outlined,
                        color: Colors.white,
                        size: 30,
                      ),
                    ),
                  ),
                ),
              ),
            ),
            const SizedBox(height: 20),

            // Animated Text Content
            FadeTransition(
              opacity: _fadeAnimation,
              child: SlideTransition(
                position: _slideAnimation,
                child: Column(
                  children: [
                    const Text(
                      'Session Deleted Successfully',
                      textAlign: TextAlign.center,
                      style: TextStyle(
                        fontSize: 17,
                        fontWeight: FontWeight.w800,
                        color: Color(0xFF0F172A),
                        letterSpacing: -0.2,
                      ),
                    ),
                    const SizedBox(height: 8),
                    RichText(
                      textAlign: TextAlign.center,
                      text: TextSpan(
                        style: const TextStyle(fontSize: 13, color: Color(0xFF64748B), height: 1.45),
                        children: [
                          const TextSpan(text: 'The onboarding package for '),
                          TextSpan(
                            text: '${widget.branchName} (${widget.branchCode})',
                            style: const TextStyle(fontWeight: FontWeight.bold, color: Color(0xFF0F172A)),
                          ),
                          const TextSpan(text: ' and all associated staged records have been permanently removed.'),
                        ],
                      ),
                    ),
                    const SizedBox(height: 22),
                    OutlinedButton(
                      style: OutlinedButton.styleFrom(
                        foregroundColor: const Color(0xFF475569),
                        side: const BorderSide(color: Color(0xFFCBD5E1)),
                        padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 10),
                        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
                      ),
                      onPressed: () => Navigator.of(context, rootNavigator: true).pop(),
                      child: const Text('Dismiss', style: TextStyle(fontSize: 12.5, fontWeight: FontWeight.w600)),
                    ),
                  ],
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}
