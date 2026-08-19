/* MineLink Chat — floating overlay shell. Draggable + resizable window with
 * minimized (pseudo-3D disc launcher) / normal (floating panel) / maximized
 * (fullscreen) states and a title bar (settings · minimize · maximize · close).
 * Mirrors CPS chat_overlay_shell. Exposes window.ChatShell. */
(function () {
  const { Icon } = window.MineLinkDesignSystem_9acfde;
  const { LiveChatIcon } = window.ChatIcon;

  const MIN_W = 340, MIN_H = 440, MAX_W = 720, MAX_H = 860;
  const clamp = (v, lo, hi) => Math.max(lo, Math.min(hi, v));

  function WinBtn({ icon, title, onClick, pal }) {
    const [h, setH] = React.useState(false);
    return (
      <button type="button" title={title} onClick={onClick} onMouseEnter={() => setH(true)} onMouseLeave={() => setH(false)}
        style={{ border: 'none', background: h ? 'rgba(127,127,127,.25)' : 'transparent', cursor: 'pointer', display: 'flex', padding: 6, borderRadius: 6 }}>
        <Icon name={icon} size={16} color={pal.headerText} />
      </button>
    );
  }

  function TitleBar({ pal, mode, onDragStart, onSettings, onMinimize, onToggleMax, onClose }) {
    return (
      <div onPointerDown={mode === 'normal' ? onDragStart : undefined}
        style={{ height: 40, display: 'flex', alignItems: 'center', gap: 6, padding: '0 8px', background: pal.header, borderBottom: `1px solid ${pal.divider}`, cursor: mode === 'normal' ? 'grab' : 'default', flexShrink: 0, userSelect: 'none' }}>
        <Icon name="forum" size={18} color={pal.accent} fill={1} />
        <span style={{ flex: 1, fontSize: 13, fontWeight: 700, color: pal.headerText }}>Messages</span>
        <WinBtn icon="settings" title="Messages settings" onClick={onSettings} pal={pal} />
        <WinBtn icon="remove" title="Minimize" onClick={onMinimize} pal={pal} />
        <WinBtn icon={mode === 'maximized' ? 'close_fullscreen' : 'open_in_full'} title={mode === 'maximized' ? 'Restore' : 'Maximize'} onClick={onToggleMax} pal={pal} />
        <WinBtn icon="close" title="Close" onClick={onClose} pal={pal} />
      </div>
    );
  }

  function ChatShell({ pal, accent, viewer, unreadCount, isTyping, cursorTracking, onOpenSettings, children }) {
    const [mode, setMode] = React.useState('minimized'); // minimized | normal | maximized
    const vw = () => window.innerWidth, vh = () => window.innerHeight;
    const [geo, setGeo] = React.useState(() => {
      const w = Math.min(384, vw() - 24);
      const h = Math.min(560, vh() - 88);
      return { x: clamp(vw() - w - 24, 8, vw() - w), y: clamp(vh() - h - 20, 56, vh() - h), w, h };
    });
    const [discPos, setDiscPos] = React.useState(() => ({ x: vw() - 84, y: vh() - 84 }));
    const drag = React.useRef(null);

    // window drag (title bar)
    const startWinDrag = (e) => {
      drag.current = { kind: 'move', sx: e.clientX, sy: e.clientY, gx: geo.x, gy: geo.y };
      window.addEventListener('pointermove', onMove); window.addEventListener('pointerup', onUp);
    };
    const startResize = (e) => {
      e.stopPropagation();
      drag.current = { kind: 'resize', sx: e.clientX, sy: e.clientY, gw: geo.w, gh: geo.h };
      window.addEventListener('pointermove', onMove); window.addEventListener('pointerup', onUp);
    };
    const onMove = (e) => {
      const d = drag.current; if (!d) return;
      if (d.kind === 'move') {
        setGeo((g) => ({ ...g, x: clamp(d.gx + (e.clientX - d.sx), 0, vw() - g.w), y: clamp(d.gy + (e.clientY - d.sy), 0, vh() - g.h) }));
      } else if (d.kind === 'resize') {
        setGeo((g) => ({ ...g, w: clamp(d.gw + (e.clientX - d.sx), MIN_W, Math.min(MAX_W, vw() - g.x)), h: clamp(d.gh + (e.clientY - d.sy), MIN_H, Math.min(MAX_H, vh() - g.y)) }));
      } else if (d.kind === 'disc') {
        d.moved = Math.hypot(e.clientX - d.sx, e.clientY - d.sy) > 4 || d.moved;
        setDiscPos({ x: clamp(d.gx + (e.clientX - d.sx), 4, vw() - 60), y: clamp(d.gy + (e.clientY - d.sy), 4, vh() - 60) });
      }
    };
    const onUp = () => { window.removeEventListener('pointermove', onMove); window.removeEventListener('pointerup', onUp); setTimeout(() => { drag.current = null; }, 0); };

    const startDiscDrag = (e) => { drag.current = { kind: 'disc', sx: e.clientX, sy: e.clientY, gx: discPos.x, gy: discPos.y, moved: false }; window.addEventListener('pointermove', onMove); window.addEventListener('pointerup', onUp); };

    if (mode === 'minimized') {
      return (
        <div style={{ position: 'fixed', left: discPos.x, top: discPos.y, zIndex: 9000 }} onPointerDown={startDiscDrag}>
          <LiveChatIcon size={60} accent={accent} cursorTracking={cursorTracking} unreadCount={unreadCount} isTyping={isTyping}
            onClick={() => { if (!drag.current || !drag.current.moved) setMode('normal'); }} />
        </div>
      );
    }

    const isMax = mode === 'maximized';
    const box = isMax ? { left: 0, top: 0, width: vw(), height: vh(), borderRadius: 0 }
      : { left: geo.x, top: geo.y, width: geo.w, height: geo.h, borderRadius: 14 };

    return (
      <div style={{ position: 'fixed', ...box, zIndex: 9000, boxShadow: '0 18px 50px rgba(2,6,23,.5)', overflow: 'hidden', border: `1px solid ${pal.divider}`, background: pal.body, display: 'flex', flexDirection: 'column' }}>
        <TitleBar pal={pal} mode={mode} onDragStart={startWinDrag} onSettings={onOpenSettings}
          onMinimize={() => setMode('minimized')} onToggleMax={() => setMode(isMax ? 'normal' : 'maximized')} onClose={() => setMode('minimized')} />
        <div style={{ flex: 1, minHeight: 0, position: 'relative' }}>{children}</div>
        {!isMax && (
          <div onPointerDown={startResize} title="Resize" style={{ position: 'absolute', right: 0, bottom: 0, width: 18, height: 18, cursor: 'nwse-resize', zIndex: 5 }}>
            <svg width="18" height="18" style={{ position: 'absolute', right: 2, bottom: 2 }}><path d="M11 17 L17 11 M15 17 L17 15" stroke={pal.bodySubtle} strokeWidth="1.5" fill="none" /></svg>
          </div>
        )}
      </div>
    );
  }

  window.ChatShell = { ChatShell };
})();
