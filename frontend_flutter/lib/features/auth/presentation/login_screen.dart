import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../../core/auth/auth_controller.dart';
import '../../../core/auth/auth_state.dart';
import '../../shared/presentation/co_app_scaffold.dart';

/// Screen 0: 1:1 Direct Translation of Streamlit auth/login.py and app.py L598-950
class LoginScreen extends ConsumerStatefulWidget {
  const LoginScreen({super.key});

  @override
  ConsumerState<LoginScreen> createState() => _LoginScreenState();
}

class _LoginScreenState extends ConsumerState<LoginScreen> {
  final TextEditingController _usernameController = TextEditingController();
  final TextEditingController _passwordController = TextEditingController();
  bool _obscurePassword = true;

  @override
  void dispose() {
    _usernameController.dispose();
    _passwordController.dispose();
    super.dispose();
  }

  void _handleLogin() async {
    final username = _usernameController.text.trim();
    final password = _passwordController.text.trim();

    if (username.isEmpty || password.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Please enter both username and password'),
          backgroundColor: Color(0xFFDC2626),
        ),
      );
      return;
    }

    await ref.read(authControllerProvider.notifier).login(
          username: username,
          password: password,
        );

    if (!mounted) return;
    final currentAuth = ref.read(authControllerProvider);
    if (currentAuth is AuthStateAuthenticated && ModalRoute.of(context)?.isCurrent == true) {
      Navigator.of(context).pushReplacement(
        MaterialPageRoute(builder: (_) => const CoAppScaffold()),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    ref.listen<AuthState>(authControllerProvider, (previous, next) {
      if (next is AuthStateAuthenticated && ModalRoute.of(context)?.isCurrent == true) {
        Navigator.of(context).pushReplacement(
          MaterialPageRoute(builder: (_) => const CoAppScaffold()),
        );
      }
    });

    final authState = ref.watch(authControllerProvider);
    final isLoading = authState is AuthStateLoading;
    final isWide = MediaQuery.of(context).size.width > 900;

    return Scaffold(
      body: Stack(
        children: [
          // 1. Gradient Background (app.py L601)
          Container(
            decoration: const BoxDecoration(
              gradient: LinearGradient(
                begin: Alignment.topLeft,
                end: Alignment.bottomRight,
                colors: [
                  Color(0xFF0A1628),
                  Color(0xFF0F2744),
                  Color(0xFF163B5C),
                  Color(0xFF1B4F72),
                  Color(0xFF0F2744),
                ],
              ),
            ),
          ),

          // 2. Glowing Radial Orbs (app.py L605-624)
          Positioned(
            top: -100,
            left: -100,
            child: Container(
              width: 500,
              height: 500,
              decoration: BoxDecoration(
                shape: BoxShape.circle,
                color: const Color(0xFF8CC63F).withOpacity(0.12),
              ),
            ),
          ),
          Positioned(
            bottom: -100,
            right: -100,
            child: Container(
              width: 500,
              height: 500,
              decoration: BoxDecoration(
                shape: BoxShape.circle,
                color: const Color(0xFF2E86C1).withOpacity(0.15),
              ),
            ),
          ),

          // 3. Floating Particles (app.py L637-662)
          Positioned.fill(
            child: IgnorePointer(
              child: Stack(
                children: [
                  _buildParticle(left: 0.10, top: 0.20, size: 3, color: const Color(0xFF8CC63F).withOpacity(0.30)),
                  _buildParticle(left: 0.25, top: 0.70, size: 2, color: const Color(0xFF8CC63F).withOpacity(0.25)),
                  _buildParticle(left: 0.45, top: 0.35, size: 3, color: const Color(0xFF2E86C1).withOpacity(0.25)),
                  _buildParticle(left: 0.65, top: 0.80, size: 4, color: const Color(0xFF8CC63F).withOpacity(0.20)),
                  _buildParticle(left: 0.80, top: 0.15, size: 3, color: const Color(0xFF2E86C1).withOpacity(0.20)),
                  _buildParticle(left: 0.55, top: 0.60, size: 2, color: const Color(0xFF8CC63F).withOpacity(0.25)),
                ],
              ),
            ),
          ),

          // 4. Split Layout (auth/login.py L31-101)
          Center(
            child: SingleChildScrollView(
              padding: EdgeInsets.symmetric(horizontal: isWide ? 24 : 16, vertical: isWide ? 32 : 20),
              child: ConstrainedBox(
                constraints: const BoxConstraints(maxWidth: 1100),
                child: isWide
                    ? Row(
                        crossAxisAlignment: CrossAxisAlignment.center,
                        children: [
                          Expanded(flex: 12, child: _buildLeftInfoPanel()),
                          const SizedBox(width: 48),
                          Expanded(flex: 9, child: _buildRightLoginForm(isLoading, authState)),
                        ],
                      )
                    : Column(
                        children: [
                          _buildRightLoginForm(isLoading, authState),
                          const SizedBox(height: 32),
                          _buildLeftInfoPanel(),
                        ],
                      ),
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildParticle({required double left, required double top, required double size, required Color color}) {
    return Align(
      alignment: FractionalOffset(left, top),
      child: Container(
        width: size,
        height: size,
        decoration: BoxDecoration(
          color: color,
          shape: BoxShape.circle,
        ),
      ),
    );
  }

  /// Left Info Panel (auth/login.py L34-66)
  Widget _buildLeftInfoPanel() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        // Pill Badge (L36)
        Container(
          padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 5),
          decoration: BoxDecoration(
            color: const Color(0xFF8CC63F).withOpacity(0.12),
            borderRadius: BorderRadius.circular(20),
            border: Border.all(color: const Color(0xFF8CC63F).withOpacity(0.20)),
          ),
          child: const Text(
            'Est. 2006 — South-West Nigeria',
            style: TextStyle(
              color: Color(0xFF8CC63F),
              fontSize: 10.5,
              fontWeight: FontWeight.w700,
              letterSpacing: 1.0,
            ),
          ),
        ),
        const SizedBox(height: 20),

        // Headline (L37)
        RichText(
          text: const TextSpan(
            style: TextStyle(
              fontSize: 32,
              fontWeight: FontWeight.w800,
              color: Colors.white,
              letterSpacing: -0.5,
              height: 1.25,
            ),
            children: [
              TextSpan(text: 'Empowering Communities,\n'),
              TextSpan(
                text: 'Growing Together',
                style: TextStyle(
                  color: Color(0xFF8CC63F),
                ),
              ),
            ],
          ),
        ),
        const SizedBox(height: 8),

        // Slogan (L38)
        const Text(
          '"Building a better community through inspiration, motivation and empowerment"',
          style: TextStyle(
            color: Color(0xFF8CC63F),
            fontSize: 13.5,
            fontWeight: FontWeight.w600,
            fontStyle: FontStyle.italic,
            letterSpacing: 0.3,
          ),
        ),
        const SizedBox(height: 18),

        // Description Paragraph (L39-45)
        const Text(
          'ICARE (Initiative for Community Advancement, Relief and Empowerment), founded by Mrs. Alayo L.S., is a Non-Governmental Organization dedicated to the intellectual and socio-economic growth of its members. Operating across South-Western Nigeria, ICARE runs micro-credit programmes for traders and artisans, asset acquisition schemes, agric-enterprise ventures, and skill acquisition programmes for the youths.',
          style: TextStyle(
            color: Color(0x8CFFFFFF),
            fontSize: 12.5,
            height: 1.8,
          ),
        ),
        const SizedBox(height: 20),

        // Divider (L46)
        Container(
          width: 40,
          height: 2,
          decoration: BoxDecoration(
            gradient: const LinearGradient(
              colors: [Color(0xFF8CC63F), Colors.transparent],
            ),
            borderRadius: BorderRadius.circular(2),
          ),
        ),
        const SizedBox(height: 16),

        // Our Vision (L47-51)
        const Text(
          'OUR VISION',
          style: TextStyle(
            color: Color(0x59FFFFFF),
            fontSize: 10,
            fontWeight: FontWeight.w700,
            letterSpacing: 1.5,
          ),
        ),
        const SizedBox(height: 4),
        const Text(
          'To be among the foremost catalysts in initiating and implementing sustainable programmes focused on empowering people for growth and self-reliance.',
          style: TextStyle(
            color: Color(0xA6FFFFFF),
            fontSize: 12,
            height: 1.7,
          ),
        ),
        const SizedBox(height: 16),

        // Core Values (L52-60)
        const Text(
          'CORE VALUES',
          style: TextStyle(
            color: Color(0x59FFFFFF),
            fontSize: 10,
            fontWeight: FontWeight.w700,
            letterSpacing: 1.5,
          ),
        ),
        const SizedBox(height: 6),
        Wrap(
          spacing: 6,
          runSpacing: 6,
          children: const [
            _ValuePill('Integrity'),
            _ValuePill('Commitment'),
            _ValuePill('Competence'),
            _ValuePill('Teamwork'),
          ],
        ),
        const SizedBox(height: 24),

        // Address (L61-64)
        Container(
          padding: const EdgeInsets.only(top: 16),
          decoration: const BoxDecoration(
            border: Border(top: BorderSide(color: Color(0x0FFFFFFF))),
          ),
          child: Row(
            children: const [
              Icon(Icons.location_on, size: 12, color: Color(0x59FFFFFF)),
              SizedBox(width: 4),
              Expanded(
                child: Text(
                  'H.Q: 7 Ibifiele Street, Aiyegbami, Sagamu, Ogun State, Nigeria',
                  style: TextStyle(color: Color(0x59FFFFFF), fontSize: 11, height: 1.6),
                ),
              ),
            ],
          ),
        ),
      ],
    );
  }

  /// Right Form Card (auth/login.py L68-101)
  Widget _buildRightLoginForm(bool isLoading, AuthState authState) {
    return Container(
      constraints: const BoxConstraints(maxWidth: 420),
      decoration: BoxDecoration(
        color: Colors.white.withOpacity(0.06),
        borderRadius: BorderRadius.circular(24),
        border: Border.all(color: Colors.white.withOpacity(0.10)),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.30),
            blurRadius: 32,
            offset: const Offset(0, 8),
          ),
        ],
      ),
      padding: const EdgeInsets.symmetric(horizontal: 36, vertical: 40),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.center,
        children: [
          // Logo (L71-73)
          Container(
            width: 72,
            height: 72,
            decoration: BoxDecoration(
              shape: BoxShape.circle,
              color: const Color(0xFF0F2744),
              border: Border.all(color: Colors.white.withOpacity(0.15), width: 3),
              boxShadow: [
                BoxShadow(
                  color: const Color(0xFF8CC63F).withOpacity(0.30),
                  blurRadius: 20,
                ),
              ],
            ),
            child: ClipOval(
              child: Image.asset(
                'assets/icare_logo.png',
                width: 72,
                height: 72,
                fit: BoxFit.contain,
                errorBuilder: (context, error, stackTrace) => const Center(
                  child: Text(
                    'IC',
                    style: TextStyle(
                      color: Color(0xFF8CC63F),
                      fontSize: 26,
                      fontWeight: FontWeight.w900,
                    ),
                  ),
                ),
              ),
            ),
          ),
          const SizedBox(height: 10),

          // Brand Name (L74)
          const Text(
            'ICARE',
            style: TextStyle(
              fontSize: 24,
              fontWeight: FontWeight.w800,
              color: Colors.white,
              letterSpacing: 6.0,
            ),
          ),
          const SizedBox(height: 4),

          // Org Name (L75)
          const Text(
            'Initiative for Community Advancement,\nRelief and Empowerment',
            textAlign: TextAlign.center,
            style: TextStyle(
              fontSize: 10.5,
              color: Color(0x73FFFFFF),
              height: 1.6,
              letterSpacing: 0.3,
            ),
          ),
          const SizedBox(height: 16),

          // Accent Line (L76)
          Container(
            width: 44,
            height: 3,
            decoration: BoxDecoration(
              gradient: const LinearGradient(
                colors: [Color(0xFF8CC63F), Color(0xFF2E86C1)],
              ),
              borderRadius: BorderRadius.circular(4),
            ),
          ),
          const SizedBox(height: 16),

          // Title (L77-78)
          const Text(
            'Welcome Back',
            style: TextStyle(
              fontSize: 16,
              fontWeight: FontWeight.w700,
              color: Colors.white,
            ),
          ),
          const SizedBox(height: 2),
          const Text(
            'ICARE — Growing Together',
            style: TextStyle(
              fontSize: 11.5,
              color: Color(0x66FFFFFF),
            ),
          ),
          const SizedBox(height: 22),

          // Username Field (L81)
          Align(
            alignment: Alignment.centerLeft,
            child: const Text(
              'Username',
              style: TextStyle(
                color: Color(0xD9FFFFFF),
                fontSize: 12.5,
                fontWeight: FontWeight.w500,
              ),
            ),
          ),
          const SizedBox(height: 6),
          TextField(
            controller: _usernameController,
            style: const TextStyle(color: Color(0xFF1A1D23), fontWeight: FontWeight.w500, fontSize: 14),
            decoration: InputDecoration(
              filled: true,
              fillColor: Colors.white,
              hintText: 'Enter your username',
              hintStyle: const TextStyle(color: Color(0xFF9CA3AF), fontSize: 13),
              contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
              border: OutlineInputBorder(
                borderRadius: BorderRadius.circular(12),
                borderSide: const BorderSide(color: Color(0xFFD1D5DB)),
              ),
              enabledBorder: OutlineInputBorder(
                borderRadius: BorderRadius.circular(12),
                borderSide: const BorderSide(color: Color(0xFFD1D5DB)),
              ),
              focusedBorder: OutlineInputBorder(
                borderRadius: BorderRadius.circular(12),
                borderSide: const BorderSide(color: Color(0xFF2E86C1), width: 2),
              ),
            ),
          ),
          const SizedBox(height: 14),

          // Password Field (L82)
          Align(
            alignment: Alignment.centerLeft,
            child: const Text(
              'Password',
              style: TextStyle(
                color: Color(0xD9FFFFFF),
                fontSize: 12.5,
                fontWeight: FontWeight.w500,
              ),
            ),
          ),
          const SizedBox(height: 6),
          TextField(
            controller: _passwordController,
            obscureText: _obscurePassword,
            style: const TextStyle(color: Color(0xFF1A1D23), fontWeight: FontWeight.w500, fontSize: 14),
            decoration: InputDecoration(
              filled: true,
              fillColor: Colors.white,
              hintText: 'Enter your password',
              hintStyle: const TextStyle(color: Color(0xFF9CA3AF), fontSize: 13),
              contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
              suffixIcon: IconButton(
                icon: Icon(
                  _obscurePassword ? Icons.visibility_outlined : Icons.visibility_off_outlined,
                  color: const Color(0xFF6B7280),
                  size: 18,
                ),
                onPressed: () => setState(() => _obscurePassword = !_obscurePassword),
              ),
              border: OutlineInputBorder(
                borderRadius: BorderRadius.circular(12),
                borderSide: const BorderSide(color: Color(0xFFD1D5DB)),
              ),
              enabledBorder: OutlineInputBorder(
                borderRadius: BorderRadius.circular(12),
                borderSide: const BorderSide(color: Color(0xFFD1D5DB)),
              ),
              focusedBorder: OutlineInputBorder(
                borderRadius: BorderRadius.circular(12),
                borderSide: const BorderSide(color: Color(0xFF2E86C1), width: 2),
              ),
            ),
          ),
          const SizedBox(height: 20),

          // Error Notification (L91)
          if (authState is AuthStateError) ...[
            Container(
              padding: const EdgeInsets.all(10),
              margin: const EdgeInsets.only(bottom: 14),
              decoration: BoxDecoration(
                color: Colors.red.shade900.withOpacity(0.5),
                borderRadius: BorderRadius.circular(8),
                border: Border.all(color: Colors.redAccent.withOpacity(0.5)),
              ),
              child: Row(
                children: [
                  const Icon(Icons.error_outline, color: Colors.white, size: 16),
                  const SizedBox(width: 8),
                  Expanded(
                    child: Text(
                      authState.message,
                      style: const TextStyle(color: Colors.white, fontSize: 11.5),
                    ),
                  ),
                ],
              ),
            ),
          ],

          // SIGN IN Button (L84)
          SizedBox(
            width: double.infinity,
            height: 48,
            child: ElevatedButton(
              style: ElevatedButton.styleFrom(
                backgroundColor: const Color(0xFF8CC63F),
                foregroundColor: Colors.white,
                elevation: 4,
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(12),
                ),
              ),
              onPressed: isLoading ? null : _handleLogin,
              child: isLoading
                  ? const SizedBox(
                      width: 20,
                      height: 20,
                      child: CircularProgressIndicator(color: Colors.white, strokeWidth: 2),
                    )
                  : const Text(
                      'SIGN IN',
                      style: TextStyle(
                        fontWeight: FontWeight.w700,
                        fontSize: 14,
                        letterSpacing: 1.5,
                      ),
                    ),
            ),
          ),
          const SizedBox(height: 20),

          // Footer Bar (L94-100)
          Container(
            padding: const EdgeInsets.only(top: 14),
            decoration: const BoxDecoration(
              border: Border(top: BorderSide(color: Color(0x14FFFFFF))),
            ),
            child: Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: const [
                Text(
                  'Core Banking System v2.4.0',
                  style: TextStyle(color: Color(0x4DFFFFFF), fontSize: 10, letterSpacing: 0.5),
                ),
                Row(
                  children: [
                    Icon(Icons.lock, size: 10, color: Color(0xFF8CC63F)),
                    SizedBox(width: 4),
                    Text(
                      '256-bit Secured Connection',
                      style: TextStyle(color: Color(0x4DFFFFFF), fontSize: 10),
                    ),
                  ],
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

class _ValuePill extends StatelessWidget {
  final String label;
  const _ValuePill(this.label);

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 4),
      decoration: BoxDecoration(
        color: Colors.white.withOpacity(0.06),
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: Colors.white.withOpacity(0.08)),
      ),
      child: Text(
        label,
        style: const TextStyle(
          color: Color(0x99FFFFFF),
          fontSize: 11,
          fontWeight: FontWeight.w600,
        ),
      ),
    );
  }
}
