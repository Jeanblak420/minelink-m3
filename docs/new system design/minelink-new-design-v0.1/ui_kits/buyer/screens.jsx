/* MineLink — Buyer Portal screens. */
const DSb = window.MineLinkDesignSystem_9acfde;
const { Icon: IconB, StatCard, FeatureCard, StatusBadge: BadgeB, PlatePill: PlateB, Button: BtnB, Avatar: AvB, Input: InputB } = DSb;
const { SectionTitle: STitleB, DataTable: TableB, MapCanvas: MapB, Modal: ModalB, IconWell: WellB } = window.MLShell;

const BUYER_TRIPS = [
  { id: 't1', plate: 'CDF 789 LP', driver: 'Thabo Mokoena', from: 'Mogalakwena Mine', to: 'Saldanha Steel Works', tone: 'transit', status: 'OTW TO LOADING', time: '09:19' },
  { id: 't2', plate: 'JKL 012 NW', driver: 'Pieter van Wyk', from: 'Thabazimbi Mine', to: 'Vanderbijlpark', tone: 'atmine', status: 'AT MINE', time: '09:18' },
  { id: 't3', plate: 'BKG 456 GP', driver: 'Pieter Jacobs', from: 'Mogalakwena Mine', to: 'Saldanha Steel Works', tone: 'done', status: 'LOADED', time: '08:55' },
  { id: 't4', plate: 'RST 678 GP', driver: 'Johan Pretorius', from: 'Mogalakwena Mine', to: 'Richards Bay', tone: 'transit', status: 'OTW TO LOADING', time: '08:40' },
];

function RouteArrow({ from, to, color }) {
  return (
    <span style={{ display: 'inline-flex', alignItems: 'center', gap: 7, fontSize: 14, color: color || 'var(--text-body)' }}>
      {from} <IconB name="arrow_forward" size={15} color="var(--text-faint)" /> {to}
    </span>
  );
}

function TripTable({ rows, onMap }) {
  return (
    <DSb.Card padding={22}>
      <div style={{ display: 'flex', alignItems: 'center', gap: 12, marginBottom: 18, flexWrap: 'wrap' }}>
        <IconB name="local_shipping" size={22} color="var(--accent)" />
        <h2 style={{ margin: 0, fontSize: 18, fontWeight: 800, color: 'var(--text-strong)', flex: 1 }}>Active Trips</h2>
        <DSb.Select label="All Clients" icon="person" options={['Atlas Buyer Group', 'Pioneer Mining']} />
        <DSb.Select label="All Routes" icon="alt_route" options={['Mogalakwena → Saldanha', 'Thabazimbi → Vanderbijlpark']} />
        <BtnB variant="outline" size="sm" icon="map" onClick={onMap}>View on Map</BtnB>
      </div>
      <TableB
        columns={[
          { key: 'truck', label: 'Truck / Driver', w: '1.4fr' },
          { key: 'route', label: 'Route', w: '1.6fr' },
          { key: 'status', label: 'Status', w: '1fr' },
          { key: 'time', label: 'Updated', w: '0.7fr' },
          { key: 'kebab', label: '', w: '40px', align: 'right' },
        ]}
        rows={rows}
        renderCell={(r, k) => {
          if (k === 'truck') return (
            <div style={{ display: 'flex', alignItems: 'center', gap: 12 }}>
              <WellB icon="local_shipping" tone="blue" size={36} radius={10} />
              <div><PlateB size="sm">{r.plate}</PlateB><div style={{ fontSize: 12.5, color: 'var(--text-muted)' }}>{r.driver}</div></div>
            </div>);
          if (k === 'route') return <RouteArrow from={r.from} to={r.to} />;
          if (k === 'status') return <BadgeB tone={r.tone}>{r.status}</BadgeB>;
          if (k === 'time') return <span style={{ fontFamily: 'var(--font-mono)', fontSize: 13.5, color: 'var(--text-muted)' }}>{r.time}</span>;
          return <button type="button" style={{ border: 'none', background: 'transparent', cursor: 'pointer', color: 'var(--text-faint)', display: 'flex' }}><IconB name="more_vert" size={18} /></button>;
        }}
      />
      <div style={{ textAlign: 'center', marginTop: 14 }}>
        <button type="button" style={{ border: 'none', background: 'transparent', color: 'var(--accent)', fontWeight: 700, fontSize: 14, cursor: 'pointer', display: 'inline-flex', alignItems: 'center', gap: 6 }}>View all trips <IconB name="arrow_forward" size={16} /></button>
      </div>
    </DSb.Card>
  );
}

function BuyerDashboard({ go }) {
  return (
    <div style={{ display: 'flex', flexDirection: 'column', gap: 20 }}>
      <div style={{ display: 'flex', alignItems: 'center', gap: 18, padding: '18px 22px', borderRadius: 'var(--radius-xl)', background: 'linear-gradient(110deg,#0b192e 0%,#0b2545 55%,#0496b6 140%)', boxShadow: 'var(--shadow-md)' }}>
        <div style={{ width: 48, height: 48, borderRadius: 14, background: 'rgba(255,255,255,.12)', display: 'flex', alignItems: 'center', justifyContent: 'center', flexShrink: 0 }}><IconB name="local_shipping" size={26} color="#fff" fill={1} /></div>
        <div style={{ flex: 1 }}>
          <div style={{ fontSize: 17, fontWeight: 800, color: '#fff' }}>Need trucks on a route?</div>
          <div style={{ fontSize: 13.5, color: 'rgba(226,232,240,.8)', marginTop: 2 }}>Send a contract-ready haulage request to your MineLink representative — matched with qualified transporters.</div>
        </div>
        <button type="button" onClick={() => go('request-new')} style={{ display: 'inline-flex', alignItems: 'center', gap: 9, padding: '13px 20px', borderRadius: 'var(--radius-md)', border: 'none', background: 'var(--accent)', color: '#fff', fontFamily: 'var(--font-sans)', fontSize: 14.5, fontWeight: 700, cursor: 'pointer', boxShadow: '0 4px 14px rgba(0,181,216,.4)', whiteSpace: 'nowrap' }}><IconB name="add" size={20} />Request transportation</button>
      </div>
      <div style={{ display: 'grid', gridTemplateColumns: 'repeat(4,1fr)', gap: 16 }}>
        <StatCard icon="description" label="Active Waybills" value="14" tone="cyan" />
        <StatCard icon="inventory_2" label="Tons Allocated" value="1,240" unit="t" tone="blue" />
        <StatCard icon="local_shipping" label="Active Trips" value="3" tone="cyan" />
        <StatCard icon="balance" label="Pending Recons" value="2" tone="amber" />
      </div>
      <div style={{ display: 'grid', gridTemplateColumns: 'repeat(3,1fr)', gap: 16 }}>
        <FeatureCard icon="alt_route" title="Routes & Mines" tone="cyan" description="View all your active routes across mines and offload points. Assign trucks per route." onOpen={() => go('routes')} />
        <FeatureCard icon="balance" title="Reconciliations" tone="amber" description="View recons per mine, per individual route, or across all your operations at a glance." onOpen={() => go('recons')} />
        <FeatureCard icon="map" title="Truck Locations" tone="green" description="Live map showing all trucks assigned to your routes — see position and current status." onOpen={() => go('locations')} />
      </div>
      <TripTable rows={BUYER_TRIPS} onMap={() => go('locations')} />
    </div>
  );
}

function NewRouteModal({ open, onClose }) {
  const [seal, setSeal] = React.useState('required');
  if (!open) return null;
  return (
    <ModalB open={open} title="Create transport route" onClose={onClose} width={480}
      footer={<><BtnB variant="outline" onClick={onClose}>Cancel</BtnB><BtnB icon="check_circle" onClick={onClose}>Create route</BtnB></>}>
      <div style={{ display: 'flex', flexDirection: 'column', gap: 16 }}>
        <div style={{ display: 'flex', gap: 12 }}>
          <div style={{ flex: 1 }}><InputB label="Loading point" required icon="location_on" placeholder="e.g. Mogalakwena Mine" /></div>
          <div style={{ flex: 1 }}><InputB label="Offloading point" required icon="warehouse" placeholder="e.g. Saldanha" /></div>
        </div>
        <DSb.Select label="Commodity" icon="diamond" options={['Iron Ore', 'Chrome Ore', 'Manganese', 'Coal']} />
        <div style={{ display: 'flex', gap: 12 }}>
          <div style={{ flex: 1 }}><DSb.Select label="Payment terms" icon="payments" options={['50/50', 'Daily', '7 days', '14 days', '30 days']} /></div>
          <div style={{ flex: 1 }}><InputB label="Operational hours" icon="schedule" placeholder="e.g. 24/7" /></div>
        </div>
        {/* Seal requirement — slide 1 */}
        <div>
          <div style={{ fontSize: 13, fontWeight: 600, color: 'var(--text-body)', marginBottom: 8 }}>Seal requirement</div>
          <div style={{ display: 'flex', flexDirection: 'column', gap: 8 }}>
            {[['required', 'lock', 'Required', "Can't complete a load without a photo of each seal & its number."], ['optional', 'lock_open', 'Not required', 'Loads can be completed without seal photos or numbers.']].map(([v, ic, t, d]) => {
              const on = seal === v;
              return (
                <button key={v} type="button" onClick={() => setSeal(v)} style={{ display: 'flex', alignItems: 'flex-start', gap: 12, textAlign: 'left', padding: 14, borderRadius: 'var(--radius-md)', cursor: 'pointer', border: `1.5px solid ${on ? 'var(--accent)' : 'var(--border-card)'}`, background: on ? 'var(--ml-well-cyan)' : 'var(--surface-card)' }}>
                  <IconB name={ic} size={20} color={on ? 'var(--accent)' : 'var(--text-faint)'} />
                  <div style={{ flex: 1 }}><div style={{ fontSize: 14.5, fontWeight: 700, color: 'var(--text-strong)' }}>{t}</div><div style={{ fontSize: 12.5, color: 'var(--text-muted)', marginTop: 1 }}>{d}</div></div>
                  <span style={{ width: 20, height: 20, borderRadius: 999, border: `2px solid ${on ? 'var(--accent)' : 'var(--border-strong)'}`, display: 'flex', alignItems: 'center', justifyContent: 'center', flexShrink: 0, marginTop: 1 }}>{on && <span style={{ width: 10, height: 10, borderRadius: 999, background: 'var(--accent)' }} />}</span>
                </button>
              );
            })}
          </div>
        </div>
      </div>
    </ModalB>
  );
}

function BuyerRoutesMines({ go }) {
  const [newRoute, setNewRoute] = React.useState(false);
  const routes = [
    { mine: 'Mogalakwena Mine', to: 'Saldanha Steel Works', trucks: 4, tons: '620 t', tone: 'cyan' },
    { mine: 'Thabazimbi Mine', to: 'Vanderbijlpark', trucks: 2, tons: '310 t', tone: 'amber' },
    { mine: 'Mogalakwena Mine', to: 'Richards Bay', trucks: 3, tons: '310 t', tone: 'green' },
  ];
  return (
    <div>
      <NewRouteModal open={newRoute} onClose={() => setNewRoute(false)} />
      <STitleB icon="alt_route" action={<BtnB icon="add" size="sm" onClick={() => setNewRoute(true)}>New route</BtnB>}>Routes &amp; Mines</STitleB>
      <div style={{ display: 'grid', gridTemplateColumns: 'repeat(2,1fr)', gap: 16 }}>
        {routes.map((r, i) => (
          <DSb.Card key={i} onClick={() => go('locations')} tone="plain">
            <div style={{ display: 'flex', alignItems: 'flex-start', gap: 14 }}>
              <WellB icon="conveyor_belt" tone={r.tone} size={48} radius={14} />
              <div style={{ flex: 1 }}>
                <RouteArrow from={r.mine} to={r.to} color="var(--text-strong)" />
                <div style={{ display: 'flex', gap: 18, marginTop: 12 }}>
                  <div><div style={{ fontSize: 12, color: 'var(--text-muted)' }}>Assigned trucks</div><div style={{ fontSize: 20, fontWeight: 800, color: 'var(--text-strong)' }}>{r.trucks}</div></div>
                  <div><div style={{ fontSize: 12, color: 'var(--text-muted)' }}>Tons this week</div><div style={{ fontSize: 20, fontWeight: 800, color: 'var(--accent)' }}>{r.tons}</div></div>
                </div>
              </div>
              <IconB name="chevron_right" size={22} color="var(--text-faint)" />
            </div>
          </DSb.Card>
        ))}
      </div>
    </div>
  );
}

function BuyerTruckLocations() {
  const [sel, setSel] = React.useState('t1');
  const trucks = [
    { id: 'b1', plate: 'BKG 456 GP', driver: 'Sipho Ndlovu', tone: 'done', status: 'Available', route: null },
    { id: 't1', plate: 'CDF 789 LP', driver: 'Thabo Mokoena', tone: 'transit', status: 'On Trip', route: 'Mogalakwena Mine → Saldanha Steel Works' },
    { id: 't2', plate: 'JKL 012 NW', driver: 'Pieter van Wyk', tone: 'transit', status: 'On Trip', route: 'Thabazimbi Mine → Vanderbijlpark' },
    { id: 'b2', plate: 'MNP 345 MP', driver: 'David Mthembu', tone: 'done', status: 'Available', route: null },
    { id: 'm1', plate: 'XYZ 901 LP', driver: 'Mandla Zulu', tone: 'warn', status: 'Maintenance', route: null },
  ];
  return (
    <div style={{ display: 'grid', gridTemplateColumns: '380px 1fr', gap: 16, height: 'calc(100vh - 160px)', minHeight: 480 }}>
      <div style={{ display: 'flex', flexDirection: 'column', gap: 12, overflowY: 'auto', paddingRight: 4 }}>
        {trucks.map((t) => (
          <DSb.Card key={t.id} padding={16} onClick={() => setSel(t.id)} style={{ borderColor: sel === t.id ? 'var(--accent)' : 'var(--border-card)', borderWidth: sel === t.id ? 1.5 : 1 }}>
            <div style={{ display: 'flex', alignItems: 'center', justifyContent: 'space-between' }}>
              <PlateB>{t.plate}</PlateB>
              <BadgeB tone={t.tone}>{t.status}</BadgeB>
            </div>
            <div style={{ fontSize: 13.5, color: 'var(--text-muted)', marginTop: 6 }}>{t.driver}</div>
            {t.route && <div style={{ fontSize: 13, color: 'var(--accent)', marginTop: 6, fontWeight: 600 }}>{t.route}</div>}
            <div style={{ fontSize: 12, color: 'var(--text-faint)', marginTop: 6 }}>No GPS data</div>
          </DSb.Card>
        ))}
      </div>
      <MapB>
        <div style={{ position: 'absolute', inset: 0, display: 'flex', flexDirection: 'column', alignItems: 'center', justifyContent: 'center', color: 'var(--text-faint)', textAlign: 'center', padding: 20 }}>
          <IconB name="local_shipping" size={90} color="#cbd5e1" />
          <div style={{ fontSize: 20, fontWeight: 700, color: 'var(--text-muted)', marginTop: 14 }}>No trucks have GPS coordinates recorded.</div>
          <div style={{ fontSize: 14, marginTop: 6 }}>GPS is updated when drivers report via the Driver App.</div>
        </div>
      </MapB>
    </div>
  );
}

function BuyerReconciliations() {
  const recs = [
    { mine: 'Mogalakwena Mine', loaded: '620 t', received: '614 t', variance: '-6 t', tone: 'atmine', state: 'REVIEW' },
    { mine: 'Thabazimbi Mine', loaded: '310 t', received: '310 t', variance: '0 t', tone: 'done', state: 'MATCHED' },
    { mine: 'Richards Bay Route', loaded: '290 t', received: '286 t', variance: '-4 t', tone: 'atmine', state: 'REVIEW' },
  ];
  return (
    <div>
      <STitleB icon="balance" action={<BtnB icon="download" size="sm" variant="outline">Export</BtnB>}>Reconciliations</STitleB>
      <DSb.Card padding={22}>
        <TableB
          columns={[
            { key: 'mine', label: 'Mine / Route', w: '1.6fr' },
            { key: 'loaded', label: 'Tons Loaded', w: '1fr', align: 'right' },
            { key: 'received', label: 'Received', w: '1fr', align: 'right' },
            { key: 'variance', label: 'Variance', w: '1fr', align: 'right' },
            { key: 'state', label: 'Status', w: '1fr', align: 'right' },
          ]}
          rows={recs}
          renderCell={(r, k) => {
            if (k === 'mine') return <span style={{ fontWeight: 600, color: 'var(--text-strong)' }}>{r.mine}</span>;
            if (k === 'state') return <BadgeB tone={r.tone}>{r.state}</BadgeB>;
            if (k === 'variance') return <span style={{ fontFamily: 'var(--font-mono)', fontWeight: 700, color: r.variance === '0 t' ? 'var(--ml-green-600)' : 'var(--ml-orange-600)' }}>{r.variance}</span>;
            return <span style={{ fontFamily: 'var(--font-mono)', fontSize: 14, color: 'var(--text-body)' }}>{r[k]}</span>;
          }}
        />
      </DSb.Card>
    </div>
  );
}

function BuyerWaybills() {
  return (
    <div>
      <STitleB icon="description">Waybills</STitleB>
      <DSb.Card padding={22}>
        <TableB
          columns={[
            { key: 'wb', label: 'Waybill #', w: '1fr' },
            { key: 'truck', label: 'Truck', w: '1fr' },
            { key: 'route', label: 'Route', w: '1.8fr' },
            { key: 'tons', label: 'Tons', w: '0.7fr', align: 'right' },
            { key: 'state', label: 'Status', w: '1fr', align: 'right' },
          ]}
          rows={[
            { id: 1, wb: 'WB-0045', truck: 'CDF 789 LP', from: 'Mogalakwena', to: 'Saldanha', tons: '34.5 t', tone: 'done', state: 'SIGNED' },
            { id: 2, wb: 'WB-0046', truck: 'JKL 012 NW', from: 'Thabazimbi', to: 'Vanderbijlpark', tons: '—', tone: 'atmine', state: 'PENDING' },
            { id: 3, wb: 'WB-0047', truck: 'BKG 456 GP', from: 'Mogalakwena', to: 'Saldanha', tons: '31.8 t', tone: 'done', state: 'SIGNED' },
          ]}
          renderCell={(r, k) => {
            if (k === 'wb') return <span style={{ fontFamily: 'var(--font-mono)', fontWeight: 700, color: 'var(--text-strong)' }}>{r.wb}</span>;
            if (k === 'truck') return <PlateB size="sm">{r.truck}</PlateB>;
            if (k === 'route') return <RouteArrow from={r.from} to={r.to} />;
            if (k === 'state') return <BadgeB tone={r.tone}>{r.state}</BadgeB>;
            return <span style={{ fontFamily: 'var(--font-mono)', fontSize: 14 }}>{r.tons}</span>;
          }}
        />
      </DSb.Card>
    </div>
  );
}

/* ============ Request Transportation (premium contract-ready form) ============ */
const MINERALS = ['Iron Ore', 'Chrome Ore', 'Manganese', 'Coal', 'Copper Concentrate', 'Platinum Ore'];
const PAY_TERMS = ['50/50', 'Daily', '7 days', '14 days', '30 days', '60 days'];
const DIESEL = ['On account', 'On transporter'];
const DAYS = ['Mon', 'Tue', 'Wed', 'Thu', 'Fri', 'Sat', 'Sun'];

function FieldShell({ label, required, hint, children }) {
  return (
    <label style={{ display: 'flex', flexDirection: 'column', gap: 7, flex: 1, minWidth: 0 }}>
      <span style={{ fontSize: 11, fontWeight: 700, textTransform: 'uppercase', letterSpacing: '.07em', color: 'var(--text-faint)' }}>{label}{required && <span style={{ color: 'var(--accent)' }}> *</span>}{hint && <span style={{ float: 'right', textTransform: 'none', letterSpacing: 0, fontWeight: 500, color: 'var(--text-faint)' }}>{hint}</span>}</span>
      {children}
    </label>
  );
}
function TextField({ label, required, hint, suffix, icon, value, onChange, placeholder, type = 'text' }) {
  return (
    <FieldShell label={label} required={required} hint={hint}>
      <span style={{ position: 'relative', display: 'flex', alignItems: 'center' }}>
        {icon && <span style={{ position: 'absolute', left: 13, display: 'flex', pointerEvents: 'none' }}><IconB name={icon} size={18} color="var(--text-faint)" /></span>}
        <input value={value} onChange={(e) => onChange(e.target.value)} placeholder={placeholder} type={type}
          style={{ width: '100%', boxSizing: 'border-box', padding: icon ? '13px 14px 13px 40px' : '13px 14px', paddingRight: suffix ? 48 : 14, background: 'var(--surface-sunken)', border: '1.5px solid transparent', borderRadius: 'var(--radius-md)', fontFamily: 'var(--font-sans)', fontSize: 15, color: 'var(--text-strong)', outline: 'none', transition: 'border-color .14s, background .14s' }}
          onFocus={(e) => { e.target.style.borderColor = 'var(--accent)'; e.target.style.background = 'var(--surface-card)'; }} onBlur={(e) => { e.target.style.borderColor = 'transparent'; e.target.style.background = 'var(--surface-sunken)'; }} />
        {suffix && <span style={{ position: 'absolute', right: 14, fontSize: 13, color: 'var(--text-faint)', fontFamily: 'var(--font-mono)' }}>{suffix}</span>}
      </span>
    </FieldShell>
  );
}
function FormSelect({ label, required, placeholder = 'Select', options = [], value, onChange }) {
  return (
    <FieldShell label={label} required={required}>
      <span style={{ position: 'relative', display: 'flex', alignItems: 'center' }}>
        <select value={value} onChange={(e) => onChange(e.target.value)}
          style={{ width: '100%', boxSizing: 'border-box', appearance: 'none', WebkitAppearance: 'none', padding: '13px 40px 13px 14px', background: 'var(--surface-sunken)', border: '1.5px solid transparent', borderRadius: 'var(--radius-md)', fontFamily: 'var(--font-sans)', fontSize: 15, fontWeight: value ? 600 : 400, color: value ? 'var(--text-strong)' : 'var(--text-faint)', cursor: 'pointer', outline: 'none' }}
          onFocus={(e) => { e.target.style.borderColor = 'var(--accent)'; e.target.style.background = 'var(--surface-card)'; }} onBlur={(e) => { e.target.style.borderColor = 'transparent'; e.target.style.background = 'var(--surface-sunken)'; }}>
          <option value="">{placeholder}</option>
          {options.map((o) => <option key={o} value={o}>{o}</option>)}
        </select>
        <span style={{ position: 'absolute', right: 12, pointerEvents: 'none', display: 'flex' }}><IconB name="expand_more" size={20} color="var(--text-muted)" /></span>
      </span>
    </FieldShell>
  );
}
const TIME_OPTS = Array.from({ length: 24 }, (_, h) => String(h).padStart(2, '0') + ':00');
function CheckRow({ checked, onChange, title, sub }) {
  return (
    <div onClick={() => onChange(!checked)} style={{ display: 'flex', alignItems: 'center', gap: 12, cursor: 'pointer' }}>
      <span style={{ width: 22, height: 22, borderRadius: 6, flexShrink: 0, border: `1.5px solid ${checked ? 'var(--accent)' : 'var(--border-strong)'}`, background: checked ? 'var(--accent)' : 'var(--surface-card)', display: 'flex', alignItems: 'center', justifyContent: 'center' }}>{checked && <IconB name="check" size={16} color="#fff" weight={700} />}</span>
      <span><span style={{ display: 'block', fontSize: 15, fontWeight: 700, color: 'var(--text-strong)' }}>{title}</span><span style={{ display: 'block', fontSize: 12.5, color: 'var(--text-muted)' }}>{sub}</span></span>
    </div>
  );
}
function SectionCard({ n, title, hint, icon, children }) {
  return (
    <div style={{ background: 'var(--surface-card)', border: '1px solid var(--border-card)', borderRadius: 'var(--radius-xl)', boxShadow: 'var(--shadow-sm)', padding: 24 }}>
      <div style={{ display: 'flex', alignItems: 'center', gap: 12, marginBottom: 20 }}>
        <div style={{ width: 30, height: 30, borderRadius: 9, background: 'var(--ml-well-cyan)', display: 'flex', alignItems: 'center', justifyContent: 'center', fontFamily: 'var(--font-mono)', fontSize: 13, fontWeight: 700, color: 'var(--accent)' }}>{n}</div>
        <h3 style={{ margin: 0, fontSize: 17, fontWeight: 800, color: 'var(--text-strong)', flex: 1 }}>{title}</h3>
        {hint && <span style={{ fontSize: 12.5, color: 'var(--text-faint)' }}>{hint}</span>}
      </div>
      {children}
    </div>
  );
}
function Segmented({ options, value, onChange }) {
  return (
    <div style={{ display: 'inline-flex', background: 'var(--surface-sunken)', borderRadius: 'var(--radius-md)', padding: 3, gap: 2 }}>
      {options.map((o) => (
        <button key={o} type="button" onClick={() => onChange(o)} style={{ padding: '8px 14px', borderRadius: 9, border: 'none', cursor: 'pointer', fontFamily: 'var(--font-sans)', fontSize: 13.5, fontWeight: 600, background: value === o ? 'var(--surface-card)' : 'transparent', color: value === o ? 'var(--text-strong)' : 'var(--text-muted)', boxShadow: value === o ? 'var(--shadow-xs)' : 'none' }}>{o}</button>
      ))}
    </div>
  );
}
function Toggle({ on, onChange }) {
  return (
    <button type="button" onClick={() => onChange(!on)} style={{ width: 46, height: 27, borderRadius: 999, border: 'none', cursor: 'pointer', background: on ? 'var(--accent)' : 'var(--ml-slate-300)', position: 'relative', transition: 'background .18s', flexShrink: 0 }}>
        <span style={{ position: 'absolute', top: 3, left: on ? 22 : 3, width: 21, height: 21, borderRadius: 999, background: '#fff', boxShadow: 'var(--shadow-xs)', transition: 'left .18s var(--ease-out-cubic)' }} />
    </button>
  );
}

function RequestTransportation({ go }) {
  const [f, setF] = React.useState({ loading: '', offload: '', commodity: '', distance: '', tons: '', slots: '', duration: '', pay: '30 days', diesel: 'On account', rate: '', hours24: false, start: '06:00', end: '18:00', days: ['Mon', 'Tue', 'Wed', 'Thu', 'Fri'], ongoing: false, startDate: '', notes: '' });
  const set = (k, v) => setF((s) => ({ ...s, [k]: v }));
  const toggleDay = (d) => setF((s) => ({ ...s, days: s.days.includes(d) ? s.days.filter((x) => x !== d) : [...s.days, d] }));
  const [sent, setSent] = React.useState(false);

  const req = [['loading', f.loading], ['offload', f.offload], ['commodity', f.commodity], ['pay', f.pay], ['diesel', f.diesel]];
  const sched = f.hours24 || (f.start && f.end);
  const dateOk = f.ongoing || f.startDate;
  const filled = req.filter(([, v]) => v && String(v).trim()).length + (sched ? 1 : 0) + (dateOk ? 1 : 0);
  const total = req.length + 2;
  const pct = Math.round((filled / total) * 100);

  const rateNum = parseFloat(f.rate) || 0;
  const tonsNum = parseFloat((f.tons || '').replace(/,/g, '')) || 0;

  return (
    <div>
      <button type="button" onClick={() => go('dashboard')} style={{ display: 'inline-flex', alignItems: 'center', gap: 7, marginBottom: 16, padding: '8px 14px', borderRadius: 'var(--radius-md)', border: '1px solid var(--border-strong)', background: 'var(--surface-card)', color: 'var(--text-body)', fontSize: 13.5, fontWeight: 600, cursor: 'pointer' }}><IconB name="chevron_left" size={18} />Back to dashboard</button>
      <div style={{ display: 'flex', alignItems: 'flex-start', gap: 16, marginBottom: 22 }}>
        <div style={{ flex: 1 }}>
          <h1 style={{ margin: 0, fontSize: 27, fontWeight: 800, color: 'var(--text-strong)', letterSpacing: '-.01em' }}>New transport request</h1>
          <p style={{ margin: '6px 0 0', fontSize: 14, color: 'var(--text-muted)' }}>Create a contract-ready haulage request for your mineral routes — sent to your MineLink representative for matching.</p>
        </div>
        <BadgeB tone={sent ? 'done' : 'neutral'} dot>{sent ? 'Submitted' : 'Draft · auto-saved'}</BadgeB>
      </div>

      <div style={{ display: 'grid', gridTemplateColumns: 'minmax(0,1fr) 340px', gap: 20, alignItems: 'start' }}>
        <div style={{ display: 'flex', flexDirection: 'column', gap: 16 }}>
          <SectionCard n="01" title="Route" hint="Origin, destination & load profile">
            <div style={{ display: 'flex', gap: 14, marginBottom: 16 }}>
              <TextField label="Loading point" required icon="location_on" placeholder="e.g. Mogalakwena Mine" value={f.loading} onChange={(v) => set('loading', v)} />
              <div style={{ display: 'flex', alignItems: 'flex-end', paddingBottom: 8 }}><IconB name="sync_alt" size={20} color="var(--text-faint)" /></div>
              <TextField label="Offloading point" required icon="warehouse" placeholder="e.g. Saldanha Steel Works" value={f.offload} onChange={(v) => set('offload', v)} />
            </div>
            <div style={{ marginBottom: 16 }}>
              <FormSelect label="Commodity" required placeholder="Select commodity" options={MINERALS} value={f.commodity} onChange={(v) => set('commodity', v)} />
            </div>
            <div style={{ display: 'grid', gridTemplateColumns: 'repeat(3,1fr)', gap: 14, marginBottom: 16 }}>
              <TextField label="Distance" hint="est." suffix="km" type="number" placeholder="480" value={f.distance} onChange={(v) => set('distance', v)} />
              <TextField label="Tons available" suffix="t" type="number" placeholder="2,400" value={f.tons} onChange={(v) => set('tons', v)} />
              <TextField label="No. of slots" suffix="trucks" type="number" placeholder="12" value={f.slots} onChange={(v) => set('slots', v)} />
            </div>
            <TextField label="Contract duration" icon="event_repeat" placeholder="e.g. 3 months / 12,000 t" value={f.duration} onChange={(v) => set('duration', v)} />
          </SectionCard>

          <SectionCard n="02" title="Commercials" hint="Pricing & payment terms">
            <div style={{ display: 'flex', flexDirection: 'column', gap: 16 }}>
              <FormSelect label="Payment terms" required placeholder="Select payment terms" options={PAY_TERMS} value={f.pay} onChange={(v) => set('pay', v)} />
              <FormSelect label="Diesel" required placeholder="Select diesel arrangement" options={DIESEL} value={f.diesel} onChange={(v) => set('diesel', v)} />
              <TextField label="Rate" suffix="R / t" type="number" placeholder="0.00" value={f.rate} onChange={(v) => set('rate', v)} />
            </div>
          </SectionCard>

          <SectionCard n="03" title="Mine loading operation hours" hint="When trucks can load">
            <div style={{ display: 'flex', alignItems: 'center', gap: 14, padding: '14px 16px', background: 'var(--surface-app)', borderRadius: 'var(--radius-md)', border: '1px solid var(--border-card)', marginBottom: f.hours24 ? 0 : 18 }}>
              <IconB name="schedule" size={22} color="var(--accent)" />
              <div style={{ flex: 1 }}><div style={{ fontSize: 14.5, fontWeight: 700, color: 'var(--text-strong)' }}>24 hours</div><div style={{ fontSize: 12.5, color: 'var(--text-muted)' }}>Mine operates continuously</div></div>
              <Toggle on={f.hours24} onChange={(v) => set('hours24', v)} />
            </div>
            {!f.hours24 && (<>
              <div style={{ display: 'flex', gap: 14, marginBottom: 16 }}>
                <FormSelect label="Start time" placeholder="Select" options={TIME_OPTS} value={f.start} onChange={(v) => set('start', v)} />
                <FormSelect label="End time" placeholder="Select" options={TIME_OPTS} value={f.end} onChange={(v) => set('end', v)} />
              </div>
              <FieldShell label="Operating days">
                <div style={{ display: 'flex', gap: 8 }}>
                  {DAYS.map((d) => (
                    <button key={d} type="button" onClick={() => toggleDay(d)} style={{ width: 46, height: 40, borderRadius: 'var(--radius-md)', border: `1.5px solid ${f.days.includes(d) ? 'var(--accent)' : 'var(--border-strong)'}`, cursor: 'pointer', fontFamily: 'var(--font-sans)', fontSize: 12.5, fontWeight: 700, background: f.days.includes(d) ? 'var(--accent)' : 'var(--surface-card)', color: f.days.includes(d) ? '#fff' : 'var(--text-muted)' }}>{d}</button>
                  ))}
                </div>
              </FieldShell>
            </>)}
          </SectionCard>

          <SectionCard n="04" title="Starting date" hint="Earliest selectable is tomorrow">
            <div style={{ marginBottom: f.ongoing ? 0 : 18 }}>
              <CheckRow checked={f.ongoing} onChange={(v) => set('ongoing', v)} title="Ongoing" sub="No fixed starting period" />
            </div>
            {!f.ongoing && <TextField label="Starting date" icon="calendar_month" type="date" value={f.startDate} onChange={(v) => set('startDate', v)} />}
          </SectionCard>

          <SectionCard n="05" title="Notes" hint="Optional">
            <textarea value={f.notes} onChange={(e) => set('notes', e.target.value)} placeholder="Route notes — access requirements, weighbridge details, special handling…" rows={3}
              style={{ width: '100%', boxSizing: 'border-box', padding: 14, background: 'var(--surface-card)', border: '1.5px solid var(--border-strong)', borderRadius: 'var(--radius-md)', fontFamily: 'var(--font-sans)', fontSize: 15, color: 'var(--text-strong)', outline: 'none', resize: 'vertical' }}
              onFocus={(e) => { e.target.style.borderColor = 'var(--accent)'; }} onBlur={(e) => { e.target.style.borderColor = 'var(--border-strong)'; }} />
          </SectionCard>
        </div>

        {/* Live preview panel */}
        <div style={{ position: 'sticky', top: 0, display: 'flex', flexDirection: 'column', gap: 14, borderRadius: 'var(--radius-xl)', overflow: 'hidden', background: 'linear-gradient(165deg,#0b192e,#020617)', boxShadow: 'var(--shadow-lg)' }}>
          <div style={{ padding: '20px 20px 0' }}>
            <div style={{ fontSize: 11, fontWeight: 700, letterSpacing: '.14em', color: 'var(--accent)' }}>LIVE PREVIEW</div>
            <div style={{ fontSize: 19, fontWeight: 800, color: '#fff', marginTop: 4 }}>Request summary</div>
            <div style={{ fontSize: 12, color: 'rgba(148,163,184,.9)', fontFamily: 'var(--font-mono)', marginTop: 2 }}>REQ · DRAFT-26-001847</div>
          </div>
          <div style={{ display: 'flex', alignItems: 'center', gap: 12, padding: '0 20px' }}>
            <div style={{ position: 'relative', width: 46, height: 46, flexShrink: 0 }}>
              <svg width="46" height="46" style={{ transform: 'rotate(-90deg)' }}><circle cx="23" cy="23" r="19" fill="none" stroke="rgba(148,163,184,.25)" strokeWidth="4" /><circle cx="23" cy="23" r="19" fill="none" stroke="#00b5d8" strokeWidth="4" strokeDasharray={`${(pct / 100) * 119} 119`} strokeLinecap="round" style={{ transition: 'stroke-dasharray .4s' }} /></svg>
              <span style={{ position: 'absolute', inset: 0, display: 'flex', alignItems: 'center', justifyContent: 'center', fontSize: 12, fontWeight: 800, color: '#fff' }}>{pct}%</span>
            </div>
            <div><div style={{ fontSize: 14.5, fontWeight: 700, color: '#fff' }}>{pct === 100 ? 'Ready to submit' : pct >= 60 ? 'Almost ready' : 'In progress'}</div><div style={{ fontSize: 12, color: 'rgba(148,163,184,.9)' }}>{total - filled} field group(s) left</div></div>
          </div>
          <div style={{ margin: '4px 16px 0', padding: 16, borderRadius: 'var(--radius-md)', background: 'rgba(148,163,184,.08)' }}>
            <SummaryRow icon="radio_button_checked" label="LOADING · A" val={f.loading || 'Loading point'} muted={!f.loading} />
            <div style={{ height: 14, borderLeft: '1.5px dashed rgba(148,163,184,.35)', marginLeft: 8 }} />
            <SummaryRow icon="place" label="OFFLOAD · B" val={f.offload || 'Offloading point'} muted={!f.offload} />
          </div>
          <div style={{ display: 'flex', alignItems: 'center', gap: 10, margin: '0 16px', padding: 14, borderRadius: 'var(--radius-md)', background: 'rgba(148,163,184,.08)' }}>
            <div style={{ width: 34, height: 34, borderRadius: 10, background: 'rgba(0,181,216,.18)', display: 'flex', alignItems: 'center', justifyContent: 'center' }}><IconB name="diamond" size={17} color="var(--accent)" fill={1} /></div>
            <div style={{ flex: 1 }}><div style={{ fontSize: 10.5, color: 'rgba(148,163,184,.9)', letterSpacing: '.06em' }}>COMMODITY</div><div style={{ fontSize: 14, fontWeight: 700, color: f.commodity ? '#fff' : 'rgba(148,163,184,.7)' }}>{f.commodity || 'Not selected'}</div></div>
          </div>
          <div style={{ display: 'grid', gridTemplateColumns: '1fr 1fr', gap: 1, margin: '0 16px', background: 'rgba(148,163,184,.12)', borderRadius: 'var(--radius-md)', overflow: 'hidden' }}>
            <SummaryStat label="TONNAGE" val={f.tons || '—'} unit="t" />
            <SummaryStat label="DISTANCE" val={f.distance || '—'} unit="km" />
            <SummaryStat label="SLOTS" val={f.slots || '—'} unit="trucks" />
            <SummaryStat label="PAY TERMS" val={f.pay} unit="" />
          </div>
          <div style={{ margin: '0 16px', padding: 16, borderRadius: 'var(--radius-md)', background: 'rgba(0,181,216,.1)', border: '1px solid rgba(0,181,216,.25)' }}>
            <div style={{ fontSize: 10.5, color: 'var(--accent)', letterSpacing: '.06em', fontWeight: 700 }}>INDICATIVE HAUL RATE</div>
            <div style={{ display: 'flex', alignItems: 'baseline', gap: 4, marginTop: 4 }}><span style={{ fontSize: 26, fontWeight: 800, color: '#fff', fontFamily: 'var(--font-mono)' }}>R {rateNum ? rateNum.toFixed(2) : '0.00'}</span><span style={{ fontSize: 12, color: 'rgba(148,163,184,.9)' }}>/ t · {f.diesel}</span></div>
            {rateNum > 0 && tonsNum > 0 && <div style={{ fontSize: 12, color: 'rgba(226,232,240,.85)', marginTop: 6 }}>≈ <b style={{ color: '#fff' }}>R {(rateNum * tonsNum).toLocaleString(undefined, { maximumFractionDigits: 0 })}</b> total for {tonsNum.toLocaleString()} t</div>}
          </div>
          <div style={{ padding: '6px 16px 18px', display: 'flex', flexDirection: 'column', gap: 10 }}>
            <button type="button" onClick={() => setSent(true)} style={{ display: 'inline-flex', alignItems: 'center', justifyContent: 'center', gap: 9, padding: '14px', borderRadius: 'var(--radius-md)', border: 'none', background: 'var(--accent)', color: '#fff', fontFamily: 'var(--font-sans)', fontSize: 15, fontWeight: 700, cursor: 'pointer', boxShadow: '0 4px 14px rgba(0,181,216,.4)' }}><IconB name="send" size={19} />{sent ? 'Request sent ✓' : 'Submit request'}</button>
            <button type="button" onClick={() => go('dashboard')} style={{ padding: '12px', borderRadius: 'var(--radius-md)', border: '1px solid rgba(148,163,184,.3)', background: 'transparent', color: 'rgba(226,232,240,.9)', fontFamily: 'var(--font-sans)', fontSize: 14, fontWeight: 600, cursor: 'pointer' }}>Save & review later</button>
          </div>
        </div>
      </div>
    </div>
  );
}
function SummaryRow({ icon, label, val, muted }) {
  return (
    <div style={{ display: 'flex', alignItems: 'center', gap: 10 }}>
      <IconB name={icon} size={16} color={muted ? 'rgba(148,163,184,.6)' : 'var(--accent)'} />
      <div><div style={{ fontSize: 10, color: 'rgba(148,163,184,.9)', letterSpacing: '.06em' }}>{label}</div><div style={{ fontSize: 13.5, fontWeight: 700, color: muted ? 'rgba(148,163,184,.7)' : '#fff' }}>{val}</div></div>
    </div>
  );
}
function SummaryStat({ label, val, unit }) {
  return (
    <div style={{ background: '#0b192e', padding: '12px 14px' }}>
      <div style={{ fontSize: 10, color: 'rgba(148,163,184,.9)', letterSpacing: '.06em' }}>{label}</div>
      <div style={{ display: 'flex', alignItems: 'baseline', gap: 3, marginTop: 2 }}><span style={{ fontSize: 17, fontWeight: 800, color: '#fff', fontFamily: 'var(--font-mono)' }}>{val}</span>{unit && <span style={{ fontSize: 11, color: 'rgba(148,163,184,.9)' }}>{unit}</span>}</div>
    </div>
  );
}

window.BuyerScreens = { BuyerDashboard, BuyerRoutesMines, BuyerTruckLocations, BuyerReconciliations, BuyerWaybills, RequestTransportation };
