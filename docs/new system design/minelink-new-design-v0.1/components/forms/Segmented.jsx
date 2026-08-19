import React from 'react';

/** Segmented control — pill of 2–5 short options. options: [string] or [{value,label}]. */
export function Segmented({ options = [], value, onChange, size = 'md', style }) {
  const pad = size === 'sm' ? '7px 12px' : '9px 15px';
  const fs = size === 'sm' ? 13 : 13.5;
  return (
    <div style={{ display: 'inline-flex', background: 'var(--surface-sunken)', borderRadius: 'var(--radius-md)', padding: 3, gap: 2, ...style }}>
      {options.map((o) => {
        const opt = typeof o === 'string' ? { value: o, label: o } : o;
        const sel = value === opt.value;
        return (
          <button key={opt.value} type="button" onClick={() => onChange && onChange(opt.value)}
            style={{
              padding: pad, borderRadius: 9, border: 'none', cursor: 'pointer',
              fontFamily: 'var(--font-sans)', fontSize: fs, fontWeight: 600, whiteSpace: 'nowrap',
              background: sel ? 'var(--surface-card)' : 'transparent',
              color: sel ? 'var(--text-strong)' : 'var(--text-muted)',
              boxShadow: sel ? 'var(--shadow-xs)' : 'none',
              transition: 'background var(--dur-fast), color var(--dur-fast)',
            }}
          >
            {opt.label}
          </button>
        );
      })}
    </div>
  );
}
