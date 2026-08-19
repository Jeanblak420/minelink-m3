/* MineLink — Employee Register (theme-aware "directory" view).
 * Self-contained surface used by BOTH the super-admin company mirror
 * (read-only) and each org type's own portal (manage). Ships a DARK theme
 * (default) and a warm-cream LIGHT theme, toggleable in-view.
 * Renders identically regardless of the host app's own theme.
 * Data is keyed by org type (Mine / Buyer / Transporter).
 * Exposes window.MLEmployeeRegister. */
(function () {
  const DS = window.MineLinkDesignSystem_9acfde;
  const Icon = DS.Icon;

  /* ---- editorial serif + drawer keyframes (loaded once) ---- */
  (function loadFont() {
    if (!document.getElementById('ml-emp-serif')) {
      const l = document.createElement('link');
      l.id = 'ml-emp-serif';
      l.rel = 'stylesheet';
      l.href = 'https://fonts.googleapis.com/css2?family=Newsreader:ital,opsz,wght@0,6..72,400;0,6..72,600;0,6..72,700;1,6..72,500;1,6..72,600&display=swap';
      document.head.appendChild(l);
    }
    if (!document.getElementById('ml-emp-kf')) {
      const s = document.createElement('style');
      s.id = 'ml-emp-kf';
      s.textContent = '@keyframes mlEmpFade{from{opacity:0}to{opacity:1}}@keyframes mlEmpSlide{from{transform:translateX(24px);opacity:0}to{transform:none;opacity:1}}.ml-prof-grid{display:grid;gap:20px;align-items:start;grid-template-columns:minmax(320px,380px) minmax(0,1fr) minmax(320px,400px);}@media(max-width:1200px){.ml-prof-grid{grid-template-columns:1fr;}}';
      document.head.appendChild(s);
    }
  })();

  const FONTS = {
    mono: 'ui-monospace, SFMono-Regular, "SF Mono", Menlo, monospace',
    serif: '"Newsreader", Georgia, "Times New Roman", serif',
    sans: 'var(--font-sans)',
  };

  /* ================= PALETTE (single source of truth: tokens/editorial.css) =================
   * Every value is a var(--er-*). Light/dark live in the design-system token layer and
   * switch via the app-wide [data-theme] attribute — the register never hard-codes color. */
  const TONE = {
    blue: { bg: 'var(--er-tone-blue-bg)', fg: 'var(--er-tone-blue-fg)', bd: 'var(--er-tone-blue-bd)' },
    indigo: { bg: 'var(--er-tone-indigo-bg)', fg: 'var(--er-tone-indigo-fg)', bd: 'var(--er-tone-indigo-bd)' },
    amber: { bg: 'var(--er-tone-amber-bg)', fg: 'var(--er-tone-amber-fg)', bd: 'var(--er-tone-amber-bd)' },
    green: { bg: 'var(--er-tone-green-bg)', fg: 'var(--er-tone-green-fg)', bd: 'var(--er-tone-green-bd)' },
  };
  const C = {
    ...FONTS,
    bg: 'var(--er-bg)', veil: 'var(--er-veil)', panel: 'var(--er-panel)', panelHi: 'var(--er-panel-hi)',
    line: 'var(--er-line)', lineSoft: 'var(--er-line-soft)', chip: 'var(--er-chip)',
    strong: 'var(--er-strong)', body: 'var(--er-body)', muted: 'var(--er-muted)', faint: 'var(--er-faint)',
    blue: 'var(--er-blue)', accent: 'var(--er-accent)', green: 'var(--er-green)', amber: 'var(--er-amber)', red: 'var(--er-red)',
    hoverRow: 'var(--er-hover-row)', inputBg: 'var(--er-input-bg)', focusBd: 'var(--er-focus-bd)',
    selBg: 'var(--er-sel-bg)', selFg: 'var(--er-sel-fg)',
    pillActiveBg: 'var(--er-sel-bg)', pillActiveBd: 'var(--er-sel-bg)', pillActiveFg: 'var(--er-sel-fg)',
    okBg: 'var(--er-ok-bg)', okBd: 'var(--er-ok-bd)', okGlow: 'var(--er-ok-glow)', okText: 'var(--er-ok-text)',
    scrim: 'var(--er-scrim)', drawerBg: 'var(--er-drawer-bg)',
    ctaBg: 'var(--er-cta-bg)', ctaFg: 'var(--er-cta-fg)',
    redBg: 'var(--er-red-bg)', redBd: 'var(--er-red-bd)',
    redBtnBd: 'var(--er-redbtn-bd)', redBtnBg: 'var(--er-redbtn-bg)', redBtnFg: 'var(--er-redbtn-fg)',
    bannerFade: 'var(--er-banner-fade)', roleChipBg: 'var(--er-role-chip-bg)', ring: 'var(--er-ring)',
    drawerShadow: 'var(--er-drawer-shadow)', embShadow: 'var(--er-emb-shadow)',
    PRES: { online: 'var(--er-pres-online)', away: 'var(--er-pres-away)', offline: 'var(--er-pres-offline)' },
    GTONE: { super: TONE.blue, load: TONE.indigo, security: TONE.amber, admin: TONE.green, procure: TONE.amber, fleet: TONE.blue, driver: TONE.green },
    BADGE: {
      tenure: { bg: 'var(--er-badge-tenure-bg)', fg: 'var(--er-badge-tenure-fg)', bd: 'var(--er-badge-tenure-bd)' },
      skill: TONE.blue, info: TONE.blue, good: TONE.green,
      perm: { bg: 'var(--er-badge-perm-bg)', fg: 'var(--er-badge-perm-fg)', bd: 'var(--er-badge-perm-bd)' },
      danger: { bg: 'var(--er-badge-danger-bg)', fg: 'var(--er-badge-danger-fg)', bd: 'var(--er-badge-danger-bd)' },
    },
  };
  const useTH = () => C;

  const initials = (n) => n.split(' ').filter(Boolean).slice(0, 2).map((w) => w[0].toUpperCase()).join('');
  const B = (t, k) => ({ t, k });

  /* ============ DATA ============ */
  const EMP_DATA = {
    Mine: {
      company: 'Iron Hills Mining', kicker: 'Iron Hills Mining · Directory',
      groups: [
        { key: 'super', label: 'Supervisors & Foremen', icon: 'groups', desc: 'Full operational access — everything besides generating invoices & managing employees.', coverage: 85, trend: 'up',
          people: [
            { name: 'Vusi Khumalo', id: 'SUP-021', verified: true, presence: 'online', pres: 'Online now', role: 'Supervisor', post: 'Day shift · Pit 3', tenure: '7y tenure', badges: [B('Blast', 'skill'), B('First aid', 'skill')], meta: 'Radio Ch. 3', spark: [4, 5, 4, 6, 5, 7, 6, 8] },
            { name: 'Musi Ndlovu', id: 'FRM-014', presence: 'away', pres: 'Away · 22m', role: 'Foreman', post: 'Day shift · Pit 1', tenure: '4y tenure', badges: [B('Rigger', 'skill')], meta: 'Radio Ch. 1', spark: [7, 6, 6, 5, 5, 4, 4, 3] },
            { name: 'Lusi Dlamini', id: 'SUP-008', verified: true, presence: 'offline', pres: 'Last seen 2h ago', role: 'Supervisor', post: 'Day shift · Pit 2', tenure: '9y tenure', badges: [B('Blast', 'skill'), B('Explosives', 'danger')], meta: 'Radio Ch. 2', spark: [6, 6, 5, 5, 4, 4, 4, 3] },
            { name: 'Pusi Nkosi', id: 'FRM-005', presence: 'offline', pres: 'Last seen yesterday', role: 'Foreman', post: 'Night shift · Pit 3', tenure: '3y tenure', badges: [B('First aid', 'skill')], meta: 'Radio Ch. 3', spark: [5, 5, 4, 4, 4, 3, 3, 3] },
          ] },
        { key: 'load', label: 'Load Controllers', icon: 'tune', desc: 'Load trucks only — record tons, seals & waybill slips. No invoice or roster access.', coverage: 88, trend: 'up',
          people: [
            { name: 'Ben Botha', id: 'LC-102', presence: 'online', pres: 'Online now', role: 'Load Controller', post: 'Day · Weighbridge A', tenure: '5y tenure', badges: [B('42 loads today', 'good')], meta: '3.1t avg', spark: [3, 4, 4, 5, 6, 6, 7, 8] },
            { name: 'John Meyer', id: 'LC-107', presence: 'online', pres: 'Online now', role: 'Load Controller', post: 'Day · Weighbridge B', tenure: '2y tenure', badges: [B('38 loads today', 'good')], meta: '3.4t avg', spark: [4, 4, 5, 5, 6, 7, 7, 8] },
            { name: 'Bob Naidoo', id: 'LC-110', presence: 'offline', pres: 'Last seen 30m ago', role: 'Load Controller', post: 'Day · Weighbridge A', tenure: '6y tenure', badges: [B('21 loads today', 'good')], meta: '2.9t avg', spark: [6, 6, 5, 5, 5, 4, 4, 4] },
            { name: 'Ken Adams', id: 'LC-118', presence: 'away', pres: 'Away · 18m', role: 'Load Controller', post: 'Night · Weighbridge B', tenure: '1y tenure', badges: [B('14 loads today', 'good')], meta: '3.2t avg', spark: [6, 5, 5, 4, 4, 4, 3, 3] },
          ] },
        { key: 'security', label: 'Security Guards', icon: 'shield', desc: 'Gate checks only — mark trucks arrived & departed. No load or invoice data.', coverage: 27, trend: 'down',
          people: [
            { name: 'Happy Sithole', id: 'SG-201', presence: 'online', pres: 'Online now', role: 'Security Guard', post: 'Day · North gate', tenure: '3y tenure', badges: [B('12 gate checks', 'info')], meta: '0 flags', spark: [3, 4, 4, 5, 5, 6, 7, 8] },
            { name: 'Linky Mabaso', id: 'SG-204', presence: 'online', pres: 'Online now', role: 'Security Guard', post: 'Day · South gate', tenure: '2y tenure', badges: [B('9 gate checks', 'info')], meta: '1 flag', spark: [4, 4, 5, 5, 6, 6, 7, 7] },
            { name: 'Dinky Zulu', id: 'SG-208', presence: 'offline', pres: 'Last seen 1h ago', role: 'Security Guard', post: 'Night · North gate', tenure: '4y tenure', badges: [B('6 gate checks', 'info')], meta: '0 flags', spark: [5, 5, 5, 4, 4, 4, 3, 3] },
            { name: 'Minky Cele', id: 'SG-212', presence: 'away', pres: 'Away · 34m', role: 'Security Guard', post: 'Day · South gate', tenure: '1y tenure', badges: [B('4 gate checks', 'info'), B('1 flag', 'danger')], meta: '', spark: [5, 5, 4, 4, 4, 3, 3, 3] },
          ] },
        { key: 'admin', label: 'Admins & Management', icon: 'calendar_month', desc: 'Full company administration — billing, rosters, and permissions.', coverage: 69, trend: 'flat',
          people: [
            { name: 'Nadia Pillay', id: 'ADM-001', verified: true, presence: 'online', pres: 'Online now', role: 'Admin', post: 'Head office · Johannesburg', badges: [B('System owner', 'perm'), B('All permissions', 'perm')], meta: '8y tenure', spark: [4, 5, 5, 6, 6, 7, 7, 8] },
            { name: 'Pieter Botha', id: 'MGT-002', presence: 'away', pres: 'Away · 12m', role: 'Management', post: 'Head office · Cape Town', badges: [B('Director', 'perm'), B('Billing · Rosters', 'perm')], meta: '11y tenure', spark: [7, 6, 6, 5, 5, 4, 4, 4] },
          ] },
      ],
    },
    Buyer: {
      company: 'Atlas Buyer Group', kicker: 'Atlas Buyer Group · Directory',
      groups: [
        { key: 'admin', label: 'Admins & Management', icon: 'calendar_month', desc: 'Full company administration — contracts, billing, and permissions.', coverage: 74, trend: 'up',
          people: [
            { name: 'Eli Roberts', id: 'ADM-001', verified: true, presence: 'online', pres: 'Online now', role: 'Admin', post: 'Head office · Johannesburg', badges: [B('System owner', 'perm'), B('All permissions', 'perm')], meta: '6y tenure', spark: [4, 5, 5, 6, 6, 7, 7, 8] },
            { name: 'Grace Dube', id: 'MGT-002', presence: 'away', pres: 'Away · 15m', role: 'Management', post: 'Head office · Durban', badges: [B('Director', 'perm'), B('Contracts', 'perm')], meta: '4y tenure', spark: [6, 6, 5, 5, 5, 4, 4, 4] },
          ] },
        { key: 'procure', label: 'Procurement', icon: 'shopping_bag', desc: 'Routes, waybills & reconciliation. No token or roster administration.', coverage: 80, trend: 'up',
          people: [
            { name: 'Sarah Adams', id: 'PRC-101', presence: 'online', pres: 'Online now', role: 'Procurement', post: 'Contracts · Region North', tenure: '3y tenure', badges: [B('18 waybills', 'good')], meta: '2 recons open', spark: [3, 4, 4, 5, 6, 6, 7, 8] },
            { name: 'Themba Zwane', id: 'PRC-104', presence: 'offline', pres: 'Last seen 45m ago', role: 'Procurement', post: 'Contracts · Region South', tenure: '2y tenure', badges: [B('12 waybills', 'good')], meta: '0 recons open', spark: [6, 5, 5, 5, 4, 4, 4, 3] },
            { name: 'Naledi Khoza', id: 'PRC-108', presence: 'online', pres: 'Online now', role: 'Procurement', post: 'Contracts · Region East', tenure: '1y tenure', badges: [B('9 waybills', 'good')], meta: '1 recon open', spark: [4, 4, 5, 5, 6, 6, 7, 7] },
          ] },
      ],
    },
    Transporter: {
      company: 'Roadhaul Logistics', kicker: 'Roadhaul Logistics · Directory',
      groups: [
        { key: 'admin', label: 'Admins & Management', icon: 'calendar_month', desc: 'Full company administration — billing, permissions, and fleet access.', coverage: 76, trend: 'up',
          people: [
            { name: 'Anna Steyn', id: 'ADM-001', verified: true, presence: 'online', pres: 'Online now', role: 'Admin', post: 'Head office · Johannesburg', badges: [B('System owner', 'perm'), B('All permissions', 'perm')], meta: '7y tenure', spark: [4, 5, 5, 6, 6, 7, 7, 8] },
            { name: 'Pieter van der Merwe', id: 'MGT-002', presence: 'away', pres: 'Away · 20m', role: 'Management', post: 'Head office · Pretoria', badges: [B('Director', 'perm'), B('Billing', 'perm')], meta: '9y tenure', spark: [7, 6, 6, 5, 5, 4, 4, 4] },
          ] },
        { key: 'fleet', label: 'Fleet Controllers', icon: 'local_shipping', desc: 'Manage vehicles, routes & assignments. Record trips, seals & waybill slips.', coverage: 82, trend: 'up',
          people: [
            { name: 'Riaan Steyn', id: 'FC-101', presence: 'online', pres: 'Online now', role: 'Fleet Controller', post: 'Depot · North yard', tenure: '5y tenure', badges: [B('42 trucks', 'good')], meta: '6 in service', spark: [3, 4, 4, 5, 6, 6, 7, 8] },
            { name: 'Nomsa Dube', id: 'FC-104', presence: 'away', pres: 'Away · 11m', role: 'Fleet Controller', post: 'Depot · South yard', tenure: '3y tenure', badges: [B('28 trucks', 'good')], meta: '4 in service', spark: [6, 6, 5, 5, 5, 4, 4, 4] },
          ] },
        { key: 'driver', label: 'Drivers', icon: 'badge', desc: 'Trips, POD upload & routes (mobile). Sign in with WhatsApp number.', coverage: 61, trend: 'flat',
          people: [
            { name: 'Thabo Mokoena', id: 'DRV-201', presence: 'online', pres: 'On route · N3', role: 'Driver', post: 'Day · Long haul', tenure: '4y tenure', badges: [B('18 trips', 'good'), B('PrDP', 'skill'), B('Hazmat', 'skill')], meta: 'POD 98%', spark: [4, 5, 5, 6, 6, 7, 7, 8] },
            { name: 'Pieter van Wyk', id: 'DRV-208', presence: 'offline', pres: 'Last seen 3h ago', role: 'Driver', post: 'Depot · North yard', tenure: '2y tenure', badges: [B('11 trips', 'good'), B('PrDP', 'skill')], meta: 'POD 91%', spark: [6, 5, 5, 5, 4, 4, 4, 3] },
            { name: 'Sipho Ndlovu', id: 'DRV-212', presence: 'online', pres: 'On route · N1', role: 'Driver', post: 'Day · Long haul', tenure: '1y tenure', badges: [B('22 trips', 'good'), B('PrDP', 'skill'), B('Hazmat', 'skill')], meta: 'POD 96%', spark: [3, 4, 5, 5, 6, 7, 7, 8] },
          ] },
      ],
    },
  };

  /* ============ profile / linked info (keyed by name — unique) ============ */
  const CONTACT = {
    'Vusi Khumalo': { email: 'vusi.k@ironhills.co.za', wa: '+27 82 145 9931', idno: '8604125023086', joined: 'Mar 2018', docs: ['ID document.pdf', 'Employment contract.pdf', 'Safety induction.pdf'] },
    'Musi Ndlovu': { email: 'musi.n@ironhills.co.za', wa: '+27 83 552 1180', idno: '9011080145087', joined: 'Jul 2021', docs: ['ID document.pdf', 'Employment contract.pdf'] },
    'Lusi Dlamini': { email: 'lusi.d@ironhills.co.za', wa: '+27 84 220 7745', idno: '8809215582081', joined: 'Feb 2016', docs: ['ID document.pdf'] },
    'Pusi Nkosi': { wa: '+27 82 771 3390', idno: '9207304412083', joined: 'Sep 2022', docs: ['ID document.pdf', 'Medical certificate.pdf'] },
    'Ben Botha': { email: 'ben.b@ironhills.co.za', wa: '+27 82 334 1122', idno: '8501055023084', joined: 'Jan 2020', docs: ['ID document.pdf', 'Weighbridge cert.pdf'] },
    'John Meyer': { email: 'john.m@ironhills.co.za', wa: '+27 83 909 4410', idno: '9103128823080', joined: 'Apr 2023', docs: ['ID document.pdf'] },
    'Bob Naidoo': { wa: '+27 84 118 6620', idno: '8712095412085', joined: 'Nov 2019', docs: ['ID document.pdf', 'Employment contract.pdf'] },
    'Ken Adams': { wa: '+27 82 665 9987', idno: '9309215023081', joined: 'Jun 2024', docs: ['ID document.pdf'] },
    'Happy Sithole': { wa: '+27 82 447 1123', idno: '8905125523088', joined: 'May 2022', docs: ['ID document.pdf', 'PSIRA certificate.pdf'] },
    'Linky Mabaso': { wa: '+27 83 220 8890', idno: '9207084412086', joined: 'Aug 2023', docs: ['ID document.pdf', 'PSIRA certificate.pdf'] },
    'Dinky Zulu': { wa: '+27 84 552 3345', idno: '8611095582082', joined: 'Feb 2021', docs: ['ID document.pdf'] },
    'Minky Cele': { wa: '+27 82 998 4471', idno: '9401125023089', joined: 'Oct 2024', docs: ['ID document.pdf', 'PSIRA certificate.pdf'] },
    'Nadia Pillay': { email: 'nadia.p@ironhills.co.za', wa: '+27 82 100 2030', idno: '8803120145080', joined: 'Jan 2017', docs: ['ID document.pdf', 'Employment contract.pdf'] },
    'Pieter Botha': { email: 'pieter.b@ironhills.co.za', wa: '+27 83 445 6677', idno: '7906155023087', joined: 'Mar 2014', docs: ['ID document.pdf'] },
    'Eli Roberts': { email: 'eli.r@atlasbuyer.com', wa: '+27 82 771 2211', idno: '8705120145083', joined: 'Feb 2019', docs: ['ID document.pdf', 'Employment contract.pdf'] },
    'Grace Dube': { email: 'grace.d@atlasbuyer.com', wa: '+27 83 118 4420', idno: '9002085582084', joined: 'Jun 2021', docs: ['ID document.pdf'] },
    'Sarah Adams': { email: 'sarah.a@atlasbuyer.com', wa: '+27 82 445 9931', idno: '9105120145083', joined: 'Mar 2022', docs: ['ID document.pdf'] },
    'Themba Zwane': { wa: '+27 84 220 9988', idno: '8807095412089', joined: 'Sep 2023', docs: ['ID document.pdf', 'Employment contract.pdf'] },
    'Naledi Khoza': { email: 'naledi.k@atlasbuyer.com', wa: '+27 82 990 3321', idno: '9309125023081', joined: 'Jan 2024', docs: ['ID document.pdf'] },
    'Anna Steyn': { email: 'anna.s@roadhaul.co.za', wa: '+27 82 334 5566', idno: '8604125023082', joined: 'Mar 2018', docs: ['ID document.pdf', 'Employment contract.pdf'] },
    'Pieter van der Merwe': { email: 'pieter.v@roadhaul.co.za', wa: '+27 83 445 1200', idno: '7906155023087', joined: 'Jan 2016', docs: ['ID document.pdf'] },
    'Riaan Steyn': { email: 'riaan.s@roadhaul.co.za', wa: '+27 82 118 2200', idno: '8811125023082', joined: 'May 2020', docs: ['ID document.pdf', 'Weighbridge cert.pdf'] },
    'Nomsa Dube': { wa: '+27 83 220 7788', idno: '9209085582084', joined: 'Aug 2022', docs: ['ID document.pdf'] },
    'Thabo Mokoena': { wa: '+27 82 445 1199', idno: '8811125023085', joined: 'Apr 2021', docs: ['ID document.pdf', "Driver's licence.pdf", 'PrDP.pdf'] },
    'Pieter van Wyk': { wa: '+27 84 662 3344', idno: '9002155412088', joined: 'Jul 2023', docs: ['ID document.pdf', "Driver's licence.pdf"] },
    'Sipho Ndlovu': { wa: '+27 82 990 7788', idno: '8705095523083', joined: 'Feb 2024', docs: ["Driver's licence.pdf", 'PrDP.pdf'] },
  };
  Object.values(EMP_DATA).forEach((org) => org.groups.forEach((g) => g.people.forEach((p) => Object.assign(p, CONTACT[p.name] || {}))));

  /* ============ small pieces ============ */
  function Spark({ data, color, w = 58, h = 20 }) {
    const min = Math.min(...data), max = Math.max(...data), rng = max - min || 1;
    const pts = data.map((v, i) => `${(i / (data.length - 1)) * w},${h - ((v - min) / rng) * (h - 3) - 1.5}`).join(' ');
    return (
      <svg width={w} height={h} viewBox={`0 0 ${w} ${h}`} style={{ display: 'block', overflow: 'visible' }}>
        <polyline points={pts} fill="none" strokeWidth="1.6" strokeLinecap="round" strokeLinejoin="round" style={{ stroke: color, opacity: 0.9 }} />
      </svg>
    );
  }

  function Chip({ t, k }) {
    const C = useTH();
    const s = C.BADGE[k] || C.BADGE.tenure;
    const mono = k === 'tenure' || k === 'good' || k === 'info' || k === 'danger';
    return <span style={{ display: 'inline-flex', alignItems: 'center', padding: '2px 7px', borderRadius: 6, fontSize: 10.5, fontWeight: 600, lineHeight: 1.5, letterSpacing: mono ? '.01em' : 0, fontFamily: mono ? C.mono : C.sans, color: s.fg, background: s.bg, border: `1px solid ${s.bd}`, whiteSpace: 'nowrap' }}>{t}</span>;
  }

  function EmpId({ id }) {
    const C = useTH();
    return <span style={{ fontFamily: C.mono, fontSize: 10.5, fontWeight: 600, color: C.faint, background: C.chip, border: `1px solid ${C.line}`, borderRadius: 5, padding: '1px 6px', letterSpacing: '.02em' }}>{id}</span>;
  }

  function Avatar({ person, tone }) {
    const C = useTH();
    const t = C.GTONE[tone] || C.GTONE.super;
    return (
      <div style={{ position: 'relative', flexShrink: 0 }}>
        <div style={{ width: 40, height: 40, borderRadius: 11, background: t.bg, color: t.fg, border: `1px solid ${t.bd}`, display: 'flex', alignItems: 'center', justifyContent: 'center', fontWeight: 700, fontSize: 14, fontFamily: C.sans }}>{initials(person.name)}</div>
        <span style={{ position: 'absolute', left: -2, bottom: -2, width: 12, height: 12, borderRadius: 999, background: C.PRES[person.presence], border: `2.5px solid ${C.ring}` }} />
      </div>
    );
  }

  function PersonRow({ person, tone, canManage, onOpen }) {
    const C = useTH();
    const [hover, setHover] = React.useState(false);
    const sparkColor = person.presence === 'online' ? C.green : person.presence === 'away' ? C.amber : C.faint;
    return (
      <div onClick={() => onOpen && onOpen(person)} onMouseEnter={() => setHover(true)} onMouseLeave={() => setHover(false)}
        style={{ display: 'flex', alignItems: 'flex-start', gap: 13, padding: '13px 16px', borderRadius: 12, cursor: 'pointer', background: hover ? C.hoverRow : 'transparent', transition: 'background .14s' }}>
        <Avatar person={person} tone={tone} />
        <div style={{ flex: 1, minWidth: 0 }}>
          <div style={{ display: 'flex', alignItems: 'center', gap: 8, flexWrap: 'wrap' }}>
            <span style={{ fontSize: 14, fontWeight: 700, color: C.strong }}>{person.name}</span>
            <EmpId id={person.id} />
            {person.verified && <Icon name="verified" size={14} color={C.blue} fill={1} />}
          </div>
          <div style={{ display: 'flex', alignItems: 'center', gap: 6, marginTop: 4, fontSize: 12, color: C.muted, flexWrap: 'wrap' }}>
            <span style={{ display: 'inline-flex', alignItems: 'center', gap: 5, color: C.PRES[person.presence], fontWeight: 600 }}>
              <span style={{ width: 6, height: 6, borderRadius: 999, background: C.PRES[person.presence] }} />{person.pres}
            </span>
            <span style={{ color: C.faint }}>·</span><span>{person.role}</span>
            <span style={{ color: C.faint }}>·</span><span style={{ color: C.faint }}>{person.post}</span>
          </div>
          <div style={{ display: 'flex', alignItems: 'center', gap: 6, marginTop: 8, flexWrap: 'wrap' }}>
            {person.tenure && <Chip t={person.tenure} k="tenure" />}
            {person.badges.map((b, i) => <Chip key={i} t={b.t} k={b.k} />)}
            {person.meta && <span style={{ fontSize: 11, color: C.faint, fontFamily: C.mono }}>· {person.meta}</span>}
          </div>
        </div>
        <div style={{ display: 'flex', alignItems: 'center', gap: 10, alignSelf: 'center', flexShrink: 0 }}>
          <Spark data={person.spark} color={sparkColor} />
          {canManage
            ? <button type="button" onClick={(e) => { e.stopPropagation(); }} title="Remove" style={{ border: 'none', background: 'transparent', cursor: 'pointer', color: C.faint, display: 'flex', padding: 2 }}><Icon name="person_remove" size={17} /></button>
            : <Icon name="chevron_right" size={18} color={hover ? C.body : C.faint} />}
        </div>
      </div>
    );
  }

  const covSpark = (dir) => dir === 'up' ? [3, 4, 4, 5, 5, 6, 7, 8] : dir === 'down' ? [8, 7, 6, 6, 5, 4, 4, 3] : [5, 5, 5, 5, 5, 5, 5, 5];

  function GroupCard({ group, tone, canManage, onOpen }) {
    const C = useTH();
    const online = group.people.filter((p) => p.presence === 'online').length;
    const away = group.people.filter((p) => p.presence === 'away').length;
    const offline = group.people.filter((p) => p.presence === 'offline').length;
    const t = C.GTONE[tone] || C.GTONE.super;
    const cc = group.trend === 'up' ? C.green : group.trend === 'down' ? C.red : C.amber;
    return (
      <section style={{ background: C.panel, border: `1px solid ${C.line}`, borderRadius: 18, overflow: 'hidden' }}>
        <div style={{ display: 'flex', alignItems: 'center', gap: 14, padding: '16px 20px', background: C.panelHi, borderBottom: `1px solid ${C.line}` }}>
          <div style={{ width: 38, height: 38, borderRadius: 10, background: t.bg, border: `1px solid ${t.bd}`, display: 'flex', alignItems: 'center', justifyContent: 'center', flexShrink: 0 }}><Icon name={group.icon} size={19} color={t.fg} /></div>
          <div style={{ flex: 1, minWidth: 0 }}>
            <div style={{ display: 'flex', alignItems: 'center', gap: 10 }}>
              <h3 style={{ margin: 0, fontFamily: C.serif, fontSize: 21, fontWeight: 700, color: C.strong, letterSpacing: '.005em' }}>{group.label}</h3>
              <span style={{ fontSize: 11, fontFamily: C.mono, color: C.muted, background: C.chip, border: `1px solid ${C.line}`, borderRadius: 999, padding: '2px 9px' }}>{group.people.length} people</span>
            </div>
            <div style={{ fontSize: 12.5, color: C.muted, marginTop: 4, maxWidth: 560 }}>{group.desc}</div>
          </div>
          <div style={{ display: 'flex', alignItems: 'center', gap: 10, flexShrink: 0 }}>
            <span style={{ display: 'inline-flex', alignItems: 'center', gap: 6, fontSize: 11.5, color: C.body, background: C.chip, border: `1px solid ${C.line}`, borderRadius: 999, padding: '4px 10px' }}><span style={{ width: 6, height: 6, borderRadius: 999, background: C.green }} />{online} online</span>
            <span style={{ display: 'inline-flex', alignItems: 'center', gap: 6, fontSize: 11.5, color: C.body, background: C.chip, border: `1px solid ${C.line}`, borderRadius: 999, padding: '4px 10px' }}><span style={{ width: 6, height: 6, borderRadius: 999, background: C.amber }} />{away} away</span>
            <span style={{ display: 'inline-flex', alignItems: 'center', gap: 6, fontSize: 11.5, color: C.body, background: C.chip, border: `1px solid ${C.line}`, borderRadius: 999, padding: '4px 10px', opacity: offline ? 1 : 0.55 }}><span style={{ width: 6, height: 6, borderRadius: 999, background: C.red }} />{offline} offline</span>
            <div style={{ display: 'flex', alignItems: 'center', gap: 9, paddingLeft: 6 }}>
              <span style={{ fontSize: 9.5, fontWeight: 700, letterSpacing: '.14em', color: C.faint }}>COVERAGE</span>
              <Spark data={covSpark(group.trend)} color={cc} w={66} h={22} />
              <span style={{ fontFamily: C.serif, fontSize: 22, fontWeight: 700, color: C.strong }}>{group.coverage}%</span>
            </div>
            {canManage && <button type="button" style={{ display: 'inline-flex', alignItems: 'center', gap: 6, marginLeft: 4, border: `1px solid ${C.line}`, background: C.chip, color: C.body, borderRadius: 9, padding: '7px 12px', fontSize: 12.5, fontWeight: 600, cursor: 'pointer', fontFamily: C.sans }}><Icon name="person_add" size={16} />Add</button>}
          </div>
        </div>
        <div style={{ display: 'grid', gridTemplateColumns: '1fr 1fr', gap: 2, padding: 8 }}>
          {group.people.map((p, i) => <PersonRow key={i} person={p} tone={tone} canManage={canManage} onOpen={(pp) => onOpen && onOpen(pp, group)} />)}
        </div>
      </section>
    );
  }

  function Stat({ label, value, sub, delta, dir, dot }) {
    const C = useTH();
    const dc = dir === 'up' ? C.green : dir === 'down' ? C.red : C.faint;
    return (
      <div style={{ flex: 1, padding: '14px 18px', borderLeft: `1px solid ${C.line}` }}>
        <div style={{ display: 'flex', alignItems: 'center', gap: 6, fontSize: 9.5, fontWeight: 700, letterSpacing: '.13em', color: C.faint }}>{label}
          {delta && <span style={{ display: 'inline-flex', alignItems: 'center', gap: 1, color: dc, fontFamily: C.mono, letterSpacing: 0 }}><Icon name={dir === 'up' ? 'arrow_drop_up' : 'arrow_drop_down'} size={16} color={dc} />{delta}</span>}
        </div>
        <div style={{ fontFamily: C.serif, fontSize: 38, fontWeight: 700, color: C.strong, lineHeight: 1.05, marginTop: 4 }}>{value}</div>
        <div style={{ fontSize: 11, color: C.muted, marginTop: 3, display: 'flex', alignItems: 'center', gap: 6 }}>{dot && <span style={{ width: 8, height: 8, borderRadius: 2, background: dot }} />}{sub}</div>
      </div>
    );
  }

  const SORTS = [['role', 'By role'], ['site', 'By site'], ['az', 'A–Z']];

  function ProfileRow({ icon, label, value, mono }) {
    const C = useTH();
    return (
      <div style={{ display: 'flex', alignItems: 'center', gap: 12, padding: '11px 0', borderBottom: `1px solid ${C.lineSoft}` }}>
        <Icon name={icon} size={17} color={C.faint} />
        <span style={{ fontSize: 12, color: C.muted, width: 92, flexShrink: 0 }}>{label}</span>
        <span style={{ fontSize: 13.5, fontWeight: 600, color: C.strong, flex: 1, textAlign: 'right', fontFamily: mono ? C.mono : C.sans, wordBreak: 'break-all' }}>{value}</span>
      </div>
    );
  }

  function ProfilePanel({ sel, coName, canManage, onClose }) {
    const C = useTH();
    if (!sel) return null;
    const p = sel.person, group = sel.group;
    const t = C.GTONE[group.key] || C.GTONE.super;
    const presColor = C.PRES[p.presence];
    const label = { fontSize: 10, fontWeight: 700, letterSpacing: '.12em', color: C.faint, textTransform: 'uppercase', marginBottom: 9 };
    return (
      <div style={{ position: 'fixed', inset: 0, zIndex: 60 }}>
        <div onClick={onClose} style={{ position: 'absolute', inset: 0, background: C.scrim, animation: 'mlEmpFade .2s ease' }} />
        <div style={{ position: 'absolute', top: 0, right: 0, bottom: 0, width: 452, maxWidth: '94%', background: C.drawerBg, borderLeft: `1px solid ${C.line}`, boxShadow: C.drawerShadow, display: 'flex', flexDirection: 'column', animation: 'mlEmpSlide .26s cubic-bezier(.22,.61,.36,1)', fontFamily: C.sans }}>
          <div style={{ display: 'flex', alignItems: 'center', padding: '18px 22px', borderBottom: `1px solid ${C.line}` }}>
            <span style={{ fontSize: 11.5, fontWeight: 700, letterSpacing: '.12em', color: C.faint, flex: 1 }}>EMPLOYEE PROFILE</span>
            <button type="button" onClick={onClose} style={{ border: 'none', background: 'transparent', cursor: 'pointer', color: C.muted, display: 'flex' }}><Icon name="close" size={21} /></button>
          </div>
          <div style={{ flex: 1, overflowY: 'auto', padding: 22, display: 'flex', flexDirection: 'column', gap: 22 }}>
            <div style={{ display: 'flex', alignItems: 'center', gap: 16, padding: 18, borderRadius: 16, background: `linear-gradient(150deg, ${t.bg}, ${C.bannerFade})`, border: `1px solid ${t.bd}` }}>
              <div style={{ position: 'relative', flexShrink: 0 }}>
                <div style={{ width: 66, height: 66, borderRadius: 16, background: t.bg, color: t.fg, border: `1px solid ${t.bd}`, display: 'flex', alignItems: 'center', justifyContent: 'center', fontWeight: 700, fontSize: 24 }}>{initials(p.name)}</div>
                <span style={{ position: 'absolute', left: -2, bottom: -2, width: 16, height: 16, borderRadius: 999, background: presColor, border: `3px solid ${C.drawerBg}` }} />
              </div>
              <div style={{ flex: 1, minWidth: 0 }}>
                <div style={{ display: 'flex', alignItems: 'center', gap: 7 }}>
                  <span style={{ fontFamily: C.serif, fontSize: 22, fontWeight: 700, color: C.strong }}>{p.name}</span>
                  {p.verified && <Icon name="verified" size={16} color={C.blue} fill={1} />}
                </div>
                <div style={{ display: 'inline-block', marginTop: 5, fontSize: 10.5, fontWeight: 700, letterSpacing: '.05em', textTransform: 'uppercase', color: t.fg, background: C.roleChipBg, padding: '3px 9px', borderRadius: 999, border: `1px solid ${t.bd}` }}>{p.role}</div>
                <div style={{ fontSize: 12.5, color: C.muted, marginTop: 7 }}>{coName} · {group.label}</div>
                <div style={{ display: 'inline-flex', alignItems: 'center', gap: 6, marginTop: 6, fontSize: 12, color: presColor, fontWeight: 600 }}><span style={{ width: 7, height: 7, borderRadius: 999, background: presColor }} />{p.pres}</div>
              </div>
            </div>
            <button type="button" onClick={() => { window.location.href = '../chat/index.html'; }} style={{ display: 'inline-flex', alignItems: 'center', justifyContent: 'center', gap: 8, width: '100%', padding: '11px 0', borderRadius: 11, border: 'none', cursor: 'pointer', background: C.ctaBg, color: C.ctaFg, fontSize: 14, fontWeight: 600, fontFamily: C.sans }}><Icon name="chat" size={18} />Message {p.name.split(' ')[0]}</button>
            <div>
              <div style={label}>Role snapshot</div>
              <div style={{ display: 'flex', alignItems: 'center', gap: 7, flexWrap: 'wrap', marginBottom: 10 }}>
                {p.tenure && <Chip t={p.tenure} k="tenure" />}
                {p.badges.map((b, i) => <Chip key={i} t={b.t} k={b.k} />)}
                {p.meta && <Chip t={p.meta} k="tenure" />}
              </div>
              <div style={{ display: 'grid', gridTemplateColumns: '1fr 1fr', gap: 10 }}>
                <div style={{ padding: '11px 13px', borderRadius: 11, background: C.chip, border: `1px solid ${C.lineSoft}` }}><div style={{ fontSize: 10.5, color: C.faint, marginBottom: 3 }}>Posting</div><div style={{ fontSize: 13, fontWeight: 600, color: C.strong }}>{p.post}</div></div>
                <div style={{ padding: '11px 13px', borderRadius: 11, background: C.chip, border: `1px solid ${C.lineSoft}` }}><div style={{ fontSize: 10.5, color: C.faint, marginBottom: 3 }}>Joined</div><div style={{ fontSize: 13, fontWeight: 600, color: C.strong }}>{p.joined || '—'}</div></div>
              </div>
            </div>
            <div>
              <div style={label}>Contact &amp; identity</div>
              <ProfileRow icon="badge" label="Employee ID" value={p.id} mono />
              <ProfileRow icon="work" label="Role" value={p.role} />
              {p.email && <ProfileRow icon="mail" label="Email" value={p.email} />}
              <ProfileRow icon="chat" label="WhatsApp" value={p.wa} mono />
              <ProfileRow icon="fingerprint" label="ID number" value={p.idno} mono />
              {!p.email && (
                <div style={{ display: 'flex', alignItems: 'center', gap: 9, marginTop: 11, padding: '9px 12px', background: C.okBg, border: `1px solid ${C.okBd}`, borderRadius: 10 }}>
                  <Icon name="chat" size={16} color={C.green} />
                  <span style={{ fontSize: 12, color: C.okText }}>WhatsApp-only account — signs in with their WhatsApp number, no email on file.</span>
                </div>
              )}
            </div>
            <div>
              <div style={label}>Documents ({p.docs ? p.docs.length : 0})</div>
              <div style={{ display: 'flex', flexDirection: 'column', gap: 8 }}>
                {(p.docs || []).map((d, i) => (
                  <div key={i} style={{ display: 'flex', alignItems: 'center', gap: 11, padding: '10px 12px', borderRadius: 11, background: C.chip, border: `1px solid ${C.lineSoft}` }}>
                    <div style={{ width: 32, height: 32, borderRadius: 8, background: C.redBg, border: `1px solid ${C.redBd}`, display: 'flex', alignItems: 'center', justifyContent: 'center' }}><Icon name="picture_as_pdf" size={17} color={C.red} /></div>
                    <span style={{ flex: 1, fontSize: 13, fontWeight: 600, color: C.body }}>{d}</span>
                    <button type="button" style={{ border: 'none', background: 'transparent', cursor: 'pointer', color: C.blue, display: 'flex' }}><Icon name="download" size={18} /></button>
                  </div>
                ))}
              </div>
            </div>
            {canManage && (
              <div style={{ display: 'flex', gap: 10, paddingTop: 4 }}>
                <button type="button" style={{ flex: 1, display: 'inline-flex', alignItems: 'center', justifyContent: 'center', gap: 7, padding: '10px 0', borderRadius: 10, border: `1px solid ${C.line}`, background: C.chip, color: C.body, fontSize: 13, fontWeight: 600, cursor: 'pointer', fontFamily: C.sans }}><Icon name="lock_reset" size={17} />Reset password</button>
                <button type="button" style={{ flex: 1, display: 'inline-flex', alignItems: 'center', justifyContent: 'center', gap: 7, padding: '10px 0', borderRadius: 10, border: `1px solid ${C.redBtnBd}`, background: C.redBtnBg, color: C.redBtnFg, fontSize: 13, fontWeight: 600, cursor: 'pointer', fontFamily: C.sans }}><Icon name="person_remove" size={17} />Remove</button>
              </div>
            )}
          </div>
        </div>
      </div>
    );
  }

  function RegisterInner({ otype, coName, data, canManage, onBack, embedded, theme, setTheme }) {
    const C = useTH();
    const [sel, setSel] = React.useState(null);
    const [q, setQ] = React.useState('');
    const [sort, setSort] = React.useState('role');

    const allPeople = data.groups.flatMap((g) => g.people);
    const total = allPeople.length;
    const online = allPeople.filter((p) => p.presence === 'online').length;
    const away = allPeople.filter((p) => p.presence === 'away').length;
    const offline = total - online - away;

    const ql = q.trim().toLowerCase();
    const match = (p) => !ql || p.name.toLowerCase().includes(ql) || p.role.toLowerCase().includes(ql) || p.id.toLowerCase().includes(ql);
    const orderGroups = data.groups.map((g) => {
      let people = g.people.filter(match);
      if (sort === 'az') people = [...people].sort((a, b) => a.name.localeCompare(b.name));
      else if (sort === 'site') people = [...people].sort((a, b) => a.post.localeCompare(b.post));
      return { ...g, people };
    }).filter((g) => g.people.length > 0);

    const ctl = { display: 'inline-flex', alignItems: 'center', gap: 7, padding: '7px 13px', borderRadius: 9, border: `1px solid ${C.line}`, background: C.chip, color: C.body, fontSize: 12.5, fontWeight: 600, cursor: 'pointer', fontFamily: C.sans };
    const iconBtn = { width: 38, height: 38, borderRadius: 10, border: `1px solid ${C.line}`, background: C.chip, color: C.body, cursor: 'pointer', display: 'flex', alignItems: 'center', justifyContent: 'center', position: 'relative' };

    return (
      <div style={{ background: C.bg, backgroundImage: C.veil, color: C.body, fontFamily: C.sans, minHeight: embedded ? 'auto' : '100%', padding: embedded ? '24px 26px 34px' : '22px 30px 40px', borderRadius: embedded ? 20 : 0, border: embedded ? `1px solid ${C.line}` : 'none', margin: embedded ? '-6px 0 0' : 0, boxShadow: embedded ? C.embShadow : 'none' }}>
        <div style={{ maxWidth: 1180, margin: '0 auto' }}>
          {/* top bar */}
          <div style={{ display: 'flex', alignItems: 'center', gap: 14, marginBottom: 26 }}>
            {onBack && <button type="button" onClick={onBack} style={{ ...iconBtn, width: 36, height: 36 }}><Icon name="chevron_left" size={20} /></button>}
            <div style={{ display: 'flex', alignItems: 'center', gap: 8, fontSize: 11.5, fontWeight: 700, letterSpacing: '.14em', color: C.faint }}>EMPLOYEES <span style={{ opacity: .5 }}>/</span> <span style={{ color: C.body }}>EMPLOYEE REGISTER</span></div>
            <div style={{ flex: 1 }} />
            <button type="button" title={theme === 'dark' ? 'Switch to light theme' : 'Switch to dark theme'} onClick={() => setTheme(theme === 'dark' ? 'light' : 'dark')} style={iconBtn}><Icon name={theme === 'dark' ? 'light_mode' : 'dark_mode'} size={19} /></button>
            <button type="button" title="Notifications" style={iconBtn}><Icon name="notifications" size={19} /><span style={{ position: 'absolute', top: 8, right: 9, width: 7, height: 7, borderRadius: 999, background: C.amber, border: `2px solid ${C.bg}` }} /></button>
            <span style={{ display: 'inline-flex', alignItems: 'center', gap: 7, fontSize: 11.5, color: C.okText, background: C.okBg, border: `1px solid ${C.okBd}`, borderRadius: 999, padding: '7px 13px' }}><span style={{ width: 7, height: 7, borderRadius: 999, background: C.green, boxShadow: `0 0 0 3px ${C.okGlow}` }} />Live · Synced 12s ago</span>
          </div>

          {/* masthead */}
          <div style={{ display: 'flex', alignItems: 'flex-start', gap: 28, marginBottom: 30, flexWrap: 'wrap' }}>
            <div style={{ flex: '1 1 460px', minWidth: 0 }}>
              <div style={{ display: 'flex', alignItems: 'center', gap: 10, marginBottom: 12 }}><span style={{ width: 26, height: 1.5, background: C.accent }} /><span style={{ fontSize: 11.5, fontWeight: 700, letterSpacing: '.16em', color: C.accent, textTransform: 'uppercase' }}>{data.kicker}</span></div>
              <h1 style={{ margin: 0, fontFamily: C.serif, fontSize: 54, fontWeight: 700, color: C.strong, letterSpacing: '-.01em', lineHeight: 1 }}>Employee <span style={{ fontStyle: 'italic', fontWeight: 600, color: C.accent }}>Register</span></h1>
              <p style={{ margin: '16px 0 0', fontSize: 13.5, lineHeight: 1.6, color: C.muted, maxWidth: 540 }}>Live Employee Register · A {canManage ? 'managed' : 'read-only'} view of each employee/user registered under <b style={{ color: C.body, letterSpacing: '.04em' }}>{coName.toUpperCase()}</b>. Synced &amp; updated automatically on every change and last seen / online / away status for each member.</p>
              <div style={{ display: 'inline-flex', alignItems: 'center', gap: 7, marginTop: 14, fontSize: 11.5, fontWeight: 600, color: C.muted, background: C.chip, border: `1px solid ${C.line}`, borderRadius: 999, padding: '6px 13px' }}><Icon name={canManage ? 'manage_accounts' : 'lock'} size={14} color={C.faint} />{canManage ? 'Manage access' : 'Read-only'}</div>
            </div>
            {/* stat panel */}
            <div style={{ flex: '0 1 440px', display: 'flex', background: C.panel, border: `1px solid ${C.line}`, borderRadius: 16, overflow: 'hidden' }}>
              <Stat label="TOTAL STAFF" value={total} sub={`Across ${data.groups.length} roles`} />
              <Stat label="ONLINE NOW" value={online} sub="Online (active)" dot={C.green} delta="2" dir="up" />
              <Stat label="AWAY" value={away} sub="Away (idle)" dot={C.amber} delta="1" dir="down" />
              <Stat label="OFFLINE" value={offline} sub="Offline" dot={C.red} />
            </div>
          </div>

          {/* controls */}
          <div style={{ display: 'flex', alignItems: 'center', gap: 12, marginBottom: 22, flexWrap: 'wrap' }}>
            <div style={{ flex: '1 1 320px', position: 'relative', display: 'flex', alignItems: 'center' }}>
              <Icon name="search" size={18} color={C.faint} style={{ position: 'absolute', left: 14 }} />
              <input value={q} onChange={(e) => setQ(e.target.value)} placeholder="Search by name, role, or employee ID…"
                style={{ width: '100%', boxSizing: 'border-box', padding: '11px 44px 11px 42px', borderRadius: 11, border: `1px solid ${C.line}`, background: C.inputBg, color: C.strong, fontSize: 13.5, fontFamily: C.sans, outline: 'none' }}
                onFocus={(e) => { e.target.style.borderColor = C.focusBd; }} onBlur={(e) => { e.target.style.borderColor = C.line; }} />
              <span style={{ position: 'absolute', right: 12, fontFamily: C.mono, fontSize: 11, color: C.faint, border: `1px solid ${C.line}`, borderRadius: 5, padding: '1px 6px' }}>⌘K</span>
            </div>
            <div style={{ display: 'inline-flex', gap: 4, padding: 4, borderRadius: 11, background: C.chip, border: `1px solid ${C.line}` }}>
              {SORTS.map(([k, l]) => <button key={k} type="button" onClick={() => setSort(k)} style={{ padding: '6px 12px', borderRadius: 8, border: 'none', cursor: 'pointer', fontSize: 12.5, fontWeight: 600, fontFamily: C.sans, background: sort === k ? C.selBg : 'transparent', color: sort === k ? C.selFg : C.muted }}>{l}</button>)}
            </div>
            <button type="button" style={ctl}><Icon name="filter_list" size={16} color={C.muted} />Filter</button>
            <button type="button" style={ctl}>Status: <b style={{ color: C.strong }}>All</b><Icon name="expand_more" size={16} color={C.faint} /></button>
            <button type="button" style={ctl}>Shift: <b style={{ color: C.strong }}>Day</b><Icon name="expand_more" size={16} color={C.faint} /></button>
          </div>

          {/* groups */}
          <div style={{ display: 'flex', flexDirection: 'column', gap: 18 }}>
            {orderGroups.map((g) => <GroupCard key={g.key} group={g} tone={g.key} canManage={canManage} onOpen={(person, grp) => setSel({ person, group: grp })} />)}
            {orderGroups.length === 0 && <div style={{ padding: 40, textAlign: 'center', color: C.faint, fontSize: 14 }}>No employees match “{q}”.</div>}
          </div>

          {/* footer */}
          <div style={{ display: 'flex', alignItems: 'center', gap: 20, marginTop: 28, paddingTop: 18, borderTop: `1px solid ${C.line}`, flexWrap: 'wrap' }}>
            <span style={{ display: 'inline-flex', alignItems: 'center', gap: 7, fontSize: 11.5, color: C.muted }}><span style={{ width: 7, height: 7, borderRadius: 999, background: C.green }} />Online (active &lt; 5m)</span>
            <span style={{ display: 'inline-flex', alignItems: 'center', gap: 7, fontSize: 11.5, color: C.muted }}><span style={{ width: 7, height: 7, borderRadius: 999, background: C.amber }} />Away (idle 15m+)</span>
            <span style={{ display: 'inline-flex', alignItems: 'center', gap: 7, fontSize: 11.5, color: C.muted }}><span style={{ width: 7, height: 7, borderRadius: 999, background: C.red }} />Offline (&gt; 2h)</span>
            <div style={{ flex: 1 }} />
            <span style={{ fontSize: 11.5, color: C.faint }}>Live Register · Auto-updates on any changes · Updated <b style={{ color: C.muted }}>12s ago</b></span>
            <button type="button" style={{ display: 'inline-flex', alignItems: 'center', gap: 7, border: `1px solid ${C.line}`, background: C.chip, color: C.body, borderRadius: 10, padding: '8px 14px', fontSize: 12.5, fontWeight: 600, cursor: 'pointer', fontFamily: C.sans }}><Icon name="download" size={16} />Export CSV</button>
          </div>
        </div>
        <FullProfile sel={sel} otype={otype} coName={coName} canManage={canManage} flat={data.groups.flatMap((g) => g.people.map((person) => ({ person, group: g })))} onSelect={setSel} onClose={() => setSel(null)} />
      </div>
    );
  }

  function Register({ otype = 'Mine', companyName, canManage = false, onBack, embedded = false, theme: initialTheme }) {
    const data = EMP_DATA[otype] || EMP_DATA.Mine;
    const coName = companyName || data.company;
    const [theme, setThemeState] = React.useState(() => initialTheme || (window.MLPortalTheme ? window.MLPortalTheme.get() : 'dark'));
    React.useEffect(() => {
      const h = (e) => setThemeState(e.detail);
      window.addEventListener('ml-theme-change', h);
      return () => window.removeEventListener('ml-theme-change', h);
    }, []);
    // toggling from within the register flips the whole app theme (chrome + screens)
    const setTheme = (t) => { if (window.MLPortalTheme) window.MLPortalTheme.set(t); else setThemeState(t); };
    return (
      <RegisterInner otype={otype} coName={coName} data={data} canManage={canManage} onBack={onBack} embedded={embedded} theme={theme} setTheme={setTheme} />
    );
  }

  /* ================= FULL-SCREEN EMPLOYEE PROFILE ================= */
  const num = (s) => { if (s == null) return null; const m = String(s).match(/\d+(\.\d+)?/); return m ? m[0] : null; };
  const seed = (str) => { let h = 2166136261; for (let i = 0; i < str.length; i++) { h ^= str.charCodeAt(i); h = Math.imul(h, 16777619); } return () => { h = Math.imul(h ^ (h >>> 15), 2246822507); h ^= h >>> 13; return ((h >>> 0) % 1000) / 1000; }; };
  const UP = [3, 4, 4, 5, 6, 6, 7, 8], DOWN = [8, 7, 6, 6, 5, 4, 4, 3], WAVE = [4, 5, 4, 6, 5, 7, 6, 8];

  const SUPERVISOR = { Mine: { name: 'Vusi Khumalo', role: 'Day shift · Pit 3', init: 'VK' }, Buyer: { name: 'Eli Roberts', role: 'Head office · JHB', init: 'ER' }, Transporter: { name: 'Riaan Steyn', role: 'Depot · North yard', init: 'RS' } };

  /* role → three live productivity metrics (values pulled from the register data
   * where present so the numbers agree with the list, otherwise seeded per-id). */
  function roleMetrics(p, key, C) {
    const rnd = seed(p.id + p.name);
    const badge = (re) => { const b = p.badges.find((x) => re.test(x.t)); return b ? num(b.t) : null; };
    const pick = (lo, hi) => lo + Math.round(rnd() * (hi - lo));
    const M = (label, value, unit, sub, dir, delta, spark, color) => ({ label, value, unit, sub, dir, delta, spark, color });
    switch (key) {
      case 'load': {
        const loads = badge(/load/i) || pick(18, 44); const tons = num(p.meta) || (2.8 + rnd()).toFixed(1); const err = pick(0, 1);
        return [
          M('LOADS LOGGED', loads, '', 'weekly avg ' + Math.max(1, loads - 8), 'up', '8', UP, C.green),
          M('AVG TONS / LOAD', tons, 't', 'best ' + (parseFloat(tons) + 1.1).toFixed(1) + 't @ 09:48', 'up', '0.3', WAVE, C.blue),
          M('ERRORS / REJECTS', err, '', '7-day clean streak', 'down', '1', DOWN, C.amber),
        ];
      }
      case 'security': {
        const gc = badge(/gate/i) || pick(4, 14); const flags = num((p.badges.find((x) => /flag/i.test(x.t)) || {}).t || p.meta) || 0;
        return [
          M('GATE CHECKS', gc, '', 'weekly avg ' + Math.max(1, gc - 2), 'up', '3', UP, C.green),
          M('TRUCKS CLEARED', pick(22, 58), '', 'through gate today', 'up', '6', WAVE, C.blue),
          M('FLAGS RAISED', flags, '', flags ? 'review pending' : 'none this shift', flags ? 'up' : 'down', '1', flags ? UP : DOWN, flags ? C.red : C.amber),
        ];
      }
      case 'super': {
        return [
          M('CREW ON SHIFT', pick(8, 16), '', 'assigned to you', 'flat', null, [6, 6, 5, 6, 6, 5, 6, 6], C.blue),
          M('APPROVALS', pick(4, 14), '', 'sign-offs today', 'up', '4', UP, C.green),
          M('INCIDENTS', pick(0, 1), '', '0 = clean shift', 'down', '1', DOWN, C.amber),
        ];
      }
      case 'admin': {
        return [
          M('APPROVALS', pick(6, 22), '', 'requests this week', 'up', '5', UP, C.green),
          M('SEATS MANAGED', pick(18, 60), '', 'active company seats', 'flat', null, [5, 6, 6, 5, 6, 6, 6, 6], C.blue),
          M('SIGN-INS', pick(40, 140), '', 'across org · 30-day', 'up', '12', WAVE, C.green),
        ];
      }
      case 'procure': {
        const wb = badge(/waybill/i) || pick(8, 20); const open = num(p.meta) || pick(0, 3);
        return [
          M('WAYBILLS', wb, '', 'raised this month', 'up', '4', UP, C.green),
          M('RECONS CLOSED', pick(6, 18), '', 'this month', 'up', '3', WAVE, C.blue),
          M('OPEN RECONS', open, '', open ? 'awaiting match' : 'all cleared', open ? 'up' : 'down', '1', open ? UP : DOWN, C.amber),
        ];
      }
      case 'fleet': {
        const trucks = badge(/truck/i) || pick(20, 42); const svc = num(p.meta) || pick(3, 8);
        return [
          M('TRUCKS MANAGED', trucks, '', 'in your fleet', 'flat', null, [6, 6, 6, 5, 6, 6, 6, 6], C.blue),
          M('DISPATCHED', pick(10, 40), '', 'trips today', 'up', '5', UP, C.green),
          M('IN SERVICE', svc, '', 'on the road now', 'flat', null, WAVE, C.green),
        ];
      }
      case 'driver': {
        const trips = badge(/trip/i) || pick(8, 24); const pod = num(p.meta) || pick(90, 99); const km = pick(180, 820);
        return [
          M('TRIPS', trips, '', 'this month', 'up', '4', UP, C.green),
          M('POD RATE', pod, '%', 'proof-of-delivery signed', 'up', '2', WAVE, C.blue),
          M('DISTANCE', km, ' km', 'covered today', 'up', '18', UP, C.green),
        ];
      }
      default:
        return [
          M('TASKS', pick(4, 18), '', 'completed today', 'up', '3', UP, C.green),
          M('ACTIVE', pick(2, 8), '', 'in progress', 'flat', null, WAVE, C.blue),
          M('FLAGS', pick(0, 1), '', 'open', 'down', '1', DOWN, C.amber),
        ];
    }
  }

  /* role → today's activity feed (last 24h). Deterministic per person. */
  function roleActivity(p, key) {
    const rnd = seed(p.id + 'act');
    const t = (h, m) => String(h).padStart(2, '0') + ':' + String(m).padStart(2, '0');
    const clockIn = { b: 'Clocked in', r: ' · biometric gate · North entrance', time: t(5, 2 + Math.round(rnd() * 8)), tone: 'on' };
    const online = { b: 'Online', r: ' · currently at station', time: 'now', tone: 'on' };
    const radio = { b: 'Radio ping', r: ' from supervisor Vusi K.', time: t(11, 22), tone: 'amber' };
    const brk = { b: 'Break', r: ' · 22 min', time: t(9, 15), tone: 'blue' };
    const byKey = {
      load: [clockIn, { b: 'Load #01 logged', r: ' · 3.4t · truck HH-402', time: t(5, 38), tone: 'blue' }, { b: '14 loads processed', r: ' · avg 3.0t', time: '05:38 – 09:15', tone: 'blue' }, brk, { b: 'Best load', r: ' · 4.2t · truck HH-311', time: t(9, 48), tone: 'blue' }, { b: '28 more loads processed', r: '', time: '09:37 – 11:40', tone: 'blue' }, radio, online],
      security: [clockIn, { b: 'Gate check', r: ' · truck HH-118 cleared', time: t(6, 12), tone: 'green' }, { b: '9 trucks cleared', r: ' · North gate', time: '06:12 – 09:04', tone: 'blue' }, brk, { b: 'Flag raised', r: ' · seal mismatch HH-244', time: t(10, 26), tone: 'red' }, radio, online],
      super: [clockIn, { b: 'Shift brief', r: ' · 12 crew assigned', time: t(5, 20), tone: 'blue' }, { b: 'Approved', r: ' · 4 load sign-offs', time: '06:00 – 09:00', tone: 'green' }, brk, { b: 'Toolbox talk', r: ' · Pit 3 safety', time: t(10, 5), tone: 'blue' }, online],
      admin: [{ b: 'Signed in', r: ' · web · Johannesburg', time: t(7, 40), tone: 'on' }, { b: 'Approved', r: ' · seat expansion · Atlas', time: t(8, 15), tone: 'green' }, { b: 'Issued token', r: ' · Corridor Freight', time: t(9, 2), tone: 'blue' }, { b: 'Reviewed', r: ' · 3 role changes', time: t(10, 30), tone: 'blue' }, online],
      procure: [{ b: 'Signed in', r: ' · web', time: t(7, 55), tone: 'on' }, { b: 'Waybill raised', r: ' · WB-1042', time: t(8, 30), tone: 'blue' }, { b: 'Recon closed', r: ' · Region North', time: t(9, 40), tone: 'green' }, brk, online],
      fleet: [{ b: 'Signed in', r: ' · depot terminal', time: t(6, 10), tone: 'on' }, { b: 'Dispatched', r: ' · 6 trucks · N3', time: t(6, 45), tone: 'blue' }, { b: 'Route assigned', r: ' · HH-402 → Saldanha', time: t(8, 20), tone: 'blue' }, radio, online],
      driver: [{ b: 'Started trip', r: ' · N3 southbound', time: t(5, 30), tone: 'on' }, { b: 'POD uploaded', r: ' · trip #18', time: t(8, 12), tone: 'green' }, { b: 'Fuel stop', r: ' · 22 min', time: t(9, 40), tone: 'blue' }, { b: 'On route', r: ' · 320 km covered', time: 'now', tone: 'on' }],
    };
    return byKey[key] || [clockIn, online];
  }

  function roleNote(p, key) {
    const notes = {
      load: { title: 'Site induction renewal due', body: p.name.split(' ')[0] + "'s annual site induction expires in 42 days. Schedule a slot before the renewal window closes on 15 Aug 2026.", by: 'Nadia P.', ago: '3 days ago' },
      security: { title: 'PSIRA certificate check', body: 'Confirm PSIRA grade on file is current before next roster. No action needed if renewed in the last 12 months.', by: 'Nadia P.', ago: '1 week ago' },
      super: { title: 'Blast ticket expiry', body: 'Blasting certificate valid — next competency refresher recommended within 6 months.', by: 'Pieter B.', ago: '2 weeks ago' },
      driver: { title: 'PrDP renewal window', body: "Professional driving permit renews within the quarter. Keep licence and PrDP copies current in Documents.", by: 'Riaan S.', ago: '5 days ago' },
    };
    return notes[key] || { title: 'No open flags', body: 'This employee has no outstanding notes or compliance flags.', by: 'System', ago: 'today' };
  }

  /* ---- profile sub-pieces ---- */
  function PCard({ title, right, pad = 18, children }) {
    const C = useTH();
    return (
      <section style={{ background: C.panel, border: `1px solid ${C.line}`, borderRadius: 18, overflow: 'hidden' }}>
        {title && (
          <div style={{ display: 'flex', alignItems: 'center', gap: 8, padding: '13px 18px', borderBottom: `1px solid ${C.lineSoft}` }}>
            <span style={{ width: 5, height: 5, borderRadius: 999, background: C.accent }} />
            <span style={{ fontSize: 10.5, fontWeight: 700, letterSpacing: '.13em', color: C.faint, flex: 1 }}>{title}</span>
            {right}
          </div>
        )}
        <div style={{ padding: pad }}>{children}</div>
      </section>
    );
  }

  function AreaSpark({ data, color, h = 40 }) {
    const w = 200; const min = Math.min(...data), max = Math.max(...data), rng = max - min || 1;
    const P = data.map((v, i) => [(i / (data.length - 1)) * w, h - ((v - min) / rng) * (h - 8) - 4]);
    const line = P.map((p) => p.join(',')).join(' ');
    const area = '0,' + h + ' ' + line + ' ' + w + ',' + h;
    const id = 'as' + Math.random().toString(36).slice(2, 8);
    return (
      <svg viewBox={`0 0 ${w} ${h}`} width="100%" height={h} preserveAspectRatio="none" style={{ display: 'block' }}>
        <defs><linearGradient id={id} x1="0" y1="0" x2="0" y2="1"><stop offset="0" style={{ stopColor: color, stopOpacity: 0.26 }} /><stop offset="1" style={{ stopColor: color, stopOpacity: 0 }} /></linearGradient></defs>
        <polygon points={area} fill={`url(#${id})`} />
        <polyline points={line} fill="none" strokeWidth="2" strokeLinecap="round" strokeLinejoin="round" style={{ stroke: color }} />
      </svg>
    );
  }

  function PMetric({ m }) {
    const C = useTH();
    const dc = m.dir === 'up' ? C.green : m.dir === 'down' ? C.red : C.faint;
    return (
      <div style={{ flex: 1, minWidth: 0, padding: '13px 14px', borderRadius: 14, background: C.chip, border: `1px solid ${C.lineSoft}`, display: 'flex', flexDirection: 'column' }}>
        <div style={{ display: 'flex', justifyContent: 'space-between', alignItems: 'flex-start', gap: 6, minHeight: 26 }}>
          <span style={{ fontSize: 9.5, fontWeight: 700, letterSpacing: '.09em', color: C.faint, lineHeight: 1.35 }}>{m.label}</span>
          {m.delta != null && <span style={{ display: 'inline-flex', alignItems: 'center', color: dc, fontSize: 11, fontFamily: C.mono, flexShrink: 0 }}><Icon name={m.dir === 'up' ? 'arrow_drop_up' : 'arrow_drop_down'} size={15} color={dc} />{m.delta}</span>}
        </div>
        <div style={{ fontFamily: C.serif, fontSize: 32, fontWeight: 700, color: C.strong, lineHeight: 1, marginTop: 4 }}>{m.value}{m.unit && <span style={{ fontSize: 15, color: C.muted, fontFamily: C.serif }}>{m.unit}</span>}</div>
        <div style={{ fontSize: 10, color: C.faint, marginTop: 5, marginBottom: 8 }}>{m.sub}</div>
        <div style={{ marginTop: 'auto' }}><AreaSpark data={m.spark} color={m.color} /></div>
      </div>
    );
  }

  const ACT_TONE = { on: 'green', green: 'green', blue: 'blue', amber: 'amber', red: 'red' };
  function FullProfile({ sel, otype, coName, canManage, flat, onSelect, onClose }) {
    const C = useTH();
    React.useEffect(() => {
      if (!sel) return;
      const h = (e) => { if (e.key === 'Escape') onClose(); };
      window.addEventListener('keydown', h);
      return () => window.removeEventListener('keydown', h);
    }, [sel]);
    if (!sel) return null;
    const p = sel.person, group = sel.group;
    const t = C.GTONE[group.key] || C.GTONE.super;
    const presColor = C.PRES[p.presence];
    const metrics = roleMetrics(p, group.key, C);
    const activity = roleActivity(p, group.key);
    const note = roleNote(p, group.key);
    const sup = SUPERVISOR[otype] || SUPERVISOR.Mine;
    const isLeader = group.key === 'admin';
    const idx = flat.findIndex((f) => f.person.id === p.id && f.person.name === p.name);
    const go = (d) => { const n = (idx + d + flat.length) % flat.length; onSelect(flat[n]); };
    const shiftPct = 56;

    const L = { fontSize: 10, fontWeight: 700, letterSpacing: '.12em', color: C.faint, textTransform: 'uppercase' };
    const iconBtn = { width: 34, height: 34, borderRadius: 9, border: `1px solid ${C.line}`, background: C.chip, color: C.body, cursor: 'pointer', display: 'flex', alignItems: 'center', justifyContent: 'center' };
    const infoTile = (lab, val, sub) => (
      <div style={{ padding: '11px 13px', borderRadius: 12, background: C.chip, border: `1px solid ${C.lineSoft}` }}>
        <div style={{ fontSize: 9.5, fontWeight: 700, letterSpacing: '.1em', color: C.faint }}>{lab}</div>
        <div style={{ fontSize: 13.5, fontWeight: 700, color: C.strong, marginTop: 4, fontFamily: C.mono }}>{val}</div>
        {sub && <div style={{ fontSize: 10.5, color: C.faint, marginTop: 2 }}>{sub}</div>}
      </div>
    );

    return (
      <div style={{ position: 'fixed', inset: 0, zIndex: 60, background: C.bg, backgroundImage: C.veil, overflowY: 'auto', animation: 'mlEmpFade .18s ease', fontFamily: C.sans }}>
        <div style={{ maxWidth: 1560, margin: '0 auto', padding: '20px 30px 40px' }}>
          {/* header */}
          <div style={{ display: 'flex', alignItems: 'center', gap: 14, marginBottom: 24 }}>
            <button type="button" onClick={onClose} style={{ ...iconBtn, width: 36, height: 36 }}><Icon name="chevron_left" size={20} /></button>
            <div style={{ display: 'flex', alignItems: 'center', gap: 8, fontSize: 11.5, fontWeight: 700, letterSpacing: '.13em', color: C.faint }}>EMPLOYEES <span style={{ opacity: .5 }}>/</span> EMPLOYEE REGISTER <span style={{ opacity: .5 }}>/</span> <span style={{ color: C.strong }}>{p.name.toUpperCase()}</span></div>
            <div style={{ flex: 1 }} />
            <span style={{ display: 'inline-flex', alignItems: 'center', gap: 7, fontSize: 11.5, color: C.okText, background: C.okBg, border: `1px solid ${C.okBd}`, borderRadius: 999, padding: '6px 12px' }}><span style={{ width: 7, height: 7, borderRadius: 999, background: C.green, boxShadow: `0 0 0 3px ${C.okGlow}` }} />Live · Synced 8s ago</span>
            <button type="button" title="Previous employee" onClick={() => go(-1)} style={iconBtn}><Icon name="chevron_left" size={18} /></button>
            <button type="button" title="Next employee" onClick={() => go(1)} style={iconBtn}><Icon name="chevron_right" size={18} /></button>
            <button type="button" title="Notifications" style={{ ...iconBtn, position: 'relative' }}><Icon name="notifications" size={18} /><span style={{ position: 'absolute', top: 6, right: 7, width: 6, height: 6, borderRadius: 999, background: C.amber }} /></button>
            <button type="button" title="More" style={iconBtn}><Icon name="more_horiz" size={18} /></button>
            <button type="button" title="Close" onClick={onClose} style={iconBtn}><Icon name="close" size={18} /></button>
          </div>

          {/* 3-column grid */}
          <div className="ml-prof-grid">
            {/* ---- LEFT ---- */}
            <div style={{ display: 'flex', flexDirection: 'column', gap: 20 }}>
              <div style={{ background: `linear-gradient(160deg, ${t.bg}, ${C.panel})`, border: `1px solid ${C.line}`, borderRadius: 20, padding: 22 }}>
                <div style={{ display: 'flex', gap: 16 }}>
                  <div style={{ position: 'relative', flexShrink: 0 }}>
                    <div style={{ width: 78, height: 78, borderRadius: 20, background: t.bg, color: t.fg, border: `1px solid ${t.bd}`, display: 'flex', alignItems: 'center', justifyContent: 'center', fontWeight: 700, fontSize: 27 }}>{initials(p.name)}</div>
                    <span style={{ position: 'absolute', right: -3, bottom: -3, width: 18, height: 18, borderRadius: 999, background: presColor, border: `3px solid ${C.bg}` }} />
                  </div>
                  <div style={{ flex: 1, minWidth: 0 }}>
                    <div style={{ display: 'flex', alignItems: 'center', gap: 8 }}>
                      <span style={{ fontFamily: C.serif, fontSize: 30, fontWeight: 700, color: C.strong, lineHeight: 1 }}>{p.name.split(' ')[0]} <span style={{ fontStyle: 'italic', fontWeight: 600 }}>{p.name.split(' ').slice(1).join(' ')}</span></span>
                      {p.verified && <Icon name="verified" size={18} color={C.blue} fill={1} />}
                    </div>
                    <div style={{ display: 'flex', alignItems: 'center', gap: 8, marginTop: 10, flexWrap: 'wrap' }}>
                      <span style={{ display: 'inline-flex', alignItems: 'center', gap: 6, fontSize: 10.5, fontWeight: 700, letterSpacing: '.05em', textTransform: 'uppercase', color: t.fg, background: C.roleChipBg, padding: '4px 10px', borderRadius: 999, border: `1px solid ${t.bd}` }}><span style={{ width: 6, height: 6, borderRadius: 999, background: t.fg }} />{p.role}</span>
                      <span style={{ fontFamily: C.mono, fontSize: 11, color: C.faint, background: C.chip, border: `1px solid ${C.line}`, borderRadius: 6, padding: '2px 7px' }}>{p.id}</span>
                    </div>
                    <div style={{ fontSize: 12.5, color: C.muted, marginTop: 10 }}>{coName} · {group.label}</div>
                    <div style={{ fontSize: 12.5, color: C.faint }}>{p.post}</div>
                  </div>
                </div>
                <div style={{ display: 'inline-flex', alignItems: 'center', gap: 7, marginTop: 16, fontSize: 11.5, fontWeight: 600, color: C.muted, background: C.chip, border: `1px solid ${C.line}`, borderRadius: 999, padding: '6px 12px' }}><Icon name={canManage ? 'manage_accounts' : 'lock'} size={14} color={C.faint} />{canManage ? 'Managed profile' : 'Read-only profile'}</div>
                <div style={{ display: 'flex', alignItems: 'center', gap: 10, marginTop: 14, padding: '10px 14px', borderRadius: 12, background: C.chip, border: `1px solid ${C.lineSoft}` }}>
                  <span style={{ display: 'inline-flex', alignItems: 'center', gap: 7, fontSize: 13, fontWeight: 600, color: presColor }}><span style={{ width: 8, height: 8, borderRadius: 999, background: presColor }} />{p.presence === 'online' ? 'Online now · On shift' : p.presence === 'away' ? 'Away' : 'Offline'}</span>
                  <span style={{ flex: 1 }} />
                  <span style={{ fontSize: 11, color: C.faint, fontFamily: C.mono }}>last ping · 8s ago</span>
                </div>
                <div style={{ display: 'flex', gap: 10, marginTop: 16 }}>
                  <button type="button" onClick={() => { window.location.href = '../chat/index.html'; }} style={{ flex: 1, display: 'inline-flex', alignItems: 'center', justifyContent: 'center', gap: 8, padding: '12px 0', borderRadius: 12, border: 'none', cursor: 'pointer', background: C.ctaBg, color: C.ctaFg, fontSize: 14, fontWeight: 600, fontFamily: C.sans }}><Icon name="chat" size={18} />Message {p.name.split(' ')[0]}</button>
                  <button type="button" title="Call" style={{ ...iconBtn, width: 46, height: 46, borderRadius: 12 }}><Icon name="call" size={19} /></button>
                  <button type="button" title="Chat" style={{ ...iconBtn, width: 46, height: 46, borderRadius: 12 }}><Icon name="sms" size={19} /></button>
                  <button type="button" title="Radio" style={{ ...iconBtn, width: 46, height: 46, borderRadius: 12 }}><Icon name="sensors" size={19} /></button>
                </div>
              </div>

              <PCard title="CONTACT & IDENTITY" right={<span style={{ fontSize: 10.5, color: C.faint }}>Hover to copy</span>} pad={'4px 18px 14px'}>
                <ProfileRow icon="badge" label="Employee ID" value={p.id} mono />
                <ProfileRow icon="work" label="Role" value={p.role} />
                {p.email && <ProfileRow icon="mail" label="Email" value={p.email} />}
                <ProfileRow icon="chat" label="WhatsApp" value={p.wa} mono />
                <ProfileRow icon="fingerprint" label="ID number" value={p.idno} mono />
                {!p.email && <div style={{ display: 'flex', alignItems: 'center', gap: 9, marginTop: 11, padding: '9px 12px', background: C.okBg, border: `1px solid ${C.okBd}`, borderRadius: 10 }}><Icon name="chat" size={16} color={C.green} /><span style={{ fontSize: 12, color: C.okText }}>WhatsApp-only account — signs in with their WhatsApp number.</span></div>}
              </PCard>

              <PCard title={'DOCUMENTS · ' + (p.docs ? p.docs.length : 0)} right={<span style={{ fontSize: 10.5, color: C.green, fontWeight: 600 }}>All verified</span>}>
                <div style={{ display: 'flex', flexDirection: 'column', gap: 10 }}>
                  {(p.docs || []).map((d, i) => {
                    const expiring = /cert|induction|licence|prdp/i.test(d);
                    return (
                      <div key={i} style={{ display: 'flex', alignItems: 'center', gap: 12, padding: '11px 12px', borderRadius: 12, background: C.chip, border: `1px solid ${C.lineSoft}` }}>
                        <div style={{ width: 36, height: 36, borderRadius: 9, background: C.redBg, border: `1px solid ${C.redBd}`, display: 'flex', alignItems: 'center', justifyContent: 'center', flexShrink: 0 }}><Icon name="description" size={18} color={C.red} /></div>
                        <div style={{ flex: 1, minWidth: 0 }}>
                          <div style={{ fontSize: 13, fontWeight: 700, color: C.strong, whiteSpace: 'nowrap', overflow: 'hidden', textOverflow: 'ellipsis' }}>{d}</div>
                          <div style={{ fontSize: 10.5, color: C.faint, marginTop: 3 }}>{(300 + i * 280)} KB · {expiring ? 'renewed Jun 2025' : 'uploaded Jan 2020'}</div>
                          <span style={{ display: 'inline-block', marginTop: 6, fontSize: 9.5, fontWeight: 700, padding: '2px 7px', borderRadius: 6, color: expiring ? C.amber : C.green, background: expiring ? 'transparent' : C.okBg, border: `1px solid ${expiring ? C.line : C.okBd}` }}>{expiring ? 'Expires 14 mo' : 'Verified'}</span>
                        </div>
                        <div style={{ display: 'flex', gap: 6, flexShrink: 0 }}>
                          <button type="button" title="View" style={{ ...iconBtn, width: 30, height: 30 }}><Icon name="visibility" size={15} /></button>
                          <button type="button" title="Download" style={{ ...iconBtn, width: 30, height: 30 }}><Icon name="download" size={15} /></button>
                        </div>
                      </div>
                    );
                  })}
                  {canManage && <button type="button" style={{ display: 'inline-flex', alignItems: 'center', justifyContent: 'center', gap: 7, padding: '10px 0', borderRadius: 11, border: `1px dashed ${C.line}`, background: 'transparent', color: C.muted, fontSize: 12.5, fontWeight: 600, cursor: 'pointer', fontFamily: C.sans }}><Icon name="upload_file" size={16} />Upload document</button>}
                </div>
              </PCard>
            </div>

            {/* ---- MIDDLE ---- */}
            <div style={{ display: 'flex', flexDirection: 'column', gap: 20 }}>
              <PCard title="TODAY'S SHIFT" right={<span style={{ display: 'inline-flex', alignItems: 'center', gap: 5, fontSize: 10.5, color: C.green, fontWeight: 700 }}><span style={{ width: 6, height: 6, borderRadius: 999, background: C.green }} />LIVE</span>}>
                <div style={{ display: 'flex', alignItems: 'baseline', justifyContent: 'space-between' }}>
                  <span style={{ fontFamily: C.serif, fontSize: 21, fontWeight: 700, color: C.strong }}>{p.post}</span>
                  <span style={{ fontFamily: C.mono, fontSize: 13, color: C.body }}>05:00 → 17:00</span>
                </div>
                <div style={{ position: 'relative', height: 8, borderRadius: 999, background: C.chip, border: `1px solid ${C.lineSoft}`, marginTop: 14 }}>
                  <div style={{ position: 'absolute', left: 0, top: 0, bottom: 0, width: shiftPct + '%', borderRadius: 999, background: `linear-gradient(90deg, ${C.blue}, ${C.green})` }} />
                  <div style={{ position: 'absolute', left: shiftPct + '%', top: '50%', width: 14, height: 14, borderRadius: 999, background: C.strong, border: `3px solid ${C.bg}`, transform: 'translate(-50%,-50%)' }} />
                </div>
                <div style={{ display: 'flex', justifyContent: 'space-between', marginTop: 6, fontFamily: C.mono, fontSize: 10.5, color: C.faint }}><span>05:00</span><span>08:00</span><span>11:00</span><span>14:00</span><span>17:00</span></div>
                <div style={{ display: 'flex', gap: 26, marginTop: 16 }}>
                  <div><div style={L}>SHIFT PROGRESS</div><div style={{ fontSize: 14, fontWeight: 700, color: C.green, marginTop: 5, fontFamily: C.mono }}>{shiftPct}% · 6h 42m</div></div>
                  <div><div style={L}>LAST BREAK</div><div style={{ fontSize: 14, fontWeight: 700, color: C.strong, marginTop: 5, fontFamily: C.mono }}>09:15 · 22m</div></div>
                  <div><div style={L}>NEXT CHECK-IN</div><div style={{ fontSize: 14, fontWeight: 700, color: C.amber, marginTop: 5, fontFamily: C.mono }}>12:00</div></div>
                </div>
              </PCard>

              <PCard title="TODAY'S PRODUCTIVITY" right={<span style={{ fontSize: 10.5, color: C.faint }}>vs. weekly avg</span>}>
                <div style={{ display: 'flex', gap: 12 }}>
                  {metrics.map((m, i) => <PMetric key={i} m={m} />)}
                </div>
              </PCard>

              <PCard title="LOCATION & ASSIGNMENT" right={<span style={{ fontSize: 10.5, color: C.faint }}>Auto-detected · 8s ago</span>}>
                <div style={{ display: 'flex', alignItems: 'center', gap: 14 }}>
                  <div style={{ width: 46, height: 46, borderRadius: 12, background: t.bg, border: `1px solid ${t.bd}`, display: 'flex', alignItems: 'center', justifyContent: 'center', flexShrink: 0 }}><Icon name="location_on" size={22} color={t.fg} /></div>
                  <div style={{ flex: 1, minWidth: 0 }}>
                    <div style={{ fontSize: 15, fontWeight: 700, color: C.strong }}>{p.post.split(' · ').pop()}</div>
                    <div style={{ fontSize: 12, color: C.muted }}>{coName} · Zone 2</div>
                  </div>
                  <span style={{ display: 'inline-flex', alignItems: 'center', gap: 6, fontSize: 11, fontWeight: 700, color: C.green, background: C.okBg, border: `1px solid ${C.okBd}`, borderRadius: 999, padding: '5px 11px' }}><span style={{ width: 6, height: 6, borderRadius: 999, background: C.green }} />ON-SITE</span>
                </div>
                <div style={{ position: 'relative', height: 168, borderRadius: 14, marginTop: 14, background: C.chip, border: `1px solid ${C.lineSoft}`, overflow: 'hidden' }}>
                  <svg viewBox="0 0 400 168" width="100%" height="168" preserveAspectRatio="none" style={{ position: 'absolute', inset: 0 }}>
                    <ellipse cx="205" cy="92" rx="150" ry="52" fill="none" strokeWidth="1.5" strokeDasharray="5 6" style={{ stroke: C.line }} />
                    <path d="M60 118 Q170 60 320 96" fill="none" strokeWidth="1.5" strokeDasharray="4 5" style={{ stroke: C.green, opacity: 0.7 }} />
                    <circle cx="215" cy="88" r="6" style={{ fill: C.blue }} />
                    <circle cx="215" cy="88" r="12" fill="none" strokeWidth="1.5" style={{ stroke: C.blue, opacity: 0.5 }} />
                  </svg>
                  <span style={{ position: 'absolute', top: 12, right: 14, fontFamily: C.mono, fontSize: 9.5, letterSpacing: '.12em', color: C.faint }}>{coName.split(' ')[0].toUpperCase()} · ZONE 2</span>
                  <span style={{ position: 'absolute', left: 14, bottom: 12, fontFamily: C.mono, fontSize: 10.5, color: C.body }}>{p.post.split(' · ').pop()}<br /><span style={{ color: C.faint }}>-25.7461° · 27.4523°</span></span>
                </div>
                <div style={{ display: 'flex', alignItems: 'center', gap: 12, marginTop: 14 }}>
                  <div style={{ width: 38, height: 38, borderRadius: 10, background: C.GTONE.super.bg, color: C.GTONE.super.fg, border: `1px solid ${C.GTONE.super.bd}`, display: 'flex', alignItems: 'center', justifyContent: 'center', fontWeight: 700, fontSize: 13, flexShrink: 0 }}>{sup.init}</div>
                  <div style={{ flex: 1, minWidth: 0 }}>
                    <div style={{ fontSize: 9.5, fontWeight: 700, letterSpacing: '.11em', color: C.faint }}>{isLeader ? 'REPORTS TO' : 'REPORTING SUPERVISOR'}</div>
                    <div style={{ fontSize: 13.5, fontWeight: 700, color: C.strong, marginTop: 2 }}>{isLeader ? 'Board / Directors' : sup.name + ' · ' + sup.role}</div>
                  </div>
                  {!isLeader && <span style={{ display: 'inline-flex', alignItems: 'center', gap: 6, fontSize: 11, color: C.green }}><span style={{ width: 6, height: 6, borderRadius: 999, background: C.green }} />Online</span>}
                </div>
              </PCard>
            </div>

            {/* ---- RIGHT ---- */}
            <div style={{ display: 'flex', flexDirection: 'column', gap: 20 }}>
              <PCard title="ACTIVITY · LAST 24H" right={<a href="../notifications/index.html" style={{ fontSize: 10.5, color: C.accent, textDecoration: 'none', fontWeight: 600 }}>View full log →</a>}>
                <div style={{ position: 'relative', paddingLeft: 6 }}>
                  {activity.map((a, i) => {
                    const dot = C[ACT_TONE[a.tone] || 'blue'] || C.blue;
                    return (
                      <div key={i} style={{ display: 'flex', gap: 12, position: 'relative', paddingBottom: i < activity.length - 1 ? 16 : 0 }}>
                        <div style={{ display: 'flex', flexDirection: 'column', alignItems: 'center', flexShrink: 0 }}>
                          <span style={{ width: 9, height: 9, borderRadius: 999, background: 'transparent', border: `2px solid ${dot}`, marginTop: 3 }} />
                          {i < activity.length - 1 && <span style={{ flex: 1, width: 1.5, background: C.lineSoft, marginTop: 2 }} />}
                        </div>
                        <div style={{ flex: 1, minWidth: 0, display: 'flex', justifyContent: 'space-between', gap: 10 }}>
                          <span style={{ fontSize: 12.5, color: C.body, lineHeight: 1.4 }}><b style={{ color: C.strong, fontWeight: 700 }}>{a.b}</b>{a.r}</span>
                          <span style={{ fontFamily: C.mono, fontSize: 10.5, color: C.faint, whiteSpace: 'nowrap', flexShrink: 0 }}>{a.time}</span>
                        </div>
                      </div>
                    );
                  })}
                </div>
              </PCard>

              <PCard title="ROLE SNAPSHOT" right={<span style={{ fontSize: 10.5, color: C.faint }}>updated by {sup.name.split(' ')[0]} {sup.name.split(' ')[1] ? sup.name.split(' ')[1][0] + '.' : ''}</span>}>
                <div style={{ display: 'grid', gridTemplateColumns: '1fr 1fr', gap: 10, marginBottom: 12 }}>
                  {infoTile('TENURE', (p.tenure || p.meta || '—').replace(' tenure', ''), 'since ' + (p.joined || '—'))}
                  {infoTile('POSTING', p.post.split(' · ')[0] || p.post, p.post.split(' · ')[1] || '')}
                  {infoTile('RADIO CHANNEL', (p.badges.find((b) => /Ch\./.test(p.meta)) ? p.meta : (p.meta && /Ch\./.test(p.meta) ? p.meta : 'Ch. 4 · Loads')), '')}
                  {infoTile('PERMISSIONS', canManage ? 'Full · R/W' : (group.key === 'load' ? 'Loads · R/W' : group.key === 'security' ? 'Gate · R/W' : 'Scoped'), '')}
                </div>
                <div style={{ display: 'flex', flexWrap: 'wrap', gap: 7 }}>
                  {p.badges.map((b, i) => <Chip key={i} t={b.t} k={b.k} />)}
                </div>
              </PCard>

              <PCard title="NOTES & FLAGS" right={<span style={{ fontSize: 10.5, color: C.faint }}>{note.title === 'No open flags' ? '0 open' : '1 open'}</span>}>
                <div style={{ display: 'flex', gap: 12, padding: '13px 14px', borderRadius: 12, background: C.chip, border: `1px solid ${C.lineSoft}`, borderLeft: `3px solid ${note.title === 'No open flags' ? C.green : C.amber}` }}>
                  <Icon name={note.title === 'No open flags' ? 'check_circle' : 'warning'} size={18} color={note.title === 'No open flags' ? C.green : C.amber} />
                  <div style={{ flex: 1, minWidth: 0 }}>
                    <div style={{ fontSize: 13.5, fontWeight: 700, color: C.strong }}>{note.title}</div>
                    <div style={{ fontSize: 12, color: C.muted, marginTop: 5, lineHeight: 1.5 }}>{note.body}</div>
                    <div style={{ fontSize: 10.5, color: C.faint, marginTop: 8 }}>Opened by {note.by} · {note.ago}</div>
                  </div>
                </div>
                {canManage && <button type="button" style={{ display: 'inline-flex', alignItems: 'center', justifyContent: 'center', gap: 7, width: '100%', marginTop: 10, padding: '10px 0', borderRadius: 11, border: `1px solid ${C.line}`, background: C.chip, color: C.body, fontSize: 12.5, fontWeight: 600, cursor: 'pointer', fontFamily: C.sans }}><Icon name="add" size={16} />Add note or flag</button>}
              </PCard>
            </div>
          </div>

          {/* footer */}
          <div style={{ display: 'flex', alignItems: 'center', gap: 16, marginTop: 26, paddingTop: 18, borderTop: `1px solid ${C.line}` }}>
            <span style={{ display: 'inline-flex', alignItems: 'center', gap: 7, fontSize: 11.5, color: C.faint }}><Icon name="check" size={15} color={C.green} />Live profile · Auto-updates on any change · Synced 8s ago</span>
            <div style={{ flex: 1 }} />
            <button type="button" style={{ display: 'inline-flex', alignItems: 'center', gap: 7, border: `1px solid ${C.line}`, background: C.chip, color: C.body, borderRadius: 10, padding: '9px 15px', fontSize: 12.5, fontWeight: 600, cursor: 'pointer', fontFamily: C.sans }}><Icon name="download" size={16} />Export profile PDF</button>
          </div>
        </div>
      </div>
    );
  }

  window.MLEmployeeRegister = { Register, EMP_DATA };
})();
