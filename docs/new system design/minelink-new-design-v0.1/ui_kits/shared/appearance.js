/* MineLink — per-user theming (modes, accents, backgrounds incl. gradients &
 * slow-moving animated gradients, plus customizable variants). Plain IIFE.
 * Persists per-user to localStorage; only affects THAT user's view.
 * Renders a floating quick panel; full controls via MLTheme.renderSettings(el). */
(function () {
  var KEY = 'ml-theme-v2';

  var ACCENTS = [
    { id: 'cyan', name: 'MineLink Cyan', hex: '#00b5d8', hover: '#0496b6', press: '#0a7791', soft: '#e6fbff' },
    { id: 'indigo', name: 'Indigo', hex: '#4f46e5', hover: '#4338ca', press: '#3730a3', soft: '#eef2ff' },
    { id: 'violet', name: 'Violet', hex: '#7c3aed', hover: '#6d28d9', press: '#5b21b6', soft: '#f5f3ff' },
    { id: 'emerald', name: 'Emerald', hex: '#059669', hover: '#047857', press: '#065f46', soft: '#ecfdf5' },
    { id: 'amber', name: 'Amber', hex: '#d97706', hover: '#b45309', press: '#92400e', soft: '#fffbeb' },
    { id: 'rose', name: 'Rose', hex: '#e11d48', hover: '#be123c', press: '#9f1239', soft: '#fff1f2' },
  ];

  // Background presets. kind hints; mode = text palette (light/dark); anim = slow motion;
  // pattern = overlay texture (dots/grid/mesh/diagonal) layered over the base.
  var BACKGROUNDS = [
    // Solids — dark → light ramp
    { id: 'light', name: 'Light', group: 'Solid', mode: 'light', css: '#f8fafc' },
    { id: 'paper', name: 'Warm paper', group: 'Solid', mode: 'light', css: '#f6f4ef' },
    { id: 'mist', name: 'Cool mist', group: 'Solid', mode: 'light', css: '#eef2f7' },
    { id: 'slate', name: 'Slate', group: 'Solid', mode: 'dark', css: '#0b1220' },
    { id: 'midnight', name: 'Midnight navy', group: 'Solid', mode: 'dark', css: '#060f20' },
    { id: 'charcoal', name: 'Charcoal', group: 'Solid', mode: 'dark', css: '#131417' },

    // 2-colour gradients — light + dark
    { id: 'g2-dawn', name: 'Dawn', group: '2-colour gradient', mode: 'light', css: 'linear-gradient(150deg,#eef2f7,#e6fbff)' },
    { id: 'g2-sky', name: 'Sky', group: '2-colour gradient', mode: 'light', css: 'linear-gradient(150deg,#eff6ff,#f5f3ff)' },
    { id: 'g2-deep', name: 'Deep sea', group: '2-colour gradient', mode: 'dark', css: 'linear-gradient(150deg,#0b2545,#020617)' },
    { id: 'g2-plum', name: 'Plum night', group: '2-colour gradient', mode: 'dark', css: 'linear-gradient(150deg,#1e1b4b,#0b1220)' },
    // 3-colour gradients — light + dark
    { id: 'g3-aurora', name: 'Aurora', group: '3-colour gradient', mode: 'light', css: 'linear-gradient(150deg,#e6fbff,#eef2f7,#f5f3ff)' },
    { id: 'g3-sunrise', name: 'Sunrise', group: '3-colour gradient', mode: 'light', css: 'linear-gradient(150deg,#fffbeb,#fff1f2,#f5f3ff)' },
    { id: 'g3-nebula', name: 'Nebula', group: '3-colour gradient', mode: 'dark', css: 'linear-gradient(150deg,#0b2545,#1e1b4b,#020617)' },
    { id: 'g3-ember', name: 'Ember', group: '3-colour gradient', mode: 'dark', css: 'linear-gradient(150deg,#1a0f0a,#3b1d12,#0b1220)' },
    // 4-colour gradients — light + dark
    { id: 'g4-prism', name: 'Prism', group: '4-colour gradient', mode: 'light', css: 'linear-gradient(150deg,#e6fbff,#eef2f7,#f5f3ff,#fff1f2)' },
    { id: 'g4-meadow', name: 'Meadow', group: '4-colour gradient', mode: 'light', css: 'linear-gradient(150deg,#ecfdf5,#e6fbff,#eff6ff,#f5f3ff)' },
    { id: 'g4-eclipse', name: 'Eclipse', group: '4-colour gradient', mode: 'dark', css: 'linear-gradient(150deg,#0b2545,#0f3d3e,#1e1b4b,#020617)' },
    { id: 'g4-obsidian', name: 'Obsidian', group: '4-colour gradient', mode: 'dark', css: 'linear-gradient(150deg,#111827,#1e1b4b,#0b2545,#020617)' },

    // Animated gradients — each in BOTH light and dark
    { id: 'a2-tide', name: 'Tide · 2 (light)', group: 'Animated gradient', mode: 'light', anim: true, css: 'linear-gradient(120deg,#e6fbff,#eef2f7)' },
    { id: 'a2-tide-d', name: 'Tide · 2 (dark)', group: 'Animated gradient', mode: 'dark', anim: true, css: 'linear-gradient(120deg,#0b2545,#020617)' },
    { id: 'a3-flow', name: 'Flow · 3 (light)', group: 'Animated gradient', mode: 'light', anim: true, css: 'linear-gradient(120deg,#e6fbff,#f5f3ff,#eef2f7)' },
    { id: 'a3-flow-d', name: 'Flow · 3 (dark)', group: 'Animated gradient', mode: 'dark', anim: true, css: 'linear-gradient(120deg,#0b2545,#1e1b4b,#020617)' },
    { id: 'a4-spectrum', name: 'Spectrum · 4 (light)', group: 'Animated gradient', mode: 'light', anim: true, css: 'linear-gradient(120deg,#e6fbff,#f5f3ff,#fff1f2,#eef2f7)' },
    { id: 'a4-galaxy-d', name: 'Galaxy · 4 (dark)', group: 'Animated gradient', mode: 'dark', anim: true, css: 'linear-gradient(120deg,#0b2545,#0f3d3e,#1e1b4b,#020617)' },

    // Patterned — light + dark (base colour + texture overlay)
    { id: 'p-dots', name: 'Dots (light)', group: 'Patterned', mode: 'light', base: '#f8fafc', pattern: 'dots' },
    { id: 'p-dots-d', name: 'Dots (dark)', group: 'Patterned', mode: 'dark', base: '#0b1220', pattern: 'dots' },
    { id: 'p-grid', name: 'Grid (light)', group: 'Patterned', mode: 'light', base: '#f6f8fb', pattern: 'grid' },
    { id: 'p-grid-d', name: 'Grid (dark)', group: 'Patterned', mode: 'dark', base: '#060f20', pattern: 'grid' },
    { id: 'p-diag', name: 'Diagonal (light)', group: 'Patterned', mode: 'light', base: '#f5f3ff', pattern: 'diagonal' },
    { id: 'p-diag-d', name: 'Diagonal (dark)', group: 'Patterned', mode: 'dark', base: '#131417', pattern: 'diagonal' },

    // Premium — curated multi-layer (radial glows / mesh), light + dark
    { id: 'pr-lumen', name: 'Lumen', group: 'Premium', mode: 'light', premium: 'radial-gradient(circle at 15% 12%,#e6fbff,transparent 45%),radial-gradient(circle at 85% 20%,#f5f3ff,transparent 40%),radial-gradient(circle at 50% 100%,#fff1f2,transparent 55%),#f8fafc' },
    { id: 'pr-halo', name: 'Halo', group: 'Premium', mode: 'light', premium: 'radial-gradient(circle at 80% 0%,#dbeafe,transparent 50%),radial-gradient(circle at 0% 80%,#ecfdf5,transparent 50%),#f6f8fb' },
    { id: 'pr-aurora', name: 'Aurora Pro', group: 'Premium', mode: 'dark', anim: true, css: 'linear-gradient(120deg,#0b2545,#0f766e,#1e1b4b,#020617)' },
    { id: 'pr-cosmos', name: 'Cosmos Pro', group: 'Premium', mode: 'dark', premium: 'radial-gradient(circle at 20% 15%,#1e3a8a55,transparent 45%),radial-gradient(circle at 85% 30%,#5b21b655,transparent 40%),radial-gradient(circle at 50% 100%,#0f766e55,transparent 55%),#060f20', pattern: 'dots' },
    { id: 'pr-mesh', name: 'Mesh Noir', group: 'Premium', mode: 'dark', premium: 'radial-gradient(circle at 10% 20%,#0f3d3e,transparent 40%),radial-gradient(circle at 90% 10%,#1e1b4b,transparent 40%),radial-gradient(circle at 60% 90%,#0b2545,transparent 45%),#0b1220' },
  ];

  // Pattern overlays (added on top of a base colour / premium layer)
  var PATTERNS = {
    none: function () { return ''; },
    dots: function (dark) { var c = dark ? 'rgba(148,163,184,.14)' : 'rgba(15,23,42,.09)'; return 'radial-gradient(' + c + ' 1.4px,transparent 1.4px)'; },
    grid: function (dark) { var c = dark ? 'rgba(148,163,184,.10)' : 'rgba(15,23,42,.06)'; return 'linear-gradient(' + c + ' 1px,transparent 1px),linear-gradient(90deg,' + c + ' 1px,transparent 1px)'; },
    mesh: function (dark) { var c = dark ? 'rgba(148,163,184,.08)' : 'rgba(15,23,42,.05)'; return 'linear-gradient(' + c + ' 1px,transparent 1px),linear-gradient(90deg,' + c + ' 1px,transparent 1px)'; },
    diagonal: function (dark) { var c = dark ? 'rgba(148,163,184,.08)' : 'rgba(15,23,42,.05)'; return 'repeating-linear-gradient(45deg,' + c + ' 0 1px,transparent 1px 14px)'; },
  };
  var PATTERN_SIZE = { dots: '22px 22px', grid: '120px 120px,120px 120px', mesh: '28px 28px,28px 28px', diagonal: 'auto' };
  function patternLayer(name, dark) { var f = PATTERNS[name]; return f ? f(dark) : ''; }

  var DEFAULT_CUSTOM = { colors: ['#00b5d8', '#7c3aed'], animated: false, mode: 'dark', angle: 150, pattern: 'none' };

  function read() { try { return JSON.parse(localStorage.getItem(KEY)) || {}; } catch (e) { return {}; } }
  function write(s) { try { localStorage.setItem(KEY, JSON.stringify(s)); } catch (e) {} }
  var state = Object.assign({ mode: 'light', accent: 'cyan', bg: 'light', custom: DEFAULT_CUSTOM }, read());
  if (!state.custom) state.custom = DEFAULT_CUSTOM;
  if (!state.custom.pattern) state.custom.pattern = 'none';

  function accentById(id) { for (var i = 0; i < ACCENTS.length; i++) if (ACCENTS[i].id === id) return ACCENTS[i]; return ACCENTS[0]; }
  function bgById(id) { for (var i = 0; i < BACKGROUNDS.length; i++) if (BACKGROUNDS[i].id === id) return BACKGROUNDS[i]; return null; }

  /* Compose a full CSS background (image list + sizes) for a preset or custom config.
   * Layers order: pattern (top) , base gradient/solid (bottom). Returns {image, size, anim, mode}. */
  function composeBg(cfg) {
    var dark = cfg.mode === 'dark';
    var layers = [], sizes = [];
    if (cfg.pattern && cfg.pattern !== 'none') { layers.push(patternLayer(cfg.pattern, dark)); sizes.push(PATTERN_SIZE[cfg.pattern] || 'auto'); }
    var baseImg, baseSize = 'auto';
    if (cfg.premium) { baseImg = cfg.premium; }
    else if (cfg.css) { baseImg = cfg.css; if (cfg.anim) baseSize = '300% 300%'; }
    else if (cfg.base) { baseImg = 'linear-gradient(' + cfg.base + ',' + cfg.base + ')'; }
    else { baseImg = 'linear-gradient(#f8fafc,#f8fafc)'; }
    if (baseImg.charAt(0) === '#') baseImg = 'linear-gradient(' + baseImg + ',' + baseImg + ')';
    layers.push(baseImg); sizes.push(baseSize);
    return { image: layers.join(','), size: sizes.join(','), anim: !!cfg.anim, mode: cfg.mode };
  }
  function customCfg() {
    var c = state.custom;
    return { css: 'linear-gradient(' + (c.angle || 150) + 'deg,' + c.colors.join(',') + ')', mode: c.mode, anim: !!c.animated, pattern: c.pattern || 'none' };
  }
  function resolvedCfg() {
    if (state.bg === 'custom') return customCfg();
    return bgById(state.bg) || bgById('light');
  }
  // Build a plain CSS `background` shorthand for previews
  function previewCss(cfg) { var c = composeBg(cfg); return c.image; }

  function darkVars() {
    return '--surface-card:#131c2e;--surface-raised:#1a2438;--surface-sunken:#0e1626;--surface-chrome:#060f20;'
      + '--text-strong:#f1f5f9;--text-body:#cbd5e1;--text-muted:#94a3b8;--text-faint:#64748b;'
      + '--border-subtle:#243149;--border-card:#243149;--border-strong:#334155;--divider:#1e293b;'
      + '--ml-slate-50:#0b1220;--ml-slate-100:#0e1626;--ml-slate-200:#243149;--ml-white:#131c2e;'
      + '--ml-well-blue:#132033;--ml-well-amber:#2a1f12;--ml-well-green:#0f2318;'
      + '--shadow-xs:0 1px 2px rgba(0,0,0,.4);--shadow-sm:0 1px 3px rgba(0,0,0,.45);--shadow-md:0 4px 12px rgba(0,0,0,.5);--shadow-lg:0 12px 28px rgba(0,0,0,.55);';
  }

  function apply() {
    var a = accentById(state.accent);
    var cfg = resolvedCfg();
    var comp = composeBg(cfg);
    var dark = (state.mode === 'dark') || (cfg && cfg.mode === 'dark' && state.mode !== 'light');
    var css = ':root{--accent:' + a.hex + ';--accent-hover:' + a.hover + ';--accent-press:' + a.press + ';--accent-soft:' + a.soft + ';--focus-ring:' + a.hex + ';--border-accent:' + a.hex + '66;--ml-well-cyan:' + a.soft + ';}';
    if (dark) css += ':root{' + darkVars() + '}';
    var isFlat = comp.image.indexOf(',') === -1 && /linear-gradient\((#[0-9a-fA-F]{3,8}),\1\)/.test(comp.image.replace(/\s/g, ''));
    css += ':root{--surface-app:' + (isFlat ? comp.image : (dark ? '#0b1220' : '#f8fafc')) + ';}';
    css += 'body.ml-has-bg{background-image:' + comp.image + ' !important;background-size:' + comp.size + ' !important;background-color:' + (dark ? '#0b1220' : '#f8fafc') + ';'
      + (comp.anim ? 'animation:mlBgFlow 24s ease infinite;' : 'background-attachment:fixed;') + '}';
    css += '@keyframes mlBgFlow{0%{background-position:0% 50%}50%{background-position:100% 50%}100%{background-position:0% 50%}}';
    document.documentElement.style.colorScheme = dark ? 'dark' : 'light';
    document.body.classList.add('ml-has-bg');
    var el = document.getElementById('ml-theme-vars');
    if (!el) { el = document.createElement('style'); el.id = 'ml-theme-vars'; document.head.appendChild(el); }
    el.textContent = css;
  }

  function setState(patch) { state = Object.assign({}, state, patch); write(state); apply(); render(); rerenderSettings(); }
  function setCustom(patch) { state.custom = Object.assign({}, state.custom, patch); state.bg = 'custom'; write(state); apply(); render(); rerenderSettings(); }

  var ms = "font-family:'Material Symbols Rounded';";
  var panelOpen = false;
  function render() {
    var host = document.getElementById('ml-theme-host');
    if (!host) { host = document.createElement('div'); host.id = 'ml-theme-host'; host.style.cssText = 'position:fixed;left:20px;bottom:20px;z-index:70;font-family:var(--font-sans),sans-serif'; document.body.appendChild(host); }
    var a = accentById(state.accent);
    var btn = '<button id="ml-theme-btn" title="Theme" style="width:48px;height:48px;border-radius:14px;border:1px solid var(--border-card);background:var(--surface-card);box-shadow:var(--shadow-md);cursor:pointer;display:flex;align-items:center;justify-content:center"><span class="material-symbols-rounded" style="' + ms + 'font-size:24px;color:' + a.hex + '">palette</span></button>';
    var panel = '';
    if (panelOpen) {
      var modeBtn = function (m, label, icon) { var sel = state.mode === m; return '<button data-mode="' + m + '" style="flex:1;display:flex;align-items:center;justify-content:center;gap:6px;padding:9px;border-radius:10px;cursor:pointer;font-family:inherit;font-size:13px;font-weight:700;border:1px solid ' + (sel ? 'var(--accent)' : 'var(--border-strong)') + ';background:' + (sel ? 'var(--accent)' : 'var(--surface-card)') + ';color:' + (sel ? '#fff' : 'var(--text-body)') + '"><span class="material-symbols-rounded" style="' + ms + 'font-size:18px">' + icon + '</span>' + label + '</button>'; };
      var sw = ACCENTS.map(function (c) { var sel = c.id === state.accent; return '<button data-accent="' + c.id + '" title="' + c.name + '" style="width:32px;height:32px;border-radius:9px;cursor:pointer;background:' + c.hex + ';border:2.5px solid ' + (sel ? 'var(--text-strong)' : 'transparent') + '"></button>'; }).join('');
      panel = '<div style="position:absolute;left:0;bottom:60px;width:290px;background:var(--surface-card);border:1px solid var(--border-card);border-radius:16px;box-shadow:var(--shadow-lg);padding:18px">'
        + '<div style="display:flex;align-items:center;gap:8px;margin-bottom:14px"><span class="material-symbols-rounded" style="' + ms + 'font-size:20px;color:var(--accent)">palette</span><span style="font-size:15px;font-weight:800;color:var(--text-strong);flex:1">Appearance</span><button id="ml-theme-close" style="border:none;background:transparent;cursor:pointer;color:var(--text-muted);display:flex"><span class="material-symbols-rounded" style="' + ms + 'font-size:20px">close</span></button></div>'
        + '<div style="font-size:11px;font-weight:700;letter-spacing:.06em;text-transform:uppercase;color:var(--text-faint);margin-bottom:8px">Mode</div>'
        + '<div style="display:flex;gap:8px;margin-bottom:16px">' + modeBtn('light', 'Light', 'light_mode') + modeBtn('dark', 'Dark', 'dark_mode') + '</div>'
        + '<div style="font-size:11px;font-weight:700;letter-spacing:.06em;text-transform:uppercase;color:var(--text-faint);margin-bottom:8px">Accent</div>'
        + '<div style="display:flex;gap:8px;flex-wrap:wrap;margin-bottom:16px">' + sw + '</div>'
        + '<button id="ml-open-settings" style="width:100%;display:flex;align-items:center;justify-content:center;gap:7px;padding:10px;border-radius:10px;border:1px solid var(--border-strong);background:var(--surface-app);color:var(--accent);font-family:inherit;font-size:13px;font-weight:700;cursor:pointer"><span class="material-symbols-rounded" style="' + ms + 'font-size:18px">tune</span>More themes & backgrounds</button>'
        + '<div style="font-size:11.5px;color:var(--text-muted);margin-top:10px;display:flex;align-items:center;gap:6px"><span class="material-symbols-rounded" style="' + ms + 'font-size:15px">person</span>Saved to your account only</div>'
        + '</div>';
    }
    host.innerHTML = panel + btn;
    document.getElementById('ml-theme-btn').onclick = function () { panelOpen = !panelOpen; render(); };
    if (panelOpen) {
      document.getElementById('ml-theme-close').onclick = function () { panelOpen = false; render(); };
      host.querySelectorAll('[data-accent]').forEach(function (b) { b.onclick = function () { setState({ accent: b.getAttribute('data-accent') }); }; });
      host.querySelectorAll('[data-mode]').forEach(function (b) { b.onclick = function () { setState({ mode: b.getAttribute('data-mode') }); }; });
      var os = document.getElementById('ml-open-settings');
      os.onclick = function () { if (window.__mlSettingsNav) { window.__mlSettingsNav(); } else { window.location.href = (location.pathname.indexOf('/ui_kits/') > -1 ? '../settings/index.html' : 'ui_kits/settings/index.html'); } };
    }
  }

  /* ---- Full settings renderer (used by the Settings page → Themes category) ---- */
  var settingsEl = null;
  function rerenderSettings() { if (settingsEl) renderSettings(settingsEl); }
  function swatchPreview(css, anim) { return '<span style="display:block;width:100%;height:52px;border-radius:10px;background-image:' + css + ';background-size:' + (anim ? '300% 300%' : 'auto') + ';' + (anim ? 'animation:mlBgFlow 8s ease infinite;' : '') + 'border:1px solid rgba(0,0,0,.08)"></span>'; }
  function renderSettings(el) {
    settingsEl = el;
    var groups = {};
    BACKGROUNDS.forEach(function (b) { (groups[b.group] = groups[b.group] || []).push(b); });
    var html = '';
    // Mode + accent quick row
    html += '<div style="display:grid;grid-template-columns:1fr 1fr;gap:12px;margin-bottom:24px">';
    html += '<div style="background:var(--surface-card);border:1px solid var(--border-card);border-radius:14px;padding:16px"><div style="font-size:12px;font-weight:700;text-transform:uppercase;letter-spacing:.06em;color:var(--text-faint);margin-bottom:10px">Mode</div><div style="display:flex;gap:8px">'
      + ['light', 'dark'].map(function (m) { var sel = state.mode === m; return '<button data-smode="' + m + '" style="flex:1;padding:10px;border-radius:10px;cursor:pointer;font-family:inherit;font-size:13.5px;font-weight:700;border:1px solid ' + (sel ? 'var(--accent)' : 'var(--border-strong)') + ';background:' + (sel ? 'var(--accent)' : 'var(--surface-card)') + ';color:' + (sel ? '#fff' : 'var(--text-body)') + '">' + (m[0].toUpperCase() + m.slice(1)) + '</button>'; }).join('') + '</div></div>';
    html += '<div style="background:var(--surface-card);border:1px solid var(--border-card);border-radius:14px;padding:16px"><div style="font-size:12px;font-weight:700;text-transform:uppercase;letter-spacing:.06em;color:var(--text-faint);margin-bottom:10px">Accent</div><div style="display:flex;gap:8px;flex-wrap:wrap">'
      + ACCENTS.map(function (c) { var sel = c.id === state.accent; return '<button data-saccent="' + c.id + '" title="' + c.name + '" style="width:32px;height:32px;border-radius:9px;cursor:pointer;background:' + c.hex + ';border:2.5px solid ' + (sel ? 'var(--text-strong)' : 'transparent') + '"></button>'; }).join('') + '</div></div>';
    html += '</div>';
    // Background groups
    Object.keys(groups).forEach(function (g) {
      html += '<div style="font-size:13px;font-weight:800;color:var(--text-strong);margin:18px 0 12px">' + g + ' backgrounds</div>';
      html += '<div style="display:grid;grid-template-columns:repeat(auto-fill,minmax(150px,1fr));gap:12px">';
      groups[g].forEach(function (b) {
        var sel = state.bg === b.id;
        html += '<button data-sbg="' + b.id + '" style="text-align:left;padding:8px;border-radius:14px;cursor:pointer;background:var(--surface-card);border:2px solid ' + (sel ? 'var(--accent)' : 'var(--border-card)') + '">'
          + swatchPreview(previewCss(b), b.anim)
          + '<div style="display:flex;align-items:center;gap:5px;margin-top:8px;padding:0 2px"><span style="font-size:12.5px;font-weight:600;color:var(--text-strong);flex:1">' + b.name + '</span>' + (b.anim ? '<span class="material-symbols-rounded" style="' + ms + 'font-size:15px;color:var(--accent)">motion_photos_on</span>' : '') + (sel ? '<span class="material-symbols-rounded" style="' + ms + 'font-size:16px;color:var(--accent)">check_circle</span>' : '') + '</div></button>';
      });
      html += '</div>';
    });
    // Custom builder
    var c = state.custom;
    html += '<div style="font-size:13px;font-weight:800;color:var(--text-strong);margin:22px 0 12px">Customizable gradient</div>';
    html += '<div style="background:var(--surface-card);border:2px solid ' + (state.bg === 'custom' ? 'var(--accent)' : 'var(--border-card)') + ';border-radius:16px;padding:18px">';
    html += swatchPreview(previewCss(customCfg()), c.animated);
    html += '<div style="font-size:12px;font-weight:700;text-transform:uppercase;letter-spacing:.06em;color:var(--text-faint);margin:14px 0 8px">Colours (2–4)</div>';
    html += '<div style="display:flex;gap:10px;flex-wrap:wrap;align-items:center">';
    c.colors.forEach(function (col, i) { html += '<input type="color" data-ccol="' + i + '" value="' + col + '" style="width:44px;height:44px;border:1px solid var(--border-strong);border-radius:10px;cursor:pointer;background:none;padding:0">'; });
    if (c.colors.length < 4) html += '<button id="ml-add-col" style="width:44px;height:44px;border-radius:10px;border:1px dashed var(--border-strong);background:var(--surface-app);cursor:pointer;color:var(--accent)"><span class="material-symbols-rounded" style="' + ms + 'font-size:20px">add</span></button>';
    if (c.colors.length > 2) html += '<button id="ml-rm-col" style="width:44px;height:44px;border-radius:10px;border:1px solid var(--border-strong);background:var(--surface-app);cursor:pointer;color:var(--text-muted)"><span class="material-symbols-rounded" style="' + ms + 'font-size:20px">remove</span></button>';
    html += '</div>';
    html += '<div style="display:flex;gap:20px;align-items:center;margin-top:16px;flex-wrap:wrap">';
    html += '<label style="display:flex;align-items:center;gap:8px;font-size:13.5px;color:var(--text-body);cursor:pointer"><input type="checkbox" id="ml-anim" ' + (c.animated ? 'checked' : '') + ' style="width:18px;height:18px;accent-color:var(--accent)">Slow-moving animation</label>';
    html += '<label style="display:flex;align-items:center;gap:8px;font-size:13.5px;color:var(--text-body)">Base text <select id="ml-cmode" style="padding:7px 10px;border-radius:8px;border:1px solid var(--border-strong);background:var(--surface-card);color:var(--text-body);font-family:inherit;font-size:13px"><option value="light"' + (c.mode === 'light' ? ' selected' : '') + '>Light</option><option value="dark"' + (c.mode === 'dark' ? ' selected' : '') + '>Dark</option></select></label>';
    html += '<label style="display:flex;align-items:center;gap:8px;font-size:13.5px;color:var(--text-body)">Angle <input type="range" id="ml-angle" min="0" max="360" value="' + (c.angle || 150) + '" style="accent-color:var(--accent)"></label>';
    html += '</div>';
    html += '<div style="font-size:12px;font-weight:700;text-transform:uppercase;letter-spacing:.06em;color:var(--text-faint);margin:16px 0 8px">Pattern overlay (mix & match)</div>';
    html += '<div style="display:flex;gap:8px;flex-wrap:wrap">' + ['none', 'dots', 'grid', 'mesh', 'diagonal'].map(function (pn) { var sel = (c.pattern || 'none') === pn; return '<button data-cpat="' + pn + '" style="padding:8px 14px;border-radius:9px;cursor:pointer;font-family:inherit;font-size:12.5px;font-weight:700;text-transform:capitalize;border:1px solid ' + (sel ? 'var(--accent)' : 'var(--border-strong)') + ';background:' + (sel ? 'var(--accent)' : 'var(--surface-card)') + ';color:' + (sel ? '#fff' : 'var(--text-body)') + '">' + pn + '</button>'; }).join('') + '</div>';
    html += '<button id="ml-apply-custom" style="margin-top:16px;padding:10px 18px;border-radius:10px;border:none;background:var(--accent);color:#fff;font-family:inherit;font-size:13.5px;font-weight:700;cursor:pointer">Use custom background</button>';
    html += '</div>';
    html += '<div style="margin-top:20px;display:flex;align-items:center;gap:8px;padding:12px 14px;background:var(--accent-soft,#e6fbff);border-radius:10px"><span class="material-symbols-rounded" style="' + ms + 'font-size:18px;color:var(--accent)">info</span><span style="font-size:12.5px;color:var(--text-body)">All choices are saved to your account only and never change how the app looks for anyone else. If a background makes text hard to read, pick a Solid or switch Mode.</span></div>';
    el.innerHTML = html;
    // wire
    el.querySelectorAll('[data-smode]').forEach(function (b) { b.onclick = function () { setState({ mode: b.getAttribute('data-smode') }); }; });
    el.querySelectorAll('[data-saccent]').forEach(function (b) { b.onclick = function () { setState({ accent: b.getAttribute('data-saccent') }); }; });
    el.querySelectorAll('[data-sbg]').forEach(function (b) { b.onclick = function () { var bg = bgById(b.getAttribute('data-sbg')); setState({ bg: b.getAttribute('data-sbg'), mode: bg.mode }); }; });
    el.querySelectorAll('[data-ccol]').forEach(function (inp) { inp.oninput = function () { var cols = state.custom.colors.slice(); cols[+inp.getAttribute('data-ccol')] = inp.value; setCustom({ colors: cols }); }; });
    var add = document.getElementById('ml-add-col'); if (add) add.onclick = function () { var cols = state.custom.colors.slice(); cols.push('#' + Math.floor(Math.random() * 16777215).toString(16).padStart(6, '0')); setCustom({ colors: cols }); };
    var rm = document.getElementById('ml-rm-col'); if (rm) rm.onclick = function () { var cols = state.custom.colors.slice(); cols.pop(); setCustom({ colors: cols }); };
    var anim = document.getElementById('ml-anim'); if (anim) anim.onchange = function () { setCustom({ animated: anim.checked }); };
    var cm = document.getElementById('ml-cmode'); if (cm) cm.onchange = function () { setCustom({ mode: cm.value }); };
    var ang = document.getElementById('ml-angle'); if (ang) ang.oninput = function () { setCustom({ angle: +ang.value }); };
    var ap = document.getElementById('ml-apply-custom'); if (ap) ap.onclick = function () { setState({ bg: 'custom' }); };
    el.querySelectorAll('[data-cpat]').forEach(function (b) { b.onclick = function () { setCustom({ pattern: b.getAttribute('data-cpat') }); }; });
  }

  function boot() { apply(); render(); }
  if (document.readyState === 'loading') document.addEventListener('DOMContentLoaded', boot); else boot();
  window.MLTheme = { setState: setState, get: function () { return state; }, renderSettings: renderSettings, BACKGROUNDS: BACKGROUNDS, ACCENTS: ACCENTS };
})();
