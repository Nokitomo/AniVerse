import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import 'package:aniverse/ui/pages/calendar_page.dart';
import 'package:aniverse/ui/pages/explore_page.dart';
import 'package:aniverse/ui/pages/settings_page.dart';
import 'package:aniverse/ui/pages/sc_archive_page.dart';
import 'package:aniverse/ui/pages/sc_explore_page.dart';
import 'package:aniverse/ui/pages/sc_home_page.dart';
import 'package:aniverse/ui/pages/home_page.dart';
import 'package:aniverse/ui/pages/archive_page.dart';
import 'package:aniverse/ui/widgets/sc_webview_host.dart';

class MainPage extends StatefulWidget {
  const MainPage({super.key});

  @override
  State<MainPage> createState() => _MainPageState();
}

class _MainPageState extends State<MainPage> {
  var index = 0;
  _AppSection section = _AppSection.anime;
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
    final tabs = _buildTabs();
    final destinations = _buildDestinations(context);
    return Scaffold(
      backgroundColor: Theme.of(context).colorScheme.background,
      appBar: AppBar(
        backgroundColor: Theme.of(context).colorScheme.surface,
        leading: Builder(
          builder: (context) => IconButton(
            icon: const Icon(Icons.menu),
            onPressed: () => Scaffold.of(context).openDrawer(),
          ),
        ),
        title: Text(section == _AppSection.media ? "Film / Serie TV" : "Anime"),
      ),
      drawer: _buildDrawer(context),
      body: Stack(
        children: [
          IndexedStack(
            index: index,
            children: tabs,
          ),
          const ScWebViewHost(),
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
          destinations: destinations,
        ),
      ),
    );
  }

  List<Widget> _buildTabs() {
    if (section == _AppSection.media) {
      return [
        const ScHomePage(),
        const ScExplorePage(),
        const ScArchivePage(),
        SettingsPage(),
      ];
    }
    return [
      const HomePage(),
      const ExplorePage(),
      const CalendarPage(),
      const ArchivePage(),
      SettingsPage(),
    ];
  }

  List<NavigationDestination> _buildDestinations(BuildContext context) {
    if (section == _AppSection.media) {
      return [
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
          label: "Impost.",
        ),
      ];
    }
    return [
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
        label: "Impost.",
      ),
    ];
  }

  Drawer _buildDrawer(BuildContext context) {
    return Drawer(
      child: SafeArea(
        child: ListView(
          padding: const EdgeInsets.all(12),
          children: [
            Text(
              "Sezioni",
              style: TextStyle(
                color: Theme.of(context).colorScheme.onBackground,
                fontSize: 20,
                fontWeight: FontWeight.bold,
              ),
            ),
            const SizedBox(height: 8),
            ListTile(
              leading: const Icon(Icons.animation),
              title: const Text("Anime"),
              selected: section == _AppSection.anime,
              onTap: () {
                Navigator.of(context).pop();
                if (section != _AppSection.anime) {
                  setState(() {
                    section = _AppSection.anime;
                    index = 0;
                  });
                }
              },
            ),
            ListTile(
              leading: const Icon(Icons.movie),
              title: const Text("Film / Serie TV"),
              selected: section == _AppSection.media,
              onTap: () {
                Navigator.of(context).pop();
                if (section != _AppSection.media) {
                  setState(() {
                    section = _AppSection.media;
                    index = 0;
                  });
                }
              },
            ),
          ],
        ),
      ),
    );
  }
}

enum _AppSection {
  anime,
  media,
}

