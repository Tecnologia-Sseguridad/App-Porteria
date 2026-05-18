import 'package:flutter/material.dart';
import 'dart:math' as math;
import '../services/storage_service.dart';
import '../services/api_service.dart';
import '../widgets/session_expired_dialog.dart';
import 'login_screen.dart';
import 'home_screen.dart';

class SplashScreen extends StatefulWidget {
  const SplashScreen({super.key});

  @override
  State<SplashScreen> createState() => _SplashScreenState();
}

class _SplashScreenState extends State<SplashScreen>
    with TickerProviderStateMixin {
  late AnimationController _logoController;
  late AnimationController _bgController;
  late AnimationController _shimmerController;
  late Animation<double> _fadeAnimation;
  late Animation<double> _scaleAnimation;
  late Animation<double> _slideUpAnimation;

  @override
  void initState() {
    super.initState();
    
    _bgController = AnimationController(
      duration: const Duration(seconds: 8),
      vsync: this,
    )..repeat();

    _shimmerController = AnimationController(
      duration: const Duration(milliseconds: 2000),
      vsync: this,
    )..repeat();

    _logoController = AnimationController(
      duration: const Duration(milliseconds: 1800),
      vsync: this,
    );

    _fadeAnimation = Tween<double>(begin: 0.0, end: 1.0).animate(
      CurvedAnimation(
        parent: _logoController,
        curve: const Interval(0.0, 0.5, curve: Curves.easeOut),
      ),
    );

    _scaleAnimation = Tween<double>(begin: 0.6, end: 1.0).animate(
      CurvedAnimation(
        parent: _logoController,
        curve: const Interval(0.0, 0.6, curve: Curves.elasticOut),
      ),
    );

    _slideUpAnimation = Tween<double>(begin: 30.0, end: 0.0).animate(
      CurvedAnimation(
        parent: _logoController,
        curve: const Interval(0.3, 0.7, curve: Curves.easeOutCubic),
      ),
    );

    _logoController.forward();
    _setupSessionListener();
    _checkUser();
  }

  void _setupSessionListener() {
    final apiService = ApiService();
    apiService.onSessionExpired = () {
      if (mounted) {
        Navigator.pushReplacement(
          context,
          PageRouteBuilder(
            pageBuilder: (context, animation, secondaryAnimation) =>
                const LoginScreen(),
            transitionsBuilder:
                (context, animation, secondaryAnimation, child) {
              return FadeTransition(opacity: animation, child: child);
            },
            transitionDuration: const Duration(milliseconds: 500),
          ),
        );
      }
    };
  }

  Future<void> _checkUser() async {
    await Future.delayed(const Duration(milliseconds: 1500));
    if (!mounted) return;

    final storage = StorageService();
    final user = await storage.getUser();

    final apiService = ApiService();
    await apiService.restoreSession();

    if (!mounted) return;

    if (user != null && apiService.isLoggedIn) {
      final isValid = await apiService.validateSession();

      if (!mounted) return;

      if (isValid) {
        Navigator.pushReplacement(
          context,
          PageRouteBuilder(
            pageBuilder: (context, animation, secondaryAnimation) =>
                HomeScreen(user: user),
            transitionsBuilder:
                (context, animation, secondaryAnimation, child) {
              return FadeTransition(opacity: animation, child: child);
            },
            transitionDuration: const Duration(milliseconds: 500),
          ),
        );
      } else {
        if (!mounted) return;
        showSessionExpiredDialog(
          context,
          onDismiss: () {
            if (mounted) {
              Navigator.pushReplacement(
                context,
                PageRouteBuilder(
                  pageBuilder: (context, animation, secondaryAnimation) =>
                      const LoginScreen(),
                  transitionsBuilder:
                      (context, animation, secondaryAnimation, child) {
                    return FadeTransition(opacity: animation, child: child);
                  },
                  transitionDuration: const Duration(milliseconds: 500),
                ),
              );
            }
          },
        );
      }
    } else {
      Navigator.pushReplacement(
        context,
        PageRouteBuilder(
          pageBuilder: (context, animation, secondaryAnimation) =>
              const LoginScreen(),
          transitionsBuilder:
              (context, animation, secondaryAnimation, child) {
            return FadeTransition(opacity: animation, child: child);
          },
          transitionDuration: const Duration(milliseconds: 500),
        ),
      );
    }
  }

  @override
  void dispose() {
    _logoController.dispose();
    _bgController.dispose();
    _shimmerController.dispose();
    ApiService().onSessionExpired = null;
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: AnimatedBuilder(
        animation: Listenable.merge([_bgController, _logoController, _shimmerController]),
        builder: (context, child) {
          return Container(
            decoration: BoxDecoration(
              gradient: LinearGradient(
                begin: Alignment(
                  math.cos(_bgController.value * 2 * math.pi) * 0.5,
                  math.sin(_bgController.value * 2 * math.pi) * 0.5,
                ),
                end: Alignment(
                  math.cos((_bgController.value + 0.5) * 2 * math.pi) * 0.5,
                  math.sin((_bgController.value + 0.5) * 2 * math.pi) * 0.5,
                ),
                colors: const [
                  Color(0xFF1E293B),
                  Color(0xFF334155),
                  Color(0xFF0F172A),
                  Color(0xFF1E293B),
                ],
                stops: const [0.0, 0.3, 0.7, 1.0],
              ),
            ),
            child: SafeArea(
              child: Center(
                child: Column(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    // Logo with animations
                    Opacity(
                      opacity: _fadeAnimation.value,
                      child: Transform.scale(
                        scale: _scaleAnimation.value,
                        child: Transform.translate(
                          offset: Offset(0, _slideUpAnimation.value),
                          child: Container(
                            padding: const EdgeInsets.all(24),
                            decoration: BoxDecoration(
                              color: Colors.white.withOpacity(0.15),
                              borderRadius: BorderRadius.circular(32),
                              border: Border.all(
                                color: Colors.white.withOpacity(0.2),
                                width: 1,
                              ),
                              boxShadow: [
                                BoxShadow(
                                  color: Colors.black.withOpacity(0.1),
                                  blurRadius: 40,
                                  offset: const Offset(0, 20),
                                ),
                              ],
                            ),
                            child: Image.asset(
                              'assets/sseguridad.png',
                              width: 120,
                              fit: BoxFit.contain,
                            ),
                          ),
                        ),
                      ),
                    ),
                    
                    const SizedBox(height: 40),
                    
                    // Title with fade
                    Opacity(
                      opacity: _fadeAnimation.value,
                      child: Transform.translate(
                        offset: Offset(0, _slideUpAnimation.value),
                        child: Column(
                          children: [
                            const Text(
                              'Escaner Carnets',
                              style: TextStyle(
                                fontSize: 30,
                                fontWeight: FontWeight.w700,
                                color: Colors.white,
                                letterSpacing: 0.5,
                              ),
                            ),
                            const SizedBox(height: 8),
                            Text(
                              'Control de acceso inteligente',
                              style: TextStyle(
                                fontSize: 14,
                                color: Colors.white.withOpacity(0.7),
                                letterSpacing: 1.5,
                                fontWeight: FontWeight.w300,
                              ),
                            ),
                          ],
                        ),
                      ),
                    ),
                    
                    const SizedBox(height: 60),
                    
                    // Loading indicator
                    Opacity(
                      opacity: _fadeAnimation.value,
                      child: SizedBox(
                        width: 32,
                        height: 32,
                        child: CircularProgressIndicator(
                          strokeWidth: 2.5,
                          color: Colors.white.withOpacity(0.6),
                        ),
                      ),
                    ),
                  ],
                ),
              ),
            ),
          );
        },
      ),
    );
  }
}