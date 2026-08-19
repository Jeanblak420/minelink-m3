import React from 'react';

const MAP = {
  transit: { fg: 'var(--status-transit-fg)', bg: 'var(--status-transit-bg)' },
  atmine: { fg: 'var(--status-atmine-fg)', bg: 'var(--status-atmine-bg)' },
  done: { fg: 'var(--status-done-fg)', bg: 'var(--status-done-bg)' },
  warn: { fg: 'var(--status-warn-fg)', bg: 'var(--status-warn-bg)' },
  error: { fg: 'var(--status-error-fg)', bg: 'var(--status-error-bg)' },
  neutral: { fg: 'var(--text-muted)', bg: 'var(--surface-sunken)' },
};

/**
 * Status pill for trip / truck lifecycle states.
 * tone: transit | atmine | done | warn | error | neutral
 */
export function StatusBadge({ children, tone = 'neutral', dot = false, style, ...rest }) {
  const c = MAP[tone] || MAP.neutral;
  return (
    <span
      style={{
        display: 'inline-flex',
        alignItems: 'center',
        gap: 6,
        padding: '5px 11px',
        borderRadius: 'var(--radius-pill)',
        background: c.bg,
        color: c.fg,
        fontFamily: 'var(--font-sans)',
        fontSize: 12,
        fontWeight: 700,
        letterSpacing: '0.02em',
        lineHeight: 1.2,
        whiteSpace: 'nowrap',
        ...style,
      }}
      {...rest}
    >
      {dot && <span style={{ width: 6, height: 6, borderRadius: 999, background: c.fg }} />}
      {children}
    </span>
  );
}
