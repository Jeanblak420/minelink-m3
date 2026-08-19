/* MineLink — Super Global Serial Admin screens. */
const DSa = window.MineLinkDesignSystem_9acfde;
const { Icon: IconA, StatCard: StatA, StatusBadge: BadgeA, Button: BtnA, Avatar: AvA, Input: InA, Icon3D: Icon3DA, ICON3D_ALIASES: AL3A, ICON3D_NAMES: N3A } = DSa;
const { SectionTitle: STitleA, DataTable: TableA, SlideOver: SlideA, Modal: ModalA } = window.MLShell;
// alias OR direct Icon3D name → concept (null when there is no 3D equivalent, e.g. status counts)
const resolve3DA = (ic) => { if (!ic || window.MLIconMode === 'fallback') return null; return AL3A[ic] || (N3A.includes(ic) ? ic : null); };

const ORG_TONE = { Mine: 'cyan', Buyer: 'amber', Transporter: 'green' };
const ORG_3D = { Mine: 'mine', Buyer: 'buyer', Transporter: 'shipment' };
const ORG_CHIP = {
  Transporter: { rgb: '106,184,255', fg: '#6ab8ff', icon: 'local_shipping' },
  Buyer: { rgb: '192,124,240', fg: '#c07cf0', icon: 'shopping_cart' },
  Mine: { rgb: '245,140,60', fg: '#f7a45a', icon: 'terrain' },
};

const COMPANIES = [
  { id: 'c1', name: 'Iron Hills Mining', type: 'Mine', seats: 5, used: 5, expires: Date.now() + 1000 * 60 * 60 * 24 * 42 + 1000 * 60 * 37, serial: '7Kp$92Xv-aQ4mMIN', owner: 'ironhills.owner@mineralguide.com',
    users: [ { name: 'Iron Hills Owner', role: 'Owner', seat: 'aQ4mMIN', active: true }, { name: 'Gate Security', role: 'Security', seat: 'b8RtSEC', active: true }, { name: 'Load Controller', role: 'Controller', seat: 'k2WpCON', active: true }, { name: 'Mine Admin', role: 'Admin', seat: 'x9LmADM', active: true }, { name: 'Mine Management', role: 'Management', seat: 'p4QvMGT', active: true } ] },
  { id: 'c2', name: 'Atlas Buyer Group', type: 'Buyer', seats: 3, used: 3, expires: Date.now() + 1000 * 60 * 60 * 24 * 11 + 1000 * 60 * 12, serial: '3Mn!47Qz-rT9xBUY', owner: 'atlasbuyer.owner@mineralguide.com',
    users: [ { name: 'Atlas Owner', role: 'Owner', seat: 'rT9xBUY', active: true }, { name: 'Atlas Admin', role: 'Admin', seat: 'w1KpADM', active: true }, { name: 'Atlas Management', role: 'Management', seat: 'm7QvMGT', active: true } ] },
  { id: 'c3', name: 'Roadhaul Logistics', type: 'Transporter', seats: 4, used: 4, expires: Date.now() + 1000 * 60 * 60 * 24 * 88 + 1000 * 60 * 51, serial: '9Vb#62Lk-sW3pTRA', owner: 'roadhaul.owner@mineralguide.com',
    users: [ { name: 'Roadhaul Owner', role: 'Owner', seat: 'sW3pTRA', active: true }, { name: 'Roadhaul Driver', role: 'Driver', seat: 'd5XzDRV', active: true }, { name: 'Roadhaul Admin', role: 'Admin', seat: 'a2NpADM', active: true }, { name: 'Roadhaul Mgmt', role: 'Management', seat: 'q8RvMGT', active: false } ] },
  { id: 'c4', name: 'Test Live Mine', type: 'Mine', seats: 5, used: 6, expires: Date.now() + 1000 * 60 * 60 * 24 * 3 + 1000 * 60 * 5, serial: '5Hq^18Rd-vB6nMIN', owner: 'minesupplier.owner@gmail.com',
    users: [] },
];

function useCountdown(target) {
  const [now, setNow] = React.useState(Date.now());
  React.useEffect(() => { const id = setInterval(() => setNow(Date.now()), 1000); return () => clearInterval(id); }, []);
  let d = Math.max(0, target - now);
  const days = Math.floor(d / 86400000); d -= days * 86400000;
  const h = Math.floor(d / 3600000); d -= h * 3600000;
  const m = Math.floor(d / 60000); d -= m * 60000;
  const s = Math.floor(d / 1000);
  return { days, h, m, s, urgent: days < 7 };
}

function Countdown({ target, big }) {
  const c = useCountdown(target);
  const col = c.urgent ? 'var(--ml-orange-600)' : 'var(--text-strong)';
  const pad = (n) => String(n).padStart(2, '0');
  if (big) {
    return (
      <div style={{ display: 'flex', gap: 8 }}>
        {[[c.days, 'days'], [c.h, 'hrs'], [c.m, 'min'], [c.s, 'sec']].map(([v, l], i) => (
          <div key={i} style={{ background: 'var(--surface-app)', borderRadius: 'var(--radius-md)', padding: '10px 12px', minWidth: 58, textAlign: 'center', border: `1px solid ${c.urgent ? 'var(--ml-orange-200,#fed7aa)' : 'var(--border-card)'}` }}>
            <div style={{ fontFamily: 'var(--font-mono)', fontSize: 22, fontWeight: 700, color: col }}>{pad(v)}</div>
            <div style={{ fontSize: 10.5, color: 'var(--text-faint)', textTransform: 'uppercase', letterSpacing: '.08em' }}>{l}</div>
          </div>
        ))}
      </div>
    );
  }
  return <span style={{ fontFamily: 'var(--font-mono)', fontSize: 13.5, fontWeight: 700, color: col }}>{c.days}d {pad(c.h)}:{pad(c.m)}:{pad(c.s)}</span>;
}

/* Org-type live-operations aggregates (dashboard deck). */
const ORG_AGG = {
  transporter: { key: 'Transporter', title: 'Transporters', sub: '6 organizations · 42 fleet',
    metrics: [['Trips', '1,248'], ['Tons', '55,340 t'], ['Fleet', '42']], spark: [4, 6, 5, 7, 6, 8, 7, 9, 8, 10], sparkColor: '#5fa8ff' },
  buyer: { key: 'Buyer', title: 'Buyers', sub: '7 organizations · 22 buyer users',
    metrics: [['Orders', '318'], ['Tons', '41,860 t'], ['Value', 'R14.2m']], spark: [5, 4, 6, 5, 7, 6, 8, 7, 9, 8], sparkColor: '#b98cff' },
  mineSupplier: { key: 'Mine', title: 'Mines / Suppliers', sub: '11 organizations · 6 active pits',
    metrics: [['Tons', '74,040 t'], ['Loads', '21,338'], ['Users', '89']], spark: [3, 4, 4, 5, 6, 6, 7, 8, 9, 11], sparkColor: '#f0a55f' },
};
const REGISTRY = [
  { key: 'orgs', label: 'Total companies', value: 24, icon: 'business', tone: 'cyan', sub: 'across 4 org types', delta: '2', deltaTone: 'up' },
  { key: 'orgs:active', label: 'Active', value: 20, icon: 'check_circle', tone: 'green', sub: 'tokens valid · 100% up', delta: '83% healthy', deltaTone: 'good' },
  { key: 'orgs:expired', label: 'Expired', value: 3, icon: 'timer_off', tone: 'amber', sub: 'action needed', delta: '1', deltaTone: 'warn' },
  { key: 'orgs:suspended', label: 'Suspended', value: 1, icon: 'block', tone: 'red', sub: 'manually held', delta: 'unchanged', deltaTone: 'flat' },
  { key: 'users', label: 'Total users', value: 186, icon: 'groups', tone: 'blue', sub: 'across all orgs', delta: '14', deltaTone: 'up' },
  { key: 'token-requests', label: 'Open token requests', value: 3, icon: 'token', tone: 'amber', sub: 'awaiting approval', delta: '2', deltaTone: 'warn' },
  { key: 'users:active', label: 'Active users right now', value: 14, icon: 'bolt', tone: 'cyan', sub: 'signed-in · last 5m', delta: 'Live', deltaTone: 'live' },
  { key: 'insights:mineSupplier', label: 'Total tons managed', value: '171,240', unit: 't', icon: 'scale', tone: 'green', sub: 'Jan → today', delta: '6.4%', deltaTone: 'up' },
];
// flat tinted-chip tones (rgb for tint/border, fg for the line icon)
const REG_TONE = {
  cyan:  { rgb: '96,140,255', fg: '#8fb4ff' },
  blue:  { rgb: '96,140,255', fg: '#8fb4ff' },
  green: { rgb: '52,199,120', fg: '#5fd68f' },
  amber: { rgb: '245,140,60', fg: '#f7a45a' },
  red:   { rgb: '244,90,110', fg: '#f77f92' },
};

/* ---- dashboard helpers ---- */
function Sparkline({ data, color, w = 100, h = 34 }) {
  const max = Math.max.apply(null, data), min = Math.min.apply(null, data);
  const rng = (max - min) || 1;
  const pts = data.map((v, i) => `${(i / (data.length - 1)) * w},${h - ((v - min) / rng) * (h - 5) - 3}`).join(' ');
  const gid = 'spk' + color.replace('#', '');
  return (
    <svg width={w} height={h} style={{ display: 'block', overflow: 'visible', flexShrink: 0 }}>
      <defs><linearGradient id={gid} x1="0" y1="0" x2="0" y2="1"><stop offset="0" stopColor={color} stopOpacity=".3" /><stop offset="1" stopColor={color} stopOpacity="0" /></linearGradient></defs>
      <polygon points={`0,${h} ${pts} ${w},${h}`} fill={`url(#${gid})`} />
      <polyline points={pts} fill="none" stroke={color} strokeWidth="2" strokeLinecap="round" strokeLinejoin="round" />
    </svg>
  );
}
function Delta({ delta, tone }) {
  if (!delta) return null;
  const map = {
    up: { c: 'var(--ml-green-600)', tri: true, suffix: true },
    warn: { c: 'var(--ml-orange-600)', tri: true, suffix: true },
    good: { c: 'var(--ml-green-600)' },
    live: { c: 'var(--ml-green-600)', dot: true },
    flat: { c: 'var(--text-faint)' },
  };
  const m = map[tone] || map.flat;
  return (
    <span style={{ display: 'inline-flex', alignItems: 'center', gap: 4, fontSize: 11, fontWeight: 700, color: m.c, fontFamily: 'var(--font-mono)', whiteSpace: 'nowrap' }}>
      {m.dot && <span style={{ width: 7, height: 7, borderRadius: 999, background: m.c }} />}
      {m.tri && <span style={{ fontSize: 8, lineHeight: 1 }}>▲</span>}
      {m.suffix ? delta + ' · 24h' : delta}
    </span>
  );
}
const OTYPE_META = { Mine: { label: 'MINE', c: 'var(--ml-blue-500,#5b8dff)' }, Buyer: { label: 'BUYER', c: '#c07cf0' }, Transporter: { label: 'TRANSPORTER', c: 'var(--ml-blue-500,#5b8dff)' } };
const RECENT = [
  { id: 'r1', name: 'Iron Hills Mining', type: 'Mine', status: 'Active', loc: 'Johannesburg', users: 62, used: 5, seats: 5, expiry: '42d 08 : 34 : 55', date: '12 Aug ’26', ex: 'ok', av: 'linear-gradient(135deg,#6d8bff,#9b6cf0)' },
  { id: 'r2', name: 'Atlas Buyer Group', type: 'Buyer', status: 'Idle', loc: 'Cape Town', users: 18, used: 3, seats: 3, expiry: '13d 03 : 11 : 55', date: '17 Jul ’26', ex: 'warn', av: 'linear-gradient(135deg,#f472b6,#a855f7)' },
  { id: 'r3', name: 'Roadhaul Logistics', type: 'Transporter', status: 'Active', loc: 'Durban', users: 24, used: 4, seats: 4, expiry: '02d 18 : 46 : 05', date: '06 Jul ’26', ex: 'warn', av: 'linear-gradient(135deg,#fb9a4b,#f97316)' },
  { id: 'r4', name: 'Northern Coal Co.', type: 'Mine', status: 'Active', loc: 'Emalahleni', users: 38, used: 4, seats: 6, expiry: '78d 22 : 04 : 12', date: '20 Sep ’26', ex: 'ok', av: 'linear-gradient(135deg,#4ade80,#10b981)' },
  { id: 'r5', name: 'Sable Mercantile', type: 'Buyer', status: 'Token expired', loc: 'Gqeberha', users: 8, used: 1, seats: 2, expiry: 'Expired · 5d ago', date: '29 Jun ’26', ex: 'expired', av: 'linear-gradient(135deg,#fbbf24,#f59e0b)' },
];
function SeatsBar({ used, seats }) {
  const full = used >= seats;
  const pct = Math.min(100, (used / seats) * 100);
  return (
    <div style={{ display: 'flex', alignItems: 'center', gap: 10 }}>
      <div style={{ width: 90, height: 6, borderRadius: 999, background: 'var(--surface-sunken)', overflow: 'hidden' }}>
        <div style={{ width: pct + '%', height: '100%', borderRadius: 999, background: full ? 'var(--ml-orange-500,#f97316)' : 'var(--ml-blue-500,#3b82f6)' }} />
      </div>
      <span style={{ fontFamily: 'var(--font-mono)', fontSize: 12.5, color: 'var(--text-muted)' }}>{used}/{seats}</span>
    </div>
  );
}
function RecentActiveOrgs({ go }) {
  const TABS = [['all', 'All types', 24], ['Mine', 'Mines', 11], ['Buyer', 'Buyers', 7], ['Transporter', 'Transporters', 6]];
  const [tab, setTab] = React.useState('all');
  const rows = tab === 'all' ? RECENT : RECENT.filter((r) => r.type === tab);
  const exDot = { ok: 'var(--ml-green-500,#22c55e)', warn: 'var(--ml-orange-500,#f97316)', expired: 'var(--ml-red-500,#ef4444)' };
  return (
    <DSa.Card padding={22}>
      <div style={{ display: 'flex', alignItems: 'center', gap: 12, marginBottom: 4 }}>
        <div style={{ width: 40, height: 40, borderRadius: 11, background: 'rgba(52,199,120,.1)', border: '1px solid rgba(52,199,120,.28)', display: 'flex', alignItems: 'center', justifyContent: 'center', flexShrink: 0 }}><IconA name="monitor_heart" size={20} color="#5fd68f" /></div>
        <div style={{ flex: 1, minWidth: 0 }}>
          <h2 style={{ margin: 0, fontFamily: 'var(--font-serif)', fontSize: 16, fontWeight: 500, color: '#eaf2ff', letterSpacing: '-0.16px', lineHeight: 1.4 }}>Recently active <em style={{ fontStyle: 'italic', fontWeight: 500, color: '#7aa2ff' }}>organizations</em></h2>
          <p style={{ margin: '2px 0 0', fontSize: 11.5, color: '#657795', lineHeight: 1.4 }}>Live token expiry — companies under 7 days are flagged for upgrade.</p>
        </div>
        <button type="button" onClick={() => go('orgs')} style={{ display: 'inline-flex', alignItems: 'center', gap: 7, padding: '8px 14px', borderRadius: 'var(--radius-md)', border: '1px solid var(--border-strong)', background: 'var(--surface-card)', color: 'var(--accent)', fontFamily: 'var(--font-sans)', fontSize: 13, fontWeight: 700, cursor: 'pointer' }}><IconA name="open_in_new" size={16} />Manage all</button>
      </div>
      <div style={{ display: 'flex', alignItems: 'center', gap: 8, margin: '16px 0 8px', flexWrap: 'wrap' }}>
        {TABS.map(([k, l, n]) => { const sel = tab === k; return (
          <button key={k} type="button" onClick={() => setTab(k)} style={{ display: 'inline-flex', alignItems: 'center', gap: 5, height: 26, padding: '0 10px', borderRadius: 8, cursor: 'pointer', fontFamily: 'var(--font-sans)', fontSize: 11.5, fontWeight: 500, border: '1px solid ' + (sel ? '#6ab8ff' : 'rgba(140,180,240,.22)'), background: sel ? 'rgba(106,184,255,.1)' : 'transparent', color: sel ? '#8fd0ff' : '#c8d5ec' }}>
            {l}<span style={{ fontFamily: 'var(--font-mono)', fontSize: 11, opacity: .55 }}>{n}</span>
          </button>
        ); })}
        <div style={{ flex: 1 }} />
        <span style={{ fontSize: 12, color: 'var(--text-faint)' }}>Sort by <span style={{ color: 'var(--text-body)', fontWeight: 600 }}>last active ↓</span></span>
      </div>
      <TableA
        columns={[{ key: 'company', label: 'Company', w: '1.8fr' }, { key: 'type', label: 'Org type', w: '1fr' }, { key: 'seats', label: 'Seats', w: '1fr' }, { key: 'expiry', label: 'Token expiry', w: '1.3fr' }, { key: 'act', label: 'Actions', w: '84px', align: 'right' }]}
        rows={rows}
        renderCell={(r, k) => {
          if (k === 'company') return <div style={{ display: 'flex', alignItems: 'center', gap: 12 }}><div style={{ width: 38, height: 38, borderRadius: 11, background: r.av, display: 'flex', alignItems: 'center', justifyContent: 'center', color: '#fff', fontSize: 13, fontWeight: 800, letterSpacing: '.02em', flexShrink: 0 }}>{r.name.split(' ').filter(Boolean).slice(0, 2).map((w) => w[0]).join('')}</div><div><div style={{ fontSize: 14, fontWeight: 700, color: 'var(--text-strong)' }}>{r.name}</div><div style={{ display: 'flex', alignItems: 'center', gap: 6, fontSize: 12, color: 'var(--text-muted)', marginTop: 1 }}><span style={{ width: 6, height: 6, borderRadius: 999, background: exDot[r.ex], flexShrink: 0 }} />{r.status} · {r.loc} · {r.users} users</div></div></div>;
          if (k === 'type') { const m = OTYPE_META[r.type]; return <span style={{ display: 'inline-flex', alignItems: 'center', gap: 6, fontSize: 11, fontWeight: 700, letterSpacing: '.05em', color: m.c, background: 'var(--surface-sunken)', borderRadius: 999, padding: '4px 10px' }}><span style={{ width: 6, height: 6, borderRadius: 999, background: m.c }} />{m.label}</span>; }
          if (k === 'seats') return <SeatsBar used={r.used} seats={r.seats} />;
          if (k === 'expiry') return <div style={{ display: 'flex', alignItems: 'center', gap: 8 }}><span style={{ width: 8, height: 8, borderRadius: 999, background: exDot[r.ex], flexShrink: 0 }} /><span style={{ fontFamily: 'var(--font-mono)', fontSize: 13, fontWeight: 700, color: r.ex === 'expired' ? 'var(--ml-orange-600)' : 'var(--text-body)' }}>{r.expiry}</span><span style={{ fontSize: 11.5, color: 'var(--text-faint)' }}>{r.date}</span></div>;
          return <div style={{ display: 'flex', gap: 6, justifyContent: 'flex-end' }}><button type="button" title="Message" style={{ border: 'none', background: 'transparent', cursor: 'pointer', color: 'var(--text-faint)', display: 'flex' }}><IconA name="chat_bubble_outline" size={18} /></button><button type="button" title="Open" onClick={() => go('orgs')} style={{ border: 'none', background: 'transparent', cursor: 'pointer', color: 'var(--text-faint)', display: 'flex' }}><IconA name="chevron_right" size={20} /></button></div>;
        }}
      />
    </DSa.Card>
  );
}

function TinyMetric({ k, v }) {
  return <span style={{ fontSize: 11.5, fontWeight: 600, color: 'var(--text-muted)', background: 'var(--surface-sunken)', padding: '3px 9px', borderRadius: 999 }}>{k} · {v}</span>;
}

const HEAD_BLUE = '#7aa2ff';
function SectionHead({ title, sub, meta, link, onLink, badge }) {
  return (
    <div style={{ display: 'flex', alignItems: 'flex-start', gap: 12, margin: '0 0 14px' }}>
      <div style={{ flex: 1, minWidth: 0 }}>
        <div style={{ display: 'flex', alignItems: 'center', gap: 10 }}>
          <h2 style={{ margin: 0, fontFamily: 'var(--font-serif)', fontSize: 19, fontWeight: 500, color: '#eaf2ff', letterSpacing: '-0.19px', lineHeight: 1.4 }}>{title}</h2>
          {badge}
        </div>
        {sub && <p style={{ margin: '4px 0 0', fontSize: 13, color: 'var(--text-muted)' }}>{sub}</p>}
      </div>
      {(meta || link) && (
        <div style={{ whiteSpace: 'nowrap', display: 'flex', alignItems: 'center', gap: 14, paddingTop: 3 }}>
          {meta && <span style={{ fontSize: 12, color: 'var(--text-faint)' }}>{meta}</span>}
          {link && <button type="button" onClick={onLink} style={{ border: 'none', background: 'transparent', cursor: 'pointer', color: 'var(--accent)', fontFamily: 'var(--font-sans)', fontSize: 12.5, fontWeight: 700, padding: 0 }}>{link} →</button>}
        </div>
      )}
    </div>
  );
}
function AdminOverview({ go }) {
  return (
    <div style={{ display: 'flex', flexDirection: 'column', gap: 24 }}>
      {/* Live operations by org type */}
      <div>
        <SectionHead title="Live operations by organization type" sub="Tap a card to drill into company-level monthly rollups this calendar month." meta="This month · Jul 2026" link="View insights" onLink={() => go('insights:mineSupplier')} />
        <div style={{ display: 'grid', gridTemplateColumns: 'repeat(3,1fr)', gap: 16 }}>
          {Object.entries(ORG_AGG).map(([k, a]) => { const oc = ORG_CHIP[a.key] || ORG_CHIP.Mine; return (
            <div key={k} onClick={() => go('insights:' + k)} style={{ cursor: 'pointer', background: 'linear-gradient(180deg, var(--surface-card), rgba(' + oc.rgb + ',.05))', border: '1px solid var(--border-card)', borderRadius: 'var(--radius-xl)', boxShadow: 'var(--shadow-sm)', padding: 18, transition: 'box-shadow .18s, transform .18s' }}
              onMouseEnter={(e) => { e.currentTarget.style.boxShadow = 'var(--shadow-lg)'; e.currentTarget.style.transform = 'translateY(-3px)'; }}
              onMouseLeave={(e) => { e.currentTarget.style.boxShadow = 'var(--shadow-sm)'; e.currentTarget.style.transform = 'none'; }}>
              <div style={{ display: 'flex', alignItems: 'center', gap: 12 }}>
                <div style={{ width: 38, height: 38, borderRadius: 11, background: 'rgba(' + oc.rgb + ',.1)', border: '1px solid rgba(' + oc.rgb + ',.28)', display: 'flex', alignItems: 'center', justifyContent: 'center', flexShrink: 0 }}><IconA name={oc.icon} size={19} color={oc.fg} /></div>
                <div style={{ flex: 1, minWidth: 0 }}>
                  <div style={{ fontFamily: 'var(--font-serif)', fontSize: 19, fontWeight: 500, color: '#eaf2ff', lineHeight: 1.25 }}>{a.title}</div>
                  <div style={{ fontSize: 11.5, color: '#657795', marginTop: 2, lineHeight: 1.4 }}>{a.sub}</div>
                </div>
                <IconA name="chevron_right" size={20} color="var(--text-faint)" />
              </div>
              <div style={{ display: 'flex', alignItems: 'flex-end', gap: 16, marginTop: 16 }}>
                <div style={{ display: 'flex', justifyContent: 'space-between', flex: 1, minWidth: 0 }}>
                  {a.metrics.map(([mk, mv]) => (
                    <div key={mk}>
                      <div style={{ fontSize: 9.5, textTransform: 'uppercase', letterSpacing: '1.33px', color: '#465774', fontWeight: 600 }}>{mk}</div>
                      <div style={{ fontFamily: 'var(--font-mono)', fontSize: 14, fontWeight: 600, color: '#eaf2ff', marginTop: 4, whiteSpace: 'nowrap' }}>{mv}</div>
                    </div>
                  ))}
                </div>
                <Sparkline data={a.spark} color={a.sparkColor} />
              </div>
            </div>
          ); })}
        </div>
      </div>

      {/* Pending requests — surfaced on the dashboard when any exist */}
      {(() => {
        const REQS = [
          { key: 'requests', label: 'Requested routes', icon: 'alt_route', n: 1, sub: 'Buyers request mine — dispatch routes to be opened.', rgb: '106,184,255', fg: '#6ab8ff' },
          { key: 'req-product', label: 'Requested product', icon: 'inventory_2', n: 2, sub: 'Buyers or mines request a new product listing.', rgb: '192,124,240', fg: '#c07cf0' },
          { key: 'req-buyer', label: 'Requested buyers', icon: 'group_add', n: 1, sub: 'Mines request buyer connections and roster access.', rgb: '245,140,60', fg: '#f7a45a' },
        ].filter((r) => r.n > 0);
        if (!REQS.length) return null;
        return (
          <div>
            <SectionHead title="Pending requests" sub="Requests waiting on your approval — oldest first, ordered by criticality."
              badge={<span style={{ display: 'inline-flex', alignItems: 'center', gap: 5, fontSize: 11, fontWeight: 800, letterSpacing: '.06em', color: 'var(--ml-green-500,#22c55e)', background: 'rgba(34,197,94,.14)', border: '1px solid rgba(34,197,94,.3)', borderRadius: 999, padding: '3px 9px' }}><span style={{ width: 6, height: 6, borderRadius: 999, background: 'currentColor' }} />NEW</span>}
              meta={REQS.reduce((a, r) => a + r.n, 0) + ' open · 2 aging > 24h'} link="All requests" onLink={() => go('requests')} />
            <div style={{ display: 'grid', gridTemplateColumns: 'repeat(' + REQS.length + ',1fr)', gap: 14 }}>
              {REQS.map((r) => (
                <div key={r.key} onClick={() => go(r.key)} title={'Open ' + r.label} style={{ cursor: 'pointer', position: 'relative', background: 'linear-gradient(180deg, var(--surface-card), rgba(' + r.rgb + ',.05))', border: '1px solid var(--border-card)', borderRadius: 'var(--radius-lg)', boxShadow: 'var(--shadow-xs)', padding: 16, display: 'flex', alignItems: 'center', gap: 14, transition: 'box-shadow .15s, transform .15s' }}
                  onMouseEnter={(e) => { e.currentTarget.style.boxShadow = 'var(--shadow-md)'; e.currentTarget.style.transform = 'translateY(-2px)'; }}
                  onMouseLeave={(e) => { e.currentTarget.style.boxShadow = 'var(--shadow-xs)'; e.currentTarget.style.transform = 'none'; }}>
                  <div style={{ position: 'relative', width: 44, height: 44, borderRadius: 11, background: 'rgba(' + r.rgb + ',.1)', border: '1px solid rgba(' + r.rgb + ',.28)', display: 'flex', alignItems: 'center', justifyContent: 'center', flexShrink: 0 }}>
                    <IconA name={r.icon} size={20} color={r.fg} />
                    <span style={{ position: 'absolute', top: -6, right: -6, minWidth: 20, height: 20, padding: '0 5px', borderRadius: 999, background: 'var(--ml-orange-500,#f97316)', color: '#fff', fontSize: 11.5, fontWeight: 800, display: 'flex', alignItems: 'center', justifyContent: 'center', border: '2px solid var(--surface-card)' }}>{r.n}</span>
                  </div>
                  <div style={{ flex: 1, minWidth: 0 }}>
                    <div style={{ fontSize: 14.5, fontWeight: 800, color: 'var(--text-strong)' }}>{r.label}</div>
                    <div style={{ fontSize: 12, color: 'var(--text-muted)', marginTop: 2 }}>{r.sub}</div>
                    <div style={{ fontSize: 11.5, fontWeight: 700, color: 'var(--accent)', marginTop: 6 }}>{r.n} new · Review →</div>
                  </div>
                </div>
              ))}
            </div>
          </div>
        );
      })()}

      {/* Platform registry */}
      <div>
        <SectionHead title="Platform registry" sub="Companies, users and throughput — updated live from the biometric gate and API events." meta="Last 24h · +2 companies, +14 users" link="Export snapshot" onLink={() => go('orgs')} />
        <div style={{ display: 'grid', gridTemplateColumns: 'repeat(4,1fr)', gap: 14 }}>
          {REGISTRY.map((s) => { const t = REG_TONE[s.tone] || REG_TONE.blue; return (
            <div key={s.key} onClick={() => go(s.key)} title="Open" style={{ cursor: 'pointer', background: 'linear-gradient(180deg, var(--surface-card), rgba(' + t.rgb + ',.05))', border: '1px solid var(--border-card)', borderLeft: '3px solid rgba(' + t.rgb + ',.85)', borderRadius: 'var(--radius-lg)', boxShadow: 'var(--shadow-xs)', padding: 16, transition: 'box-shadow .15s' }}
              onMouseEnter={(e) => { e.currentTarget.style.boxShadow = 'var(--shadow-md)'; }} onMouseLeave={(e) => { e.currentTarget.style.boxShadow = 'var(--shadow-xs)'; }}>
              <div style={{ display: 'flex', alignItems: 'flex-start' }}>
                <div style={{ width: 40, height: 40, borderRadius: 11, background: 'rgba(' + t.rgb + ',.1)', border: '1px solid rgba(' + t.rgb + ',.28)', display: 'flex', alignItems: 'center', justifyContent: 'center' }}><IconA name={s.icon} size={18} color={t.fg} /></div>
                <div style={{ flex: 1 }} />
                <Delta delta={s.delta} tone={s.deltaTone} />
              </div>
              <div style={{ fontSize: 32, fontWeight: 600, fontFamily: 'var(--font-serif)', color: '#d7e2f2', lineHeight: 1, marginTop: 14 }}>{s.value}{s.unit ? <span style={{ fontSize: 16, marginLeft: 2, fontWeight: 600, color: 'var(--text-faint)' }}>{s.unit}</span> : null}</div>
              <div style={{ fontSize: 13, color: 'var(--text-strong)', fontWeight: 700, marginTop: 8 }}>{s.label}</div>
              <div style={{ fontSize: 11.5, color: 'var(--text-faint)', marginTop: 2, fontFamily: 'var(--font-mono)' }}>{s.sub}</div>
            </div>
          ); })}
        </div>
      </div>

      {/* Expired token requests banner */}
      <div onClick={() => go('token-requests')} style={{ cursor: 'pointer', display: 'flex', alignItems: 'center', gap: 14, padding: '14px 16px', borderRadius: 'var(--radius-lg)', background: 'linear-gradient(180deg, transparent, rgba(148,163,196,.07) 42%, rgba(148,163,196,.06) 58%, transparent), linear-gradient(90deg, rgba(245,140,60,.09), rgba(245,140,60,.015) 42%, transparent)', border: '1px solid var(--border-card)', borderLeft: '3px solid rgba(245,140,60,.85)' }}>
        <div style={{ width: 40, height: 40, borderRadius: 11, background: 'rgba(245,140,60,.1)', border: '1px solid rgba(245,140,60,.28)', display: 'flex', alignItems: 'center', justifyContent: 'center', flexShrink: 0 }}><IconA name="warning" size={18} color="#f7a45a" /></div>
        <div style={{ flex: 1, minWidth: 0 }}>
          <div style={{ fontSize: 14, fontWeight: 700, color: 'var(--text-strong)' }}>Expired token requests</div>
          <div style={{ fontSize: 12.5, color: 'var(--text-muted)', marginTop: 2 }}>3 companies need approvals or action from the Admin panel · oldest 5 days waiting.</div>
        </div>
        <button type="button" style={{ display: 'inline-flex', alignItems: 'center', justifyContent: 'center', gap: 6, height: 34, padding: '0 14px', borderRadius: 9, border: 'none', background: 'linear-gradient(180deg,#ffb066,#f5943c)', color: '#1a0f08', fontFamily: 'var(--font-sans)', fontSize: 12.5, fontWeight: 600, lineHeight: 1.4, cursor: 'pointer', flexShrink: 0, boxShadow: '0 0 0 4px rgba(245,148,60,.14), 0 0 22px rgba(245,148,60,.5)' }}>Review <IconA name="chevron_right" size={16} /></button>
      </div>

      {/* Quick actions */}
      <div>
        <SectionHead title="Quick actions" sub="Jump straight to the most-used admin flows." />
        <div style={{ display: 'flex', flexWrap: 'wrap', gap: 10 }}>
          {[['register', 'Register company', 'add', true], ['orgs', 'Organizations', 'domain'], ['token-requests', 'Token requests', 'vpn_key'], ['token-history', 'Token history', 'history'], ['audit', 'Audit logs', 'description'], ['export', 'Export report', 'download']].map(([k, l, ic, primary]) => (
            <button key={k} type="button" onClick={() => { if (k !== 'export') go(k); }} style={{ display: 'inline-flex', alignItems: 'center', justifyContent: 'center', gap: 10, height: 42, padding: '0 16px', borderRadius: 12, border: '1px solid ' + (primary ? '#6ab8ff' : 'rgba(106,184,255,.22)'), background: primary ? 'linear-gradient(180deg,#3b7bf6,#2159d8)' : 'var(--surface-card)', color: primary ? '#f4f9ff' : '#eaf2ff', boxShadow: primary ? '0 4px 14px rgba(37,99,235,.34)' : 'none', fontFamily: 'var(--font-sans)', fontSize: 13, fontWeight: 500, cursor: 'pointer' }}>
              <IconA name={ic} size={18} color={primary ? '#f4f9ff' : '#6ab8ff'} />{l}
            </button>
          ))}
        </div>
      </div>

      {/* Recently active orgs */}
      <RecentActiveOrgs go={go} />
    </div>
  );
}

function OrgTable({ rows, onOpen }) {
  return (
    <TableA
      columns={[{ key: 'name', label: 'Company', w: '1.6fr' }, { key: 'type', label: 'Org Type', w: '1fr' }, { key: 'seats', label: 'Seats', w: '0.9fr', align: 'center' }, { key: 'expiry', label: 'Token Expiry', w: '1.3fr' }, { key: 'go', label: '', w: '44px', align: 'right' }]}
      rows={rows}
      renderCell={(r, k) => {
        if (k === 'name') return <div onClick={() => onOpen(r)} style={{ display: 'flex', alignItems: 'center', gap: 12, cursor: 'pointer' }}><Icon3DA name={ORG_3D[r.type]} size={34} /><div><div style={{ fontWeight: 700, color: 'var(--text-strong)', fontSize: 14 }}>{r.name}</div><div style={{ fontSize: 12, color: 'var(--text-faint)', fontFamily: 'var(--font-mono)' }}>{r.serial}</div></div></div>;
        if (k === 'type') return <BadgeA tone={ORG_TONE[r.type] === 'cyan' ? 'transit' : ORG_TONE[r.type] === 'amber' ? 'atmine' : 'done'}>{r.type}</BadgeA>;
        if (k === 'seats') return <span style={{ fontFamily: 'var(--font-mono)', fontWeight: 700, color: r.used > r.seats ? 'var(--ml-orange-600)' : 'var(--text-body)' }}>{r.used}/{r.seats}</span>;
        if (k === 'expiry') return <Countdown target={r.expires} />;
        return <button type="button" onClick={() => onOpen(r)} style={{ border: 'none', background: 'transparent', cursor: 'pointer', color: 'var(--text-faint)', display: 'flex' }}><IconA name="chevron_right" size={20} /></button>;
      }}
    />
  );
}

function AdminOrganizations({ openCompany, onRegister }) {
  const now = Date.now();
  const [q, setQ] = React.useState('');
  const [type, setType] = React.useState('all');
  const [status, setStatus] = React.useState('all');
  const [perPage, setPerPage] = React.useState(10);
  const [page, setPage] = React.useState(1);

  const daysLeft = (c) => Math.floor((c.expires - now) / 86400000);
  const statusOf = (c) => { const d = daysLeft(c); if (d < 0) return 'expired'; if (c.used > c.seats) return 'overlimit'; if (d < 7) return 'expiring'; return 'active'; };

  let filtered = COMPANIES.filter((c) => {
    if (q && !(c.name.toLowerCase().includes(q.toLowerCase()) || (c.serial || '').toLowerCase().includes(q.toLowerCase()))) return false;
    if (type !== 'all' && c.type !== type) return false;
    if (status !== 'all' && statusOf(c) !== status) return false;
    return true;
  });

  const total = filtered.length;
  const pages = Math.max(1, Math.ceil(total / perPage));
  const curPage = Math.min(page, pages);
  const start = (curPage - 1) * perPage;
  const shown = filtered.slice(start, start + perPage);
  React.useEffect(() => { setPage(1); }, [q, type, status, perPage]);

  const selCss = { appearance: 'none', WebkitAppearance: 'none', padding: '9px 32px 9px 12px', background: 'var(--surface-card)', border: '1px solid var(--border-strong)', borderRadius: 'var(--radius-md)', fontFamily: 'var(--font-sans)', fontSize: 13.5, fontWeight: 600, color: 'var(--text-body)', cursor: 'pointer', outline: 'none' };
  const Chevron = () => <span style={{ position: 'absolute', right: 10, top: '50%', transform: 'translateY(-50%)', pointerEvents: 'none', display: 'flex' }}><IconA name="expand_more" size={17} color="var(--text-muted)" /></span>;

  return (
    <div>
      <STitleA icon="apartment" action={<BtnA icon="add" size="sm" onClick={() => onRegister && onRegister()}>Register company</BtnA>}>Organizations</STitleA>
      <DSa.Card padding={22}>
        {/* Filter bar */}
        <div style={{ display: 'flex', gap: 10, marginBottom: 16, flexWrap: 'wrap', alignItems: 'center' }}>
          <div style={{ flex: 1, minWidth: 220 }}><InA icon="search" placeholder="Search name or serial..." value={q} onChange={(e) => setQ(e.target.value)} /></div>
          <div style={{ position: 'relative' }}>
            <select value={type} onChange={(e) => setType(e.target.value)} style={selCss}>
              <option value="all">All org types</option><option value="Mine">Mine</option><option value="Buyer">Buyer</option><option value="Transporter">Transporter</option>
            </select><Chevron />
          </div>
          <div style={{ position: 'relative' }}>
            <select value={status} onChange={(e) => setStatus(e.target.value)} style={selCss}>
              <option value="all">All statuses</option><option value="active">Active</option><option value="expiring">Expiring &lt; 7d</option><option value="expired">Expired</option><option value="overlimit">Over seat limit</option>
            </select><Chevron />
          </div>
        </div>

        {shown.length ? <OrgTable rows={shown} onOpen={openCompany} /> : <div style={{ padding: 40, textAlign: 'center', color: 'var(--text-faint)', fontSize: 14 }}>No organizations match these filters.</div>}

        {/* Pagination footer */}
        <div style={{ display: 'flex', alignItems: 'center', gap: 14, marginTop: 16, paddingTop: 16, borderTop: '1px solid var(--divider)', flexWrap: 'wrap' }}>
          <span style={{ fontSize: 13, color: 'var(--text-muted)' }}>{total === 0 ? '0' : (start + 1) + '\u2013' + Math.min(start + perPage, total)} of {total}</span>
          <div style={{ position: 'relative' }}>
            <select value={perPage} onChange={(e) => setPerPage(Number(e.target.value))} style={{ ...selCss, padding: '7px 30px 7px 12px', fontSize: 13 }}>
              {[5, 10, 25, 50].map((n) => <option key={n} value={n}>{n} / page</option>)}
            </select><Chevron />
          </div>
          <div style={{ flex: 1 }} />
          <div style={{ display: 'flex', alignItems: 'center', gap: 6 }}>
            <button type="button" disabled={curPage <= 1} onClick={() => setPage(curPage - 1)} style={{ width: 34, height: 34, borderRadius: 9, border: '1px solid var(--border-strong)', background: 'var(--surface-card)', cursor: curPage <= 1 ? 'not-allowed' : 'pointer', opacity: curPage <= 1 ? 0.4 : 1, display: 'flex', alignItems: 'center', justifyContent: 'center', color: 'var(--text-body)' }}><IconA name="chevron_left" size={18} /></button>
            {Array.from({ length: pages }, (_, i) => i + 1).map((p) => (
              <button key={p} type="button" onClick={() => setPage(p)} style={{ minWidth: 34, height: 34, borderRadius: 9, border: `1px solid ${p === curPage ? 'var(--accent)' : 'var(--border-strong)'}`, background: p === curPage ? 'var(--accent)' : 'var(--surface-card)', color: p === curPage ? '#fff' : 'var(--text-body)', fontFamily: 'var(--font-sans)', fontSize: 13.5, fontWeight: 700, cursor: 'pointer' }}>{p}</button>
            ))}
            <button type="button" disabled={curPage >= pages} onClick={() => setPage(curPage + 1)} style={{ width: 34, height: 34, borderRadius: 9, border: '1px solid var(--border-strong)', background: 'var(--surface-card)', cursor: curPage >= pages ? 'not-allowed' : 'pointer', opacity: curPage >= pages ? 0.4 : 1, display: 'flex', alignItems: 'center', justifyContent: 'center', color: 'var(--text-body)' }}><IconA name="chevron_right" size={18} /></button>
          </div>
        </div>
      </DSa.Card>
    </div>
  );
}

function CompanyPanel({ company, onClose }) {
  const [gen, setGen] = React.useState(false);
  if (!company) return null;
  return (
    <>
      <SlideA open={!!company} title={company.name} onClose={onClose} width={460}>
        <div style={{ display: 'flex', flexDirection: 'column', gap: 22 }}>
          <div style={{ display: 'flex', alignItems: 'center', gap: 10 }}>
            <BadgeA tone={ORG_TONE[company.type] === 'cyan' ? 'transit' : ORG_TONE[company.type] === 'amber' ? 'atmine' : 'done'}>{company.type}</BadgeA>
            <span style={{ fontSize: 13, color: 'var(--text-muted)' }}>{company.owner}</span>
          </div>

          <div>
            <div style={{ fontSize: 12, textTransform: 'uppercase', letterSpacing: '.08em', color: 'var(--text-faint)', fontWeight: 700, marginBottom: 8 }}>Token expiry</div>
            <Countdown target={company.expires} big />
            <div style={{ fontSize: 12.5, color: 'var(--text-muted)', marginTop: 8 }}>Serial <span style={{ fontFamily: 'var(--font-mono)', color: 'var(--text-body)', fontWeight: 600 }}>{company.serial}</span> · assigned 30 Mar 2026</div>
          </div>

          <div style={{ display: 'flex', gap: 10 }}>
            <div style={{ flex: 1, background: 'var(--surface-app)', borderRadius: 'var(--radius-md)', padding: 14, border: '1px solid var(--border-card)' }}><div style={{ fontSize: 12, color: 'var(--text-muted)' }}>Seats used</div><div style={{ fontSize: 24, fontWeight: 800, color: company.used > company.seats ? 'var(--ml-orange-600)' : 'var(--text-strong)' }}>{company.used}/{company.seats}</div></div>
            <div style={{ flex: 1, background: 'var(--surface-app)', borderRadius: 'var(--radius-md)', padding: 14, border: '1px solid var(--border-card)' }}><div style={{ fontSize: 12, color: 'var(--text-muted)' }}>Reassigns left (30d)</div><div style={{ fontSize: 24, fontWeight: 800, color: 'var(--text-strong)' }}>2</div></div>
          </div>

          {company.used > company.seats && (
            <div style={{ display: 'flex', gap: 10, padding: 14, background: 'var(--status-warn-bg)', borderRadius: 'var(--radius-md)', alignItems: 'flex-start' }}>
              <IconA name="warning" size={20} color="var(--ml-orange-700)" />
              <div style={{ fontSize: 13, color: 'var(--ml-orange-700)' }}><b>Over seat limit.</b> {company.used} users, {company.seats} active seats. {company.used - company.seats} user(s) have no active access — prompt the company to upgrade.</div>
            </div>
          )}

          <div>
            <div style={{ display: 'flex', alignItems: 'center', marginBottom: 10 }}><div style={{ fontSize: 12, textTransform: 'uppercase', letterSpacing: '.08em', color: 'var(--text-faint)', fontWeight: 700, flex: 1 }}>Linked users &amp; seats</div><button type="button" onClick={() => setGen(true)} style={{ border: 'none', background: 'transparent', color: 'var(--accent)', fontWeight: 700, fontSize: 13, cursor: 'pointer' }}>+ Generate seat</button></div>
            {company.users.length === 0 && <div style={{ fontSize: 13, color: 'var(--text-faint)', padding: '12px 0' }}>No users linked yet.</div>}
            <div style={{ display: 'flex', flexDirection: 'column', gap: 8 }}>
              {company.users.map((u, i) => (
                <div key={i} style={{ display: 'flex', alignItems: 'center', gap: 12, padding: 12, border: '1px solid var(--border-card)', borderRadius: 'var(--radius-md)' }}>
                  <AvA name={u.name} size={34} tone="slate" />
                  <div style={{ flex: 1 }}><div style={{ fontSize: 14, fontWeight: 600, color: 'var(--text-strong)' }}>{u.name}</div><div style={{ fontSize: 12, color: 'var(--text-muted)' }}>{u.role} · seat <span style={{ fontFamily: 'var(--font-mono)' }}>…{u.seat}</span></div></div>
                  <BadgeA tone={u.active ? 'done' : 'neutral'}>{u.active ? 'ACTIVE' : 'NO SEAT'}</BadgeA>
                </div>
              ))}
            </div>
          </div>

          <div style={{ display: 'flex', gap: 10 }}>
            <BtnA block icon="download" variant="outline">Token history</BtnA>
            <BtnA block icon="upgrade">Upgrade seats</BtnA>
          </div>
        </div>
      </SlideA>
      <ModalA open={gen} title="Generate seat serial" onClose={() => setGen(false)} footer={<><BtnA variant="outline" onClick={() => setGen(false)}>Cancel</BtnA><BtnA icon="vpn_key" onClick={() => setGen(false)}>Generate</BtnA></>}>
        <div style={{ display: 'flex', flexDirection: 'column', gap: 16 }}>
          <DSa.Select label="Role type" icon="badge" options={['Owner', 'Admin', 'Management', 'Security', 'Controller', 'Driver']} />
          <DSa.Select label="Valid period" icon="event" options={['30 days', '90 days', '6 months', '12 months']} />
          <div style={{ background: 'var(--surface-app)', borderRadius: 'var(--radius-md)', padding: 14, border: '1px dashed var(--border-strong)' }}>
            <div style={{ fontSize: 11.5, color: 'var(--text-faint)', marginBottom: 4 }}>Preview — last 3 chars bind to role</div>
            <div style={{ fontFamily: 'var(--font-mono)', fontSize: 16, fontWeight: 700, color: 'var(--text-strong)', letterSpacing: '.04em' }}>2Hq#84Lp-mN6w<span style={{ color: 'var(--accent)' }}>ADM</span></div>
          </div>
        </div>
      </ModalA>
    </>
  );
}

/* ============ Transportation Requests inbox (admin/representative side) ============ */
const REQ_TONE = { submitted: 'transit', under_review: 'atmine', sent_back: 'warn', accepted: 'done', declined: 'error', dispatched: 'done' };
const REQ_LABEL = { submitted: 'Submitted', under_review: 'Under review', sent_back: 'Sent back', accepted: 'Accepted', declined: 'Declined', dispatched: 'Dispatched' };

const REQUESTS = [
  { id: 'TR-26-001847', buyer: 'Atlas Buyer Group', type: 'transportation', status: 'submitted', loading: 'Mogalakwena Mine', offload: 'Saldanha Steel Works', commodity: 'Iron Ore', distance: '480', tons: '2,400', slots: '12', duration: '3 months / 12,000 t', pay: '30 days', diesel: 'On account', rate: '420.00', hours: '24 hours', days: 'Mon–Sun', start: 'Ongoing', notes: 'Weighbridge on-site. Tarp required for offload. Night access via Gate 2.', mins: 14 },
  { id: 'TR-26-001846', buyer: 'Pioneer Mining', type: 'transportation', status: 'under_review', loading: 'Thabazimbi Mine', offload: 'Vanderbijlpark', commodity: 'Chrome Ore', distance: '210', tons: '1,100', slots: '6', duration: '6 weeks', pay: '14 days', diesel: 'On transporter', rate: '365.00', hours: '06:00 – 18:00', days: 'Mon–Fri', start: '03 Jul 2026', notes: 'Buyer prefers single transporter for full allocation.', mins: 51 },
  { id: 'TR-26-001844', buyer: 'Bathopele Mining', type: 'transportation', status: 'sent_back', loading: 'Rustenburg Mine', offload: 'Richards Bay Terminal', commodity: 'Manganese', distance: '640', tons: '3,200', slots: '16', duration: '4 months', pay: '50/50', diesel: 'On account', rate: '510.00', hours: '24 hours', days: 'Mon–Sun', start: '10 Jul 2026', notes: '', adminNotes: 'Please confirm offload terminal booking ref and revise rate — current rate below corridor average.', mins: 180 },
  { id: 'TR-26-001840', buyer: 'Atlas Buyer Group', type: 'transportation', status: 'accepted', loading: 'Mogalakwena Mine', offload: 'Durban Port', commodity: 'Coal', distance: '560', tons: '1,800', slots: '9', duration: '2 months', pay: '30 days', diesel: 'On account', rate: '475.00', hours: '24 hours', days: 'Mon–Sun', start: '01 Jul 2026', notes: '', supplier: 'Iron Hills Mining', mins: 1440 },
];

function timeAgo(mins) {
  if (mins < 60) return `${mins}m ago`;
  if (mins < 1440) return `${Math.floor(mins / 60)}h ago`;
  return `${Math.floor(mins / 1440)}d ago`;
}

function AdminRequests({ openRequest }) {
  const [filter, setFilter] = React.useState('all');
  const counts = REQUESTS.reduce((a, r) => { a[r.status] = (a[r.status] || 0) + 1; return a; }, {});
  const tabs = [['all', 'All', REQUESTS.length], ['submitted', 'New', counts.submitted || 0], ['under_review', 'Under review', counts.under_review || 0], ['sent_back', 'Sent back', counts.sent_back || 0], ['accepted', 'Accepted', counts.accepted || 0]];
  const rows = filter === 'all' ? REQUESTS : REQUESTS.filter((r) => r.status === filter);
  return (
    <div>
      <STitleA icon="inbox" action={<BadgeA tone="transit" dot>{counts.submitted || 0} new</BadgeA>}>Transportation Requests</STitleA>
      <div style={{ display: 'flex', gap: 8, marginBottom: 16, flexWrap: 'wrap' }}>
        {tabs.map(([k, l, n]) => {
          const sel = filter === k;
          return (
            <button key={k} type="button" onClick={() => setFilter(k)} style={{ display: 'inline-flex', alignItems: 'center', gap: 8, padding: '9px 15px', borderRadius: 'var(--radius-pill)', cursor: 'pointer', fontFamily: 'var(--font-sans)', fontSize: 13.5, fontWeight: 700, border: `1px solid ${sel ? 'var(--accent)' : 'var(--border-strong)'}`, background: sel ? 'var(--accent)' : 'var(--surface-card)', color: sel ? '#fff' : 'var(--text-body)' }}>
              {l}<span style={{ fontFamily: 'var(--font-mono)', fontSize: 12, padding: '1px 7px', borderRadius: 999, background: sel ? 'rgba(255,255,255,.22)' : 'var(--surface-sunken)', color: sel ? '#fff' : 'var(--text-muted)' }}>{n}</span>
            </button>
          );
        })}
      </div>
      <DSa.Card padding={22}>
        <TableA
          columns={[{ key: 'req', label: 'Request / Buyer', w: '1.7fr' }, { key: 'route', label: 'Route · Commodity', w: '1.9fr' }, { key: 'load', label: 'Tons / Slots', w: '1fr' }, { key: 'status', label: 'Status', w: '1.1fr' }, { key: 'age', label: 'Received', w: '0.9fr', align: 'right' }, { key: 'go', label: '', w: '44px', align: 'right' }]}
          rows={rows}
          renderCell={(r, k) => {
            if (k === 'req') return <div style={{ display: 'flex', alignItems: 'center', gap: 12 }}><div style={{ width: 38, height: 38, borderRadius: 11, background: 'var(--ml-well-cyan)', display: 'flex', alignItems: 'center', justifyContent: 'center' }}><IconA name="local_shipping" size={19} color="var(--accent)" /></div><div><div style={{ fontFamily: 'var(--font-mono)', fontSize: 12.5, fontWeight: 700, color: 'var(--text-strong)' }}>{r.id}</div><div style={{ fontSize: 13, color: 'var(--text-muted)' }}>{r.buyer}</div></div></div>;
            if (k === 'route') return <div><div style={{ display: 'flex', alignItems: 'center', gap: 6, fontSize: 13.5, color: 'var(--text-body)' }}>{r.loading} <IconA name="arrow_forward" size={13} color="var(--text-faint)" /> {r.offload}</div><div style={{ fontSize: 12, color: 'var(--accent)', fontWeight: 600, marginTop: 2 }}>{r.commodity} · {r.distance} km</div></div>;
            if (k === 'load') return <div style={{ fontFamily: 'var(--font-mono)', fontSize: 13.5 }}><span style={{ fontWeight: 700, color: 'var(--text-strong)' }}>{r.tons} t</span><div style={{ fontSize: 12, color: 'var(--text-muted)' }}>{r.slots} trucks</div></div>;
            if (k === 'status') return <BadgeA tone={REQ_TONE[r.status]}>{REQ_LABEL[r.status]}</BadgeA>;
            if (k === 'age') return <span style={{ fontSize: 12.5, color: 'var(--text-muted)' }}>{timeAgo(r.mins)}</span>;
            return <button type="button" onClick={() => openRequest(r)} style={{ border: 'none', background: 'transparent', cursor: 'pointer', color: 'var(--text-faint)', display: 'flex' }}><IconA name="chevron_right" size={20} /></button>;
          }}
        />
      </DSa.Card>
    </div>
  );
}

function ReqRow({ icon, label, value, accent }) {
  return (
    <div style={{ display: 'flex', alignItems: 'flex-start', gap: 12, padding: '11px 0', borderBottom: '1px solid var(--divider)' }}>
      <IconA name={icon} size={18} color="var(--text-faint)" />
      <div style={{ fontSize: 12.5, color: 'var(--text-muted)', width: 120, flexShrink: 0, paddingTop: 1 }}>{label}</div>
      <div style={{ fontSize: 14, fontWeight: 600, color: accent ? 'var(--accent)' : 'var(--text-strong)', flex: 1, textAlign: 'right' }}>{value}</div>
    </div>
  );
}

function RequestPanel({ request, onClose }) {
  const [stage, setStage] = React.useState(null); // null | 'sendback' | 'accept' | 'decline'
  const [note, setNote] = React.useState('');
  const [supplier, setSupplier] = React.useState('');
  const [resolved, setResolved] = React.useState(null);
  React.useEffect(() => { setStage(null); setNote(''); setSupplier(''); setResolved(null); }, [request && request.id]);
  if (!request) return null;
  const status = resolved || request.status;
  const isOpen = ['submitted', 'under_review'].includes(status);
  return (
    <SlideA open={!!request} title={request.id} onClose={onClose} width={480}>
      <div style={{ display: 'flex', flexDirection: 'column', gap: 20 }}>
        <div style={{ display: 'flex', alignItems: 'center', gap: 10, flexWrap: 'wrap' }}>
          <BadgeA tone={REQ_TONE[status]} dot>{REQ_LABEL[status]}</BadgeA>
          <span style={{ fontSize: 13, color: 'var(--text-muted)' }}>{request.buyer} · received {timeAgo(request.mins)}</span>
        </div>

        {/* Route hero */}
        <div style={{ background: 'linear-gradient(150deg,var(--ml-well-cyan),var(--surface-card))', border: '1px solid var(--border-accent)', borderRadius: 'var(--radius-lg)', padding: 18 }}>
          <div style={{ display: 'flex', gap: 14 }}>
            <div style={{ display: 'flex', flexDirection: 'column', alignItems: 'center', paddingTop: 5 }}>
              <span style={{ width: 12, height: 12, borderRadius: 999, background: 'var(--accent)' }} />
              <span style={{ width: 2, flex: 1, minHeight: 26, background: 'var(--border-accent)', margin: '4px 0' }} />
              <span style={{ width: 12, height: 12, borderRadius: 999, background: 'var(--ml-green-600)' }} />
            </div>
            <div style={{ flex: 1, display: 'flex', flexDirection: 'column', gap: 12 }}>
              <div><div style={{ fontSize: 11, color: 'var(--text-muted)', textTransform: 'uppercase', letterSpacing: '.06em' }}>Loading</div><div style={{ fontSize: 16, fontWeight: 800, color: 'var(--text-strong)' }}>{request.loading}</div></div>
              <div><div style={{ fontSize: 11, color: 'var(--text-muted)', textTransform: 'uppercase', letterSpacing: '.06em' }}>Offloading</div><div style={{ fontSize: 16, fontWeight: 800, color: 'var(--text-strong)' }}>{request.offload}</div></div>
            </div>
            <div style={{ textAlign: 'right' }}><div style={{ fontSize: 11, color: 'var(--text-muted)' }}>Commodity</div><div style={{ fontSize: 14, fontWeight: 700, color: 'var(--accent)' }}>{request.commodity}</div><div style={{ fontSize: 12.5, color: 'var(--text-muted)', marginTop: 4, fontFamily: 'var(--font-mono)' }}>{request.distance} km</div></div>
          </div>
        </div>

        {/* Load + commercials */}
        <div>
          <div style={{ fontSize: 12, textTransform: 'uppercase', letterSpacing: '.08em', color: 'var(--text-faint)', fontWeight: 700, marginBottom: 4 }}>Load &amp; commercials</div>
          <ReqRow icon="inventory_2" label="Tons available" value={`${request.tons} t`} />
          <ReqRow icon="local_shipping" label="Slots requested" value={`${request.slots} trucks`} />
          <ReqRow icon="event_repeat" label="Contract" value={request.duration} />
          <ReqRow icon="payments" label="Payment terms" value={request.pay} />
          <ReqRow icon="local_gas_station" label="Diesel" value={request.diesel} />
          <ReqRow icon="sell" label="Buyer rate" value={`R ${request.rate} / t`} accent />
        </div>

        {/* Schedule */}
        <div>
          <div style={{ fontSize: 12, textTransform: 'uppercase', letterSpacing: '.08em', color: 'var(--text-faint)', fontWeight: 700, marginBottom: 4 }}>Schedule</div>
          <ReqRow icon="schedule" label="Loading hours" value={request.hours} />
          <ReqRow icon="calendar_view_week" label="Operating days" value={request.days} />
          <ReqRow icon="calendar_month" label="Starting" value={request.start} />
        </div>

        {request.notes ? <div style={{ background: 'var(--surface-app)', borderRadius: 'var(--radius-md)', padding: 14, border: '1px solid var(--border-card)' }}><div style={{ fontSize: 11.5, textTransform: 'uppercase', letterSpacing: '.06em', color: 'var(--text-faint)', fontWeight: 700, marginBottom: 6 }}>Buyer notes</div><div style={{ fontSize: 13.5, color: 'var(--text-body)', lineHeight: 1.55 }}>{request.notes}</div></div> : null}

        {request.adminNotes && status === 'sent_back' ? <div style={{ background: 'var(--status-warn-bg)', borderRadius: 'var(--radius-md)', padding: 14, display: 'flex', gap: 10 }}><IconA name="undo" size={18} color="var(--ml-orange-700)" /><div><div style={{ fontSize: 11.5, textTransform: 'uppercase', letterSpacing: '.06em', color: 'var(--ml-orange-700)', fontWeight: 700, marginBottom: 4 }}>Sent back to buyer</div><div style={{ fontSize: 13.5, color: 'var(--ml-orange-700)', lineHeight: 1.5 }}>{request.adminNotes}</div></div></div> : null}

        {status === 'accepted' && (request.supplier || supplier) ? <div style={{ background: 'var(--status-done-bg)', borderRadius: 'var(--radius-md)', padding: 14, display: 'flex', gap: 10, alignItems: 'center' }}><IconA name="check_circle" size={20} color="var(--ml-green-700)" /><div style={{ fontSize: 13.5, color: 'var(--ml-green-700)' }}>Matched to <b>{request.supplier || supplier}</b> — ready to dispatch to transporters.</div></div> : null}

        {/* Action zone */}
        {isOpen && !stage && (
          <div style={{ display: 'flex', flexDirection: 'column', gap: 10, paddingTop: 4 }}>
            <div style={{ fontSize: 12, textTransform: 'uppercase', letterSpacing: '.08em', color: 'var(--text-faint)', fontWeight: 700 }}>Representative actions</div>
            <BtnA block variant="go" icon="check_circle" onClick={() => setStage('accept')}>Accept &amp; match to mine</BtnA>
            <div style={{ display: 'flex', gap: 10 }}>
              <BtnA block variant="outline" icon="undo" onClick={() => setStage('sendback')}>Send back</BtnA>
              <BtnA block variant="danger" icon="block" onClick={() => setStage('decline')}>Decline</BtnA>
            </div>
          </div>
        )}

        {stage === 'accept' && (
          <div style={{ display: 'flex', flexDirection: 'column', gap: 14, paddingTop: 4, borderTop: '1px solid var(--divider)' }}>
            <div style={{ fontSize: 15, fontWeight: 800, color: 'var(--text-strong)' }}>Match to a supplier mine</div>
            <DSa.Select label="Select mine" icon="conveyor_belt" value={supplier} onChange={(e) => setSupplier(e.target.value)} options={['Iron Hills Mining', 'Test Live Mine', 'Rustenburg Platinum']} />
            <InA label="Note to transporters (optional)" placeholder="Dispatch instructions…" value={note} onChange={(e) => setNote(e.target.value)} />
            <div style={{ display: 'flex', gap: 10 }}>
              <BtnA block variant="go" icon="send" disabled={!supplier} onClick={() => { setResolved('accepted'); setStage(null); }}>Accept &amp; dispatch</BtnA>
              <BtnA variant="outline" onClick={() => setStage(null)}>Cancel</BtnA>
            </div>
          </div>
        )}

        {stage === 'sendback' && (
          <div style={{ display: 'flex', flexDirection: 'column', gap: 14, paddingTop: 4, borderTop: '1px solid var(--divider)' }}>
            <div style={{ fontSize: 15, fontWeight: 800, color: 'var(--text-strong)' }}>Send back for changes</div>
            <div style={{ fontSize: 13, color: 'var(--text-muted)' }}>The buyer can edit &amp; resubmit. Tell them what to fix.</div>
            <textarea value={note} onChange={(e) => setNote(e.target.value)} placeholder="e.g. Confirm offload terminal booking ref; revise rate to corridor average." rows={3} style={{ width: '100%', boxSizing: 'border-box', padding: 13, background: 'var(--surface-card)', border: '1.5px solid var(--border-strong)', borderRadius: 'var(--radius-md)', fontFamily: 'var(--font-sans)', fontSize: 14.5, color: 'var(--text-strong)', outline: 'none', resize: 'vertical' }} />
            <div style={{ display: 'flex', gap: 10 }}>
              <BtnA block variant="leave" icon="undo" disabled={!note.trim()} onClick={() => { setResolved('sent_back'); setStage(null); }}>Send back to buyer</BtnA>
              <BtnA variant="outline" onClick={() => setStage(null)}>Cancel</BtnA>
            </div>
          </div>
        )}

        {stage === 'decline' && (
          <div style={{ display: 'flex', flexDirection: 'column', gap: 14, paddingTop: 4, borderTop: '1px solid var(--divider)' }}>
            <div style={{ fontSize: 15, fontWeight: 800, color: 'var(--text-strong)' }}>Decline this request</div>
            <InA label="Reason" placeholder="Reason shown to buyer…" value={note} onChange={(e) => setNote(e.target.value)} />
            <div style={{ display: 'flex', gap: 10 }}>
              <BtnA block variant="danger" icon="block" disabled={!note.trim()} onClick={() => { setResolved('declined'); setStage(null); }}>Confirm decline</BtnA>
              <BtnA variant="outline" onClick={() => setStage(null)}>Cancel</BtnA>
            </div>
          </div>
        )}

        {!isOpen && !stage ? <div style={{ display: 'flex', gap: 10 }}><BtnA block variant="outline" icon="history" onClick={onClose}>Close</BtnA></div> : null}
      </div>
    </SlideA>
  );
}

window.__ADMIN_COMPANIES__ = COMPANIES;
window.AdminScreens = Object.assign(window.AdminScreens || {}, { AdminOverview, AdminOrganizations, CompanyPanel, AdminRequests, RequestPanel });
