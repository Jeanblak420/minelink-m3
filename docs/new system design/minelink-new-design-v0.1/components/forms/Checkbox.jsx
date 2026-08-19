import React from 'react';
import { Icon } from '../core/Icon.jsx';

/** Checkbox with optional label. Cyan filled tick when checked. */
export function Checkbox({ checked = false, indeterminate = false, onChange, disabled = false, label, hint, style }) {
  const box = (
    <span
      onClick={() => !disabled && onChange && onChange(!checked)}
      style={{
        width: 22, height: 22, borderRadius: 6, flexShrink: 0,
        border: `1.5px solid ${checked || indeterminate ? 'var(--accent)' : 'var(--border-strong)'}`,
        background: checked || indeterminate ? 'var(--accent)' : 'var(--surface-card)',
        display: 'flex', alignItems: 'center', justifyContent: 'center',
        cursor: disabled ? 'not-allowed' : 'pointer', opacity: disabled ? 0.5 : 1,
        transition: 'background var(--dur-fast), border-color var(--dur-fast)',
      }}
    >
      {indeterminate ? <Icon name="remove" size={16} color="#fff" /> : checked ? <Icon name="check" size={16} color="#fff" weight={700} /> : null}
    </span>
  );
  if (!label) return <span style={style}>{box}</span>;
  return (
    <label style={{ display: 'flex', alignItems: 'flex-start', gap: 11, cursor: disabled ? 'not-allowed' : 'pointer', minHeight: 44, ...style }}>
      {box}
      <span style={{ paddingTop: 1 }}>
        <span style={{ display: 'block', fontFamily: 'var(--font-sans)', fontSize: 14.5, fontWeight: 500, color: 'var(--text-strong)' }}>{label}</span>
        {hint && <span style={{ display: 'block', fontSize: 12.5, color: 'var(--text-muted)', marginTop: 1 }}>{hint}</span>}
      </span>
    </label>
  );
}
