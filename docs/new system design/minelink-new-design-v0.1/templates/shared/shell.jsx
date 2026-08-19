/* MineLink UI Kit — shared portal chrome.
 * Composes the design-system primitives (window.MineLinkDesignSystem_9acfde)
 * into the navy-sidebar + app-bar shell used by every portal. Loaded as a
 * text/babel script; exports onto window for the per-screen kit files. */

const DS = window.MineLinkDesignSystem_9acfde;
const { Icon, Avatar, StatusBadge, Button, Icon3D, ICON3D_ALIASES, ICON3D_NAMES } = DS;
// alias OR direct Icon3D name → concept (null when no 3D equivalent)
const resolve3D = (name) => { if (!name || window.MLIconMode === 'fallback') return null; return ICON3D_ALIASES[name] || (ICON3D_NAMES.includes(name) ? name : null); };

/* ---------- Sidebar ---------- */
const SIDE_ACTIVE = 'linear-gradient(110deg,#2f6bef,#1b47c7)';

function Sidebar({ brand, brandSubtitle, sectionLabel, items, active, onSelect, user,
  collapsed, onToggle, utilityNav, settingsNav, onLogout, searchable = true }) {
  const w = collapsed ? 78 : 274;
  const groupHasActive = (it) => it.children && it.children.some((c) => c.key === active);
  const allGroups = [...(items || []), ...(settingsNav ? [{ key: '__settings', children: settingsNav }] : [])];
  const [openGroups, setOpenGroups] = React.useState(() => {
    const o = {}; allGroups.forEach((it) => { if (it.children) o[it.key] = groupHasActive(it); }); return o;
  });
  React.useEffect(() => { setOpenGroups((prev) => { const n = { ...prev }; allGroups.forEach((it) => { if (it.children && groupHasActive(it)) n[it.key] = true; }); return n; }); }, [active]);

  const tileStyle = (sel, indent) => ({
    display: 'flex', alignItems: 'center', gap: 12, width: '100%', textAlign: 'left',
    padding: collapsed ? '11px 0' : (indent ? '9px 12px 9px 42px' : '10px 12px'),
    justifyContent: collapsed ? 'center' : 'flex-start',
    borderRadius: 12, border: sel && !indent ? '1px solid rgba(106,184,255,.4)' : '1px solid transparent', cursor: 'pointer',
    background: sel ? (indent ? 'rgba(106,184,255,.07)' : 'rgba(106,184,255,.1)') : 'transparent',
    color: sel ? '#eaf2ff' : 'rgba(226,232,240,.82)',
    boxShadow: sel && !indent ? 'inset 3px 0 0 #6ab8ff' : 'none',
    fontFamily: 'var(--font-sans)', fontSize: indent ? 13.5 : 14.5, fontWeight: sel ? 700 : 500,
    transition: 'background .16s, color .16s, border-color .16s',
  });
  const hoverOn = (e, sel) => { if (!sel) e.currentTarget.style.background = 'rgba(148,163,184,.10)'; };
  const hoverOff = (e, sel) => { if (!sel) e.currentTarget.style.background = 'transparent'; };
  const Badge = ({ v, tone }) => v ? <span style={{ background: tone === 'red' ? 'var(--ml-red-600)' : 'var(--accent)', color: tone === 'red' ? '#fff' : '#04222b', fontSize: 11, fontWeight: 800, borderRadius: 999, padding: '1px 7px', lineHeight: 1.5 }}>{v}</span> : null;

  const renderGroup = (it, keyPrefix) => {
    const open = collapsed ? false : !!openGroups[it.key];
    const parentSel = groupHasActive(it);
    const totalBadge = it.badge || it.children.reduce((a, c) => a + (parseInt(c.badge, 10) || 0), 0) || null;
    return (
      <React.Fragment key={keyPrefix + it.key}>
        <button type="button" onClick={() => collapsed ? onSelect(it.children[0].key) : setOpenGroups((o) => ({ ...o, [it.key]: !o[it.key] }))}
          title={collapsed ? it.label : undefined} style={{ ...tileStyle(parentSel && !open, false), position: 'relative' }}
          onMouseEnter={(e) => hoverOn(e, parentSel && !open)} onMouseLeave={(e) => hoverOff(e, parentSel && !open)}>
          <Icon name={it.icon} size={21} color={parentSel ? '#fff' : 'rgba(226,232,240,.8)'} fill={parentSel && !open ? 1 : 0} />
          {!collapsed && <span style={{ flex: 1 }}>{it.label}</span>}
          {!collapsed && totalBadge ? <Badge v={totalBadge} /> : null}
          {collapsed && totalBadge ? <span style={{ position: 'absolute', top: 7, right: 14, width: 8, height: 8, borderRadius: 999, background: 'var(--accent)', border: '2px solid #0b192e' }} /> : null}
          {!collapsed && <Icon name={open ? 'expand_less' : 'expand_more'} size={18} color="rgba(226,232,240,.55)" />}
        </button>
        {open && it.children.map((c) => {
          const sel = c.key === active;
          return (
            <button key={c.key} type="button" onClick={() => c.href ? (window.location.href = c.href) : onSelect(c.key)} title={collapsed ? c.label : undefined}
              style={tileStyle(sel, true)} onMouseEnter={(e) => hoverOn(e, sel)} onMouseLeave={(e) => hoverOff(e, sel)}>
              <Icon name={c.icon || 'chevron_right'} size={18} color={sel ? '#fff' : 'rgba(226,232,240,.66)'} fill={sel ? 1 : 0} />
              {!collapsed && <span style={{ flex: 1 }}>{c.label}</span>}
              {!collapsed && c.badge ? <Badge v={c.badge} /> : null}
            </button>
          );
        })}
      </React.Fragment>
    );
  };
  const renderItem = (it, keyPrefix = '') => {
    if (it.children) return renderGroup(it, keyPrefix);
    const sel = it.key === active;
    return (
      <button key={keyPrefix + it.key} type="button" onClick={() => it.href ? (window.location.href = it.href) : onSelect(it.key)}
        title={collapsed ? it.label : undefined} style={{ ...tileStyle(sel, false), position: 'relative' }}
        onMouseEnter={(e) => hoverOn(e, sel)} onMouseLeave={(e) => hoverOff(e, sel)}>
        <Icon name={it.icon} size={21} color={sel ? '#fff' : 'rgba(226,232,240,.82)'} fill={sel ? 1 : 0} />
        {!collapsed && <span style={{ flex: 1 }}>{it.label}</span>}
        {!collapsed && it.badge ? <Badge v={it.badge} tone={it.badgeTone} /> : null}
        {collapsed && it.badge ? <span style={{ position: 'absolute', top: 7, right: 14, width: 8, height: 8, borderRadius: 999, background: it.badgeTone === 'red' ? 'var(--ml-red-600)' : 'var(--accent)', border: '2px solid #0b192e' }} /> : null}
      </button>
    );
  };

  const first = items && items.length ? items[0] : null;
  const rest = items ? items.slice(1) : [];

  return (
    <aside style={{
      width: w, flexShrink: 0, background: 'linear-gradient(168deg,#0c1c34,#050b18)',
      display: 'flex', flexDirection: 'column', transition: 'width .26s var(--ease-out-cubic)',
      color: 'var(--text-on-chrome)', position: 'relative', borderRight: '1px solid rgba(148,163,184,.08)',
    }}>
      {/* Brand */}
      <div style={{ position: 'relative', padding: collapsed ? '20px 8px 12px' : '22px 16px 14px', textAlign: 'center' }}>
        {!collapsed ? (
          <React.Fragment>
            <div style={{ fontFamily: 'var(--font-serif)', fontSize: 22, fontWeight: 600, letterSpacing: '.005em', lineHeight: 1.1, backgroundImage: 'linear-gradient(90deg,#7fe3f2,#5aa2ff)', WebkitBackgroundClip: 'text', backgroundClip: 'text', color: 'transparent' }}>{brand}</div>
            {brandSubtitle && (() => { const p = String(brandSubtitle).split(' '); const head = p[0]; const tail = p.slice(1).join(' '); return (
              <div style={{ fontSize: 10.5, fontWeight: 600, letterSpacing: '.14em', textTransform: 'uppercase', marginTop: 4 }}><span style={{ color: '#eaf2ff' }}>{head}</span>{tail ? <span style={{ color: 'rgba(148,178,214,.55)' }}> {tail}</span> : null}</div>
            ); })()}
            <button type="button" onClick={onToggle} title="Collapse" style={{ position: 'absolute', top: 18, right: 14, width: 26, height: 26, borderRadius: 8, border: '1px solid rgba(148,163,184,.2)', background: 'rgba(148,163,184,.06)', color: 'rgba(226,232,240,.7)', cursor: 'pointer', display: 'flex', alignItems: 'center', justifyContent: 'center' }}>
              <Icon name="chevron_left" size={16} />
            </button>
          </React.Fragment>
        ) : (
          <div style={{ display: 'flex', flexDirection: 'column', alignItems: 'center', gap: 12 }}>
            <button type="button" onClick={onToggle} title="Expand" style={{ width: 26, height: 26, borderRadius: 8, border: '1px solid rgba(148,163,184,.2)', background: 'rgba(148,163,184,.06)', color: 'rgba(226,232,240,.7)', cursor: 'pointer', display: 'flex', alignItems: 'center', justifyContent: 'center' }}>
              <Icon name="chevron_right" size={16} />
            </button>
            <div style={{ fontFamily: 'var(--font-serif)', fontSize: 24, fontWeight: 600, lineHeight: 1, backgroundImage: 'linear-gradient(90deg,#7fe3f2,#5aa2ff)', WebkitBackgroundClip: 'text', backgroundClip: 'text', color: 'transparent' }}>{String(brand).charAt(0)}</div>
          </div>
        )}
      </div>

      <nav style={{ flex: 1, overflowY: 'auto', padding: '6px 10px 10px', display: 'flex', flexDirection: 'column', gap: 3 }}>
        {first && renderItem(first, 'f-')}

        {/* Search */}
        {searchable && !collapsed && (
          <div style={{ position: 'relative', margin: '8px 2px 10px' }}>
            <span style={{ position: 'absolute', left: 11, top: '50%', transform: 'translateY(-50%)', display: 'flex', pointerEvents: 'none' }}><Icon name="search" size={16} color="#657795" /></span>
            <input className="ml-sidenav-search" placeholder="Search..." style={{ width: '100%', height: 36, boxSizing: 'border-box', padding: '0 12px 0 34px', background: '#080f1c', border: '1px solid rgba(140,180,240,.12)', borderRadius: 10, color: '#c8d5ec', fontFamily: 'var(--font-sans)', fontSize: 12.5, outline: 'none' }}
              onFocus={(e) => { e.target.style.borderColor = '#6ab8ff'; }}
              onBlur={(e) => { e.target.style.borderColor = 'rgba(140,180,240,.12)'; }} />
          </div>
        )}
        {searchable && !collapsed && <div style={{ height: 1, background: 'rgba(148,163,184,.1)', margin: '0 2px 10px' }} />}

        {rest.map((it) => renderItem(it, 'n-'))}

        <div style={{ flex: 1, minHeight: 8 }} />

        {/* Utility group */}
        <div style={{ borderTop: '1px solid rgba(148,163,184,.12)', margin: collapsed ? '6px 4px' : '6px 2px', paddingTop: 8, display: 'flex', flexDirection: 'column', gap: 3 }}>
          {(utilityNav || []).map((it) => renderItem(it, 'u-'))}
          {settingsNav && settingsNav.length
            ? renderGroup({ key: '__settings', label: 'Settings', icon: 'settings', children: settingsNav }, 'u-')
            : null}
        </div>
      </nav>

      {/* Logout + collapse */}
      <div style={{ padding: collapsed ? '4px 10px 8px' : '4px 14px 8px', display: 'flex', flexDirection: 'column', gap: 8 }}>
        <button type="button" onClick={onLogout || (() => { window.location.href = '../auth/index.html'; })} title="Logout"
          style={{ display: 'flex', alignItems: 'center', justifyContent: 'center', gap: 9, padding: collapsed ? '10px 0' : '10px 12px', borderRadius: 11, border: '1px solid rgba(249,115,22,.28)', background: 'rgba(249,115,22,.08)', color: 'var(--ml-orange-500,#f97316)', fontFamily: 'var(--font-sans)', fontSize: 14, fontWeight: 700, cursor: 'pointer' }}
          onMouseEnter={(e) => { e.currentTarget.style.background = 'rgba(249,115,22,.16)'; }} onMouseLeave={(e) => { e.currentTarget.style.background = 'rgba(249,115,22,.08)'; }}>
          <Icon name="logout" size={19} />{!collapsed && <span>Logout</span>}
        </button>
        <button type="button" onClick={onToggle} title="Toggle sidebar"
          style={{ display: 'flex', alignItems: 'center', justifyContent: 'center', gap: 8, padding: collapsed ? '9px 0' : '9px 12px', borderRadius: 11, border: '1px solid rgba(106,184,255,.22)', background: 'rgba(106,184,255,.06)', color: '#9fc4ee', fontFamily: 'var(--font-sans)', fontSize: 13, fontWeight: 600, cursor: 'pointer' }}>
          <Icon name={collapsed ? 'chevron_right' : 'chevron_left'} size={17} />{!collapsed && <span>Collapse</span>}
        </button>
      </div>

      {/* User card */}
      {user && (
        <div style={{ borderTop: '1px solid rgba(148,163,184,.14)', padding: collapsed ? '12px 8px' : '13px 16px', display: 'flex', alignItems: 'center', gap: 10 }}>
          <div style={{ position: 'relative' }}>
            <Avatar name={user.name} size={38} />
            <span style={{ position: 'absolute', right: -1, bottom: -1, width: 11, height: 11, borderRadius: 999, background: 'var(--ml-green-500,#22c55e)', border: '2px solid #0b192e' }} />
          </div>
          {!collapsed && (<div style={{ flex: 1, minWidth: 0 }}>
            <div style={{ color: '#fff', fontWeight: 700, fontSize: 13.5, whiteSpace: 'nowrap', overflow: 'hidden', textOverflow: 'ellipsis' }}>{user.name}</div>
            <div style={{ color: 'rgba(148,178,214,.7)', fontSize: 11.5, whiteSpace: 'nowrap', overflow: 'hidden', textOverflow: 'ellipsis' }}>{user.email || user.role}</div>
          </div>)}
        </div>
      )}
    </aside>
  );
}

/* ---------- App bar ---------- */
function AppBar({ title, subtitle, meta, onHome, actions }) {
  const [theme, setTheme] = React.useState(() => (window.MLPortalTheme ? window.MLPortalTheme.get() : 'light'));
  React.useEffect(() => {
    const h = (e) => setTheme(e.detail);
    window.addEventListener('ml-theme-change', h);
    return () => window.removeEventListener('ml-theme-change', h);
  }, []);
  return (
    <header style={{ display: 'flex', alignItems: 'center', gap: 16, padding: '16px 28px', background: 'var(--surface-card)', borderBottom: '1px solid var(--border-card)', minHeight: 72, boxSizing: 'border-box' }}>
      <button type="button" onClick={onHome} title="Home" style={{ width: 38, height: 38, borderRadius: 11, border: '1px solid #6ab8ff', background: 'transparent', cursor: 'pointer', display: 'flex', alignItems: 'center', justifyContent: 'center', color: '#8fd0ff', flexShrink: 0 }}>
        <Icon name="space_dashboard" size={20} />
      </button>
      <div style={{ flex: 1, minWidth: 0 }}>
        <div style={{ fontSize: 22, fontWeight: 800, color: 'var(--text-strong)', letterSpacing: '-.01em', lineHeight: 1.15, whiteSpace: 'nowrap', overflow: 'hidden', textOverflow: 'ellipsis' }}>{title}</div>
        <div style={{ fontSize: 12, color: '#657795', marginTop: 1, lineHeight: 1.4, whiteSpace: 'nowrap', overflow: 'hidden', textOverflow: 'ellipsis' }}>{subtitle}</div>
      </div>
      {meta && <div style={{ fontSize: 12.5, color: 'var(--text-faint)', textAlign: 'right', marginRight: 4 }}>{meta}</div>}
      {actions}
      <button type="button" title={theme === 'dark' ? 'Switch to light theme' : 'Switch to dark theme'} onClick={() => window.MLPortalTheme && window.MLPortalTheme.toggle()} style={{ width: 42, height: 42, borderRadius: 999, border: 'none', background: 'transparent', cursor: 'pointer', color: 'var(--text-body)', display: 'flex', alignItems: 'center', justifyContent: 'center' }}>
        <Icon name={theme === 'dark' ? 'light_mode' : 'dark_mode'} size={22} />
      </button>
      <button type="button" title="Notifications" style={{ position: 'relative', width: 42, height: 42, borderRadius: 999, border: 'none', background: 'transparent', cursor: 'pointer', color: 'var(--text-body)', display: 'flex', alignItems: 'center', justifyContent: 'center' }}>
        <Icon name="notifications" size={23} />
        <span style={{ position: 'absolute', top: 9, right: 10, width: 8, height: 8, borderRadius: 999, background: 'var(--accent)', border: '2px solid var(--surface-card)' }} />
      </button>
    </header>
  );
}

/* ---------- Floating chat launcher (FAB) — chat has its OWN unread badge,
   separate from the notification bell ---------- */
function ChatFab({ unread = 0, onOpen }) {
  const [hover, setHover] = React.useState(false);
  return (
    <button type="button" onClick={onOpen} title="Messages"
      onMouseEnter={() => setHover(true)} onMouseLeave={() => setHover(false)}
      style={{ position: 'absolute', right: 26, bottom: 26, zIndex: 35, width: 60, height: 60, borderRadius: 20, border: 'none', cursor: 'pointer', background: 'linear-gradient(150deg,#22c2de,#0496b6)', boxShadow: hover ? '0 12px 30px rgba(0,181,216,.5)' : '0 8px 22px rgba(0,181,216,.4)', display: 'flex', alignItems: 'center', justifyContent: 'center', transform: hover ? 'translateY(-2px)' : 'none', transition: 'transform .16s var(--ease-out), box-shadow .16s var(--ease-out)' }}>
      <Icon name="forum" size={27} color="#fff" fill={1} />
      {unread > 0 && (
        <span style={{ position: 'absolute', top: -4, right: -4, minWidth: 22, height: 22, padding: '0 6px', borderRadius: 999, background: 'var(--ml-red-600)', color: '#fff', fontSize: 11.5, fontWeight: 800, display: 'flex', alignItems: 'center', justifyContent: 'center', border: '2.5px solid var(--surface-app)' }}>{unread > 99 ? '99+' : unread}</span>
      )}
    </button>
  );
}

/* ---------- Portal shell ---------- */
function PortalShell({ brand, brandSubtitle, sectionLabel, nav, active, onNav, user, title, subtitle, meta, headerActions, children, chatUnread = 0, onOpenChat, utilityNav, settingsNav, onLogout }) {
  const [collapsed, setCollapsed] = React.useState(false);
  const defaultUtility = utilityNav || [
    { key: 'notifications', label: 'Notifications', icon: 'notifications', badge: '1', badgeTone: 'red', href: '../notifications/index.html' },
  ];
  const defaultSettings = settingsNav || [
    { key: 'set-account', label: 'Account & profile', icon: 'account_circle', href: '../settings/index.html' },
    { key: 'set-notifs', label: 'Notification preferences', icon: 'notifications_active', href: '../settings/index.html' },
    { key: 'set-security', label: 'Security & password', icon: 'lock', href: '../settings/index.html' },
    { key: 'set-theme', label: 'Appearance & theme', icon: 'palette', href: '../settings/index.html' },
  ];
  return (
    <div style={{ display: 'flex', height: '100%', minHeight: 0, background: 'var(--surface-app)', fontFamily: 'var(--font-sans)', position: 'relative' }}>
      <Sidebar brand={brand} brandSubtitle={brandSubtitle} sectionLabel={sectionLabel} items={nav} active={active} onSelect={onNav} user={user} collapsed={collapsed} onToggle={() => setCollapsed((c) => !c)} utilityNav={defaultUtility} settingsNav={defaultSettings} onLogout={onLogout} />
      <div style={{ flex: 1, minWidth: 0, display: 'flex', flexDirection: 'column' }}>
        <AppBar title={title} subtitle={subtitle} meta={meta} onHome={() => onNav(nav[0].key)} actions={headerActions} />
        <main style={{ flex: 1, overflowY: 'auto', padding: 28 }}>
          <div style={{ width: '100%' }}>{children}</div>
        </main>
      </div>
      {onOpenChat && <ChatFab unread={chatUnread} onOpen={onOpenChat} />}
    </div>
  );
}

/* ---------- Section title ---------- */
function SectionTitle({ icon, children, action }) {
  return (
    <div style={{ display: 'flex', alignItems: 'center', gap: 10, marginBottom: 16 }}>
      {icon && (resolve3D(icon)
        ? <Icon3D name={resolve3D(icon)} size={28} />
        : <Icon name={icon} size={22} color="var(--accent)" />)}
      <h2 style={{ margin: 0, fontSize: 18, fontWeight: 800, color: 'var(--text-strong)', flex: 1 }}>{children}</h2>
      {action}
    </div>
  );
}

/* ---------- Data table ---------- */
function DataTable({ columns, rows, renderCell }) {
  return (
    <div style={{ width: '100%', overflowX: 'auto' }}>
      <div style={{ display: 'grid', gridTemplateColumns: columns.map((c) => c.w || '1fr').join(' '), padding: '0 8px 10px', borderBottom: '1px solid var(--divider)' }}>
        {columns.map((c) => <div key={c.key} style={{ fontSize: 11.5, textTransform: 'uppercase', letterSpacing: '.08em', color: 'var(--text-faint)', fontWeight: 700, textAlign: c.align || 'left' }}>{c.label}</div>)}
      </div>
      {rows.map((r, i) => (
        <div key={r.id || i} style={{ display: 'grid', gridTemplateColumns: columns.map((c) => c.w || '1fr').join(' '), alignItems: 'center', padding: '14px 8px', borderBottom: i < rows.length - 1 ? '1px solid var(--divider)' : 'none' }}>
          {columns.map((c) => <div key={c.key} style={{ textAlign: c.align || 'left', minWidth: 0 }}>{renderCell(r, c.key)}</div>)}
        </div>
      ))}
    </div>
  );
}

/* ---------- Faint map backdrop ---------- */
function MapCanvas({ children, height = '100%', style }) {
  return (
    <div style={{
      position: 'relative', height, borderRadius: 'var(--radius-lg)', overflow: 'hidden',
      background: 'linear-gradient(0deg,#eef2f7,#f1f5f9)',
      backgroundImage: 'linear-gradient(#e2e8f0 1px,transparent 1px),linear-gradient(90deg,#e2e8f0 1px,transparent 1px),linear-gradient(rgba(203,213,225,.5) 1px,transparent 1px),linear-gradient(90deg,rgba(203,213,225,.5) 1px,transparent 1px)',
      backgroundSize: '120px 120px,120px 120px,24px 24px,24px 24px',
      border: '1px solid var(--border-card)', ...style,
    }}>{children}</div>
  );
}

/* ---------- Slide-over panel ---------- */
function SlideOver({ open, title, onClose, children, width = 380 }) {
  return (
    <>
      <div onClick={onClose} style={{ position: 'absolute', inset: 0, background: 'rgba(15,23,42,.32)', opacity: open ? 1 : 0, pointerEvents: open ? 'auto' : 'none', transition: 'opacity .24s', zIndex: 40 }} />
      <div style={{ position: 'absolute', top: 0, right: 0, bottom: 0, width, maxWidth: '92%', background: 'var(--surface-card)', boxShadow: 'var(--shadow-drawer)', transform: open ? 'translateX(0)' : 'translateX(105%)', transition: 'transform .28s var(--ease-out-cubic)', zIndex: 41, display: 'flex', flexDirection: 'column' }}>
        <div style={{ display: 'flex', alignItems: 'center', padding: '20px 22px', borderBottom: '1px solid var(--divider)' }}>
          <h3 style={{ margin: 0, flex: 1, fontSize: 17, fontWeight: 800, color: 'var(--text-strong)' }}>{title}</h3>
          <button type="button" onClick={onClose} style={{ border: 'none', background: 'transparent', cursor: 'pointer', color: 'var(--text-muted)', display: 'flex' }}><Icon name="close" size={22} /></button>
        </div>
        <div style={{ flex: 1, overflowY: 'auto', padding: 22 }}>{children}</div>
      </div>
    </>
  );
}

/* ---------- Modal ---------- */
function Modal({ open, title, onClose, children, footer, width = 460 }) {
  if (!open) return null;
  return (
    <div onClick={onClose} style={{ position: 'absolute', inset: 0, background: 'rgba(15,23,42,.45)', display: 'flex', alignItems: 'center', justifyContent: 'center', zIndex: 50, padding: 24, animation: 'mlFade .18s ease' }}>
      <div onClick={(e) => e.stopPropagation()} style={{ width, maxWidth: '100%', background: 'var(--surface-card)', borderRadius: 'var(--radius-lg)', boxShadow: 'var(--shadow-lg)', overflow: 'hidden', animation: 'mlPop .22s var(--ease-out-cubic)' }}>
        <div style={{ display: 'flex', alignItems: 'center', padding: '18px 22px', borderBottom: '1px solid var(--divider)' }}>
          <h3 style={{ margin: 0, flex: 1, fontSize: 17, fontWeight: 800, color: 'var(--text-strong)' }}>{title}</h3>
          <button type="button" onClick={onClose} style={{ border: 'none', background: 'transparent', cursor: 'pointer', color: 'var(--text-muted)', display: 'flex' }}><Icon name="close" size={22} /></button>
        </div>
        <div style={{ padding: 22 }}>{children}</div>
        {footer && <div style={{ padding: '14px 22px', borderTop: '1px solid var(--divider)', display: 'flex', justifyContent: 'flex-end', gap: 10, background: 'var(--surface-app)' }}>{footer}</div>}
      </div>
    </div>
  );
}

/* keyframes */
(function injectKeyframes() {
  if (document.getElementById('ml-shell-kf')) return;
  const s = document.createElement('style');
  s.id = 'ml-shell-kf';
  s.textContent = '@keyframes mlFade{from{opacity:0}to{opacity:1}}@keyframes mlPop{from{opacity:0;transform:translateY(8px) scale(.98)}to{opacity:1;transform:none}}@keyframes mlCount{from{opacity:0;transform:translateY(6px)}to{opacity:1;transform:none}}';
  document.head.appendChild(s);
})();

/* ---------- Icon well ----------
 * The one primitive every "icon-in-a-chip" surface should use. If the icon maps
 * to a 3D concept (alias or direct name) it renders the expressive Icon3D with
 * no background chip; otherwise it falls back to the flat tinted well. This keeps
 * the flat-for-functional / 3D-for-identity rule in ONE place.
 *   <IconWell icon="local_shipping" tone="blue" size={48} />
 * Pass force="flat" to opt out (rare — e.g. when chip color carries meaning). */
function IconWell({ icon, tone = 'cyan', size = 46, radius, force }) {
  const three = force !== 'flat' && resolve3D(icon);
  if (three) {
    return <Icon3D name={three} size={Math.round(size * 0.92)} style={{ flexShrink: 0 }} />;
  }
  return (
    <div style={{
      width: size, height: size, borderRadius: radius != null ? radius : Math.round(size * 0.28),
      background: `var(--ml-well-${tone})`, display: 'flex', alignItems: 'center',
      justifyContent: 'center', flexShrink: 0,
    }}>
      <Icon name={icon} size={Math.round(size * 0.5)} color="var(--accent)" />
    </div>
  );
}

window.MLShell = { Sidebar, AppBar, PortalShell, ChatFab, SectionTitle, DataTable, MapCanvas, SlideOver, Modal, IconWell };
