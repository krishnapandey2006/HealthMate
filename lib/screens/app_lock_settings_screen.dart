import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:provider/provider.dart';

import '../app/theme.dart';
import '../l10n/app_localizations.dart';
import '../services/app_lock_provider.dart';
import '../widgets/app_widgets.dart';

/// Optional PIN privacy screen. The PIN gates access to the app's local data,
/// but it does not encrypt the files themselves.
class AppLockSettingsScreen extends StatefulWidget {
  const AppLockSettingsScreen({super.key});

  @override
  State<AppLockSettingsScreen> createState() =>
      _AppLockSettingsScreenState();
}

class _AppLockSettingsScreenState extends State<AppLockSettingsScreen> {
  final _currentController = TextEditingController();
  final _newController = TextEditingController();
  final _confirmController = TextEditingController();
  final _disableController = TextEditingController();

  bool _working = false;
  String? _error;
  String? _disableError;

  @override
  void dispose() {
    _currentController.dispose();
    _newController.dispose();
    _confirmController.dispose();
    _disableController.dispose();
    super.dispose();
  }

  bool _isValidPin(String value) =>
      RegExp(r'^\d{4,6}$').hasMatch(value);

  void _clearFields() {
    _currentController.clear();
    _newController.clear();
    _confirmController.clear();
    _disableController.clear();
  }

  Future<void> _enable(String l10nMessage) async {
    final l10n = AppLocalizations.of(context);
    final pin = _newController.text;
    final confirm = _confirmController.text;
    if (!_isValidPin(pin)) {
      setState(() => _error = l10n.t('pin_length'));
      return;
    }
    if (pin != confirm) {
      setState(() => _error = l10n.t('pin_mismatch'));
      return;
    }
    setState(() {
      _working = true;
      _error = null;
    });
    final saved = await context.read<AppLockProvider>().setPin(pin);
    if (!mounted) return;
    setState(() {
      _working = false;
      if (!saved) {
        _error = context.read<AppLockProvider>().error ??
            l10n.t('auth_generic_error');
      }
    });
    if (saved) {
      _clearFields();
      showAppSnackBar(context, l10nMessage);
    }
  }

  Future<void> _change() async {
    final l10n = AppLocalizations.of(context);
    final current = _currentController.text;
    if (current.isEmpty) {
      setState(() => _error = l10n.t('pin_current_required'));
      return;
    }
    final provider = context.read<AppLockProvider>();
    setState(() {
      _working = true;
      _error = null;
    });
    final correct = await provider.verify(current);
    if (!mounted) return;
    if (!correct) {
      setState(() {
        _working = false;
        _error = l10n.t('pin_wrong');
      });
      return;
    }
    await _enable(l10n.t('pin_changed'));
  }

  Future<void> _disable() async {
    final l10n = AppLocalizations.of(context);
    final current = _disableController.text;
    if (current.isEmpty) {
      setState(() => _disableError = l10n.t('pin_current_required'));
      return;
    }
    setState(() {
      _working = true;
      _disableError = null;
    });
    final disabled =
        await context.read<AppLockProvider>().disable(current);
    if (!mounted) return;
    setState(() {
      _working = false;
      if (!disabled) {
        _disableError =
            context.read<AppLockProvider>().error ?? l10n.t('pin_wrong');
      }
    });
    if (disabled) {
      _clearFields();
      showAppSnackBar(context, l10n.t('pin_removed'));
    }
  }

  void _lockNow() {
    context.read<AppLockProvider>().lockNow();
    Navigator.of(context).popUntil((route) => route.isFirst);
  }

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    final lock = context.watch<AppLockProvider>();
    return Scaffold(
      appBar: AppBar(title: Text(l10n.t('settings_app_lock'))),
      body: SingleChildScrollView(
        padding: const EdgeInsets.fromLTRB(16, 8, 16, 32),
        child: ResponsiveBody(
          maxWidth: 680,
          padding: EdgeInsets.zero,
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              Container(
                padding: const EdgeInsets.all(20),
                decoration: BoxDecoration(
                  gradient: lock.enabled ? null : AppColors.softGradient,
                  color: lock.enabled ? AppColors.teal : null,
                  borderRadius: BorderRadius.circular(AppRadii.xl),
                  border: lock.enabled
                      ? null
                      : Border.all(color: AppColors.border),
                  boxShadow:
                      lock.enabled ? AppShadows.brand : AppShadows.card,
                ),
                child: Row(
                  children: [
                    Container(
                      width: 54,
                      height: 54,
                      decoration: BoxDecoration(
                        color: lock.enabled
                            ? Colors.white.withValues(alpha: 0.16)
                            : AppColors.tealSoft,
                        borderRadius: BorderRadius.circular(17),
                      ),
                      child: Icon(
                        lock.enabled
                            ? Icons.lock_rounded
                            : Icons.lock_open_rounded,
                        color: lock.enabled
                            ? Colors.white
                            : AppColors.tealDark,
                        size: 28,
                      ),
                    ),
                    const SizedBox(width: 14),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            lock.enabled
                                ? l10n.t('settings_app_lock_on')
                                : l10n.t('settings_app_lock'),
                            style: TextStyle(
                              color: lock.enabled
                                  ? Colors.white
                                  : AppColors.navy,
                              fontSize: 19,
                              fontWeight: FontWeight.w800,
                              letterSpacing: -0.3,
                            ),
                          ),
                          const SizedBox(height: 4),
                          Text(
                            lock.enabled
                                ? l10n.t('settings_app_lock_on_body')
                                : l10n.t('settings_app_lock_off_body'),
                            style: TextStyle(
                              color: lock.enabled
                                  ? Colors.white.withValues(alpha: 0.84)
                                  : AppColors.slate,
                              fontSize: 12.5,
                              height: 1.45,
                            ),
                          ),
                        ],
                      ),
                    ),
                  ],
                ),
              ),
              const SizedBox(height: 14),
              AppInfoBanner(
                icon: Icons.shield_outlined,
                text: l10n.t('settings_app_lock_note'),
                color: AppColors.warning,
                background: AppColors.warningSoft,
              ),
              if (lock.enabled) ...[
                const SizedBox(height: 12),
                FilledButton.icon(
                  onPressed: _lockNow,
                  icon: const Icon(Icons.lock_outline_rounded),
                  label: Text(l10n.t('app_lock_lock_now')),
                ),
              ],
              const SizedBox(height: 18),
              if (!lock.enabled) ...[
                _SectionLabel(label: l10n.t('app_lock_enable_title')),
                _PinForm(
                  fields: [
                    _PinInput(
                      controller: _newController,
                      label: l10n.t('pin_new'),
                    ),
                    _PinInput(
                      controller: _confirmController,
                      label: l10n.t('pin_confirm'),
                    ),
                  ],
                  helper: l10n.t('pin_create_body'),
                  error: _error,
                  working: _working,
                  buttonLabel: l10n.t('set_pin'),
                  onPressed: () => _enable(l10n.t('pin_saved')),
                ),
              ] else ...[
                _SectionLabel(label: l10n.t('app_lock_change_title')),
                _PinForm(
                  fields: [
                    _PinInput(
                      controller: _currentController,
                      label: l10n.t('pin_current'),
                    ),
                    _PinInput(
                      controller: _newController,
                      label: l10n.t('pin_new'),
                    ),
                    _PinInput(
                      controller: _confirmController,
                      label: l10n.t('pin_confirm'),
                    ),
                  ],
                  helper: l10n.t('app_lock_new_body'),
                  error: _error,
                  working: _working,
                  buttonLabel: l10n.t('change_pin'),
                  onPressed: _change,
                ),
                const SizedBox(height: 22),
                _SectionLabel(label: l10n.t('remove_pin')),
                Card(
                  child: Padding(
                    padding: const EdgeInsets.all(16),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.stretch,
                      children: [
                        Text(
                          l10n.t('app_lock_current_body'),
                          style: Theme.of(context).textTheme.bodySmall,
                        ),
                        const SizedBox(height: 10),
                        _PinInput(
                          controller: _disableController,
                          label: l10n.t('pin_current'),
                        ),
                        if (_disableError != null) ...[
                          const SizedBox(height: 8),
                          Text(
                            _disableError!,
                            style: const TextStyle(
                              color: AppColors.danger,
                              fontSize: 12.5,
                              fontWeight: FontWeight.w600,
                            ),
                          ),
                        ],
                        const SizedBox(height: 12),
                        OutlinedButton.icon(
                          onPressed: _working ? null : _disable,
                          style: OutlinedButton.styleFrom(
                            foregroundColor: AppColors.danger,
                            side: const BorderSide(
                              color: AppColors.danger,
                            ),
                          ),
                          icon: const Icon(Icons.lock_open_rounded, size: 18),
                          label: Text(l10n.t('remove_pin')),
                        ),
                      ],
                    ),
                  ),
                ),
              ],
              const SizedBox(height: 18),
              Text(
                l10n.t('settings_app_lock_note'),
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
    );
  }
}

class _PinForm extends StatelessWidget {
  final List<Widget> fields;
  final String helper;
  final String? error;
  final bool working;
  final String buttonLabel;
  final VoidCallback onPressed;

  const _PinForm({
    required this.fields,
    required this.helper,
    required this.error,
    required this.working,
    required this.buttonLabel,
    required this.onPressed,
  });

  @override
  Widget build(BuildContext context) {
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Text(helper, style: Theme.of(context).textTheme.bodySmall),
            const SizedBox(height: 12),
            for (var i = 0; i < fields.length; i++) ...[
              if (i > 0) const SizedBox(height: 10),
              fields[i],
            ],
            if (error != null) ...[
              const SizedBox(height: 10),
              Text(
                error!,
                style: const TextStyle(
                  color: AppColors.danger,
                  fontSize: 12.5,
                  fontWeight: FontWeight.w600,
                ),
              ),
            ],
            const SizedBox(height: 14),
            FilledButton(
              onPressed: working ? null : onPressed,
              child: working
                  ? const SizedBox(
                      width: 20,
                      height: 20,
                      child: CircularProgressIndicator(
                        strokeWidth: 2,
                        color: Colors.white,
                      ),
                    )
                  : Text(buttonLabel),
            ),
          ],
        ),
      ),
    );
  }
}

class _PinInput extends StatelessWidget {
  final TextEditingController controller;
  final String label;

  const _PinInput({required this.controller, required this.label});

  @override
  Widget build(BuildContext context) {
    return TextField(
      controller: controller,
      obscureText: true,
      keyboardType: TextInputType.number,
      maxLength: 6,
      inputFormatters: [FilteringTextInputFormatter.digitsOnly],
      decoration: InputDecoration(
        labelText: label,
        counterText: '',
        prefixIcon: const Icon(Icons.pin_outlined),
      ),
    );
  }
}

class _SectionLabel extends StatelessWidget {
  final String label;

  const _SectionLabel({required this.label});

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(left: 4, bottom: 8),
      child: Text(
        label,
        style: Theme.of(context).textTheme.labelLarge?.copyWith(
              color: AppColors.slate,
              fontWeight: FontWeight.w700,
              fontSize: 12.5,
            ),
      ),
    );
  }
}
