import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../app/theme.dart';
import '../services/app_lock_provider.dart';
import '../services/profile_provider.dart';
import 'app_lock_screen.dart';
import 'main_scaffold.dart';
import 'profile_setup_screen.dart';
import 'welcome_screen.dart';

/// Decides between local profile setup and the dashboard.
///
/// There is no account or sign-in step. Users can create a local profile or
/// choose to explore the public parts of the app without one.
class AppGate extends StatelessWidget {
  const AppGate({super.key});

  @override
  Widget build(BuildContext context) {
    final profileProvider = context.watch<ProfileProvider>();
    final appLock = context.watch<AppLockProvider>();

    if (profileProvider.loading || !appLock.initialized) {
      return const _GateLoading();
    }

    if (appLock.locked) {
      return const AppLockScreen();
    }

    if (profileProvider.needsSetup) {
      if (profileProvider.hasProfile) return const ProfileSetupScreen();
      return const WelcomeScreen();
    }

    return const MainScaffold();
  }
}

class _GateLoading extends StatelessWidget {
  const _GateLoading();

  @override
  Widget build(BuildContext context) {
    return const Scaffold(
      backgroundColor: AppColors.mintBackground,
      body: Center(
        child: SizedBox(
          width: 28,
          height: 28,
          child: CircularProgressIndicator(strokeWidth: 2.6),
        ),
      ),
    );
  }
}
