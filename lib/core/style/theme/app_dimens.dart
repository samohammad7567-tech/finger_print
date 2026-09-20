import 'dart:math' as math;
import 'dart:ui' show Size;

/// Fixed desktop metrics.
///
/// This is a Windows desktop app, so sizes are absolute logical pixels rather
/// than scaled units — there is no `flutter_screenutil` here.
///
/// ## The shell
///
/// ```
/// ┌──────────┬────────────────────────────────┐
/// │  brand   │  top bar                 48px  │
/// ├──────────┼────────────────────────────────┤
/// │   rail   │  page header  (title + tabs)   │
/// │  236px   ├────────────────────────────────┤
/// │  (58px)  │  content      pad 20           │
/// ├──────────┴────────────────────────────────┤
/// │  status bar                         26px  │
/// └───────────────────────────────────────────┘
/// ```
///
/// The top bar runs the full width and its first [sidebarWidth] pixels are
/// filled with the rail's deep teal, so the brand block and the rail read as
/// one continuous column of chrome down the leading edge.
class AppDimens {
  const AppDimens._();

  // Chrome
  static const double sidebarWidth = 236;
  static const double sidebarCollapsedWidth = 58;
  static const double topBarHeight = 48;
  static const double statusBarHeight = 26;
  static const double toolbarHeight = 48;
  static const double pageHeaderHeight = 68;

  /// Width of the notification panel, which overlays the content rather than
  /// displacing it — a table that reflows when a panel opens loses the row the
  /// operator was reading.
  static const double notificationPanelWidth = 340;

  // Minimum window the layout is designed for
  static const double minWindowWidth = 1024;
  static const double minWindowHeight = 700;

  /// The window to open with when the display is big enough to hold it.
  static const Size designWindowSize = Size(1440, 900);

  /// The window to open, and the smallest the operator may drag it to, on a
  /// desktop whose displays report these work areas.
  ///
  /// [openOn] is the work area of the display the window will be centred on;
  /// [smallest] the smallest work area of any display it could later be moved
  /// to. Both exclude the taskbar, and both are logical pixels — a 1920×1080
  /// panel at 175% is a 1097×590 work area, not a 1920×1080 one.
  ///
  /// ## Why the minimum is clamped at all
  ///
  /// A minimum taller than the screen is a window that cannot be made to fit.
  /// Windows honours the minimum over the desktop bounds, so the bottom of the
  /// app — [statusBarHeight] and whatever sits above it — is pushed below the
  /// visible desktop, and no amount of dragging or maximising brings it back.
  /// On a 1920×1080 panel at 175% scaling that is exactly what
  /// [minWindowHeight] does: 700 logical pixels of demand against 590 of
  /// screen. The layout does not need those 700 — the shell is a column that
  /// gives whatever is left to the routed page, and every page scrolls — so
  /// the number is a preference, and a preference must yield to the display.
  ///
  /// The two sizes come from different displays on purpose. The window opens
  /// centred on one screen, so its *size* is that screen's business; it can be
  /// dragged to any of them afterwards, so its *minimum* has to satisfy the
  /// meanest one. A minimum smaller than the design figure costs nothing: it
  /// permits a smaller window, it does not impose one.
  ///
  /// A work area that arrives empty or nonsensical — a display query that
  /// failed — falls back to the design sizes, which is the behaviour this had
  /// before it asked the display anything.
  static ({Size size, Size minimum}) windowFor({
    required Size openOn,
    required Size smallest,
  }) {
    final display = _usable(openOn);
    final meanest = _usable(smallest);

    return (
      size: Size(
        math.min(designWindowSize.width, display.width),
        math.min(designWindowSize.height, display.height),
      ),
      minimum: Size(
        math.min(minWindowWidth, meanest.width),
        math.min(minWindowHeight, meanest.height),
      ),
    );
  }

  /// [area] if it is a size a window could actually occupy, the design size
  /// otherwise. Guards zero, negative and NaN alike — `min` propagates a NaN
  /// silently, and a NaN window size is a window that never appears.
  static Size _usable(Size area) => Size(
    area.width.isFinite && area.width > 0 ? area.width : designWindowSize.width,
    area.height.isFinite && area.height > 0
        ? area.height
        : designWindowSize.height,
  );

  // ---------------------------------------------------------------------------
  // Radii
  // ---------------------------------------------------------------------------
  //
  // Almost square. Enterprise software is judged on how much information fits
  // and how sober it looks; rounded panels read as consumer-friendly at the
  // cost of both. Radius grows with the surface — a classification swatch is
  // barely rounded at all, a dialog is the softest thing on screen — but the
  // whole scale spans four pixels.

  /// Swatches, level badges, inline tags.
  static const double radiusXs = 2;

  /// Small controls: pagination buttons, rail destinations, demo chips.
  static const double radiusSm = 3;

  /// The default: buttons, inputs, dropdowns, filter chips.
  static const double radius = 4;

  /// Cards, panels, toasts.
  static const double radiusLg = 5;

  /// Dialogs.
  static const double radiusXl = 6;

  static const double radiusFull = 999;

  // ---------------------------------------------------------------------------
  // Spacing — a 4px base grid, with the two half-steps the dense layouts need.
  // ---------------------------------------------------------------------------
  static const double spaceXs = 4;
  static const double spaceSm = 8;
  static const double spaceMd = 12;
  static const double spaceLg = 16;
  static const double spaceXl = 24;
  static const double space2xl = 32;

  /// Gap between sibling cards in a grid or a stack.
  static const double cardGap = 12;

  /// Gap between the major sections of a page.
  static const double sectionGap = 16;

  /// Width of the halo drawn outside a focused control.
  static const double focusRingWidth = 3;

  /// Padding around the scrollable content of a page. The bottom is deeper
  /// than the top so the last row of a long table does not sit against the
  /// status bar.
  static const double pagePadding = 20;
  static const double pagePaddingTop = 18;
  static const double pagePaddingBottom = 26;

  /// Padding inside a card body, and inside a card's header strip.
  static const double cardPadding = 16;
  static const double cardHeaderPaddingV = 11;

  // ---------------------------------------------------------------------------
  // Controls
  // ---------------------------------------------------------------------------
  static const double controlHeightSm = 26;
  static const double controlHeight = 30;
  static const double controlHeightLg = 36;
  static const double iconButtonWidth = 32;
  static const double iconButtonSize = 30;

  // ---------------------------------------------------------------------------
  // Data tables
  // ---------------------------------------------------------------------------

  /// Horizontal padding of every cell, header and body alike.
  static const double tableCellPaddingH = 12;

  /// Header band. Shorter than a body row: it is read once, not scanned.
  static const double tableHeaderHeight = 30;

  /// Vertical padding of a body row at each density, and the row heights they
  /// produce with a 13px line.
  ///
  /// Comfortable is the default because rows are the surface an operator
  /// scans all day. Compact exists for the two screens that are genuinely
  /// about volume — history and the record table — and is opt-in per session.
  static const double tableRowPaddingV = 9;
  static const double tableRowPaddingVCompact = 5;
  static const double tableRowHeight = 38;
  static const double tableRowHeightCompact = 30;

  /// Footer strip carrying the row range and pagination.
  static const double tableFooterHeight = 34;

  // ---------------------------------------------------------------------------
  // Icons
  // ---------------------------------------------------------------------------
  static const double iconXs = 12;
  static const double iconSm = 14;
  static const double iconMd = 16;
  static const double iconLg = 17;
  static const double iconXl = 19;
  static const double icon2xl = 24;

  /// Stroke width every line icon is drawn at.
  static const double iconStroke = 1.5;

  // ---------------------------------------------------------------------------
  // Folding thresholds
  // ---------------------------------------------------------------------------

  /// Below this the sign-in brand panel drops away.
  static const double signInFoldWidth = 900;

  /// Below this the dashboard's four figures fold to 2x2 — folding beats
  /// truncating a formatted number.
  static const double statFoldWidth = 1180;
}
