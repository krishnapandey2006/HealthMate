import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';

import '../app/theme.dart';
import '../health_news_screen.dart';
import '../l10n/app_localizations.dart';
import '../services/chatbot_web.dart';
import '../widgets/app_widgets.dart';
import '../widgets/chatbot_launcher.dart';
import 'appointments_screen.dart';
import 'chatbot_chat.dart';
import 'health_hub_screen.dart';
import 'home_screen.dart';
import 'profile_screen.dart';
import 'settings_screen.dart';

class MainScaffold extends StatefulWidget {
  const MainScaffold({super.key});

  @override
  State<MainScaffold> createState() => _MainScaffoldState();
}

class _MainScaffoldState extends State<MainScaffold> {
  int _index = 0;
  bool _chatMounted = false;
  bool _chatOpen = false;

  static const _pages = <Widget>[
    HomeScreen(),
    AppointmentsScreen(),
    HealthHubScreen(),
    HealthNewsScreen(),
    ProfileScreen(),
  ];

  @override
  void initState() {
    super.initState();
    // The web build uses the Noupe embed's own launcher (web/index.html).
    setChatbotLauncherVisible(true);
  }

  @override
  void dispose() {
    setChatbotLauncherVisible(false);
    super.dispose();
  }

  void _openChatbot() {
    setState(() {
      _chatMounted = true;
      _chatOpen = true;
    });
  }

  void _closeChatbot() {
    if (!_chatOpen) return;
    setState(() => _chatOpen = false);
  }

  void _openSettings() {
    Navigator.of(context).push(
      MaterialPageRoute(builder: (_) => const SettingsScreen()),
    );
  }

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    final wide = MediaQuery.sizeOf(context).width >= 900;
    final bottomInset = MediaQuery.paddingOf(context).bottom;
    final destinations = [
      _Destination(Icons.home_outlined, Icons.home_rounded, l10n.t('home')),
      _Destination(Icons.calendar_month_outlined, Icons.calendar_month_rounded,
          l10n.t('appointments')),
      _Destination(Icons.health_and_safety_outlined,
          Icons.health_and_safety_rounded, l10n.t('health')),
      _Destination(
          Icons.newspaper_outlined, Icons.newspaper_rounded, l10n.t('news')),
      _Destination(Icons.person_outline_rounded, Icons.person_rounded,
          l10n.t('profile')),
    ];

    final Widget shell;
    if (wide) {
      shell = Scaffold(
        body: Row(
          children: [
            Container(
              decoration: const BoxDecoration(
                color: Colors.white,
                border: Border(right: BorderSide(color: AppColors.border)),
              ),
              child: NavigationRail(
                selectedIndex: _index,
                onDestinationSelected: (value) =>
                    setState(() => _index = value),
                labelType: NavigationRailLabelType.all,
                backgroundColor: Colors.white,
                indicatorColor: AppColors.tealSoft,
                useIndicator: true,
                minWidth: 86,
                leading: const Padding(
                  padding: EdgeInsets.only(top: 18, bottom: 28),
                  child: AppMark(size: 40),
                ),
                trailing: Padding(
                  padding: const EdgeInsets.only(bottom: 18),
                  child: IconButton(
                    tooltip: l10n.t('settings_title'),
                    onPressed: _openSettings,
                    icon: const Icon(Icons.settings_outlined),
                  ),
                ),
                destinations: [
                  for (final destination in destinations)
                    NavigationRailDestination(
                      icon: Icon(destination.icon),
                      selectedIcon:
                          Icon(destination.selectedIcon, color: AppColors.teal),
                      label: Text(destination.label),
                    ),
                ],
              ),
            ),
            Expanded(
              child: MainTabScope(
                selectTab: (value) => setState(() => _index = value),
                child: IndexedStack(index: _index, children: _pages),
              ),
            ),
          ],
        ),
      );
    } else {
      shell = Scaffold(
        body: MainTabScope(
          selectTab: (value) => setState(() => _index = value),
          child: IndexedStack(index: _index, children: _pages),
        ),
        bottomNavigationBar: NavigationBar(
          selectedIndex: _index,
          onDestinationSelected: (value) => setState(() => _index = value),
          destinations: [
            for (final destination in destinations)
              NavigationDestination(
                icon: Icon(destination.icon),
                selectedIcon: Icon(destination.selectedIcon),
                label: destination.label,
              ),
          ],
        ),
      );
    }

    if (kIsWeb) return shell;

    return PopScope(
      canPop: !_chatOpen,
      onPopInvokedWithResult: (didPop, result) {
        if (!didPop && _chatOpen) _closeChatbot();
      },
      child: Stack(
        children: [
          shell,
          if (_chatMounted)
            Offstage(
              offstage: !_chatOpen,
              child: ChatbotChat(
                open: _chatOpen,
                onClosed: _closeChatbot,
              ),
            ),
          if (!_chatOpen)
            Positioned(
              right: 16,
              bottom: bottomInset + (wide ? 16 : 72 + 16),
              child: ChatbotLauncher(onPressed: _openChatbot),
            ),
        ],
      ),
    );
  }
}

class _Destination {
  final IconData icon;
  final IconData selectedIcon;
  final String label;

  const _Destination(this.icon, this.selectedIcon, this.label);
}

/// Lets dashboard cards switch the main tab without pushing a duplicate screen.
class MainTabScope extends InheritedWidget {
  final ValueChanged<int> selectTab;

  const MainTabScope({
    super.key,
    required this.selectTab,
    required super.child,
  });

  static MainTabScope? maybeOf(BuildContext context) =>
      context.dependOnInheritedWidgetOfExactType<MainTabScope>();

  @override
  bool updateShouldNotify(MainTabScope oldWidget) => false;
}
