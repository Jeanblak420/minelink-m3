/* MineLink — Super Admin: remaining screens (Insights, Token requests/history,
 * Audit logs, Account security, Platform settings, Register company,
 * Requested product/buyers). Faithful to lib/features/super_admin. Merges into
 * window.AdminScreens. Loaded after screens.jsx. */
const DSx = window.MineLinkDesignSystem_9acfde;
const { Icon: IcX, StatusBadge: BdgX, Button: BtnX2, Avatar: AvX, Input: InX, Select: SelX, Switch: SwX, Icon3D: Ic3X } = DSx;
const { SectionTitle: STitleX, DataTable: TblX } = window.MLShell;

const OT = { Mine: 'cyan', Buyer: 'amber', Transporter: 'green' };
const OT_BADGE = { Mine: 'transit', Buyer: 'atmine', Transporter: 'done' };
const O3 = { Mine: 'mine', Buyer: 'buyer', Transporter: 'shipment' };
const CO = window.__ADMIN_COMPANIES__ || [];

/* ---------- Insights (per org type) ---------- */
/* Per-company monthly ops stats — mirrors CompanyMonthlyOpsStats (current calendar month).
 * Metrics: employees, drivers, fleet, routes, trips, loads, tons, wbDone, wbOpen. */
const INSIGHT_ROWS = {
  transporter: [
    { id: 'roadhaul', name: 'Roadhaul Logistics', employees: 34, drivers: 28, fleet: 42, routes: 9, trips: 18, loads: 132, tons: 12420.5, wbDone: 140, wbOpen: 6 },
    { id: 'transafrican', name: 'Trans African Haul', employees: 26, drivers: 22, fleet: 31, routes: 7, trips: 14, loads: 98, tons: 9880.0, wbDone: 96, wbOpen: 9 },
    { id: 'corridor', name: 'Corridor Freight', employees: 19, drivers: 16, fleet: 23, routes: 5, trips: 10, loads: 71, tons: 6940.0, wbDone: 82, wbOpen: 3 },
  ],
  buyer: [
    { id: 'atlas', name: 'Atlas Buyer Group', employees: 12, drivers: 0, fleet: 0, routes: 11, trips: 22, loads: 204, tons: 18240.0, wbDone: 190, wbOpen: 12 },
    { id: 'pioneerb', name: 'Pioneer Mining', employees: 9, drivers: 0, fleet: 0, routes: 8, trips: 17, loads: 151, tons: 13120.0, wbDone: 142, wbOpen: 7 },
    { id: 'bathopele', name: 'Bathopele Trading', employees: 6, drivers: 0, fleet: 0, routes: 4, trips: 12, loads: 88, tons: 9820.0, wbDone: 70, wbOpen: 4 },
  ],
  mineSupplier: [
    { id: 'ironhills', name: 'Iron Hills Mining', employees: 41, drivers: 4, fleet: 6, routes: 14, trips: 28, loads: 268, tons: 44210.0, wbDone: 240, wbOpen: 15 },
    { id: 'pioneerm', name: 'Pioneer Mine', employees: 33, drivers: 3, fleet: 4, routes: 10, trips: 20, loads: 189, tons: 31200.0, wbDone: 168, wbOpen: 9 },
    { id: 'thabazimbi', name: 'Thabazimbi Mine', employees: 24, drivers: 2, fleet: 2, routes: 7, trips: 15, loads: 121, tons: 21010.0, wbDone: 103, wbOpen: 6 },
  ],
};
const INSIGHT_META = {
  transporter: { title: 'Transporters', icon: 'shipment', otype: 'Transporter' },
  buyer: { title: 'Buyers', icon: 'buyer', otype: 'Buyer' },
  mineSupplier: { title: 'Mines & Suppliers', icon: 'mine', otype: 'Mine' },
};

function InsightKpi({ icon, label, value, accent }) {
  return (
    <div style={{ background: 'var(--surface-card)', border: '1px solid var(--border-card)', borderRadius: 'var(--radius-lg)', boxShadow: 'var(--shadow-xs)', padding: 15, display: 'flex', flexDirection: 'column', gap: 8 }}>
      <div style={{ width: 34, height: 34, borderRadius: 10, background: accent + '1f', display: 'flex', alignItems: 'center', justifyContent: 'center' }}><IcX name={icon} size={18} color={accent} /></div>
      <div style={{ fontSize: 22, fontWeight: 800, color: 'var(--text-strong)', lineHeight: 1 }}>{value}</div>
      <div style={{ fontSize: 12, color: 'var(--text-muted)' }}>{label}</div>
    </div>
  );
}
function StatChip({ k, v }) {
  return <span style={{ fontSize: 12, fontWeight: 600, color: 'var(--text-body)', background: 'var(--surface-sunken)', padding: '4px 10px', borderRadius: 999 }}>{k}: <b style={{ color: 'var(--text-strong)' }}>{v}</b></span>;
}

/* Layer 2 — org-type insights: 6 KPIs + searchable per-company cards (9 metrics each) */
function AdminInsights({ type, openCompany }) {
  const meta = INSIGHT_META[type] || INSIGHT_META.transporter;
  const all = INSIGHT_ROWS[type] || [];
  const [q, setQ] = React.useState('');
  const rows = q ? all.filter((r) => r.name.toLowerCase().includes(q.toLowerCase())) : all;
  const agg = all.reduce((a, r) => ({ trips: a.trips + r.trips, fleet: a.fleet + r.fleet, tons: a.tons + r.tons, wbDone: a.wbDone + r.wbDone, wbOpen: a.wbOpen + r.wbOpen }), { trips: 0, fleet: 0, tons: 0, wbDone: 0, wbOpen: 0 });
  return (
    <div>
      <div style={{ display: 'flex', alignItems: 'center', gap: 12, marginBottom: 6 }}>
        <Ic3X name={meta.icon} size={44} />
        <div style={{ flex: 1 }}><h2 style={{ margin: 0, fontSize: 20, fontWeight: 800, color: 'var(--text-strong)' }}>{meta.title}</h2><div style={{ fontSize: 13, color: 'var(--text-muted)' }}>Combined organizations · current calendar month (local time)</div></div>
        <BtnX2 size="sm" variant="outline" icon="download">Export CSV</BtnX2>
      </div>
      <div style={{ maxWidth: 380, margin: '14px 0 18px' }}><InX icon="search" placeholder="Filter companies by name" value={q} onChange={(e) => setQ(e.target.value)} /></div>
      {/* 6-KPI summary row */}
      <div style={{ display: 'grid', gridTemplateColumns: 'repeat(6,1fr)', gap: 12, marginBottom: 22 }}>
        <InsightKpi icon="business" label="Companies" value={all.length} accent="#00b5d8" />
        <InsightKpi icon="route" label="Trips (mo.)" value={agg.trips} accent="#0891b2" />
        <InsightKpi icon="local_shipping" label="Fleet vehicles" value={agg.fleet} accent="#14b8a6" />
        <InsightKpi icon="inventory_2" label="Tons moved" value={agg.tons.toLocaleString(undefined, { maximumFractionDigits: 1 }) + ' t'} accent="#6366f1" />
        <InsightKpi icon="check_circle" label="Waybills done" value={agg.wbDone} accent="#22c55e" />
        <InsightKpi icon="pending_actions" label="Waybills open" value={agg.wbOpen} accent="#f59e0b" />
      </div>
      {/* Per-company cards */}
      <div style={{ display: 'flex', flexDirection: 'column', gap: 12 }}>
        {rows.map((r) => (
          <div key={r.id} onClick={() => openCompany && openCompany({ ...r, otype: meta.otype })} style={{ cursor: 'pointer', background: 'var(--surface-card)', border: '1px solid var(--border-card)', borderRadius: 'var(--radius-lg)', boxShadow: 'var(--shadow-xs)', padding: 18, transition: 'box-shadow .15s, transform .15s' }}
            onMouseEnter={(e) => { e.currentTarget.style.boxShadow = 'var(--shadow-md)'; e.currentTarget.style.transform = 'translateY(-2px)'; }}
            onMouseLeave={(e) => { e.currentTarget.style.boxShadow = 'var(--shadow-xs)'; e.currentTarget.style.transform = 'none'; }}>
            <div style={{ display: 'flex', alignItems: 'center', gap: 10 }}>
              <span style={{ fontSize: 16, fontWeight: 800, color: 'var(--text-strong)', flex: 1 }}>{r.name}</span>
              <IcX name="chevron_right" size={20} color="var(--text-faint)" />
            </div>
            <div style={{ display: 'flex', flexWrap: 'wrap', gap: 9, marginTop: 12 }}>
              <StatChip k="Employees" v={r.employees} /><StatChip k="Drivers" v={r.drivers} /><StatChip k="Fleet" v={r.fleet} />
              <StatChip k="Routes" v={r.routes} /><StatChip k="Trips" v={r.trips} /><StatChip k="Loads" v={r.loads} />
              <StatChip k="Tons" v={r.tons.toLocaleString(undefined, { maximumFractionDigits: 1 }) + ' t'} /><StatChip k="WB done" v={r.wbDone} /><StatChip k="WB open" v={r.wbOpen} />
            </div>
            <div style={{ marginTop: 10, fontSize: 12.5, color: 'var(--accent)', fontWeight: 600, display: 'flex', alignItems: 'center', gap: 5 }}><IcX name="visibility" size={14} />Open full read-only workspace</div>
          </div>
        ))}
        {rows.length === 0 && <div style={{ padding: 40, textAlign: 'center', color: 'var(--text-faint)', fontSize: 14 }}>No companies match "{q}".</div>}
      </div>
    </div>
  );
}

/* Layer 3 — read-only company mirror workspace: the org's own portal tabs, scoped & read-only */
const MIRROR_TABS = {
  Mine: [
    { key: 'dashboard', label: 'Dashboard', icon: 'dashboard' },
    { key: 'control', label: 'Control', icon: 'tune' },
    { key: 'stockpile', label: 'Stockpile', icon: 'terrain' },
    { key: 'buyers', label: 'Buyers', icon: 'handshake' },
    { key: 'ops', label: 'Operations Hub', icon: 'precision_manufacturing' },
  ],
  Buyer: [
    { key: 'dashboard', label: 'Dashboard', icon: 'dashboard' },
    { key: 'routes', label: 'Routes & Mines', icon: 'alt_route' },
    { key: 'waybills', label: 'Waybills', icon: 'description' },
    { key: 'recons', label: 'Reconciliations', icon: 'balance' },
    { key: 'ops', label: 'Operations Hub', icon: 'precision_manufacturing' },
  ],
  Transporter: [
    { key: 'dashboard', label: 'Dashboard', icon: 'dashboard' },
    { key: 'fleet', label: 'Fleet', icon: 'local_shipping' },
    { key: 'positions', label: 'Positions', icon: 'place' },
    { key: 'recons', label: 'Reconciliations', icon: 'balance' },
    { key: 'ops', label: 'Operations Hub', icon: 'precision_manufacturing' },
  ],
};
function MirrorStat({ icon, label, value, unit, accent = '#00b5d8', onClick }) {
  return (
    <div onClick={onClick} title={onClick ? 'View ' + label : undefined} style={{ background: 'var(--surface-card)', border: '1px solid var(--border-card)', borderRadius: 'var(--radius-lg)', boxShadow: 'var(--shadow-xs)', padding: 16, display: 'flex', flexDirection: 'column', gap: 9, cursor: onClick ? 'pointer' : 'default', transition: 'box-shadow .15s, transform .15s', position: 'relative' }}
      onMouseEnter={(e) => { if (onClick) { e.currentTarget.style.boxShadow = 'var(--shadow-md)'; e.currentTarget.style.transform = 'translateY(-2px)'; } }}
      onMouseLeave={(e) => { if (onClick) { e.currentTarget.style.boxShadow = 'var(--shadow-xs)'; e.currentTarget.style.transform = 'none'; } }}>
      <div style={{ display: 'flex', alignItems: 'center', justifyContent: 'space-between' }}>
        <div style={{ width: 34, height: 34, borderRadius: 10, background: accent + '1f', display: 'flex', alignItems: 'center', justifyContent: 'center' }}><IcX name={icon} size={18} color={accent} /></div>
        {onClick && <IcX name="arrow_outward" size={16} color="var(--text-faint)" />}
      </div>
      <div style={{ fontSize: 24, fontWeight: 800, color: 'var(--text-strong)', lineHeight: 1 }}>{value}{unit && <span style={{ fontSize: 15 }}> {unit}</span>}</div>
      <div style={{ fontSize: 12.5, color: 'var(--text-muted)' }}>{label}</div>
    </div>
  );
}
function MirrorCard({ icon, title, meta, children }) {
  return (
    <DSx.Card padding={0} style={{ overflow: 'hidden' }}>
      <div style={{ display: 'flex', alignItems: 'center', gap: 9, padding: '16px 20px', borderBottom: '1px solid var(--divider)' }}>
        <IcX name={icon} size={20} color="var(--accent)" />
        <h3 style={{ margin: 0, fontSize: 16, fontWeight: 800, color: 'var(--text-strong)', flex: 1 }}>{title}</h3>
        {meta && <span style={{ fontSize: 12.5, color: 'var(--text-faint)' }}>{meta}</span>}
      </div>
      <div style={{ padding: 20 }}>{children}</div>
    </DSx.Card>
  );
}
function MiniTable({ cols, rows, cell }) {
  return (
    <div style={{ width: '100%', overflowX: 'auto' }}>
      <div style={{ display: 'grid', gridTemplateColumns: cols.map((c) => c.w || '1fr').join(' '), padding: '0 4px 9px', borderBottom: '1px solid var(--divider)' }}>
        {cols.map((c) => <div key={c.key} style={{ fontSize: 11, textTransform: 'uppercase', letterSpacing: '.07em', color: 'var(--text-faint)', fontWeight: 700, textAlign: c.align || 'left' }}>{c.label}</div>)}
      </div>
      {rows.map((r, i) => (
        <div key={i} style={{ display: 'grid', gridTemplateColumns: cols.map((c) => c.w || '1fr').join(' '), alignItems: 'center', padding: '12px 4px', borderBottom: i < rows.length - 1 ? '1px solid var(--divider)' : 'none' }}>
          {cols.map((c) => <div key={c.key} style={{ textAlign: c.align || 'left', minWidth: 0 }}>{cell(r, c.key)}</div>)}
        </div>
      ))}
    </div>
  );
}
function MiniBars({ data, unit }) {
  const max = Math.max(...data.map((d) => d.v));
  return (
    <div style={{ display: 'flex', alignItems: 'flex-end', gap: 10, height: 130 }}>
      {data.map((d, i) => (
        <div key={i} style={{ flex: 1, display: 'flex', flexDirection: 'column', alignItems: 'center', gap: 7 }}>
          <span style={{ fontSize: 11, fontFamily: 'var(--font-mono)', color: 'var(--text-muted)' }}>{d.v}</span>
          <div style={{ width: '100%', height: `${(d.v / max) * 92}px`, background: i === data.length - 1 ? 'var(--accent)' : 'var(--ml-cyan-200)', borderRadius: '6px 6px 0 0' }} />
          <span style={{ fontSize: 10.5, color: 'var(--text-faint)', fontFamily: 'var(--font-mono)' }}>{d.k}</span>
        </div>
      ))}
    </div>
  );
}
const money = (n) => 'R ' + n.toLocaleString(undefined, { maximumFractionDigits: 0 });

/* Per-tab, per-org-type live-mirror content */
function MirrorTabBody({ company, tab }) {
  const T = company.otype;
  const plate = (p) => <span style={{ fontFamily: 'var(--font-mono)', fontWeight: 700, letterSpacing: '.05em' }}>{p}</span>;
  const stTone = { SIGNED: 'done', PENDING: 'atmine', LOADED: 'done', 'AT MINE': 'atmine', OTW: 'transit', APPROVED: 'done', DISPUTED: 'warn', AVAILABLE: 'done', 'ON TRIP': 'transit', MAINTENANCE: 'warn', OPEN: 'transit' };

  if (tab === 'ops') {
    return (
      <MirrorCard icon="precision_manufacturing" title="Operations Hub" meta="Live records">
        <div style={{ display: 'grid', gridTemplateColumns: 'repeat(3,1fr)', gap: 12, marginBottom: 16 }}>
          {[['Weighbridge tickets', company.loads, 'scale'], ['Loads logged', company.loads, 'inventory_2'], ['Gate checks', Math.round(company.trips * 2.1), 'sensor_door']].map(([l, v, ic], i) => (
            <div key={i} style={{ display: 'flex', alignItems: 'center', gap: 10, padding: 12, border: '1px solid var(--border-card)', borderRadius: 'var(--radius-md)' }}><IcX name={ic} size={18} color="var(--accent)" /><div><div style={{ fontSize: 18, fontWeight: 800, color: 'var(--text-strong)' }}>{v}</div><div style={{ fontSize: 11.5, color: 'var(--text-muted)' }}>{l}</div></div></div>
          ))}
        </div>
        <MiniTable cols={[{ key: 'a', label: 'Record', w: '1.2fr' }, { key: 'b', label: 'Detail', w: '1.6fr' }, { key: 'c', label: 'When', w: '0.9fr', align: 'right' }]}
          rows={[{ a: 'WB-0051', b: 'Outbound · net 34.5 t', c: '09:19' }, { a: 'LD-8842', b: company.name + ' · Iron Ore', c: '09:20' }, { a: 'GC-991', b: 'Entry · driver verified', c: '09:18' }]}
          cell={(r, k) => k === 'a' ? plate(r.a) : k === 'c' ? <span style={{ fontFamily: 'var(--font-mono)', fontSize: 13, color: 'var(--text-muted)' }}>{r.c}</span> : <span style={{ fontSize: 13.5, color: 'var(--text-body)' }}>{r.b}</span>} />
      </MirrorCard>
    );
  }

  if (tab === 'dashboard') {
    return (
      <div style={{ display: 'grid', gridTemplateColumns: '1.5fr 1fr', gap: 16, alignItems: 'start' }}>
        <MirrorCard icon="show_chart" title="Tons moved — last 7 days">
          <MiniBars data={[{ k: 'Mo', v: 420 }, { k: 'Tu', v: 510 }, { k: 'We', v: 480 }, { k: 'Th', v: 620 }, { k: 'Fr', v: 390 }, { k: 'Sa', v: 560 }, { k: 'Su', v: 487 }]} />
        </MirrorCard>
        <MirrorCard icon="insights" title="This month">
          <div style={{ display: 'flex', flexDirection: 'column', gap: 12 }}>
            {[['Trips', company.trips], ['Loads', company.loads], ['Routes', company.routes], ['Waybills done', company.wbDone], ['Waybills open', company.wbOpen]].map(([l, v], i) => (
              <div key={i} style={{ display: 'flex', alignItems: 'center', justifyContent: 'space-between', paddingBottom: 10, borderBottom: i < 4 ? '1px solid var(--divider)' : 'none' }}><span style={{ fontSize: 13.5, color: 'var(--text-muted)' }}>{l}</span><span style={{ fontSize: 16, fontWeight: 800, color: 'var(--text-strong)', fontFamily: 'var(--font-mono)' }}>{v}</span></div>
            ))}
          </div>
        </MirrorCard>
      </div>
    );
  }

  // MINE tabs
  if (T === 'Mine' && tab === 'control') {
    return (
      <MirrorCard icon="tune" title="Recent loads recorded" meta="Load control desk">
        <MiniTable cols={[{ key: 'plate', label: 'Truck', w: '1fr' }, { key: 'buyer', label: 'Buyer', w: '1.3fr' }, { key: 'tons', label: 'Tons', w: '0.7fr', align: 'right' }, { key: 's', label: 'Status', w: '0.9fr', align: 'right' }]}
          rows={[{ plate: 'DV12UH GP', buyer: 'Atlas Buyer Group', tons: '34.5 t', s: 'LOADED' }, { plate: 'HGH 789 GP', buyer: 'Pioneer Mining', tons: '—', s: 'AT MINE' }, { plate: 'BKG 456 GP', buyer: 'Atlas Buyer Group', tons: '31.8 t', s: 'LOADED' }]}
          cell={(r, k) => k === 'plate' ? plate(r.plate) : k === 'tons' ? <span style={{ fontFamily: 'var(--font-mono)' }}>{r.tons}</span> : k === 's' ? <BdgX tone={stTone[r.s]}>{r.s}</BdgX> : <span style={{ fontSize: 13.5, color: 'var(--text-body)' }}>{r.buyer}</span>} />
      </MirrorCard>
    );
  }
  if (T === 'Mine' && tab === 'stockpile') {
    return (
      <MirrorCard icon="terrain" title="Stockpiles by mineral" meta="Per buyer">
        <MiniTable cols={[{ key: 'm', label: 'Mineral', w: '1.2fr' }, { key: 'buyer', label: 'For buyer', w: '1.2fr' }, { key: 'oh', label: 'On hand', w: '0.9fr', align: 'right' }, { key: 'cap', label: 'Capacity', w: '0.9fr', align: 'right' }]}
          rows={[{ m: 'Iron Ore', buyer: 'Atlas', oh: '9,640 t', cap: '14,000 t' }, { m: 'Chrome Ore', buyer: 'Pioneer', oh: '3,120 t', cap: '6,000 t' }, { m: 'Manganese', buyer: 'Bathopele', oh: '1,840 t', cap: '4,000 t' }]}
          cell={(r, k) => k === 'm' ? <span style={{ fontWeight: 700, color: 'var(--text-strong)' }}>{r.m}</span> : k === 'buyer' ? <span style={{ fontSize: 13.5, color: 'var(--text-body)' }}>{r.buyer}</span> : <span style={{ fontFamily: 'var(--font-mono)', color: k === 'oh' ? 'var(--accent)' : 'var(--text-muted)', fontWeight: k === 'oh' ? 700 : 400 }}>{r[k]}</span>} />
      </MirrorCard>
    );
  }
  if (T === 'Mine' && tab === 'buyers') {
    return (
      <MirrorCard icon="handshake" title="Buyers & tonnage" meta="This month">
        <MiniTable cols={[{ key: 'b', label: 'Buyer', w: '1.6fr' }, { key: 't', label: 'Tons out', w: '1fr', align: 'right' }, { key: 'v', label: 'Value', w: '1fr', align: 'right' }]}
          rows={[{ b: 'Atlas Buyer Group', t: '6,200 t', v: money(2604000) }, { b: 'Pioneer Mining', t: '3,100 t', v: money(1302000) }, { b: 'Bathopele Trading', t: '2,900 t', v: money(1218000) }]}
          cell={(r, k) => k === 'b' ? <span style={{ fontWeight: 700, color: 'var(--text-strong)' }}>{r.b}</span> : <span style={{ fontFamily: 'var(--font-mono)', color: k === 'v' ? 'var(--ml-green-600)' : 'var(--text-body)', fontWeight: k === 'v' ? 700 : 400 }}>{r[k]}</span>} />
      </MirrorCard>
    );
  }

  // BUYER tabs
  if (T === 'Buyer' && tab === 'routes') {
    return (
      <MirrorCard icon="alt_route" title="Routes & mines" meta={company.routes + ' routes'}>
        <MiniTable cols={[{ key: 'r', label: 'Mine → Offload', w: '2fr' }, { key: 'tr', label: 'Trucks', w: '0.8fr', align: 'right' }, { key: 't', label: 'Tons / wk', w: '1fr', align: 'right' }]}
          rows={[{ r: 'Mogalakwena → Saldanha', tr: 4, t: '620 t' }, { r: 'Thabazimbi → Vanderbijlpark', tr: 2, t: '310 t' }, { r: 'Mogalakwena → Richards Bay', tr: 3, t: '310 t' }]}
          cell={(r, k) => k === 'r' ? <span style={{ fontWeight: 600, color: 'var(--text-strong)' }}>{r.r}</span> : <span style={{ fontFamily: 'var(--font-mono)', color: 'var(--text-body)' }}>{r[k]}</span>} />
      </MirrorCard>
    );
  }
  if (T === 'Buyer' && tab === 'waybills') {
    return (
      <MirrorCard icon="description" title="Waybills" meta={company.wbDone + ' signed · ' + company.wbOpen + ' open'}>
        <MiniTable cols={[{ key: 'wb', label: 'Waybill', w: '1fr' }, { key: 'd', label: 'Truck · Route', w: '1.8fr' }, { key: 'v', label: 'Tons', w: '0.7fr', align: 'right' }, { key: 's', label: 'Status', w: '0.9fr', align: 'right' }]}
          rows={[{ wb: 'WB-0045', d: 'CDF 789 LP · Saldanha', v: '34.5 t', s: 'SIGNED' }, { wb: 'WB-0046', d: 'JKL 012 NW · Vanderbijlpark', v: '—', s: 'PENDING' }, { wb: 'WB-0047', d: 'BKG 456 GP · Richards Bay', v: '31.8 t', s: 'SIGNED' }]}
          cell={(r, k) => k === 'wb' ? plate(r.wb) : k === 'd' ? <span style={{ fontSize: 13.5, color: 'var(--text-body)' }}>{r.d}</span> : k === 'v' ? <span style={{ fontFamily: 'var(--font-mono)' }}>{r.v}</span> : <BdgX tone={stTone[r.s]}>{r.s}</BdgX>} />
      </MirrorCard>
    );
  }
  if (tab === 'recons') {
    return (
      <MirrorCard icon="balance" title="Reconciliations" meta="Loaded vs delivered">
        <MiniTable cols={[{ key: 'r', label: T === 'Buyer' ? 'Mine / Route' : 'Client / Route', w: '1.7fr' }, { key: 'l', label: 'Loaded', w: '0.9fr', align: 'right' }, { key: 'd', label: 'Delivered', w: '0.9fr', align: 'right' }, { key: 'var', label: 'Var', w: '0.7fr', align: 'right' }, { key: 's', label: 'Status', w: '1fr', align: 'right' }]}
          rows={[{ r: 'Mogalakwena · Saldanha', l: '620 t', d: '614 t', v: '-6 t', s: 'DISPUTED' }, { r: 'Thabazimbi · Vanderbijlpark', l: '310 t', d: '310 t', v: '0 t', s: 'APPROVED' }, { r: 'Mogalakwena · Richards Bay', l: '290 t', d: '288 t', v: '-2 t', s: 'APPROVED' }]}
          cell={(r, k) => k === 'r' ? <span style={{ fontWeight: 600, color: 'var(--text-strong)' }}>{r.r}</span> : k === 'var' ? <span style={{ fontFamily: 'var(--font-mono)', fontWeight: 700, color: r.v === '0 t' ? 'var(--ml-green-600)' : 'var(--ml-orange-600)' }}>{r.v}</span> : k === 's' ? <BdgX tone={stTone[r.s]}>{r.s}</BdgX> : <span style={{ fontFamily: 'var(--font-mono)', color: 'var(--text-body)' }}>{r[k]}</span>} />
      </MirrorCard>
    );
  }

  // TRANSPORTER tabs
  if (T === 'Transporter' && tab === 'fleet') {
    return (
      <MirrorCard icon="local_shipping" title="Fleet register" meta={company.fleet + ' vehicles'}>
        <MiniTable cols={[{ key: 'p', label: 'Vehicle', w: '1fr' }, { key: 'd', label: 'Driver', w: '1.2fr' }, { key: 'cap', label: 'Cap', w: '0.7fr', align: 'right' }, { key: 's', label: 'Status', w: '1fr', align: 'right' }]}
          rows={[{ p: 'CDF 789 LP', d: 'Thabo Mokoena', cap: '34 t', s: 'ON TRIP' }, { p: 'JKL 012 NW', d: 'Pieter van Wyk', cap: '34 t', s: 'AT MINE' }, { p: 'XYZ 901 LP', d: 'Mandla Zulu', cap: '34 t', s: 'MAINTENANCE' }]}
          cell={(r, k) => k === 'p' ? plate(r.p) : k === 'd' ? <span style={{ fontSize: 13.5, color: 'var(--text-body)' }}>{r.d}</span> : k === 'cap' ? <span style={{ fontFamily: 'var(--font-mono)' }}>{r.cap}</span> : <BdgX tone={stTone[r.s]}>{r.s}</BdgX>} />
      </MirrorCard>
    );
  }
  if (T === 'Transporter' && tab === 'positions') {
    return (
      <MirrorCard icon="place" title="Live truck positions" meta="4 live">
        <MiniTable cols={[{ key: 'p', label: 'Truck', w: '1fr' }, { key: 'r', label: 'Route', w: '1.8fr' }, { key: 's', label: 'Status', w: '1fr', align: 'right' }]}
          rows={[{ p: 'CDF 789 LP', r: 'Mogalakwena → Saldanha', s: 'OTW' }, { p: 'JKL 012 NW', r: 'Thabazimbi → Vanderbijlpark', s: 'AT MINE' }, { p: 'BKG 456 GP', r: 'Mogalakwena → Richards Bay', s: 'LOADED' }]}
          cell={(r, k) => k === 'p' ? plate(r.p) : k === 'r' ? <span style={{ fontSize: 13.5, color: 'var(--text-body)' }}>{r.r}</span> : <BdgX tone={stTone[r.s]}>{r.s}</BdgX>} />
      </MirrorCard>
    );
  }

  return <MirrorCard icon="visibility" title="No data"><div style={{ fontSize: 13.5, color: 'var(--text-faint)' }}>Nothing recorded for this view yet.</div></MirrorCard>;
}

/* ---------- Employee register + profile (per company, role-grouped) ---------- */
const EMP_ROLES = {
  Mine: [
    { key: 'super', label: 'Supervisors & Foremen', icon: 'groups', tone: 'cyan', desc: 'Everything besides generating invoices & managing employees' },
    { key: 'load', label: 'Load Controllers', icon: 'tune', tone: 'blue', desc: 'Load trucks only — record tons, seals & wayslips' },
    { key: 'security', label: 'Security Guards', icon: 'shield', tone: 'amber', desc: 'Gate checks only — mark trucks arrived & left' },
    { key: 'admin', label: 'Admins & Management', icon: 'admin_panel_settings', tone: 'cyan', desc: 'Full company administration' },
  ],
  Buyer: [
    { key: 'admin', label: 'Admins & Management', icon: 'admin_panel_settings', tone: 'amber', desc: 'Full company administration' },
    { key: 'procure', label: 'Procurement', icon: 'shopping_bag', tone: 'cyan', desc: 'Routes, waybills & reconciliation' },
  ],
  Transporter: [
    { key: 'admin', label: 'Admins & Management', icon: 'admin_panel_settings', tone: 'green', desc: 'Full company administration' },
    { key: 'fleet', label: 'Fleet Controllers', icon: 'local_shipping', tone: 'cyan', desc: 'Manage vehicles, routes & assignments' },
    { key: 'driver', label: 'Drivers', icon: 'badge', tone: 'blue', desc: 'Trips, POD upload & routes (mobile)' },
  ],
};
const EMP_TONE_FG = { cyan: 'var(--accent)', blue: 'var(--ml-blue-600)', amber: 'var(--ml-orange-600)', green: 'var(--ml-green-600)' };
const EMP_TONE_BG = { cyan: 'var(--ml-well-cyan)', blue: 'var(--ml-well-blue)', amber: 'var(--ml-well-amber)', green: 'var(--ml-well-green)' };
const EMP_PEOPLE = {
  super: [
    { name: 'Vusi Khumalo', role: 'Supervisor', presence: 'online', email: 'vusi.k@ironhills.co.za', wa: '+27 82 145 9931', idno: '8604125023086', docs: ['ID document.pdf', 'Employment contract.pdf', 'Safety induction.pdf'] },
    { name: 'Musi Ndlovu', role: 'Foreman', presence: 'away', email: 'musi.n@ironhills.co.za', wa: '+27 83 552 1180', idno: '9011080145087', docs: ['ID document.pdf', 'Employment contract.pdf'] },
    { name: 'Lusi Dlamini', role: 'Supervisor', presence: 'offline', lastSeen: '2h ago', email: 'lusi.d@ironhills.co.za', wa: '+27 84 220 7745', idno: '8809215582081', docs: ['ID document.pdf'] },
    { name: 'Pusi Nkosi', role: 'Foreman', presence: 'offline', lastSeen: 'yesterday', wa: '+27 82 771 3390', idno: '9207304412083', docs: ['ID document.pdf', 'Medical certificate.pdf'] },
  ],
  load: [
    { name: 'Ben Botha', role: 'Load Controller', presence: 'online', email: 'ben.b@ironhills.co.za', wa: '+27 82 334 1122', idno: '8501055023084', docs: ['ID document.pdf', 'Weighbridge cert.pdf'] },
    { name: 'John Meyer', role: 'Load Controller', presence: 'online', email: 'john.m@ironhills.co.za', wa: '+27 83 909 4410', idno: '9103128823080', docs: ['ID document.pdf'] },
    { name: 'Bob Naidoo', role: 'Load Controller', presence: 'offline', lastSeen: '30m ago', wa: '+27 84 118 6620', idno: '8712095412085', docs: ['ID document.pdf', 'Employment contract.pdf'] },
    { name: 'Ken Adams', role: 'Load Controller', presence: 'away', wa: '+27 82 665 9987', idno: '9309215023081', docs: ['ID document.pdf'] },
  ],
  security: [
    { name: 'Happy Sithole', role: 'Security Guard', presence: 'online', wa: '+27 82 447 1123', idno: '8905125523088', docs: ['ID document.pdf', 'PSIRA certificate.pdf'] },
    { name: 'Linky Mabaso', role: 'Security Guard', presence: 'online', wa: '+27 83 220 8890', idno: '9207084412086', docs: ['ID document.pdf', 'PSIRA certificate.pdf'] },
    { name: 'Dinky Zulu', role: 'Security Guard', presence: 'offline', lastSeen: '1h ago', wa: '+27 84 552 3345', idno: '8611095582082', docs: ['ID document.pdf'] },
    { name: 'Minky Cele', role: 'Security Guard', presence: 'away', wa: '+27 82 998 4471', idno: '9401125023089', docs: ['ID document.pdf', 'PSIRA certificate.pdf'] },
  ],
  admin: [
    { name: 'Nadia Pillay', role: 'Admin', presence: 'online', email: 'nadia.p@ironhills.co.za', wa: '+27 82 100 2030', idno: '8803120145080', docs: ['ID document.pdf', 'Employment contract.pdf'] },
    { name: 'Pieter Botha', role: 'Management', presence: 'away', email: 'pieter.b@ironhills.co.za', wa: '+27 83 445 6677', idno: '7906155023087', docs: ['ID document.pdf'] },
  ],
  procure: [
    { name: 'Sarah Adams', role: 'Procurement', presence: 'online', email: 'sarah.a@atlasbuyer.com', wa: '+27 82 771 2211', idno: '9105120145083', docs: ['ID document.pdf'] },
    { name: 'Themba Zwane', role: 'Procurement', presence: 'offline', lastSeen: '45m ago', wa: '+27 84 220 9988', idno: '8807095412089', docs: ['ID document.pdf'] },
  ],
  fleet: [
    { name: 'Riaan Steyn', role: 'Fleet Controller', presence: 'online', email: 'riaan.s@roadhaul.co.za', wa: '+27 82 334 5566', idno: '8604125023082', docs: ['ID document.pdf'] },
    { name: 'Nomsa Dube', role: 'Fleet Controller', presence: 'away', wa: '+27 83 118 2200', idno: '9209085582084', docs: ['ID document.pdf'] },
  ],
  driver: [
    { name: 'Thabo Mokoena', role: 'Driver', presence: 'online', wa: '+27 82 445 1199', idno: '8811125023085', docs: ['ID document.pdf', "Driver's licence.pdf", 'PrDP.pdf'] },
    { name: 'Pieter van Wyk', role: 'Driver', presence: 'offline', lastSeen: '3h ago', wa: '+27 84 662 3344', idno: '9002155412088', docs: ['ID document.pdf', "Driver's licence.pdf"] },
    { name: 'Sipho Ndlovu', role: 'Driver', presence: 'online', wa: '+27 82 990 7788', idno: '8705095523083', docs: ["Driver's licence.pdf", 'PrDP.pdf'] },
  ],
};
const PRESENCE_DOT = { online: '#16a34a', away: '#f59e0b', offline: '#94a3b8' };
function presenceLabel(p) { return p.presence === 'online' ? 'Online now' : p.presence === 'away' ? 'Away' : (p.lastSeen ? 'Last seen ' + p.lastSeen : 'Offline'); }
function initials(n) { return n.split(' ').filter(Boolean).slice(0, 2).map((w) => w[0].toUpperCase()).join(''); }

/* Per-identity theme colors — role / org-type / super-admin each get their own accent.
 * fg = strong accent, bg = soft tint. Deterministic by role keyword. */
const IDENTITY_THEMES = {
  owner:      { fg: '#7c3aed', bg: '#ede9fe' },  // violet
  admin:      { fg: '#2563eb', bg: '#dbeafe' },  // blue
  management: { fg: '#0891b2', bg: '#cffafe' },  // cyan-deep
  supervisor: { fg: '#00b5d8', bg: '#e2f6fb' },  // brand cyan
  foreman:    { fg: '#0f766e', bg: '#ccfbf1' },  // teal
  controller: { fg: '#4f46e5', bg: '#e0e7ff' },  // indigo
  security:   { fg: '#ea580c', bg: '#ffedd5' },  // orange
  driver:     { fg: '#16a34a', bg: '#dcfce7' },  // green
  procurement:{ fg: '#d97706', bg: '#fef3c7' },  // amber
  fleet:      { fg: '#0d9488', bg: '#ccfbf1' },  // teal-2
  superadmin: { fg: '#0b192e', bg: '#e2e8f0' },  // navy chrome
  default:    { fg: '#64748b', bg: '#e2e8f0' },
};
function identityTheme(role) {
  const r = (role || '').toLowerCase();
  if (r.includes('super') || r.includes('global')) return IDENTITY_THEMES.superadmin;
  for (const k of ['owner', 'admin', 'management', 'supervisor', 'foreman', 'controller', 'security', 'driver', 'procurement', 'fleet']) {
    if (r.includes(k)) return IDENTITY_THEMES[k];
  }
  return IDENTITY_THEMES.default;
}
/* Org / company type themes */
const ORG_THEMES = { Mine: { fg: '#00b5d8', bg: '#e2f6fb' }, Buyer: { fg: '#ea580c', bg: '#ffedd5' }, Transporter: { fg: '#16a34a', bg: '#dcfce7' } };

function EmpAvatar({ person, size = 44 }) {
  const th = identityTheme(person.role);
  return (
    <div style={{ position: 'relative', flexShrink: 0 }}>
      <div style={{ width: size, height: size, borderRadius: 999, background: th.bg, color: th.fg, display: 'flex', alignItems: 'center', justifyContent: 'center', fontWeight: 800, fontSize: size * 0.36, border: `1.5px solid ${th.fg}33` }}>{initials(person.name)}</div>
      <span style={{ position: 'absolute', right: -1, bottom: -1, width: size * 0.28, height: size * 0.28, minWidth: 10, minHeight: 10, borderRadius: 999, background: PRESENCE_DOT[person.presence], border: '2.5px solid var(--surface-card)' }} />
    </div>
  );
}

function EmployeeRegister({ company, canManage, onBack, onOpenEmployee }) {
  const roles = EMP_ROLES[company.otype] || EMP_ROLES.Mine;
  const total = roles.reduce((a, r) => a + (EMP_PEOPLE[r.key] || []).length, 0);
  return (
    <div>
      <div style={{ display: 'flex', alignItems: 'center', gap: 12, marginBottom: 14 }}>
        {onBack && <button type="button" onClick={onBack} style={{ width: 38, height: 38, borderRadius: 10, border: '1px solid var(--border-strong)', background: 'var(--surface-card)', cursor: 'pointer', display: 'flex', alignItems: 'center', justifyContent: 'center', color: 'var(--text-body)' }}><IcX name="arrow_back" size={20} /></button>}
        <div style={{ flex: 1 }}>
          <div style={{ display: 'flex', alignItems: 'center', gap: 9 }}><IcX name="badge" size={22} color="var(--accent)" /><h2 style={{ margin: 0, fontSize: 19, fontWeight: 800, color: 'var(--text-strong)' }}>Employee Register</h2></div>
          <div style={{ fontSize: 13, color: 'var(--text-muted)', marginTop: 2 }}>{company.name} · {canManage ? 'add or remove staff by role — each role sees only the screens its permissions allow' : 'read-only view of all registered staff by role'}</div>
        </div>
        <BdgX tone="done" dot>{total} employees</BdgX>
      </div>
      <div style={{ display: 'flex', flexDirection: 'column', gap: 16 }}>
        {roles.map((r) => {
          const people = EMP_PEOPLE[r.key] || [];
          return (
            <DSx.Card key={r.key} padding={0} style={{ overflow: 'hidden' }}>
              <div style={{ display: 'flex', alignItems: 'center', gap: 13, padding: '16px 20px', borderBottom: '1px solid var(--divider)' }}>
                <div style={{ width: 44, height: 44, borderRadius: 12, background: EMP_TONE_BG[r.tone], display: 'flex', alignItems: 'center', justifyContent: 'center', flexShrink: 0 }}><IcX name={r.icon} size={22} color={EMP_TONE_FG[r.tone]} /></div>
                <div style={{ flex: 1 }}><div style={{ fontSize: 16, fontWeight: 800, color: 'var(--text-strong)' }}>{r.label}</div><div style={{ fontSize: 12.5, color: 'var(--text-muted)' }}>{r.desc}</div></div>
                {canManage && <BtnX2 size="sm" icon="person_add">Add new</BtnX2>}
              </div>
              <div style={{ display: 'grid', gridTemplateColumns: '1fr 1fr', gap: 12, padding: 18 }}>
                {people.map((p, i) => (
                  <div key={i} onClick={() => onOpenEmployee({ ...p, roleLabel: r.label, company: company.name })} style={{ display: 'flex', alignItems: 'center', gap: 12, padding: '11px 14px', border: '1px solid var(--border-card)', borderRadius: 'var(--radius-md)', background: 'var(--surface-app)', cursor: 'pointer', transition: 'border-color .15s, background .15s' }}
                    onMouseEnter={(e) => { e.currentTarget.style.borderColor = 'var(--border-accent)'; e.currentTarget.style.background = 'var(--ml-well-cyan)'; }}
                    onMouseLeave={(e) => { e.currentTarget.style.borderColor = 'var(--border-card)'; e.currentTarget.style.background = 'var(--surface-app)'; }}>
                    <EmpAvatar person={p} size={40} />
                    <div style={{ flex: 1, minWidth: 0 }}><div style={{ fontSize: 14.5, fontWeight: 600, color: 'var(--text-strong)' }}>{p.name}</div><div style={{ fontSize: 12, color: 'var(--text-muted)' }}>{p.role} · {presenceLabel(p)}</div></div>
                    {canManage ? <button type="button" onClick={(e) => { e.stopPropagation(); }} title="Remove" style={{ border: 'none', background: 'transparent', cursor: 'pointer', color: 'var(--text-faint)', display: 'flex' }}><IcX name="person_remove" size={18} /></button> : <IcX name="chevron_right" size={18} color="var(--text-faint)" />}
                  </div>
                ))}
              </div>
            </DSx.Card>
          );
        })}
      </div>
    </div>
  );
}

function EmployeeProfilePanel({ employee, onClose, SlideCmp }) {
  if (!employee) return null;
  const p = employee;
  return (
    <SlideCmp open={!!employee} title="Employee profile" onClose={onClose} width={460}>
      <div style={{ display: 'flex', flexDirection: 'column', gap: 22 }}>
        {/* themed header banner */}
        {(() => { const th = identityTheme(p.roleLabel); return (
          <div style={{ display: 'flex', alignItems: 'center', gap: 16, padding: 18, borderRadius: 'var(--radius-lg)', background: `linear-gradient(150deg, ${th.bg}, var(--surface-card))`, border: `1px solid ${th.fg}33` }}>
            <EmpAvatar person={p} size={72} />
            <div style={{ flex: 1, minWidth: 0 }}>
              <div style={{ fontSize: 20, fontWeight: 800, color: 'var(--text-strong)' }}>{p.name}</div>
              <div style={{ display: 'inline-block', marginTop: 4, fontSize: 11.5, fontWeight: 800, letterSpacing: '.04em', textTransform: 'uppercase', color: th.fg, background: 'var(--surface-card)', padding: '3px 10px', borderRadius: 999, border: `1px solid ${th.fg}33` }}>{p.roleLabel}</div>
              <div style={{ fontSize: 13, color: 'var(--text-muted)', marginTop: 5 }}>{p.company}</div>
              <div style={{ display: 'inline-flex', alignItems: 'center', gap: 6, marginTop: 6, fontSize: 12.5, color: PRESENCE_DOT[p.presence], fontWeight: 600 }}><span style={{ width: 8, height: 8, borderRadius: 999, background: PRESENCE_DOT[p.presence] }} />{presenceLabel(p)}</div>
            </div>
          </div>
        ); })()}
        {/* message CTA */}
        <BtnX2 block icon="chat" onClick={() => { window.location.href = '../chat/index.html'; }}>Message {p.name.split(' ')[0]}</BtnX2>
        {/* contact details — WhatsApp-only accounts (drivers, security, some staff) have no email */}
        <div>
          <div style={{ fontSize: 12, textTransform: 'uppercase', letterSpacing: '.08em', color: 'var(--text-faint)', fontWeight: 700, marginBottom: 8 }}>Contact & identity</div>
          {(() => {
            const rows = [['badge', 'Role', p.roleLabel]];
            if (p.email) rows.push(['mail', 'Email', p.email]);
            rows.push(['chat', 'WhatsApp', p.wa]);
            rows.push(['fingerprint', 'ID number', p.idno]);
            return rows.map(([ic, l, v], i) => (
              <div key={i} style={{ display: 'flex', alignItems: 'center', gap: 12, padding: '11px 0', borderBottom: '1px solid var(--divider)' }}>
                <IcX name={ic} size={18} color="var(--accent)" />
                <span style={{ fontSize: 12.5, color: 'var(--text-muted)', width: 90, flexShrink: 0 }}>{l}</span>
                <span style={{ fontSize: 14, fontWeight: 600, color: 'var(--text-strong)', flex: 1, textAlign: 'right', fontFamily: (l === 'ID number' || l === 'WhatsApp') ? 'var(--font-mono)' : 'var(--font-sans)', wordBreak: 'break-all' }}>{v}</span>
              </div>
            ));
          })()}
          {!p.email && (
            <div style={{ display: 'flex', alignItems: 'center', gap: 8, marginTop: 10, padding: '9px 12px', background: 'var(--ml-well-green)', borderRadius: 'var(--radius-md)' }}>
              <IcX name="chat" size={16} color="var(--ml-green-600)" />
              <span style={{ fontSize: 12.5, color: 'var(--ml-green-700)' }}>WhatsApp-only account — this role signs in with their WhatsApp number, no email on file.</span>
            </div>
          )}
        </div>
        {/* documents */}
        <div>
          <div style={{ fontSize: 12, textTransform: 'uppercase', letterSpacing: '.08em', color: 'var(--text-faint)', fontWeight: 700, marginBottom: 8 }}>Documents ({p.docs.length})</div>
          <div style={{ display: 'flex', flexDirection: 'column', gap: 8 }}>
            {p.docs.map((d, i) => (
              <div key={i} style={{ display: 'flex', alignItems: 'center', gap: 11, padding: '10px 12px', border: '1px solid var(--border-card)', borderRadius: 'var(--radius-md)' }}>
                <div style={{ width: 34, height: 34, borderRadius: 9, background: 'var(--status-error-bg)', display: 'flex', alignItems: 'center', justifyContent: 'center' }}><IcX name="picture_as_pdf" size={18} color="var(--ml-red-600)" /></div>
                <span style={{ flex: 1, fontSize: 13.5, fontWeight: 600, color: 'var(--text-strong)' }}>{d}</span>
                <button type="button" style={{ border: 'none', background: 'transparent', cursor: 'pointer', color: 'var(--accent)', display: 'flex' }}><IcX name="download" size={18} /></button>
              </div>
            ))}
          </div>
        </div>
      </div>
    </SlideCmp>
  );
}

function AdminCompanyMirror({ company, onBack }) {
  const tabs = MIRROR_TABS[company.otype] || MIRROR_TABS.Mine;
  const [tab, setTab] = React.useState(tabs[0].key);
  const [showEmp, setShowEmp] = React.useState(false);
  const [emp, setEmp] = React.useState(null);
  const otAccent = { Mine: '#00b5d8', Buyer: '#ea580c', Transporter: '#16a34a' }[company.otype] || '#00b5d8';
  return (
    <div>
      <div style={{ display: 'flex', alignItems: 'center', gap: 12, marginBottom: 14 }}>
        <button type="button" onClick={onBack} style={{ width: 38, height: 38, borderRadius: 10, border: '1px solid var(--border-strong)', background: 'var(--surface-card)', cursor: 'pointer', display: 'flex', alignItems: 'center', justifyContent: 'center', color: 'var(--text-body)' }}><IcX name="arrow_back" size={20} /></button>
        <div style={{ flex: 1 }}>
          <div style={{ display: 'flex', alignItems: 'center', gap: 8 }}><h2 style={{ margin: 0, fontSize: 19, fontWeight: 800, color: 'var(--text-strong)' }}>{company.name}</h2><BdgX tone={OT_BADGE[company.otype]}>{company.otype}</BdgX></div>
          <div style={{ fontSize: 12.5, color: 'var(--text-muted)' }}>Live read-only mirror · current calendar month</div>
        </div>
        <BtnX2 size="sm" variant="outline" icon="download">Export monthly insights (CSV)</BtnX2>
      </div>
      <div style={{ display: 'flex', alignItems: 'center', gap: 10, padding: '11px 16px', background: 'var(--ml-well-blue)', borderRadius: 'var(--radius-md)', marginBottom: 16 }}>
        <IcX name="visibility" size={19} color="var(--ml-blue-600)" />
        <span style={{ fontSize: 13, color: 'var(--ml-blue-600)' }}>Edits, deletes, and moves are disabled. You can scroll, filter and export where the UI allows.</span>
      </div>
      <div style={{ display: 'flex', gap: 4, borderBottom: '1px solid var(--divider)', marginBottom: 18, overflowX: 'auto' }}>
        {tabs.map((t) => { const s = tab === t.key; return (
          <button key={t.key} type="button" onClick={() => setTab(t.key)} style={{ display: 'inline-flex', alignItems: 'center', gap: 7, padding: '11px 15px', border: 'none', background: 'transparent', cursor: 'pointer', whiteSpace: 'nowrap', fontFamily: 'var(--font-sans)', fontSize: 13.5, fontWeight: s ? 700 : 500, color: s ? 'var(--accent)' : 'var(--text-muted)', borderBottom: `2.5px solid ${s ? 'var(--accent)' : 'transparent'}`, marginBottom: -1 }}>
            <IcX name={t.icon} size={17} fill={s ? 1 : 0} />{t.label}
          </button>
        ); })}
      </div>
      <div style={{ display: 'grid', gridTemplateColumns: 'repeat(4,1fr)', gap: 14, marginBottom: 18 }}>
        <MirrorStat icon="groups" label="Employees" value={company.employees} accent={otAccent} onClick={() => setShowEmp(true)} />
        <MirrorStat icon="route" label="Trips this month" value={company.trips} accent="#0891b2" onClick={() => setTab(company.otype === 'Transporter' ? 'positions' : 'dashboard')} />
        <MirrorStat icon="inventory_2" label="Tons moved" value={company.tons.toLocaleString(undefined, { maximumFractionDigits: 1 })} unit="t" accent="#6366f1" onClick={() => setTab(company.otype === 'Mine' ? 'stockpile' : company.otype === 'Buyer' ? 'waybills' : 'recons')} />
        <MirrorStat icon={company.otype === 'Buyer' ? 'alt_route' : 'local_shipping'} label={company.otype === 'Buyer' ? 'Routes' : 'Fleet'} value={company.otype === 'Buyer' ? company.routes : company.fleet} accent="#14b8a6" onClick={() => setTab(company.otype === 'Mine' ? 'control' : company.otype === 'Buyer' ? 'routes' : 'fleet')} />
      </div>
      <MirrorTabBody company={company} tab={tab} />
      {showEmp && <div style={{ position: 'fixed', inset: 0, background: 'var(--surface-app)', zIndex: 45, overflowY: 'auto' }}><window.MLEmployeeRegister.Register otype={company.otype} companyName={company.name} canManage={false} onBack={() => setShowEmp(false)} /></div>}
    </div>
  );
}

/* ---------- Token requests queue ---------- */
const TOKEN_REQUESTS = [
  { id: 'tr1', org: 'Atlas Buyer Group', type: 'Buyer', kind: 'Seat expansion', curLimit: 3, used: 3, extra: 2, newTotal: 5, reason: 'Adding two procurement managers for the new Saldanha contract.', by: 'atlasbuyer.owner@mineralguide.com', status: 'pending', mins: 22 },
  { id: 'tr2', org: 'Iron Hills Mining', type: 'Mine', kind: 'Token renewal', curLimit: 5, used: 5, extra: 0, newTotal: 5, validDays: 365, reason: 'Annual renewal ahead of expiry (42 days left).', by: 'ironhills.owner@mineralguide.com', status: 'in_progress', handler: 'MineLink Ops', mins: 90 },
  { id: 'tr3', org: 'Corridor Freight', type: 'Transporter', kind: 'New token', curLimit: 0, used: 0, extra: 4, newTotal: 4, validDays: 90, reason: 'Newly registered transporter — initial seat allocation.', by: 'corridor.owner@gmail.com', status: 'pending', mins: 240 },
];
const TR_TONE = { pending: 'atmine', in_progress: 'transit', approved: 'done', rejected: 'error' };
const TR_LABEL = { pending: 'Pending', in_progress: 'In progress', approved: 'Approved', rejected: 'Rejected' };

function AdminTokenRequests({ openRequest }) {
  const [f, setF] = React.useState('all');
  const rows = f === 'all' ? TOKEN_REQUESTS : TOKEN_REQUESTS.filter((r) => r.status === f);
  const tabs = [['all', 'All'], ['pending', 'Pending'], ['in_progress', 'In progress'], ['approved', 'Approved'], ['rejected', 'Rejected']];
  return (
    <div>
      <STitleX icon="vpn_key" action={<BdgX tone="atmine" dot>{TOKEN_REQUESTS.filter((r) => r.status === 'pending').length} pending</BdgX>}>Token requests</STitleX>
      <div style={{ display: 'flex', gap: 8, marginBottom: 16, flexWrap: 'wrap' }}>
        {tabs.map(([k, l]) => { const s = f === k; return <button key={k} type="button" onClick={() => setF(k)} style={{ padding: '8px 15px', borderRadius: 999, cursor: 'pointer', fontFamily: 'var(--font-sans)', fontSize: 13.5, fontWeight: 700, border: `1px solid ${s ? 'var(--accent)' : 'var(--border-strong)'}`, background: s ? 'var(--accent)' : 'var(--surface-card)', color: s ? '#fff' : 'var(--text-body)' }}>{l}</button>; })}
      </div>
      <div style={{ display: 'flex', flexDirection: 'column', gap: 12 }}>
        {rows.map((r) => (
          <div key={r.id} onClick={() => openRequest(r)} style={{ cursor: 'pointer', background: 'var(--surface-card)', border: '1px solid var(--border-card)', borderRadius: 'var(--radius-lg)', boxShadow: 'var(--shadow-xs)', padding: 18, display: 'flex', alignItems: 'center', gap: 16 }}>
            <div style={{ width: 44, height: 44, borderRadius: 12, background: 'var(--ml-well-cyan)', display: 'flex', alignItems: 'center', justifyContent: 'center' }}><IcX name="vpn_key" size={22} color="var(--accent)" /></div>
            <div style={{ flex: 1, minWidth: 0 }}>
              <div style={{ display: 'flex', alignItems: 'center', gap: 8 }}><span style={{ fontSize: 15, fontWeight: 700, color: 'var(--text-strong)' }}>{r.org}</span><BdgX tone={OT_BADGE[r.type]}>{r.type}</BdgX></div>
              <div style={{ fontSize: 13, color: 'var(--text-muted)', marginTop: 3 }}>{r.kind} · {r.kind === 'Seat expansion' ? `${r.used}/${r.curLimit} → ${r.newTotal} seats` : r.validDays + ' days'} · by {r.by}</div>
            </div>
            <BdgX tone={TR_TONE[r.status]}>{TR_LABEL[r.status]}</BdgX>
            <span style={{ fontSize: 12.5, color: 'var(--text-faint)' }}>{r.mins < 60 ? r.mins + 'm' : Math.floor(r.mins / 60) + 'h'} ago</span>
            <IcX name="chevron_right" size={20} color="var(--text-faint)" />
          </div>
        ))}
      </div>
    </div>
  );
}

function TokenRequestPanel({ request, onClose, SlideCmp }) {
  const [note, setNote] = React.useState('');
  const [resolved, setResolved] = React.useState(null);
  React.useEffect(() => { setNote(''); setResolved(null); }, [request && request.id]);
  if (!request) return null;
  const st = resolved || request.status;
  const open = st === 'pending' || st === 'in_progress';
  return (
    <SlideCmp open={!!request} title={`Token request — ${request.org}`} onClose={onClose} width={460}>
      <div style={{ display: 'flex', flexDirection: 'column', gap: 18 }}>
        <div style={{ display: 'flex', alignItems: 'center', gap: 10 }}><BdgX tone={TR_TONE[st]} dot>{TR_LABEL[st]}</BdgX><BdgX tone={OT_BADGE[request.type]}>{request.type}</BdgX></div>
        <div style={{ background: 'var(--surface-app)', borderRadius: 'var(--radius-md)', padding: 16, border: '1px solid var(--border-card)' }}>
          <div style={{ fontSize: 12, textTransform: 'uppercase', letterSpacing: '.08em', color: 'var(--text-faint)', fontWeight: 700, marginBottom: 10 }}>{request.kind}</div>
          {request.kind === 'Seat expansion' ? (
            <div style={{ display: 'flex', gap: 20 }}>
              <div><div style={{ fontSize: 12, color: 'var(--text-muted)' }}>Current</div><div style={{ fontSize: 22, fontWeight: 800, fontFamily: 'var(--font-mono)' }}>{request.used}/{request.curLimit}</div></div>
              <div style={{ display: 'flex', alignItems: 'center' }}><IcX name="arrow_forward" size={20} color="var(--text-faint)" /></div>
              <div><div style={{ fontSize: 12, color: 'var(--text-muted)' }}>Requested total</div><div style={{ fontSize: 22, fontWeight: 800, fontFamily: 'var(--font-mono)', color: 'var(--accent)' }}>{request.newTotal}</div></div>
              <div style={{ marginLeft: 'auto', textAlign: 'right' }}><div style={{ fontSize: 12, color: 'var(--text-muted)' }}>Extra seats</div><div style={{ fontSize: 22, fontWeight: 800, fontFamily: 'var(--font-mono)', color: 'var(--ml-green-600)' }}>+{request.extra}</div></div>
            </div>
          ) : <div style={{ fontSize: 15, fontWeight: 700 }}>{request.validDays} day validity</div>}
        </div>
        <div><div style={{ fontSize: 12, textTransform: 'uppercase', letterSpacing: '.08em', color: 'var(--text-faint)', fontWeight: 700, marginBottom: 4 }}>Reason</div><div style={{ fontSize: 14, color: 'var(--text-body)', lineHeight: 1.5 }}>{request.reason}</div></div>
        <div style={{ fontSize: 13, color: 'var(--text-muted)' }}>Requested by <b style={{ color: 'var(--text-body)' }}>{request.by}</b></div>
        {st === 'in_progress' && request.handler && <div style={{ fontSize: 13, color: 'var(--text-muted)', display: 'flex', alignItems: 'center', gap: 6 }}><IcX name="person" size={16} color="var(--accent)" />Claimed by {request.handler}</div>}
        {open ? (
          <div style={{ display: 'flex', flexDirection: 'column', gap: 12, borderTop: '1px solid var(--divider)', paddingTop: 16 }}>
            <InX label="Review note (optional)" placeholder="Note attached to approval/rejection…" value={note} onChange={(e) => setNote(e.target.value)} />
            <div style={{ display: 'flex', gap: 10 }}>
              <BtnX2 block variant="go" icon="vpn_key" onClick={() => setResolved('approved')}>Approve &amp; issue</BtnX2>
              <BtnX2 block variant="danger" icon="block" onClick={() => setResolved('rejected')}>Reject</BtnX2>
            </div>
            {st === 'pending' && <BtnX2 variant="outline" block icon="pan_tool" onClick={() => setResolved('in_progress')}>Claim (mark in progress)</BtnX2>}
          </div>
        ) : (st === 'approved' || st === 'rejected') && <div style={{ padding: 14, borderRadius: 'var(--radius-md)', background: st === 'approved' ? 'var(--status-done-bg)' : 'var(--status-error-bg)', color: st === 'approved' ? 'var(--ml-green-700)' : 'var(--ml-red-600)', fontSize: 13.5, fontWeight: 600 }}>{st === 'approved' ? 'Approved — token issued & seat limit updated.' : 'Rejected — requester notified.'}</div>}
      </div>
    </SlideCmp>
  );
}

/* ---------- Token history + Audit logs ---------- */
const AUDIT = [
  { act: 'TOKEN_GENERATED', tone: 'done', icon: 'vpn_key', actor: 'MineLink Admin', org: 'Corridor Freight', type: 'Transporter', desc: 'Issued new token · 4 seats · 90 days', ip: '196.25.11.4', at: 'Jul 3 · 09:41' },
  { act: 'SEAT_REQUEST_APPROVED', tone: 'done', icon: 'check_circle', actor: 'MineLink Ops', org: 'Atlas Buyer Group', type: 'Buyer', desc: 'Approved seat expansion 3 → 5', ip: '196.25.11.9', at: 'Jul 3 · 08:20' },
  { act: 'COMPANY_SUSPENDED', tone: 'error', icon: 'block', actor: 'MineLink Admin', org: 'Test Live Mine', type: 'Mine', desc: 'Suspended — overdue token, over seat limit', ip: '196.25.11.4', at: 'Jul 2 · 16:03' },
  { act: 'TOKEN_REVOKED', tone: 'warn', icon: 'key_off', actor: 'MineLink Admin', org: 'Old Haulers CC', type: 'Transporter', desc: 'Revoked token on contract termination', ip: '196.25.11.4', at: 'Jul 2 · 11:12' },
  { act: 'SEAT_LIMIT_UPDATED', tone: 'transit', icon: 'event_seat', actor: 'MineLink Ops', org: 'Pioneer Mining', type: 'Buyer', desc: 'Seat limit 3 → 4', ip: '196.25.11.9', at: 'Jul 1 · 09:55' },
];
const AUDIT_FG = { done: 'var(--ml-green-600)', error: 'var(--ml-red-600)', warn: 'var(--ml-orange-600)', transit: 'var(--ml-blue-600)' };
const AUDIT_BG = { done: 'var(--ml-well-green)', error: 'var(--status-error-bg)', warn: 'var(--status-warn-bg)', transit: 'var(--ml-well-blue)' };

function AuditRow({ e }) {
  return (
    <div style={{ display: 'flex', gap: 13, padding: '14px 0', borderBottom: '1px solid var(--divider)' }}>
      <div style={{ width: 40, height: 40, borderRadius: 11, background: AUDIT_BG[e.tone], display: 'flex', alignItems: 'center', justifyContent: 'center', flexShrink: 0 }}><IcX name={e.icon} size={20} color={AUDIT_FG[e.tone]} /></div>
      <div style={{ flex: 1, minWidth: 0 }}>
        <div style={{ display: 'flex', alignItems: 'center', gap: 8, flexWrap: 'wrap' }}><span style={{ fontFamily: 'var(--font-mono)', fontSize: 12, fontWeight: 700, color: AUDIT_FG[e.tone] }}>{e.act}</span>{e.type && <BdgX tone={OT_BADGE[e.type]}>{e.type}</BdgX>}</div>
        <div style={{ fontSize: 14, color: 'var(--text-strong)', marginTop: 3 }}>{e.desc}</div>
        <div style={{ fontSize: 12, color: 'var(--text-faint)', marginTop: 3 }}>{e.org !== '—' ? e.org + ' · ' : ''}by {e.actor} · {e.ip} · {e.at}</div>
      </div>
    </div>
  );
}

function AdminAuditLogs({ tokenOnly }) {
  const [type, setType] = React.useState('all');
  let rows = tokenOnly ? AUDIT.filter((e) => /TOKEN|SEAT/.test(e.act)) : AUDIT;
  if (type !== 'all') rows = rows.filter((e) => e.type === type);
  return (
    <div>
      <STitleX icon={tokenOnly ? 'timeline' : 'history'} action={<BtnX2 size="sm" variant="outline" icon="download">Export CSV</BtnX2>}>{tokenOnly ? 'Token history' : 'Audit logs'}</STitleX>
      <div style={{ display: 'flex', gap: 8, marginBottom: 16, flexWrap: 'wrap' }}>
        {[['all', 'All org types'], ['Mine', 'Mines'], ['Buyer', 'Buyers'], ['Transporter', 'Transporters']].map(([k, l]) => { const s = type === k; return <button key={k} type="button" onClick={() => setType(k)} style={{ padding: '7px 14px', borderRadius: 999, cursor: 'pointer', fontFamily: 'var(--font-sans)', fontSize: 13, fontWeight: 700, border: `1px solid ${s ? 'var(--accent)' : 'var(--border-strong)'}`, background: s ? 'var(--accent)' : 'var(--surface-card)', color: s ? '#fff' : 'var(--text-body)' }}>{l}</button>; })}
      </div>
      <DSx.Card padding={22}>{rows.map((e, i) => <AuditRow key={i} e={e} />)}</DSx.Card>
    </div>
  );
}

/* ---------- Account security ---------- */
function AdminAccountSecurity() {
  return (
    <div style={{ maxWidth: 480 }}>
      <STitleX icon="lock">Account security</STitleX>
      <DSx.Card padding={24}>
        <div style={{ fontSize: 15, fontWeight: 800, color: 'var(--text-strong)', marginBottom: 4 }}>Change sign-in password</div>
        <div style={{ fontSize: 13, color: 'var(--text-muted)', marginBottom: 18 }}>Used for your email sign-in to the platform console.</div>
        <div style={{ display: 'flex', flexDirection: 'column', gap: 16 }}>
          <InX label="Current password" type="password" icon="lock" placeholder="••••••••" />
          <InX label="New password" type="password" icon="lock_reset" placeholder="At least 10 characters" />
          <InX label="Confirm new password" type="password" icon="lock_reset" placeholder="Re-enter new password" />
          <BtnX2 icon="check_circle">Update password</BtnX2>
        </div>
      </DSx.Card>
    </div>
  );
}

/* ---------- Platform settings ---------- */
function AdminPlatformSettings() {
  const [s, setS] = React.useState({ autoSuspend: true, notifyExpiry: true, allowSelfReg: false });
  return (
    <div style={{ maxWidth: 620 }}>
      <STitleX icon="settings">Platform settings</STitleX>
      <DSx.Card padding={22}>
        <div style={{ display: 'flex', flexDirection: 'column' }}>
          {[['autoSuspend', 'Auto-suspend on token expiry', 'Companies are suspended automatically when their token expires.'], ['notifyExpiry', 'Notify companies before expiry', 'Send reminders 7 days before a token expires.'], ['allowSelfReg', 'Allow self-registration', 'Let new companies request an account without an invite.']].map(([k, t, d]) => (
            <div key={k} style={{ display: 'flex', alignItems: 'center', gap: 14, padding: '16px 0', borderBottom: '1px solid var(--divider)' }}>
              <div style={{ flex: 1 }}><div style={{ fontSize: 14.5, fontWeight: 700, color: 'var(--text-strong)' }}>{t}</div><div style={{ fontSize: 12.5, color: 'var(--text-muted)' }}>{d}</div></div>
              <SwX checked={s[k]} onChange={(v) => setS((p) => ({ ...p, [k]: v }))} />
            </div>
          ))}
        </div>
        <div style={{ marginTop: 18, display: 'flex', flexDirection: 'column', gap: 14 }}>
          <InX label="Default token validity (days)" type="number" icon="event" placeholder="365" />
          <InX label="Platform support contact" icon="mail" placeholder="support@mine-link.co.za" />
          <BtnX2 icon="check_circle">Save settings</BtnX2>
        </div>
      </DSx.Card>
    </div>
  );
}

/* ---------- Register company ---------- */
const REG_ROLE_SUFFIX = { Mine: 'MIN', Buyer: 'BUY', Transporter: 'TRA' };
function AdminRegisterCompany({ go }) {
  const [type, setType] = React.useState('Mine');
  const [sent, setSent] = React.useState(false);
  const [validity, setValidity] = React.useState('30 days');
  const suffix = REG_ROLE_SUFFIX[type];
  const Section = ({ n, title, children }) => (
    <div style={{ background: 'var(--surface-card)', border: '1px solid var(--border-card)', borderRadius: 'var(--radius-xl)', boxShadow: 'var(--shadow-sm)', padding: 22 }}>
      <div style={{ display: 'flex', alignItems: 'center', gap: 12, marginBottom: 18 }}>
        <div style={{ width: 28, height: 28, borderRadius: 8, background: 'var(--ml-well-cyan)', display: 'flex', alignItems: 'center', justifyContent: 'center', fontFamily: 'var(--font-mono)', fontSize: 12.5, fontWeight: 700, color: 'var(--accent)' }}>{n}</div>
        <h3 style={{ margin: 0, fontSize: 16, fontWeight: 800, color: 'var(--text-strong)' }}>{title}</h3>
      </div>
      {children}
    </div>
  );
  if (sent) {
    return (
      <div style={{ maxWidth: 620 }}>
        <STitleX icon="add_business">Register company</STitleX>
        <DSx.Card padding={30} style={{ textAlign: 'center' }}>
          <div style={{ width: 64, height: 64, borderRadius: 18, background: 'var(--ml-well-green)', display: 'flex', alignItems: 'center', justifyContent: 'center', margin: '0 auto 16px' }}><IcX name="check_circle" size={34} color="var(--ml-green-600)" fill={1} /></div>
          <h3 style={{ margin: 0, fontSize: 20, fontWeight: 800, color: 'var(--text-strong)' }}>Company registered</h3>
          <p style={{ margin: '8px 0 4px', fontSize: 14, color: 'var(--text-muted)' }}>The owner token has been issued and the owner will receive their seat serial.</p>
          <div style={{ display: 'inline-block', margin: '14px 0 20px', padding: '10px 16px', background: 'var(--surface-app)', border: '1px dashed var(--border-strong)', borderRadius: 'var(--radius-md)', fontFamily: 'var(--font-mono)', fontSize: 16, fontWeight: 700, color: 'var(--text-strong)' }}>2Hq#84Lp-mN6w<span style={{ color: 'var(--accent)' }}>{suffix}</span></div>
          <div style={{ display: 'flex', gap: 10, justifyContent: 'center' }}>
            <BtnX2 icon="business" onClick={() => go('orgs')}>Back to organizations</BtnX2>
            <BtnX2 variant="outline" onClick={() => setSent(false)}>Register another</BtnX2>
          </div>
        </DSx.Card>
      </div>
    );
  }
  return (
    <div style={{ maxWidth: 640 }}>
      <STitleX icon="add_business">Register company</STitleX>
      <p style={{ margin: '-6px 0 16px', fontSize: 13.5, color: 'var(--text-muted)' }}>Onboard a new organization. Registering issues the owner's token and their role-bound seat serial.</p>
      <div style={{ display: 'flex', flexDirection: 'column', gap: 16 }}>
        <Section n="01" title="Organization type">
          <div style={{ display: 'flex', gap: 10 }}>
            {['Mine', 'Buyer', 'Transporter'].map((t) => { const s = type === t; return (
              <button key={t} type="button" onClick={() => setType(t)} style={{ flex: 1, display: 'flex', flexDirection: 'column', alignItems: 'center', gap: 8, padding: 16, borderRadius: 'var(--radius-lg)', cursor: 'pointer', border: `1.5px solid ${s ? 'var(--accent)' : 'var(--border-card)'}`, background: s ? 'var(--ml-well-cyan)' : 'var(--surface-card)' }}>
                <Ic3X name={O3[t]} size={40} /><span style={{ fontSize: 13.5, fontWeight: 700, color: s ? 'var(--accent)' : 'var(--text-body)' }}>{t === 'Mine' ? 'Mine / Supplier' : t}</span>
              </button>); })}
          </div>
        </Section>

        <Section n="02" title="Company details">
          <div style={{ display: 'flex', flexDirection: 'column', gap: 16 }}>
            <InX label="Company name" required icon="business" placeholder="e.g. Iron Hills Mining" />
            <div style={{ display: 'flex', gap: 12 }}>
              <div style={{ flex: 1 }}><InX label="Company registration no." icon="tag" placeholder="e.g. 2019/123456/07" /></div>
              <div style={{ flex: 1 }}><InX label="VAT number" icon="receipt_long" placeholder="e.g. 4123456789" /></div>
            </div>
            <InX label="Physical / operating address" icon="location_on" placeholder="Street, town, province" />
          </div>
        </Section>

        <Section n="03" title="Owner / primary contact">
          <div style={{ display: 'flex', flexDirection: 'column', gap: 16 }}>
            <InX label="Owner full name" required icon="person" placeholder="e.g. Johan Steyn" />
            <div style={{ display: 'flex', gap: 12 }}>
              <div style={{ flex: 1 }}><InX label="Owner email" required icon="mail" type="email" placeholder="owner@company.com" /></div>
              <div style={{ flex: 1 }}><InX label="Owner cell / WhatsApp" icon="chat" placeholder="+27 82 000 0000" /></div>
            </div>
          </div>
        </Section>

        <Section n="04" title="Token & seats">
          <div style={{ display: 'flex', gap: 12, marginBottom: 14, alignItems: 'flex-start' }}>
            <div style={{ flex: 1 }}><InX label="User seats" required type="number" icon="event_seat" placeholder="5" /></div>
            <div style={{ flex: 1 }}>
              <label style={{ display: 'flex', flexDirection: 'column', gap: 7 }}><span style={{ fontSize: 14, fontWeight: 600, color: 'var(--text-body)' }}>Token validity</span><SelX value={validity} onChange={(e) => setValidity(e.target.value)} options={['30 days', '90 days', '6 months', '12 months', 'Custom…']} /></label>
              {validity === 'Custom…' && <div style={{ marginTop: 12 }}><InX label="Custom validity (days)" required type="number" icon="event" placeholder="e.g. 180" /></div>}
            </div>
          </div>
          <div style={{ background: 'var(--surface-app)', borderRadius: 'var(--radius-md)', padding: 14, border: '1px dashed var(--border-strong)' }}>
            <div style={{ fontSize: 11.5, color: 'var(--text-faint)', marginBottom: 4 }}>Owner seat serial preview — last 3 chars bind the org type</div>
            <div style={{ fontFamily: 'var(--font-mono)', fontSize: 16, fontWeight: 700, color: 'var(--text-strong)', letterSpacing: '.04em' }}>2Hq#84Lp-mN6w<span style={{ color: 'var(--accent)' }}>{suffix}</span></div>
          </div>
        </Section>

        <div style={{ display: 'flex', gap: 10 }}>
          <BtnX2 icon="vpn_key" onClick={() => setSent(true)}>Register &amp; issue token</BtnX2>
          <BtnX2 variant="outline" onClick={() => go('orgs')}>Cancel</BtnX2>
        </div>
      </div>
    </div>
  );
}

/* ---------- Requested product / buyers (queues) ---------- */
function SimpleRequestQueue({ icon, title, subtitle, rows, renderMeta }) {
  return (
    <div>
      <STitleX icon={icon} action={<BdgX tone="atmine" dot>{rows.filter((r) => r.status === 'pending').length} new</BdgX>}>{title}</STitleX>
      <p style={{ margin: '-6px 0 16px', fontSize: 13.5, color: 'var(--text-muted)' }}>{subtitle}</p>
      <DSx.Card padding={22}>
        {rows.map((r, i) => (
          <div key={i} style={{ display: 'flex', alignItems: 'center', gap: 14, padding: '14px 0', borderBottom: i < rows.length - 1 ? '1px solid var(--divider)' : 'none' }}>
            <div style={{ width: 42, height: 42, borderRadius: 12, background: 'var(--ml-well-cyan)', display: 'flex', alignItems: 'center', justifyContent: 'center' }}><IcX name={icon} size={21} color="var(--accent)" /></div>
            <div style={{ flex: 1, minWidth: 0 }}><div style={{ fontSize: 14.5, fontWeight: 700, color: 'var(--text-strong)' }}>{r.title}</div><div style={{ fontSize: 13, color: 'var(--text-muted)', marginTop: 2 }}>{renderMeta(r)}</div></div>
            <BdgX tone={r.status === 'pending' ? 'atmine' : 'done'}>{r.status === 'pending' ? 'Pending' : 'Handled'}</BdgX>
            <BtnX2 size="sm" variant="outline">Review</BtnX2>
          </div>
        ))}
      </DSx.Card>
    </div>
  );
}
function AdminRequestedProduct() {
  return <SimpleRequestQueue icon="inventory_2" title="Requested product" subtitle="Buyers requesting new mineral products to purchase on the platform."
    rows={[
      { title: 'Atlas Buyer Group', product: 'Chrome 38/40 · 4,000 t / month', by: 'atlasbuyer.owner@…', status: 'pending' },
      { title: 'Pioneer Mining', product: 'Coal RB2 · 2,500 t / month', by: 'pioneer.owner@…', status: 'pending' },
      { title: 'Bathopele Trading', product: 'Manganese 44% · 1,200 t', by: 'bathopele.owner@…', status: 'handled' },
    ]} renderMeta={(r) => `${r.product} · by ${r.by}`} />;
}
function AdminRequestedBuyers() {
  return <SimpleRequestQueue icon="group_add" title="Requested buyers" subtitle="Mines asking MineLink to connect them with additional buyers for their minerals."
    rows={[
      { title: 'Iron Hills Mining', need: 'Iron ore buyers · Saldanha corridor', by: 'ironhills.owner@…', status: 'pending' },
      { title: 'Thabazimbi Mine', need: 'Chrome buyers · Vanderbijlpark', by: 'thaba.owner@…', status: 'handled' },
    ]} renderMeta={(r) => `${r.need} · by ${r.by}`} />;
}

/* ---------- Org Members & Tokens (active + expired) ---------- */
function AdminMembersTokens() {
  const [view, setView] = React.useState('active');
  const [type, setType] = React.useState('all');
  const [q, setQ] = React.useState('');
  const [sel, setSel] = React.useState(null);
  const companies = window.__ADMIN_COMPANIES__ || [];
  const now = Date.now();
  const rows = [];
  companies.forEach((c) => {
    const days = Math.floor((c.expires - now) / 86400000);
    const expired = days < 0;
    (c.users || []).forEach((u) => rows.push({
      name: u.name, role: u.role, seat: u.seat, active: u.active, org: c.name, type: c.type,
      expDays: days, expired, overLimit: c.used > c.seats, serial: c.serial,
      seats: c.seats, used: c.used, owner: c.owner,
      lastActive: u.active ? ['2m ago', '1h ago', 'today', 'yesterday'][Math.floor(Math.random() * 4)] : '—',
    }));
  });
  let activeRows = rows.filter((r) => !r.expired && r.active);
  let expiredRows = rows.filter((r) => r.expired || !r.active);
  const inType = (r) => type === 'all' || r.type === type;
  const inQ = (r) => !q || (r.name + ' ' + r.org + ' ' + r.role).toLowerCase().includes(q.toLowerCase());
  activeRows = activeRows.filter((r) => inType(r) && inQ(r));
  expiredRows = expiredRows.filter((r) => inType(r) && inQ(r));
  const shown = view === 'active' ? activeRows : expiredRows;
  // summary
  const expiringSoon = rows.filter((r) => !r.expired && r.active && r.expDays < 7).length;
  const seatUtil = companies.reduce((a, c) => a + c.used, 0) + ' / ' + companies.reduce((a, c) => a + c.seats, 0);
  const roleTone = { Owner: 'done', Admin: 'transit', Management: 'transit', Security: 'error', Controller: 'atmine', Driver: 'done' };

  return (
    <div>
      <STitleX icon="badge">Org Members &amp; Tokens</STitleX>
      <p style={{ margin: '-6px 0 16px', fontSize: 13.5, color: 'var(--text-muted)' }}>Every member across organizations with their seat &amp; token status. Search, filter by org type, and open a member for full seat &amp; token detail.</p>

      {/* summary strip */}
      <div style={{ display: 'grid', gridTemplateColumns: 'repeat(4,1fr)', gap: 14, marginBottom: 18 }}>
        {[['groups', 'Total members', rows.length, 'cyan'], ['verified_user', 'Active seats', rows.filter((r) => !r.expired && r.active).length, 'green'], ['event_seat', 'Seat utilisation', seatUtil, 'blue'], ['timer', 'Expiring < 7d', expiringSoon, 'amber']].map(([ic, l, v, tn], i) => (
          <div key={i} style={{ background: 'var(--surface-card)', border: '1px solid var(--border-card)', borderRadius: 'var(--radius-lg)', padding: 16, display: 'flex', flexDirection: 'column', gap: 8 }}>
            <div style={{ width: 38, height: 38, borderRadius: 11, background: REG_BG_M[tn], display: 'flex', alignItems: 'center', justifyContent: 'center' }}><IcX name={ic} size={19} color={REG_FG_M[tn]} /></div>
            <div style={{ fontSize: 22, fontWeight: 800, color: 'var(--text-strong)', fontFamily: 'var(--font-mono)' }}>{v}</div>
            <div style={{ fontSize: 12.5, color: 'var(--text-muted)' }}>{l}</div>
          </div>
        ))}
      </div>

      {/* controls */}
      <div style={{ display: 'flex', gap: 10, marginBottom: 16, flexWrap: 'wrap', alignItems: 'center' }}>
        <div style={{ display: 'flex', gap: 8 }}>
          {[['active', 'Active members', activeRows.length], ['expired', 'Expired / inactive', expiredRows.length]].map(([k, l, n]) => { const s = view === k; return (
            <button key={k} type="button" onClick={() => setView(k)} style={{ display: 'inline-flex', alignItems: 'center', gap: 8, padding: '8px 15px', borderRadius: 999, cursor: 'pointer', fontFamily: 'var(--font-sans)', fontSize: 13.5, fontWeight: 700, border: `1px solid ${s ? (k === 'expired' ? 'var(--ml-orange-600)' : 'var(--accent)') : 'var(--border-strong)'}`, background: s ? (k === 'expired' ? 'var(--ml-orange-600)' : 'var(--accent)') : 'var(--surface-card)', color: s ? '#fff' : 'var(--text-body)' }}>{l}<span style={{ fontFamily: 'var(--font-mono)', fontSize: 12, padding: '1px 6px', borderRadius: 999, background: s ? 'rgba(255,255,255,.22)' : 'var(--surface-sunken)', color: s ? '#fff' : 'var(--text-muted)' }}>{n}</span></button>
          ); })}
        </div>
        <div style={{ flex: 1 }} />
        <SelX label="All org types" icon="filter_list" value={type === 'all' ? '' : type} onChange={(e) => setType(e.target.value || 'all')} options={['Mine', 'Buyer', 'Transporter']} />
        <div style={{ position: 'relative', width: 240 }}><InX icon="search" placeholder="Search member, org, role…" value={q} onChange={(e) => setQ(e.target.value)} /></div>
      </div>

      <DSx.Card padding={22}>
        <TblX
          columns={[{ key: 'member', label: 'Member', w: '1.4fr' }, { key: 'org', label: 'Organization', w: '1.4fr' }, { key: 'role', label: 'Role', w: '0.9fr' }, { key: 'seat', label: 'Seat serial', w: '0.9fr' }, { key: 'token', label: view === 'active' ? 'Token expiry' : 'State', w: '1fr', align: 'right' }, { key: 'go', label: '', w: '40px', align: 'right' }]}
          rows={shown}
          renderCell={(r, k) => {
            if (k === 'member') return <div style={{ display: 'flex', alignItems: 'center', gap: 11 }}><AvX name={r.name} size={34} tone="slate" /><div><div style={{ fontSize: 14, fontWeight: 600, color: 'var(--text-strong)' }}>{r.name}</div><div style={{ fontSize: 12, color: 'var(--text-faint)' }}>{r.active ? 'Active ' + r.lastActive : 'Inactive'}</div></div></div>;
            if (k === 'org') return <div style={{ display: 'flex', alignItems: 'center', gap: 8 }}><span style={{ fontSize: 13.5, color: 'var(--text-body)' }}>{r.org}</span><BdgX tone={OT_BADGE[r.type]}>{r.type}</BdgX></div>;
            if (k === 'role') return <BdgX tone={roleTone[r.role] || 'neutral'}>{r.role}</BdgX>;
            if (k === 'seat') return <span style={{ fontFamily: 'var(--font-mono)', fontSize: 13, color: 'var(--text-muted)' }}>…{r.seat}</span>;
            if (k === 'token') { if (r.expired) return <BdgX tone="error">TOKEN EXPIRED</BdgX>; if (!r.active) return <BdgX tone="warn">NO ACTIVE SEAT</BdgX>; return <span style={{ fontFamily: 'var(--font-mono)', fontSize: 13.5, fontWeight: 700, color: r.expDays < 7 ? 'var(--ml-orange-600)' : 'var(--ml-green-600)' }}>{r.expDays}d left</span>; }
            return <button type="button" onClick={() => setSel(r)} style={{ border: 'none', background: 'transparent', cursor: 'pointer', color: 'var(--text-faint)', display: 'flex' }}><IcX name="chevron_right" size={20} /></button>;
          }}
        />
        {shown.length === 0 && <div style={{ padding: 30, textAlign: 'center', color: 'var(--text-faint)', fontSize: 14 }}>No members match.</div>}
      </DSx.Card>

      {/* member detail */}
      <window.MLShell.SlideOver open={!!sel} title={sel ? sel.name : ''} onClose={() => setSel(null)} width={440}>
        {sel && (<div style={{ display: 'flex', flexDirection: 'column', gap: 20 }}>
          <div style={{ display: 'flex', alignItems: 'center', gap: 14 }}>
            <AvX name={sel.name} size={56} tone="cyan" />
            <div><div style={{ fontSize: 17, fontWeight: 800, color: 'var(--text-strong)' }}>{sel.name}</div><div style={{ fontSize: 13, color: 'var(--text-muted)' }}>{sel.role} · {sel.org}</div>
              <div style={{ marginTop: 6 }}>{sel.expired ? <BdgX tone="error" dot>TOKEN EXPIRED</BdgX> : sel.active ? <BdgX tone="done" dot>ACTIVE SEAT</BdgX> : <BdgX tone="warn" dot>NO ACTIVE SEAT</BdgX>}</div>
            </div>
          </div>
          <div style={{ display: 'grid', gridTemplateColumns: '1fr 1fr', gap: 10 }}>
            {[['Organization', sel.org], ['Org type', sel.type], ['Seat serial', '…' + sel.seat], ['Full token', sel.serial], ['Org seats', sel.used + ' / ' + sel.seats], ['Token expiry', sel.expired ? 'Expired' : sel.expDays + ' days left'], ['Last active', sel.lastActive], ['Owner contact', sel.owner]].map(([l, v], i) => (
              <div key={i} style={{ background: 'var(--surface-app)', borderRadius: 'var(--radius-md)', padding: '10px 12px', border: '1px solid var(--border-card)' }}><div style={{ fontSize: 11, textTransform: 'uppercase', letterSpacing: '.05em', color: 'var(--text-faint)' }}>{l}</div><div style={{ fontSize: 13.5, fontWeight: 700, color: 'var(--text-strong)', marginTop: 2, fontFamily: /serial|token/i.test(l) ? 'var(--font-mono)' : 'inherit', wordBreak: 'break-all' }}>{v}</div></div>
            ))}
          </div>
          {sel.overLimit && <div style={{ display: 'flex', gap: 10, padding: 12, background: 'var(--status-warn-bg)', borderRadius: 'var(--radius-md)', fontSize: 12.5, color: 'var(--ml-orange-700)' }}><IcX name="warning" size={16} color="var(--ml-orange-700)" />This member's company is over its seat limit ({sel.used}/{sel.seats}).</div>}
          <div style={{ display: 'flex', flexDirection: 'column', gap: 10 }}>
            {sel.expired
              ? <BtnX2 block variant="go" icon="vpn_key">Renew org token</BtnX2>
              : sel.active
                ? <BtnX2 block variant="outline" icon="link_off">Deactivate seat</BtnX2>
                : <BtnX2 block variant="go" icon="event_seat">Assign a seat</BtnX2>}
            <div style={{ display: 'flex', gap: 10 }}>
              <BtnX2 block variant="outline" icon="business" onClick={() => setSel(null)}>Open organization</BtnX2>
              <BtnX2 block variant="ghost" icon="lock_reset">Reset password</BtnX2>
            </div>
          </div>
        </div>)}
      </window.MLShell.SlideOver>
    </div>
  );
}
const REG_FG_M = { cyan: 'var(--accent)', green: 'var(--ml-green-600)', amber: 'var(--ml-orange-600)', blue: 'var(--ml-blue-600)' };
const REG_BG_M = { cyan: 'var(--ml-well-cyan)', green: 'var(--ml-well-green)', amber: 'var(--ml-well-amber)', blue: 'var(--ml-well-blue)' };

window.AdminScreens = Object.assign(window.AdminScreens || {}, {
  AdminInsights, AdminCompanyMirror, EmployeeRegister, EmployeeProfilePanel, AdminTokenRequests, TokenRequestPanel, AdminAuditLogs,
  AdminAccountSecurity, AdminPlatformSettings,
  AdminRegisterCompany, AdminRequestedProduct, AdminRequestedBuyers, AdminMembersTokens,
});
