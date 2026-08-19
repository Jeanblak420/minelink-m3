import React from 'react';

/** Radio group. options: [{value,label,hint}] or [string]. */
export function RadioGroup({ options = [], value, onChange, name, disabled = false, style }) {
  return (
    <div role="radiogroup" style={{ display: 'flex', flexDirection: 'column', gap: 4, ...style }}>
      {options.map((o) => {
        const opt = typeof o === 'string' ? { value: o, label: o } : o;
        const sel = value === opt.value;
        return (
          <label key={opt.value} style={{ display: 'flex', alignItems: 'flex-start', gap: 11, cursor: disabled ? 'not-allowed' : 'pointer', minHeight: 44, opacity: disabled ? 0.5 : 1 }}>
            <span
              onClick={() => !disabled && onChange && onChange(opt.value)}
              style={{
                width: 22, height: 22, borderRadius: 999, flexShrink: 0, marginTop: 1,
                border: `2px solid ${sel ? 'var(--accent)' : 'var(--border-strong)'}`,
                background: 'var(--surface-card)', display: 'flex', alignItems: 'center', justifyContent: 'center',
                transition: 'border-color var(--dur-fast)',
              }}
            >
              {sel && <span style={{ width: 11, height: 11, borderRadius: 999, background: 'var(--accent)' }} />}
            </span>
            <span style={{ paddingTop: 1 }}>
              <span style={{ display: 'block', fontFamily: 'var(--font-sans)', fontSize: 14.5, fontWeight: 500, color: 'var(--text-strong)' }}>{opt.label}</span>
              {opt.hint && <span style={{ display: 'block', fontSize: 12.5, color: 'var(--text-muted)', marginTop: 1 }}>{opt.hint}</span>}
            </span>
          </label>
        );
      })}
    </div>
  );
}
