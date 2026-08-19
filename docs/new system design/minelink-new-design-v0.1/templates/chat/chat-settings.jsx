/* MineLink Chat — Messages Settings panel. Renders inside the overlay (replaces
 * the home view). Theme grid + live preview + chat-icon cursor toggle + message
 * sounds (default + per-contact). Mirrors CPS chat_settings_panel.
 * Exposes window.ChatSettings. */
(function () {
  const { Icon } = window.MineLinkDesignSystem_9acfde;
  const T = window.ChatThemes, S = window.ChatSound;

  function Section({ children, pal }) {
    return <div style={{ fontSize: 11, fontWeight: 800, letterSpacing: '.12em', color: pal.accent, margin: '4px 0 8px' }}>{children}</div>;
  }

  function ThemeTile({ p, selected, onTap }) {
    return (
      <button type="button" onClick={onTap} style={{ border: `${selected ? 2 : 1}px solid ${selected ? p.accent : p.divider}`, borderRadius: 12, overflow: 'hidden', cursor: 'pointer', padding: 0, background: p.body, boxShadow: selected ? `0 0 0 3px ${p.accent}44` : 'none', textAlign: 'left' }}>
        <div style={{ height: 60, background: p.body, padding: 8, display: 'flex', flexDirection: 'column', justifyContent: 'space-between' }}>
          <span style={{ alignSelf: 'flex-start', background: p.incomingBubble, color: p.incomingText, fontSize: 10, fontWeight: 700, padding: '3px 6px', borderRadius: 6 }}>Aa</span>
          <span style={{ alignSelf: 'flex-end', background: p.outgoingBubble, color: p.outgoingText, fontSize: 10, fontWeight: 700, padding: '3px 6px', borderRadius: 6 }}>Aa</span>
        </div>
        <div style={{ background: p.header, padding: '6px 8px', display: 'flex', alignItems: 'center', gap: 4 }}>
          <span style={{ flex: 1, color: p.headerText, fontSize: 11.5, fontWeight: 700, whiteSpace: 'nowrap', overflow: 'hidden', textOverflow: 'ellipsis' }}>{p.name}</span>
          {selected && <Icon name="check_circle" size={15} color={p.accent} fill={1} />}
        </div>
      </button>
    );
  }

  function BubblePreview({ pal }) {
    return (
      <div style={{ padding: 12, borderRadius: 12, border: `1px solid ${pal.divider}`, background: pal.body }}>
        <div style={{ background: pal.incomingBubble, color: pal.incomingText, borderRadius: '16px 16px 16px 4px', padding: '10px 13px', maxWidth: '80%', marginBottom: 8 }}>
          <div style={{ color: pal.senderName, fontWeight: 800, fontSize: 12.5, borderBottom: `1px solid ${pal.bubbleSeparator}`, paddingBottom: 4, marginBottom: 6 }}>Johan Steyn</div>
          <div style={{ fontSize: 14 }}>Trucks are loaded and ready to roll.</div>
          <div style={{ fontSize: 10.5, opacity: 0.6, marginTop: 3, fontFamily: 'var(--font-mono)' }}>09:19</div>
        </div>
        <div style={{ background: pal.outgoingBubble, color: pal.outgoingText, borderRadius: '16px 16px 4px 16px', padding: '10px 13px', maxWidth: '80%', marginLeft: 'auto' }}>
          <div style={{ fontSize: 14 }}>Great — sending waybills now.</div>
          <div style={{ fontSize: 10.5, opacity: 0.7, marginTop: 3, textAlign: 'right', fontFamily: 'var(--font-mono)' }}>09:20 ✓✓</div>
        </div>
      </div>
    );
  }

  function Toggle({ on, onChange, pal }) {
    return (
      <button type="button" onClick={() => onChange(!on)} style={{ width: 44, height: 26, borderRadius: 999, border: 'none', cursor: 'pointer', background: on ? pal.accent : pal.divider, position: 'relative', flexShrink: 0, transition: 'background .15s' }}>
        <span style={{ position: 'absolute', top: 3, left: on ? 21 : 3, width: 20, height: 20, borderRadius: 999, background: '#fff', transition: 'left .15s', boxShadow: '0 1px 3px rgba(0,0,0,.3)' }} />
      </button>
    );
  }

  function SoundRow({ title, value, onChange, pal, allowDefault }) {
    const preview = value || (allowDefault ? 'default' : value);
    return (
      <div style={{ display: 'flex', alignItems: 'center', gap: 8, padding: '6px 12px', borderRadius: 12, border: `1px solid ${pal.divider}`, background: pal.body }}>
        <span style={{ flex: 1, fontSize: 13.5, fontWeight: 600, color: pal.bodyText, whiteSpace: 'nowrap', overflow: 'hidden', textOverflow: 'ellipsis' }}>{title}</span>
        <select value={value} onChange={(e) => onChange(e.target.value)} style={{ appearance: 'none', WebkitAppearance: 'none', background: pal.header, color: pal.bodyText, border: `1px solid ${pal.divider}`, borderRadius: 8, padding: '5px 9px', fontSize: 12.5, fontFamily: 'var(--font-sans)', cursor: 'pointer' }}>
          {allowDefault && <option value="">Default</option>}
          {S.NAMES.map((n) => <option key={n} value={n}>{S.LABELS[n]}</option>)}
        </select>
        <button type="button" onClick={() => S.play(value || (allowDefault ? S.getDefault(window.__chatViewer) : value))} title="Preview" style={{ border: 'none', background: 'transparent', cursor: 'pointer', display: 'flex' }}>
          <Icon name={(value === 'none') ? 'volume_off' : 'play_circle'} size={22} color={pal.accent} />
        </button>
      </div>
    );
  }

  function SettingsPanel({ pal, viewer, cursorTracking, onCursorTracking, onPalette, onBack, contacts }) {
    const [, force] = React.useState(0);
    const rerender = () => force((n) => n + 1);
    return (
      <div style={{ display: 'flex', flexDirection: 'column', height: '100%', background: pal.body }}>
        <div style={{ display: 'flex', alignItems: 'center', gap: 6, padding: '8px 10px', background: pal.header, borderBottom: `1px solid ${pal.divider}` }}>
          <button type="button" onClick={onBack} style={{ border: 'none', background: 'transparent', cursor: 'pointer', display: 'flex', padding: 6 }}><Icon name="arrow_back" size={20} color={pal.headerText} /></button>
          <Icon name="settings" size={18} color={pal.accent} />
          <span style={{ fontSize: 14, fontWeight: 700, color: pal.headerText }}>Messages Settings</span>
        </div>
        <div style={{ flex: 1, overflowY: 'auto', padding: 16 }}>
          <Section pal={pal}>THEME</Section>
          <p style={{ margin: '0 0 12px', fontSize: 12, color: pal.bodySubtle, lineHeight: 1.4 }}>Pick a colour scheme just for your messenger. Every theme is tuned for high contrast — names and messages stay easy to read.</p>
          <div style={{ display: 'grid', gridTemplateColumns: 'repeat(auto-fill, minmax(120px, 1fr))', gap: 10 }}>
            {T.PALETTES.map((p) => <ThemeTile key={p.id} p={p} selected={p.id === pal.id} onTap={() => onPalette(p.id)} />)}
          </div>

          <div style={{ height: 20 }} />
          <Section pal={pal}>PREVIEW</Section>
          <BubblePreview pal={pal} />

          <div style={{ height: 20 }} />
          <Section pal={pal}>CHAT ICON</Section>
          <div style={{ display: 'flex', alignItems: 'center', gap: 12, padding: 12, borderRadius: 12, border: `1px solid ${pal.divider}`, background: pal.body }}>
            <div style={{ flex: 1 }}>
              <div style={{ fontSize: 14, fontWeight: 600, color: pal.bodyText }}>Follow the cursor</div>
              <div style={{ fontSize: 12, color: pal.bodySubtle, lineHeight: 1.3, marginTop: 2 }}>The floating chat icon turns to face your mouse anywhere on screen. Turn off to keep it still.</div>
            </div>
            <Toggle on={cursorTracking} onChange={onCursorTracking} pal={pal} />
          </div>

          <div style={{ height: 20 }} />
          <Section pal={pal}>MESSAGE SOUNDS</Section>
          <p style={{ margin: '0 0 10px', fontSize: 12, color: pal.bodySubtle, lineHeight: 1.4 }}>Played when a new message arrives, unless a contact below has its own sound.</p>
          <SoundRow title="Default sound" value={S.getDefault(viewer)} pal={pal} onChange={(v) => { S.setDefault(viewer, v); S.play(v); rerender(); }} />
          <div style={{ height: 14 }} />
          <div style={{ fontSize: 11, fontWeight: 800, letterSpacing: '.1em', color: pal.bodySubtle, marginBottom: 8 }}>PER-CONTACT SOUNDS</div>
          <div style={{ display: 'flex', flexDirection: 'column', gap: 8 }}>
            {(contacts || []).map((c) => (
              <SoundRow key={c.id} title={c.name} allowDefault value={S.getPerUser(viewer)[c.id] || ''} pal={pal} onChange={(v) => { S.setPerUser(viewer, c.id, v); if (v) S.play(v); rerender(); }} />
            ))}
          </div>

          <div style={{ height: 20 }} />
          <div style={{ textAlign: 'center' }}>
            <button type="button" onClick={() => onPalette(T.DEFAULT.id)} style={{ display: 'inline-flex', alignItems: 'center', gap: 7, border: 'none', background: 'transparent', color: pal.accent, cursor: 'pointer', fontFamily: 'var(--font-sans)', fontSize: 13.5, fontWeight: 700, padding: 8 }}>
              <Icon name="restart_alt" size={18} color={pal.accent} />Reset to Default
            </button>
          </div>
        </div>
      </div>
    );
  }

  window.ChatSettings = { SettingsPanel };
})();
