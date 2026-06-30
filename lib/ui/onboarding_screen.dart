import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:quick_pdf/constants/preference_keys.dart';
import 'package:quick_pdf/router/app_routes.dart';

class OnboardingScreen extends StatefulWidget {
  const OnboardingScreen({super.key});

  @override
  State<OnboardingScreen> createState() => _OnboardingScreenState();
}

class _OnboardingScreenState extends State<OnboardingScreen> {
  final PageController _pageController = PageController();
  int _currentPage = 0;
  static const int _pageCount = 4;

  @override
  void dispose() {
    _pageController.dispose();
    super.dispose();
  }

  Future<void> _finish() async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setBool(kPrefHasSeenOnboarding, true);
    if (!mounted) return;
    context.go(AppRoutes.home);
  }

  @override
  Widget build(BuildContext context) {
    final isLast = _currentPage == _pageCount - 1;

    return Scaffold(
      body: Container(
        decoration: const BoxDecoration(
          gradient: LinearGradient(
            begin: Alignment.topCenter,
            end: Alignment.bottomCenter,
            colors: [
              Color(0xFF1A237E), // navy primary
              Color(0xFF283593),
            ],
          ),
        ),
        child: SafeArea(
          child: Column(
            children: [
              // ── Skip button (every page) ──
              Align(
                alignment: Alignment.topRight,
                child: TextButton(
                  onPressed: _finish,
                  child: const Text(
                    'Skip',
                    style: TextStyle(color: Colors.white70),
                  ),
                ),
              ),

              // ── Pages ──
              Expanded(
                child: PageView(
                  controller: _pageController,
                  onPageChanged: (page) => setState(() => _currentPage = page),
                  children: const [
                    _OnboardingPage(
                      title: 'Privacy First',
                      description:
                          'Your files never leave your device.\nAll processing happens 100% offline.',
                      icon: Icons.privacy_tip,
                    ),
                    _OnboardingPage(
                      title: 'All-in-One Utility',
                      description:
                          'Scan, Merge, Compress, Sign, and more.\nOne app for all your PDF needs.',
                      icon: Icons.widgets,
                    ),
                    _OnboardingPage(
                      title: 'Lightweight & Powerful',
                      description:
                          'Powerful tools, minimal footprint.\nOptimized for performance and speed.',
                      icon: Icons.flash_on,
                    ),
                    _OnboardingPage(
                      title: 'Works 100% Offline',
                      description:
                          'No internet needed for any document task.\nYour documents never leave your device.',
                      icon: Icons.cloud_off_outlined,
                    ),
                  ],
                ),
              ),

              // ── Dot indicators ──
              Row(
                mainAxisAlignment: MainAxisAlignment.center,
                children: List.generate(
                  _pageCount,
                  (i) => AnimatedContainer(
                    duration: const Duration(milliseconds: 300),
                    margin: const EdgeInsets.symmetric(horizontal: 4),
                    width: _currentPage == i ? 14 : 8,
                    height: 8,
                    decoration: BoxDecoration(
                      borderRadius: BorderRadius.circular(4),
                      color: _currentPage == i
                          ? const Color(0xFFFFB300) // amber accent
                          : Colors.white.withValues(alpha: 0.4),
                    ),
                  ),
                ),
              ),
              const SizedBox(height: 24),

              // ── Next / Get Started ──
              Padding(
                padding: const EdgeInsets.symmetric(horizontal: 24),
                child: ElevatedButton(
                  onPressed: isLast
                      ? _finish
                      : () => _pageController.nextPage(
                            duration: const Duration(milliseconds: 350),
                            curve: Curves.easeInOut,
                          ),
                  style: ElevatedButton.styleFrom(
                    backgroundColor: const Color(0xFFFFB300),
                    foregroundColor: Colors.black87,
                    minimumSize: const Size.fromHeight(52),
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(30),
                    ),
                  ),
                  child: Text(
                    isLast ? 'Get Started' : 'Next',
                    style: const TextStyle(
                      fontSize: 16,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                ),
              ),
              const SizedBox(height: 16),
            ],
          ),
        ),
      ),
    );
  }
}

class _OnboardingPage extends StatelessWidget {
  final String title;
  final String description;
  final IconData icon;

  const _OnboardingPage({
    required this.title,
    required this.description,
    required this.icon,
  });

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 40, vertical: 20),
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Container(
            width: 110,
            height: 110,
            decoration: BoxDecoration(
              color: Colors.white.withValues(alpha: 0.12),
              borderRadius: BorderRadius.circular(28),
            ),
            child: Icon(icon, size: 56, color: Colors.white),
          ),
          const SizedBox(height: 28),
          Text(
            title,
            style: const TextStyle(
              fontSize: 26,
              fontWeight: FontWeight.bold,
              color: Colors.white,
            ),
          ),
          const SizedBox(height: 14),
          Text(
            description,
            textAlign: TextAlign.center,
            style: TextStyle(
              fontSize: 15,
              color: Colors.white.withValues(alpha: 0.88),
              height: 1.6,
            ),
          ),
        ],
      ),
    );
  }
}
