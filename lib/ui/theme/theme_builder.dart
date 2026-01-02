import 'package:aniverse/settings/routes.dart';
import 'package:dynamic_color/dynamic_color.dart';
import 'package:dynamic_themes/dynamic_themes.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:get/route_manager.dart';
import 'package:aniverse/theme.dart';
import 'package:aniverse/ui/pages/search_page.dart';

class _BackIntent extends Intent {
  const _BackIntent();
}

class _SearchIntent extends Intent {
  const _SearchIntent();
}

bool _isTextEditing() {
  final focus = FocusManager.instance.primaryFocus;
  final context = focus?.context;
  if (context == null) {
    return false;
  }
  return context.widget is EditableText ||
      context.findAncestorWidgetOfExactType<EditableText>() != null;
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
            home: AnimatedBuilder(
              animation: FocusManager.instance,
              builder: (context, _) {
                final isEditing = _isTextEditing();
                return Shortcuts(
                  shortcuts: {
                    if (!isEditing)
                      LogicalKeySet(LogicalKeyboardKey.backspace):
                          const _BackIntent(),
                    if (!isEditing)
                      LogicalKeySet(LogicalKeyboardKey.escape):
                          const _BackIntent(),
                    if (!isEditing)
                      LogicalKeySet(
                        LogicalKeyboardKey.control,
                        LogicalKeyboardKey.keyF,
                      ):
                          const _SearchIntent(),
                  },
                  child: Actions(
                    actions: {
                      _BackIntent: CallbackAction<_BackIntent>(
                        onInvoke: (intent) {
                          if (_isTextEditing()) {
                            return null;
                          }
                          return Navigator.of(context).maybePop();
                        },
                      ),
                      _SearchIntent: CallbackAction<_SearchIntent>(
                        onInvoke: (intent) {
                          if (_isTextEditing()) {
                            return null;
                          }
                          Get.to(() => const SearchPage());
                          return null;
                        },
                      ),
                    },
                    child: FocusScope(
                      autofocus: true,
                      child: home,
                    ),
                  ),
                );
              },
            ),
            onGenerateRoute: RouteGenerator.generateRoute,
            initialRoute: RouteGenerator.mainPage,
          ),
        );
      },
    );
  }
}

