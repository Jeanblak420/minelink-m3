/* MineLink — "Coming soon" placeholders for features that are planned but not
 * yet confirmed / built: the mineral marketplace + invoicing flow, and the
 * Employee/HR + dismissal lifecycle. Premium branded holding screens. */
const DScs = window.MineLinkDesignSystem_9acfde;
const { Icon: IconCS, Button: BtnCS } = DScs;

function ComingSoon({ icon = 'rocket_launch', eyebrow = 'Coming soon', title, blurb, bullets = [], tone = 'cyan' }) {
  const fg = { cyan: 'var(--accent)', amber: 'var(--ml-orange-600)', green: 'var(--ml-green-600)' }[tone] || 'var(--accent)';
  const bg = { cyan: 'var(--ml-well-cyan)', amber: 'var(--ml-well-amber)', green: 'var(--ml-well-green)' }[tone] || 'var(--ml-well-cyan)';
  return (
    <div style={{ display: 'flex', justifyContent: 'center', paddingTop: 24 }}>
      <div style={{ maxWidth: 640, width: '100%', background: 'var(--surface-card)', border: '1px solid var(--border-card)', borderRadius: 'var(--radius-xl)', boxShadow: 'var(--shadow-md)', overflow: 'hidden' }}>
        {/* navy banner */}
        <div style={{ position: 'relative', padding: '32px 32px 28px', background: 'linear-gradient(150deg,#0b2545,#0b192e 60%,#020617)', overflow: 'hidden' }}>
          <div style={{ position: 'absolute', width: 260, height: 260, borderRadius: 999, background: 'radial-gradient(circle,rgba(0,181,216,.28),transparent 70%)', top: -110, right: -70 }} />
          <div style={{ position: 'relative', display: 'inline-flex', alignItems: 'center', gap: 8, padding: '6px 13px', borderRadius: 999, background: 'rgba(0,181,216,.16)', border: '1px solid rgba(0,181,216,.4)' }}>
            <span style={{ width: 7, height: 7, borderRadius: 999, background: 'var(--accent)' }} />
            <span style={{ fontSize: 11.5, fontWeight: 800, letterSpacing: '.12em', color: 'var(--accent)' }}>{eyebrow.toUpperCase()}</span>
          </div>
          <div style={{ position: 'relative', display: 'flex', alignItems: 'center', gap: 16, marginTop: 18 }}>
            <div style={{ width: 60, height: 60, borderRadius: 17, background: 'rgba(255,255,255,.1)', display: 'flex', alignItems: 'center', justifyContent: 'center', flexShrink: 0 }}><IconCS name={icon} size={30} color="#fff" fill={1} /></div>
            <h1 style={{ margin: 0, fontSize: 26, fontWeight: 800, color: '#fff', letterSpacing: '-.01em', lineHeight: 1.2 }}>{title}</h1>
          </div>
        </div>
        {/* body */}
        <div style={{ padding: 32 }}>
          <p style={{ margin: 0, fontSize: 15.5, color: 'var(--text-body)', lineHeight: 1.6 }}>{blurb}</p>
          {bullets.length > 0 && (
            <div style={{ marginTop: 22, display: 'flex', flexDirection: 'column', gap: 12 }}>
              {bullets.map((b, i) => (
                <div key={i} style={{ display: 'flex', alignItems: 'flex-start', gap: 12 }}>
                  <div style={{ width: 30, height: 30, borderRadius: 9, background: bg, display: 'flex', alignItems: 'center', justifyContent: 'center', flexShrink: 0, marginTop: 1 }}><IconCS name={b.icon} size={17} color={fg} /></div>
                  <div><div style={{ fontSize: 14.5, fontWeight: 700, color: 'var(--text-strong)' }}>{b.title}</div><div style={{ fontSize: 13, color: 'var(--text-muted)', marginTop: 1, lineHeight: 1.45 }}>{b.desc}</div></div>
                </div>
              ))}
            </div>
          )}
          <div style={{ display: 'flex', gap: 10, marginTop: 26 }}>
            <BtnCS icon="notifications_active">Notify me when it's ready</BtnCS>
            <BtnCS variant="outline" icon="lightbulb">Share feedback</BtnCS>
          </div>
          <div style={{ display: 'flex', alignItems: 'center', gap: 8, marginTop: 20, padding: 12, background: 'var(--surface-app)', borderRadius: 'var(--radius-md)', fontSize: 12.5, color: 'var(--text-muted)' }}>
            <IconCS name="schedule" size={16} color="var(--text-faint)" />
            This feature is in design. Scope isn't finalised yet — nothing here is live.
          </div>
        </div>
      </div>
    </div>
  );
}

function MarketplaceComingSoon() {
  return <ComingSoon
    icon="storefront"
    title="Mineral Marketplace & Invoicing"
    tone="cyan"
    blurb="A live marketplace where mines list minerals on a map and buyers purchase directly — with automatic proforma invoices, proof-of-payment approval and generated invoices in ZAR."
    bullets={[
      { icon: 'map', title: 'Map listings', desc: 'Pins per mineral showing tons available, price, grade and certificates of analysis/conformity.' },
      { icon: 'shopping_cart', title: 'Buy flow', desc: 'Select tons → Pay now or send proof of payment; payment details saved per company.' },
      { icon: 'receipt_long', title: 'Proforma → Invoice', desc: 'Auto-numbered proforma invoice on purchase; matching invoice generated once the mine accepts proof of payment.' },
      { icon: 'inventory', title: 'Live stock sync', desc: 'Purchased tons subtract from the listed amount so remaining availability stays accurate.' },
    ]} />;
}

function HrComingSoon() {
  return <ComingSoon
    icon="badge"
    title="Employee / HR & Dismissal"
    tone="amber"
    eyebrow="Coming soon · scope not confirmed"
    blurb="Employee onboarding, role approval and the dismissal lifecycle for company accounts. This flow is still being designed and approved — it is intentionally not built yet."
    bullets={[
      { icon: 'group_add', title: 'Join requests & role approval', desc: 'Employees request to join a company; management verifies and assigns a role.' },
      { icon: 'grid_view', title: 'Employee grid', desc: 'Company-wide roster with roles, status and documents.' },
      { icon: 'gavel', title: 'Dismissal lifecycle', desc: 'Initiate → appeal → final decision, with notifications at each step. (Pending approval.)' },
    ]} />;
}

window.ComingSoonScreens = { ComingSoon, MarketplaceComingSoon, HrComingSoon };
