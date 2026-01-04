import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import 'package:aniverse/ui/pages/calendar_page.dart';
import 'package:aniverse/ui/pages/explore_page.dart';
import 'package:aniverse/ui/pages/settings_page.dart';
import 'package:aniverse/services/app_section_controller.dart';
import 'package:aniverse/ui/pages/sc_webview_page.dart';
import 'package:aniverse/ui/pages/home_page.dart';
import 'package:aniverse/ui/pages/archive_page.dart';

class MainPage extends StatefulWidget {
  const MainPage({super.key});

  @override
  State<MainPage> createState() => _MainPageState();
}

class _MainPageState extends State<MainPage> {
  late final AppSectionController _sectionController;

  @override
  void initState() {
    super.initState();
    _sectionController = Get.put(AppSectionController());

    SystemChrome.setPreferredOrientations([
      DeviceOrientation.portraitUp,
      DeviceOrientation.portraitDown,
      DeviceOrientation.landscapeLeft,
      DeviceOrientation.landscapeRight,
    ]);
  }

  @override
  Widget build(BuildContext context) {
    return GetX<AppSectionController>(
      builder: (controller) {
        final section = controller.section.value;
        final index = controller.index.value;
        final tabs = _buildTabs(section);
        final destinations = _buildDestinations(context, section);
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
            title: Text(
              section == AppSection.media ? "StreamingCommunity" : "Anime",
            ),
          ),
          drawer: _buildDrawer(context, controller, section),
          body: IndexedStack(
            index: index,
            children: tabs,
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
              onDestinationSelected: (value) =>
                  controller.setIndex(value),
              destinations: destinations,
            ),
          ),
        );
      },
    );
  }

  List<Widget> _buildTabs(AppSection section) {
    if (section == AppSection.media) {
      return [
        const ScWebViewPage(),
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

  List<NavigationDestination> _buildDestinations(
    BuildContext context,
    AppSection section,
  ) {
    if (section == AppSection.media) {
      return [
        NavigationDestination(
          icon: Icon(
            Icons.movie_outlined,
            color: Theme.of(context).colorScheme.onSurfaceVariant,
          ),
          selectedIcon: Icon(
            Icons.movie,
            color: Theme.of(context).colorScheme.onSecondaryContainer,
          ),
          label: "Streaming",
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

  Drawer _buildDrawer(
    BuildContext context,
    AppSectionController controller,
    AppSection section,
  ) {
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
              selected: section == AppSection.anime,
              onTap: () {
                Navigator.of(context).pop();
                controller.switchTo(AppSection.anime);
              },
            ),
            ListTile(
              leading: const Icon(Icons.movie),
              title: const Text("Film / Serie TV"),
              selected: section == AppSection.media,
              onTap: () {
                Navigator.of(context).pop();
                controller.switchTo(AppSection.media);
              },
            ),
          ],
        ),
      ),
    );
  }
}

