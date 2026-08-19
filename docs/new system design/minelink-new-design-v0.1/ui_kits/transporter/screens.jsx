/* MineLink — Transporter Portal screens. */
const DSt = window.MineLinkDesignSystem_9acfde;
const { Icon: IconT, StatCard: StatT, FeatureCard: FeatT, StatusBadge: BadgeT, PlatePill: PlateT, Button: BtnT } = DSt;
const { SectionTitle: STitleT, DataTable: TableT, MapCanvas: MapT, SlideOver: SlideT, IconWell: WellT } = window.MLShell;

const T_TRIPS = [
  { id: 't1', plate: 'CDF 789 LP', driver: 'Thabo Mokoena', from: 'Mogalakwena Mine', to: 'Saldanha Steel Works', tone: 'transit', status: 'OTW TO LOADING', time: '09:19' },
  { id: 't2', plate: 'JKL 012 NW', driver: 'Pieter van Wyk', from: 'Thabazimbi Mine', to: 'Vanderbijlpark', tone: 'atmine', status: 'AT MINE', time: '09:18' },
  { id: 't3', plate: 'BKG 456 GP', driver: 'Pieter Jacobs', from: 'Mogalakwena Mine', to: 'Saldanha Steel Works', tone: 'done', status: 'LOADED', time: '08:55' },
];

function RouteArrowT({ from, to, color }) {
  return <span style={{ display: 'inline-flex', alignItems: 'center', gap: 7, fontSize: 14, color: color || 'var(--text-body)' }}>{from} <IconT name="arrow_forward" size={15} color="var(--text-faint)" /> {to}</span>;
}

function TransporterDashboard({ go }) {
  return (
    <div style={{ display: 'flex', flexDirection: 'column', gap: 20 }}>
      <div style={{ display: 'grid', gridTemplateColumns: 'repeat(4,1fr)', gap: 16 }}>
        <StatT icon="local_shipping" label="Total Fleet" value="6" tone="cyan" />
        <StatT icon="bolt" label="On Trip" value="3" tone="blue" />
        <StatT icon="alt_route" label="Active Trips" value="3" tone="cyan" />
        <StatT icon="inventory_2" label="Tons Delivered" value="33.2" unit="t" delta="12.5t" deltaDir="up" tone="green" />
      </div>
      <div style={{ display: 'grid', gridTemplateColumns: 'repeat(4,1fr)', gap: 16 }}>
        <FeatT icon="local_shipping" title="Fleet Register" tone="cyan" description="Manage your entire fleet — upload truck packs, driver details, and documents for each vehicle." onOpen={() => go('fleet')} />
        <FeatT icon="balance" title="Reconciliations" tone="amber" description="View detailed load vs delivery variance reports. Track disputes, approvals, and discrepancies." onOpen={() => go('recons')} />
        <FeatT icon="alt_route" title="Routes" tone="cyan" description="See all active routes at a glance. Drill into individual clients and assign trucks to buyers." onOpen={() => go('routes')} />
        <FeatT icon="map" title="Truck Positions" tone="green" description="Live map view of all trucks with GPS data. See where every vehicle is in real time." onOpen={() => go('positions')} />
      </div>
      <DSt.Card padding={22}>
        <div style={{ display: 'flex', alignItems: 'center', gap: 12, marginBottom: 18, flexWrap: 'wrap' }}>
          <h2 style={{ margin: 0, fontSize: 18, fontWeight: 800, color: 'var(--text-strong)', flex: 1 }}>Active Trips</h2>
          <DSt.Select label="All Clients" icon="person" options={['Atlas Buyer Group', 'Pioneer Mining']} />
          <DSt.Select label="All Routes" icon="alt_route" options={['Mogalakwena → Saldanha']} />
          <BtnT variant="outline" size="sm" icon="map" onClick={() => go('positions')}>View on Map</BtnT>
        </div>
        <TableT
          columns={[{ key: 'truck', label: 'Truck / Driver', w: '1.4fr' }, { key: 'route', label: 'Route', w: '1.6fr' }, { key: 'status', label: 'Status', w: '1fr' }, { key: 'time', label: 'Updated', w: '0.7fr' }, { key: 'kebab', label: '', w: '40px', align: 'right' }]}
          rows={T_TRIPS}
          renderCell={(r, k) => {
            if (k === 'truck') return <div style={{ display: 'flex', alignItems: 'center', gap: 12 }}><WellT icon="local_shipping" tone="blue" size={36} radius={10} /><div><PlateT size="sm">{r.plate}</PlateT><div style={{ fontSize: 12.5, color: 'var(--text-muted)' }}>{r.driver}</div></div></div>;
            if (k === 'route') return <RouteArrowT from={r.from} to={r.to} />;
            if (k === 'status') return <BadgeT tone={r.tone}>{r.status}</BadgeT>;
            if (k === 'time') return <span style={{ fontFamily: 'var(--font-mono)', fontSize: 13.5, color: 'var(--text-muted)' }}>{r.time}</span>;
            return <button type="button" style={{ border: 'none', background: 'transparent', cursor: 'pointer', color: 'var(--text-faint)', display: 'flex' }}><IconT name="more_vert" size={18} /></button>;
          }}
        />
      </DSt.Card>
    </div>
  );
}

function TransporterFleet() {
  const [edit, setEdit] = React.useState(null);
  const [filter, setFilter] = React.useState('all');
  const fleet = [
    { id: 'v1', plate: 'CDF 789 LP', driver: 'Thabo Mokoena', make: 'Volvo FH16', cap: '34 t', tone: 'transit', status: 'On Trip', docs: 'Complete', disk: '2026-11-30' },
    { id: 'v2', plate: 'JKL 012 NW', driver: 'Pieter van Wyk', make: 'Scania R500', cap: '34 t', tone: 'atmine', status: 'At Mine', docs: 'Complete', disk: '2026-08-14' },
    { id: 'v3', plate: 'BKG 456 GP', driver: 'Pieter Jacobs', make: 'MAN TGX', cap: '36 t', tone: 'done', status: 'Available', docs: 'Complete', disk: '2027-02-28' },
    { id: 'v4', plate: 'MNP 345 MP', driver: 'David Mthembu', make: 'Mercedes Actros', cap: '34 t', tone: 'done', status: 'Available', docs: '1 expiring', disk: '2026-07-19' },
    { id: 'v5', plate: 'XYZ 901 LP', driver: 'Mandla Zulu', make: 'Volvo FH', cap: '34 t', tone: 'warn', status: 'Maintenance', docs: 'Complete', disk: '2026-09-05' },
  ];
  const active = (v) => v.status === 'On Trip' || v.status === 'At Mine';
  const counts = { all: fleet.length, active: fleet.filter(active).length, inactive: fleet.filter((v) => v.status === 'Available').length, maintenance: fleet.filter((v) => v.status === 'Maintenance').length };
  const rows = filter === 'all' ? fleet : filter === 'active' ? fleet.filter(active) : filter === 'inactive' ? fleet.filter((v) => v.status === 'Available') : fleet.filter((v) => v.status === 'Maintenance');
  const diskSoon = (d) => (new Date(d) - Date.now()) < 1000 * 60 * 60 * 24 * 45;
  return (
    <div style={{ position: 'relative' }}>
      <STitleT icon="local_shipping" action={<BtnT icon="add" size="sm">Add vehicle</BtnT>}>Fleet Register</STitleT>
      <div style={{ display: 'flex', gap: 8, marginBottom: 16, flexWrap: 'wrap' }}>
        {[['all', 'All vehicles'], ['active', 'Active'], ['inactive', 'Inactive'], ['maintenance', 'Maintenance']].map(([k, l]) => { const s = filter === k; return <button key={k} type="button" onClick={() => setFilter(k)} style={{ display: 'inline-flex', alignItems: 'center', gap: 7, padding: '8px 15px', borderRadius: 999, cursor: 'pointer', fontFamily: 'var(--font-sans)', fontSize: 13.5, fontWeight: 700, border: `1px solid ${s ? 'var(--accent)' : 'var(--border-strong)'}`, background: s ? 'var(--accent)' : 'var(--surface-card)', color: s ? '#fff' : 'var(--text-body)' }}>{l}<span style={{ fontFamily: 'var(--font-mono)', fontSize: 12, padding: '1px 6px', borderRadius: 999, background: s ? 'rgba(255,255,255,.22)' : 'var(--surface-sunken)', color: s ? '#fff' : 'var(--text-muted)' }}>{counts[k]}</span></button>; })}
      </div>
      <DSt.Card padding={22}>
        <TableT
          columns={[{ key: 'truck', label: 'Vehicle', w: '1.3fr' }, { key: 'make', label: 'Make / Model', w: '1.1fr' }, { key: 'cap', label: 'Capacity', w: '0.7fr', align: 'right' }, { key: 'disk', label: 'License disk', w: '1fr' }, { key: 'docs', label: 'Documents', w: '0.9fr' }, { key: 'status', label: 'Status', w: '1fr', align: 'right' }, { key: 'edit', label: '', w: '44px', align: 'right' }]}
          rows={rows}
          renderCell={(r, k) => {
            if (k === 'truck') return <div><PlateT size="sm">{r.plate}</PlateT><div style={{ fontSize: 12.5, color: 'var(--text-muted)' }}>{r.driver}</div></div>;
            if (k === 'make') return <span style={{ fontSize: 14, color: 'var(--text-body)' }}>{r.make}</span>;
            if (k === 'cap') return <span style={{ fontFamily: 'var(--font-mono)', fontSize: 14 }}>{r.cap}</span>;
            if (k === 'disk') return <span style={{ display: 'inline-flex', alignItems: 'center', gap: 6, fontFamily: 'var(--font-mono)', fontSize: 13, color: diskSoon(r.disk) ? 'var(--ml-orange-600)' : 'var(--text-body)', fontWeight: diskSoon(r.disk) ? 700 : 400 }}>{diskSoon(r.disk) && <IconT name="warning" size={14} color="var(--ml-orange-600)" />}{r.disk}</span>;
            if (k === 'docs') return <span style={{ fontSize: 13, color: r.docs === 'Complete' ? 'var(--ml-green-600)' : 'var(--ml-orange-600)', fontWeight: 600 }}>{r.docs}</span>;
            if (k === 'status') return <BadgeT tone={r.tone}>{r.status}</BadgeT>;
            return <button type="button" onClick={() => setEdit(r)} style={{ border: 'none', background: 'transparent', cursor: 'pointer', color: 'var(--text-faint)', display: 'flex' }}><IconT name="edit" size={18} /></button>;
          }}
        />
      </DSt.Card>
      <SlideT open={!!edit} title={edit ? `Edit — ${edit.plate}` : ''} onClose={() => setEdit(null)}>
        {edit && (<div style={{ display: 'flex', flexDirection: 'column', gap: 16 }}>
          <DSt.Input label="Registration" defaultValue={edit.plate} />
          <DSt.Input label="Assigned driver" defaultValue={edit.driver} icon="person" />
          <DSt.Input label="Make / model" defaultValue={edit.make} />
          <DSt.Input label="Capacity (tons)" defaultValue={edit.cap.replace(' t', '')} />
          <div style={{ display: 'flex', gap: 10, marginTop: 4 }}>
            <BtnT block onClick={() => setEdit(null)}>Save changes</BtnT>
            <BtnT variant="outline" onClick={() => setEdit(null)}>Cancel</BtnT>
          </div>
        </div>)}
      </SlideT>
    </div>
  );
}

function TransporterPositions() {
  const trucks = [
    { id: 1, plate: 'CDF 789 LP', tone: 'transit', x: '34%', y: '40%', label: 'OTW' },
    { id: 2, plate: 'JKL 012 NW', tone: 'atmine', x: '58%', y: '30%', label: 'At Mine' },
    { id: 3, plate: 'BKG 456 GP', tone: 'done', x: '48%', y: '62%', label: 'Loaded' },
    { id: 4, plate: 'RST 678 GP', tone: 'transit', x: '70%', y: '55%', label: 'OTW' },
  ];
  const dot = { transit: 'var(--ml-blue-600)', atmine: 'var(--ml-amber-700)', done: 'var(--ml-green-600)' };
  return (
    <div>
      <STitleT icon="place" action={<BadgeT tone="done" dot>4 live</BadgeT>}>Truck Positions</STitleT>
      <MapT height="calc(100vh - 200px)" style={{ minHeight: 460 }}>
        {trucks.map((t) => (
          <div key={t.id} style={{ position: 'absolute', left: t.x, top: t.y, transform: 'translate(-50%,-100%)', display: 'flex', flexDirection: 'column', alignItems: 'center', gap: 2 }}>
            <div style={{ background: 'var(--surface-card)', borderRadius: 999, padding: '4px 10px', boxShadow: 'var(--shadow-md)', display: 'flex', alignItems: 'center', gap: 6, border: `1.5px solid ${dot[t.tone]}` }}>
              <IconT name="local_shipping" size={16} color={dot[t.tone]} fill={1} />
              <span style={{ fontFamily: 'var(--font-mono)', fontSize: 12, fontWeight: 700 }}>{t.plate}</span>
            </div>
            <div style={{ width: 10, height: 10, borderRadius: 999, background: dot[t.tone], boxShadow: '0 0 0 4px rgba(255,255,255,.7)' }} />
          </div>
        ))}
        <div style={{ position: 'absolute', left: 16, bottom: 16, background: 'var(--surface-card)', borderRadius: 'var(--radius-md)', padding: '10px 14px', boxShadow: 'var(--shadow-md)', display: 'flex', gap: 16 }}>
          {[['transit', 'On the way'], ['atmine', 'At mine'], ['done', 'Loaded']].map(([k, l]) => (
            <span key={k} style={{ display: 'flex', alignItems: 'center', gap: 6, fontSize: 12.5, color: 'var(--text-body)' }}><span style={{ width: 9, height: 9, borderRadius: 999, background: dot[k] }} />{l}</span>
          ))}
        </div>
      </MapT>
    </div>
  );
}

function TransporterRecons() {
  return (
    <div>
      <STitleT icon="balance" action={<BtnT icon="download" size="sm" variant="outline">Export</BtnT>}>Reconciliations</STitleT>
      <DSt.Card padding={22}>
        <TableT
          columns={[{ key: 'client', label: 'Client / Route', w: '1.6fr' }, { key: 'loaded', label: 'Loaded', w: '1fr', align: 'right' }, { key: 'delivered', label: 'Delivered', w: '1fr', align: 'right' }, { key: 'variance', label: 'Variance', w: '1fr', align: 'right' }, { key: 'state', label: 'Status', w: '1fr', align: 'right' }]}
          rows={[
            { id: 1, client: 'Atlas Buyer · Saldanha', loaded: '620 t', delivered: '614 t', variance: '-6 t', tone: 'atmine', state: 'DISPUTED' },
            { id: 2, client: 'Pioneer · Vanderbijlpark', loaded: '310 t', delivered: '310 t', variance: '0 t', tone: 'done', state: 'APPROVED' },
            { id: 3, client: 'Atlas Buyer · Richards Bay', loaded: '290 t', delivered: '288 t', variance: '-2 t', tone: 'done', state: 'APPROVED' },
          ]}
          renderCell={(r, k) => {
            if (k === 'client') return <span style={{ fontWeight: 600, color: 'var(--text-strong)' }}>{r.client}</span>;
            if (k === 'state') return <BadgeT tone={r.tone}>{r.state}</BadgeT>;
            if (k === 'variance') return <span style={{ fontFamily: 'var(--font-mono)', fontWeight: 700, color: r.variance === '0 t' ? 'var(--ml-green-600)' : 'var(--ml-orange-600)' }}>{r.variance}</span>;
            return <span style={{ fontFamily: 'var(--font-mono)', fontSize: 14 }}>{r[k]}</span>;
          }}
        />
      </DSt.Card>
    </div>
  );
}

window.TransporterScreens = { TransporterDashboard, TransporterFleet, TransporterPositions, TransporterRecons };
