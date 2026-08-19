import React from 'react';

/** Hover tooltip wrapper. Wrap any element; shows on hover/focus. */
export function Tooltip({ label, placement = 'top', children, style }) {
  const [show, setShow] = React.useState(false);
  const pos = {
    top: { bottom: '100%', left: '50%', transform: 'translateX(-50%) translateY(-8px)' },
    bottom: { top: '100%', left: '50%', transform: 'translateX(-50%) translateY(8px)' },
    left: { right: '100%', top: '50%', transform: 'translateY(-50%) translateX(-8px)' },
    right: { left: '100%', top: '50%', transform: 'translateY(-50%) translateX(8px)' },
  }[placement];
  return (
    <span style={{ position: 'relative', display: 'inline-flex', ...style }}
      onMouseEnter={() => setShow(true)} onMouseLeave={() => setShow(false)}
      onFocus={() => setShow(true)} onBlur={() => setShow(false)}>
      {children}
      <span style={{
        position: 'absolute', ...pos, zIndex: 60, pointerEvents: 'none', whiteSpace: 'nowrap',
        background: 'var(--ml-navy-900)', color: '#fff', fontFamily: 'var(--font-sans)', fontSize: 12, fontWeight: 600,
        padding: '6px 10px', borderRadius: 8, boxShadow: 'var(--shadow-md)',
        opacity: show ? 1 : 0, transition: 'opacity var(--dur-fast)',
      }}>
        {label}
      </span>
    </span>
  );
}
