import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:shared_preferences/shared_preferences.dart';

import '../../../../core/providers/currency_provider.dart';
import '../../../../core/theme/app_colors.dart';
import '../../../../main.dart';

/// Interactive multi-slide onboarding walkthrough & initial setup screen.
class OnboardingScreen extends ConsumerStatefulWidget {
  final bool isViewingOnly;

  const OnboardingScreen({
    super.key,
    this.isViewingOnly = false,
  });

  @override
  ConsumerState<OnboardingScreen> createState() => _OnboardingScreenState();
}

class _OnboardingScreenState extends ConsumerState<OnboardingScreen> {
  final PageController _pageController = PageController();
  int _currentPage = 0;

  final _nameController = TextEditingController();
  final _emailController = TextEditingController();
  late AppCurrency _selectedCurrency;

  @override
  void initState() {
    super.initState();
    _selectedCurrency = ref.read(currencyProvider);
    _loadExistingProfile();
  }

  Future<void> _loadExistingProfile() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final name = prefs.getString('user_profile_name') ?? '';
      final email = prefs.getString('user_profile_email') ?? '';
      if (mounted && (name.isNotEmpty || email.isNotEmpty)) {
        _nameController.text = name;
        _emailController.text = email;
      }
    } catch (_) {}
  }

  @override
  void dispose() {
    _pageController.dispose();
    _nameController.dispose();
    _emailController.dispose();
    super.dispose();
  }

  void _nextPage() {
    if (_currentPage < 3) {
      _pageController.animateToPage(
        _currentPage + 1,
        duration: const Duration(milliseconds: 350),
        curve: Curves.easeInOutCubic,
      );
    }
  }

  void _skipToSetup() {
    _pageController.animateToPage(
      3,
      duration: const Duration(milliseconds: 400),
      curve: Curves.easeInOutCubic,
    );
  }

  Future<void> _completeOnboarding() async {
    final prefs = await SharedPreferences.getInstance();
    final name = _nameController.text.trim();
    final email = _emailController.text.trim();

    if (name.isNotEmpty) {
      await prefs.setString('user_profile_name', name);
    }
    if (email.isNotEmpty) {
      await prefs.setString('user_profile_email', email);
    }

    // Set active currency
    await ref.read(currencyProvider.notifier).setCurrency(_selectedCurrency);

    // Mark onboarded
    await prefs.setBool('is_onboarded', true);

    if (mounted) {
      if (widget.isViewingOnly) {
        Navigator.of(context).pop();
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Preferences updated successfully!'),
            behavior: SnackBarBehavior.floating,
          ),
        );
      } else {
        Navigator.of(context).pushReplacement(
          MaterialPageRoute(builder: (_) => const MainNavigationShell()),
        );
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final backgroundColor = isDark ? AppColors.darkBg : AppColors.lightBg;

    return Scaffold(
      backgroundColor: backgroundColor,
      body: SafeArea(
        child: Column(
          children: [
            // Top Navigation Bar (Skip / Back / Close)
            _buildTopBar(isDark),

            // Main PageView for Onboarding Slides
            Expanded(
              child: PageView(
                controller: _pageController,
                onPageChanged: (index) {
                  setState(() => _currentPage = index);
                },
                children: [
                  _buildPrivacySlide(isDark),
                  _buildTrackingSlide(isDark),
                  _buildAnalyticsSlide(isDark),
                  _buildSetupSlide(isDark),
                ],
              ),
            ),

            // Bottom Navigation Controls (Page Indicator & Action Buttons)
            _buildBottomBar(isDark),
          ],
        ),
      ),
    );
  }

  Widget _buildTopBar(bool isDark) {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          // Back Button (or Close if viewing only on slide 0)
          if (_currentPage > 0)
            IconButton(
              onPressed: () {
                _pageController.previousPage(
                  duration: const Duration(milliseconds: 300),
                  curve: Curves.easeInOutCubic,
                );
              },
              icon: const Icon(Icons.arrow_back_rounded, size: 22),
              tooltip: 'Back',
            )
          else if (widget.isViewingOnly)
            IconButton(
              onPressed: () => Navigator.of(context).pop(),
              icon: const Icon(Icons.close_rounded, size: 22),
              tooltip: 'Close Tour',
            )
          else
            const SizedBox(width: 48, height: 48),

          // Slide indicator counter
          Text(
            '${_currentPage + 1} of 4',
            style: TextStyle(
              fontSize: 13,
              fontWeight: FontWeight.w600,
              color: isDark ? AppColors.darkTextSecondary : AppColors.lightTextSecondary,
            ),
          ),

          // Skip Button (Only visible on slides 0..2)
          if (_currentPage < 3)
            TextButton(
              onPressed: _skipToSetup,
              style: TextButton.styleFrom(
                foregroundColor: AppColors.primary,
                padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
              ),
              child: const Text(
                'Skip',
                style: TextStyle(fontSize: 14, fontWeight: FontWeight.w700),
              ),
            )
          else
            const SizedBox(width: 48, height: 48),
        ],
      ),
    );
  }

  Widget _buildBottomBar(bool isDark) {
    final isFinalPage = _currentPage == 3;

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 16),
      decoration: BoxDecoration(
        color: isDark ? AppColors.darkBg : AppColors.lightBg,
      ),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          // Animated Pill Page Indicator
          Row(
            children: List.generate(4, (index) {
              final isActive = _currentPage == index;
              return AnimatedContainer(
                duration: const Duration(milliseconds: 300),
                margin: const EdgeInsets.only(right: 6),
                height: 8,
                width: isActive ? 26 : 8,
                decoration: BoxDecoration(
                  color: isActive
                      ? AppColors.primary
                      : (isDark ? Colors.white24 : Colors.black12),
                  borderRadius: BorderRadius.circular(4),
                ),
              );
            }),
          ),

          // Next / Get Started Action Button
          if (!isFinalPage)
            ElevatedButton(
              onPressed: _nextPage,
              style: ElevatedButton.styleFrom(
                backgroundColor: AppColors.primary,
                foregroundColor: Colors.white,
                padding: const EdgeInsets.symmetric(horizontal: 22, vertical: 14),
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(16),
                ),
                elevation: 2,
              ),
              child: const Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Text(
                    'Next',
                    style: TextStyle(fontSize: 15, fontWeight: FontWeight.w700),
                  ),
                  SizedBox(width: 6),
                  Icon(Icons.arrow_forward_rounded, size: 18),
                ],
              ),
            )
          else
            ElevatedButton(
              onPressed: _completeOnboarding,
              style: ElevatedButton.styleFrom(
                backgroundColor: AppColors.primary,
                foregroundColor: Colors.white,
                padding: const EdgeInsets.symmetric(horizontal: 26, vertical: 14),
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(16),
                ),
                elevation: 3,
              ),
              child: Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Text(
                    widget.isViewingOnly ? 'Save & Close' : 'Get Started',
                    style: const TextStyle(fontSize: 15, fontWeight: FontWeight.w700),
                  ),
                  const SizedBox(width: 6),
                  const Icon(Icons.check_rounded, size: 18),
                ],
              ),
            ),
        ],
      ),
    );
  }

  // ─── Slide 1: Offline & Privacy ──────────────────────────────
  Widget _buildPrivacySlide(bool isDark) {
    return _SlideLayout(
      isDark: isDark,
      badgeText: '100% PRIVATE & OFFLINE',
      badgeIcon: Icons.verified_user_rounded,
      badgeColor: AppColors.primary,
      heroWidget: _buildPrivacyHeroCard(isDark),
      title: 'Total Privacy,\nZero Cloud Tracking',
      subtitle:
          'Your financial records belong exclusively to you. Everything is stored locally on your device with biometric-grade security.',
      highlights: const [
        '🔒 Biometric & PIN App Lock Protection',
        '📵 100% Offline • No Sign-ups Required',
        '🛡️ Zero Data Collection, Ads, or Trackers',
        '💾 Safe Local & Encrypted Backup Files',
      ],
    );
  }

  Widget _buildPrivacyHeroCard(bool isDark) {
    return Container(
      width: double.infinity,
      height: 180,
      decoration: BoxDecoration(
        gradient: LinearGradient(
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
          colors: isDark
              ? [
                  AppColors.primary.withValues(alpha: 0.25),
                  const Color(0xFF0F172A),
                ]
              : [
                  AppColors.primary.withValues(alpha: 0.15),
                  Colors.white,
                ],
        ),
        borderRadius: BorderRadius.circular(24),
        border: Border.all(
          color: AppColors.primary.withValues(alpha: isDark ? 0.35 : 0.25),
          width: 1.5,
        ),
      ),
      child: Center(
        child: Stack(
          alignment: Alignment.center,
          children: [
            // Ambient Outer Glow
            Container(
              width: 110,
              height: 110,
              decoration: BoxDecoration(
                shape: BoxShape.circle,
                color: AppColors.primary.withValues(alpha: 0.12),
              ),
            ),
            Container(
              width: 86,
              height: 86,
              decoration: BoxDecoration(
                shape: BoxShape.circle,
                color: AppColors.primary.withValues(alpha: 0.22),
              ),
            ),
            // Center Shield Badge
            Container(
              width: 64,
              height: 64,
              decoration: BoxDecoration(
                color: AppColors.primary,
                shape: BoxShape.circle,
                boxShadow: [
                  BoxShadow(
                    color: AppColors.primary.withValues(alpha: 0.4),
                    blurRadius: 18,
                    offset: const Offset(0, 6),
                  ),
                ],
              ),
              child: const Icon(
                Icons.gpp_good_rounded,
                color: Colors.white,
                size: 34,
              ),
            ),
          ],
        ),
      ),
    );
  }

  // ─── Slide 2: Smart Budgeting & Tracking ─────────────────────
  Widget _buildTrackingSlide(bool isDark) {
    return _SlideLayout(
      isDark: isDark,
      badgeText: 'EFFORTLESS MANAGEMENT',
      badgeIcon: Icons.track_changes_rounded,
      badgeColor: AppColors.secondary,
      heroWidget: _buildTrackingHeroCard(isDark),
      title: 'Smart Tracking\n& Category Budgets',
      subtitle:
          'Effortlessly track daily expenses, set category spending caps, and avoid overspending with real-time budget status alerts.',
      highlights: const [
        '⚡ Quick-Add Multi-Account Transactions',
        '📊 Category Budgets with Smart Warning Alerts',
        '🔄 Auto Recurring Subscriptions & Bill Catch-Up',
        '💳 Multi-Wallet & Cash Accounts Overview',
      ],
    );
  }

  Widget _buildTrackingHeroCard(bool isDark) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        gradient: LinearGradient(
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
          colors: isDark
              ? [
                  AppColors.secondary.withValues(alpha: 0.25),
                  const Color(0xFF0F172A),
                ]
              : [
                  AppColors.secondary.withValues(alpha: 0.15),
                  Colors.white,
                ],
        ),
        borderRadius: BorderRadius.circular(24),
        border: Border.all(
          color: AppColors.secondary.withValues(alpha: isDark ? 0.35 : 0.25),
          width: 1.5,
        ),
      ),
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Row(
                children: [
                  Container(
                    padding: const EdgeInsets.all(8),
                    decoration: BoxDecoration(
                      color: AppColors.secondary.withValues(alpha: 0.2),
                      borderRadius: BorderRadius.circular(10),
                    ),
                    child: const Icon(Icons.restaurant_rounded,
                        color: AppColors.secondary, size: 18),
                  ),
                  const SizedBox(width: 10),
                  Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      const Text(
                        'Dining & Groceries',
                        style: TextStyle(fontSize: 13, fontWeight: FontWeight.w700),
                      ),
                      Text(
                        'Monthly Budget',
                        style: TextStyle(
                          fontSize: 11,
                          color: isDark
                              ? AppColors.darkTextSecondary
                              : AppColors.lightTextSecondary,
                        ),
                      ),
                    ],
                  ),
                ],
              ),
              const Text(
                '68% Spent',
                style: TextStyle(
                  fontSize: 12,
                  fontWeight: FontWeight.w700,
                  color: AppColors.secondary,
                ),
              ),
            ],
          ),
          const SizedBox(height: 12),
          ClipRRect(
            borderRadius: BorderRadius.circular(6),
            child: LinearProgressIndicator(
              value: 0.68,
              minHeight: 8,
              backgroundColor: isDark ? Colors.white12 : Colors.black12,
              valueColor: const AlwaysStoppedAnimation<Color>(AppColors.secondary),
            ),
          ),
          const SizedBox(height: 12),
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              _buildMiniChip(
                icon: Icons.check_circle_outline_rounded,
                label: 'On Track',
                color: AppColors.income,
                isDark: isDark,
              ),
              _buildMiniChip(
                icon: Icons.subscriptions_outlined,
                label: 'Subscriptions Active',
                color: AppColors.secondary,
                isDark: isDark,
              ),
            ],
          ),
        ],
      ),
    );
  }

  // ─── Slide 3: Visual Analytics & Insights ────────────────────
  Widget _buildAnalyticsSlide(bool isDark) {
    return _SlideLayout(
      isDark: isDark,
      badgeText: 'DEEP INSIGHTS & REPORTS',
      badgeIcon: Icons.auto_graph_rounded,
      badgeColor: AppColors.transfer,
      heroWidget: _buildAnalyticsHeroCard(isDark),
      title: 'Insightful Analytics\n& Cash Flow Trends',
      subtitle:
          'Gain complete clarity on where your money flows with visual breakdown charts, financial health checks, and exportable reports.',
      highlights: const [
        '📈 Interactive Cash Flow & Spending Charts',
        '🏷️ Top Spending Categories & Trend Analysis',
        '🏆 Financial Health & Savings Rate Scoring',
        '📄 Instant CSV & Device Report Exports',
      ],
    );
  }

  Widget _buildAnalyticsHeroCard(bool isDark) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        gradient: LinearGradient(
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
          colors: isDark
              ? [
                  AppColors.transfer.withValues(alpha: 0.25),
                  const Color(0xFF0F172A),
                ]
              : [
                  AppColors.transfer.withValues(alpha: 0.15),
                  Colors.white,
                ],
        ),
        borderRadius: BorderRadius.circular(24),
        border: Border.all(
          color: AppColors.transfer.withValues(alpha: isDark ? 0.35 : 0.25),
          width: 1.5,
        ),
      ),
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceAround,
            crossAxisAlignment: CrossAxisAlignment.end,
            children: [
              _buildBar(height: 50, color: AppColors.income, label: 'Income'),
              _buildBar(height: 75, color: AppColors.expense, label: 'Expense'),
              _buildBar(height: 90, color: AppColors.transfer, label: 'Savings'),
              _buildBar(height: 60, color: AppColors.warning, label: 'Invest'),
            ],
          ),
          const SizedBox(height: 12),
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              _buildMiniChip(
                icon: Icons.favorite_rounded,
                label: 'Health Score: 88%',
                color: AppColors.income,
                isDark: isDark,
              ),
              _buildMiniChip(
                icon: Icons.file_download_outlined,
                label: 'CSV & PDF Ready',
                color: AppColors.transfer,
                isDark: isDark,
              ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildBar({
    required double height,
    required Color color,
    required String label,
  }) {
    return Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        Container(
          width: 22,
          height: height,
          decoration: BoxDecoration(
            color: color,
            borderRadius: BorderRadius.circular(6),
            boxShadow: [
              BoxShadow(
                color: color.withValues(alpha: 0.3),
                blurRadius: 6,
                offset: const Offset(0, 2),
              ),
            ],
          ),
        ),
        const SizedBox(height: 6),
        Text(
          label,
          style: const TextStyle(fontSize: 10, fontWeight: FontWeight.w600),
        ),
      ],
    );
  }

  Widget _buildMiniChip({
    required IconData icon,
    required String label,
    required Color color,
    required bool isDark,
  }) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
      decoration: BoxDecoration(
        color: color.withValues(alpha: isDark ? 0.18 : 0.12),
        borderRadius: BorderRadius.circular(8),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(icon, size: 13, color: color),
          const SizedBox(width: 5),
          Text(
            label,
            style: TextStyle(
              fontSize: 11,
              fontWeight: FontWeight.w600,
              color: color,
            ),
          ),
        ],
      ),
    );
  }

  // ─── Slide 4: Profile & Currency Setup ───────────────────────
  Widget _buildSetupSlide(bool isDark) {
    return SingleChildScrollView(
      physics: const BouncingScrollPhysics(),
      padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 12),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.center,
        children: [
          // App Logo
          Container(
            width: 80,
            height: 80,
            decoration: BoxDecoration(
              borderRadius: BorderRadius.circular(22),
              boxShadow: [
                BoxShadow(
                  color: AppColors.primary.withValues(alpha: 0.35),
                  blurRadius: 18,
                  offset: const Offset(0, 6),
                ),
              ],
            ),
            child: ClipRRect(
              borderRadius: BorderRadius.circular(22),
              child: Image.asset(
                'assets/images/app_logo.png',
                fit: BoxFit.cover,
                errorBuilder: (context, error, stackTrace) => Container(
                  color: AppColors.primary,
                  child: const Icon(Icons.account_balance_wallet_rounded,
                      color: Colors.white, size: 38),
                ),
              ),
            ),
          ),

          const SizedBox(height: 16),

          Text(
            'Personalize Your Lumina',
            textAlign: TextAlign.center,
            style: TextStyle(
              fontSize: 22,
              fontWeight: FontWeight.w800,
              color: isDark ? AppColors.darkTextPrimary : AppColors.lightTextPrimary,
              letterSpacing: -0.5,
            ),
          ),

          const SizedBox(height: 6),

          Text(
            'Select your default currency and optional profile info. You can modify these anytime in Settings.',
            textAlign: TextAlign.center,
            style: TextStyle(
              fontSize: 13,
              height: 1.4,
              color: isDark ? AppColors.darkTextSecondary : AppColors.lightTextSecondary,
            ),
          ),

          const SizedBox(height: 20),

          // Setup Form Container
          Container(
            padding: const EdgeInsets.all(18),
            decoration: BoxDecoration(
              color: isDark ? AppColors.darkSurface : AppColors.lightSurface,
              borderRadius: BorderRadius.circular(20),
              border: Border.all(
                color: isDark ? AppColors.darkBorder : AppColors.lightBorder,
              ),
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                // Currency Dropdown
                const Row(
                  children: [
                    Icon(Icons.monetization_on_outlined,
                        size: 18, color: AppColors.primary),
                    SizedBox(width: 6),
                    Text(
                      'Default Currency',
                      style: TextStyle(fontSize: 13, fontWeight: FontWeight.w700),
                    ),
                  ],
                ),
                const SizedBox(height: 8),
                DropdownButtonFormField<AppCurrency>(
                  initialValue: _selectedCurrency,
                  decoration: InputDecoration(
                    border: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(12),
                    ),
                    contentPadding:
                        const EdgeInsets.symmetric(horizontal: 12, vertical: 12),
                  ),
                  isExpanded: true,
                  items: supportedCurrencies.map((currency) {
                    return DropdownMenuItem(
                      value: currency,
                      child: Text(
                        currency.displayName,
                        style: const TextStyle(fontSize: 13),
                        overflow: TextOverflow.ellipsis,
                      ),
                    );
                  }).toList(),
                  onChanged: (val) {
                    if (val != null) {
                      setState(() => _selectedCurrency = val);
                    }
                  },
                ),

                const SizedBox(height: 16),

                // Name Field
                TextField(
                  controller: _nameController,
                  decoration: InputDecoration(
                    labelText: 'Your Name (Optional)',
                    hintText: 'e.g. Alex Smith',
                    prefixIcon:
                        const Icon(Icons.person_outline_rounded, size: 20),
                    border: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(12),
                    ),
                    contentPadding:
                        const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
                  ),
                ),

                const SizedBox(height: 12),

                // Email Field
                TextField(
                  controller: _emailController,
                  keyboardType: TextInputType.emailAddress,
                  decoration: InputDecoration(
                    labelText: 'Email Address (Optional)',
                    hintText: 'e.g. alex@example.com',
                    prefixIcon: const Icon(Icons.mail_outline_rounded, size: 20),
                    border: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(12),
                    ),
                    contentPadding:
                        const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(height: 12),
        ],
      ),
    );
  }
}

/// Generic slide layout helper with responsive scrolling and highlight bullets.
class _SlideLayout extends StatelessWidget {
  final bool isDark;
  final String badgeText;
  final IconData badgeIcon;
  final Color badgeColor;
  final Widget heroWidget;
  final String title;
  final String subtitle;
  final List<String> highlights;

  const _SlideLayout({
    required this.isDark,
    required this.badgeText,
    required this.badgeIcon,
    required this.badgeColor,
    required this.heroWidget,
    required this.title,
    required this.subtitle,
    required this.highlights,
  });

  @override
  Widget build(BuildContext context) {
    return SingleChildScrollView(
      physics: const BouncingScrollPhysics(),
      padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 8),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Hero Illustration Card
          heroWidget,

          const SizedBox(height: 18),

          // Feature Tag Badge
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
            decoration: BoxDecoration(
              color: badgeColor.withValues(alpha: isDark ? 0.2 : 0.12),
              borderRadius: BorderRadius.circular(20),
              border: Border.all(
                color: badgeColor.withValues(alpha: 0.3),
              ),
            ),
            child: Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                Icon(badgeIcon, size: 14, color: badgeColor),
                const SizedBox(width: 6),
                Text(
                  badgeText,
                  style: TextStyle(
                    fontSize: 11,
                    fontWeight: FontWeight.w800,
                    color: badgeColor,
                    letterSpacing: 0.5,
                  ),
                ),
              ],
            ),
          ),

          const SizedBox(height: 10),

          // Headline
          Text(
            title,
            style: TextStyle(
              fontSize: 24,
              fontWeight: FontWeight.w800,
              height: 1.2,
              letterSpacing: -0.5,
              color: isDark ? AppColors.darkTextPrimary : AppColors.lightTextPrimary,
            ),
          ),

          const SizedBox(height: 8),

          // Subtitle
          Text(
            subtitle,
            style: TextStyle(
              fontSize: 13,
              height: 1.45,
              color: isDark ? AppColors.darkTextSecondary : AppColors.lightTextSecondary,
            ),
          ),

          const SizedBox(height: 14),

          // Highlights Chips / Bullets
          Container(
            padding: const EdgeInsets.all(12),
            decoration: BoxDecoration(
              color: isDark ? AppColors.darkSurface : AppColors.lightSurface,
              borderRadius: BorderRadius.circular(16),
              border: Border.all(
                color: isDark ? AppColors.darkBorder : AppColors.lightBorder,
              ),
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: highlights.map((item) {
                return Padding(
                  padding: const EdgeInsets.symmetric(vertical: 3.5),
                  child: Row(
                    children: [
                      Expanded(
                        child: Text(
                          item,
                          style: TextStyle(
                            fontSize: 12.5,
                            fontWeight: FontWeight.w600,
                            color: isDark
                                ? AppColors.darkTextPrimary
                                : AppColors.lightTextPrimary,
                          ),
                        ),
                      ),
                    ],
                  ),
                );
              }).toList(),
            ),
          ),
        ],
      ),
    );
  }
}
