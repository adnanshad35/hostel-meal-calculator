import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';

/// Tells screens whether the browser window is wide enough for the
/// desktop layout.
class WebLayout extends InheritedWidget {
  const WebLayout({super.key, required this.isDesktop, required super.child});

  /// Windows at least this wide get the desktop layout.
  static const double desktopBreakpoint = 1000;

  /// Narrow screens, such as sign-in, are shown in a column this wide.
  static const double phoneWidth = 520;

  /// True while the desktop shell is on screen and needs the whole
  /// window. Set by the shell itself.
  static final ValueNotifier<bool> shellActive = ValueNotifier(false);

  final bool isDesktop;

  static bool isDesktopOf(BuildContext context) {
    return context.dependOnInheritedWidgetOfExactType<WebLayout>()?.isDesktop ??
        false;
  }

  @override
  bool updateShouldNotify(WebLayout oldWidget) {
    return oldWidget.isDesktop != isDesktop;
  }
}

/// Decides how the app sits in a browser window.
///
/// On a phone-sized window, and outside the browser, the app is shown
/// as it is. On a wider window it is a phone-width column in the
/// centre of the page, unless the desktop shell is on screen, which
/// uses the full width.
class WebFrame extends StatelessWidget {
  const WebFrame({super.key, required this.child});

  final Widget child;

  @override
  Widget build(BuildContext context) {
    // Outside the browser the app always fills the screen.
    if (!kIsWeb) return child;

    final media = MediaQuery.of(context);
    final width = media.size.width;
    final isDesktop = width >= WebLayout.desktopBreakpoint;

    return WebLayout(
      isDesktop: isDesktop,
      child: ValueListenableBuilder<bool>(
        valueListenable: WebLayout.shellActive,
        builder: (context, shellActive, _) {
          final fillsWindow =
              width <= WebLayout.phoneWidth || (isDesktop && shellActive);

          // The same widgets are used whether or not the app is framed,
          // so switching between the two never rebuilds the app from
          // scratch and loses what the user was doing.
          return ColoredBox(
            color: const Color(0xFFE3EBE6),
            child: Center(
              child: Container(
                width: fillsWindow ? width : WebLayout.phoneWidth,
                decoration: BoxDecoration(
                  boxShadow: [
                    if (!fillsWindow)
                      const BoxShadow(
                        color: Color(0x33000000),
                        blurRadius: 40,
                        offset: Offset(0, 8),
                      ),
                  ],
                ),
                child: ClipRect(
                  // Screens measure themselves against the column's
                  // width, not the browser window's.
                  child: MediaQuery(
                    data: fillsWindow
                        ? media
                        : media.copyWith(
                            size: Size(WebLayout.phoneWidth, media.size.height),
                          ),
                    child: child,
                  ),
                ),
              ),
            ),
          );
        },
      ),
    );
  }
}
