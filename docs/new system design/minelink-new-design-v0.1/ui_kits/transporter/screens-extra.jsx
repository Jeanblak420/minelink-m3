/* MineLink — Transporter extra screens: Routes (+detail & assign-trucks),
 * Available routes marketplace (+accept), Drivers register. Slides 16-19, 22.
 * Merges into window.TransporterScreens. Loaded after screens.jsx. */
const DTx = window.MineLinkDesignSystem_9acfde;
const { Icon: IcT2, StatusBadge: BdgT2, PlatePill: PltT2, Button: BtnT2, Avatar: AvT2, Input: InT2, Checkbox: CkT2 } = DTx;
const { SectionTitle: STitleT2, DataTable: TblT2, SlideOver: SlideT2, Modal: ModalT2 } = window.MLShell;

const MY_TRUCKS = [
  { id: 'v1', plate: 'CDF 789 LP', driver: 'Thabo Mokoena' }, { id: 'v2', plate: 'JKL 012 NW', driver: 'Pieter van Wyk' },
  { id: 'v3', plate: 'BKG 456 GP', driver: 'Pieter Jacobs' }, { id: 'v4', plate: 'MNP 345 MP', driver: 'David Mthembu' },
  { id: 'v5', plate: 'XYZ 901 LP', driver: 'Mandla Zulu' }, { id: 'v6', plate: 'RST 678 GP', driver: 'Johan Pretorius' },
];

const ACTIVE_ROUTES = [
  { id: 'r1', from: 'Brys Mine', to: 'Port', trucks: 20, km: 100, rate: 135, commodity: 'Coal', pay: '1 week after invoice', hours: '24/7', diesel: 'On account', delivered: 680, loads: 20,
    trips: [{ plate: 'HVK 345 MP', tone: 'transit', status: 'OTW to loading' }, { plate: 'WEK 392 MP', tone: 'done', status: 'OTW to offload' }] },
  { id: 'r2', from: 'Hugo Mine', to: 'Washplant', trucks: 5, km: 35, rate: 60, commodity: 'Chrome', pay: 'Daily', hours: '06:00–18:00', diesel: 'On transporter', delivered: 210, loads: 7,
    trips: [{ plate: 'JNS 123 MP', tone: 'atmine', status: 'At mine' }] },
  { id: 'r3', from: 'Drifon', to: 'Ergo', trucks: 35, km: 450, rate: 600, commodity: 'Chrome', pay: 'Weekly', hours: '24/7', diesel: 'On account', delivered: 1240, loads: 41,
    trips: [{ plate: 'ABC 111 GP', tone: 'transit', status: 'OTW to loading' }] },
];

const AVAILABLE_ROUTES = [
  { id: 'a1', mine: 'Triton Mine', from: 'Happy', to: 'Dingo', slots: 10, km: 80, rate: 120, pay: 'Daily', commodity: 'Chrome', diesel: 'On account', hours: '06:00–18:00', tons: '6,000 daily', duration: '6 months', start: 'Ongoing', notes: 'Truck inspection done on mine.' },
  { id: 'a2', mine: 'Gorge Mine', from: 'Gorge', to: 'Bush', slots: 5, km: 53, rate: 80, pay: '50/50', commodity: 'Coal', diesel: 'On transporter', hours: '24/7', tons: '2,400', duration: '3 months', start: '10 Jul 2026', notes: 'Weighbridge on site.' },
  { id: 'a3', mine: 'Ergo Mine', from: 'Ergo', to: 'Lingo', slots: 30, km: 75, rate: 115, pay: 'Weekly', commodity: 'Chrome', diesel: 'On account', hours: '24/7', tons: '9,000', duration: 'Ongoing', start: 'Ongoing', notes: 'PPE mandatory.' },
];

function AssignTrucksModal({ open, onClose, title, onDone }) {
  const [sel, setSel] = React.useState({});
  if (!open) return null;
  const count = Object.values(sel).filter(Boolean).length;
  return (
    <ModalT2 open={open} title={title} onClose={onClose} width={440}
      footer={<><BtnT2 variant="outline" onClick={onClose}>Cancel</BtnT2><BtnT2 icon="check" disabled={!count} onClick={onDone}>Assign {count || ''} truck{count === 1 ? '' : 's'}</BtnT2></>}>
      <div style={{ fontSize: 13, color: 'var(--text-muted)', marginBottom: 14 }}>Tick the trucks from your fleet to assign to this route.</div>
      <div style={{ display: 'flex', flexDirection: 'column', gap: 8, maxHeight: 320, overflowY: 'auto' }}>
        {MY_TRUCKS.map((t) => (
          <label key={t.id} style={{ display: 'flex', alignItems: 'center', gap: 12, padding: '10px 12px', border: `1.5px solid ${sel[t.id] ? 'var(--accent)' : 'var(--border-card)'}`, borderRadius: 'var(--radius-md)', cursor: 'pointer', background: sel[t.id] ? 'var(--ml-well-cyan)' : 'var(--surface-card)' }}>
            <CkT2 checked={!!sel[t.id]} onChange={(v) => setSel((s) => ({ ...s, [t.id]: v }))} />
            <div style={{ flex: 1 }}><PltT2 size="sm">{t.plate}</PltT2><div style={{ fontSize: 12.5, color: 'var(--text-muted)' }}>{t.driver}</div></div>
          </label>
        ))}
      </div>
    </ModalT2>
  );
}

function TransporterRoutes({ onTrip }) {
  const [sel, setSel] = React.useState(ACTIVE_ROUTES[0]);
  const [assign, setAssign] = React.useState(false);
  return (
    <div style={{ position: 'relative' }}>
      <STitleT2 icon="alt_route" action={<BtnT2 size="sm" variant="outline" icon="add_road">Request routes</BtnT2>}>Routes</STitleT2>
      <div style={{ display: 'grid', gridTemplateColumns: '1fr 1.1fr', gap: 16, alignItems: 'start' }}>
        {/* list */}
        <DTx.Card padding={16}>
          <div style={{ maxHeight: 'calc(100vh - 230px)', overflowY: 'auto', display: 'flex', flexDirection: 'column', gap: 8 }}>
            {ACTIVE_ROUTES.map((r) => {
              const on = sel && sel.id === r.id;
              return (
                <button key={r.id} type="button" onClick={() => setSel(r)} style={{ textAlign: 'left', border: `1.5px solid ${on ? 'var(--accent)' : 'var(--border-card)'}`, background: on ? 'var(--ml-well-cyan)' : 'var(--surface-card)', borderRadius: 'var(--radius-md)', padding: 14, cursor: 'pointer' }}>
                  <div style={{ display: 'flex', alignItems: 'center', gap: 7, fontSize: 14.5, fontWeight: 700, color: 'var(--text-strong)' }}>{r.from} <IcT2 name="arrow_forward" size={14} color="var(--text-faint)" /> {r.to}</div>
                  <div style={{ display: 'flex', gap: 14, marginTop: 6, fontSize: 12.5, color: 'var(--text-muted)', fontFamily: 'var(--font-mono)' }}><span>{r.trucks} trucks</span><span>{r.km} km</span><span style={{ color: 'var(--accent)', fontWeight: 700 }}>R{r.rate} pt</span></div>
                </button>
              );
            })}
          </div>
        </DTx.Card>
        {/* detail */}
        {sel && (
          <DTx.Card padding={22}>
            <div style={{ display: 'flex', alignItems: 'center', gap: 8, marginBottom: 4 }}>
              <h3 style={{ margin: 0, fontSize: 19, fontWeight: 800, color: 'var(--text-strong)', flex: 1 }}>{sel.from} → {sel.to}</h3>
              <BdgT2 tone="transit">{sel.commodity}</BdgT2>
            </div>
            <div style={{ fontSize: 13, color: 'var(--text-muted)', fontFamily: 'var(--font-mono)', marginBottom: 16 }}>{sel.trucks} trucks · {sel.km} km · R{sel.rate} per ton</div>
            <div style={{ display: 'grid', gridTemplateColumns: '1fr 1fr', gap: 12, marginBottom: 18 }}>
              {[['Payment terms', sel.pay], ['Commodity', sel.commodity], ['Operational hours', sel.hours], ['Diesel', sel.diesel], ['Tons delivered', sel.delivered + ' t'], ['No. of loads', sel.loads]].map(([l, v], i) => (
                <div key={i} style={{ background: 'var(--surface-app)', borderRadius: 'var(--radius-md)', padding: '10px 12px', border: '1px solid var(--border-card)' }}><div style={{ fontSize: 11, textTransform: 'uppercase', letterSpacing: '.05em', color: 'var(--text-faint)' }}>{l}</div><div style={{ fontSize: 14.5, fontWeight: 700, color: 'var(--text-strong)', marginTop: 2 }}>{v}</div></div>
              ))}
            </div>
            <div style={{ fontSize: 12, textTransform: 'uppercase', letterSpacing: '.06em', color: 'var(--text-faint)', fontWeight: 700, marginBottom: 8 }}>Active trips</div>
            <div style={{ display: 'flex', flexDirection: 'column', gap: 6, marginBottom: 16 }}>
              {sel.trips.map((t, i) => (
                <button key={i} type="button" onClick={() => onTrip && onTrip(t)} title="Show on map" style={{ display: 'flex', alignItems: 'center', gap: 10, padding: '9px 12px', border: '1px solid var(--border-card)', borderRadius: 'var(--radius-md)', background: 'var(--surface-card)', cursor: 'pointer', textAlign: 'left' }}>
                  <IcT2 name="local_shipping" size={18} color="var(--accent)" />
                  <PltT2 size="sm">{t.plate}</PltT2>
                  <BdgT2 tone={t.tone} style={{ marginLeft: 'auto' }}>{t.status}</BdgT2>
                  <IcT2 name="map" size={17} color="var(--text-faint)" />
                </button>
              ))}
            </div>
            <div style={{ display: 'flex', gap: 10, flexWrap: 'wrap' }}>
              <BtnT2 size="sm" icon="add" onClick={() => setAssign(true)}>Assign trucks</BtnT2>
              <BtnT2 size="sm" variant="outline" icon="download">View / download recons</BtnT2>
              <BtnT2 size="sm" variant="outline" icon="receipt_long">Generate invoice</BtnT2>
              <BtnT2 size="sm" variant="ghost" icon="list">Truck list</BtnT2>
            </div>
          </DTx.Card>
        )}
      </div>
      <AssignTrucksModal open={assign} onClose={() => setAssign(false)} title={sel ? `Assign trucks — ${sel.from} → ${sel.to}` : ''} onDone={() => setAssign(false)} />
    </div>
  );
}

function TransporterAvailableRoutes() {
  const [sel, setSel] = React.useState(AVAILABLE_ROUTES[0]);
  const [accept, setAccept] = React.useState(false);
  return (
    <div style={{ position: 'relative' }}>
      <STitleT2 icon="explore">Available routes</STitleT2>
      <p style={{ margin: '-6px 0 16px', fontSize: 13.5, color: 'var(--text-muted)' }}>Open routes posted by mines & buyers. Accept a route and assign trucks from your fleet.</p>
      <div style={{ display: 'grid', gridTemplateColumns: '1fr 1.1fr', gap: 16, alignItems: 'start' }}>
        <DTx.Card padding={16}>
          <div style={{ maxHeight: 'calc(100vh - 250px)', overflowY: 'auto', display: 'flex', flexDirection: 'column', gap: 8 }}>
            {AVAILABLE_ROUTES.map((r) => {
              const on = sel && sel.id === r.id;
              return (
                <button key={r.id} type="button" onClick={() => setSel(r)} style={{ textAlign: 'left', border: `1.5px solid ${on ? 'var(--accent)' : 'var(--border-card)'}`, background: on ? 'var(--ml-well-cyan)' : 'var(--surface-card)', borderRadius: 'var(--radius-md)', padding: 14, cursor: 'pointer' }}>
                  <div style={{ display: 'flex', alignItems: 'center', gap: 7, fontSize: 14.5, fontWeight: 700, color: 'var(--text-strong)' }}>{r.from} <IcT2 name="arrow_forward" size={14} color="var(--text-faint)" /> {r.to}</div>
                  <div style={{ display: 'flex', gap: 12, marginTop: 6, fontSize: 12, color: 'var(--text-muted)', fontFamily: 'var(--font-mono)', flexWrap: 'wrap' }}><span>{r.slots} slots</span><span>{r.km} km</span><span style={{ color: 'var(--accent)', fontWeight: 700 }}>R{r.rate} pt</span><span>{r.pay}</span><span>{r.commodity}</span></div>
                </button>
              );
            })}
          </div>
        </DTx.Card>
        {sel && (
          <DTx.Card padding={22}>
            <div style={{ display: 'flex', alignItems: 'center', gap: 8, marginBottom: 4 }}>
              <h3 style={{ margin: 0, fontSize: 19, fontWeight: 800, color: 'var(--text-strong)', flex: 1 }}>{sel.mine}</h3>
              <BdgT2 tone="atmine">{sel.commodity}</BdgT2>
            </div>
            <div style={{ display: 'flex', alignItems: 'center', gap: 7, fontSize: 14, color: 'var(--text-body)', marginBottom: 16 }}>{sel.from} <IcT2 name="arrow_forward" size={14} color="var(--text-faint)" /> {sel.to}</div>
            <div style={{ display: 'grid', gridTemplateColumns: '1fr 1fr', gap: 12, marginBottom: 18 }}>
              {[['Rate', 'R' + sel.rate + ' pt'], ['Distance', sel.km + ' km'], ['Payment terms', sel.pay], ['Diesel', sel.diesel], ['Operational hours', sel.hours], ['Tons available', sel.tons], ['Duration', sel.duration], ['No. of slots', sel.slots], ['Starting date', sel.start]].map(([l, v], i) => (
                <div key={i} style={{ background: 'var(--surface-app)', borderRadius: 'var(--radius-md)', padding: '10px 12px', border: '1px solid var(--border-card)' }}><div style={{ fontSize: 11, textTransform: 'uppercase', letterSpacing: '.05em', color: 'var(--text-faint)' }}>{l}</div><div style={{ fontSize: 14, fontWeight: 700, color: 'var(--text-strong)', marginTop: 2 }}>{v}</div></div>
              ))}
            </div>
            <div style={{ background: 'var(--surface-sunken)', borderRadius: 'var(--radius-md)', padding: 12, marginBottom: 16 }}><div style={{ fontSize: 11, textTransform: 'uppercase', letterSpacing: '.05em', color: 'var(--text-faint)', marginBottom: 4 }}>Route notes</div><div style={{ fontSize: 13.5, color: 'var(--text-body)' }}>{sel.notes}</div></div>
            <div style={{ display: 'flex', gap: 10 }}>
              <BtnT2 variant="go" icon="check_circle" onClick={() => setAccept(true)}>Accept route</BtnT2>
              <BtnT2 variant="outline" icon="list">Truck list</BtnT2>
            </div>
          </DTx.Card>
        )}
      </div>
      <AssignTrucksModal open={accept} onClose={() => setAccept(false)} title={sel ? `Accept — assign trucks to ${sel.mine}` : ''} onDone={() => setAccept(false)} />
    </div>
  );
}

function TransporterDrivers() {
  const [add, setAdd] = React.useState(false);
  const [reset, setReset] = React.useState(null);
  const drivers = [
    { id: 'd1', name: 'Thabo Mokoena', cell: '+27 82 111 2233', truck: 'CDF 789 LP', trips: 142, tone: 'transit', status: 'On Trip' },
    { id: 'd2', name: 'Pieter van Wyk', cell: '+27 83 222 3344', truck: 'JKL 012 NW', trips: 118, tone: 'atmine', status: 'At Mine' },
    { id: 'd3', name: 'Pieter Jacobs', cell: '+27 84 333 4455', truck: 'BKG 456 GP', trips: 96, tone: 'done', status: 'Available' },
    { id: 'd4', name: 'David Mthembu', cell: '+27 85 555 6677', truck: 'MNP 345 MP', trips: 73, tone: 'done', status: 'Available' },
  ];
  return (
    <div style={{ position: 'relative' }}>
      <STitleT2 icon="badge" action={<BtnT2 size="sm" icon="person_add" onClick={() => setAdd(true)}>Register driver</BtnT2>}>Drivers</STitleT2>
      <p style={{ margin: '-6px 0 16px', fontSize: 13.5, color: 'var(--text-muted)' }}>Drivers sign in with their cell / WhatsApp number — no email needed. You can reset a driver's password here.</p>
      <DTx.Card padding={22}>
        <TblT2
          columns={[{ key: 'driver', label: 'Driver', w: '1.4fr' }, { key: 'cell', label: 'Cell / WhatsApp', w: '1.2fr' }, { key: 'truck', label: 'Assigned truck', w: '1fr' }, { key: 'trips', label: 'Trips', w: '0.6fr', align: 'right' }, { key: 'status', label: 'Status', w: '1fr', align: 'right' }, { key: 'act', label: '', w: '44px', align: 'right' }]}
          rows={drivers}
          renderCell={(r, k) => {
            if (k === 'driver') return <div style={{ display: 'flex', alignItems: 'center', gap: 11 }}><AvT2 name={r.name} size={36} tone="slate" /><span style={{ fontSize: 14, fontWeight: 600, color: 'var(--text-strong)' }}>{r.name}</span></div>;
            if (k === 'cell') return <span style={{ fontFamily: 'var(--font-mono)', fontSize: 13.5, color: 'var(--text-body)' }}>{r.cell}</span>;
            if (k === 'truck') return <PltT2 size="sm">{r.truck}</PltT2>;
            if (k === 'trips') return <span style={{ fontFamily: 'var(--font-mono)', fontSize: 14 }}>{r.trips}</span>;
            if (k === 'status') return <BdgT2 tone={r.tone}>{r.status}</BdgT2>;
            return <button type="button" onClick={() => setReset(r)} title="Reset password" style={{ border: 'none', background: 'transparent', cursor: 'pointer', color: 'var(--text-faint)', display: 'flex' }}><IcT2 name="lock_reset" size={18} /></button>;
          }}
        />
      </DTx.Card>
      <SlideT2 open={add} title="Register driver" onClose={() => setAdd(false)}>
        <div style={{ display: 'flex', flexDirection: 'column', gap: 16 }}>
          <InT2 label="Full name" required icon="person" placeholder="e.g. Sipho Ndlovu" />
          <InT2 label="Cell / WhatsApp number" required icon="chat" placeholder="+27 82 000 0000" />
          <DTx.Select label="Assign truck (optional)" icon="local_shipping" options={MY_TRUCKS.map((t) => t.plate)} />
          <InT2 label="Temporary password" icon="lock" placeholder="Driver can change on first sign-in" />
          <BtnT2 variant="go" block icon="check_circle" onClick={() => setAdd(false)}>Register driver</BtnT2>
          <BtnT2 variant="outline" block onClick={() => setAdd(false)}>Cancel</BtnT2>
        </div>
      </SlideT2>
      <ModalT2 open={!!reset} title={reset ? `Reset password — ${reset.name}` : ''} onClose={() => setReset(null)}
        footer={<><BtnT2 variant="outline" onClick={() => setReset(null)}>Cancel</BtnT2><BtnT2 icon="lock_reset" onClick={() => setReset(null)}>Set new password</BtnT2></>}>
        <div style={{ display: 'flex', flexDirection: 'column', gap: 14 }}>
          <div style={{ fontSize: 13, color: 'var(--text-muted)' }}>Set a new temporary password for {reset && reset.name}. They'll be prompted to change it on next sign-in.</div>
          <InT2 label="New temporary password" icon="lock" placeholder="At least 6 characters" />
        </div>
      </ModalT2>
    </div>
  );
}

/* Maintenance detail — per-truck records + truck-pack PDF (slide 20) */
function TransporterMaintenance() {
  const [sel, setSel] = React.useState(null);
  const trucks = [
    { id: 'v5', plate: 'XYZ 901 LP', make: 'Volvo FH', tone: 'warn', status: 'In maintenance', issue: 'Brake overhaul', since: 'Jul 1', pack: true },
    { id: 'v4', plate: 'MNP 345 MP', make: 'Mercedes Actros', tone: 'atmine', status: 'Service due', issue: 'License disk expires 19 Jul', since: '—', pack: true },
    { id: 'v2', plate: 'JKL 012 NW', make: 'Scania R500', tone: 'done', status: 'Serviced', issue: 'Last service 22 Jun', since: '—', pack: false },
  ];
  const history = [
    { date: '01 Jul 2026', type: 'Brake overhaul', cost: 'R 12,400', by: 'FleetFix Centurion' },
    { date: '22 Jun 2026', type: 'Major service (120k km)', cost: 'R 8,900', by: 'Volvo Midrand' },
    { date: '14 May 2026', type: 'Tyre replacement ×4', cost: 'R 21,600', by: 'Tyremart' },
  ];
  return (
    <div style={{ position: 'relative' }}>
      <STitleT2 icon="build" action={<BtnT2 size="sm" icon="add">Log maintenance</BtnT2>}>Maintenance</STitleT2>
      <DTx.Card padding={22}>
        <TblT2
          columns={[{ key: 'truck', label: 'Vehicle', w: '1.2fr' }, { key: 'issue', label: 'Detail', w: '1.6fr' }, { key: 'status', label: 'Status', w: '1fr' }, { key: 'pack', label: 'Truck pack', w: '1fr' }, { key: 'go', label: '', w: '40px', align: 'right' }]}
          rows={trucks}
          renderCell={(r, k) => {
            if (k === 'truck') return <div><PltT2 size="sm">{r.plate}</PltT2><div style={{ fontSize: 12.5, color: 'var(--text-muted)' }}>{r.make}</div></div>;
            if (k === 'issue') return <span style={{ fontSize: 13.5, color: 'var(--text-body)' }}>{r.issue}</span>;
            if (k === 'status') return <BdgT2 tone={r.tone}>{r.status}</BdgT2>;
            if (k === 'pack') return r.pack ? <span style={{ display: 'inline-flex', alignItems: 'center', gap: 5, fontSize: 13, color: 'var(--ml-green-600)', fontWeight: 600 }}><IcT2 name="picture_as_pdf" size={15} />Uploaded</span> : <span style={{ fontSize: 12.5, color: 'var(--text-faint)' }}>Not uploaded</span>;
            return <button type="button" onClick={() => setSel(r)} style={{ border: 'none', background: 'transparent', cursor: 'pointer', color: 'var(--text-faint)', display: 'flex' }}><IcT2 name="chevron_right" size={20} /></button>;
          }}
        />
      </DTx.Card>
      <SlideT2 open={!!sel} title={sel ? `${sel.plate} — Maintenance` : ''} onClose={() => setSel(null)} width={480}>
        {sel && (<div style={{ display: 'flex', flexDirection: 'column', gap: 18 }}>
          <div style={{ display: 'flex', alignItems: 'center', gap: 10 }}><PltT2 size="lg">{sel.plate}</PltT2><BdgT2 tone={sel.tone}>{sel.status}</BdgT2></div>
          <DTx.FileUpload label="Truck pack (PDF)" hint="Sensitive — contract & compliance docs" />
          <div>
            <div style={{ fontSize: 12, textTransform: 'uppercase', letterSpacing: '.08em', color: 'var(--text-faint)', fontWeight: 700, marginBottom: 8 }}>Maintenance history</div>
            {history.map((h, i) => (
              <div key={i} style={{ display: 'flex', alignItems: 'center', gap: 12, padding: '11px 0', borderBottom: i < history.length - 1 ? '1px solid var(--divider)' : 'none' }}>
                <div style={{ width: 36, height: 36, borderRadius: 10, background: 'var(--ml-well-amber)', display: 'flex', alignItems: 'center', justifyContent: 'center' }}><IcT2 name="build" size={18} color="var(--ml-orange-600)" /></div>
                <div style={{ flex: 1 }}><div style={{ fontSize: 13.5, fontWeight: 600, color: 'var(--text-strong)' }}>{h.type}</div><div style={{ fontSize: 12, color: 'var(--text-muted)' }}>{h.date} · {h.by}</div></div>
                <span style={{ fontFamily: 'var(--font-mono)', fontSize: 13.5, fontWeight: 700, color: 'var(--text-body)' }}>{h.cost}</span>
              </div>
            ))}
          </div>
          <BtnT2 block icon="add">Log new maintenance</BtnT2>
        </div>)}
      </SlideT2>
    </div>
  );
}

window.TransporterScreens = Object.assign(window.TransporterScreens || {}, {
  TransporterRoutes, TransporterAvailableRoutes, TransporterDrivers, TransporterMaintenance,
});
