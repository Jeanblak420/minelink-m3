/* MineLink Chat — navigator + app root. Single-column messenger routed inside
 * the floating ChatShell: Home (Chats/Groups/Contacts) → Conversation / Group
 * room → Settings / Profile / Company / Connections. PRESERVES the MineLink
 * company-scoping rules & guardrails (data.js): internal + Mine-Link + granted
 * connections only; revoke keeps history but blocks; org-to-org groups with
 * per-company member control; super-admin grant/revoke. */
const CDx = window.ChatData;
const K = window.ChatKit;
const TH = window.ChatThemes;
const SND = window.ChatSound;
const { Icon: IconX } = window.MineLinkDesignSystem_9acfde;
const { ChatShell } = window.ChatShell;
const { SettingsPanel } = window.ChatSettings;
const { ProfilePanel } = window.ChatProfile;
const { SupportHome, NewTicketForm, TicketView } = window.ChatSupport;

const VIEWERS = [
  { id: 'ih1', label: 'Johan · Iron Hills (Mine)' },
  { id: 'at1', label: 'Eli · Atlas (Buyer)' },
  { id: 'rh1', label: 'Sipho · Roadhaul (Transporter)' },
  { id: 'sa1', label: 'MineLink Admin (Super)' },
];
function useForce() { const [, s] = React.useState(0); return () => s((n) => n + 1); }

/* ── Home: header + tabs + lists ───────────────────────────────────────── */
function Home({ viewer, pal, tab, setTab, groups, myGroups, convItems, typingUser, onOpenDM, onOpenRoom, onOpenProfile, onOpenContacts, onCreate, connectedForGroups, isAdmin, onConnections, onOpenTicket, onNewTicket }) {
  const v = CDx.user(viewer);
  const supportBadge = isAdmin ? CDx.ticketsForAdmin().filter((k) => k.status === 'sent').length : CDx.unreadNotifCount(viewer);
  return (
    <div style={{ display: 'flex', flexDirection: 'column', height: '100%', background: pal.body }}>
      <div style={{ background: pal.header, padding: '10px 14px 0' }}>
        <div style={{ display: 'flex', alignItems: 'center', gap: 10, paddingBottom: 10 }}>
          <div style={{ width: 34, height: 34, borderRadius: 10, background: `linear-gradient(150deg,${pal.accent},${pal.senderName})`, display: 'flex', alignItems: 'center', justifyContent: 'center' }}><IconX name="forum" size={18} color={pal.accentText} fill={1} /></div>
          <div style={{ flex: 1, minWidth: 0 }}>
            <div style={{ fontSize: 15, fontWeight: 800, color: pal.headerText }}>Messages</div>
            <div style={{ fontSize: 11.5, color: pal.bodySubtle, whiteSpace: 'nowrap', overflow: 'hidden', textOverflow: 'ellipsis' }}>{v.name} · {CDx.org(v.org).name}</div>
          </div>
          {isAdmin && <button type="button" onClick={onConnections} title="Org-to-org connections" style={{ border: `1px solid ${pal.divider}`, background: pal.tabSelectedBg, color: pal.accent, width: 32, height: 32, borderRadius: 9, cursor: 'pointer', display: 'flex', alignItems: 'center', justifyContent: 'center' }}><IconX name="hub" size={18} color={pal.accent} /></button>}
        </div>
        <div style={{ display: 'flex', gap: 4 }}>
          {(isAdmin ? [['chats', 'Chats'], ['contacts', 'Contacts'], ['support', 'Support']] : [['chats', 'Chats'], ['groups', 'Groups'], ['contacts', 'Contacts'], ['support', 'Support']]).map(([k, l]) => (
            <button key={k} type="button" onClick={() => setTab(k)} style={{ flex: 1, padding: '9px 0', border: 'none', background: 'transparent', color: tab === k ? pal.accent : pal.bodySubtle, fontFamily: 'var(--font-sans)', fontSize: 12.5, fontWeight: 700, cursor: 'pointer', borderBottom: `2.5px solid ${tab === k ? pal.tabIndicator : 'transparent'}`, display: 'inline-flex', alignItems: 'center', justifyContent: 'center', gap: 5 }}>{l}{k === 'support' && supportBadge > 0 ? <span style={{ background: pal.unreadBadge, color: pal.unreadBadgeText, fontSize: 10, fontWeight: 800, borderRadius: 999, minWidth: 16, height: 16, display: 'inline-flex', alignItems: 'center', justifyContent: 'center', padding: '0 4px' }}>{supportBadge}</span> : null}</button>
          ))}
        </div>
      </div>

      <div style={{ flex: 1, minHeight: 0, display: 'flex', flexDirection: 'column' }}>
        {tab === 'support' ? (
          <SupportHome viewer={viewer} pal={pal} isAdmin={isAdmin} onOpenTicket={onOpenTicket} onNew={onNewTicket} />
        ) : (
        <div style={{ flex: 1, overflowY: 'auto' }}>
        {tab === 'chats' ? (
          convItems.length ? convItems.map(({ user, group, last, unread }) => (
            <K.ConversationRow key={user.id} person={user} pal={pal} onClick={() => onOpenDM(user.id)} unread={unread}
              typing={typingUser === user.id}
              last={(last.from === viewer ? 'You: ' : '') + (last.text || (last.file ? '📎 ' + last.file : ''))}
              groupBadge={group.kind === 'admin' ? <IconX name="verified" size={14} color={pal.accent} fill={1} /> : group.kind !== 'internal' && group.org ? <span style={{ fontSize: 10, color: pal.bodySubtle }}>· {group.org.name}</span> : null} />
          )) : <Empty pal={pal} icon="forum" title="No conversations yet" sub="Open Contacts to start one." />
        ) : tab === 'groups' ? (
          <div>
            <div style={{ padding: '12px 14px' }}>
              <button type="button" onClick={onCreate} disabled={!connectedForGroups.length} title={connectedForGroups.length ? '' : 'No connected orgs yet'}
                style={{ display: 'flex', alignItems: 'center', gap: 10, width: '100%', border: `1px dashed ${pal.accent}`, background: connectedForGroups.length ? pal.tabSelectedBg : 'transparent', borderRadius: 12, padding: '11px 12px', cursor: connectedForGroups.length ? 'pointer' : 'not-allowed', opacity: connectedForGroups.length ? 1 : 0.55 }}>
                <IconX name="group_add" size={19} color={pal.accent} />
                <div style={{ flex: 1, textAlign: 'left' }}><div style={{ fontSize: 13, fontWeight: 700, color: pal.bodyText }}>New org-to-org group</div><div style={{ fontSize: 11.5, color: pal.bodySubtle }}>{connectedForGroups.length ? 'With a connected company' : 'Requires a Mine-Link connection'}</div></div>
              </button>
            </div>
            {myGroups.length ? myGroups.map((g) => {
              const last = g.messages[g.messages.length - 1]; const gb = CDx.groupBlocked(g);
              return (
                <button key={g.id} type="button" onClick={() => onOpenRoom(g.id)} style={{ display: 'flex', alignItems: 'center', gap: 12, width: '100%', textAlign: 'left', border: 'none', cursor: 'pointer', padding: '11px 14px', background: 'transparent' }}>
                  <div style={{ width: 44, height: 44, borderRadius: 13, background: pal.tabSelectedBg, display: 'flex', alignItems: 'center', justifyContent: 'center', flexShrink: 0 }}><IconX name="groups" size={22} color={pal.accent} /></div>
                  <div style={{ flex: 1, minWidth: 0 }}>
                    <div style={{ fontSize: 14, fontWeight: 700, color: pal.bodyText, whiteSpace: 'nowrap', overflow: 'hidden', textOverflow: 'ellipsis' }}>{g.name}</div>
                    <div style={{ fontSize: 12.5, color: pal.bodySubtle, whiteSpace: 'nowrap', overflow: 'hidden', textOverflow: 'ellipsis' }}>{gb ? '⚠ Messaging disabled' : last ? `${CDx.user(last.from).name.split(' ')[0]}: ${last.text}` : 'No messages yet'}</div>
                  </div>
                </button>
              );
            }) : <Empty pal={pal} icon="groups" title="No group chats yet" sub="Create one with a connected company." />}
          </div>
        ) : (
          groups.map((g, gi) => (
            <div key={gi}>
              <K.GroupHeader group={g} count={g.users.length} pal={pal} />
              {g.users.map((u) => <K.ContactRow key={u.id} person={u} pal={pal} blocked={g.kind === 'connected' && g.status === 'revoked'} onClick={() => onOpenDM(u.id)} onProfile={() => onOpenProfile(u.id)} />)}
            </div>
          ))
        )}
        </div>
        )}
      </div>
    </div>
  );
}

function Empty({ pal, icon, title, sub }) {
  return (
    <div style={{ display: 'flex', flexDirection: 'column', alignItems: 'center', justifyContent: 'center', gap: 10, padding: '40px 24px', textAlign: 'center' }}>
      <div style={{ width: 64, height: 64, borderRadius: 20, background: pal.tabSelectedBg, display: 'flex', alignItems: 'center', justifyContent: 'center' }}><IconX name={icon} size={32} color={pal.accent} /></div>
      <div style={{ fontSize: 15, fontWeight: 700, color: pal.bodyText }}>{title}</div>
      <div style={{ fontSize: 12.5, color: pal.bodySubtle, maxWidth: 240 }}>{sub}</div>
    </div>
  );
}

/* ── Conversation (DM) ─────────────────────────────────────────────────── */
function Conversation({ viewer, otherId, pal, group, blocked, typing, onBack, onProfile, onSend, requestMineLink, contacts }) {
  const other = CDx.user(otherId);
  const msgs = CDx.messagesBetween(viewer, otherId);
  const [reply, setReply] = React.useState(null);
  const scrollRef = React.useRef(null);
  React.useEffect(() => { if (scrollRef.current) scrollRef.current.scrollTop = scrollRef.current.scrollHeight; }, [msgs.length]);
  const statusPill = group.kind === 'admin' ? ['MINE-LINK', pal.accent] : group.kind === 'internal' ? ['MY COMPANY', '#16a34a'] : blocked ? ['BLOCKED', '#e0842b'] : ['CONNECTED', '#16a34a'];

  return (
    <div style={{ display: 'flex', flexDirection: 'column', height: '100%', background: pal.body }}>
      <div style={{ display: 'flex', alignItems: 'center', gap: 8, padding: '8px 10px', background: pal.header, borderBottom: `1px solid ${pal.divider}` }}>
        <button type="button" onClick={onBack} style={{ border: 'none', background: 'transparent', cursor: 'pointer', display: 'flex', padding: 4 }}><IconX name="arrow_back" size={20} color={pal.headerText} /></button>
        <button type="button" onClick={() => onProfile(otherId)} style={{ display: 'flex', alignItems: 'center', gap: 8, flex: 1, minWidth: 0, border: 'none', background: 'transparent', cursor: 'pointer', textAlign: 'left' }}>
          <K.ChatAvatar person={other} size={34} pal={pal} />
          <div style={{ minWidth: 0 }}>
            <div style={{ fontSize: 14, fontWeight: 800, color: pal.headerText, whiteSpace: 'nowrap', overflow: 'hidden', textOverflow: 'ellipsis' }}>{other.name}</div>
            <div style={{ fontSize: 11, color: typing ? pal.accent : pal.bodySubtle, fontWeight: typing ? 700 : 400, fontStyle: typing ? 'italic' : 'normal' }}>{typing ? 'typing…' : K.presenceText(other)}</div>
          </div>
        </button>
        <span style={{ fontSize: 9.5, fontWeight: 800, letterSpacing: '.05em', color: '#fff', background: statusPill[1], padding: '3px 7px', borderRadius: 999 }}>{statusPill[0]}</span>
        <button type="button" onClick={() => onProfile(otherId)} title="View profile" style={{ border: 'none', background: 'transparent', cursor: 'pointer', display: 'flex', padding: 4 }}><IconX name="info" size={20} color={pal.bodySubtle} /></button>
      </div>

      <div ref={scrollRef} style={{ flex: 1, overflowY: 'auto', padding: '12px 16px' }}>
        <DayGroups msgs={msgs} viewer={viewer} pal={pal} onReply={setReply} nameFor={(id) => CDx.user(id).name} />
        {blocked && <HistoryChip pal={pal} />}
      </div>
      {blocked
        ? <K.BlockedBanner orgName={CDx.org(other.org).name} onRequest={requestMineLink} pal={pal} />
        : <K.Composer pal={pal} contacts={contacts} replyTo={reply} onCancelReply={() => setReply(null)} onSend={(text, meta) => { onSend(otherId, text, meta); setReply(null); }} onTyping={() => {}} />}
    </div>
  );
}

/* ── Group room ────────────────────────────────────────────────────────── */
function GroupRoom({ viewer, groupId, pal, onBack, onMembers, onSend, requestMineLink, contacts }) {
  const room = CDx.groupById(groupId);
  const blocked = CDx.groupBlocked(room);
  const scrollRef = React.useRef(null);
  const [reply, setReply] = React.useState(null);
  React.useEffect(() => { if (scrollRef.current) scrollRef.current.scrollTop = scrollRef.current.scrollHeight; }, [room.messages.length]);
  const otherOrgName = room.orgs.map((o) => CDx.org(o).name).find((n) => n !== CDx.org(CDx.user(viewer).org).name) || 'the other company';
  return (
    <div style={{ display: 'flex', flexDirection: 'column', height: '100%', background: pal.body }}>
      <div style={{ display: 'flex', alignItems: 'center', gap: 8, padding: '8px 10px', background: pal.header, borderBottom: `1px solid ${pal.divider}` }}>
        <button type="button" onClick={onBack} style={{ border: 'none', background: 'transparent', cursor: 'pointer', display: 'flex', padding: 4 }}><IconX name="arrow_back" size={20} color={pal.headerText} /></button>
        <div style={{ width: 34, height: 34, borderRadius: 10, background: pal.tabSelectedBg, display: 'flex', alignItems: 'center', justifyContent: 'center' }}><IconX name="groups" size={19} color={pal.accent} /></div>
        <div style={{ flex: 1, minWidth: 0 }}>
          <div style={{ fontSize: 14, fontWeight: 800, color: pal.headerText, whiteSpace: 'nowrap', overflow: 'hidden', textOverflow: 'ellipsis' }}>{room.name}</div>
          <div style={{ fontSize: 11, color: pal.bodySubtle }}>{CDx.groupMembers(room).length} members · {room.orgs.map((o) => CDx.org(o).name).join(' × ')}</div>
        </div>
        <button type="button" onClick={onMembers} title="Members" style={{ border: 'none', background: 'transparent', cursor: 'pointer', display: 'flex', padding: 4 }}><IconX name="manage_accounts" size={20} color={pal.accent} /></button>
      </div>
      <div ref={scrollRef} style={{ flex: 1, overflowY: 'auto', padding: '12px 16px' }}>
        <K.DateSeparator label="Group chat" pal={pal} />
        {room.messages.map((m) => { const mine = m.from === viewer; return <K.MessageBubble key={m.id} msg={m} mine={mine} showName={!mine} senderName={`${CDx.user(m.from).name} · ${CDx.org(CDx.user(m.from).org).name}`} pal={pal} onReply={blocked ? null : setReply} attachment={m.file} />; })}
        {blocked && <HistoryChip pal={pal} />}
      </div>
      {blocked
        ? <K.BlockedBanner orgName={otherOrgName} onRequest={requestMineLink} pal={pal} />
        : <K.Composer pal={pal} contacts={contacts} replyTo={reply} onCancelReply={() => setReply(null)} placeholder="Message the group…" onSend={(text, meta) => { onSend(groupId, text, meta); setReply(null); }} />}
    </div>
  );
}

function DayGroups({ msgs, viewer, pal, onReply, nameFor }) {
  const out = []; let lastDay = null;
  msgs.forEach((m) => {
    const day = K.fmtDateLabel(m.at);
    if (day !== lastDay) { out.push(<K.DateSeparator key={'d' + m.id} label={day} pal={pal} />); lastDay = day; }
    const mine = m.from === viewer;
    out.push(<K.MessageBubble key={m.id} msg={m} mine={mine} showName={false} senderName={nameFor(m.from)} pal={pal} reply={m.reply} attachment={m.file} onReply={onReply} />);
  });
  return out;
}
function HistoryChip({ pal }) {
  return <div style={{ textAlign: 'center', margin: '16px 0' }}><span style={{ display: 'inline-flex', alignItems: 'center', gap: 6, fontSize: 12, color: pal.bodySubtle, background: pal.tabSelectedBg, padding: '6px 12px', borderRadius: 999 }}><IconX name="history" size={14} color={pal.bodySubtle} />History preserved · messaging disabled</span></div>;
}

/* ── Modals: Connections (admin), Members, Create group ─────────────────── */
function Scrim({ onClose }) { return <div onClick={onClose} style={{ position: 'absolute', inset: 0, background: 'rgba(3,7,18,.5)', zIndex: 40 }} />; }

function ConnectionsModal({ pal, onClose }) {
  const force = useForce();
  const [pick, setPick] = React.useState({ a: '', b: '' });
  const on = (id) => CDx.org(id).name;
  const oType = (id) => CDx.org(id).type;
  const orgs = CDx.ORGS;
  // Every possible company pair + its current link status (default = 'none').
  const pairs = [];
  for (let i = 0; i < orgs.length; i++) for (let j = i + 1; j < orgs.length; j++) {
    pairs.push({ a: orgs[i].id, b: orgs[j].id, status: CDx.connectionStatus(orgs[i].id, orgs[j].id) });
  }
  const linked = pairs.filter((p) => p.status === 'granted');
  const blocked = pairs.filter((p) => p.status === 'revoked');
  const none = pairs.filter((p) => p.status === 'none');
  const setStatus = (a, b, s) => { CDx.setConnection(a, b, s); force(); };
  const sel = { flex: 1, appearance: 'none', WebkitAppearance: 'none', padding: '9px 11px', background: pal.body, color: pal.bodyText, border: `1px solid ${pal.divider}`, borderRadius: 10, fontSize: 13, fontFamily: 'var(--font-sans)', cursor: 'pointer' };

  const Row = ({ p }) => {
    const meta = CDx.getConnections().find((c) => [c.a, c.b].sort().join('|') === [p.a, p.b].sort().join('|'));
    const sub = p.status === 'granted' ? `Can chat${meta && meta.since ? ' · linked ' + meta.since : ''}`
      : p.status === 'revoked' ? `Link removed${meta && meta.revokedOn ? ' · ' + meta.revokedOn : ''} · history kept`
      : 'Not linked · internal chat only';
    const act = p.status === 'granted' ? { label: 'Unlink', icon: 'link_off', color: '#e0842b', to: 'revoked' }
      : { label: p.status === 'revoked' ? 'Re-link' : 'Link', icon: 'link', color: '#16a34a', to: 'granted' };
    return (
      <div style={{ display: 'flex', alignItems: 'center', gap: 10, padding: 12, border: `1px solid ${pal.divider}`, borderRadius: 10 }}>
        <div style={{ flex: 1, minWidth: 0 }}>
          <div style={{ fontSize: 13.5, fontWeight: 700, color: pal.bodyText }}>{on(p.a)} <span style={{ color: pal.bodySubtle, fontWeight: 400 }}>↔</span> {on(p.b)}</div>
          <div style={{ fontSize: 11, color: pal.bodySubtle, marginTop: 2 }}>{oType(p.a)} × {oType(p.b)} · {sub}</div>
        </div>
        <button type="button" onClick={() => setStatus(p.a, p.b, act.to)}
          style={{ border: `1px solid ${act.color}`, background: 'transparent', color: act.color, borderRadius: 8, padding: '6px 11px', fontSize: 12.5, fontWeight: 700, cursor: 'pointer', fontFamily: 'var(--font-sans)', display: 'inline-flex', gap: 5, alignItems: 'center' }}>
          <IconX name={act.icon} size={15} color={act.color} />{act.label}</button>
      </div>
    );
  };
  const Group = ({ title, tint, items }) => items.length ? (
    <div style={{ marginBottom: 16 }}>
      <div style={{ display: 'flex', alignItems: 'center', gap: 7, marginBottom: 8 }}>
        <span style={{ width: 8, height: 8, borderRadius: 999, background: tint }} />
        <span style={{ fontSize: 11, fontWeight: 800, letterSpacing: '.08em', color: pal.bodySubtle }}>{title} · {items.length}</span>
      </div>
      <div style={{ display: 'flex', flexDirection: 'column', gap: 8 }}>{items.map((p, i) => <Row key={i} p={p} />)}</div>
    </div>
  ) : null;
  const chip = (n, c, l) => <span style={{ display: 'inline-flex', alignItems: 'center', gap: 5, fontSize: 12, fontWeight: 700, color: pal.bodyText }}><span style={{ width: 8, height: 8, borderRadius: 999, background: c }} />{n} {l}</span>;

  return (
    <>
      <Scrim onClose={onClose} />
      <div style={{ position: 'absolute', inset: 0, zIndex: 41, background: pal.body, display: 'flex', flexDirection: 'column' }}>
        <div style={{ display: 'flex', alignItems: 'center', gap: 8, padding: '10px 12px', background: pal.header, borderBottom: `1px solid ${pal.divider}` }}>
          <IconX name="hub" size={20} color={pal.accent} />
          <div style={{ flex: 1 }}><div style={{ fontSize: 14, fontWeight: 800, color: pal.headerText }}>Company chat links</div><div style={{ fontSize: 11.5, color: pal.bodySubtle }}>Link two companies so they can message each other</div></div>
          <button type="button" onClick={onClose} style={{ border: 'none', background: 'transparent', cursor: 'pointer', display: 'flex', padding: 6 }}><IconX name="close" size={20} color={pal.headerText} /></button>
        </div>
        <div style={{ flex: 1, overflowY: 'auto', padding: 16 }}>
          <div style={{ display: 'flex', gap: 9, padding: 12, marginBottom: 16, background: pal.tabSelectedBg, borderRadius: 10 }}>
            <IconX name="info" size={17} color={pal.accent} />
            <div style={{ fontSize: 12, color: pal.bodySubtle, lineHeight: 1.5 }}>By default no two companies are linked — everyone can only chat <b>inside their own company</b> and won't see other companies in their contacts. Link a pair below to let them message each other.</div>
          </div>
          <div style={{ display: 'flex', gap: 16, flexWrap: 'wrap', marginBottom: 16 }}>{chip(linked.length, '#16a34a', 'linked')}{chip(blocked.length, '#e0842b', 'blocked')}{chip(none.length, pal.bodySubtle, 'not linked')}</div>

          <div style={{ border: `1px solid ${pal.divider}`, borderRadius: 12, padding: 14, marginBottom: 18 }}>
            <div style={{ fontSize: 12.5, fontWeight: 800, color: pal.bodyText, marginBottom: 10 }}>Link two companies</div>
            <div style={{ display: 'flex', alignItems: 'center', gap: 8 }}>
              <select value={pick.a} onChange={(e) => setPick((p) => ({ ...p, a: e.target.value }))} style={sel}><option value="">Company A</option>{orgs.map((o) => <option key={o.id} value={o.id}>{o.name}</option>)}</select>
              <IconX name="sync_alt" size={16} color={pal.bodySubtle} />
              <select value={pick.b} onChange={(e) => setPick((p) => ({ ...p, b: e.target.value }))} style={sel}><option value="">Company B</option>{orgs.filter((o) => o.id !== pick.a).map((o) => <option key={o.id} value={o.id}>{o.name}</option>)}</select>
            </div>
            <button type="button" disabled={!pick.a || !pick.b} onClick={() => { CDx.setConnection(pick.a, pick.b, 'granted'); setPick({ a: '', b: '' }); force(); }} style={{ marginTop: 12, width: '100%', border: 'none', background: pal.accent, color: pal.accentText, borderRadius: 10, padding: '9px 0', fontSize: 13, fontWeight: 700, cursor: pick.a && pick.b ? 'pointer' : 'not-allowed', opacity: pick.a && pick.b ? 1 : 0.5, fontFamily: 'var(--font-sans)', display: 'inline-flex', gap: 6, alignItems: 'center', justifyContent: 'center' }}><IconX name="link" size={16} color={pal.accentText} />Link companies</button>
          </div>

          <Group title="LINKED — CAN CHAT" tint="#16a34a" items={linked} />
          <Group title="BLOCKED — LINK REMOVED" tint="#e0842b" items={blocked} />
          <Group title="NOT LINKED — DEFAULT" tint={pal.bodySubtle} items={none} />

          <div style={{ display: 'flex', gap: 9, padding: 12, marginTop: 4, background: pal.tabSelectedBg, borderRadius: 10 }}>
            <IconX name="info" size={17} color={pal.accent} />
            <div style={{ fontSize: 12, color: pal.bodySubtle, lineHeight: 1.5 }}>Unlinking keeps all past messages but blocks new ones — both companies see a banner asking them to contact Mine-Link. You can re-link a pair at any time.</div>
          </div>
        </div>
      </div>
    </>
  );
}

function MembersModal({ pal, group, viewer, onClose }) {
  const force = useForce(); const myOrg = CDx.user(viewer).org;
  return (
    <>
      <Scrim onClose={onClose} />
      <div style={{ position: 'absolute', inset: 0, zIndex: 41, background: pal.body, display: 'flex', flexDirection: 'column' }}>
        <div style={{ display: 'flex', alignItems: 'center', gap: 8, padding: '10px 12px', background: pal.header, borderBottom: `1px solid ${pal.divider}` }}>
          <IconX name="groups" size={20} color={pal.accent} />
          <div style={{ flex: 1 }}><div style={{ fontSize: 14, fontWeight: 800, color: pal.headerText }}>Group members</div><div style={{ fontSize: 11.5, color: pal.bodySubtle, whiteSpace: 'nowrap', overflow: 'hidden', textOverflow: 'ellipsis' }}>{group.name}</div></div>
          <button type="button" onClick={onClose} style={{ border: 'none', background: 'transparent', cursor: 'pointer', display: 'flex', padding: 6 }}><IconX name="close" size={20} color={pal.headerText} /></button>
        </div>
        <div style={{ flex: 1, overflowY: 'auto', padding: 16 }}>
          {group.orgs.map((orgId) => {
            const o = CDx.org(orgId); const mine = orgId === myOrg; const memberIds = group.members[orgId] || [];
            return (
              <div key={orgId} style={{ marginBottom: 20 }}>
                <div style={{ display: 'flex', alignItems: 'center', gap: 8, marginBottom: 8 }}>
                  <div style={{ width: 22, height: 22, borderRadius: 6, background: pal.tabSelectedBg, display: 'flex', alignItems: 'center', justifyContent: 'center' }}><IconX name={o.icon} size={13} color={pal.accent} /></div>
                  <span style={{ fontSize: 13, fontWeight: 800, color: pal.bodyText }}>{o.name}</span>
                  {mine ? <span style={{ fontSize: 10.5, fontWeight: 700, color: pal.accentText, background: pal.accent, padding: '2px 7px', borderRadius: 999 }}>You manage</span> : <span style={{ fontSize: 11.5, color: pal.bodySubtle }}>managed by them</span>}
                </div>
                <div style={{ display: 'flex', flexDirection: 'column', gap: 6 }}>
                  {CDx.usersOf(orgId).map((u) => {
                    const isMember = memberIds.includes(u.id);
                    return (
                      <div key={u.id} style={{ display: 'flex', alignItems: 'center', gap: 10, padding: '7px 9px', borderRadius: 10, background: isMember ? pal.tabSelectedBg : 'transparent', border: `1px solid ${isMember ? pal.divider : 'transparent'}` }}>
                        <K.ChatAvatar person={u} size={32} pal={pal} />
                        <div style={{ flex: 1, minWidth: 0 }}><div style={{ fontSize: 13.5, fontWeight: 600, color: pal.bodyText }}>{u.name}</div><div style={{ fontSize: 11.5, color: pal.bodySubtle }}>{u.role}</div></div>
                        {mine ? <button type="button" onClick={() => { CDx.setGroupMember(group.id, orgId, u.id, !isMember); force(); }} style={{ border: `1px solid ${isMember ? '#e0842b' : pal.accent}`, background: isMember ? 'transparent' : pal.accent, color: isMember ? '#e0842b' : pal.accentText, borderRadius: 8, padding: '5px 10px', fontSize: 12, fontWeight: 700, cursor: 'pointer', fontFamily: 'var(--font-sans)' }}>{isMember ? 'Remove' : 'Add'}</button>
                          : isMember ? <IconX name="check_circle" size={17} color="#16a34a" /> : <span style={{ fontSize: 11, color: pal.bodySubtle }}>—</span>}
                      </div>
                    );
                  })}
                </div>
              </div>
            );
          })}
          <div style={{ display: 'flex', gap: 9, padding: 12, background: pal.tabSelectedBg, borderRadius: 10 }}><IconX name="info" size={16} color={pal.accent} /><div style={{ fontSize: 12, color: pal.bodySubtle, lineHeight: 1.5 }}>Each company controls only its own members. You can add or remove people from <b>{CDx.org(myOrg).name}</b> only.</div></div>
        </div>
      </div>
    </>
  );
}

function CreateGroupModal({ pal, viewer, connected, onClose, onCreated }) {
  const [name, setName] = React.useState(''); const [orgB, setOrgB] = React.useState(connected[0] ? connected[0].id : '');
  const inp = { boxSizing: 'border-box', width: '100%', padding: '11px 13px', background: pal.body, color: pal.bodyText, border: `1.5px solid ${pal.divider}`, borderRadius: 10, fontSize: 14, fontFamily: 'var(--font-sans)', outline: 'none' };
  return (
    <>
      <Scrim onClose={onClose} />
      <div style={{ position: 'absolute', inset: 0, zIndex: 41, background: pal.body, display: 'flex', flexDirection: 'column' }}>
        <div style={{ display: 'flex', alignItems: 'center', gap: 8, padding: '10px 12px', background: pal.header, borderBottom: `1px solid ${pal.divider}` }}>
          <IconX name="group_add" size={20} color={pal.accent} />
          <div style={{ flex: 1, fontSize: 14, fontWeight: 800, color: pal.headerText }}>New org-to-org group</div>
          <button type="button" onClick={onClose} style={{ border: 'none', background: 'transparent', cursor: 'pointer', display: 'flex', padding: 6 }}><IconX name="close" size={20} color={pal.headerText} /></button>
        </div>
        <div style={{ padding: 18, display: 'flex', flexDirection: 'column', gap: 14 }}>
          <label style={{ display: 'flex', flexDirection: 'column', gap: 6 }}><span style={{ fontSize: 12.5, fontWeight: 600, color: pal.bodyText }}>Group name</span><input value={name} onChange={(e) => setName(e.target.value)} placeholder="e.g. Iron Hills × Atlas — Q3" style={inp} /></label>
          <label style={{ display: 'flex', flexDirection: 'column', gap: 6 }}><span style={{ fontSize: 12.5, fontWeight: 600, color: pal.bodyText }}>Connect with</span>
            <select value={orgB} onChange={(e) => setOrgB(e.target.value)} style={{ ...inp, appearance: 'none', WebkitAppearance: 'none', cursor: 'pointer' }}>{connected.map((o) => <option key={o.id} value={o.id}>{o.name} ({o.type})</option>)}</select></label>
          <div style={{ fontSize: 12, color: pal.bodySubtle, display: 'flex', gap: 7, alignItems: 'flex-start' }}><IconX name="info" size={15} color={pal.accent} /><span>You'll be added as the first member. Add teammates from your company via <b>Members</b>.</span></div>
          <button type="button" disabled={!name.trim() || !orgB} onClick={() => onCreated(CDx.createGroup(name.trim(), CDx.user(viewer).org, orgB, viewer).id)} style={{ border: 'none', background: pal.accent, color: pal.accentText, borderRadius: 12, padding: '12px 0', fontSize: 14, fontWeight: 700, cursor: name.trim() && orgB ? 'pointer' : 'not-allowed', opacity: name.trim() && orgB ? 1 : 0.5, fontFamily: 'var(--font-sans)' }}>Create group</button>
        </div>
      </div>
    </>
  );
}

/* ── Company page (read-only, opened from a profile) ────────────────────── */
function CompanyPage({ pal, org, onBack }) {
  return (
    <div style={{ display: 'flex', flexDirection: 'column', height: '100%', background: pal.body }}>
      <div style={{ display: 'flex', alignItems: 'center', gap: 6, padding: '8px 10px', background: pal.header, borderBottom: `1px solid ${pal.divider}` }}>
        <button type="button" onClick={onBack} style={{ border: 'none', background: 'transparent', cursor: 'pointer', display: 'flex', padding: 6 }}><IconX name="arrow_back" size={20} color={pal.headerText} /></button>
        <span style={{ fontSize: 14, fontWeight: 700, color: pal.headerText }}>Company page</span>
        <span style={{ marginLeft: 'auto', fontSize: 10.5, fontWeight: 700, color: pal.bodySubtle, display: 'inline-flex', gap: 4, alignItems: 'center' }}><IconX name="visibility" size={14} color={pal.bodySubtle} />View only</span>
      </div>
      <div style={{ flex: 1, overflowY: 'auto', padding: 20 }}>
        <div style={{ display: 'flex', alignItems: 'center', gap: 14, marginBottom: 18 }}>
          <div style={{ width: 64, height: 64, borderRadius: 18, background: `linear-gradient(150deg,${pal.accent},${pal.senderName})`, display: 'flex', alignItems: 'center', justifyContent: 'center' }}><IconX name={org.icon} size={32} color={pal.accentText} fill={1} /></div>
          <div><div style={{ fontSize: 19, fontWeight: 800, color: pal.bodyText }}>{org.name}</div><div style={{ fontSize: 13, color: pal.bodySubtle }}>{org.type} · MineLink verified</div></div>
        </div>
        {[['location_on', 'Location', 'Northern Cape, South Africa'], ['inventory_2', 'Primary product', org.type === 'Mine' ? 'Iron ore · Manganese' : org.type === 'Buyer' ? 'Bulk mineral offtake' : 'Bulk haulage · 34t tri-axle'], ['groups', 'Team', `${CDx.usersOf(org.id).length} people on MineLink`], ['verified', 'Status', 'Active connection']].map(([ic, l, v]) => (
          <div key={l} style={{ display: 'flex', gap: 12, alignItems: 'flex-start', padding: '11px 0', borderBottom: `1px solid ${pal.divider}` }}>
            <IconX name={ic} size={20} color={pal.bodySubtle} />
            <div><div style={{ fontSize: 11.5, color: pal.bodySubtle }}>{l}</div><div style={{ fontSize: 14, fontWeight: 600, color: pal.bodyText }}>{v}</div></div>
          </div>
        ))}
      </div>
    </div>
  );
}

/* ── Messenger: owns view routing + palette + typing sim, inside the shell ─ */
function Messenger({ viewer }) {
  const force = useForce();
  const isAdmin = CDx.user(viewer).org === 'minelink';
  const [palId, setPalId] = React.useState(() => TH.get(viewer).id);
  const [cursorTracking, setCursorTracking] = React.useState(true);
  const [view, setView] = React.useState('home');   // home|chat|group|settings|profile|company|connections|members|create
  const [tab, setTab] = React.useState('chats');
  const [activeId, setActiveId] = React.useState(null);
  const [activeGroupId, setActiveGroupId] = React.useState(null);
  const [profileId, setProfileId] = React.useState(null);
  const [companyOrg, setCompanyOrg] = React.useState(null);
  const [typingUser, setTypingUser] = React.useState(null);
  const [activeTicketId, setActiveTicketId] = React.useState(null);
  const pal = TH.PALETTES.find((p) => p.id === palId) || TH.DEFAULT;
  React.useEffect(() => { window.__chatViewer = viewer; }, [viewer]);

  const groups = CDx.contactsFor(viewer);
  const myGroups = CDx.groupsFor(viewer);
  const connectedForGroups = CDx.connectedOrgs(viewer);
  const allContacts = groups.flatMap((g) => g.users);

  // conversations with history + unread counts
  const convItems = [];
  groups.forEach((g) => g.users.forEach((u) => {
    const msgs = CDx.messagesBetween(viewer, u.id);
    if (msgs.length) { const last = msgs[msgs.length - 1]; convItems.push({ user: u, group: g, last, unread: last.from !== viewer && last.status !== 'read' ? 1 : 0 }); }
  }));
  convItems.sort((a, b) => new Date(b.last.at) - new Date(a.last.at));
  const totalUnread = convItems.reduce((n, c) => n + c.unread, 0) + CDx.unreadNotifCount(viewer);

  // typing simulation → drives launcher + header + row typing
  React.useEffect(() => {
    const internal = allContacts.filter((u) => u.presence === 'online');
    if (!internal.length) return;
    let onTimer, offTimer;
    const cycle = () => {
      const u = internal[Math.floor(Math.random() * internal.length)];
      setTypingUser(u.id);
      offTimer = setTimeout(() => { setTypingUser(null); onTimer = setTimeout(cycle, 4500 + Math.random() * 4000); }, 2600);
    };
    onTimer = setTimeout(cycle, 3500);
    return () => { clearTimeout(onTimer); clearTimeout(offTimer); };
  }, [viewer]);

  const openDM = (id) => { setActiveId(id); setActiveGroupId(null); setView('chat'); };
  const openRoom = (id) => { setActiveGroupId(id); setView('group'); };
  const openProfile = (id) => { setProfileId(id); setView('profile'); };
  const requestMineLink = () => openDM('sa1');
  const openTicket = (id) => { setActiveTicketId(id); setView('ticket'); };
  const newTicket = () => setView('newticket');

  const sendDM = (id, text, meta) => {
    const reply = meta && meta.reply ? { name: meta.reply.name, text: meta.reply.text } : undefined;
    CDx.addMessage(viewer, id, { id: 'x' + Date.now(), from: viewer, text, at: new Date().toISOString(), status: 'delivered', reply, file: meta && meta.file });
    force();
  };
  const sendRoom = (id, text, meta) => {
    const reply = meta && meta.reply ? { name: meta.reply.name, text: meta.reply.text } : undefined;
    CDx.addGroupMessage(id, { id: 'x' + Date.now(), from: viewer, text, at: new Date().toISOString(), status: 'delivered', reply, file: meta && meta.file });
    force();
  };
  const changePalette = (id) => { TH.set(viewer, id); setPalId(id); };

  // active DM context
  const activeGroup = activeId ? groups.find((g) => g.users.some((u) => u.id === activeId)) : null;
  const blocked = activeGroup && activeGroup.kind === 'connected' && activeGroup.status === 'revoked';

  let content;
  if (view === 'settings') content = <SettingsPanel pal={pal} viewer={viewer} cursorTracking={cursorTracking} onCursorTracking={setCursorTracking} onPalette={changePalette} onBack={() => setView('home')} contacts={allContacts.slice(0, 8)} />;
  else if (view === 'profile' && profileId) content = <ProfilePanel userId={profileId} pal={pal} onBack={() => setView(activeId ? 'chat' : 'home')} onMessage={(id) => openDM(id)} onOpenCompany={(o) => { setCompanyOrg(o); setView('company'); }} />;
  else if (view === 'company' && companyOrg) content = <CompanyPage pal={pal} org={companyOrg} onBack={() => setView(profileId ? 'profile' : 'home')} />;
  else if (view === 'chat' && activeId) content = <Conversation viewer={viewer} otherId={activeId} pal={pal} group={activeGroup} blocked={blocked} typing={typingUser === activeId} contacts={allContacts} onBack={() => setView('home')} onProfile={openProfile} onSend={sendDM} requestMineLink={requestMineLink} />;
  else if (view === 'group' && activeGroupId) content = <GroupRoom viewer={viewer} groupId={activeGroupId} pal={pal} contacts={allContacts} onBack={() => setView('home')} onMembers={() => setView('members')} onSend={sendRoom} requestMineLink={requestMineLink} />;
  else if (view === 'newticket') content = <NewTicketForm viewer={viewer} pal={pal} onBack={() => setView('home')} onCreated={(id) => { setActiveTicketId(id); setView('ticket'); }} />;
  else if (view === 'ticket' && activeTicketId) content = <TicketView viewer={viewer} ticketId={activeTicketId} pal={pal} isAdmin={isAdmin} onBack={() => setView('home')} />;
  else content = <Home viewer={viewer} pal={pal} tab={tab} setTab={setTab} groups={groups} myGroups={myGroups} convItems={convItems} typingUser={typingUser} isAdmin={isAdmin}
    connectedForGroups={connectedForGroups} onOpenDM={openDM} onOpenRoom={openRoom} onOpenProfile={openProfile} onCreate={() => setView('create')} onConnections={() => setView('connections')} onOpenTicket={openTicket} onNewTicket={newTicket} />;

  return (
    <ChatShell pal={pal} accent={pal.accent} viewer={viewer} unreadCount={totalUnread} isTyping={!!typingUser} cursorTracking={cursorTracking} onOpenSettings={() => setView('settings')}>
      {content}
      {view === 'connections' && <ConnectionsModal pal={pal} onClose={() => { setView('home'); force(); }} />}
      {view === 'members' && activeGroupId && <MembersModal pal={pal} group={CDx.groupById(activeGroupId)} viewer={viewer} onClose={() => { setView('group'); force(); }} />}
      {view === 'create' && <CreateGroupModal pal={pal} viewer={viewer} connected={connectedForGroups} onClose={() => setView('home')} onCreated={(id) => { openRoom(id); force(); }} />}
    </ChatShell>
  );
}

/* ── Demo backdrop (a faux MineLink portal behind the overlay) ──────────── */
function Backdrop({ viewer }) {
  const v = CDx.user(viewer); const o = CDx.org(v.org);
  const tiles = [['local_shipping', 'Trucks at Mine', '14', 'blue'], ['balance', 'Tons Allocated', '1,240 t', 'cyan'], ['alt_route', 'Active Waybills', '32', 'green'], ['warning', 'Pending Recons', '5', 'amber']];
  return (
    <div style={{ position: 'absolute', inset: 0, display: 'flex', overflow: 'hidden' }}>
      <div style={{ width: 220, background: 'linear-gradient(180deg,#0B192E,#020617)', padding: '18px 14px', flexShrink: 0 }}>
        <div style={{ display: 'flex', alignItems: 'center', gap: 9, marginBottom: 22 }}>
          <div style={{ width: 32, height: 32, borderRadius: 9, background: 'linear-gradient(150deg,#22C2DE,#0496B6)', display: 'flex', alignItems: 'center', justifyContent: 'center' }}><IconX name="local_shipping" size={18} color="#fff" fill={1} /></div>
          <span style={{ color: '#fff', fontWeight: 800, fontSize: 16 }}>MineLink</span>
        </div>
        {['dashboard', 'local_shipping', 'alt_route', 'balance', 'map', 'forum', 'settings'].map((ic, i) => (
          <div key={ic} style={{ display: 'flex', alignItems: 'center', gap: 11, padding: '10px 11px', borderRadius: 10, marginBottom: 3, background: i === 5 ? 'rgba(0,181,216,.16)' : 'transparent', borderLeft: i === 5 ? '3px solid #00B5D8' : '3px solid transparent', color: i === 5 ? '#22C2DE' : 'rgba(226,232,240,.75)' }}>
            <IconX name={ic} size={19} color={i === 5 ? '#22C2DE' : 'rgba(226,232,240,.75)'} fill={i === 5 ? 1 : 0} /><span style={{ fontSize: 13, fontWeight: 600, textTransform: 'capitalize' }}>{ic === 'forum' ? 'Messages' : ic}</span>
          </div>
        ))}
      </div>
      <div style={{ flex: 1, minWidth: 0, background: '#F4F8FB', overflow: 'hidden' }}>
        <div style={{ height: 58, background: '#fff', borderBottom: '1px solid #E2ECF3', display: 'flex', alignItems: 'center', padding: '0 24px', gap: 12 }}>
          <div style={{ flex: 1 }}><div style={{ fontSize: 15, fontWeight: 800, color: '#0F1B2D' }}>{o.name} — {o.type} Portal</div><div style={{ fontSize: 11.5, color: '#5A6B80' }}>{o.name.toLowerCase().replace(/\s+/g, '')} · {v.name} · {v.role}</div></div>
          <IconX name="notifications" size={22} color="#5A6B80" />
        </div>
        <div style={{ padding: 24 }}>
          <div style={{ fontSize: 20, fontWeight: 800, color: '#0F1B2D', marginBottom: 4 }}>Loading activity</div>
          <div style={{ fontSize: 13, color: '#5A6B80', marginBottom: 20 }}>Live overview of trucks, tonnage and waybills across your operation.</div>
          <div style={{ display: 'grid', gridTemplateColumns: 'repeat(4, 1fr)', gap: 16 }}>
            {tiles.map(([ic, label, val, tone]) => (
              <div key={label} style={{ background: '#fff', border: '1px solid #E7EDF3', borderRadius: 16, padding: 18, boxShadow: '0 1px 3px rgba(15,23,42,.06)' }}>
                <div style={{ width: 42, height: 42, borderRadius: 12, background: tone === 'cyan' ? '#E0F7FC' : tone === 'blue' ? '#E6F0FF' : tone === 'green' ? '#E4F7EC' : '#FEF3E2', display: 'flex', alignItems: 'center', justifyContent: 'center', marginBottom: 12 }}>
                  <IconX name={ic} size={22} color={tone === 'cyan' ? '#00B5D8' : tone === 'blue' ? '#2563EB' : tone === 'green' ? '#16A34A' : '#EA8C1E'} />
                </div>
                <div style={{ fontSize: 24, fontWeight: 800, color: '#0F1B2D', fontFamily: 'var(--font-mono)' }}>{val}</div>
                <div style={{ fontSize: 12.5, color: '#5A6B80', marginTop: 2 }}>{label}</div>
              </div>
            ))}
          </div>
        </div>
      </div>
    </div>
  );
}

function ChatApp() {
  const [viewer, setViewer] = React.useState('ih1');
  return (
    <div style={{ height: '100%', display: 'flex', flexDirection: 'column', fontFamily: 'var(--font-sans)' }}>
      <div style={{ display: 'flex', alignItems: 'center', gap: 12, padding: '9px 16px', background: '#0B192E', flexShrink: 0, zIndex: 20 }}>
        <span style={{ fontSize: 11.5, fontWeight: 700, letterSpacing: '.06em', color: '#7FB7C6' }}>VIEW AS</span>
        <div style={{ display: 'flex', gap: 6, flexWrap: 'wrap' }}>
          {VIEWERS.map((vw) => (
            <button key={vw.id} type="button" onClick={() => setViewer(vw.id)} style={{ padding: '6px 12px', borderRadius: 999, border: `1px solid ${viewer === vw.id ? '#22C2DE' : 'rgba(148,163,184,.35)'}`, background: viewer === vw.id ? '#00B5D8' : 'transparent', color: viewer === vw.id ? '#04222B' : '#CBD5E1', fontFamily: 'var(--font-sans)', fontSize: 12, fontWeight: 700, cursor: 'pointer' }}>{vw.label}</button>
          ))}
        </div>
        <span style={{ marginLeft: 'auto', fontSize: 11, color: '#7FB7C6', display: 'inline-flex', alignItems: 'center', gap: 5 }}><IconX name="drag_indicator" size={15} color="#7FB7C6" />Drag the disc · click to open</span>
      </div>
      <div style={{ flex: 1, minHeight: 0, position: 'relative' }}>
        <Backdrop key={'bg' + viewer} viewer={viewer} />
        <Messenger key={viewer} viewer={viewer} />
      </div>
    </div>
  );
}

window.ChatApp = ChatApp;
