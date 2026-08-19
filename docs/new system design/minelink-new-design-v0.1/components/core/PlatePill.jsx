import React from 'react';

/** Monospace vehicle registration plate. size: sm | md | lg */
export function PlatePill({ children, size = 'md', style, ...rest }) {
  const fs = size === 'lg' ? 22 : size === 'sm' ? 14 : 17;
  return (
    <span
      style={{
        fontFamily: 'var(--font-mono)',
        fontWeight: 700,
        fontSize: fs,
        letterSpacing: 'var(--ls-plate)',
        color: 'var(--text-strong)',
        ...style,
      }}
      {...rest}
    >
      {children}
    </span>
  );
}
