/* MineLink — Driver mobile app kit. Faithful premium recreation of the
 * "Driver App — Manage your trip" mockup, in a phone frame. */
const DSd = window.MineLinkDesignSystem_9acfde;
const { Icon: IconD, StatusBadge: BadgeD, PlatePill: PlateD } = DSd;
const { IconWell: WellD } = window.MLShell;

function PhoneFrame({ children, label }) {
  return (
    <div style={{ display: 'flex', flexDirection: 'column', alignItems: 'center', gap: 14 }}>
      {label && <div style={{ fontSize: 12, fontWeight: 700, letterSpacing: '.1em', textTransform: 'uppercase', color: 'var(--text-faint)' }}>{label}</div>}
      <div style={{ width: 384, borderRadius: 44, background: '#0b192e', padding: 10, boxShadow: 'var(--shadow-lg)' }}>
        <div style={{ borderRadius: 36, background: 'var(--surface-app)', overflow: 'hidden', position: 'relative' }}>
          <div style={{ height: 30, display: 'flex', alignItems: 'center', justifyContent: 'center' }}>
            <div style={{ width: 110, height: 22, background: '#0b192e', borderRadius: 999 }} />
          </div>
          {children}
        </div>
      </div>
    </div>
  );
}

function TripAction({ icon, label, variant, onClick }) {
  const styles = {
    primary: { bg: 'linear-gradient(180deg,#0aa6c7,#0496b6)', fg: '#fff', bd: 'transparent', sh: '0 4px 12px rgba(0,181,216,.32)' },
    pod: { bg: 'linear-gradient(180deg,#0a7791,#0b5f74)', fg: '#fff', bd: 'transparent', sh: '0 4px 12px rgba(10,119,145,.3)' },
    outline: { bg: 'var(--surface-card)', fg: 'var(--accent)', bd: 'var(--border-accent)', sh: 'none' },
  };
  const s = styles[variant] || styles.outline;
  return (
    <button type="button" onClick={onClick} style={{ display: 'flex', alignItems: 'center', gap: 12, width: '100%', padding: '15px 18px', borderRadius: 'var(--radius-md)', border: `1.5px solid ${s.bd}`, background: s.bg, color: s.fg, boxShadow: s.sh, fontFamily: 'var(--font-sans)', fontSize: 15.5, fontWeight: 700, cursor: 'pointer' }}>
      {variant === 'outline'
        ? <span style={{ width: 26, height: 26, borderRadius: 999, background: 'var(--accent)', display: 'flex', alignItems: 'center', justifyContent: 'center', flexShrink: 0 }}><IconD name={icon} size={16} color="#fff" fill={1} /></span>
        : <IconD name={icon} size={21} color={s.fg} />}
      {label}
    </button>
  );
}

function DriverApp() {
  const [done, setDone] = React.useState({ loading: false, offloading: false });
  const recent = [
    { plate: 'BKG 456 GP', from: 'Mogalakwena Mine', to: 'Saldanha Steel Works', date: '12 May 2025', time: '08:45' },
    { plate: 'MNP 345 MP', from: 'Thabazimbi Mine', to: 'Richards Bay Terminal', date: '10 May 2025', time: '13:20' },
  ];
  return (
    <PhoneFrame label="Driver App — Transporter">
      <div style={{ maxHeight: 740, overflowY: 'auto', padding: '6px 18px 0' }}>
        {/* Header */}
        <div style={{ display: 'flex', alignItems: 'center', gap: 13, padding: '8px 0 18px' }}>
          <WellD icon="local_shipping" tone="cyan" size={50} radius={14} />
          <div style={{ flex: 1 }}>
            <div style={{ fontSize: 22, fontWeight: 800, color: 'var(--text-strong)', letterSpacing: '-.01em' }}>Driver App</div>
            <div style={{ fontSize: 13.5, color: 'var(--text-muted)' }}>Manage your trip</div>
          </div>
          <div style={{ position: 'relative' }}><IconD name="notifications" size={25} color="var(--text-body)" /><span style={{ position: 'absolute', top: -1, right: -1, width: 9, height: 9, borderRadius: 999, background: 'var(--accent)', border: '2px solid var(--surface-app)' }} /></div>
        </div>

        {/* Current trip card */}
        <div style={{ background: 'var(--surface-card)', border: '1px solid var(--border-card)', borderRadius: 'var(--radius-xl)', boxShadow: 'var(--shadow-sm)', padding: 20, marginBottom: 18 }}>
          <div style={{ display: 'flex', alignItems: 'center', marginBottom: 18 }}>
            <h3 style={{ margin: 0, fontSize: 19, fontWeight: 800, color: 'var(--text-strong)', flex: 1 }}>Current Trip</h3>
            <BadgeD tone="transit" dot>OTW TO LOADING</BadgeD>
          </div>
          <div style={{ display: 'flex', alignItems: 'center', gap: 16, marginBottom: 18 }}>
            <WellD icon="local_shipping" tone="cyan" size={66} radius={16} />
            <div><PlateD size="lg">CDF 789 LP</PlateD><div style={{ fontSize: 15, color: 'var(--text-muted)', marginTop: 2 }}>Chrome Ore</div></div>
          </div>

          {/* Route timeline */}
          <div style={{ background: 'var(--surface-sunken)', borderRadius: 'var(--radius-md)', padding: '18px 20px', marginBottom: 18 }}>
            <div style={{ display: 'flex', gap: 16 }}>
              <div style={{ display: 'flex', flexDirection: 'column', alignItems: 'center', paddingTop: 6 }}>
                <span style={{ width: 13, height: 13, borderRadius: 999, background: 'var(--accent)' }} />
                <span style={{ width: 2, flex: 1, minHeight: 34, background: 'var(--border-strong)', margin: '4px 0' }} />
                <span style={{ width: 13, height: 13, borderRadius: 999, background: 'var(--ml-green-600)' }} />
              </div>
              <div style={{ flex: 1, display: 'flex', flexDirection: 'column', gap: 16 }}>
                <div><div style={{ fontSize: 13, color: 'var(--text-muted)' }}>From</div><div style={{ fontSize: 17, fontWeight: 800, color: 'var(--text-strong)' }}>Mogalakwena Mine</div></div>
                <div><div style={{ fontSize: 13, color: 'var(--text-muted)' }}>To</div><div style={{ fontSize: 17, fontWeight: 800, color: 'var(--text-strong)' }}>Saldanha Steel Works</div></div>
              </div>
            </div>
          </div>

          {/* Actions */}
          <div style={{ display: 'flex', flexDirection: 'column', gap: 10 }}>
            <TripAction icon="near_me" label="Directions" variant="primary" />
            <TripAction icon={done.loading ? 'check' : 'check'} label={done.loading ? 'Arrived at loading ✓' : 'Arrived at loading'} variant="outline" onClick={() => setDone((d) => ({ ...d, loading: true }))} />
            <TripAction icon="check" label={done.offloading ? 'Arrived at offloading ✓' : 'Arrived at offloading'} variant="outline" onClick={() => setDone((d) => ({ ...d, offloading: true }))} />
            <TripAction icon="cloud_upload" label="Upload POD" variant="pod" />
          </div>
        </div>

        {/* Recent trips */}
        <div style={{ background: 'var(--surface-card)', border: '1px solid var(--border-card)', borderRadius: 'var(--radius-xl)', boxShadow: 'var(--shadow-sm)', padding: 20, marginBottom: 16 }}>
          <div style={{ display: 'flex', alignItems: 'center', marginBottom: 16 }}>
            <h3 style={{ margin: 0, fontSize: 18, fontWeight: 800, color: 'var(--text-strong)', flex: 1 }}>Recent Trips</h3>
            <button type="button" style={{ display: 'inline-flex', alignItems: 'center', gap: 4, border: 'none', background: 'transparent', color: 'var(--accent)', fontWeight: 700, fontSize: 13.5, cursor: 'pointer' }}>View all <IconD name="chevron_right" size={16} /></button>
          </div>
          <div style={{ display: 'flex', flexDirection: 'column', gap: 4 }}>
            {recent.map((t, i) => (
              <div key={i} style={{ display: 'flex', alignItems: 'center', gap: 13, padding: '12px 0', borderTop: i > 0 ? '1px solid var(--divider)' : 'none' }}>
                <div style={{ width: 44, height: 44, borderRadius: 12, background: 'var(--ml-well-green)', display: 'flex', alignItems: 'center', justifyContent: 'center', flexShrink: 0 }}><IconD name="check_circle" size={22} color="var(--ml-green-600)" /></div>
                <div style={{ flex: 1, minWidth: 0 }}>
                  <PlateD size="sm">{t.plate}</PlateD>
                  <div style={{ display: 'flex', alignItems: 'center', gap: 5, fontSize: 12.5, color: 'var(--text-muted)', marginTop: 3 }}>{t.from} <IconD name="arrow_forward" size={12} color="var(--text-faint)" /> {t.to}</div>
                  <div style={{ fontSize: 12, color: 'var(--text-faint)', fontFamily: 'var(--font-mono)', marginTop: 2 }}>{t.date} · {t.time}</div>
                </div>
                <BadgeD tone="done">Completed</BadgeD>
              </div>
            ))}
          </div>
        </div>
      </div>

      {/* Bottom nav */}
      <div style={{ display: 'flex', borderTop: '1px solid var(--divider)', background: 'var(--surface-card)', padding: '4px 0 12px' }}>
        {[['grid_view', 'Dashboard', false], ['local_shipping', 'Trip', true], ['person', 'Profile', false]].map(([ic, l, a], i) => (
          <div key={i} style={{ flex: 1, display: 'flex', flexDirection: 'column', alignItems: 'center', gap: 4, padding: '10px 0' }}>
            <span style={{ width: 54, height: 32, borderRadius: 999, background: a ? 'var(--ml-well-cyan)' : 'transparent', display: 'flex', alignItems: 'center', justifyContent: 'center' }}><IconD name={ic} size={22} color={a ? 'var(--accent)' : 'var(--text-faint)'} fill={a ? 1 : 0} /></span>
            <span style={{ fontSize: 11.5, fontWeight: a ? 700 : 500, color: a ? 'var(--accent)' : 'var(--text-faint)' }}>{l}</span>
          </div>
        ))}
      </div>
    </PhoneFrame>
  );
}

window.DriverScreens = { DriverApp, PhoneFrame };
