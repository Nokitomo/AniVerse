import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import 'package:aniverse/ui/pages/calendar_page.dart';
import 'package:aniverse/ui/pages/explore_page.dart';
import 'package:aniverse/ui/pages/settings_page.dart';
import 'package:aniverse/ui/pages/home_page.dart';
import 'package:aniverse/ui/pages/archive_page.dart';

class MainPage extends StatefulWidget {
  const MainPage({super.key});

  @override
  State<MainPage> createState() => _MainPageState();
}

class _MainPageState extends State<MainPage> {
  var index = 0;
  @override
  void initState() {
    super.initState();

    SystemChrome.setPreferredOrientations([
      DeviceOrientation.portraitUp,
      DeviceOrientation.portraitDown,
      DeviceOrientation.landscapeLeft,
      DeviceOrientation.landscapeRight,
    ]);
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Theme.of(context).colorScheme.background,
      body: IndexedStack(
        index: index,
        children: [
          HomePage(),
          const ExplorePage(),
          const CalendarPage(),
          const ArchivePage(),
          SettingsPage(),
        ],
      ),
      bottomNavigationBar: NavigationBarTheme(
        data: NavigationBarThemeData(
          backgroundColor: Theme.of(context).colorScheme.surface,
          height: 70,
          indicatorColor: Theme.of(context).colorScheme.secondaryContainer,
          labelTextStyle: MaterialStateProperty.all(
            const TextStyle(
              fontSize: 14,
              fontWeight: FontWeight.w500,
            ),
          ),
        ),
        child: NavigationBar(
          // labelBehavior: NavigationDestinationLabelBehavior.onlyShowSelected,
          animationDuration: const Duration(milliseconds: 1200),
          selectedIndex: index,
          onDestinationSelected: (value) => index == value ? null : setState(() => index = value),
          destinations: [
            NavigationDestination(
              icon: Icon(
                Icons.home_outlined,
                color: Theme.of(context).colorScheme.onSurfaceVariant,
              ),
              selectedIcon: Icon(
                Icons.home,
                color: Theme.of(context).colorScheme.onSecondaryContainer,
              ),
              label: "Home",
            ),
            NavigationDestination(
              icon: Icon(
                Icons.explore_outlined,
                color: Theme.of(context).colorScheme.onSurfaceVariant,
              ),
              selectedIcon: Icon(
                Icons.explore,
                color: Theme.of(context).colorScheme.onSecondaryContainer,
              ),
              label: "Esplora",
            ),
            NavigationDestination(
              icon: Icon(
                Icons.calendar_today_outlined,
                color: Theme.of(context).colorScheme.onSurfaceVariant,
              ),
              selectedIcon: Icon(
                Icons.calendar_today,
                color: Theme.of(context).colorScheme.onSecondaryContainer,
              ),
              label: "Calendario",
            ),
            NavigationDestination(
              icon: Icon(
                Icons.archive_outlined,
                color: Theme.of(context).colorScheme.onSurfaceVariant,
              ),
              selectedIcon: Icon(
                Icons.archive,
                color: Theme.of(context).colorScheme.onSecondaryContainer,
              ),
              label: "Archivio",
            ),
            NavigationDestination(
              icon: Icon(
                Icons.settings_outlined,
                color: Theme.of(context).colorScheme.onSurfaceVariant,
              ),
              selectedIcon: Icon(
                Icons.settings,
                color: Theme.of(context).colorScheme.onSecondaryContainer,
              ),
              label: "Impostazioni",
            ),
          ],
        ),
      ),
    );
  }
}

