import React from 'react';

/** Circular avatar with initials (or image). tone: cyan | navy | slate */
export function Avatar({ name = '', src, size = 40, tone = 'cyan', style }) {
  const initials = name.split(' ').filter(Boolean).slice(0, 2).map((w) => w[0]?.toUpperCase()).join('');
  const tones = {
    cyan: { bg: 'var(--accent)', fg: '#fff' },
    navy: { bg: 'var(--ml-navy-800)', fg: '#fff' },
    slate: { bg: 'var(--ml-slate-200)', fg: 'var(--text-strong)' },
  };
  const t = tones[tone] || tones.cyan;
  return (
    <div style={{
      width: size, height: size, borderRadius: 999, flexShrink: 0,
      background: src ? `center/cover url(${src})` : t.bg, color: t.fg,
      display: 'flex', alignItems: 'center', justifyContent: 'center',
      fontFamily: 'var(--font-sans)', fontWeight: 700, fontSize: size * 0.36,
      letterSpacing: '0.01em', ...style,
    }}>
      {!src && initials}
    </div>
  );
}
