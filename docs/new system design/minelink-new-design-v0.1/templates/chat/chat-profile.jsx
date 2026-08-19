/* MineLink Chat — in-overlay profile panel. Shows a contact's identity, live
 * presence / last-seen, role, company (tappable → company page per MineLink
 * rules), and contact info. Mirrors CPS in_overlay_profile_panel.
 * Exposes window.ChatProfile. */
(function () {
  const { Icon } = window.MineLinkDesignSystem_9acfde;
  const CD = window.ChatData;
  const K = window.ChatKit;

  function InfoRow({ icon, label, value, pal }) {
    return (
      <div style={{ display: 'flex', gap: 12, alignItems: 'flex-start', padding: '10px 0', borderBottom: `1px solid ${pal.divider}` }}>
        <Icon name={icon} size={20} color={pal.bodySubtle} />
        <div style={{ flex: 1, minWidth: 0 }}>
          <div style={{ fontSize: 11.5, color: pal.bodySubtle, letterSpacing: '.04em' }}>{label}</div>
          <div style={{ fontSize: 14, color: pal.bodyText, fontWeight: 600, wordBreak: 'break-word' }}>{value}</div>
        </div>
      </div>
    );
  }

  function ProfilePanel({ userId, pal, onBack, onMessage, onOpenCompany }) {
    const u = CD.user(userId);
    if (!u) return null;
    const o = CD.org(u.org);
    const isAdmin = u.org === 'minelink';
    const first = u.name.split(' ')[0];
    const last = u.name.split(' ').slice(1).join(' ');
    const phone = '+27 ' + (60 + (userId.charCodeAt(0) % 20)) + ' ' + String(1000000 + (userId.charCodeAt(1) * 7919 % 9000000)).slice(0, 3) + ' ' + String(1000 + (userId.charCodeAt(0) * 31 % 9000)).slice(0, 4);
    const email = (first + '.' + (last || 'user')).toLowerCase().replace(/\s+/g, '') + '@' + o.id + '.co.za';

    return (
      <div style={{ display: 'flex', flexDirection: 'column', height: '100%', background: pal.body }}>
        <div style={{ display: 'flex', alignItems: 'center', gap: 6, padding: '8px 10px', background: pal.header, borderBottom: `1px solid ${pal.divider}` }}>
          <button type="button" onClick={onBack} style={{ border: 'none', background: 'transparent', cursor: 'pointer', display: 'flex', padding: 6 }}><Icon name="arrow_back" size={20} color={pal.headerText} /></button>
          <span style={{ fontSize: 14, fontWeight: 700, color: pal.headerText, whiteSpace: 'nowrap', overflow: 'hidden', textOverflow: 'ellipsis' }}>{u.name}'s Profile</span>
        </div>
        <div style={{ flex: 1, overflowY: 'auto', padding: 20 }}>
          <div style={{ display: 'flex', flexDirection: 'column', alignItems: 'center', gap: 8 }}>
            <K.ChatAvatar person={u} size={92} pal={pal} />
            <div style={{ fontSize: 20, fontWeight: 800, color: pal.bodyText, textAlign: 'center' }}>{u.name}</div>
            <div style={{ fontSize: 13.5, color: u.presence === 'online' ? '#16a34a' : pal.bodySubtle, fontWeight: 600 }}>{K.presenceText(u)}</div>
            {isAdmin && (
              <span style={{ display: 'inline-flex', alignItems: 'center', gap: 5, background: pal.tabSelectedBg, color: pal.accent, fontSize: 12, fontWeight: 700, padding: '4px 10px', borderRadius: 999 }}><Icon name="verified" size={14} color={pal.accent} fill={1} />Mine-Link Admin</span>
            )}
          </div>

          <div style={{ display: 'flex', gap: 8, margin: '18px 0' }}>
            <button type="button" onClick={() => onMessage(userId)} style={{ flex: 1, display: 'inline-flex', alignItems: 'center', justifyContent: 'center', gap: 7, border: 'none', background: pal.accent, color: pal.accentText, fontFamily: 'var(--font-sans)', fontSize: 13.5, fontWeight: 700, padding: '11px 0', borderRadius: 12, cursor: 'pointer' }}><Icon name="forum" size={18} color={pal.accentText} />Message</button>
            {!isAdmin && (
              <button type="button" onClick={() => onOpenCompany(o)} style={{ flex: 1, display: 'inline-flex', alignItems: 'center', justifyContent: 'center', gap: 7, border: `1.5px solid ${pal.divider}`, background: 'transparent', color: pal.bodyText, fontFamily: 'var(--font-sans)', fontSize: 13.5, fontWeight: 700, padding: '11px 0', borderRadius: 12, cursor: 'pointer' }}><Icon name={o.icon} size={18} color={pal.accent} />Company page</button>
            )}
          </div>

          <InfoRow icon="badge" label="Role" value={u.role} pal={pal} />
          <InfoRow icon={o.icon} label="Company" value={`${o.name} · ${o.type}`} pal={pal} />
          <InfoRow icon="mail" label="Email" value={email} pal={pal} />
          <InfoRow icon="call" label="Phone" value={phone} pal={pal} />
          <div style={{ marginTop: 14, display: 'flex', gap: 8, padding: 12, borderRadius: 12, background: pal.tabSelectedBg }}>
            <Icon name="info" size={16} color={pal.accent} />
            <div style={{ fontSize: 12, color: pal.bodySubtle, lineHeight: 1.5 }}>Opening the company page shows their public profile as set up in their company information — you can view but not edit it.</div>
          </div>
        </div>
      </div>
    );
  }

  window.ChatProfile = { ProfilePanel };
})();
