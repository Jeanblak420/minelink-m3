/* MineLink — Auth / Login kit screens. */
const DSau = window.MineLinkDesignSystem_9acfde;
const { Icon: IconAu, Button: BtnAu, Input: InAu } = DSau;

const ORG_TYPES = [
  { key: 'mine', label: 'Mine / Supplier', icon: 'conveyor_belt', tone: 'cyan' },
  { key: 'buyer', label: 'Buyer', icon: 'handshake', tone: 'amber' },
  { key: 'transporter', label: 'Transporter', icon: 'local_shipping', tone: 'green' },
];
const TONE_FG = { cyan: 'var(--accent)', amber: 'var(--ml-orange-600)', green: 'var(--ml-green-600)' };

function BrandMark({ size = 52 }) {
  return (
    <div style={{ width: size, height: size, borderRadius: size * 0.27, background: 'linear-gradient(150deg,#22c2de,#0496b6)', display: 'flex', alignItems: 'center', justifyContent: 'center', boxShadow: '0 8px 22px rgba(0,181,216,.4)', flexShrink: 0 }}>
      <IconAu name="local_shipping" size={size * 0.5} color="#fff" fill={1} />
    </div>
  );
}

/* Left brand rail shared across auth screens */
function AuthRail() {
  return (
    <div style={{ width: 460, flexShrink: 0, position: 'relative', overflow: 'hidden', background: 'linear-gradient(165deg,#0b2545 0%,#0b192e 55%,#020617 100%)', display: 'flex', flexDirection: 'column', padding: 44, color: '#fff' }}>
      <div style={{ position: 'absolute', inset: 0, opacity: 0.5, backgroundImage: 'linear-gradient(rgba(148,163,184,.06) 1px,transparent 1px),linear-gradient(90deg,rgba(148,163,184,.06) 1px,transparent 1px)', backgroundSize: '40px 40px' }} />
      <div style={{ position: 'absolute', width: 320, height: 320, borderRadius: 999, background: 'radial-gradient(circle,rgba(0,181,216,.22),transparent 70%)', top: -80, right: -80 }} />
      <div style={{ position: 'relative', display: 'flex', alignItems: 'center', gap: 14 }}>
        <BrandMark />
        <span style={{ fontSize: 26, fontWeight: 800, letterSpacing: '-.01em' }}>MineLink</span>
      </div>
      <div style={{ position: 'relative', marginTop: 'auto' }}>
        <div style={{ fontSize: 13, fontWeight: 700, letterSpacing: '.16em', color: 'var(--accent)' }}>MINERAL LOGISTICS, CONNECTED</div>
        <h2 style={{ margin: '14px 0 0', fontSize: 30, fontWeight: 800, lineHeight: 1.2, letterSpacing: '-.01em' }}>From the mine gate to the offload point — every ton tracked.</h2>
        <p style={{ margin: '16px 0 0', fontSize: 15, color: 'rgba(226,232,240,.78)', lineHeight: 1.6, maxWidth: 330 }}>Loading, security, haulage and reconciliation for mines, buyers and transporters — on one premium platform.</p>
        <div style={{ display: 'flex', gap: 26, marginTop: 32 }}>
          {[['apartment', '24+', 'Companies'], ['local_shipping', '480', 'Trucks live'], ['inventory_2', '1.2M t', 'Hauled']].map(([ic, v, l], i) => (
            <div key={i}>
              <IconAu name={ic} size={20} color="var(--accent)" />
              <div style={{ fontSize: 22, fontWeight: 800, marginTop: 6 }}>{v}</div>
              <div style={{ fontSize: 12, color: 'rgba(148,163,184,.85)' }}>{l}</div>
            </div>
          ))}
        </div>
      </div>
    </div>
  );
}

function AuthShell({ children }) {
  return (
    <div style={{ display: 'flex', height: '100%', minHeight: 0, background: 'var(--surface-app)', fontFamily: 'var(--font-sans)' }}>
      <AuthRail />
      <div style={{ flex: 1, minWidth: 0, display: 'flex', alignItems: 'center', justifyContent: 'center', padding: 32, overflowY: 'auto' }}>
        <div style={{ width: '100%', maxWidth: 420 }}>{children}</div>
      </div>
    </div>
  );
}

function LoginScreen({ go }) {
  const [show, setShow] = React.useState(false);
  return (
    <AuthShell>
      <div style={{ marginBottom: 28 }}>
        <h1 style={{ margin: 0, fontSize: 28, fontWeight: 800, color: 'var(--text-strong)', letterSpacing: '-.01em' }}>Welcome back</h1>
        <p style={{ margin: '8px 0 0', fontSize: 15, color: 'var(--text-muted)' }}>Sign in to your MineLink workspace.</p>
      </div>
      <div style={{ display: 'flex', flexDirection: 'column', gap: 18 }}>
        <InAu label="Email or WhatsApp number" icon="account_circle" placeholder="you@company.com  ·  +27 82 000 0000" />
        <div>
          <div style={{ position: 'relative' }}>
            <InAu label="Password" icon="lock" placeholder="••••••••" type={show ? 'text' : 'password'} />
            <button type="button" onClick={() => setShow((s) => !s)} style={{ position: 'absolute', right: 12, top: 38, border: 'none', background: 'transparent', cursor: 'pointer', color: 'var(--text-faint)', display: 'flex' }}><IconAu name={show ? 'visibility_off' : 'visibility'} size={20} /></button>
          </div>
          <div style={{ textAlign: 'right', marginTop: 8 }}><a href="#" onClick={(e) => { e.preventDefault(); go && go('forgot'); }} style={{ fontSize: 13, color: 'var(--accent)', fontWeight: 600, textDecoration: 'none' }}>Forgot password?</a></div>
        </div>
        <BtnAu block size="lg" iconRight="arrow_forward" onClick={() => go && go('app')}>Sign in</BtnAu>
        <div style={{ display: 'flex', alignItems: 'center', gap: 12, color: 'var(--text-faint)', fontSize: 12.5 }}>
          <span style={{ flex: 1, height: 1, background: 'var(--border-subtle)' }} /> OR <span style={{ flex: 1, height: 1, background: 'var(--border-subtle)' }} />
        </div>
        <button type="button" onClick={() => go && go('otp')} style={{ display: 'flex', alignItems: 'center', justifyContent: 'center', gap: 10, padding: '13px', borderRadius: 'var(--radius-md)', border: '1.5px solid var(--border-strong)', background: 'var(--surface-card)', color: 'var(--text-body)', fontFamily: 'var(--font-sans)', fontSize: 14.5, fontWeight: 700, cursor: 'pointer' }}>
          <IconAu name="chat" size={20} color="var(--ml-green-600)" />Sign in with WhatsApp code
        </button>
      </div>
      <p style={{ marginTop: 28, fontSize: 14, color: 'var(--text-muted)', textAlign: 'center' }}>New company? <a href="#" onClick={(e) => { e.preventDefault(); go && go('register'); }} style={{ color: 'var(--accent)', fontWeight: 700, textDecoration: 'none' }}>Register your organization</a></p>
    </AuthShell>
  );
}

function OtpScreen({ go }) {
  const [val, setVal] = React.useState(['', '', '', '', '', '']);
  const refs = Array.from({ length: 6 }, () => React.useRef());
  const onChg = (i, v) => {
    const c = v.replace(/\D/g, '').slice(-1);
    const next = [...val]; next[i] = c; setVal(next);
    if (c && i < 5) refs[i + 1].current && refs[i + 1].current.focus();
  };
  return (
    <AuthShell>
      <button type="button" onClick={() => go && go('login')} style={{ display: 'inline-flex', alignItems: 'center', gap: 6, marginBottom: 20, border: 'none', background: 'transparent', color: 'var(--text-muted)', fontSize: 13.5, fontWeight: 600, cursor: 'pointer' }}><IconAu name="chevron_left" size={18} />Back to sign in</button>
      <div style={{ width: 48, height: 48, borderRadius: 14, background: 'var(--ml-well-green)', display: 'flex', alignItems: 'center', justifyContent: 'center', marginBottom: 18 }}><IconAu name="chat" size={24} color="var(--ml-green-600)" /></div>
      <h1 style={{ margin: 0, fontSize: 26, fontWeight: 800, color: 'var(--text-strong)', letterSpacing: '-.01em' }}>Enter your WhatsApp code</h1>
      <p style={{ margin: '8px 0 24px', fontSize: 14.5, color: 'var(--text-muted)' }}>We sent a 6-digit code to <b style={{ color: 'var(--text-body)' }}>+27 82 •••  0000</b>. It expires in 5 minutes.</p>
      <div style={{ display: 'flex', gap: 10, alignItems: 'center', marginBottom: 22 }}>
        {val.map((v, i) => (
          <input key={i} ref={refs[i]} value={v} onChange={(e) => onChg(i, e.target.value)} inputMode="numeric" maxLength={1}
            style={{ width: 54, height: 62, textAlign: 'center', background: 'var(--surface-sunken)', border: `1.5px solid ${v ? 'var(--accent)' : 'transparent'}`, borderRadius: 'var(--radius-md)', fontFamily: 'var(--font-mono)', fontSize: 24, fontWeight: 700, color: 'var(--text-strong)', outline: 'none' }}
            onFocus={(e) => { e.target.style.borderColor = 'var(--accent)'; e.target.style.background = 'var(--surface-card)'; }}
            onBlur={(e) => { e.target.style.borderColor = v ? 'var(--accent)' : 'transparent'; e.target.style.background = 'var(--surface-sunken)'; }} />
        ))}
      </div>
      <BtnAu block size="lg" iconRight="arrow_forward" onClick={() => go && go('app')}>Verify &amp; continue</BtnAu>
      <p style={{ marginTop: 18, fontSize: 13.5, color: 'var(--text-muted)', textAlign: 'center' }}>Didn't get it? <a href="#" style={{ color: 'var(--accent)', fontWeight: 700, textDecoration: 'none' }}>Resend code</a></p>
    </AuthShell>
  );
}

function ForgotScreen({ go }) {
  return (
    <AuthShell>
      <button type="button" onClick={() => go && go('login')} style={{ display: 'inline-flex', alignItems: 'center', gap: 6, marginBottom: 20, border: 'none', background: 'transparent', color: 'var(--text-muted)', fontSize: 13.5, fontWeight: 600, cursor: 'pointer' }}><IconAu name="chevron_left" size={18} />Back to sign in</button>
      <div style={{ width: 48, height: 48, borderRadius: 14, background: 'var(--ml-well-cyan)', display: 'flex', alignItems: 'center', justifyContent: 'center', marginBottom: 18 }}><IconAu name="lock_reset" size={24} color="var(--accent)" /></div>
      <h1 style={{ margin: 0, fontSize: 26, fontWeight: 800, color: 'var(--text-strong)', letterSpacing: '-.01em' }}>Reset your password</h1>
      <p style={{ margin: '8px 0 24px', fontSize: 14.5, color: 'var(--text-muted)' }}>Enter your account email and we'll send you a secure reset link.</p>
      <div style={{ display: 'flex', flexDirection: 'column', gap: 16 }}>
        <InAu label="Account email" icon="mail" placeholder="you@company.com" type="email" />
        <BtnAu block size="lg" icon="send" onClick={() => go && go('login')}>Send reset link</BtnAu>
      </div>
    </AuthShell>
  );
}

function RegisterScreen({ go }) {
  const [type, setType] = React.useState('mine');
  return (
    <AuthShell>
      <button type="button" onClick={() => go && go('login')} style={{ display: 'inline-flex', alignItems: 'center', gap: 6, marginBottom: 20, border: 'none', background: 'transparent', color: 'var(--text-muted)', fontSize: 13.5, fontWeight: 600, cursor: 'pointer' }}><IconAu name="chevron_left" size={18} />Back to sign in</button>
      <h1 style={{ margin: 0, fontSize: 26, fontWeight: 800, color: 'var(--text-strong)', letterSpacing: '-.01em' }}>Register your organization</h1>
      <p style={{ margin: '8px 0 22px', fontSize: 14.5, color: 'var(--text-muted)' }}>Choose your organization type — this sets the portals and roles available to your team.</p>
      <div style={{ display: 'flex', flexDirection: 'column', gap: 10, marginBottom: 22 }}>
        {ORG_TYPES.map((o) => {
          const sel = type === o.key;
          return (
            <button key={o.key} type="button" onClick={() => setType(o.key)} style={{ display: 'flex', alignItems: 'center', gap: 14, padding: 16, borderRadius: 'var(--radius-lg)', cursor: 'pointer', textAlign: 'left', border: `1.5px solid ${sel ? 'var(--accent)' : 'var(--border-card)'}`, background: sel ? 'var(--ml-well-cyan)' : 'var(--surface-card)', transition: 'all .14s' }}>
              <div style={{ width: 46, height: 46, borderRadius: 13, background: `var(--ml-well-${o.tone})`, display: 'flex', alignItems: 'center', justifyContent: 'center', flexShrink: 0 }}><IconAu name={o.icon} size={24} color={TONE_FG[o.tone]} /></div>
              <div style={{ flex: 1 }}><div style={{ fontSize: 16, fontWeight: 800, color: 'var(--text-strong)' }}>{o.label}</div><div style={{ fontSize: 12.5, color: 'var(--text-muted)' }}>{o.key === 'mine' ? 'Load control, gate security & buyers' : o.key === 'buyer' ? 'Routes, waybills & reconciliation' : 'Fleet, drivers & live positions'}</div></div>
              <div style={{ width: 22, height: 22, borderRadius: 999, border: `2px solid ${sel ? 'var(--accent)' : 'var(--border-strong)'}`, display: 'flex', alignItems: 'center', justifyContent: 'center' }}>{sel && <span style={{ width: 11, height: 11, borderRadius: 999, background: 'var(--accent)' }} />}</div>
            </button>
          );
        })}
      </div>
      <div style={{ display: 'flex', flexDirection: 'column', gap: 16 }}>
        <InAu label="Company name" icon="apartment" placeholder="e.g. Iron Hills Mining" />
        <InAu label="Owner email" icon="mail" placeholder="owner@company.com" type="email" />
        <BtnAu block size="lg" iconRight="arrow_forward" onClick={() => go && go('login')}>Create organization</BtnAu>
      </div>
    </AuthShell>
  );
}

window.AuthScreens = { LoginScreen, OtpScreen, ForgotScreen, RegisterScreen };
