/* MineLink — shared status & account state screens (MISSING set).
 * waiting_for_role, request_declined, expired_access, mandatory_password_change,
 * reset_password, company_selection, org-user profile + account security.
 * Exposes window.StateScreens. */
const DSt2 = window.MineLinkDesignSystem_9acfde;
const { Icon: IcS, Button: BtnS, Input: InpS, Avatar: AvS, StatusBadge: BdgS } = DSt2;

/* Generic centered status shell */
function StatusScreen({ icon, tone = 'cyan', eyebrow, title, message, children }) {
  const fg = { cyan: 'var(--accent)', amber: 'var(--ml-orange-600)', red: 'var(--ml-red-600)', green: 'var(--ml-green-600)' }[tone];
  const bg = { cyan: 'var(--ml-well-cyan)', amber: 'var(--ml-well-amber)', red: 'var(--status-error-bg)', green: 'var(--ml-well-green)' }[tone];
  return (
    <div style={{ minHeight: '100%', display: 'flex', alignItems: 'center', justifyContent: 'center', padding: 32, fontFamily: 'var(--font-sans)', background: 'var(--surface-app)' }}>
      <div style={{ width: '100%', maxWidth: 460, background: 'var(--surface-card)', border: '1px solid var(--border-card)', borderRadius: 'var(--radius-xl)', boxShadow: 'var(--shadow-md)', overflow: 'hidden' }}>
        <div style={{ height: 6, background: fg }} />
        <div style={{ padding: 32, textAlign: 'center' }}>
          <div style={{ width: 72, height: 72, borderRadius: 20, background: bg, display: 'flex', alignItems: 'center', justifyContent: 'center', margin: '0 auto 18px' }}><IcS name={icon} size={36} color={fg} /></div>
          {eyebrow && <div style={{ fontSize: 11.5, fontWeight: 800, letterSpacing: '.12em', color: fg, marginBottom: 6 }}>{eyebrow.toUpperCase()}</div>}
          <h1 style={{ margin: 0, fontSize: 23, fontWeight: 800, color: 'var(--text-strong)', letterSpacing: '-.01em' }}>{title}</h1>
          <p style={{ margin: '10px 0 0', fontSize: 14.5, color: 'var(--text-muted)', lineHeight: 1.55 }}>{message}</p>
          {children && <div style={{ marginTop: 22 }}>{children}</div>}
        </div>
      </div>
    </div>
  );
}

function WaitingForRole() {
  return <StatusScreen icon="hourglass_top" tone="amber" eyebrow="Pending" title="Waiting for a role"
    message="Your request to join Iron Hills Mining was received. A company admin will assign your role — you'll get a notification the moment access is granted.">
    <div style={{ display: 'flex', flexDirection: 'column', gap: 10 }}>
      <div style={{ display: 'flex', alignItems: 'center', gap: 10, padding: '12px 14px', background: 'var(--surface-app)', borderRadius: 'var(--radius-md)', textAlign: 'left' }}>
        <AvS name="Iron Hills Mining" size={38} tone="cyan" /><div><div style={{ fontSize: 14, fontWeight: 700, color: 'var(--text-strong)' }}>Iron Hills Mining</div><div style={{ fontSize: 12.5, color: 'var(--text-muted)' }}>Mine / Supplier · request sent today</div></div>
      </div>
      <BtnS variant="outline" block icon="refresh">Check status</BtnS>
      <BtnS variant="ghost" block icon="logout">Sign out</BtnS>
    </div>
  </StatusScreen>;
}

function RequestDeclined() {
  return <StatusScreen icon="cancel" tone="red" eyebrow="Declined" title="Join request declined"
    message="Your request to join Iron Hills Mining wasn't approved. If you think this is a mistake, contact the company admin or Mine-Link support.">
    <div style={{ display: 'flex', flexDirection: 'column', gap: 10 }}>
      <BtnS block icon="business">Request a different company</BtnS>
      <BtnS variant="outline" block icon="chat">Message Mine-Link</BtnS>
      <BtnS variant="ghost" block icon="logout">Sign out</BtnS>
    </div>
  </StatusScreen>;
}

function ExpiredAccess() {
  return <StatusScreen icon="lock_clock" tone="red" eyebrow="Access expired" title="Your company's token has expired"
    message="Iron Hills Mining's platform token expired on 30 Jun 2026. Access is paused until it's renewed. Ask your owner to request a renewal, or contact Mine-Link.">
    <div style={{ display: 'flex', flexDirection: 'column', gap: 10 }}>
      <BtnS block icon="vpn_key">Request token renewal</BtnS>
      <BtnS variant="outline" block icon="chat">Contact Mine-Link</BtnS>
      <BtnS variant="ghost" block icon="logout">Sign out</BtnS>
    </div>
  </StatusScreen>;
}

function MandatoryPasswordChange() {
  return <StatusScreen icon="password" tone="cyan" eyebrow="Security" title="Set a new password"
    message="For your security, please choose a new password before continuing. This is required on your first sign-in.">
    <div style={{ display: 'flex', flexDirection: 'column', gap: 14, textAlign: 'left' }}>
      <InpS label="New password" type="password" icon="lock" placeholder="At least 10 characters" />
      <InpS label="Confirm new password" type="password" icon="lock_reset" placeholder="Re-enter new password" />
      <BtnS block icon="check_circle">Set password &amp; continue</BtnS>
    </div>
  </StatusScreen>;
}

function ResetPassword() {
  return <StatusScreen icon="lock_reset" tone="cyan" eyebrow="Reset" title="Choose a new password"
    message="Enter a new password for your account. You'll use it next time you sign in with your email.">
    <div style={{ display: 'flex', flexDirection: 'column', gap: 14, textAlign: 'left' }}>
      <InpS label="New password" type="password" icon="lock" placeholder="At least 10 characters" />
      <InpS label="Confirm new password" type="password" icon="lock_reset" placeholder="Re-enter new password" />
      <BtnS block icon="check_circle">Reset password</BtnS>
    </div>
  </StatusScreen>;
}

function CompanySelection() {
  const orgs = [
    { name: 'Iron Hills Mining', type: 'Mine / Supplier', role: 'Owner', icon: 'conveyor_belt', tone: 'cyan' },
    { name: 'Atlas Buyer Group', type: 'Buyer', role: 'Admin', icon: 'handshake', tone: 'amber' },
  ];
  const FG = { cyan: 'var(--accent)', amber: 'var(--ml-orange-600)' }, BG = { cyan: 'var(--ml-well-cyan)', amber: 'var(--ml-well-amber)' };
  return (
    <div style={{ minHeight: '100%', display: 'flex', alignItems: 'center', justifyContent: 'center', padding: 32, background: 'var(--surface-app)', fontFamily: 'var(--font-sans)' }}>
      <div style={{ width: '100%', maxWidth: 460 }}>
        <h1 style={{ margin: 0, fontSize: 24, fontWeight: 800, color: 'var(--text-strong)', textAlign: 'center' }}>Choose a workspace</h1>
        <p style={{ margin: '8px 0 22px', fontSize: 14.5, color: 'var(--text-muted)', textAlign: 'center' }}>You belong to more than one company. Pick the one you want to open.</p>
        <div style={{ display: 'flex', flexDirection: 'column', gap: 12 }}>
          {orgs.map((o, i) => (
            <button key={i} type="button" style={{ display: 'flex', alignItems: 'center', gap: 14, padding: 16, borderRadius: 'var(--radius-lg)', border: '1px solid var(--border-card)', background: 'var(--surface-card)', boxShadow: 'var(--shadow-xs)', cursor: 'pointer', textAlign: 'left' }}>
              <div style={{ width: 48, height: 48, borderRadius: 14, background: BG[o.tone], display: 'flex', alignItems: 'center', justifyContent: 'center' }}><IcS name={o.icon} size={24} color={FG[o.tone]} /></div>
              <div style={{ flex: 1 }}><div style={{ fontSize: 16, fontWeight: 800, color: 'var(--text-strong)' }}>{o.name}</div><div style={{ fontSize: 12.5, color: 'var(--text-muted)' }}>{o.type} · you are {o.role}</div></div>
              <IcS name="arrow_forward" size={20} color="var(--accent)" />
            </button>
          ))}
        </div>
      </div>
    </div>
  );
}

/* Org-user profile + account security (shared) */
function OrgProfile() {
  const [tab, setTab] = React.useState('profile');
  return (
    <div style={{ maxWidth: 560 }}>
      <div style={{ display: 'flex', gap: 4, borderBottom: '1px solid var(--divider)', marginBottom: 20 }}>
        {[['profile', 'Profile'], ['security', 'Account security']].map(([k, l]) => { const s = tab === k; return <button key={k} type="button" onClick={() => setTab(k)} style={{ padding: '12px 16px', border: 'none', background: 'transparent', cursor: 'pointer', fontFamily: 'var(--font-sans)', fontSize: 14, fontWeight: s ? 700 : 500, color: s ? 'var(--accent)' : 'var(--text-muted)', borderBottom: `2.5px solid ${s ? 'var(--accent)' : 'transparent'}`, marginBottom: -1 }}>{l}</button>; })}
      </div>
      {tab === 'profile' ? (
        <DSt2.Card padding={24}>
          <div style={{ display: 'flex', alignItems: 'center', gap: 16, marginBottom: 20 }}>
            <AvS name="Eli Naidoo" size={64} tone="cyan" />
            <div><div style={{ fontSize: 18, fontWeight: 800, color: 'var(--text-strong)' }}>Eli Naidoo</div><div style={{ fontSize: 13, color: 'var(--text-muted)' }}>Owner · Atlas Buyer Group</div><BdgS tone="done" style={{ marginTop: 6 }}>ACTIVE SEAT</BdgS></div>
          </div>
          <div style={{ display: 'flex', flexDirection: 'column', gap: 16 }}>
            <InpS label="Display name" defaultValue="Eli Naidoo" icon="person" />
            <InpS label="Email" defaultValue="eli@atlasbuyer.com" icon="mail" />
            <InpS label="Cell / WhatsApp" defaultValue="+27 82 555 0134" icon="chat" />
            <BtnS icon="check_circle">Save profile</BtnS>
          </div>
        </DSt2.Card>
      ) : (
        <DSt2.Card padding={24}>
          <div style={{ fontSize: 15, fontWeight: 800, color: 'var(--text-strong)', marginBottom: 4 }}>Change password</div>
          <div style={{ fontSize: 13, color: 'var(--text-muted)', marginBottom: 18 }}>Used for your email sign-in. Drivers &amp; gate staff sign in with their WhatsApp number instead.</div>
          <div style={{ display: 'flex', flexDirection: 'column', gap: 16 }}>
            <InpS label="Current password" type="password" icon="lock" placeholder="••••••••" />
            <InpS label="New password" type="password" icon="lock_reset" placeholder="At least 10 characters" />
            <InpS label="Confirm new password" type="password" icon="lock_reset" placeholder="Re-enter" />
            <BtnS icon="check_circle">Update password</BtnS>
          </div>
        </DSt2.Card>
      )}
    </div>
  );
}

window.StateScreens = { StatusScreen, WaitingForRole, RequestDeclined, ExpiredAccess, MandatoryPasswordChange, ResetPassword, CompanySelection, OrgProfile };
