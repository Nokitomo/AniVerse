import 'package:aniverse/settings/routes.dart';
import 'package:dynamic_color/dynamic_color.dart';
import 'package:dynamic_themes/dynamic_themes.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:get/route_manager.dart';
import 'package:aniverse/theme.dart';
import 'package:aniverse/ui/pages/search_page.dart';

bool _isTextEditing() {
  final focus = FocusManager.instance.primaryFocus;
  final context = focus?.context;
  if (context == null) {
    return false;
  }
  return context.widget is EditableText ||
      context.findAncestorWidgetOfExactType<EditableText>() != null;
}

KeyEventResult _handleAppKey(BuildContext context, KeyEvent event) {
  if (_isTextEditing()) {
    return KeyEventResult.ignored;
  }
  if (event is! KeyDownEvent) {
    return KeyEventResult.ignored;
  }

  final key = event.logicalKey;
  if (key == LogicalKeyboardKey.backspace ||
      key == LogicalKeyboardKey.escape) {
    Navigator.of(context).maybePop();
    return KeyEventResult.handled;
  }

  if (key == LogicalKeyboardKey.keyF &&
      HardwareKeyboard.instance.logicalKeysPressed.any(
        (k) =>
            k == LogicalKeyboardKey.controlLeft ||
            k == LogicalKeyboardKey.controlRight,
      )) {
    Get.to(() => const SearchPage());
    return KeyEventResult.handled;
  }

  return KeyEventResult.ignored;
}

class DynamicThemeBuilder extends StatelessWidget {
  const DynamicThemeBuilder({
    Key? key,
    required this.title,
    required this.home,
  }) : super(key: key);
  final String title;
  final Widget home;

  @override
  Widget build(BuildContext context) {
    return DynamicColorBuilder(
      builder: (lightColorScheme, darkColorScheme) {
        final ThemeData lightDynamicTheme = ThemeData(
          useMaterial3: true,
          colorScheme: lightColorScheme?.harmonized(),
        );
        final ThemeData darkDynamicTheme = ThemeData(
          useMaterial3: true,
          colorScheme: darkColorScheme?.harmonized(),
        );
        return DynamicTheme(
          themeCollection: ThemeCollection(
            themes: {
              0: lightCustomTheme,
              1: darkCustomTheme,
              2: lightDynamicTheme,
              3: darkDynamicTheme,
            },
            fallbackTheme: lightCustomTheme,
          ),
          builder: (context, theme) => GetMaterialApp(
            debugShowCheckedModeBanner: false,
            title: title,
            theme: theme,
            home: Focus(
              autofocus: true,
              onKeyEvent: (node, event) => _handleAppKey(context, event),
              child: home,
            ),
            onGenerateRoute: RouteGenerator.generateRoute,
            initialRoute: RouteGenerator.mainPage,
          ),
        );
      },
    );
  }
}

