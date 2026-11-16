import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../app/theme.dart';
import '../l10n/app_localizations.dart';
import '../services/profile_provider.dart';
import '../widgets/app_widgets.dart';
import 'profile_setup_screen.dart';

/// First-run experience. It explains what HealthMate is, makes the local-only
/// storage model explicit, and gives users a real choice between creating a
/// profile and browsing public information.
class WelcomeScreen extends StatefulWidget {
  const WelcomeScreen({super.key});

  @override
  State<WelcomeScreen> createState() => _WelcomeScreenState();
}

class _WelcomeScreenState extends State<WelcomeScreen> {
  final PageController _controller = PageController();
  int _page = 0;
  bool _leaving = false;

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  Future<void> _continue() async {
    if (_page < 2) {
      await _controller.nextPage(
        duration: AppMotion.gentle,
        curve: Curves.easeOutCubic,
      );
      return;
    }
    await _openSetup();
  }

  Future<void> _openSetup() async {
    if (_leaving) return;
    setState(() => _leaving = true);
    await Navigator.of(context).push(
      MaterialPageRoute(
        builder: (_) => const ProfileSetupScreen(popOnSave: true),
      ),
    );
    if (mounted) setState(() => _leaving = false);
  }

  Future<void> _skip() async {
    await context.read<ProfileProvider>().skipSetup();
  }

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    final size = MediaQuery.sizeOf(context);
    final compact = size.height < 720;

    return Scaffold(
      body: SafeArea(
        child: Center(
          child: ConstrainedBox(
            constraints: const BoxConstraints(maxWidth: 560),
            child: Column(
              children: [
                Padding(
                  padding: const EdgeInsets.fromLTRB(22, 14, 12, 4),
                  child: Row(
                    children: [
                      const AppLogo(size: 38, showWordmark: true),
                      const Spacer(),
                      TextButton(
                        onPressed: _skip,
                        child: Text(l10n.t('skip')),
                      ),
                    ],
                  ),
                ),
                Expanded(
                  child: PageView(
                    controller: _controller,
                    onPageChanged: (value) => setState(() => _page = value),
                    children: [
                      _OnboardingPage(
                        eyebrow: l10n.t('onboarding_eyebrow_one'),
                        title: l10n.t('onboarding_title_one'),
                        body: l10n.t('onboarding_body_one'),
                        accent: AppColors.teal,
                        visual: _HeroVisual(compact: compact),
                      ),
                      _OnboardingPage(
                        eyebrow: l10n.t('onboarding_eyebrow_two'),
                        title: l10n.t('onboarding_title_two'),
                        body: l10n.t('onboarding_body_two'),
                        accent: AppColors.info,
                        visual: const _PlanVisual(),
                      ),
                      _OnboardingPage(
                        eyebrow: l10n.t('onboarding_eyebrow_three'),
                        title: l10n.t('onboarding_title_three'),
                        body: l10n.t('onboarding_body_three'),
                        accent: AppColors.warning,
                        visual: _CareVisual(compact: compact),
                      ),
                    ],
                  ),
                ),
                Padding(
                  padding: const EdgeInsets.fromLTRB(22, 8, 22, 18),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.stretch,
                    children: [
                      Row(
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: [
                          for (var index = 0; index < 3; index++)
                            AnimatedContainer(
                              duration: AppMotion.base,
                              margin: const EdgeInsets.symmetric(horizontal: 3.5),
                              height: 6,
                              width: index == _page ? 22 : 6,
                              decoration: BoxDecoration(
                                color: index == _page
                                    ? AppColors.teal
                                    : AppColors.borderStrong,
                                borderRadius: BorderRadius.circular(999),
                              ),
                            ),
                        ],
                      ),
                      const SizedBox(height: 18),
                      FilledButton(
                        onPressed: _leaving ? null : _continue,
                        child: _leaving
                            ? const SizedBox(
                                width: 20,
                                height: 20,
                                child: CircularProgressIndicator(
                                  strokeWidth: 2,
                                  color: Colors.white,
                                ),
                              )
                            : Text(
                                _page == 2
                                    ? l10n.t('create_local_profile')
                                    : l10n.t('continue_label'),
                              ),
                      ),
                      const SizedBox(height: 4),
                      TextButton(
                        onPressed: _skip,
                        child: Text(l10n.t('explore_without_profile')),
                      ),
                      const SizedBox(height: 4),
                      Row(
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: [
                          const Icon(
                            Icons.lock_outline_rounded,
                            size: 13,
                            color: AppColors.muted,
                          ),
                          const SizedBox(width: 5),
                          Flexible(
                            child: Text(
                              l10n.t('onboarding_privacy_note'),
                              textAlign: TextAlign.center,
                              style: Theme.of(context)
                                  .textTheme
                                  .bodySmall
                                  ?.copyWith(fontSize: 11.5),
                            ),
                          ),
                        ],
                      ),
                    ],
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

class _OnboardingPage extends StatelessWidget {
  final String eyebrow;
  final String title;
  final String body;
  final Color accent;
  final Widget visual;

  const _OnboardingPage({
    required this.eyebrow,
    required this.title,
    required this.body,
    required this.accent,
    required this.visual,
  });

  @override
  Widget build(BuildContext context) {
    return SingleChildScrollView(
      padding: const EdgeInsets.fromLTRB(22, 12, 22, 8),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          visual,
          const SizedBox(height: 26),
          AppEyebrow(eyebrow, color: accent),
          const SizedBox(height: 9),
          Text(
            title,
            style: Theme.of(context).textTheme.headlineMedium?.copyWith(
                  fontSize: 32,
                  height: 1.14,
                  letterSpacing: -0.9,
                ),
          ),
          const SizedBox(height: 12),
          Text(
            body,
            style: Theme.of(context).textTheme.bodyLarge?.copyWith(
                  color: AppColors.slate,
                  height: 1.6,
                ),
          ),
        ],
      ),
    );
  }
}

class _HeroVisual extends StatelessWidget {
  final bool compact;

  const _HeroVisual({this.compact = false});

  @override
  Widget build(BuildContext context) {
    final height = compact ? 218.0 : 258.0;
    return Container(
      height: height,
      decoration: BoxDecoration(
        gradient: AppColors.softGradient,
        borderRadius: BorderRadius.circular(30),
        border: Border.all(color: AppColors.border),
      ),
      child: Stack(
        children: [
          Positioned(
            top: -42,
            right: -26,
            child: _Circle(size: 150, color: AppColors.teal.withValues(alpha: 0.07)),
          ),
          Positioned(
            bottom: -36,
            left: -24,
            child: _Circle(size: 120, color: AppColors.teal.withValues(alpha: 0.06)),
          ),
          Center(
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                AppMark(size: compact ? 74 : 86, withShadow: true),
                const SizedBox(height: 14),
                Text(
                  'HealthMate',
                  style: Theme.of(context).textTheme.titleLarge?.copyWith(
                        fontWeight: FontWeight.w800,
                        fontSize: 20,
                        letterSpacing: -0.5,
                      ),
                ),
                const SizedBox(height: 2),
                Text(
                  'Calm, local, personal care',
                  style: Theme.of(context)
                      .textTheme
                      .bodySmall
                      ?.copyWith(color: AppColors.tealDark),
                ),
              ],
            ),
          ),
          const Positioned(
            top: 26,
            left: 18,
            child: _FloatingChip(
              icon: Icons.calendar_month_outlined,
              label: 'Visits',
            ),
          ),
          const Positioned(
            top: 48,
            right: 14,
            child: _FloatingChip(
              icon: Icons.health_and_safety_outlined,
              label: 'Records',
            ),
          ),
          const Positioned(
            bottom: 24,
            left: 24,
            child: _FloatingChip(
              icon: Icons.near_me_outlined,
              label: 'Nearby care',
            ),
          ),
        ],
      ),
    );
  }
}

class _PlanVisual extends StatelessWidget {
  const _PlanVisual();

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        gradient: const LinearGradient(
          colors: [Color(0xFFF3F7FD), Color(0xFFE8F0FB)],
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
        ),
        borderRadius: BorderRadius.circular(30),
        border: Border.all(color: const Color(0xFFD8E5F5)),
      ),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Row(
            children: [
              const AppIconBadge(
                icon: Icons.event_note_outlined,
                color: AppColors.info,
                background: Colors.white,
                size: 42,
              ),
              const SizedBox(width: 10),
              const Expanded(
                child: Text(
                  'Plan your visits',
                  style: TextStyle(
                    fontWeight: FontWeight.w800,
                    fontSize: 16,
                    color: AppColors.navy,
                  ),
                ),
              ),
              AppStatusChip(
                label: 'Private',
                color: AppColors.info,
                background: Colors.white,
                icon: Icons.lock_outline_rounded,
              ),
            ],
          ),
          const SizedBox(height: 14),
          const _PlanPoint(
            icon: Icons.edit_calendar_outlined,
            title: 'Add a visit you arranged',
            subtitle: 'Doctor, clinic, date, time and notes',
          ),
          const SizedBox(height: 9),
          const _PlanPoint(
            icon: Icons.schedule_rounded,
            title: 'See what is next',
            subtitle: 'A reminder on Home while the app is open',
          ),
          const SizedBox(height: 14),
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 13, vertical: 11),
            decoration: BoxDecoration(
              color: Colors.white.withValues(alpha: 0.72),
              borderRadius: BorderRadius.circular(AppRadii.md),
            ),
            child: const Row(
              children: [
                Icon(Icons.info_outline_rounded, size: 16, color: AppColors.info),
                SizedBox(width: 8),
                Expanded(
                  child: Text(
                    'HealthMate never invents a slot or confirms a hospital booking.',
                    style: TextStyle(fontSize: 11.5, color: AppColors.slate, height: 1.4),
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

class _CareVisual extends StatelessWidget {
  final bool compact;

  const _CareVisual({this.compact = false});

  @override
  Widget build(BuildContext context) {
    return Container(
      height: compact ? 218 : 258,
      decoration: BoxDecoration(
        gradient: const LinearGradient(
          colors: [Color(0xFFFDF7ED), Color(0xFFF8EEDC)],
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
        ),
        borderRadius: BorderRadius.circular(30),
        border: Border.all(color: const Color(0xFFF0DFC3)),
      ),
      child: Stack(
        children: [
          Positioned(
            top: 34,
            left: 26,
            right: 26,
            bottom: 24,
            child: CustomPaint(painter: _RoutePainter()),
          ),
          const Positioned(
            top: 32,
            left: 24,
            child: _MapPin(icon: Icons.local_hospital_outlined, label: 'Hospital'),
          ),
          const Positioned(
            top: 72,
            right: 20,
            child: _MapPin(icon: Icons.local_pharmacy_outlined, label: 'Pharmacy'),
          ),
          const Positioned(
            bottom: 58,
            left: 20,
            child: _MapPin(icon: Icons.medical_services_outlined, label: 'Clinic'),
          ),
          Positioned(
            left: 20,
            right: 20,
            bottom: 16,
            child: Container(
              padding: const EdgeInsets.symmetric(horizontal: 13, vertical: 10),
              decoration: BoxDecoration(
                color: Colors.white.withValues(alpha: 0.88),
                borderRadius: BorderRadius.circular(AppRadii.md),
              ),
              child: const Row(
                children: [
                  Icon(Icons.public_rounded, size: 16, color: AppColors.warning),
                  SizedBox(width: 8),
                  Expanded(
                    child: Text(
                      'Real OpenStreetMap results. No fabricated ratings.',
                      style: TextStyle(
                        fontSize: 11.5,
                        color: AppColors.slate,
                        height: 1.4,
                      ),
                    ),
                  ),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class _Circle extends StatelessWidget {
  final double size;
  final Color color;

  const _Circle({required this.size, required this.color});

  @override
  Widget build(BuildContext context) {
    return Container(
      width: size,
      height: size,
      decoration: BoxDecoration(color: color, shape: BoxShape.circle),
    );
  }
}

class _FloatingChip extends StatelessWidget {
  final IconData icon;
  final String label;

  const _FloatingChip({required this.icon, required this.label});

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 7),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(999),
        boxShadow: AppShadows.card,
        border: Border.all(color: AppColors.border),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(icon, size: 14, color: AppColors.tealDark),
          const SizedBox(width: 5),
          Text(
            label,
            style: const TextStyle(
              fontSize: 11,
              fontWeight: FontWeight.w600,
              color: AppColors.navy,
            ),
          ),
        ],
      ),
    );
  }
}

class _PlanPoint extends StatelessWidget {
  final IconData icon;
  final String title;
  final String subtitle;

  const _PlanPoint({
    required this.icon,
    required this.title,
    required this.subtitle,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(AppRadii.md),
      ),
      child: Row(
        children: [
          Container(
            width: 38,
            height: 38,
            decoration: BoxDecoration(
              color: AppColors.infoSoft,
              borderRadius: BorderRadius.circular(11),
            ),
            child: Icon(icon, size: 19, color: AppColors.info),
          ),
          const SizedBox(width: 11),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  title,
                  style: const TextStyle(
                    fontWeight: FontWeight.w700,
                    fontSize: 13,
                    color: AppColors.navy,
                  ),
                ),
                const SizedBox(height: 2),
                Text(
                  subtitle,
                  style: const TextStyle(fontSize: 10.5, color: AppColors.slate),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

class _MapPin extends StatelessWidget {
  final IconData icon;
  final String label;

  const _MapPin({required this.icon, required this.label});

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 7),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(12),
        boxShadow: AppShadows.card,
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(icon, size: 15, color: AppColors.warning),
          const SizedBox(width: 5),
          Text(
            label,
            style: const TextStyle(
              fontSize: 10.5,
              fontWeight: FontWeight.w600,
              color: AppColors.navy,
            ),
          ),
        ],
      ),
    );
  }
}

class _RoutePainter extends CustomPainter {
  @override
  void paint(Canvas canvas, Size size) {
    final paint = Paint()
      ..color = AppColors.warning.withValues(alpha: 0.22)
      ..style = PaintingStyle.stroke
      ..strokeWidth = 2.5
      ..strokeCap = StrokeCap.round;
    final path = Path()
      ..moveTo(8, size.height * 0.20)
      ..cubicTo(
        size.width * 0.32,
        size.height * 0.05,
        size.width * 0.66,
        size.height * 0.60,
        size.width * 0.84,
        size.height * 0.28,
      )
      ..cubicTo(
        size.width * 0.96,
        size.height * 0.10,
        size.width * 0.55,
        size.height * 0.92,
        size.width * 0.24,
        size.height * 0.74,
      );
    canvas.drawPath(path, paint);
  }

  @override
  bool shouldRepaint(covariant CustomPainter oldDelegate) => false;
}
