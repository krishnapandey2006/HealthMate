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

  // Tabs are built on first visit and kept alive afterwards. Constructing all
  // five at startup duplicated network work (Home and News both fetched news)
  // and loaded local repositories that might never be opened.
  final Set<int> _mountedTabs = {0};

  static const _pages = <Widget>[
    HomeScreen(),
    AppointmentsScreen(),
    HealthHubScreen(),
    HealthNewsScreen(),
    ProfileScreen(),
  ];

  void _selectTab(int value) {
    if (value < 0 || value >= _pages.length) return;
    setState(() {
      _mountedTabs.add(value);
      _index = value;
    });
  }

  List<Widget> get _tabChildren => List<Widget>.generate(
        _pages.length,
        (i) => _mountedTabs.contains(i) ? _pages[i] : const SizedBox.shrink(),
        growable: false,
      );

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
                onDestinationSelected: _selectTab,
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
                selectTab: _selectTab,
                child: IndexedStack(index: _index, children: _tabChildren),
              ),
            ),
          ],
        ),
      );
    } else {
      shell = Scaffold(
        body: MainTabScope(
          selectTab: _selectTab,
          child: IndexedStack(index: _index, children: _tabChildren),
        ),
        bottomNavigationBar: _HealthMateNavigationBar(
          key: const Key('main-bottom-navigation'),
          selectedIndex: _index,
          onSelected: _selectTab,
          destinations: destinations,
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

/// A Material-3-style bottom bar with labels that are guaranteed to render on
/// one line. Flutter's stock NavigationBar wraps long labels such as
/// "Appointments" at 320-360 dp widths; FittedBox scales only when a label is
/// genuinely wider than the space it can borrow from short neighbouring labels.
class _HealthMateNavigationBar extends StatelessWidget {
  final int selectedIndex;
  final ValueChanged<int> onSelected;
  final List<_Destination> destinations;

  const _HealthMateNavigationBar({
    super.key,
    required this.selectedIndex,
    required this.onSelected,
    required this.destinations,
  });

  @override
  Widget build(BuildContext context) {
    final bottomInset = MediaQuery.paddingOf(context).bottom;
    return Material(
      color: Colors.white,
      child: SizedBox(
        height: 72 + bottomInset,
        child: Padding(
          padding: EdgeInsets.only(bottom: bottomInset),
          child: LayoutBuilder(
            builder: (context, constraints) {
              final slot = constraints.maxWidth / destinations.length;
              final labelWidth = (slot + 28).clamp(slot, 112.0).toDouble();
              return Row(
                children: [
                  for (var i = 0; i < destinations.length; i++)
                    Expanded(
                      child: _HealthMateNavItem(
                        destination: destinations[i],
                        selected: i == selectedIndex,
                        labelWidth: labelWidth,
                        onTap: () => onSelected(i),
                      ),
                    ),
                ],
              );
            },
          ),
        ),
      ),
    );
  }
}

class _HealthMateNavItem extends StatelessWidget {
  final _Destination destination;
  final bool selected;
  final double labelWidth;
  final VoidCallback onTap;

  const _HealthMateNavItem({
    required this.destination,
    required this.selected,
    required this.labelWidth,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    final color = selected ? AppColors.tealDark : AppColors.muted;
    return Semantics(
      button: true,
      selected: selected,
      label: destination.label,
      excludeSemantics: true,
      child: InkWell(
        onTap: onTap,
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            AnimatedContainer(
              duration: AppMotion.fast,
              curve: Curves.easeOut,
              width: 56,
              height: 30,
              alignment: Alignment.center,
              decoration: BoxDecoration(
                color: selected ? AppColors.tealSoft : Colors.transparent,
                borderRadius: BorderRadius.circular(999),
              ),
              child: Icon(
                selected ? destination.selectedIcon : destination.icon,
                size: 22,
                color: selected ? AppColors.teal : AppColors.muted,
              ),
            ),
            const SizedBox(height: 3),
            SizedBox(
              width: labelWidth,
              height: 15,
              child: FittedBox(
                fit: BoxFit.scaleDown,
                child: Text(
                  destination.label,
                  maxLines: 1,
                  softWrap: false,
                  style: TextStyle(
                    fontSize: 11.5,
                    height: 1.1,
                    fontWeight: selected ? FontWeight.w700 : FontWeight.w500,
                    color: color,
                  ),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
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
