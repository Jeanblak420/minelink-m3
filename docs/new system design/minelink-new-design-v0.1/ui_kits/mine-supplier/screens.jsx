/* MineLink — Mine / Supplier Portal screens (incl. Control + mobile Security). */
const DSm = window.MineLinkDesignSystem_9acfde;
const { Icon: IconM, StatCard: StatM, FeatureCard: FeatM, StatusBadge: BadgeM, PlatePill: PlateM, Button: BtnM, Avatar: AvM, Input: InM, FileUpload: FileM, Checkbox: CheckM, Select: SelM } = DSm;
const { SectionTitle: STitleM, DataTable: TableM, SlideOver: SlideM, IconWell: WellM } = window.MLShell;

function RouteArrowM({ from, to, color }) {
  return <span style={{ display: 'inline-flex', alignItems: 'center', gap: 7, fontSize: 13.5, color: color || 'var(--text-body)' }}>{from} <IconM name="arrow_forward" size={14} color="var(--text-faint)" /> {to}</span>;
}

function MineOverview({ go }) {
  return (
    <div style={{ display: 'flex', flexDirection: 'column', gap: 20 }}>
      <div style={{ display: 'grid', gridTemplateColumns: 'repeat(4,1fr)', gap: 16 }}>
        <StatM icon="conveyor_belt" label="Tons Out Today" value="487" unit="t" delta="42t" deltaDir="up" tone="cyan" />
        <StatM icon="local_shipping" label="Trucks at Mine" value="12" tone="amber" />
        <StatM icon="handshake" label="Active Buyers" value="8" tone="green" />
        <StatM icon="inventory_2" label="Stockpile" value="9,640" unit="t" tone="blue" />
      </div>
      <div style={{ display: 'grid', gridTemplateColumns: 'repeat(4,1fr)', gap: 16 }}>
        <FeatM icon="tune" title="Load Control" tone="cyan" description="Record loads and tonnage for trucks ready at the mine. Capture weighbridge tickets." onOpen={() => go('control')} />
        <FeatM icon="security" title="Gate Security" tone="amber" description="Mark truck arrivals and departures at the gate. Live arrivals & departures log." onOpen={() => go('security')} />
        <FeatM icon="handshake" title="Buyers" tone="green" description="Tonnage per buyer, generate invoices, download reconciliations across all operations." onOpen={() => go('buyers')} />
        <div style={{ position: 'relative', background: 'var(--surface-card)', border: '1px solid var(--border-card)', borderRadius: 'var(--radius-xl)', boxShadow: 'var(--shadow-sm)', padding: 22, display: 'flex', flexDirection: 'column', gap: 14, opacity: 0.72 }}>
          <span style={{ position: 'absolute', top: 16, right: 16, fontSize: 10.5, fontWeight: 800, letterSpacing: '.05em', color: 'var(--ml-orange-700)', background: 'var(--status-warn-bg)', padding: '3px 9px', borderRadius: 999 }}>COMING SOON</span>
          <div style={{ width: 54, height: 54, borderRadius: 16, background: 'var(--surface-sunken)', display: 'flex', alignItems: 'center', justifyContent: 'center' }}><IconM name="factory" size={26} color="var(--text-faint)" /></div>
          <div style={{ fontSize: 19, fontWeight: 800, color: 'var(--text-strong)', letterSpacing: '-.01em' }}>Operations Hub</div>
          <div style={{ fontSize: 14, color: 'var(--text-muted)', lineHeight: 1.5, flex: 1 }}>Live operational records — in design. Coming soon.</div>
        </div>
      </div>
      <div style={{ display: 'grid', gridTemplateColumns: '1.6fr 1fr', gap: 16 }}>
        <DSm.Card padding={22}>
          <h2 style={{ margin: '0 0 16px', fontSize: 18, fontWeight: 800, color: 'var(--text-strong)' }}>Tons out — last 7 days</h2>
          <div style={{ display: 'flex', alignItems: 'flex-end', gap: 12, height: 150 }}>
            {[420, 510, 480, 620, 390, 560, 487].map((v, i) => (
              <div key={i} style={{ flex: 1, display: 'flex', flexDirection: 'column', alignItems: 'center', gap: 8 }}>
                <div style={{ width: '100%', height: `${(v / 620) * 120}px`, background: i === 6 ? 'var(--accent)' : 'var(--ml-cyan-200)', borderRadius: '6px 6px 0 0', transition: 'height .4s' }} />
                <span style={{ fontSize: 11, color: 'var(--text-faint)', fontFamily: 'var(--font-mono)' }}>{['Mo', 'Tu', 'We', 'Th', 'Fr', 'Sa', 'Su'][i]}</span>
              </div>
            ))}
          </div>
        </DSm.Card>
        <DSm.Card tone="chrome" padding={22}>
          <IconM name="group_add" size={28} color="#fff" />
          <h3 style={{ margin: '14px 0 6px', fontSize: 18, fontWeight: 800, color: '#fff' }}>Request buyers</h3>
          <p style={{ margin: 0, fontSize: 13.5, color: 'rgba(255,255,255,.82)', lineHeight: 1.5 }}>Ask the platform to connect you with more buyers for your minerals.</p>
          <button type="button" style={{ marginTop: 18, border: 'none', background: 'rgba(255,255,255,.14)', color: '#fff', fontWeight: 700, fontSize: 14, padding: '10px 16px', borderRadius: 'var(--radius-md)', cursor: 'pointer', display: 'inline-flex', alignItems: 'center', gap: 8 }}>Request now <IconM name="arrow_forward" size={17} /></button>
        </DSm.Card>
      </div>
    </div>
  );
}

function MineControl() {
  const [rec, setRec] = React.useState(null);
  const ready = [
    { id: 'r1', plate: 'DV12UH GP', client: 'Atlas Buyer Group', transporter: 'Roadhaul Logistics', driver: 'Thabo Mokoena', tone: 'atmine', status: 'AT MINE' },
    { id: 'r2', plate: 'HGH 789 GP', client: 'Pioneer Mining', transporter: 'Trans African', driver: 'Sipho Mkhize', tone: 'atmine', status: 'AT MINE' },
  ];
  return (
    <div style={{ position: 'relative' }}>
      <div style={{ marginBottom: 18 }}><InM icon="search" placeholder="Search truck registration..." /></div>
      <div style={{ display: 'grid', gridTemplateColumns: 'repeat(4,1fr)', gap: 16, marginBottom: 20 }}>
        <StatM icon="local_shipping" label="Ready for Loading" value="12" delta="2" deltaDir="up" tone="cyan" />
        <StatM icon="description" label="Loads Recorded Today" value="48" delta="8" deltaDir="up" tone="blue" />
        <StatM icon="schedule" label="Avg Tons / Load" value="33.7" unit="t" delta="1.6t" deltaDir="up" tone="green" />
        <StatM icon="pending_actions" label="Waybills Pending" value="7" delta="1" deltaDir="down" tone="amber" />
      </div>
      <DSm.Card padding={20} style={{ marginBottom: 20 }}>
        <div style={{ display: 'flex', alignItems: 'center', gap: 10, marginBottom: 16 }}><IconM name="balance" size={22} color="var(--accent)" /><h2 style={{ margin: 0, fontSize: 17, fontWeight: 800, color: 'var(--text-strong)' }}>Trucks at Mine — Ready for Loading</h2></div>
        <div style={{ display: 'flex', flexDirection: 'column', gap: 12 }}>
          {ready.map((t) => (
            <div key={t.id} style={{ display: 'flex', alignItems: 'center', gap: 18, padding: 16, border: '1px solid var(--border-card)', borderRadius: 'var(--radius-md)', background: 'var(--surface-app)' }}>
              <WellM icon="local_shipping" tone="blue" size={48} radius={12} />
              <div style={{ width: 130 }}><PlateM>{t.plate}</PlateM></div>
              <div style={{ flex: 1, display: 'flex', gap: 26 }}>
                <div><div style={{ fontSize: 11, textTransform: 'uppercase', letterSpacing: '.06em', color: 'var(--text-faint)' }}>Client</div><div style={{ fontSize: 14, fontWeight: 600, color: 'var(--text-strong)' }}>{t.client}</div></div>
                <div><div style={{ fontSize: 11, textTransform: 'uppercase', letterSpacing: '.06em', color: 'var(--text-faint)' }}>Transporter</div><div style={{ fontSize: 14, color: 'var(--text-body)' }}>{t.transporter}</div></div>
                <div><div style={{ fontSize: 11, textTransform: 'uppercase', letterSpacing: '.06em', color: 'var(--text-faint)' }}>Driver</div><div style={{ fontSize: 14, color: 'var(--text-body)' }}>{t.driver}</div></div>
              </div>
              <BadgeM tone={t.tone}>{t.status}</BadgeM>
              <BtnM icon="inventory_2" onClick={() => setRec(t)}>Record Load</BtnM>
            </div>
          ))}
        </div>
      </DSm.Card>
      <DSm.Card padding={20}>
        <h2 style={{ margin: '0 0 16px', fontSize: 17, fontWeight: 800, color: 'var(--text-strong)' }}>Recent Loads</h2>
        <TableM
          columns={[{ key: 'plate', label: 'Truck Reg', w: '1fr' }, { key: 'driver', label: 'Driver', w: '1fr' }, { key: 'route', label: 'Route', w: '1.6fr' }, { key: 'tons', label: 'Tons', w: '0.7fr', align: 'right' }, { key: 'status', label: 'Status', w: '1fr', align: 'right' }, { key: 'time', label: 'Updated', w: '0.7fr', align: 'right' }]}
          rows={[
            { id: 1, plate: 'JKL 012 NW', driver: 'Pieter van Wyk', from: 'Thabazimbi', to: 'Vanderbijlpark', tons: '34.5 t', tone: 'atmine', status: 'AT MINE', time: '09:19' },
            { id: 2, plate: 'CDF 789 LP', driver: 'Thabo Mokoena', from: 'Mogalakwena', to: 'Crusher Plant', tons: '—', tone: 'transit', status: 'OTW', time: '09:12' },
            { id: 3, plate: 'BKG 456 GP', driver: 'Pieter Jacobs', from: 'Haulkek', to: 'Crusher Plant', tons: '31.8 t', tone: 'done', status: 'LOADED', time: '08:47' },
          ]}
          renderCell={(r, k) => {
            if (k === 'plate') return <PlateM size="sm">{r.plate}</PlateM>;
            if (k === 'driver') return <span style={{ fontSize: 14, color: 'var(--text-body)' }}>{r.driver}</span>;
            if (k === 'route') return <RouteArrowM from={r.from} to={r.to} />;
            if (k === 'status') return <BadgeM tone={r.tone}>{r.status}</BadgeM>;
            if (k === 'time') return <span style={{ fontFamily: 'var(--font-mono)', fontSize: 13.5, color: 'var(--text-muted)' }}>{r.time}</span>;
            return <span style={{ fontFamily: 'var(--font-mono)', fontSize: 14 }}>{r.tons}</span>;
          }}
        />
      </DSm.Card>
      <SlideM open={!!rec} title={rec ? `Record Load — ${rec.plate}` : ''} onClose={() => setRec(null)}>
        {rec && (<div style={{ display: 'flex', flexDirection: 'column', gap: 18 }}>
          <div style={{ fontSize: 13.5, color: 'var(--text-muted)', lineHeight: 1.6 }}>Driver: {rec.driver}<br />Client: {rec.client}</div>
          <InM label="Tons Loaded" required placeholder="e.g. 34.5" type="number" />
          {/* Seal requirement (per route setting) */}
          <div>
            <div style={{ display: 'flex', alignItems: 'center', gap: 8, marginBottom: 8 }}>
              <span style={{ fontSize: 14, fontWeight: 600, color: 'var(--text-body)' }}>Seal numbers</span>
              <BadgeM tone="warn">SEALS REQUIRED</BadgeM>
            </div>
            <div style={{ display: 'grid', gridTemplateColumns: '1fr 1fr', gap: 10 }}>
              {[1, 2, 3, 4].map((n) => <InM key={n} placeholder={`Seal ${n}`} icon="lock" />)}
            </div>
            <div style={{ fontSize: 12, color: 'var(--text-muted)', marginTop: 6 }}>This route requires a photo of each seal &amp; its number — you can't complete the load without them.</div>
          </div>
          <FileM label="Seal &amp; load pictures" capture hint="Photo of each seal + loaded truck" />
          <InM label="Wayslip / Weighbridge ticket" placeholder="e.g. WB-0045" icon="confirmation_number" />
          <BtnM variant="go" block icon="check_circle" onClick={() => setRec(null)}>Confirm Load</BtnM>
          <BtnM variant="outline" block onClick={() => setRec(null)}>Cancel</BtnM>
        </div>)}
      </SlideM>
    </div>
  );
}

/* ---- Mobile Security (phone frame) ---- */
function MineSecurity() {
  const Stat = ({ icon, val, label, tone }) => (
    <div style={{ flex: 1, background: 'var(--surface-card)', border: '1px solid var(--border-card)', borderRadius: 'var(--radius-md)', padding: 12, display: 'flex', flexDirection: 'column', gap: 6, alignItems: 'flex-start' }}>
      <WellM icon={icon} tone={tone} size={34} radius={10} />
      <div style={{ fontSize: 22, fontWeight: 800, color: 'var(--text-strong)', lineHeight: 1 }}>{val}</div>
      <div style={{ fontSize: 11.5, color: 'var(--text-muted)' }}>{label}</div>
    </div>
  );
  const Truck = ({ tone }) => (
    <WellM icon="local_shipping" tone={tone === 'amber' ? 'amber' : 'blue'} size={96} radius={14} />
  );
  const Field = ({ icon, label, val }) => (
    <div style={{ display: 'flex', alignItems: 'center', gap: 10, marginTop: 8 }}><IconM name={icon} size={16} color="var(--accent)" /><div><div style={{ fontSize: 10.5, color: 'var(--text-faint)' }}>{label}</div><div style={{ fontSize: 13.5, fontWeight: 600, color: 'var(--text-strong)' }}>{val}</div></div></div>
  );
  return (
    <div style={{ display: 'flex', justifyContent: 'center', padding: '8px 0 24px' }}>
      <div style={{ width: 390, borderRadius: 40, background: '#fff', boxShadow: 'var(--shadow-lg)', overflow: 'hidden', border: '8px solid #0b192e' }}>
        <div style={{ height: 28, background: '#fff' }} />
        <div style={{ padding: '4px 18px 20px', maxHeight: 720, overflowY: 'auto' }}>
          <div style={{ display: 'flex', alignItems: 'center', gap: 12, marginBottom: 18 }}>
            <div style={{ width: 46, height: 46, borderRadius: 13, background: 'linear-gradient(150deg,#22c2de,#0496b6)', display: 'flex', alignItems: 'center', justifyContent: 'center' }}><IconM name="local_shipping" size={24} color="#fff" fill={1} /></div>
            <div style={{ flex: 1 }}><div style={{ fontSize: 19, fontWeight: 800, color: 'var(--text-strong)' }}>Mine Security</div><div style={{ fontSize: 12.5, color: 'var(--text-muted)' }}>Gate control — arrivals &amp; departures</div></div>
            <IconM name="notifications" size={22} color="var(--text-body)" />
          </div>
          <div style={{ marginBottom: 16 }}><InM icon="search" placeholder="Search truck registration..." /></div>
          <div style={{ display: 'flex', gap: 10, marginBottom: 18 }}>
            <Stat icon="login" val="18" label="Incoming Today" tone="cyan" />
            <Stat icon="shield" val="27" label="At Mine" tone="amber" />
            <Stat icon="check_circle" val="14" label="Departed Today" tone="green" />
          </div>
          <div style={{ background: 'var(--surface-card)', border: '1px solid var(--border-card)', borderRadius: 'var(--radius-lg)', padding: 16, marginBottom: 14 }}>
            <div style={{ display: 'flex', alignItems: 'center', gap: 10, marginBottom: 12 }}><IconM name="login" size={20} color="var(--accent)" /><span style={{ fontWeight: 800, fontSize: 15, flex: 1 }}>Incoming Trucks — Mark Arrival</span></div>
            <div style={{ display: 'flex', gap: 14 }}>
              <Truck tone="blue" />
              <div style={{ flex: 1 }}><PlateM size="lg">DV12UH GP</PlateM><Field icon="apartment" label="Client" val="Pioneer Mining" /><Field icon="groups" label="Transporter" val="Trans African" /><Field icon="person" label="Driver" val="Sipho Mkhize" /></div>
            </div>
            <BtnM variant="go" block icon="login" style={{ marginTop: 14 }}>Mark Arrived</BtnM>
          </div>
          <div style={{ background: 'var(--surface-card)', border: '1px solid var(--border-card)', borderRadius: 'var(--radius-lg)', padding: 16 }}>
            <div style={{ display: 'flex', alignItems: 'center', gap: 10, marginBottom: 12 }}><IconM name="shield" size={20} color="var(--ml-orange-600)" /><span style={{ fontWeight: 800, fontSize: 15, flex: 1 }}>At Mine — Mark Departure</span></div>
            <div style={{ display: 'flex', gap: 14 }}>
              <Truck tone="amber" />
              <div style={{ flex: 1 }}><div style={{ display: 'flex', alignItems: 'center', gap: 8 }}><PlateM size="lg">JKL 012 NW</PlateM><BadgeM tone="atmine">AT MINE</BadgeM></div><Field icon="apartment" label="Client" val="Pioneer Mining" /><Field icon="person" label="Driver" val="Thabo Dlamini" /></div>
            </div>
            <BtnM variant="leave" block icon="logout" style={{ marginTop: 14 }}>Mark Left</BtnM>
          </div>
        </div>
        <div style={{ display: 'flex', borderTop: '1px solid var(--divider)', background: 'var(--surface-card)' }}>
          {[['shield', 'Security', true], ['list_alt', 'Activity', false], ['local_shipping', 'Trucks', false], ['more_horiz', 'More', false]].map(([ic, l, a], i) => (
            <div key={i} style={{ flex: 1, padding: '10px 0', display: 'flex', flexDirection: 'column', alignItems: 'center', gap: 3, color: a ? 'var(--accent)' : 'var(--text-faint)' }}><IconM name={ic} size={20} fill={a ? 1 : 0} /><span style={{ fontSize: 10.5, fontWeight: a ? 700 : 500 }}>{l}</span></div>
          ))}
        </div>
      </div>
    </div>
  );
}

function MineBuyers() {
  const buyers = [
    { name: 'Atlas Buyer Group', tons: 620, tone: 'cyan' },
    { name: 'Pioneer Mining (Pty) Ltd', tons: 310, tone: 'green' },
    { name: 'Bathopele Mining', tons: 290, tone: 'amber' },
  ];
  return (
    <div>
      <STitleM icon="handshake" action={<BtnM icon="group_add" size="sm">Request buyers</BtnM>}>Buyers</STitleM>
      <div style={{ display: 'grid', gridTemplateColumns: 'repeat(3,1fr)', gap: 16 }}>
        {buyers.map((b, i) => (
          <DSm.Card key={i} tone="hero">
            <div style={{ display: 'flex', alignItems: 'center', gap: 12 }}><div style={{ width: 40, height: 40, borderRadius: 12, background: 'var(--surface-card)', display: 'flex', alignItems: 'center', justifyContent: 'center', border: '1px solid var(--border-accent)' }}><IconM name="handshake" size={20} color="var(--accent)" /></div><div style={{ fontSize: 16, fontWeight: 800, color: 'var(--text-strong)' }}>{b.name}</div></div>
            <div style={{ marginTop: 16, fontSize: 12.5, color: 'var(--text-muted)' }}>Tons out</div>
            <div style={{ fontSize: 30, fontWeight: 800, color: 'var(--text-strong)' }}>{b.tons.toLocaleString()} <span style={{ fontSize: 18 }}>t</span></div>
            <div style={{ display: 'flex', flexDirection: 'column', gap: 8, marginTop: 16 }}>
              <BtnM variant="tonal" block icon="download" style={{ justifyContent: 'flex-start' }}>Download / view recons</BtnM>
              <BtnM variant="tonal" block icon="receipt_long" style={{ justifyContent: 'flex-start' }}>Generate invoice</BtnM>
            </div>
          </DSm.Card>
        ))}
      </div>
    </div>
  );
}

/* ===== Employee Register (slides 10-12) — admin workspace: add/remove
 * supervisors/foremen, load controllers, security guards. Replaces the separate
 * security/controller/management tabs. ===== */
const ROLE_GROUPS = [
  { key: 'supervisor', label: 'Supervisors & Foremen', icon: 'engineering', tone: 'cyan', perm: 'Everything besides generating invoices & managing employees' },
  { key: 'controller', label: 'Load Controllers', icon: 'tune', tone: 'blue', perm: 'Load trucks only — record tons, seals & wayslips' },
  { key: 'security', label: 'Security Guards', icon: 'security', tone: 'amber', perm: 'Gate checks only — mark trucks arrived & left' },
];
const EMP_SEED = {
  supervisor: [{ id: 's1', name: 'Vusi Khumalo' }, { id: 's2', name: 'Musi Ndlovu' }, { id: 's3', name: 'Lusi Dlamini' }, { id: 's4', name: 'Pusi Nkosi' }],
  controller: [{ id: 'c1', name: 'Ben Botha' }, { id: 'c2', name: 'John Meyer' }, { id: 'c3', name: 'Bob Naidoo' }, { id: 'c4', name: 'Ken Adams' }],
  security: [{ id: 'g1', name: 'Happy Sithole' }, { id: 'g2', name: 'Linky Mabaso' }, { id: 'g3', name: 'Dinky Zulu' }, { id: 'g4', name: 'Minky Cele' }],
};
const TONE_FGM = { cyan: 'var(--accent)', blue: 'var(--ml-blue-600)', amber: 'var(--ml-orange-600)' };
const TONE_BGM = { cyan: 'var(--ml-well-cyan)', blue: 'var(--ml-well-blue)', amber: 'var(--ml-well-amber)' };

function MineEmployeeRegister() {
  return <window.MLEmployeeRegister.Register otype="Mine" companyName="Iron Hills Mining" canManage={true} embedded={true} />;
}

function MineEmployeeRegisterLegacy() {
  const [emp, setEmp] = React.useState(EMP_SEED);
  const [add, setAdd] = React.useState(null); // group key
  const remove = (g, id) => setEmp((e) => ({ ...e, [g]: e[g].filter((u) => u.id !== id) }));
  const total = Object.values(emp).reduce((a, l) => a + l.length, 0);
  return (
    <div style={{ position: 'relative' }}>
      <STitleM icon="badge" action={<BadgeM tone="done" dot>{total} employees</BadgeM>}>Employee Register</STitleM>
      <p style={{ margin: '-6px 0 18px', fontSize: 13.5, color: 'var(--text-muted)' }}>Admin workspace — add or remove supervisors, load controllers and gate security. Each role sees only the screens their permissions allow.</p>
      <div style={{ display: 'flex', flexDirection: 'column', gap: 16 }}>
        {ROLE_GROUPS.map((g) => (
          <DSm.Card key={g.key} padding={20}>
            <div style={{ display: 'flex', alignItems: 'center', gap: 12, marginBottom: 14 }}>
              <div style={{ width: 44, height: 44, borderRadius: 12, background: TONE_BGM[g.tone], display: 'flex', alignItems: 'center', justifyContent: 'center' }}><IconM name={g.icon} size={22} color={TONE_FGM[g.tone]} /></div>
              <div style={{ flex: 1 }}>
                <div style={{ fontSize: 16, fontWeight: 800, color: 'var(--text-strong)' }}>{g.label}</div>
                <div style={{ fontSize: 12.5, color: 'var(--text-muted)' }}>{g.perm}</div>
              </div>
              <BtnM size="sm" icon="person_add" onClick={() => setAdd(g.key)}>Add new</BtnM>
            </div>
            <div style={{ display: 'grid', gridTemplateColumns: 'repeat(2,1fr)', gap: 8 }}>
              {emp[g.key].map((u) => (
                <div key={u.id} style={{ display: 'flex', alignItems: 'center', gap: 11, padding: '9px 12px', border: '1px solid var(--border-card)', borderRadius: 'var(--radius-md)', background: 'var(--surface-app)' }}>
                  <AvM name={u.name} size={34} tone="slate" />
                  <span style={{ flex: 1, fontSize: 14, fontWeight: 600, color: 'var(--text-strong)' }}>{u.name}</span>
                  <button type="button" onClick={() => remove(g.key, u.id)} title="Remove" style={{ border: 'none', background: 'transparent', cursor: 'pointer', color: 'var(--text-faint)', display: 'flex' }}><IconM name="person_remove" size={18} /></button>
                </div>
              ))}
              {emp[g.key].length === 0 && <div style={{ gridColumn: '1/-1', padding: 14, textAlign: 'center', fontSize: 13, color: 'var(--text-faint)' }}>No {g.label.toLowerCase()} yet.</div>}
            </div>
          </DSm.Card>
        ))}
      </div>
      <SlideM open={!!add} title={add ? `Add ${ROLE_GROUPS.find((g) => g.key === add).label.replace(/s$/, '')}` : ''} onClose={() => setAdd(null)}>
        {add && (<div style={{ display: 'flex', flexDirection: 'column', gap: 16 }}>
          <div style={{ fontSize: 13, color: 'var(--text-muted)' }}>Employees sign in with their cell / WhatsApp number — no email needed. You can reset their password here later.</div>
          <InM label="Full name" required icon="person" placeholder="e.g. Sipho Mahlangu" />
          <InM label="Cell / WhatsApp number" required icon="chat" placeholder="+27 82 000 0000" />
          <BtnM variant="go" block icon="check_circle" onClick={() => setAdd(null)}>Register employee</BtnM>
          <BtnM variant="outline" block onClick={() => setAdd(null)}>Cancel</BtnM>
        </div>)}
      </SlideM>
    </div>
  );
}

window.MineScreens = { MineOverview, MineControl, MineSecurity, MineBuyers, MineEmployeeRegister };
