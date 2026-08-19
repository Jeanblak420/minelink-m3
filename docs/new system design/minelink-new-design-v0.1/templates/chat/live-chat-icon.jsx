/* MineLink Chat — LiveChatIcon: a pseudo-3D glossy disc that turns to face the
 * cursor, carries an unread badge (glossy red) and an animated typing bubble.
 * Ported in spirit from CPS live_chat_icon.dart, rebuilt with CSS 3D + gradients
 * (no image assets, no WebGL). Exposes window.ChatIcon = { LiveChatIcon }.
 * Also installs a global pointer tracker at window.ChatPointer. */
(function () {
  // ── Global pointer tracker (drives the gaze from anywhere on screen) ──
  const Pointer = { x: null, y: null, listeners: new Set() };
  window.addEventListener('mousemove', (e) => { Pointer.x = e.clientX; Pointer.y = e.clientY; }, { passive: true });
  window.ChatPointer = Pointer;

  const GAZE_REACH = 340;   // px to full deflection
  const MAX_TILT = 22;      // deg

  function LiveChatIcon({ size = 56, cursorTracking = true, unreadCount = 0, isTyping = false, accent = '#00B5D8', onClick }) {
    const discRef = React.useRef(null);
    const glossRef = React.useRef(null);
    const rootRef = React.useRef(null);
    const raf = React.useRef(0);
    const cur = React.useRef({ x: 0, y: 0 });
    const idle = React.useRef(0);
    const pressed = React.useRef(0);

    React.useEffect(() => {
      if (!cursorTracking) {
        if (discRef.current) discRef.current.style.transform = 'rotateX(0deg) rotateY(0deg)';
        if (glossRef.current) glossRef.current.style.transform = 'translate(-50%,-50%)';
        return;
      }
      let last = performance.now();
      const tick = (now) => {
        const dt = Math.min(0.05, (now - last) / 1000); last = now;
        idle.current += dt;
        // desired tilt toward pointer, in -1..1 per axis
        let dx = 0, dy = 0;
        const el = rootRef.current;
        if (Pointer.x != null && el) {
          const r = el.getBoundingClientRect();
          const cx = r.left + r.width / 2, cy = r.top + r.height / 2;
          const ddx = Pointer.x - cx, ddy = Pointer.y - cy;
          const dist = Math.hypot(ddx, ddy) || 1;
          const mag = Math.min(1, dist / GAZE_REACH);
          dx = (ddx / dist) * mag; dy = (ddy / dist) * mag;
        } else {
          dx = Math.sin(idle.current * 1.1) * 0.3;
          dy = Math.sin(idle.current * 0.8 + 1.3) * 0.22;
        }
        const k = 1 - Math.exp(-dt * 11);
        cur.current.x += (dx - cur.current.x) * k;
        cur.current.y += (dy - cur.current.y) * k;
        const pk = 1 - Math.exp(-dt * 16);
        pressed.current += ((rootRef.current && rootRef.current._down ? 1 : 0) - pressed.current) * pk;
        const tx = cur.current.x, ty = cur.current.y;
        const scale = 1 - pressed.current * 0.06;
        if (discRef.current) {
          discRef.current.style.transform =
            `rotateX(${(-ty * MAX_TILT).toFixed(2)}deg) rotateY(${(tx * MAX_TILT).toFixed(2)}deg) scale(${scale.toFixed(3)})`;
        }
        if (glossRef.current) {
          glossRef.current.style.transform =
            `translate(calc(-50% + ${(-tx * size * 0.18).toFixed(1)}px), calc(-50% + ${(-ty * size * 0.18 - size * 0.12).toFixed(1)}px))`;
        }
        raf.current = requestAnimationFrame(tick);
      };
      raf.current = requestAnimationFrame(tick);
      return () => cancelAnimationFrame(raf.current);
    }, [cursorTracking, size]);

    const s = size;
    const badge = unreadCount > 99 ? '99+' : String(unreadCount);

    return (
      <div ref={rootRef} onClick={onClick}
        onPointerDown={() => { if (rootRef.current) rootRef.current._down = true; }}
        onPointerUp={() => { if (rootRef.current) rootRef.current._down = false; }}
        onPointerLeave={() => { if (rootRef.current) rootRef.current._down = false; }}
        style={{ width: s, height: s, position: 'relative', cursor: 'pointer', perspective: 460, userSelect: 'none' }}>
        {/* contact shadow */}
        <div style={{ position: 'absolute', left: '50%', top: '64%', width: s * 0.74, height: s * 0.36, transform: 'translateX(-50%)', background: 'radial-gradient(ellipse, rgba(0,0,0,.42), transparent 70%)', filter: 'blur(3px)', borderRadius: '50%' }} />
        {/* the tilting disc */}
        <div ref={discRef} style={{ position: 'absolute', inset: s * 0.09, transformStyle: 'preserve-3d', willChange: 'transform' }}>
          {/* thickness / rim */}
          <div style={{ position: 'absolute', inset: -2, borderRadius: '50%', background: 'linear-gradient(145deg,#2CC7E4,#0E86A8 55%,#06485a)' }} />
          {/* face */}
          <div style={{ position: 'absolute', inset: 0, borderRadius: '50%', background: `radial-gradient(circle at 34% 28%, #7fe4f5, ${accent} 46%, #0781a1 82%, #06485a)`, boxShadow: 'inset 0 -3px 8px rgba(0,0,0,.35), inset 0 3px 6px rgba(255,255,255,.35)', overflow: 'hidden' }}>
            {/* speech bubble mark */}
            <div style={{ position: 'absolute', left: '50%', top: '50%', transform: 'translate(-50%,-52%)', width: s * 0.42, height: s * 0.32 }}>
              <div style={{ width: '100%', height: '100%', background: 'linear-gradient(180deg,#fff,#eaf6fb)', borderRadius: s * 0.1, boxShadow: '0 1px 2px rgba(0,0,0,.25)', position: 'relative' }}>
                <div style={{ position: 'absolute', left: s * 0.05, top: s * 0.06, width: s * 0.22, height: 2, borderRadius: 2, background: '#0e86a8' }} />
                <div style={{ position: 'absolute', left: s * 0.05, top: s * 0.11, width: s * 0.28, height: 2, borderRadius: 2, background: '#0e86a8' }} />
                <div style={{ position: 'absolute', left: s * 0.05, top: s * 0.16, width: s * 0.16, height: 2, borderRadius: 2, background: '#0e86a8' }} />
                <div style={{ position: 'absolute', left: s * 0.07, bottom: -s * 0.05, width: 0, height: 0, borderLeft: `${s * 0.05}px solid transparent`, borderRight: `${s * 0.05}px solid transparent`, borderTop: `${s * 0.07}px solid #eaf6fb` }} />
              </div>
            </div>
            {/* moving specular highlight */}
            <div ref={glossRef} style={{ position: 'absolute', left: '50%', top: '50%', width: s * 0.7, height: s * 0.5, background: 'radial-gradient(ellipse, rgba(255,255,255,.55), transparent 70%)', pointerEvents: 'none' }} />
          </div>
        </div>
        {/* typing bubble — bottom-right, upright */}
        {isTyping && (
          <div style={{ position: 'absolute', right: -s * 0.02, bottom: s * 0.02, width: s * 0.44, height: s * 0.33, background: 'linear-gradient(160deg,#FFA253,#F26A1B)', borderRadius: 999, boxShadow: '0 2px 5px rgba(0,0,0,.3)', display: 'flex', alignItems: 'center', justifyContent: 'center', gap: s * 0.045 }}>
            {[0, 1, 2].map((i) => (
              <span key={i} style={{ width: s * 0.06, height: s * 0.06, borderRadius: 999, background: '#fff', animation: `mlTypingDot 1.05s ${i * 0.18}s infinite` }} />
            ))}
          </div>
        )}
        {/* unread badge — top-right, glossy red, upright */}
        {unreadCount > 0 && (
          <div style={{ position: 'absolute', right: -s * 0.06, top: -s * 0.04, minWidth: s * 0.42, height: s * 0.42, padding: badge.length > 1 ? `0 ${s * 0.1}px` : 0, borderRadius: 999, border: '2px solid rgba(255,255,255,.9)', background: 'radial-gradient(circle at 38% 30%, #FF8A78, #F4321F 55%, #B30E04)', boxShadow: '0 2px 6px rgba(0,0,0,.4), 0 0 8px rgba(244,50,31,.5)', display: 'flex', alignItems: 'center', justifyContent: 'center', boxSizing: 'border-box' }}>
            <span style={{ color: '#fff', fontWeight: 800, fontSize: s * 0.2, lineHeight: 1, fontFamily: 'var(--font-sans)' }}>{badge}</span>
          </div>
        )}
      </div>
    );
  }

  window.ChatIcon = { LiveChatIcon };
})();
