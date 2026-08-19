/* MineLink — shared theme controller (plain JS, no build step).
 * Single source of truth for the active app theme across every portal.
 * Applies [data-theme] to <html> so the design-system tokens (and thus all
 * chrome + screens) switch, persists the choice, and broadcasts changes so
 * React surfaces (app bar, Employee Register, …) can follow along.
 *
 * Load this in <head> (before the app scripts) so the theme is applied
 * before first paint — no flash. */
(function () {
  var KEY = 'ml-theme';
  var THEMES = ['light', 'dark'];
  function get() {
    try { var t = localStorage.getItem(KEY); return THEMES.indexOf(t) >= 0 ? t : 'light'; }
    catch (e) { return 'light'; }
  }
  function apply(t) { document.documentElement.setAttribute('data-theme', t); }
  function set(t) {
    if (THEMES.indexOf(t) < 0) t = 'light';
    try { localStorage.setItem(KEY, t); } catch (e) {}
    apply(t);
    try { window.dispatchEvent(new CustomEvent('ml-theme-change', { detail: t })); } catch (e) {}
  }
  function toggle() { set(get() === 'dark' ? 'light' : 'dark'); }
  apply(get());
  // keep tabs in sync
  window.addEventListener('storage', function (e) { if (e.key === KEY && e.newValue) { apply(e.newValue); try { window.dispatchEvent(new CustomEvent('ml-theme-change', { detail: e.newValue })); } catch (x) {} } });
  window.MLPortalTheme = { get: get, set: set, toggle: toggle, THEMES: THEMES };
})();
