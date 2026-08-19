import React from 'react';

/** Toggle switch. Cyan when on, slate when off; 44px hit target row. */
export function Switch({ checked = false, onChange, disabled = false, label, hint, style }) {
  const knob = (
    <button
      type="button"
      role="switch"
      aria-checked={checked}
      disabled={disabled}
      onClick={() => !disabled && onChange && onChange(!checked)}
      style={{
        width: 46, height: 27, borderRadius: 999, border: 'none', flexShrink: 0,
        cursor: disabled ? 'not-allowed' : 'pointer', opacity: disabled ? 0.5 : 1,
        background: checked ? 'var(--accent)' : 'var(--ml-slate-300)',
        position: 'relative', transition: 'background var(--dur-fast) var(--ease-out)',
      }}
    >
      <span style={{
        position: 'absolute', top: 3, left: checked ? 22 : 3, width: 21, height: 21,
        borderRadius: 999, background: '#fff', boxShadow: 'var(--shadow-xs)',
        transition: 'left var(--dur-base) var(--ease-out-cubic)',
      }} />
    </button>
  );
  if (!label) return <span style={style}>{knob}</span>;
  return (
    <label style={{ display: 'flex', alignItems: 'center', gap: 12, cursor: disabled ? 'not-allowed' : 'pointer', minHeight: 44, ...style }}>
      {knob}
      <span style={{ flex: 1 }}>
        <span style={{ display: 'block', fontFamily: 'var(--font-sans)', fontSize: 14.5, fontWeight: 600, color: 'var(--text-strong)' }}>{label}</span>
        {hint && <span style={{ display: 'block', fontSize: 12.5, color: 'var(--text-muted)', marginTop: 1 }}>{hint}</span>}
      </span>
    </label>
  );
}
