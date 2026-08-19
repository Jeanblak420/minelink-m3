/// Shared layout breakpoints for portal shell, super-admin shell, and responsive content.
abstract final class AppBreakpoints {
  AppBreakpoints._();

  /// Persistent sidebar vs drawer / compact app bar chrome.
  static const double sidebarBreakpoint = 900;

  /// Multi-column dashboard cards and wide summary layouts (can differ from [sidebarBreakpoint]).
  static const double dashboardWideMin = 800;

  /// Wide data tables vs compact card lists (fleet, dense grids).
  static const double compactTableMax = 600;
}
