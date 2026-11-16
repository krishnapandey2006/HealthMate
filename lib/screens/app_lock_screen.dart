import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:provider/provider.dart';

import '../app/theme.dart';
import '../l10n/app_localizations.dart';
import '../services/app_lock_provider.dart';
import '../widgets/app_widgets.dart';

/// Privacy screen shown before local health data when the optional app lock is
/// enabled. It does not encrypt files on disk.
class AppLockScreen extends StatefulWidget {
  const AppLockScreen({super.key});

  @override
  State<AppLockScreen> createState() => _AppLockScreenState();
}

class _AppLockScreenState extends State<AppLockScreen> {
  String _pin = '';
  bool _checking = false;

  void _enterDigit(String digit) {
    if (_pin.length >= 6 || _checking) return;
    HapticFeedback.selectionClick();
    setState(() => _pin += digit);
  }

  void _backspace() {
    if (_pin.isEmpty || _checking) return;
    setState(() => _pin = _pin.substring(0, _pin.length - 1));
  }

  Future<void> _unlock() async {
    if (_pin.length < 4 || _checking) return;
    setState(() => _checking = true);
    final lock = context.read<AppLockProvider>();
    final success = await lock.unlock(_pin);
    if (!mounted) return;
    setState(() {
      _checking = false;
      if (!success) _pin = '';
    });
    if (!success) HapticFeedback.heavyImpact();
  }

  Future<void> _showForgotPin() async {
    await showDialog<void>(
      context: context,
      builder: (dialogContext) => AlertDialog(
        title: const Text('Forgot your PIN?'),
        content: const Text(
          'For privacy, HealthMate cannot recover a forgotten PIN. You can turn off the lock by clearing this app\'s storage on your device; that also erases the local profile, vaccination records and appointments. Hospital appointments you arranged directly are not affected.',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(dialogContext).pop(),
            child: const Text('Close'),
          ),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    final lock = context.watch<AppLockProvider>();
    final size = MediaQuery.sizeOf(context);
    final compact = size.height < 700;

    return Scaffold(
      backgroundColor: AppColors.mintBackground,
      body: SafeArea(
        child: Center(
          child: ConstrainedBox(
            constraints: const BoxConstraints(maxWidth: 430),
            child: SingleChildScrollView(
              padding: const EdgeInsets.fromLTRB(28, 24, 28, 24),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  Align(
                    alignment: Alignment.centerLeft,
                    child: AppLogo(size: 44, showWordmark: true),
                  ),
                  SizedBox(height: compact ? 28 : 48),
                  Center(
                    child: Container(
                      width: 72,
                      height: 72,
                      decoration: BoxDecoration(
                        color: AppColors.tealSoft,
                        borderRadius: BorderRadius.circular(24),
                      ),
                      child: const Icon(
                        Icons.lock_outline_rounded,
                        color: AppColors.tealDark,
                        size: 32,
                      ),
                    ),
                  ),
                  const SizedBox(height: 22),
                  Text(
                    l10n.t('welcome_back'),
                    textAlign: TextAlign.center,
                    style: Theme.of(context).textTheme.headlineSmall?.copyWith(
                          fontSize: 26,
                          fontWeight: FontWeight.w800,
                        ),
                  ),
                  const SizedBox(height: 8),
                  Text(
                    l10n.t('app_lock_enter_body'),
                    textAlign: TextAlign.center,
                    style: Theme.of(context).textTheme.bodyMedium,
                  ),
                  const SizedBox(height: 26),
                  Row(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      for (var index = 0; index < 6; index++)
                        AnimatedContainer(
                          duration: AppMotion.fast,
                          margin: const EdgeInsets.symmetric(horizontal: 7),
                          width: 14,
                          height: 14,
                          decoration: BoxDecoration(
                            shape: BoxShape.circle,
                            color: index < _pin.length
                                ? AppColors.teal
                                : Colors.transparent,
                            border: Border.all(
                              color: index < _pin.length
                                  ? AppColors.teal
                                  : AppColors.borderStrong,
                              width: 1.5,
                            ),
                          ),
                        ),
                    ],
                  ),
                  if (lock.error != null) ...[
                    const SizedBox(height: 14),
                    Text(
                      lock.error!,
                      textAlign: TextAlign.center,
                      style: const TextStyle(
                        color: AppColors.danger,
                        fontSize: 13,
                        height: 1.4,
                      ),
                    ),
                  ],
                  SizedBox(height: compact ? 20 : 30),
                  _PinPad(
                    onDigit: _enterDigit,
                    onBackspace: _backspace,
                    canBackspace: _pin.isNotEmpty && !_checking,
                  ),
                  const SizedBox(height: 20),
                  FilledButton(
                    onPressed: _pin.length >= 4 && !_checking ? _unlock : null,
                    child: _checking
                        ? const SizedBox(
                            width: 20,
                            height: 20,
                            child: CircularProgressIndicator(
                              strokeWidth: 2,
                              color: Colors.white,
                            ),
                          )
                        : Text(l10n.t('unlock')),
                  ),
                  const SizedBox(height: 8),
                  TextButton(
                    onPressed: _showForgotPin,
                    child: Text(l10n.t('forgot_pin')),
                  ),
                  const SizedBox(height: 6),
                  Text(
                    l10n.t('app_lock_privacy_note'),
                    textAlign: TextAlign.center,
                    style: Theme.of(context)
                        .textTheme
                        .bodySmall
                        ?.copyWith(fontSize: 11.5),
                  ),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }
}

class _PinPad extends StatelessWidget {
  final ValueChanged<String> onDigit;
  final VoidCallback onBackspace;
  final bool canBackspace;

  const _PinPad({
    required this.onDigit,
    required this.onBackspace,
    required this.canBackspace,
  });

  @override
  Widget build(BuildContext context) {
    Widget key(String value) {
      return Expanded(
        child: Padding(
          padding: const EdgeInsets.all(5),
          child: Material(
            color: Colors.white,
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(18),
              side: const BorderSide(color: AppColors.border),
            ),
            child: InkWell(
              borderRadius: BorderRadius.circular(18),
              onTap: () => onDigit(value),
              child: SizedBox(
                height: 58,
                child: Center(
                  child: Text(
                    value,
                    style: const TextStyle(
                      fontSize: 22,
                      fontWeight: FontWeight.w600,
                      color: AppColors.navy,
                    ),
                  ),
                ),
              ),
            ),
          ),
        ),
      );
    }

    return Column(
      children: [
        for (final row in const [
          ['1', '2', '3'],
          ['4', '5', '6'],
          ['7', '8', '9'],
        ])
          Row(children: [for (final value in row) key(value)]),
        Row(
          children: [
            const Expanded(child: SizedBox()),
            key('0'),
            Expanded(
              child: Padding(
                padding: const EdgeInsets.all(5),
                child: SizedBox(
                  height: 58,
                  child: IconButton(
                    onPressed: canBackspace ? onBackspace : null,
                    icon: const Icon(Icons.backspace_outlined),
                    tooltip: 'Delete last digit',
                  ),
                ),
              ),
            ),
          ],
        ),
      ],
    );
  }
}
