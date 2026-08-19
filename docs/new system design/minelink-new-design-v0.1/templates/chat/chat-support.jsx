/* MineLink Chat — Support tickets. Any user logs a ticket to the Super Global
 * Admins; both admins can be assigned to the inbox; whoever accepts becomes the
 * handler and it auto-advances to In progress; admins can ask the logger
 * questions and mark it completed. Every stage change notifies the logger.
 * Exposes window.ChatSupport. */
(function () {
  const { Icon } = window.MineLinkDesignSystem_9acfde;
  const CD = window.ChatData;
  const K = window.ChatKit;

  const STATUS = {
    sent: { label: 'Ticket sent', color: '#2563EB', icon: 'mark_email_read' },
    in_progress: { label: 'In progress', color: '#EA8C1E', icon: 'autorenew' },
    completed: { label: 'Completed', color: '#16A34A', icon: 'check_circle' },
  };
  const fmtWhen = (iso) => { const d = new Date(iso); return `${K.fmtDateLabel(iso)} · ${String(d.getHours()).padStart(2, '0')}:${String(d.getMinutes()).padStart(2, '0')}`; };

  function StatusPill({ status, pal }) {
    const s = STATUS[status] || STATUS.sent;
    return <span style={{ display: 'inline-flex', alignItems: 'center', gap: 5, fontSize: 10.5, fontWeight: 800, letterSpacing: '.04em', color: '#fff', background: s.color, padding: '3px 8px', borderRadius: 999 }}><Icon name={s.icon} size={13} color="#fff" />{s.label.toUpperCase()}</span>;
  }

  function Toggle({ on, onChange, pal }) {
    return (
      <button type="button" onClick={() => onChange(!on)} style={{ width: 42, height: 24, borderRadius: 999, border: 'none', cursor: 'pointer', background: on ? pal.accent : pal.divider, position: 'relative', flexShrink: 0 }}>
        <span style={{ position: 'absolute', top: 3, left: on ? 21 : 3, width: 18, height: 18, borderRadius: 999, background: '#fff', transition: 'left .15s', boxShadow: '0 1px 2px rgba(0,0,0,.3)' }} />
      </button>
    );
  }

  function TicketComposer({ pal, onSend, placeholder }) {
    const [v, setV] = React.useState('');
    const send = () => { if (v.trim()) { onSend(v.trim()); setV(''); } };
    return (
      <div style={{ display: 'flex', gap: 8, padding: 10, borderTop: `1px solid ${pal.divider}`, background: pal.header, alignItems: 'flex-end' }}>
        <textarea value={v} onChange={(e) => setV(e.target.value)} onKeyDown={(e) => { if (e.key === 'Enter' && !e.shiftKey) { e.preventDefault(); send(); } }} rows={1} placeholder={placeholder || 'Type a reply…'}
          style={{ flex: 1, resize: 'none', boxSizing: 'border-box', padding: '10px 14px', background: pal.body, border: `1.5px solid ${pal.divider}`, borderRadius: 20, fontFamily: 'var(--font-sans)', fontSize: 14, color: pal.bodyText, outline: 'none', maxHeight: 110 }}
          onFocus={(e) => { e.target.style.borderColor = pal.accent; }} onBlur={(e) => { e.target.style.borderColor = pal.divider; }} />
        <button type="button" onClick={send} title="Send" style={{ border: 'none', background: pal.accent, width: 40, height: 40, borderRadius: 999, cursor: 'pointer', display: 'flex', alignItems: 'center', justifyContent: 'center', flexShrink: 0 }}><Icon name="send" size={19} color={pal.accentText} /></button>
      </div>
    );
  }

  /* Ticket list row */
  function TicketRow({ tk, pal, subtitle, onClick }) {
    const last = tk.messages[tk.messages.length - 1];
    return (
      <button type="button" onClick={onClick} style={{ display: 'flex', gap: 12, width: '100%', textAlign: 'left', border: 'none', cursor: 'pointer', padding: '12px 14px', background: 'transparent', borderBottom: `1px solid ${pal.divider}`, alignItems: 'flex-start' }}>
        <div style={{ width: 38, height: 38, borderRadius: 11, background: pal.tabSelectedBg, display: 'flex', alignItems: 'center', justifyContent: 'center', flexShrink: 0 }}><Icon name="confirmation_number" size={20} color={pal.accent} /></div>
        <div style={{ flex: 1, minWidth: 0 }}>
          <div style={{ display: 'flex', alignItems: 'center', gap: 8, marginBottom: 3 }}>
            <span style={{ flex: 1, fontSize: 14, fontWeight: 700, color: pal.bodyText, whiteSpace: 'nowrap', overflow: 'hidden', textOverflow: 'ellipsis' }}>{tk.subject}</span>
            <StatusPill status={tk.status} pal={pal} />
          </div>
          <div style={{ fontSize: 12, color: pal.bodySubtle, whiteSpace: 'nowrap', overflow: 'hidden', textOverflow: 'ellipsis' }}>{subtitle}</div>
          {last && <div style={{ fontSize: 12, color: pal.bodySubtle, marginTop: 2, whiteSpace: 'nowrap', overflow: 'hidden', textOverflow: 'ellipsis', opacity: 0.85 }}>{CD.user(last.from).name.split(' ')[0]}: {last.text}</div>}
        </div>
      </button>
    );
  }

  /* ── Support home (role-aware) ──────────────────────────────────────── */
  function SupportHome({ viewer, pal, isAdmin, onOpenTicket, onNew }) {
    const [, setN] = React.useState(0); const force = () => setN((n) => n + 1);
    if (isAdmin) {
      const inbox = CD.getInbox();
      const tickets = CD.ticketsForAdmin();
      const open = tickets.filter((k) => k.status !== 'completed');
      const done = tickets.filter((k) => k.status === 'completed');
      return (
        <div style={{ overflowY: 'auto', height: '100%' }}>
          <div style={{ padding: 14, borderBottom: `1px solid ${pal.divider}` }}>
            <div style={{ fontSize: 11, fontWeight: 800, letterSpacing: '.1em', color: pal.bodySubtle, marginBottom: 8 }}>WHO RECEIVES TICKETS</div>
            {CD.SUPER_ADMINS.map((a) => (
              <div key={a.id} style={{ display: 'flex', alignItems: 'center', gap: 10, padding: '9px 0' }}>
                <K.ChatAvatar person={a} size={32} pal={pal} />
                <div style={{ flex: 1, minWidth: 0 }}><div style={{ fontSize: 13.5, fontWeight: 600, color: pal.bodyText }}>{a.name}{a.id === viewer ? ' (you)' : ''}</div><div style={{ fontSize: 11.5, color: pal.bodySubtle }}>{inbox[a.id] ? 'Receiving new tickets' : 'Not receiving tickets'}</div></div>
                <Toggle on={!!inbox[a.id]} pal={pal} onChange={(v) => { CD.setInbox(a.id, v); force(); }} />
              </div>
            ))}
            <div style={{ display: 'flex', gap: 8, padding: '9px 11px', marginTop: 4, background: pal.tabSelectedBg, borderRadius: 10 }}><Icon name="info" size={15} color={pal.accent} /><div style={{ fontSize: 11.5, color: pal.bodySubtle, lineHeight: 1.4 }}>Both admins can be assigned. Whoever <b>accepts</b> a ticket becomes its handler and it moves to In progress.</div></div>
          </div>
          <div style={{ padding: '12px 14px 6px', fontSize: 11, fontWeight: 800, letterSpacing: '.1em', color: pal.bodySubtle }}>OPEN · {open.length}</div>
          {open.length ? open.map((k) => <TicketRow key={k.id} tk={k} pal={pal} onClick={() => onOpenTicket(k.id)}
            subtitle={`${CD.user(k.from).name} · ${CD.org(k.org).name} · ${k.category}${k.acceptedByName ? ' · handling: ' + k.acceptedByName : ' · unassigned'}`} />)
            : <div style={{ padding: 20, textAlign: 'center', color: pal.bodySubtle, fontSize: 13 }}>No open tickets.</div>}
          {done.length > 0 && <div style={{ padding: '14px 14px 6px', fontSize: 11, fontWeight: 800, letterSpacing: '.1em', color: pal.bodySubtle }}>COMPLETED · {done.length}</div>}
          {done.map((k) => <TicketRow key={k.id} tk={k} pal={pal} onClick={() => onOpenTicket(k.id)} subtitle={`${CD.user(k.from).name} · ${CD.org(k.org).name} · completed by ${k.acceptedByName || 'admin'}`} />)}
        </div>
      );
    }
    // regular user
    const mine = CD.ticketsForUser(viewer);
    const notifs = CD.notificationsFor(viewer);
    return (
      <div style={{ overflowY: 'auto', height: '100%' }}>
        <div style={{ padding: 14, borderBottom: `1px solid ${pal.divider}` }}>
          <button type="button" onClick={onNew} style={{ display: 'flex', alignItems: 'center', justifyContent: 'center', gap: 8, width: '100%', border: 'none', background: pal.accent, color: pal.accentText, borderRadius: 12, padding: '12px 0', fontSize: 14, fontWeight: 700, cursor: 'pointer', fontFamily: 'var(--font-sans)' }}><Icon name="add" size={18} color={pal.accentText} />Log a support ticket</button>
          <div style={{ fontSize: 12, color: pal.bodySubtle, marginTop: 8, textAlign: 'center' }}>Questions, queries, problems or bugs — sent to the Mine-Link team.</div>
        </div>
        {notifs.length > 0 && (
          <div style={{ padding: '12px 14px 4px' }}>
            <div style={{ fontSize: 11, fontWeight: 800, letterSpacing: '.1em', color: pal.bodySubtle, marginBottom: 8 }}>UPDATES</div>
            {notifs.slice(0, 5).map((n) => (
              <button key={n.id} type="button" onClick={() => onOpenTicket(n.ticketId)} style={{ display: 'flex', gap: 10, width: '100%', textAlign: 'left', border: 'none', cursor: 'pointer', background: n.read ? 'transparent' : pal.tabSelectedBg, borderRadius: 10, padding: '9px 10px', marginBottom: 4, alignItems: 'flex-start' }}>
                <Icon name="notifications" size={16} color={n.read ? pal.bodySubtle : pal.accent} fill={n.read ? 0 : 1} />
                <div style={{ flex: 1, minWidth: 0 }}><div style={{ fontSize: 12.5, color: pal.bodyText, lineHeight: 1.4 }}>{n.text}</div><div style={{ fontSize: 11, color: pal.bodySubtle, marginTop: 2, fontFamily: 'var(--font-mono)' }}>{fmtWhen(n.at)}</div></div>
              </button>
            ))}
          </div>
        )}
        <div style={{ padding: '12px 14px 6px', fontSize: 11, fontWeight: 800, letterSpacing: '.1em', color: pal.bodySubtle }}>MY TICKETS · {mine.length}</div>
        {mine.length ? mine.map((k) => <TicketRow key={k.id} tk={k} pal={pal} onClick={() => onOpenTicket(k.id)}
          subtitle={`${k.category}${k.acceptedByName ? ' · handled by ' + k.acceptedByName : ' · awaiting a team member'}`} />)
          : <div style={{ padding: 24, textAlign: 'center', color: pal.bodySubtle, fontSize: 13 }}>No tickets yet.</div>}
      </div>
    );
  }

  /* ── New ticket form ────────────────────────────────────────────────── */
  function NewTicketForm({ viewer, pal, onBack, onCreated }) {
    const [subject, setSubject] = React.useState('');
    const [cat, setCat] = React.useState(CD.SUPPORT_CATEGORIES[0]);
    const [body, setBody] = React.useState('');
    const inp = { boxSizing: 'border-box', width: '100%', padding: '11px 13px', background: pal.body, color: pal.bodyText, border: `1.5px solid ${pal.divider}`, borderRadius: 10, fontSize: 14, fontFamily: 'var(--font-sans)', outline: 'none' };
    return (
      <div style={{ display: 'flex', flexDirection: 'column', height: '100%', background: pal.body }}>
        <div style={{ display: 'flex', alignItems: 'center', gap: 6, padding: '8px 10px', background: pal.header, borderBottom: `1px solid ${pal.divider}` }}>
          <button type="button" onClick={onBack} style={{ border: 'none', background: 'transparent', cursor: 'pointer', display: 'flex', padding: 6 }}><Icon name="arrow_back" size={20} color={pal.headerText} /></button>
          <Icon name="confirmation_number" size={18} color={pal.accent} />
          <span style={{ fontSize: 14, fontWeight: 700, color: pal.headerText }}>New support ticket</span>
        </div>
        <div style={{ flex: 1, overflowY: 'auto', padding: 16, display: 'flex', flexDirection: 'column', gap: 14 }}>
          <label style={{ display: 'flex', flexDirection: 'column', gap: 6 }}><span style={{ fontSize: 12.5, fontWeight: 600, color: pal.bodyText }}>Subject</span><input value={subject} onChange={(e) => setSubject(e.target.value)} placeholder="Short summary of your question or issue" style={inp} /></label>
          <label style={{ display: 'flex', flexDirection: 'column', gap: 6 }}><span style={{ fontSize: 12.5, fontWeight: 600, color: pal.bodyText }}>Category</span>
            <select value={cat} onChange={(e) => setCat(e.target.value)} style={{ ...inp, appearance: 'none', WebkitAppearance: 'none', cursor: 'pointer' }}>{CD.SUPPORT_CATEGORIES.map((c) => <option key={c} value={c}>{c}</option>)}</select></label>
          <label style={{ display: 'flex', flexDirection: 'column', gap: 6 }}><span style={{ fontSize: 12.5, fontWeight: 600, color: pal.bodyText }}>Describe it</span><textarea value={body} onChange={(e) => setBody(e.target.value)} rows={5} placeholder="What happened, what you expected, and any steps to reproduce." style={{ ...inp, resize: 'vertical', minHeight: 110 }} /></label>
          <div style={{ display: 'flex', gap: 8, alignItems: 'flex-start', fontSize: 12, color: pal.bodySubtle }}><Icon name="info" size={15} color={pal.accent} /><span>Your ticket goes to the Mine-Link support team. You'll get a notification here at every stage.</span></div>
          <button type="button" disabled={!subject.trim() || !body.trim()} onClick={() => onCreated(CD.createTicket(viewer, subject.trim(), cat, body.trim()).id)} style={{ border: 'none', background: pal.accent, color: pal.accentText, borderRadius: 12, padding: '12px 0', fontSize: 14, fontWeight: 700, cursor: subject.trim() && body.trim() ? 'pointer' : 'not-allowed', opacity: subject.trim() && body.trim() ? 1 : 0.5, fontFamily: 'var(--font-sans)', display: 'inline-flex', gap: 7, alignItems: 'center', justifyContent: 'center' }}><Icon name="send" size={17} color={pal.accentText} />Send ticket</button>
        </div>
      </div>
    );
  }

  /* ── Ticket view (role-aware) ───────────────────────────────────────── */
  function TicketView({ viewer, ticketId, pal, isAdmin, onBack }) {
    const [, setN] = React.useState(0); const force = () => setN((n) => n + 1);
    const scrollRef = React.useRef(null);
    const tk = CD.ticketById(ticketId);
    React.useEffect(() => { CD.markNotifsRead(viewer, ticketId); }, [ticketId]);
    React.useEffect(() => { if (scrollRef.current) scrollRef.current.scrollTop = scrollRef.current.scrollHeight; }, [tk && tk.messages.length, tk && tk.status]);
    if (!tk) return null;
    const eventLabel = (e) => e.type === 'sent' ? 'Ticket sent' : e.type === 'accepted' ? `Accepted by ${e.actorName}` : e.type === 'in_progress' ? 'In progress' : `Completed by ${e.actorName}`;
    const eventIcon = (e) => e.type === 'sent' ? 'mark_email_read' : e.type === 'accepted' ? 'how_to_reg' : e.type === 'in_progress' ? 'autorenew' : 'check_circle';
    const send = (text) => { CD.addTicketMessage(ticketId, viewer, text); force(); };
    const accept = () => { CD.acceptTicket(ticketId, viewer); force(); };
    const complete = () => { CD.completeTicket(ticketId, viewer); force(); };

    return (
      <div style={{ display: 'flex', flexDirection: 'column', height: '100%', background: pal.body }}>
        <div style={{ display: 'flex', alignItems: 'flex-start', gap: 8, padding: '8px 10px', background: pal.header, borderBottom: `1px solid ${pal.divider}` }}>
          <button type="button" onClick={onBack} style={{ border: 'none', background: 'transparent', cursor: 'pointer', display: 'flex', padding: 6 }}><Icon name="arrow_back" size={20} color={pal.headerText} /></button>
          <div style={{ flex: 1, minWidth: 0, paddingTop: 4 }}>
            <div style={{ fontSize: 14, fontWeight: 800, color: pal.headerText, whiteSpace: 'nowrap', overflow: 'hidden', textOverflow: 'ellipsis' }}>{tk.subject}</div>
            <div style={{ fontSize: 11.5, color: pal.bodySubtle }}>{tk.category} · {CD.user(tk.from).name} · {CD.org(tk.org).name}</div>
          </div>
          <div style={{ paddingTop: 4 }}><StatusPill status={tk.status} pal={pal} /></div>
        </div>

        <div ref={scrollRef} style={{ flex: 1, overflowY: 'auto', padding: '12px 14px' }}>
          {/* Timeline */}
          <div style={{ border: `1px solid ${pal.divider}`, borderRadius: 12, padding: 12, marginBottom: 14 }}>
            <div style={{ fontSize: 11, fontWeight: 800, letterSpacing: '.1em', color: pal.bodySubtle, marginBottom: 10 }}>PROGRESS</div>
            {tk.events.map((e, i) => (
              <div key={i} style={{ display: 'flex', gap: 10, alignItems: 'flex-start', paddingBottom: i < tk.events.length - 1 ? 12 : 0, position: 'relative' }}>
                {i < tk.events.length - 1 && <span style={{ position: 'absolute', left: 11, top: 22, bottom: 0, width: 2, background: pal.divider }} />}
                <div style={{ width: 24, height: 24, borderRadius: 999, background: (STATUS[e.type] || STATUS.sent).color, display: 'flex', alignItems: 'center', justifyContent: 'center', flexShrink: 0, zIndex: 1 }}><Icon name={eventIcon(e)} size={14} color="#fff" /></div>
                <div style={{ flex: 1, paddingTop: 2 }}><div style={{ fontSize: 13, fontWeight: 700, color: pal.bodyText }}>{eventLabel(e)}</div><div style={{ fontSize: 11, color: pal.bodySubtle, fontFamily: 'var(--font-mono)' }}>{fmtWhen(e.at)}</div></div>
              </div>
            ))}
          </div>

          {/* Handling banner */}
          {tk.status === 'in_progress' && (
            <div style={{ display: 'flex', gap: 8, padding: '9px 11px', marginBottom: 12, background: pal.tabSelectedBg, borderRadius: 10, alignItems: 'center' }}><Icon name="support_agent" size={16} color={pal.accent} /><div style={{ fontSize: 12.5, color: pal.bodyText }}><b>{tk.acceptedByName}</b> is handling this ticket.</div></div>
          )}

          {/* Conversation */}
          <div style={{ fontSize: 11, fontWeight: 800, letterSpacing: '.1em', color: pal.bodySubtle, margin: '4px 0 8px' }}>CONVERSATION</div>
          {tk.messages.map((m) => {
            const mine = m.from === viewer;
            const sender = CD.user(m.from);
            return <K.MessageBubble key={m.id} msg={m} mine={mine} showName={!mine} senderName={sender.org === 'minelink' ? `${sender.name} · Mine-Link` : sender.name} pal={pal} />;
          })}
          {tk.status === 'completed' && (
            <div style={{ textAlign: 'center', margin: '14px 0' }}><span style={{ display: 'inline-flex', alignItems: 'center', gap: 6, fontSize: 12, color: '#16A34A', background: pal.tabSelectedBg, padding: '6px 12px', borderRadius: 999 }}><Icon name="check_circle" size={14} color="#16A34A" fill={1} />Ticket completed{tk.acceptedByName ? ' by ' + tk.acceptedByName : ''}</span></div>
          )}
        </div>

        {/* Admin actions */}
        {isAdmin && tk.status === 'sent' && (
          <div style={{ padding: 12, borderTop: `1px solid ${pal.divider}`, background: pal.header }}>
            <button type="button" onClick={accept} style={{ width: '100%', border: 'none', background: pal.accent, color: pal.accentText, borderRadius: 12, padding: '12px 0', fontSize: 14, fontWeight: 700, cursor: 'pointer', fontFamily: 'var(--font-sans)', display: 'inline-flex', gap: 7, alignItems: 'center', justifyContent: 'center' }}><Icon name="how_to_reg" size={18} color={pal.accentText} />Accept ticket</button>
          </div>
        )}
        {tk.status === 'in_progress' && (<>
          <TicketComposer pal={pal} onSend={send} placeholder={isAdmin ? 'Ask the user a question…' : 'Reply to the support team…'} />
          {isAdmin && (
            <div style={{ padding: '0 12px 12px', background: pal.header }}>
              <button type="button" onClick={complete} style={{ width: '100%', border: `1.5px solid #16A34A`, background: 'transparent', color: '#16A34A', borderRadius: 12, padding: '10px 0', fontSize: 13.5, fontWeight: 700, cursor: 'pointer', fontFamily: 'var(--font-sans)', display: 'inline-flex', gap: 7, alignItems: 'center', justifyContent: 'center' }}><Icon name="check_circle" size={17} color="#16A34A" />Mark as completed</button>
            </div>
          )}
        </>)}
      </div>
    );
  }

  window.ChatSupport = { SupportHome, NewTicketForm, TicketView, STATUS };
})();
