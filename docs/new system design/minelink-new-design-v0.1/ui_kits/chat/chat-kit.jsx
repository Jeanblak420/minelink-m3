/* MineLink Chat — palette-aware UI components. Composes DS Icon; every surface
 * reads the active ChatPalette (pal) so themes actually re-skin. Adds reply
 * quotes, @mention highlighting, delivered/read receipts, emoji picker, file
 * attach + the full composer (+ menu, emoji, mention info, send). Preserves the
 * MineLink company-scoping visuals (group headers, blocked banner).
 * Exposes window.ChatKit. Load after data.js + the DS bundle. */
const DSc = window.MineLinkDesignSystem_9acfde;
const { Icon: IconC } = DSc;
const CD = window.ChatData;

const PRESENCE = { online: '#16a34a', away: '#f59e0b', offline: '#94a3b8' };
const TONE_FG = { cyan: 'var(--accent)', amber: 'var(--ml-orange-600)', green: 'var(--ml-green-600)' };
const TONE_BG = { cyan: 'var(--ml-well-cyan)', amber: 'var(--ml-well-amber)', green: 'var(--ml-well-green)' };
const EMOJIS = ['😀','😄','😁','😉','😊','😍','😘','😎','🤔','😅','😂','🙂','😴','😮','😢','😡','👍','👎','👏','🙏','💪','🔥','✅','❌','⚠️','📍','📦','🚚','⛏️','⚖️','💰','📄','📊','⏱️','🎯','🤝','💬','⭐','❤️','🎉'];

function fmtTime(iso) {
  const d = new Date(iso); return `${String(d.getHours()).padStart(2, '0')}:${String(d.getMinutes()).padStart(2, '0')}`;
}
function fmtDateLabel(iso) {
  const d = new Date(iso), now = new Date();
  const day = (x) => new Date(x.getFullYear(), x.getMonth(), x.getDate());
  const diff = Math.round((day(now) - day(d)) / 86400000);
  if (diff === 0) return 'Today'; if (diff === 1) return 'Yesterday';
  return d.toLocaleDateString(undefined, { weekday: 'short', day: 'numeric', month: 'short' });
}

/* Palette-aware avatar with presence dot */
function ChatAvatar({ person, size = 42, pal, ring }) {
  const initials = (person.name || '?').split(/\s+/).filter(Boolean).slice(0, 2).map((w) => w[0].toUpperCase()).join('');
  return (
    <div style={{ position: 'relative', flexShrink: 0 }}>
      <div style={{ width: size, height: size, borderRadius: 999, background: `linear-gradient(150deg, ${pal.accent}, ${pal.senderName})`, color: pal.accentText, display: 'flex', alignItems: 'center', justifyContent: 'center', fontWeight: 800, fontSize: size * 0.38, border: ring ? `2px solid ${pal.accent}` : 'none', fontFamily: 'var(--font-sans)' }}>{initials}</div>
      {person.presence && (
        <span style={{ position: 'absolute', right: -1, bottom: -1, width: size * 0.28, height: size * 0.28, minWidth: 10, minHeight: 10, borderRadius: 999, background: PRESENCE[person.presence], border: `2.5px solid ${pal.body}` }} />
      )}
    </div>
  );
}

function presenceText(p) {
  if (p.presence === 'online') return 'Online';
  if (p.presence === 'away') return 'Away';
  return p.lastSeen ? `Last seen ${p.lastSeen}` : 'Offline';
}

function renderText(text, mentions, pal) {
  if (!/@/.test(text)) return text;
  const parts = text.split(/(@[A-Za-z][A-Za-z ]*?)(?=[.,!?]|$| [a-z])/g);
  return parts.map((p, i) => p.startsWith('@')
    ? <span key={i} style={{ color: pal.senderName, fontWeight: 700 }}>{p}</span>
    : <React.Fragment key={i}>{p}</React.Fragment>);
}

/* Message bubble — palette-driven, reply quote, timestamp, receipts, hover-reply */
function MessageBubble({ msg, mine, showName, senderName, reply, pal, onReply, attachment }) {
  const [hover, setHover] = React.useState(false);
  return (
    <div onMouseEnter={() => setHover(true)} onMouseLeave={() => setHover(false)}
      style={{ display: 'flex', justifyContent: mine ? 'flex-end' : 'flex-start', padding: '2px 0', gap: 6, alignItems: 'center', flexDirection: mine ? 'row' : 'row-reverse' }}>
      {onReply && (
        <button type="button" onClick={() => onReply(msg)} title="Reply" style={{ opacity: hover ? 1 : 0, transition: 'opacity .12s', border: 'none', background: 'transparent', cursor: 'pointer', display: 'flex', color: pal.bodySubtle, padding: 4 }}><IconC name="reply" size={17} color={pal.bodySubtle} /></button>
      )}
      <div style={{ maxWidth: '76%', display: 'flex', flexDirection: 'column', alignItems: mine ? 'flex-end' : 'flex-start' }}>
        <div style={{
          background: mine ? pal.outgoingBubble : pal.incomingBubble, color: mine ? pal.outgoingText : pal.incomingText,
          borderRadius: mine ? '16px 16px 4px 16px' : '16px 16px 16px 4px', padding: '9px 13px', boxShadow: '0 1px 2px rgba(0,0,0,.10)',
        }}>
          {showName && !mine && (
            <div style={{ fontSize: 12.5, fontWeight: 800, color: pal.senderName, marginBottom: 4, paddingBottom: 4, borderBottom: `1px solid ${pal.bubbleSeparator}` }}>{senderName}</div>
          )}
          {reply && (
            <div style={{ borderLeft: `3px solid ${mine ? 'rgba(255,255,255,.6)' : pal.accent}`, background: mine ? 'rgba(255,255,255,.14)' : pal.body, borderRadius: 6, padding: '5px 9px', marginBottom: 6, fontSize: 12.5 }}>
              <div style={{ fontWeight: 700, opacity: 0.9 }}>{reply.name}</div>
              <div style={{ opacity: 0.8, whiteSpace: 'nowrap', overflow: 'hidden', textOverflow: 'ellipsis', maxWidth: 220 }}>{reply.text}</div>
            </div>
          )}
          {attachment && (
            <div style={{ display: 'flex', alignItems: 'center', gap: 8, padding: '7px 9px', marginBottom: 6, borderRadius: 8, background: mine ? 'rgba(255,255,255,.16)' : pal.body }}>
              <IconC name="description" size={18} color={mine ? pal.outgoingText : pal.accent} />
              <span style={{ fontSize: 12.5, fontWeight: 600, maxWidth: 180, whiteSpace: 'nowrap', overflow: 'hidden', textOverflow: 'ellipsis' }}>{attachment}</span>
            </div>
          )}
          {msg.text && <div style={{ fontSize: 14.5, lineHeight: 1.45, wordBreak: 'break-word' }}>{renderText(msg.text, msg.mentions, pal)}</div>}
          <div style={{ display: 'flex', alignItems: 'center', gap: 4, justifyContent: 'flex-end', marginTop: 3 }}>
            <span style={{ fontSize: 10.5, color: mine ? pal.outgoingText : pal.incomingText, opacity: 0.65, fontFamily: 'var(--font-mono)' }}>{fmtTime(msg.at)}</span>
            {mine && <IconC name={msg.status === 'read' || msg.status === 'delivered' ? 'done_all' : 'done'} size={15} color={msg.status === 'read' ? '#7fd4ff' : pal.outgoingText} />}
          </div>
        </div>
      </div>
    </div>
  );
}

function DateSeparator({ label, pal }) {
  return (
    <div style={{ display: 'flex', alignItems: 'center', gap: 12, margin: '14px 0' }}>
      <span style={{ flex: 1, height: 1, background: pal.divider }} />
      <span style={{ fontSize: 11.5, color: pal.bodySubtle, fontWeight: 600 }}>{label}</span>
      <span style={{ flex: 1, height: 1, background: pal.divider }} />
    </div>
  );
}

/* Conversation list row */
function ConversationRow({ person, subtitle, last, unread, active, onClick, groupBadge, pal, typing }) {
  return (
    <button type="button" onClick={onClick} style={{
      display: 'flex', alignItems: 'center', gap: 12, width: '100%', textAlign: 'left', border: 'none', cursor: 'pointer',
      padding: '11px 14px', background: active ? pal.tabSelectedBg : 'transparent', borderLeft: `3px solid ${active ? pal.accent : 'transparent'}`,
    }}>
      <ChatAvatar person={person} size={44} pal={pal} ring={active} />
      <div style={{ flex: 1, minWidth: 0 }}>
        <div style={{ display: 'flex', alignItems: 'center', gap: 6 }}>
          <span style={{ fontSize: 14.5, fontWeight: 700, color: pal.bodyText, whiteSpace: 'nowrap', overflow: 'hidden', textOverflow: 'ellipsis' }}>{person.name}</span>
          {groupBadge}
        </div>
        <div style={{ fontSize: 13, color: typing ? pal.accent : pal.bodySubtle, fontStyle: typing ? 'italic' : 'normal', fontWeight: typing ? 700 : 400, whiteSpace: 'nowrap', overflow: 'hidden', textOverflow: 'ellipsis' }}>{typing ? 'typing…' : (last || subtitle)}</div>
      </div>
      {unread ? <span style={{ background: pal.unreadBadge, color: pal.unreadBadgeText, fontSize: 11, fontWeight: 800, borderRadius: 999, minWidth: 20, height: 20, display: 'flex', alignItems: 'center', justifyContent: 'center', padding: '0 6px' }}>{unread}</span> : null}
    </button>
  );
}

/* Contact group header (MineLink company-scoping visual) */
function GroupHeader({ group, count, pal }) {
  const isConn = group.kind === 'connected';
  const isAdmin = group.kind === 'admin';
  const o = group.org;
  const otype = (o && o.type) ? o.type.toUpperCase() : '';
  const label = group.kind === 'internal' ? 'MY COMPANY' : group.kind === 'admin' ? 'MINE-LINK' : group.kind === 'org' ? ('ORGANIZATION · ' + otype) : ('CONNECTED · ' + otype);
  return (
    <div style={{ display: 'flex', alignItems: 'center', gap: 9, padding: '14px 14px 7px' }}>
      <div style={{ width: 24, height: 24, borderRadius: 7, background: pal.tabSelectedBg, display: 'flex', alignItems: 'center', justifyContent: 'center' }}>
        <IconC name={o.icon} size={15} color={pal.accent} fill={isAdmin ? 1 : 0} />
      </div>
      <div style={{ flex: 1, minWidth: 0 }}>
        <div style={{ fontSize: 10.5, fontWeight: 800, letterSpacing: '.08em', color: pal.bodySubtle }}>{label}</div>
        <div style={{ fontSize: 13.5, fontWeight: 700, color: pal.bodyText, whiteSpace: 'nowrap', overflow: 'hidden', textOverflow: 'ellipsis' }}>{group.label}</div>
      </div>
      {isConn && group.status === 'revoked'
        ? <span style={{ ...pill, color: '#fff', background: '#e0842b' }}>BLOCKED</span>
        : isConn ? <span style={{ ...pill, color: pal.accentText, background: pal.accent }}>CONNECTED</span>
        : <span style={{ fontSize: 12, color: pal.bodySubtle, fontFamily: 'var(--font-mono)' }}>{count}</span>}
    </div>
  );
}
const pill = { fontSize: 9.5, fontWeight: 800, letterSpacing: '.06em', padding: '3px 7px', borderRadius: 999 };

function ContactRow({ person, onClick, blocked, pal, onProfile }) {
  return (
    <div style={{ display: 'flex', alignItems: 'center', gap: 4, padding: '2px 8px 2px 16px', opacity: blocked ? 0.6 : 1 }}>
      <button type="button" onClick={onClick} style={{ display: 'flex', alignItems: 'center', gap: 12, flex: 1, minWidth: 0, textAlign: 'left', border: 'none', cursor: 'pointer', padding: '7px 0', background: 'transparent' }}>
        <ChatAvatar person={person} size={38} pal={pal} />
        <div style={{ flex: 1, minWidth: 0 }}>
          <div style={{ fontSize: 14, fontWeight: 600, color: pal.bodyText }}>{person.name}</div>
          <div style={{ fontSize: 12.5, color: pal.bodySubtle }}>{person.role} · {presenceText(person)}</div>
        </div>
      </button>
      {blocked ? <IconC name="block" size={16} color="#e0842b" />
        : <button type="button" onClick={onProfile} title="View profile" style={{ border: 'none', background: 'transparent', cursor: 'pointer', display: 'flex', padding: 6 }}><IconC name="info" size={17} color={pal.bodySubtle} /></button>}
    </div>
  );
}

/* Emoji picker popover */
function EmojiPicker({ onPick, pal }) {
  return (
    <div style={{ display: 'grid', gridTemplateColumns: 'repeat(8, 1fr)', gap: 2, padding: 10, maxHeight: 168, overflowY: 'auto', background: pal.body, borderTop: `1px solid ${pal.divider}` }}>
      {EMOJIS.map((e) => (
        <button key={e} type="button" onClick={() => onPick(e)} style={{ border: 'none', background: 'transparent', cursor: 'pointer', fontSize: 20, padding: 5, borderRadius: 8, lineHeight: 1 }}
          onMouseEnter={(ev) => { ev.currentTarget.style.background = pal.tabSelectedBg; }} onMouseLeave={(ev) => { ev.currentTarget.style.background = 'transparent'; }}>{e}</button>
      ))}
    </div>
  );
}

/* Full composer: reply bar, + menu, emoji, mention info, textarea, send.
 * Enter = send, Shift+Enter = newline. */
function Composer({ disabled, onSend, placeholder, pal, replyTo, onCancelReply, onTyping, contacts }) {
  const [val, setVal] = React.useState('');
  const [emoji, setEmoji] = React.useState(false);
  const [addMenu, setAddMenu] = React.useState(false);
  const [info, setInfo] = React.useState(false);
  const [file, setFile] = React.useState(null);
  const [mentionQ, setMentionQ] = React.useState(null);
  const taRef = React.useRef(null);
  if (disabled) return null;

  const insertAt = (txt) => { setVal((v) => v + (v && !v.endsWith(' ') ? ' ' : '') + txt); taRef.current && taRef.current.focus(); };
  const send = () => { if (val.trim() || file) { onSend(val.trim(), { reply: replyTo, file }); setVal(''); setFile(null); setEmoji(false); onCancelReply && onCancelReply(); } };
  const onChange = (e) => {
    const t = e.target.value; setVal(t); onTyping && t.trim() && onTyping();
    const m = t.slice(0, e.target.selectionStart).match(/(?:^|\s)@([A-Za-z]*)$/);
    setMentionQ(m ? m[1].toLowerCase() : null);
  };
  const pickMention = (person) => { setVal((v) => v.replace(/(?:^|\s)@([A-Za-z]*)$/, (m) => (m.startsWith(' ') ? ' ' : '') + '@' + person.name.split(' ')[0] + ' ')); setMentionQ(null); taRef.current && taRef.current.focus(); };
  const mentionMatches = mentionQ != null ? (contacts || []).filter((p) => p.name.toLowerCase().includes(mentionQ)).slice(0, 5) : [];

  return (
    <div style={{ borderTop: `1px solid ${pal.divider}`, background: pal.header }}>
      {mentionQ != null && mentionMatches.length > 0 && (
        <div style={{ background: pal.body, borderBottom: `1px solid ${pal.divider}`, maxHeight: 168, overflowY: 'auto' }}>
          {mentionMatches.map((p) => (
            <button key={p.id} type="button" onClick={() => pickMention(p)} style={{ display: 'flex', alignItems: 'center', gap: 10, width: '100%', border: 'none', background: 'transparent', cursor: 'pointer', padding: '8px 12px', textAlign: 'left' }}>
              <ChatAvatar person={p} size={28} pal={pal} />
              <span style={{ fontSize: 13.5, fontWeight: 600, color: pal.bodyText }}>{p.name}</span>
              <span style={{ fontSize: 12, color: pal.bodySubtle }}>{p.role}</span>
            </button>
          ))}
        </div>
      )}
      {info && (
        <div style={{ padding: '10px 14px', background: pal.body, borderBottom: `1px solid ${pal.divider}`, fontSize: 12.5, color: pal.bodySubtle, lineHeight: 1.5 }}>
          <b style={{ color: pal.accent }}>Tips:</b> Type <b>@</b> to mention a teammate · <b>Enter</b> sends · <b>Shift+Enter</b> adds a line · attach files with the <b>+</b> button.
        </div>
      )}
      {replyTo && (
        <div style={{ display: 'flex', alignItems: 'center', gap: 10, padding: '8px 14px', background: pal.body, borderBottom: `1px solid ${pal.divider}` }}>
          <IconC name="reply" size={16} color={pal.accent} />
          <div style={{ flex: 1, minWidth: 0, borderLeft: `3px solid ${pal.accent}`, paddingLeft: 8 }}>
            <div style={{ fontSize: 12, fontWeight: 700, color: pal.accent }}>Replying to {replyTo.name}</div>
            <div style={{ fontSize: 12.5, color: pal.bodySubtle, whiteSpace: 'nowrap', overflow: 'hidden', textOverflow: 'ellipsis' }}>{replyTo.text}</div>
          </div>
          <button type="button" onClick={onCancelReply} style={{ border: 'none', background: 'transparent', cursor: 'pointer', display: 'flex' }}><IconC name="close" size={17} color={pal.bodySubtle} /></button>
        </div>
      )}
      {file && (
        <div style={{ display: 'flex', alignItems: 'center', gap: 10, padding: '8px 14px', background: pal.body, borderBottom: `1px solid ${pal.divider}` }}>
          <IconC name="description" size={18} color={pal.accent} />
          <span style={{ flex: 1, fontSize: 13, fontWeight: 600, color: pal.bodyText, whiteSpace: 'nowrap', overflow: 'hidden', textOverflow: 'ellipsis' }}>{file}</span>
          <button type="button" onClick={() => setFile(null)} style={{ border: 'none', background: 'transparent', cursor: 'pointer', display: 'flex' }}><IconC name="close" size={17} color={pal.bodySubtle} /></button>
        </div>
      )}
      {addMenu && (
        <div style={{ display: 'flex', background: pal.body, borderBottom: `1px solid ${pal.divider}` }}>
          <button type="button" onClick={() => { setFile('mine-report-Q3.pdf'); setAddMenu(false); }} style={addBtn(pal)}><IconC name="attach_file" size={18} color={pal.accent} />Attach file</button>
          <span style={{ width: 1, background: pal.divider }} />
          <button type="button" onClick={() => { insertAt('@'); setAddMenu(false); }} style={addBtn(pal)}><IconC name="alternate_email" size={18} color={pal.accent} />Mention</button>
        </div>
      )}
      <div style={{ display: 'flex', alignItems: 'flex-end', gap: 6, padding: 10 }}>
        <button type="button" onClick={() => { setEmoji((e) => !e); setAddMenu(false); }} title="Emoji" style={iconBtn}><IconC name={emoji ? 'keyboard' : 'mood'} size={22} color={pal.accent} /></button>
        <button type="button" onClick={() => { setAddMenu((a) => !a); setEmoji(false); }} title="Attach / mention" style={iconBtn}><IconC name={addMenu ? 'close' : 'add_circle'} size={22} color={pal.accent} /></button>
        <textarea ref={taRef} value={val} onChange={onChange} onKeyDown={(e) => { if (e.key === 'Enter' && !e.shiftKey) { e.preventDefault(); send(); } }} placeholder={placeholder || 'Type a message…  @ to mention'} rows={1}
          style={{ flex: 1, resize: 'none', boxSizing: 'border-box', padding: '10px 14px', background: pal.body, border: `1.5px solid ${pal.divider}`, borderRadius: 20, fontFamily: 'var(--font-sans)', fontSize: 14.5, color: pal.bodyText, outline: 'none', maxHeight: 120 }}
          onFocus={(e) => { e.target.style.borderColor = pal.accent; }} onBlur={(e) => { e.target.style.borderColor = pal.divider; }} />
        <button type="button" onClick={() => { setInfo((i) => !i); }} title="Tips" style={iconBtn}><IconC name="info" size={20} color={info ? pal.accent : pal.bodySubtle} /></button>
        <button type="button" onClick={send} title="Send (Enter)" style={{ border: 'none', background: pal.accent, width: 42, height: 42, borderRadius: 999, cursor: 'pointer', display: 'flex', alignItems: 'center', justifyContent: 'center', flexShrink: 0 }}><IconC name="send" size={20} color={pal.accentText} /></button>
      </div>
      {emoji && <EmojiPicker pal={pal} onPick={(e) => insertAt(e)} />}
    </div>
  );
}
const iconBtn = { border: 'none', background: 'transparent', cursor: 'pointer', display: 'flex', alignItems: 'center', justifyContent: 'center', width: 38, height: 38, borderRadius: 999, flexShrink: 0 };
const addBtn = (pal) => ({ flex: 1, border: 'none', background: 'transparent', cursor: 'pointer', display: 'flex', alignItems: 'center', justifyContent: 'center', gap: 8, padding: '11px 0', fontFamily: 'var(--font-sans)', fontSize: 13.5, fontWeight: 600, color: pal.accent });

/* Revoked / blocked banner (MineLink rule) */
function BlockedBanner({ orgName, onRequest, pal }) {
  return (
    <div style={{ padding: 14, borderTop: `1px solid ${pal.divider}`, background: pal.mode === 'dark' ? 'rgba(224,132,43,.12)' : '#fff4e6' }}>
      <div style={{ display: 'flex', gap: 10, alignItems: 'flex-start' }}>
        <IconC name="lock" size={19} color="#e0842b" />
        <div style={{ flex: 1 }}>
          <div style={{ fontSize: 13.5, color: pal.bodyText, lineHeight: 1.5 }}>
            You can no longer send or receive messages with <b>{orgName}</b>. Contact <b>Mine-Link</b> to request permission to chat with {orgName} again.
          </div>
          <button type="button" onClick={onRequest} style={{ marginTop: 10, display: 'inline-flex', alignItems: 'center', gap: 7, border: 'none', background: pal.accent, color: pal.accentText, fontFamily: 'var(--font-sans)', fontSize: 13, fontWeight: 700, padding: '8px 14px', borderRadius: 10, cursor: 'pointer' }}>
            <IconC name="forum" size={16} color={pal.accentText} />Message Mine-Link
          </button>
        </div>
      </div>
    </div>
  );
}

window.ChatKit = { ChatAvatar, MessageBubble, DateSeparator, ConversationRow, GroupHeader, ContactRow, Composer, EmojiPicker, BlockedBanner, presenceText, fmtTime, fmtDateLabel, PRESENCE, TONE_FG, TONE_BG };
