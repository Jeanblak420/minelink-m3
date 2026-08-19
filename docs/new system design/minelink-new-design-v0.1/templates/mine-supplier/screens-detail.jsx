/* MineLink — Mine detail screens (MISSING set):
 * loading_activity_detail, tons_out_detail (D/W/M/Y buyer filter), supervisor_view.
 * Merges into window.MineScreens. Loaded after screens.jsx. */
const DMx = window.MineLinkDesignSystem_9acfde;
const { Icon: IcM2, StatCard: StatM2, StatusBadge: BdgM2, PlatePill: PltM2, Button: BtnM2, Select: SelM2 } = DMx;
const { SectionTitle: STitleM2, DataTable: TblM2 } = window.MLShell;

/* Loading activity — incoming, on-site, scheduled (slide 8) */
function MineLoadingActivity() {
  const incoming = [
    { plate: 'HV23HI GP', buyer: 'Triton', eta: '15 min', tone: 'transit' },
    { plate: 'AS34G MP', buyer: 'Buyer C', eta: '30 min', tone: 'transit' },
    { plate: 'DVN18U GP', buyer: 'Atlas', eta: '48 min', tone: 'transit' },
  ];
  const onsite = [
    { plate: 'HI34HD GP', buyer: 'Triton', tone: 'atmine', status: 'Ready to load' },
    { plate: 'JNS123 MP', buyer: 'Buyer B', tone: 'done', status: 'Loaded' },
    { plate: 'KLM552 GP', buyer: 'Atlas', tone: 'atmine', status: 'Ready to load' },
  ];
  const scheduled = [{ buyer: 'Triton', n: 15 }, { buyer: 'Buyer B', n: 15 }, { buyer: 'Atlas', n: 12 }];
  return (
    <div>
      <div style={{ display: 'grid', gridTemplateColumns: 'repeat(3,1fr)', gap: 16, marginBottom: 20 }}>
        <StatM2 icon="login" label="Incoming trucks" value={incoming.length} tone="cyan" />
        <StatM2 icon="shield" label="Trucks on site" value={onsite.length} tone="amber" />
        <StatM2 icon="event" label="Scheduled today" value={scheduled.reduce((a, s) => a + s.n, 0)} tone="blue" />
      </div>
      <div style={{ display: 'grid', gridTemplateColumns: '1fr 1fr', gap: 16, alignItems: 'start' }}>
        <DMx.Card padding={20}>
          <div style={{ display: 'flex', alignItems: 'center', gap: 8, marginBottom: 14 }}><IcM2 name="login" size={20} color="var(--accent)" /><h3 style={{ margin: 0, fontSize: 16, fontWeight: 800, color: 'var(--text-strong)' }}>Incoming trucks</h3></div>
          <div style={{ display: 'flex', flexDirection: 'column', gap: 8 }}>
            {incoming.map((t, i) => (
              <div key={i} style={{ display: 'flex', alignItems: 'center', gap: 12, padding: '11px 12px', border: '1px solid var(--border-card)', borderRadius: 'var(--radius-md)' }}>
                <PltM2 size="sm">{t.plate}</PltM2>
                <span style={{ fontSize: 13, color: 'var(--text-muted)', flex: 1 }}>{t.buyer}</span>
                <span style={{ fontFamily: 'var(--font-mono)', fontSize: 13, fontWeight: 700, color: 'var(--accent)' }}>{t.eta}</span>
                <button type="button" style={{ border: 'none', background: 'transparent', cursor: 'pointer', color: 'var(--text-faint)', display: 'flex' }}><IcM2 name="map" size={18} /></button>
              </div>
            ))}
          </div>
        </DMx.Card>
        <DMx.Card padding={20}>
          <div style={{ display: 'flex', alignItems: 'center', gap: 8, marginBottom: 14 }}><IcM2 name="shield" size={20} color="var(--ml-orange-600)" /><h3 style={{ margin: 0, fontSize: 16, fontWeight: 800, color: 'var(--text-strong)' }}>Trucks on site</h3></div>
          <div style={{ display: 'flex', flexDirection: 'column', gap: 8 }}>
            {onsite.map((t, i) => (
              <div key={i} style={{ display: 'flex', alignItems: 'center', gap: 12, padding: '11px 12px', border: '1px solid var(--border-card)', borderRadius: 'var(--radius-md)' }}>
                <PltM2 size="sm">{t.plate}</PltM2>
                <span style={{ fontSize: 13, color: 'var(--text-muted)', flex: 1 }}>{t.buyer}</span>
                <BdgM2 tone={t.tone}>{t.status}</BdgM2>
              </div>
            ))}
          </div>
        </DMx.Card>
      </div>
      <DMx.Card padding={20} style={{ marginTop: 16 }}>
        <div style={{ display: 'flex', alignItems: 'center', gap: 8, marginBottom: 14 }}><IcM2 name="event" size={20} color="var(--ml-blue-600)" /><h3 style={{ margin: 0, fontSize: 16, fontWeight: 800, color: 'var(--text-strong)' }}>Trucks scheduled for the day</h3></div>
        <div style={{ display: 'flex', gap: 12, flexWrap: 'wrap' }}>
          {scheduled.map((s, i) => (
            <div key={i} style={{ display: 'flex', alignItems: 'center', gap: 12, padding: '12px 16px', border: '1px solid var(--border-card)', borderRadius: 'var(--radius-md)', minWidth: 200 }}>
              <div style={{ flex: 1 }}><div style={{ fontSize: 14, fontWeight: 700, color: 'var(--text-strong)' }}>{s.buyer}</div><div style={{ fontSize: 12.5, color: 'var(--text-muted)' }}>{s.n} trucks scheduled</div></div>
              <BtnM2 size="sm" variant="ghost">View list</BtnM2>
            </div>
          ))}
        </div>
      </DMx.Card>
    </div>
  );
}

/* Tons out detail — filter by buyer + D/W/M/Y/T (slide 5) */
function MineTonsOut() {
  const [period, setPeriod] = React.useState('Day');
  const data = { Day: 364, Week: 6683, Month: 69712, Year: 169712, Total: 2269712 };
  const buyers = [
    { name: 'Buyer A · Atlas', d: 156, w: 2566, m: 24800, tone: 'cyan' },
    { name: 'Buyer B · Pioneer', d: 128, w: 6842, m: 28100, tone: 'blue' },
    { name: 'Buyer C · Bathopele', d: 80, w: 4892, m: 16812, tone: 'green' },
  ];
  const keyFor = { Day: 'd', Week: 'w', Month: 'm', Year: 'm', Total: 'm' };
  return (
    <div>
      <div style={{ display: 'flex', alignItems: 'center', gap: 12, marginBottom: 18, flexWrap: 'wrap' }}>
        <IcM2 name="conveyor_belt" size={22} color="var(--accent)" />
        <h2 style={{ margin: 0, fontSize: 18, fontWeight: 800, color: 'var(--text-strong)', flex: 1 }}>Tons out</h2>
        <SelM2 label="All buyers" icon="handshake" options={buyers.map((b) => b.name)} />
        <div style={{ display: 'inline-flex', background: 'var(--surface-sunken)', borderRadius: 'var(--radius-md)', padding: 3, gap: 2 }}>
          {['Day', 'Week', 'Month', 'Year', 'Total'].map((p) => { const s = period === p; return <button key={p} type="button" onClick={() => setPeriod(p)} style={{ padding: '7px 13px', borderRadius: 9, border: 'none', cursor: 'pointer', fontFamily: 'var(--font-sans)', fontSize: 13, fontWeight: 600, background: s ? 'var(--surface-card)' : 'transparent', color: s ? 'var(--text-strong)' : 'var(--text-muted)', boxShadow: s ? 'var(--shadow-xs)' : 'none' }}>{p}</button>; })}
        </div>
      </div>
      <DMx.Card tone="hero" padding={26} style={{ marginBottom: 18 }}>
        <div style={{ fontSize: 13, color: 'var(--text-muted)', textTransform: 'uppercase', letterSpacing: '.08em', fontWeight: 700 }}>Tons out · {period}</div>
        <div style={{ fontSize: 44, fontWeight: 800, color: 'var(--text-strong)', fontFamily: 'var(--font-mono)', letterSpacing: '-.02em', marginTop: 6 }}>{data[period].toLocaleString()} <span style={{ fontSize: 24 }}>t</span></div>
      </DMx.Card>
      <DMx.Card padding={22}>
        <h3 style={{ margin: '0 0 14px', fontSize: 16, fontWeight: 800, color: 'var(--text-strong)' }}>By buyer</h3>
        <TblM2
          columns={[{ key: 'name', label: 'Buyer', w: '1.6fr' }, { key: 'val', label: 'Tons out (' + period.toLowerCase() + ')', w: '1fr', align: 'right' }, { key: 'act', label: '', w: '160px', align: 'right' }]}
          rows={buyers}
          renderCell={(r, k) => {
            if (k === 'name') return <span style={{ fontWeight: 700, color: 'var(--text-strong)' }}>{r.name}</span>;
            if (k === 'val') return <span style={{ fontFamily: 'var(--font-mono)', fontWeight: 700, color: 'var(--accent)' }}>{(r[keyFor[period]] || r.m).toLocaleString()} t</span>;
            return <div style={{ display: 'flex', gap: 6, justifyContent: 'flex-end' }}><BtnM2 size="sm" variant="outline" icon="download">Recons</BtnM2><BtnM2 size="sm" variant="ghost" icon="receipt_long">Invoice</BtnM2></div>;
          }}
        />
      </DMx.Card>
    </div>
  );
}

/* Supervisor / Foreman view — read-through of stockpile + tons + loading activity (slide 13) */
function MineSupervisorView({ go }) {
  return (
    <div>
      <div style={{ display: 'flex', alignItems: 'center', gap: 10, padding: '12px 16px', background: 'var(--ml-well-cyan)', borderRadius: 'var(--radius-md)', marginBottom: 18 }}>
        <IcM2 name="engineering" size={20} color="var(--accent)" />
        <span style={{ fontSize: 13.5, color: 'var(--ml-cyan-700)' }}>Supervisor / Foreman view — you can see everything except generating invoices &amp; managing employees.</span>
      </div>
      <div style={{ display: 'grid', gridTemplateColumns: 'repeat(4,1fr)', gap: 16, marginBottom: 20 }}>
        <StatM2 icon="conveyor_belt" label="Tons Out Today" value="487" unit="t" tone="cyan" />
        <StatM2 icon="inventory_2" label="Stockpile" value="9,640" unit="t" tone="blue" />
        <StatM2 icon="local_shipping" label="Trucks at Mine" value="12" tone="amber" />
        <StatM2 icon="login" label="Loads today" value="48" tone="green" />
      </div>
      <div style={{ display: 'grid', gridTemplateColumns: 'repeat(3,1fr)', gap: 16 }}>
        <DMx.FeatureCard icon="terrain" title="Stockpile levels" tone="cyan" description="View per-buyer stockpiles, add tons and upload assay results & pictures." onOpen={() => go && go('stockpile')} />
        <DMx.FeatureCard icon="conveyor_belt" title="Tons out" tone="blue" description="Filter tonnage by buyer and by day, week, month or year." onOpen={() => go && go('tonsout')} />
        <DMx.FeatureCard icon="local_shipping" title="Loading activity" tone="amber" description="Incoming trucks, trucks on site, and the day's scheduled trucks." onOpen={() => go && go('loading')} />
      </div>
    </div>
  );
}

window.MineScreens = Object.assign(window.MineScreens || {}, { MineLoadingActivity, MineTonsOut, MineSupervisorView });
