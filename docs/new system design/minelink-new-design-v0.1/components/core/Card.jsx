import React from 'react';

/** Base surface card with subtle border + shadow. Use `tone="hero"` for the
 * cyan-tinted gradient overview tile, `inset` for a sunken well. */
export function Card({ children, tone = 'plain', padding = 20, onClick, style, ...rest }) {
  const tones = {
    plain: { background: 'var(--surface-card)', border: '1px solid var(--border-card)', boxShadow: 'var(--shadow-sm)' },
    hero: {
      background: 'linear-gradient(150deg, var(--ml-well-cyan), var(--surface-card))',
      border: '1px solid var(--border-accent)',
      boxShadow: 'var(--shadow-hero)',
    },
    inset: { background: 'var(--surface-sunken)', border: '1px solid var(--border-card)', boxShadow: 'none' },
    chrome: { background: 'linear-gradient(160deg,var(--ml-navy-800),var(--ml-navy-950))', border: 'none', boxShadow: 'var(--shadow-md)', color: '#fff' },
  };
  return (
    <div
      onClick={onClick}
      style={{
        borderRadius: 'var(--radius-xl)',
        padding,
        boxSizing: 'border-box',
        cursor: onClick ? 'pointer' : 'default',
        transition: 'box-shadow var(--dur-base) var(--ease-out), transform var(--dur-base) var(--ease-out)',
        ...(tones[tone] || tones.plain),
        ...style,
      }}
      {...rest}
    >
      {children}
    </div>
  );
}
